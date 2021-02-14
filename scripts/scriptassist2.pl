use strict;
use vars qw($VERSION %IRSSI);
use utf8;
use POSIX;
use File::Glob qw/:bsd_glob/;
use CPAN::Meta::YAML;
use File::Fetch;
use Time::Piece;
use Digest::file qw/digest_file_hex/;
use Storable qw/store_fd fd_retrieve freeze thaw/;
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
%9See also%9
  https://perldoc.perl.org/perl.html
  https://github.com/irssi/irssi/blob/master/docs/perl.txt
  https://github.com/irssi/irssi/blob/master/docs/signals.txt
  https://github.com/irssi/irssi/blob/master/docs/formats.txt
END

# config path
my $path;

# data root
my $d;
# ->{rconfig}->@
# ->{rscripts}
# ->{rstat}

my %bg_process= ();

sub background {
	my ($cmd) =@_;
	my ($fh_r, $fh_w);
	pipe $fh_r, $fh_w;
	my $pid = fork();
	if ($pid ==0 ) {
		my @res;
		@res= &{$cmd->{cmd}}(@{$cmd->{args}});
		#store_fd \@res, $fh_w;
		my $yml=CPAN::Meta::YAML->new(\@res);
		print $fh_w $yml->write_string();
		close $fh_w;
		POSIX::_exit(1);
	} else {
		$cmd->{fh_r}=$fh_r;
		$bg_process{$pid}=$cmd;
		#Irssi::pidwait_add($pid);
		my $pipetag;
        my @args = ($pid, \$pipetag );
        $pipetag = Irssi::input_add(fileno($fh_r), INPUT_READ, \&sig_pidwait, \@args);
	}
}

sub sig_pidwait {
	#my ($pid, $status) = @_;
	my ($pid, $pipetag) = @{@_[0]};
	if (exists $bg_process{$pid}) {
		#my @res= @{ fd_retrieve($bg_process{$pid}->{fh_r})};
		my $fh_r= $bg_process{$pid}->{fh_r};
		my $ystr = do { local $/; <$fh_r>; };
		close $fh_r;
    	Irssi::input_remove($$pipetag);
		my $yml = CPAN::Meta::YAML->read_string($ystr);
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

sub init {
	if ( -e "$path/cache.yml" ) {
		my $yml= CPAN::Meta::YAML->read("$path/cache.yml");
		$d= $yml->[0];
	}
		
	if (! exists $d->{rconfig} ) {
		$d->{rconfig}=();
		my %n;
		$n{name}="irssi";
		$n{type}="yaml";
		$n{url_db}="https://scripts.irssi.org/scripts.yml";
		$n{url_sc}="https://scripts.irssi.org/scripts";
		push @{$d->{rconfig}}, {%n};
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
	my $w= $ff->fetch(to => $path,);
	if ( $w ) {
		return $ff->file;
	} else {
		return undef;
	}
}

sub update {
	foreach my $n ( @{ $d->{rconfig} } ) {
		my $fn=fetch( $n->{url_db} );
		if ( defined $fn && $n->{type} eq 'yaml' ) {
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
	}
	#my $ser = freeze $d;
	#return $ser;
	return $d;
	#return "hello from uptate";
}

sub print_update {
	my ( $pn ) = @_;
	debug "func hallo";
	#debug $pn->{res};
}

sub cmd_reload {
	my ($args, $server, $witem)=@_;
	init();
}

sub cmd_save {
	my ($args, $server, $witem)=@_;
	save();
}

sub cmd_update {
	my ($args, $server, $witem)=@_;
	my $ser=update();
	debug "fine", length $ser;
}

sub cmd {
	my ($args, $server, $witem)=@_;
	if ($args =~ m/^reload/) {
		cmd_reload( $args, $server, $witem);
	} elsif ($args =~ m/^save/) {
		cmd_save( $args, $server, $witem);
	} elsif ($args eq 'update') {
		background({ 
			cmd => \&update,
			last => [ \&print_update ],
		});
	} elsif ($args =~ m/^update2/) {
		cmd_update( $args, $server, $witem);
	} else {
		$args= $IRSSI{name};
		cmd_help( $args, $server, $witem);
	}
	#if (defined $witem) {
	#	$witem->printformat(MSGLEVEL_CLIENTCRAP, 'example_theme',
	#		$path, $path, $path);
	#} else {
	#	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'example_theme',
	#		$path, $path, $path);
	#}
}

sub cmd_help {
	my ($args, $server, $witem)=@_;
	$args=~ s/\s+//g;
	if ($IRSSI{name} eq $args) {
		print_box($IRSSI{name}, "$IRSSI{name} help", $help);
		#Irssi::print($help, MSGLEVEL_CLIENTCRAP);
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
]);

Irssi::signal_add('setup changed', \&sig_setup_changed);
#Irssi::signal_add('pidwait', \&sig_pidwait);

Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_path', 'scriptassist2');

Irssi::command_bind($IRSSI{name}, \&cmd);
my @cmds= qw/reload save update help/;
foreach ( @cmds ) {
	Irssi::command_bind("$IRSSI{name} $_", \&cmd);
}
Irssi::command_bind('help', \&cmd_help);

sig_setup_changed();
init();
