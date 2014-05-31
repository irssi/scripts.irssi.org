#!/usr/bin/perl -w
#
# cp1250-kick.pl - skrypt wyrzucaj±cy z kana³u osoby u¿ywaj±ce kodowania cp1250
#                - kicks people using cp1250 charset from channel
#
# /SET cp1250_kick_reason "tekst"	- powód "kopniêcia"
# /SET cp1250_kick_ops <ON|OFF>	- czy "kopiemy" operatorów kana³u [OFF]
# /SET cp1250_nokick "#chan_name nickname ..." - lista chronionych kana³ów
#			i/lub osób, dla których skrypt nie bêdzie dzia³a³
#
# Autor: Tomasz Poradowski (batonik@irc.pl)
# Na podstawie: cp2iso.pl autorstwa Jakuba Jankowskiego <shasta@atn.pl>
#
# -----
# 28.09.2002 kilka drobnych poprawek wprowadzonych przez Jakuba Jankowskiego
#	- cp1250_kick_ops ma teraz warto¶æ boolean (ON/OFF)
# -----
# 06.05.2002 ma³a poprawka w wyszukiwaniu "nicków" na li¶cie chronionych
# -----

use Irssi;

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "1.3";
%IRSSI = (
        authors         => 'Tomasz Poradowski',
        contact         => 'batonik@irc.pl',
        name            => 'cp1250_kick',
        description     => 'Kicks people using cp1250 charset',
        license         => 'GPL',
        changed         => 'Sat Sep 28 12:58:26 CEST 2002'
);

sub cp1250_kick {
        my ($server, $data, $nick, $address) = @_;
        my ($target, $text) = split(/ :/, $data, 2);
	my $kick_reason = Irssi::settings_get_str('cp1250_kick_reason');
	my $nokick_list = Irssi::settings_get_str('cp1250_nokick');

	return unless ($target =~ /^[#\!\+]/);
        if ($text =~ /[\xA5\xB9\x8C\x9C\x8F\x9F]/) {
		my $chan = Irssi::channel_find($target);
		my $n = $chan->nick_find($nick);
		return if ($nokick_list =~ m/\Q$chan->{name}\E|\Q$n->{nick}\E/);
		return if ($n->{op} && !Irssi::settings_get_bool('cp1250_kick_ops'));
		if ($chan->{chanop})
		{
			Irssi::print("Kopiemy $nick z $target! [cp1250 kick]");
			$server->send_raw("KICK $target $nick :".$kick_reason);
		}
		else
		{
			Irssi::print("%R!%n [cp1250 kick] Nie jeste¶ operatorem kana³u $target.");
		}
	}
}

Irssi::settings_add_str('misc', 'cp1250_kick_reason', 'http://windows.online.pl wzywa Ciê! [cp1250 kick]');
Irssi::settings_add_bool('misc', 'cp1250_kick_ops', 0);
Irssi::settings_add_str('misc', 'cp1250_nokick', '');

# musi siê wywo³aæ jeszcze przed cp2iso.pl (je¶li siê go u¿ywa)
Irssi::signal_add_first('event privmsg', 'cp1250_kick');
