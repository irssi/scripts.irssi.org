#!/usr/bin/perl -w

# /VSAY <text>
#  - same as /say, but removes vowels from text
#
# /VME <text>
#  - same as /me, but removes vowels from text
#
# /VTOPIC <text>
#  - same as /topic, but removes vowels from text :)

# Written by Jakub Jankowski <shasta@atn.pl>
# for Irssi 0.7.98.4+

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
    authors     => 'Jakub Jankowski',
    contact     => 'shasta@atn.pl',
    name        => 'vowels',
    description => 'Silly script, removes vowels, idea taken from #linuxnews ;-)',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.atn.pl/',
);

use Irssi;
use Irssi::Irc;

# str remove_vowels($string)
# returns random-coloured string
sub remove_vowels {
	my ($string) = @_;
	$string =~ s/[eyuioa]//gi;
	return $string;
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
		$dest->command("/msg " . $dest->{name} . " " . remove_vowels($text));
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

	return unless $dest;
	if ($dest->{type} eq "CHANNEL" || $dest->{type} eq "QUERY") {
		$dest->command("/me " . remove_vowels($text));
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

	return unless $dest;
	if ($dest->{type} eq "CHANNEL") {
		$dest->command("/topic " . remove_vowels($text));
	}
}

Irssi::command_bind("vsay", "rsay");
Irssi::command_bind("vtopic", "rtopic");
Irssi::command_bind("vme", "rme");

# changes:
#
# 07.02.2002: Initial release (v1.0)
