#!/usr/bin/perl
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "0.0.1";
%IRSSI = (
    authors     => "Christian 'mordeth' Weber",
    contact     => "chris\@mac.ruhr.de",
    name        => "autoversion",
    description => "Auto-CTCP Verison on every joining nick",
    license     => "GPLv2",
    url         => "",
    changed     => "20020821",
    modules     => ""
);

sub event_message_join ($$$$) {
    my ($server, $channel, $nick, $address) = @_;
    if (lc($channel) eq lc(Irssi::active_win()->{active}->{name})) {
    	$server->command("ctcp $nick VERSION");
    };
}				

Irssi::signal_add('message join', 'event_message_join');

