#!/usr/bin/perl
#
# by Stefan Tomanek <stefan@pico.ruhr.de>

use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "2003010201";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "anotherway",
    description => "Another auto away script",
    license     => "GPLv2",
    changed     => "$VERSION",
);
use Irssi 20020324;
use vars qw($timer @signals);

@signals = ('message own_public', 'message own_private');

sub go_away {
    #Irssi::print "%R>>%n Going away...$timer";
    Irssi::timeout_remove($timer);
    my $reason = Irssi::settings_get_str("anotherway_reason");
    my @servers = Irssi::servers();
    return unless @servers;
    Irssi::signal_remove($_ , "reset_timer") foreach (@signals);
    $servers[0]->command('AWAY '.$reason);
    Irssi::signal_add($_ , "reset_timer") foreach (@signals);
}

sub reset_timer {
    #Irssi::print "%R>>%n RESET";
    Irssi::signal_remove($_ , "reset_timer") foreach (@signals);
    foreach (Irssi::servers()) {
	$_->command('AWAY') if $_->{usermode_away};
	last;
    }
    #Irssi::signal_add('nd', "reset_timer");
    Irssi::timeout_remove($timer);
    my $timeout = Irssi::settings_get_int("anotherway_timeout");
    $timer = Irssi::timeout_add($timeout*1000, "go_away", undef);
    Irssi::signal_add($_, "reset_timer") foreach (@signals);
}

Irssi::settings_add_str($IRSSI{name}, 'anotherway_reason', 'a-nother-way');
Irssi::settings_add_int($IRSSI{name}, 'anotherway_timeout', 300);

{
    Irssi::signal_add($_, "reset_timer") foreach (@signals);
    reset_timer();
}

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded';
