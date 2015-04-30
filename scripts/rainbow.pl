#!/usr/bin/perl -w

# USAGE:
#
# /RSAY <text>
#  - same as /say, but outputs a coloured text
#
# /RME <text>
#  - same as /me, but outputs a coloured text
#
# /RTOPIC <text>
#  - same as /topic, but outputs a coloured text :)
#
# /RKICK <nick> [reason]
#  - kicks nick from the current channel with coloured reason
#
# /RKNOCKOUT [time] <nicks> [reason]
#  - knockouts nicks from the current channel with coloured reason for time

# Written by Jakub Jankowski <shasta@atn.pl>
# for Irssi 0.7.98.4 and newer

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "1.6";
%IRSSI = (
    authors     => 'Jakub Jankowski',
    contact     => 'shasta@atn.pl',
    name        => 'rainbow',
    description => 'Prints colored text. Rather simple than sophisticated.',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.atn.pl/',
);

use Irssi;
use Irssi::Irc;
use Encode;

# colors list
#  0 == white
#  4 == light red
#  8 == yellow
#  9 == light green
# 11 == light cyan
# 12 == light blue
# 13 == light magenta
my @colors = ('0', '4', '8', '9', '11', '12', '13');

# str make_colors($string)
# returns random-coloured string
sub make_colors {
	my ($string) = @_;
	Encode::_utf8_on($string);
	my $newstr = "";
	my $last = 255;
	my $color = 0;

	for (my $c = 0; $c < length($string); $c++) {
		my $char = substr($string, $c, 1);
		if ($char eq ' ') {
			$newstr .= $char;
			next;
		}
		while (($color = int(rand(scalar(@colors)))) == $last) {};
		$last = $color;
		$newstr .= "\003";
		$newstr .= sprintf("%02d", $colors[$color]);
		$newstr .= (($char eq ",") ? ",," : $char);
	}

	return $newstr;
}

# void rsay($text, $server, $destination)
# handles /rsay
sub rsay {
	my ($text, $server, $dest) = @_;

	if (!$server || !$server->{connected}) {
		Irssi::print("Not connected to server");
		return;
	}

	return unless $dest;

	if ($dest->{type} eq "CHANNEL" || $dest->{type} eq "QUERY") {
		$dest->command("/msg " . $dest->{name} . " " . make_colors($text));
	}
}

# void rme($text, $server, $destination)
# handles /rme
sub rme {
	my ($text, $server, $dest) = @_;

	if (!$server || !$server->{connected}) {
		Irssi::print("Not connected to server");
		return;
	}

	if ($dest && ($dest->{type} eq "CHANNEL" || $dest->{type} eq "QUERY")) {
		$dest->command("/me " . make_colors($text));
	}
}

# void rtopic($text, $server, $destination)
# handles /rtopic
sub rtopic {
	my ($text, $server, $dest) = @_;

	if (!$server || !$server->{connected}) {
		Irssi::print("Not connected to server");
		return;
	}

	if ($dest && $dest->{type} eq "CHANNEL") {
		$dest->command("/topic " . make_colors($text));
	}
}

# void rkick($text, $server, $destination)
# handles /rkick
sub rkick {
	my ($text, $server, $dest) = @_;

	if (!$server || !$server->{connected}) {
		Irssi::print("Not connected to server");
		return;
	}

	if ($dest && $dest->{type} eq "CHANNEL") {
		my ($nick, $reason) = split(/ +/, $text, 2);
		return unless $nick;
		$reason = "Irssi power!" if ($reason =~ /^[\ ]*$/);
		$dest->command("/kick " . $nick . " " . make_colors($reason));
	}
}

# void rknockout($text, $server, $destination)
# handles /rknockout
sub rknockout {
    my ($text, $server, $dest) = @_;

    if (!$server || !$server->{connected}) {
        Irssi::print("Not connected to server");
        return;
    }

    if ($dest && $dest->{type} eq "CHANNEL") {
        my ($time, $nick, $reason) = split(/ +/, $text, 3);
        ($time, $nick, $reason) = (300, $time, $nick . " " . $reason) if ($time !~ m/^\d+$/);
        return unless $nick;
        $reason = "See you in " . $time . " seconds!" if ($reason =~ /^[\ ]*$/);
        $dest->command("/knockout " . $time . " " . $nick . " " . make_colors($reason));
    }
}

Irssi::command_bind("rsay", "rsay");
Irssi::command_bind("rtopic", "rtopic");
Irssi::command_bind("rme", "rme");
Irssi::command_bind("rkick", "rkick");
Irssi::command_bind("rknockout", "rknockout");

# changes:
#
# 25.01.2002: Initial release (v1.0)
# 26.01.2002: /rtopic added (v1.1)
# 29.01.2002: /rsay works with dcc chats now (v1.2)
# 02.02.2002: make_colors() doesn't assign any color to spaces (v1.3)
# 23.02.2002: /rkick added
# 26.11.2014: utf-8 support
# 01.12.2014: /rknockout added (v1.6)
