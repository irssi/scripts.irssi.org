use Irssi;
use Irssi::Irc;
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "1.0";
%IRSSI = (
        authors         => "Maciek \'fahren\' Freudenheim, David Leadbeater",
        contact         => "fahren\@bochnia.pl",
        name            => "Server Ping",
        description     => "/SPING [server] - checks latency between current server and [server]",
        license         => "GNU GPLv2 or later",
        changed         => "Sun 15 Jun 18:56:52 BST 2014",
);

# us. /SPING [server]

use Time::HiRes qw(gettimeofday);

my %askping;

sub cmd_sping {
	my ($target, $server, $winit) = @_;

	$target = $server->{address} unless $target;
	$askping{$target} = gettimeofday();
	# using nickname rather than server seems to work better here
	$server->send_raw("PING $server->{nick} $target");
}

sub event_pong {
	my ($server, $args, $sname) = @_;
	return unless exists $askping{$sname};

	Irssi::signal_stop();
	Irssi::print(">> $sname latency: " .  sprintf("%0.3f",gettimeofday() - $askping{$sname}) . "s");
	delete $askping{$sname};
}

Irssi::signal_add("event pong", "event_pong");
Irssi::command_bind("sping", "cmd_sping");
