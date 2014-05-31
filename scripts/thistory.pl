# thistory.pl v1.05 [10.03.2002]
# Copyright (C) 2001, 2002 Teemu Hjelt <temex@iki.fi>
#
# Written for irssi 0.7.98 and later, idea from JSuvanto.
#
# Many thanks to fuchs, shasta, Paladin, Koffa and people 
# on #irssi for their help and suggestions.
#
# Keeps information about the most recent topics of the 
# channels you are on.
# Usage: /thistory [channel] and /tinfo [channel]
# 
# v1.00 - Initial release.
# v1.02 - Months and topics with formatting were shown
#         incorrectly. (Found by fuchs and shasta)
# v1.03 - event_topic was occasionally using the wrong
#         server tag. Also added few variables to ease
#         changing the settings and behaviour of this
#         script.
# v1.04 - Minor bug-fixes.
# v1.05 - Made the script more consistent with other
#         Irssi scripts.

use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI);

# Formatting character.
my $fchar = '%';

# Format of the line.
my $format = '"%topic" %nick (%address) [%mday.%mon.%year %hour:%min:%sec]';

# Amount of topics stored.
my $tamount = 10;

###### Don't edit below this unless you know what you're doing ######

$VERSION = "1.05";
%IRSSI = (
	authors     => "Teemu Hjelt",
	contact     => "temex\@iki.fi",
	name        => "topic history",
	description => "Keeps information about the most recent topics of the channels you are on.",
	license     => "GNU GPLv2 or later",
	url         => "http://www.iki.fi/temex/",
	changed     => "Sun Mar 10 14:53:59 EET 2002",
);

sub cmd_topicinfo {
	my ($channel) = @_;
	my $tag = Irssi::active_server()->{'tag'};
	$channel =~ s/\s+//;
	$channel =~ s/\s+$//;

	if ($channel eq "") {
		if (Irssi::channel_find(Irssi::active_win()->get_active_name())) {
			$channel = Irssi::active_win()->get_active_name();
		}
	}
	if ($channel ne "") {
		if ($topiclist{lc($tag)}{lc($channel)}{0}) {
			Irssi::print("%W$channel%n: " . $topiclist{lc($tag)}{lc($channel)}{0}, MSGLEVEL_CRAP);
		} else {
			Irssi::print("No topic information for %W$channel%n", MSGLEVEL_CRAP);
		}
	} else {
		Irssi::print("Usage: /tinfo <channel>");
	}
}

sub cmd_topichistory {
	my ($channel) = @_;
	my $tag = Irssi::active_server()->{'tag'};
	$channel =~ s/\s+//;
	$channel =~ s/\s+$//;

        if ($channel eq "") {
                if (Irssi::channel_find(Irssi::active_win()->get_active_name())) {
                        $channel = Irssi::active_win()->get_active_name();
                }
        }
	if ($channel ne "") {
		if ($topiclist{lc($tag)}{lc($channel)}{0}) {
			my $amount = &getamount($tag, $channel);
			Irssi::print("Topic history for %W$channel%n:", MSGLEVEL_CRAP);
			for (my $i = 0; $i < $amount; $i++) {
				if ($topiclist{lc($tag)}{lc($channel)}{$i}) {
					my $num = $i + 1;
					if (length($amount) >= length($tamount) && length($i + 1) < length($tamount)) {
						for (my $j = length($tamount); $j > length($i + 1); $j--) {
							$num = " " . $num;
						}
					}
					Irssi::print($num . ". " . $topiclist{lc($tag)}{lc($channel)}{$i}, MSGLEVEL_CRAP);
				} else {
					last;
				}
			}
		} else {
			Irssi::print("No topic history for %W$channel%n", MSGLEVEL_CRAP);
		}
	} else {
		Irssi::print("Usage: /thistory <channel>");
	}
}

sub event_topic {
	my ($server, $data, $nick, $address) = @_;
	my ($channel, $topic) = split(/ :/, $data, 2);
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
	my $tag = $server->{'tag'};
	my $output = $format;

	$topic =~ s/%/%%/g;
	$topic .= '%n';

	$val{'sec'} = $sec < 10 ? "0$sec" : $sec;
	$val{'min'} = $min < 10 ? "0$min" : $min;
	$val{'hour'} = $hour < 10 ? "0$hour" : $hour;
	$val{'mday'} = $mday < 10 ? "0$mday" : $mday;
	$val{'mon'} = $mon + 1 < 10 ? "0" . ($mon + 1) : $mon + 1;
	$val{'year'} = $year + 1900;

	$val{'nick'} = $nick;
	$val{'address'} = $address;
	$val{'channel'} = $channel;
	$val{'topic'} = $topic;
	$val{'tag'} = $tag;

	$output =~ s/$fchar(\w+)/$val{$1}/g;

        for (my $i = (&getamount($tag, $channel) - 1); $i >= 0; $i--) {
		if ($topiclist{lc($tag)}{lc($channel)}{$i}) {
			$topiclist{lc($tag)}{lc($channel)}{$i + 1} = $topiclist{lc($tag)}{lc($channel)}{$i};
		} 
        }
        $topiclist{lc($tag)}{lc($channel)}{0} = $output;
}

sub getamount {
	my ($tag, $channel) = @_;
	my $amount = 0;
	
	for (my $i = 0; $i < $tamount; $i++) {
		if ($topiclist{lc($tag)}{lc($channel)}{$i}) {
			$amount++;
		}
	}
	return $amount;
}

Irssi::command_bind("topichistory", "cmd_topichistory");
Irssi::command_bind("thistory", "cmd_topichistory");
Irssi::command_bind("topicinfo", "cmd_topicinfo");
Irssi::command_bind("tinfo", "cmd_topicinfo");
Irssi::signal_add("event topic", "event_topic");

Irssi::print("Loaded thistory.pl v$VERSION");
