#!/usr/bin/perl -w

# USAGE:
#
# /SET default_chanmode <modes>
#  - sets the desired default chanmodes
#
# Written by Jakub Jankowski <shasta@atn.pl>
# for Irssi 0.7.98.CVS
#
# please report any bugs

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "1.1";
%IRSSI = (
    authors     => 'Jakub Jankowski',
    contact     => 'shasta@atn.pl',
    name        => 'Default Chanmode',
    description => 'Allows your client to automatically set desired chanmode upon a join to an empty channel.',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.atn.pl/',
);

use Irssi 20011211.0107 ();
use Irssi::Irc;

# defaults
my $default_chanmode = "";

# str parse_mode($string)
# gets +a-e+bc-fg xyz
# returns +abc-efg xyz
sub parse_mode {
	my ($string) = @_;
	my ($modeStr, $rest) = split(/ +/, $string, 2);
	my @modeParams = split(/ +/, $rest);
	my $ptr = 0;
	my ($mode, $plusmodes, $minusmodes, $args, $finalstring);

	# processing the default_chanmode setting
	foreach my $char (split(//, $modeStr)) {
		if ($char eq "+") {
			$mode = "+";
		} elsif ($char eq "-") {
			$mode = "-";
		} else {
			if ($mode eq "+") {
				$plusmodes .= $char;
			} elsif ($mode eq "-") {
				$minusmodes .= $char;
			}
			if ($char =~ /[beIqoOdhvk]/ || ($char eq "l" && $mode eq "+")) {
				# those are modes with arguments, so increase the pointer
				$args .= " ".$modeParams[$ptr++];
			}
		}
	}

	# concatenating results
	$finalstring .= "+".$plusmodes if (length($plusmodes) > 0);
	$finalstring .= "-".$minusmodes if (length($minusmodes) > 0);
	$finalstring .= $args if (length($args) > 0);

	# debug stuff if you want
	# Irssi::print("parse_mode($string) returning '$finalstring'");

	return $finalstring;
}

# void event_channel_sync($channel)
# triggered on join
sub event_channel_sync {
	my ($channel) = @_;

	# return unless default_chanmode contains something valuable
	my $mode = parse_mode(Irssi::settings_get_str('default_chanmode'));
	return unless $mode;

	# return unless $channel is active, synced, not modeless, and we're a chanop
	return unless ($channel && $channel->{synced} && $channel->{chanop} && !$channel->{no_modes});

	# check if we're the only one visitor
	my @nicks = $channel->nicks();
	return unless (scalar(@nicks) == 1);

	# final stage: issue the MODE
	$channel->command("/MODE ".$channel->{name}." ".$mode);
}

Irssi::settings_add_str('misc', 'default_chanmode', $default_chanmode);
Irssi::signal_add_last('channel sync', 'event_channel_sync');

# changes:
#
# 25.01.2002: Initial release (v1.0)
# 24.02.2002: splitted into two subroutines, minor cleanups (v1.1)
