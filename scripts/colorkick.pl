#!/usr/pkg/bin/perl
#
# script what's kicking users for using color or blink
#
# settings:
#  what			type	function
#  colorkick_channels	str	list of channels have to be ``protected''
#  colorkick_color	int	0: don't kick on color
#  colorkick_blink	int	0: don't kick on blink
#

use strict;
use Irssi;
use Irssi::Irc;

use vars %IRSSI;
%IRSSI =
(
	authors		=> "Gabor Nyeki",
	contact		=> "bigmac\@vim.hu",
	name		=> "colorkick",
	description	=> "kicking users for using colors or blinks",
	license		=> "public domain",
	written		=> "Thu Dec 26 00:22:54 CET 2002",
	changed		=> "Fri Jan  2 03:43:10 CET 2004"
);

sub catch_junk
{
	my ($server, $data, $nick, $address) = @_;
	my ($target, $text) = split(/ :/, $data, 2);
	my $valid_channel = 0;

	if ($target[0] != '#' && $target[0] != '!' && $target[0] != '&')
	{
		return;
	}

	for my $channel (split(/ /,
		Irssi::settings_get_str('colorkick_channels')))
	{
		if ($target == $channel)
		{
			$valid_channel = 1;
			last;
		}
	}
	if ($valid_channel == 0)
	{
		return;
	}

	if ($text =~ /\x3/ &&
		Irssi::settings_get_bool('colorkick_color'))
	{
		$server->send_raw("KICK $target $nick :color abuse");
	}
	elsif ($text =~ /\x6/ &&
		Irssi::settings_get_bool('colorkick_blink'))
	{
		$server->send_raw("KICK $target $nick :blink abuse");
	}
}

Irssi::settings_add_str('colorkick', 'colorkick_channels', '');
Irssi::settings_add_bool('colorkick', 'colorkick_color', 1);
Irssi::settings_add_bool('colorkick', 'colorkick_blink', 1);
Irssi::signal_add("event privmsg", "catch_junk");
