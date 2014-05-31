use Irssi;
use Irssi::Irc;
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "0.9";
%IRSSI = (
        authors         => "Maciek \'fahren\' Freudenheim",
        contact         => "fahren\@bochnia.pl",
        name            => "Server Ping",
        description     => "/SPING [server] - checks latency between current server and [server]",
        license         => "GNU GPLv2 or later",
        changed         => "Fri Mar 15 15:09:42 CET 2002"
);

my %askping;

sub cmd_sping {
	my ($target, $server, $winit) = @_;
	
	$target = $server->{address} unless $target;
	$askping{$target} = time();
	$server->send_raw("PING $server->{address} $target");	
}

sub event_pong {
	my ($server, $args, $sname) = @_;
	
	Irssi::signal_stop() if ($askping{$sname});

	Irssi::print(">> $sname latency: " . (time() - $askping{$sname}) . "s");
	undef $askping{$sname};
}

Irssi::signal_add("event pong", "event_pong");
Irssi::command_bind("sping", "cmd_sping");
