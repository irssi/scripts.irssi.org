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
    authors	=> 'bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'scriptassist2',
    description	=> 'This script really does nothing. Sorry.',
    license	=> 'lgpl',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2021-02-13',
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
#  /scriptassist check
#  /scriptassist update <script|all>
#  		update != upgrade
#  /scriptassist new <num>
#  /scriptassist contact <script>
#  /scriptassist cpan <module>
#  /scriptassist install <script>
#  /scriptassist autorun <script>
#
#  /scriptassist rate <script>
#  /scriptassist ratings <scripts|all>
#  /scriptassist top <num>

# config path
my $path;

# data root
my $d;
# ->{rconfig}->@
# ->{rscripts}->%
# ->{rstat}->%

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
	debug "sig_pipe $pid";
	if (exists $bg_process{$pid}) {
		my $fh_r= $bg_process{$pid}->{fh_r};
		$bg_process{$pid}->{res_str} .= do { local $/; <$fh_r>; };
		Irssi::input_remove($$pipetag);
	}
}

sub sig_pidwait {
	my ($pid, $status) = @_;
	debug "sig_pidwait $pid";
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
}

sub save {
	my $yml= CPAN::Meta::YAML->new( $d );
	$yml->write("$path/cache.yml");
}

sub fetch {
	my ($uri)= @_;
	my $ff = File::Fetch->new (
		uri => $uri,
	);
	my $w;
	eval { $w = $ff->fetch(to => $path,); };
	if ( $w ) {
		return $ff->file;
	} else {
		return undef;
	}
}

sub update {
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

sub print_update {
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
	my ($args, $server, $witem)=@_;
	init();
	print_short "reloadet"; 
}

sub cmd_save {
	my ($args, $server, $witem)=@_;
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

sub installed_version {
	my ( $scriptname )= @_;
	my $r;
	no strict 'refs';
	#debug keys (%Irssi::Script::);
	$r = ${ "Irssi::Script::${scriptname}::VERSION" };
	return $r;
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
	my ($args, $server, $witem, @args)=@_;
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
	my ($args, $server, $witem, @args)=@_;
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

sub cmd {
	my ($args, $server, $witem)=@_;
	my @args = split /\s+/, $args;
	my $c = shift @args;
	if ($c eq 'reload') {
		cmd_reload( $args, $server, $witem);
	} elsif ($c eq 'save') {
		cmd_save( $args, $server, $witem);
	} elsif ($c eq 'update') {
		print_short "Please wait..."; 
		background({ 
			cmd => \&update,
			last => [ \&print_update ],
		});
	} elsif ($c eq 'info') {
		cmd_info( $args, $server, $witem, @args);
	} elsif ($c eq 'search') {
		cmd_search( $args, $server, $witem, @args);
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

Irssi::command_bind($IRSSI{name}, \&cmd);
my @cmds= qw/reload save update info help/;
foreach ( @cmds ) {
	Irssi::command_bind("$IRSSI{name} $_", \&cmd);
}
Irssi::command_bind('help', \&cmd_help);

sig_setup_changed();
init();

Irssi::print "%B>>%n $IRSSI{name} $VERSION loaded: /$IRSSI{name} help for help", MSGLEVEL_CLIENTCRAP;
