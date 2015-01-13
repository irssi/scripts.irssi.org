#!/usr/bin/perl

use strict;
use Irssi;

use vars qw($VERSION %IRSSI);

$VERSION = "1.999999999543675475473856-FDIV-final";
%IRSSI = (
	authors		=> 'apic',
	contact		=> 'apic@IRCnet',
	name		=> 'ignorsula',
	description	=> 'script to show ignored message in censored form',
	license		=> 'public domina', #no typo
	url		=> 'http://irssi.apic.name/ignorsula.pl',

	changed      => "2009-07-26 16:00:03"
);

Irssi::theme_register(['stopp', "\02\03" . "0,4STOPP\03\02 {msgnick \$0}"]);

sub handle_msg {
	my ($srv, $msg, $nick, $addr, $dst) = @_;
	if($srv->ignore_check($nick, $addr, $dst, $msg, MSGLEVEL_PUBLIC)) {
	        $srv->printformat($dst, MSGLEVEL_PUBLIC, "stopp", $nick);
        }
}

Irssi::signal_add_first("message public", "handle_msg");
Irssi::signal_add_first("message private", "handle_msg");
Irssi::signal_add_first("ctcp action", "handle_msg");
