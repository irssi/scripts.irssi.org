#!/usr/bin/perl
#
# by Simon 'corecode' Schuberty <corecode@corecode.ath.cx>

use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "2003011501";
%IRSSI = (
    authors     => "Simon 'corecode' Schubert",
    contact     => "corecode\@corecode.ath.cx",
    name        => "beepaway",
    description => "Only beep when you are away",
    license     => "BSD",
    changed     => "$VERSION",
);
use Irssi 20020324;

sub catch_away {
	my $level;
	my $server;
	($server) = @_;

	if ($server->{usermode_away}) {
		$level = Irssi::settings_get_str("beep_away_msg_level")
	} else {
		$level = Irssi::settings_get_str("beep_back_msg_level")
	}
#	Irssi::print "%R>>%n setting levels ``$level''";
	$server->command("/^set beep_msg_level ".$level);
}

Irssi::settings_add_str($IRSSI{name}, "beep_away_msg_level", "MSGS NOTICES DCC DCCMSGS HILIGHT");
Irssi::settings_add_str($IRSSI{name}, "beep_back_msg_level", "NONE");

Irssi::signal_add("away mode changed", "catch_away");

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' (c) '.$IRSSI{authors}.' loaded';
