use strict;
use vars qw($VERSION %IRSSI);
use utf8;
use POSIX;
use File::Glob qw/:bsd_glob/;
use CPAN::Meta::YAML;
use File::Fetch;
use Time::Piece;
use Digest::file qw/digest_file_hex/;
use Digest::MD5 qw/md5_hex/;
use Text::Wrap;
use debug;

use Irssi;

$VERSION = '0.01';
%IRSSI = (
    authors => 'bw1',
    contact => 'bw1@aol.at',
    name => 'scriptassist2',
    description   => 'This script really does nothing. Sorry.',
    license => 'lgpl',
    url     => 'https://scripts.irssi.org/',
    changed => '2021-02-13',
    modules => '',
    commands=> 'scriptassist2',
);

my $help = << "END";
%9Name%9
  $IRSSI{name}
%9Version%9
  $VERSION
%9description%9
  $IRSSI{description}
%9commands%9
  /scriptassist check
      Check all loaded scripts for new available versions
  /scriptassist update <script|all>
      Update the selected or all script to the newest version
  /scriptassist search <query>
      Search the script database
  /scriptassist info <scripts>
      Display information about <scripts>
  /scriptassist ratings <scripts|all>
      Retrieve the average ratings of the the scripts
  /scriptassist top <num>
      Retrieve the first <num> top rated scripts
  /scriptassist new <num>
      Display the newest <num> scripts
  /scriptassist rate <script>
      Rate the script if you like it
  /scriptassist contact <script>
      Write an email to the author of the script
      (Requires OpenURL)
  /scriptassist cpan <module>
      Visit CPAN to look for missing Perl modules
      (Requires OpenURL)
  /scriptassist install <script>
      Retrieve and load the script
  /scriptassist autorun <script>
      Toggles automatic loading of <script>
%9See also%9
  https://perldoc.perl.org/perl.html
  https://github.com/irssi/irssi/blob/master/docs/perl.txt
  https://github.com/irssi/irssi/blob/master/docs/signals.txt
  https://github.com/irssi/irssi/blob/master/docs/formats.txt
END

# TODO
#
#  /scriptassist contact <script>
#  /scriptassist cpan <module>
#
#  /scriptassist rate <script>
#  /scriptassist ratings <scripts|all>
#  /scriptassist top <num>
#  signature

# config path
my $path;

# data root
my $d;
# ->{rconfig}->@
# ->{rscripts}->%
# ->{rstat}->%
# ->{autorun}->@

# links to $d->{rconfig}->@
my %source;

my %bg_process= ();

sub background {
   my ($cmd) =@_;
   my ($fh_r, $fh_w);
   pipe $fh_r, $fh_w;
   my $pid = fork();
   if ($pid ==0 ) {
      my @res;
      @res= &{$cmd->{cmd}}(@{$cmd->{args}});
      my $yml=CPAN::Meta::YAML->new(\@res);
      print $fh_w $yml->write_string();
      close $fh_w;
      POSIX::_exit(1);
   } else {
      $cmd->{fh_r}=$fh_r;
      my $pipetag;
      my @args = ($pid, \$pipetag );
      $pipetag = Irssi::input_add(fileno($fh_r), Irssi::INPUT_READ, \&sig_pipe, \@args);
      $cmd->{pipetag} = $pipetag;
      $bg_process{$pid}=$cmd;
      Irssi::pidwait_add($pid);
   }
}

sub sig_pipe {
   my ($pid, $pipetag) = @{$_[0]};
   if (exists $bg_process{$pid}) {
      my $fh_r= $bg_process{$pid}->{fh_r};
      $bg_process{$pid}->{res_str} .= do { local $/; <$fh_r>; };
      Irssi::input_remove($$pipetag);
   }
}

sub sig_pidwait {
   my ($pid, $status) = @_;
   if (exists $bg_process{$pid}) {
      close $bg_process{$pid}->{fh_r};
      Irssi::input_remove($bg_process{$pid}->{pipetag});
      utf8::decode($bg_process{$pid}->{res_str});
      my $yml = CPAN::Meta::YAML->read_string($bg_process{$pid}->{res_str});
      my @res = @{ $yml->[0] };
      $bg_process{$pid}->{res}=[@res];
      if (exists $bg_process{$pid}->{last}) {
         foreach my $p (@{$bg_process{$pid}->{last}}) {
            &$p($bg_process{$pid});
         }
      } else {
         Irssi::print(join(" ",@res), MSGLEVEL_CLIENTCRAP);
      }
      delete $bg_process{$pid};
   }
}

sub print_box {
   my ( $head,  $foot, @inside)=@_;
   Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'box_header', $head); 
   foreach my $n ( @inside ) {
      foreach ( split /\n/, $n ) {
         #Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'box_inside', $_); 
         Irssi::print("%R|%n $_", MSGLEVEL_CLIENTCRAP); 
      }
   }
   Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'box_footer', $foot); 
}

sub print_short {
   my ( $str )= @_;
   Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'short_msg', $str); 
}

sub installed_version {
   my ( $scriptname )= @_;
   my $r;
   no strict 'refs';
   $r = ${ "Irssi::Script::${scriptname}::VERSION" };
   return $r;
}

sub init {
   if ( -e "$path/cache.yml" ) {
      my $yml= CPAN::Meta::YAML->read("$path/cache.yml");
      $d= $yml->[0];
   }
   if ( ref($d) ne 'HASH' || ! exists $d->{rconfig} ) {
      $d= undef;
      $d->{rconfig}=();
      my %n;
      $n{name}="irssi";
      $n{type}="yaml";
      $n{url_db}="https://scripts.irssi.org/scripts.yml";
      $n{url_sc}="https://scripts.irssi.org/scripts";
      push @{$d->{rconfig}}, {%n};
   }
   foreach my $n ( @{ $d->{rconfig} } ) {
      $source{$n->{name}}= $n;
   }
   if ( exists $d->{autorun} ) {
      foreach my $fn ( @{$d->{autorun}} ) {
         my $sn= $fn;
         $sn =~ s/\.pl$//i;
         if (! (installed_version $sn )) {
            Irssi::command("script load $fn");
         }
      }
   }
}

sub save {
   my $yml= CPAN::Meta::YAML->new( $d );
   $yml->write("$path/cache.yml");
}

sub fetch {
   my ($uri)= @_;
   my ($ff, $w, $res);
	local $File::Fetch::WARN=0;
   $ff = File::Fetch->new (
      uri => $uri,
   );
   $w = $ff->fetch(to => $path,); 
   if ( $w ) {
      $res= $ff->file;
   }
   return $res;
}

sub getmeta {
   my @msg;
   foreach my $n ( @{ $d->{rconfig} } ) {
      my $fn=fetch( $n->{url_db} );
      if ( defined $fn ) {
         if ( $n->{type} eq 'yaml' ) {
            my $di=digest_file_hex("$path/$fn", 'MD5');
            if ( $di ne $d->{rstat}->{$n->{name}}->{digest} ) {
               my $yml= CPAN::Meta::YAML->read("$path/$fn");
               my $sl;
               foreach my $sn ( @{$yml->[0]} ) {
                  $sl->{$sn->{filename}}=$sn;
               }
               $d->{rscripts}->{$n->{name}}= $sl;
            }
            my $t=localtime();
            $d->{rstat}->{$n->{name}}->{last}= $t->epoch;
            $d->{rstat}->{$n->{name}}->{digest}= $di; 
            unlink "$path/$fn";
         }
      } else {
         push @msg, "Error: fetch $n->{name} ($n->{url_db})";
      }
   }
   return $d, [@msg] ;
}

sub print_getmeta {
   my ( $pn ) = @_;
   # write back to main!
   $d= $pn->{res}->[0] ;
   foreach my $n ( @{ $d->{rconfig} } ) {
      $source{$n->{name}}= $n;
   }
   foreach my $s (@{$pn->{res}->[1]} ) {
      print_short $s; 
   }
   print_short "database cache updatet"; 
}

sub cmd_reload {
   init();
   print_short "reloadet"; 
}

sub cmd_save {
   save();
   print_short "write to disk"; 
}

sub sinfo {
   my ( $nl, $name, $value)=@_;
   my $v;
   {
      local $Text::Wrap::columns = 60;
      local $Text::Wrap::unexpand= 0;
      $v =wrap('', ' 'x($nl+2+2), $value);
   }
   return sprintf "  %-${nl}s: %s", $name, $v;
}

sub module_exist {
   my ($module) = @_;
   $module =~ s/::/\//g;
   foreach (@INC) {
      return 1 if (-e $_."/".$module.".pm");
   }
   return 0;
}

sub check_autorun {
   my ( $filename )= @_;
   my $r;
   if ( -e Irssi::get_irssi_dir()."/scripts/autorun/$filename" ) {
      $r=1;
   }
   return $r;
}

sub cmd_info {
   my ( @args)=@_;
   my @r;
   foreach my $sn ( @args ) {
      my $fn=$sn;
      $fn =~ s/$/\.pl/ if ( $sn !~ m/\.pl$/ );
      foreach my $sl ( keys %{ $d->{rscripts} } ) {
         if ( exists $d->{rscripts}->{$sl}->{$fn} ) {
            my $n=$d->{rscripts}->{$sl}->{$fn};
            my $iver=installed_version($sn);
            if ( defined $iver ) {
               push @r, "%go%n $sn";
            } else {
               push @r, "%ro%n $sn";
            }
            push @r, sinfo 11, "Version", $n->{version};
            push @r, sinfo 11, "Source", $source{$sl}->{url_sc};
            push @r, sinfo 11, "Installed", $iver if (defined $iver);
            if ( defined $iver ) {
               push @r, sinfo 11, "Autorun", check_autorun($fn) ? "yes" : "no";
            }
            push @r, sinfo 11, "Authors", $n->{authors};
            push @r, sinfo 11, "Contact", $n->{contact};
            push @r, sinfo 11, "Description", $n->{description};
            if ( exists $n->{modules} ) {
               push @r, " ";
               push @r, "  Needed Perl modules:";
               foreach my $m ( sort split /\s+/, $n->{modules} ) {
                  if ( module_exist $m ) {
                     push @r, "   %g->%n $m (found)";
                  } else {
                     push @r, "   %r->%n $m (not found)";
                  }
               }
            }
            if ( exists $n->{depends} ) {
               push @r, " ";
               push @r, "  Needed Irssi Scripts:";
               foreach my $d ( sort split /\s+/, $n->{depends} ) {
                  if ( installed_version $d ) {
                     push @r, "   %g->%n $d (loaded)";
                  } else {
                     push @r, "   %r->%n $d (not loaded)";
                  }
               }
            }
         }
      }
   }
   print_box($IRSSI{name},"info", @r);
}

sub oneline_info {
   my ( $search, $name, $desc, $aut )=@_;
   my $d;
   my $l= length( $name) +3;
   {
      local $Text::Wrap::columns = 60;
      local $Text::Wrap::unexpand= 0;
      $d =wrap('', ' 'x$l, "$desc ($aut)");
   }
   my $p= (installed_version $name) ? "%go%n " : "%yo%n ";
   my $s= "$name $d";
   $s =~ s/($search)/%U\1%n/i;
   return $p.$s;
}

sub cmd_search {
   my (@args)=@_;
   my @r;
   foreach my $sk ( keys %{ $d->{rscripts} }) {
      foreach my $fn ( sort keys %{ $d->{rscripts}->{$sk} } ) {
      my $n= $d->{rscripts}->{$sk}->{$fn};
         if ( $fn =~ m/$args[0]/i ||
            $n->{name} =~ m/$args[0]/i ||
            $n->{description} =~ m/$args[0]/i ) {
            my $sn= $fn;
            $sn=~ s/\.pl$//;
            push @r, oneline_info( $args[0], $sn, $n->{description}, $n->{authors});
         }
      }
   }
   print_box($IRSSI{name},"search", @r);
}

sub compare_versions {
   my ($ver1, $ver2) = @_;
   for ($ver1, $ver2) {
      $_ = "0:$_" unless /:/;
   }
   my @ver1 = split /[.:]/, $ver1;
   my @ver2 = split /[.:]/, $ver2;
   my $cmp = 0;
   ### Special thanks to Clemens Heidinger
   no warnings 'uninitialized';
   $cmp ||= $ver1[$_] <=> $ver2[$_] || $ver1[$_] cmp $ver2[$_] for 0..scalar(@ver2);
   return 'newer' if $cmp == 1;
   return 'older' if $cmp == -1;
   return 'equal';
}

sub cmd_check {
   my @res;
   my @sn;
   my $lm;
   foreach my $sn (keys %Irssi::Script:: ) {
      $sn =~ s/:+$//;
      $lm = length $sn if ( $lm < length $sn);
      push @sn, $sn;
   }
   foreach my $sn (sort @sn ) {
      my $v = installed_version $sn;
      my $rv;
      foreach my $sk ( keys %{ $d->{rscripts} } ) {
         my $fn = "$sn.pl";
         if ( exists $d->{rscripts}->{$sk}->{$fn} ) {
            $rv= $d->{rscripts}->{$sk}->{$fn}->{version};
         }
      }
      my $s;
      if ( defined $rv ) {
         my $r= compare_versions $v, $rv;
         if ( $r eq 'equal' ) {
            $s = sprintf "%%go%%n %%9%-${lm}s%%9 Up to date. ($v)", $sn;
         } elsif ( $r eq 'newer') {
            $s = sprintf "%%bo%%n %%9%-${lm}s%%9 Your version is newer ($v->$rv)", $sn;
         } elsif ( $r eq 'older') {
            $s = sprintf "%%ro%%n %%9%-${lm}s%%9 A new version is available ($v->$rv)", $sn;
         }
      } else {
         $s = sprintf "%%mo%%n %%9%-${lm}s%%9 No version information available on network.", $sn;
      }
      push @res, $s;
   }
   print_box($IRSSI{name},"check", @res);
}

sub cmd_new {
   my ( @args )= @_;
   my $as;
   foreach my $sk ( keys %{ $d->{rscripts} } ) {
      foreach my $fn ( keys %{ $d->{rscripts}->{$sk} } ) {
         if ( exists $as->{$fn} ) {
            if ( ($as->{$fn}->{modified} cmp $d->{rscripts}->{$sk}->{$fn}->{modified}) == -1) {
               $as->{$fn}= $d->{rscripts}->{$sk}->{$fn};
            }
         } else {
            $as->{$fn}= $d->{rscripts}->{$sk}->{$fn};
         }
      }
   }
   my $count = $args[0]*1;
   $count=5 if ( $count <1 );
   my @res;
   my $mlen;
   foreach ( sort { $as->{$b}->{modified} cmp $as->{$a}->{modified} } keys %$as ) {
      last if ( $count==0);
      push @res,$_;
      $mlen = length $_ if ( $mlen < length $_ );
      $count--;
   }
   my @r;
   $mlen -= 3;
   foreach ( @res ) {
      my $sn=$_;
      $sn =~ s/\.pl$//i;
      my $p;
      if ( installed_version $sn ) {
         $p = "%go%n ";
      } else {
         $p = "%yo%n ";
      }
      push @r, $p.sprintf "%%9%-${mlen}s%%9 $as->{$_}->{modified}", $sn;
   }
   print_box($IRSSI{name},"new", @r);
}

sub cmd_install {
   my ( @args )= @_;
   my @sl;
   foreach my $sn ( @args ) {
      $sn =~ s/\.pl$//i;
      my $fn ="$sn.pl";
      my $rd;
      foreach my $rc ( @{ $d->{rconfig} } ) {
         if ( exists $d->{rscripts}->{$rc->{name}}->{$fn} ) {
            $rd= $rc;
         }
      }
      if ( defined $rd ) {
         my $s="$rd->{url_sc}/$fn";
         push @sl, $s;
      }
   }
   print_short "Please wait..."; 
   background({ 
      cmd => \&bg_install,
      args => [ @sl ],
      last => [ \&print_install ],
   });
}

sub bg_install {
   my ( @sl )= @_;
   my @r;
   foreach my $url ( @sl ) {
      my $fn=fetch( $url );
      if (defined $fn ) {
         if ( -e Irssi::get_irssi_dir()."/scripts/$fn" ) {
            rename Irssi::get_irssi_dir()."/scripts/$fn", Irssi::get_irssi_dir()."/scripts/$fn.bak";
         }
         rename "$path/$fn", Irssi::get_irssi_dir()."/scripts/$fn";
         push @r, $fn; 
      }
   }
   return @r;
}

sub print_install {
   my ( $pn ) = @_;
   my @res;
   foreach my $fn ( @{ $pn->{res} } ) {
      my $sn= $fn;
      $sn =~ s/\.pl$//i;
      if ( !installed_version $sn ) {
         Irssi::command("script load $fn");
         push @res, "%go%n %9$sn%9 installed";
      } else {
         push @res, "%ro%n %9$sn%9 already loaded, please try 'update'";
      }
   }
   print_box($IRSSI{name},"install", @res);
}

sub cmd_autorun {
   my ( @args )= @_;
   foreach my $sn ( @args ){
      $sn =~ s/\.pl$//i;
      my $fn = "$sn.pl";
      my $of=Irssi::get_irssi_dir()."/scripts/$fn";
      if (Irssi::settings_get_bool($IRSSI{name}.'_autorun_link') ) {
         my $af=Irssi::get_irssi_dir()."/scripts/autorun/$fn";
         if (-e $af ) {
            if ( -l $af ) {
               unlink $af;
               print_short "Autorun of $sn disabled";
            } else {
               print_short "$fn is not a symlink";
            }
         } else {
            if ( -e $of ) {
               symlink "../$fn", $af;
               print_short "Autorun of $sn enabled";
            }
         }
      } else {
         if ( !exists $d->{autorun} ) {
            $d->{autorun}=[];
         }
         my $r;
         for (my $c=0; $c < scalar( @{ $d->{autorun} } ) ; $c++) {
            if ($d->{autorun}->[$c] eq $fn) {
               splice @{ $d->{autorun} } , $c ,1;
               $r=1;
               print_short "Autorun of $sn disabled";
               last;
            }
         }
         if (!$r && -e $of ) {
            push @{ $d->{autorun} }, $fn;
            print_short "Autorun of $sn enabled";
         }
      }
   }
}

sub cmd_update {
   my ( @args )= @_;
   my @sn;
   if ( $args[0] eq 'all' ) {
      foreach my $sn (keys %Irssi::Script:: ) {
         $sn =~ s/:+$//;
         push @sn, $sn;
      }
   } else {
      foreach my $sn ( @args ) {
         $sn =~ s/\.pl$//i;
         push @sn, $sn;
      }
   }
   my @r;
   my @current;
   foreach my $sn ( @sn ) {
      my $fn = "$sn.pl";
      my $iv= installed_version $sn;
      my $rv;
      foreach my $n (  @{ $d->{rconfig} } ) {
         my $sk= $n->{name};
         if ( exists $d->{rscripts}->{$sk}->{$fn} ) {
            $rv=$d->{rscripts}->{$sk}->{$fn}->{version};
            if ( ($iv cmp $rv) == -1 ) {
               push @r, "$n->{url_sc}/$fn";
            } else {
               push @current, $sn;
            }
            last;
         }
      }
   }
   print_short "Please wait..."; 
   background({ 
      cmd => \&bg_install,
      args => [ @r ],
      current => [ @current ],
      last => [ \&print_update ],
   });
}

sub print_update {
   my ( $pn ) = @_;
   my %res;
   my @r;
   my $mlen;
   foreach my $fn ( @{ $pn->{res} } ) {
      $mlen= length $fn if $mlen < length $fn;
   }
   $mlen -= 3;
   foreach my $sn ( @{ $pn->{current} } ) {
      $mlen= length $sn if $mlen < length $sn;
   }
   foreach my $fn ( @{ $pn->{res} } ) {
      my $sn= $fn;
      $sn =~ s/\.pl$//i;
      my $ov= installed_version $sn;
      Irssi::command("script load $fn");
      my $nv= installed_version $sn;
      $res{$sn}= "%yo%n %9".sprintf("%-${mlen}s",$sn)."%9 upgradet ($ov->$nv)";
   }
   foreach my $sn ( @{ $pn->{current} } ) {
      my $v= installed_version $sn;
      $res{$sn}= "%go%n %9".sprintf("%-${mlen}s",$sn)."%9 already at the latest version ($v)";
   }
   foreach my $sn (sort keys %res ) {
      push @r, $res{$sn};
   }
   print_box($IRSSI{name},"update", @r);
}

sub cmd {
   my ($args, $server, $witem)=@_;
   my @args = split /\s+/, $args;
   my $c = shift @args;
   if ($c eq 'reload') {
      cmd_reload( );
   } elsif ($c eq 'save') {
      cmd_save( );
   } elsif ($c eq 'getmeta') {
      print_short "Please wait..."; 
      background({ 
         cmd => \&getmeta,
         last => [ \&print_getmeta ],
      });
   } elsif ($c eq 'info') {
      cmd_info( @args);
   } elsif ($c eq 'search') {
      cmd_search( @args);
   } elsif ($c eq 'check') {
      cmd_check();
   } elsif ($c eq 'new') {
      cmd_new( @args );
   } elsif ($c eq 'install') {
      cmd_install( @args );
   } elsif ($c eq 'autorun') {
      cmd_autorun( @args );
   } elsif ($c eq 'update') {
      cmd_update( @args );
   } else {
      $args= $IRSSI{name};
      cmd_help( $args, $server, $witem);
   }
}

sub cmd_help {
   my ($args, $server, $witem)=@_;
   $args=~ s/\s+//g;
   if ($IRSSI{name} eq $args) {
      print_box($IRSSI{name}, "$IRSSI{name} help", $help);
      Irssi::signal_stop();
   }
}

sub sig_setup_changed {
   $path= Irssi::settings_get_str($IRSSI{name}.'_path');
   if ( $path =~ m/^[~\.]/ ) {
      $path = bsd_glob($path);
   } elsif ($path !~ m#^/# ) {
      $path= Irssi::get_irssi_dir()."/$path";
   }
   if ( !-e $path ) {
      mkdir $path;
   }

}

sub UNLOAD {
   save();
}

Irssi::theme_register([
   #'example_theme', '{hilight $0} $1 {error $2}',
   'box_header', '%R,--[%n$*%R]%n',
   #'box_inside', '%R|%n $*',
   'box_footer', '%R`--<%n$*%R>->%n',
   'short_msg', '%R>>%n $*',
]);

Irssi::signal_add('setup changed', \&sig_setup_changed);
Irssi::signal_add('pidwait', \&sig_pidwait);

Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_path', 'scriptassist2');
Irssi::settings_add_bool($IRSSI{name} ,$IRSSI{name}.'_autorun_link', 1);

Irssi::command_bind($IRSSI{name}, \&cmd);
my @cmds= qw/reload save getmeta info search check new install autorun update help/;
foreach ( @cmds ) {
   Irssi::command_bind("$IRSSI{name} $_", \&cmd);
}
Irssi::command_bind('help', \&cmd_help);

sig_setup_changed();
init();

Irssi::print "%B>>%n $IRSSI{name} $VERSION loaded: /$IRSSI{name} help for help", MSGLEVEL_CLIENTCRAP;

# vim: set ts=3 sw=3 et:
