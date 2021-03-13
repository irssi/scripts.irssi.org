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
use JSON::PP;
use Cwd;
#use debug;

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
    selfcheckcmd=> 'scriptassist2 selfcheck',
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

# sortet rate;
my %srate;

my %cmds;

my ($fetch_system, %fetchsys);
my ($selfcheck);

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
   if ( exists $Irssi::Script::{"${scriptname}::"} ) {
      no strict 'refs';
      $r = ${ "Irssi::Script::${scriptname}::VERSION" };
   }
   return $r;
}

sub call_openurl {
   my ($url) = @_;
   # check for a loaded openurl
   if (my $code = Irssi::Script::openurl::->can('launch_url')) {
      $code->($url);
   } else {
      print_short "Please install openurl.pl";
      print_short "   or open < $url > manually";
   }
}

sub init {
   if ( $fetch_system eq '' ) {
      cmd_fetchsearch();
      $fetch_system='filefetch' if $fetch_system eq '';
   }
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
      #$n{url_rate}="https://api.github.com/repos/ailin-nemui/scripts.irssi.org/issues?state=closed";
      $n{url_rate}="https://api.github.com/repos/ailin-nemui/irssi-script-votes/issues?state=closed";
      push @{$d->{rconfig}}, {%n};
   }
   foreach my $n ( @{ $d->{rconfig} } ) {
      $source{$n->{name}}= $n;
   }
   if ( exists $d->{rrate} ) {
      sort_rate();
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
   my $fn= &{ $fetchsys{$fetch_system}->{cmd} }($uri);
   return $fn;
}

sub url2target {
   my ( $url )=@_;
   my $t= "fetch.tmp";
   if ( $url=~ m#/([^/]*\.pl)$# ) {
      $t=$1;
   }
   return $t;
}

sub fetch_filefetch {
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

sub fetch_wget {
   my ($uri)= @_;
   my $opwd= getcwd;
   my $t= url2target $uri;
   chdir $path;
   system('wget', '-q', '--no-check-certificate', '-O', $t, $uri);
   chdir $opwd;
   if ( $? ==0 ) {
      return $t;
   }
}

sub fetch_curl {
   my ($uri)= @_;
   my $opwd= getcwd;
   my $t= url2target $uri;
   chdir $path;
   system('curl', '-s', '--insecure', '-o',$t, $uri);
   chdir $opwd;
   if ( $? ==0 ) {
      return $t;
   }
}

sub fetch_fetch {
   my ($uri)= @_;
   my $opwd= getcwd;
   my $t= url2target $uri;
   chdir $path;
   system('fetch','-q', '--no-verify-peer', '--no-verify-hostname', '-o', $t, $uri);
   chdir $opwd;
   if ( $? ==0 ) {
      return $t;
   }
}

%fetchsys= (
   filefetch=> {
      cmd=> \&fetch_filefetch,
      rate=> 0,
   },
   wget=> {
      cmd=> \&fetch_wget,
      rate=> 2,
   },
   curl=> {
      cmd=> \&fetch_curl,
      rate=> 1,
   },
   fetch=> {
      cmd=> \&fetch_fetch,
      rate=> 3,
   },
);

sub cmd_fetchsearch {
   my $turl="https://irssi.org/robots.txt";
   foreach my $k ( sort { $fetchsys{$a}->{rate} <=> $fetchsys{$b}->{rate} } keys %fetchsys ) {
      print_short "test $k";
      my $fn= &{ $fetchsys{$k}->{cmd} }($turl);
      next if $fn eq '' ;
      open my $fi, "<", "$path/$fn";
      my @fs = stat $fi;
      close $fi;
      unlink "$path/$fn";
      next if $fs[7] < 7;
      print_short "set $k";
      $fetch_system=$k;
      Irssi::settings_set_str($IRSSI{name}.'_fetch_system', $k);
      last;
   }
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

sub cmd_getmeta {
   print_short "Please wait..."; 
   background({ 
      cmd => \&getmeta,
      last => [ \&print_getmeta ],
   });
}

sub print_getmeta {
   my ( $pn ) = @_;
   if ( scalar (@{$pn->{res}->[1]}) ==0 ) {
      # write back to main!
      $d->{rscripts} = $pn->{res}->[0]->{rscripts} ;
      $d->{rstat} = $pn->{res}->[0]->{rstat} ;
      foreach my $n ( @{ $d->{rconfig} } ) {
         $source{$n->{name}}= $n;
      }
      print_short "database cache updatet"; 
   }
   foreach my $s (@{$pn->{res}->[1]} ) {
      print_short $s; 
   }
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
      $sn =~ s/\.pl$//i;
      my $fn="$sn.pl";
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
            push @r, sinfo 11, "Modified", $n->{modified};
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

sub cmd_cpan {
   my ( @args )= @_;
	call_openurl('http://search.cpan.org/search?mode=module&query='.$args[0]);
}

sub cmd_contact {
   my ( @args )= @_;
   my ($sn)= @args;
   $sn =~ s/\.pl//i;
   my $fn= "$sn.pl";
   my $iv= installed_version $sn;
   my $aut;
   foreach my $sk (keys %{ $d->{rscripts}} ) {
      if ( exists $d->{rscripts}->{$sk}->{$fn} ) {
         if ( exists $d->{rscripts}->{$sk}->{$fn}->{contact} ) {
            $aut= $d->{rscripts}->{$sk}->{$fn}->{contact};
            last;
         }
      }
   }
   my @ml = $aut =~ m/([\w.]+?@[\w.]+)[\s,>\|]*/g;
   if ( scalar(@ml) > 0 ) {
      my $murl = $ml[0];
      $murl .= "?subject=$sn";
      $murl .= "_$iv" if (defined $iv);
      call_openurl $murl;
   }
}

sub fetch_gh_json {
   my ( $url ) = @_;
   my $ua = LWP::UserAgent->new(timeout => 10);
   $ua->env_proxy;
   $ua->default_header(
      'Accept' => 'application/vnd.github.squirrel-girl-preview+json',
      #'Accept'=> 'application/vnd.github.v3+json',
   );
   my $response = $ua->get($url );
   if ($response->is_success) {
      return decode_json($response->decoded_content);
   } else {
      return undef;
   }
}

sub get_rate {
   my %all;
   my @err;
   foreach my $n ( reverse  @{$d->{rconfig}} ) {
      next unless exists( $n->{url_rate} );
      my $t = fetch_gh_json $n->{url_rate} ;
      push @err, "error fetch issue list ($n->{url_rate})" unless defined $t;
      foreach my $is ( @$t ) {
         my $com = fetch_gh_json $is->{comments_url}.'?per_page=100';
         push @err, "error fetch comments ($is->{comments_url})" unless defined $com;
         foreach my $n ( @$com ) {
            my $b=$n->{body};
            $b =~ m/([\w-]+\.pl)/;
            my $fn= $1;
            my $p = $n->{reactions}->{'+1'} 
                        + $n->{reactions}->{'hooray'} 
                        + $n->{reactions}->{'rocket'} 
                        + $n->{reactions}->{'heart'} ;
            my $m = $n->{reactions}->{'-1'} 
                        + $n->{reactions}->{'confused'};
            my $sum= $p-$m;
            if ( $p >0 || $m >0) {
               $all{$fn}->{vote} += $sum;
            }
            $all{$fn}->{vote_url}= $n->{html_url};
         }
      }
   }
   return {%all}, [ @err ] ;
}

sub sort_rate {
   %srate=();
   foreach my $k ( keys %{ $d->{rrate}} ) {
      if ( exists $d->{rrate}->{$k}->{vote} ) {
         if ( ! exists $srate{ $d->{rrate}->{$k}->{vote} } ) {
            $srate{ $d->{rrate}->{$k}->{vote} }=[];
         }
         push @{$srate{ $d->{rrate}->{$k}->{vote} }}, $k;
      }
   }
}

sub cmd_getrate {
   if (!module_exist('LWP::UserAgent')) {
      print_short 'LWP::UserAgent not exists';
      return;
   }
   #use LWP::UserAgent;
   require LWP::UserAgent;
   print_short "Please wait..."; 
   background({ 
      cmd => \&get_rate,
      last => [ \&print_getrate ],
   });
}

sub print_getrate {
   my ( $pn ) = @_;
   # write back to main!
   $d->{rrate} = $pn->{res}->[0] ;
   my $err= $pn->{res}->[1];
   if (ref($err) eq "ARRAY" && scalar(@$err) >0 ) {
      foreach ( @$err) {
         print_short $_;
      }
      print_short "rate cache not updatet";
      return;
   }
   sort_rate();
   my $t=localtime();
   $d->{rrate_state}->{last}= $t->epoch;
   print_short "rate cache updatet";
}

sub cmd_rate {
   my ( @args )= @_;
   foreach my $sn ( @args ) {
      $sn =~ s/\.pl$//i;
      my $fn = "$sn.pl";
      if ( exists $d->{rrate}->{$fn} ) {
         call_openurl $d->{rrate}->{$fn}->{vote_url};
      }
   }
}

sub cmd_ratings {
   my ( @args )= @_;
   for(my $c=0; $c<=$#args; $c++) {
      if ( $args[$c] eq 'all') {
         splice @args, $c, 1;
         foreach my $sn (keys %Irssi::Script:: ) {
            $sn =~ s/:+$//;
            push @args, $sn;
         }
         last;
      }
   }
   my %ra;
   foreach my $sn ( @args ) {
      $sn =~ s/\.pl$//i;
      my $fn = "$sn.pl";
      my $vote= $d->{rrate}->{$fn}->{vote};
      $ra{$vote}=[] if !exists($ra{$vote});
      push @{$ra{$vote}}, $sn;
   }
   print_rating('ratings', 0, \%ra);
}

sub print_rating {
   my ( $tail, $maxl, $ratings )=@_;
   my @res;
   my $lmax;
   my $max=$maxl;
   foreach my $r ( sort { $b <=> $a } keys %$ratings ) {
      foreach my $sn ( sort @{ $ratings->{$r} } ) {
         $sn =~ s/\.pl$//i;
         my $fn = "$sn.pl";
         if ( exists $d->{rrate}->{$fn} ) {
            $lmax =length $sn if $lmax < length $sn;
            $max--;
            last if ( $max == 0 );
         }
      }
      last if ( $max == 0 );
   }
   foreach my $r ( sort { $b <=> $a } keys %$ratings ) {
      foreach my $sn ( sort @{ $ratings->{$r} } ) {
         $sn =~ s/\.pl$//i;
         my $fn = "$sn.pl";
         if ( exists $d->{rrate}->{$fn} ) {
            my $s;
            if ( installed_version $sn ) {
               $s="%go%n %9";
            } else {
               $s="%yo%n %9";
            }
            my $vote= $d->{rrate}->{$fn}->{vote};
            if ( $vote == 0 ) {
               $s .=sprintf("%-${lmax}s",$sn)."%9 [no votes]";
            } else {
               $s .=sprintf("%-${lmax}s",$sn)."%9 [$vote votes]";
            }
            push @res, $s;
            $maxl--;
            last if ( $maxl == 0 );
         }
      }
      last if ( $maxl == 0 );
   }
   print_box $IRSSI{name}, $tail, @res;
}

sub cmd_top {
   my ( $maxl ) = @_;
   if ( !defined $maxl || $maxl == 0 ) {
      $maxl=10;
   }
   print_rating 'top', $maxl, \%srate;
}

sub cmd_selfcheck {
   my $t=19;
   print_short "start self check ( ${t}s )";
   $selfcheck->{metalast}= $d->{rstat}->{irssi}->{last};
   $selfcheck->{metalast}=0 if !defined $selfcheck->{metalast};
   $selfcheck->{ratelast}= $d->{rrate_state}->{last};
   $selfcheck->{ratelast}=0 if !defined $selfcheck->{ratelast};
   cmd_getrate();
   cmd_getmeta();
   Irssi::timeout_add_once($t*1000, \&selfcheck, '' );
}

sub selfcheck {
   print_short "check results";
   my $s='ok';
   if (  ! defined $d->{rstat}->{irssi}->{last} ||
         $selfcheck->{metalast} == $d->{rstat}->{irssi}->{last} ) {
      $s= 'Error: fetch getmeta';
      print_short $s;
   } elsif (scalar( keys %{$d->{rscripts}->{irssi}} ) < 50 ) {
      $s= 'Error: meta result count ('.scalar( keys %{$d->{rscripts}->{irssi}} ).')';
      print_short $s;
   }
   if ( !defined $d->{rrate_state}->{last} || 
         $selfcheck->{ratelast} == $d->{rrate_state}->{last} ) {
      $s= 'Error: fetch getrate';
      print_short $s;
   } elsif ( scalar( keys %srate) <5 ){
      $s= 'Error: srate result count ('.scalar( keys %srate).')';
      print_short $s;
   }
   print_short "self check ok" if $s eq "ok";
   my $schs =  exists $Irssi::Script::{'selfcheckhelperscript::'};
   Irssi::command("selfcheckhelperscript $s") if ( $schs );
}

%cmds= (
   reload=> {
         cmd=> \&cmd_reload,
   },
   save=> {
         cmd=> \&cmd_save,
   },
   getmeta=> {
         cmd=> \&cmd_getmeta,
   },
   info=> {
         cmd=> \&cmd_info,
         meta=>1,
   },
   search=> {
         cmd=> \&cmd_search,
         meta=>1,
   },
   check=> {
         cmd=> \&cmd_check,
         meta=>1,
   },
   new=> {
         cmd=> \&cmd_new,
         meta=>1,
   },
   install=> {
         cmd=> \&cmd_install,
   },
   autorun=> {
         cmd=> \&cmd_autorun,
   },
   update=> {
         cmd=> \&cmd_update,
         meta=>1,
   },
   cpan=> {
         cmd=> \&cmd_cpan,
         meta=>1,
   },
   contact=> {
         cmd=> \&cmd_contact,
         meta=>1,
   },
   getrate=> {
         cmd=> \&cmd_getrate,
   },
   rate=> {
         cmd=> \&cmd_rate,
         rate=>1,
   },
   ratings=> {
         cmd=> \&cmd_ratings,
         rate=>1,
   },
   top=> {
         cmd=> \&cmd_top,
         rate=>1,
   },
   fetchsearch=> {
         cmd=> \&cmd_fetchsearch,
   },
   selfcheck=> {
         cmd=> \&cmd_selfcheck,
   },
);

sub cmd {
   my ($args, $server, $witem)=@_;
   my @args = split /\s+/, $args;
   my $c = shift @args;
   if ( exists $cmds{$c} ) {
      my $t=localtime();
      my $to = Irssi::settings_get_int($IRSSI{name}.'_cache_timeout');
      if (exists $cmds{$c}->{meta} ) {
         my $r;
         $r=1 if ( scalar(keys %{ $d->{rstat}})==0 );
         foreach my $hn ( keys %{ $d->{rstat} } ) {
            if ( ($d->{rstat}->{$hn}->{last}+ $to) < $t->epoch) {
               $r=1;
            }
         }
         if ( $r ) {
            print_short "Please wait..."; 
            background({ 
               cmd => \&getmeta,
               cmd_args => [$c, @args],
               last => [ \&print_getmeta, \&last_cmd ],
            });
         } else {
            &{$cmds{$c}->{cmd}}(@args);
         }
      } elsif (exists $cmds{$c}->{rate} ) {
         if ( ($d->{rrate_state}->{last}+ $to) < $t->epoch) {
            if (!module_exist('LWP::UserAgent')) {
               print_short 'LWP::UserAgent not exists';
               return;
            }
            require LWP::UserAgent;
            print_short "Please wait..."; 
            background({ 
               cmd => \&get_rate,
               cmd_args => [$c, @args],
               last => [ \&print_getrate, \&last_cmd ],
            });
         } else {
            &{$cmds{$c}->{cmd}}(@args);
         }
      } else {
         &{$cmds{$c}->{cmd}}(@args);
      }
   } elsif ( $c eq 'help' ) {
      $args= $IRSSI{name};
      cmd_help( $args, $server, $witem);
   }
}

sub last_cmd {
   my ($pn)= @_;
   my @args= @{ $pn->{cmd_args} };
   my $c = shift @args;
   if ( exists $cmds{$c} ) {
      &{$cmds{$c}->{cmd}}(@args);
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
   my $fs= Irssi::settings_get_str($IRSSI{name}.'_fetch_system');
   if ( exists $fetchsys{ $fs } ) {
      $fetch_system= $fs;
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
Irssi::settings_add_bool($IRSSI{name}, $IRSSI{name}.'_integrate', 0);
Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_fetch_system', '');
Irssi::settings_add_int($IRSSI{name}, $IRSSI{name}.'_cache_timeout', 24*60*60);

Irssi::command_bind($IRSSI{name}, \&cmd);
foreach ( 'help', keys %cmds ) {
   Irssi::command_bind("$IRSSI{name} $_", \&cmd);
}
if ( Irssi::settings_get_bool($IRSSI{name}.'_integrate')) {
   Irssi::command_bind('script', \&cmd);
   foreach ( keys %cmds ) {
      Irssi::command_bind("script $_", \&cmd);
   }
}
Irssi::command_bind('help', \&cmd_help);

sig_setup_changed();
init();

Irssi::print "%B>>%n $IRSSI{name} $VERSION loaded: /$IRSSI{name} help for help", MSGLEVEL_CLIENTCRAP;

# vim: set ts=3 sw=3 et:
