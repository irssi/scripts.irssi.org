use strict;
use vars qw($VERSION %IRSSI);

use POSIX;
use Irssi;
use HTTP::Request::Common;
use LWP::UserAgent;
use Storable qw/store_fd fd_retrieve/;
use File::Glob qw/:bsd_glob/;

$VERSION = '0.05';
%IRSSI = (
    authors      => 'bw1',
    contact      => 'bw1@aol.at',
    name         => '0x0st',
    description  => 'upload file to https://0x0.st/',
    license      => 'ISC',
    url          => 'https://scripts.irssi.org/',
    changed      => '2021-09-28'
    modules      => 'POSIX HTTP::Request::Common LWP::UserAgent Storable File::Glob',
    commands     => '0x0st',
    selfcheckcmd => '0x0st -c',
);

my $help = << "END";
%9Name%9
  $IRSSI{name}
%9Version%9
  $VERSION
%9Syntax%9
  /0x0st [-p] [-s <URL> | -u <URL> | file ]
  /0x0st -c
%9Description%9
  $IRSSI{description}
    -p paste url to channel
    -s shorten url
    -u file from url
    -c self check
%9See also%9
  https://0x0.st/
  https://github.com/lachs0r/0x0
END

my $test_str;

my $base_uri;

my %bg_process= ();
my $self_check_timer;

sub background {
	my ($cmd) =@_;
	my ($fh_r, $fh_w);
	pipe $fh_r, $fh_w;
	my $pid = fork();
	if ($pid ==0 ) {
		my @res;
		@res= &{$cmd->{cmd}}(@{$cmd->{args}});
		store_fd \@res, $fh_w;
		close $fh_w;
		POSIX::_exit(1);
	} else {
		$cmd->{fh_r}=$fh_r;
		Irssi::pidwait_add($pid);
		$bg_process{$pid}=$cmd;
	}
}

sub sig_pidwait {
	my ($pid, $status) = @_;
	if (exists $bg_process{$pid}) {
		my @res= @{ fd_retrieve($bg_process{$pid}->{fh_r})};
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

sub upload {
	my ($filename) = @_;
	my $ua = LWP::UserAgent->new(agent=>'wget');
	my $filename = bsd_glob $filename;
	if (-e $filename) {
		my $re = $ua->request(POST $base_uri,
			Content_Type => 'form-data',
			Content =>
				{file=>[$filename]}
		);
		my $res= $re->content;
		my $code= $re->code();
		chomp $res;
		return $res, $code;
	}
}

sub url {
	my ($url) = @_;
	my $ua = LWP::UserAgent->new(agent=>'wget');
	my $re = $ua->request(POST $base_uri,
			{url=> $url}
	);
	my $res= $re->content;
	my $code= $re->code();
	chomp $res;
	return $res, $code;
}

sub shorten {
	my ($url) = @_;
	my $ua = LWP::UserAgent->new(agent=>'wget');
	my $re = $ua->request(POST $base_uri,
			{shorten=> $url}
	);
	my $res= $re->content;
	my $code= $re->code();
	chomp $res;
	return $res, $code;
}

sub past2channel {
	my ($cmd) = @_;
	my $witem = $cmd->{witem};
	if (defined $witem && (int($cmd->{res}[1] / 100) == 2)) {
		$witem->command("msg * $cmd->{res}[0]");
	} else {
		Irssi::print($cmd->{res}[0],MSGLEVEL_CLIENTCRAP);
	}
}

sub cmd {
	my ($args, $server, $witem)=@_;
	my ($opt, $arg) = Irssi::command_parse_options($IRSSI{'name'}, $args);

	if (length($args) >0 ) {
		my $cmd;
		if (exists $opt->{p}) {
			$cmd->{last}=[\&past2channel];
			$cmd->{witem}=$witem;
		}
		if (exists $opt->{u}) {
			$cmd->{cmd}=\&url;
			$cmd->{args}=[$arg];
			background( $cmd );
		} elsif (exists $opt->{s}) {
			$cmd->{cmd}=\&shorten;
			$cmd->{args}=[$arg];
			background( $cmd );
		} elsif (exists $opt->{c}) {
			$cmd->{cmd}=\&shorten;
			$cmd->{args}=['https://scripts.irssi.org/'];
			$cmd->{last}=[\&self_check];
			$self_check_timer= Irssi::timeout_add_once(2000, \&self_check, '');
			background( $cmd );
		} else {
			$cmd->{cmd}=\&upload;
			$cmd->{args}=[$arg];
			background( $cmd );
		}
	} else {
		cmd_help($IRSSI{'name'});
	}
}

sub self_check {
	my ( $arg )=@_;
	my $s='ok';
	my @res;
	if ( ref($arg) ne 'HASH' ) {
		$s = 'Error: timeout';
	} else {
		@res= @{$arg->{res}};
		Irssi::timeout_remove($self_check_timer);
		Irssi::print("0x0st: surl: $res[0] stat: $res[1]", MSGLEVEL_CLIENTCRAP);
		if ( 2 != scalar (@res ) ) {
			$s = 'Error: arg count';
		} elsif ( $res[1] != 200 ) {
			$s = "Error: HTTP status code ($res[1])";
		} elsif ( $res[0] !~ m/^http/ ) {
			$s = "Error: result ($res[0])";
		}
	}
	Irssi::print("0x0st: selfckeck $s", MSGLEVEL_CLIENTCRAP);
	my $schs_version = $Irssi::Script::selfcheckhelperscript::VERSION;
	Irssi::command("selfcheckhelperscript $s") if (defined $schs_version);
}

sub cmd_help {
	my ($args, $server, $witem)=@_;
	$args=~ s/\s+//g;
	if ($IRSSI{name} eq $args) {
		Irssi::print($help, MSGLEVEL_CLIENTCRAP);
		Irssi::signal_stop();
	}
}

sub sig_setup_changed {
	$base_uri= Irssi::settings_get_str($IRSSI{name}.'_base_uri');
}

Irssi::signal_add('setup changed', \&sig_setup_changed);
Irssi::signal_add('pidwait', \&sig_pidwait);

Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_base_uri', 'https://0x0.st/');

Irssi::command_bind($IRSSI{name}, \&cmd);
Irssi::command_bind('help', \&cmd_help);
Irssi::command_set_options($IRSSI{name},"p u s c");

sig_setup_changed();
