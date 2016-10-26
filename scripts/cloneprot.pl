use strict;
use vars qw($VERSION %IRSSI);
use Irssi;
    
$VERSION = "1.11";
%IRSSI = (
                     authors     => "Rick (strlen) Jansen",
                     contact     => "strlen\@shellz.nl",
                     name        => "cloneprot",
                     description => "Parses OperServ notices to make autokill aliases from clonewarnings",
                     license     => "GPL/1",
                     url         => "http://www.shellz.nl/",
                     changed     => "Wed Mar 13 20:26:46 CET 2002",
);

my ($lastmask, $clones, $trig, $hostmask, $username, $hostname);

sub event_callback {
	my ($server, $data, $sender, $address) = @_;
	my $count = 0;
	if ($sender eq $server->{address}) {
		if ($data =~ /from OperServ: CLONES\((\d+)\): /) {
			$clones = $1;
			$trig = $clones + 2;
			if ($data =~ /((\S+)\@(\S+))/) {
				$hostmask = $1;
				$username = $2;
				$hostname = $3;
				if ($hostmask eq $lastmask) {
					$count++;
					Irssi::print("[Warning #$count] $clones clones.");
					Irssi::print("[[/tk (1h)] - [/ak 1|2 (6h)] - [/tr ($trig)] - [/cw 1|2 (/who)]]");
				} else {
					$server->command("/who $hostname");
					Irssi::print("[Warning #1: $clones clones.");
					Irssi::print("[1: $hostmask] - [2: $hostname]");
					Irssi::print("[[/tk (1h)] - [/ak 1|2 (6h)] - [/tr ($trig)] - [/cw 1|2 (/who)]]");
					$count=1;
				}
				Irssi::signal_stop();
			}
		}
	}
}

sub cw_callback {
	my ($mode,$server) = @_;
	if ($mode == 1) {
		$server->command("/who $hostmask");
	} elsif ($mode == 2) {
		$server->command("/who $hostname");
	} else {
		Irssi::print("Usage: /cw 1|2");
	}
}

sub tk_callback {
	my ($null,$server) = @_;
	$server->command("/msg operserv tempakill $hostname Don't clone on SorceryNet.");
}

sub ak_callback {
	my ($mode,$server) = @_;
	if ($mode == 1) {
		$server->command("/msg operserv autokill 6 $hostmask Don't clone on SorceryNet.");
	} elsif ($mode == 2) {
		$server->command("/msg operserv autokill 6 *!*\@$hostname Don't clone on SorceryNet.");
	} else {
		Irssi::print("Usage: /ak 1|2");
	}
}

sub tr_callback {
	my ($mode,$server) = @_;
	if ($mode == 1) {
	$server->command("/msg operserv trigger $username\@$hostname $trig");
	} elsif ($mode == 2) {
	$server->command("/msg operserv trigger $hostname $trig");
	} else {
		Irssi::print("Usage: /tr 1|2");
	}
}

Irssi::command_bind("tk","tk_callback");
Irssi::command_bind("ak","ak_callback");
Irssi::command_bind("tr","tr_callback");
Irssi::command_bind("cw","cw_callback");

Irssi::signal_add("server event","event_callback");
