##
# autorejoinpunish - 	your solution for banning people who don't
#			know what kicks are for.
# This script is for irssi 0.8.4, and was written by Paul Raade,
# laaama in IRCNet.
##
# Explanations for the settings, with defaults shown:
#
# /set autorejoinpunish_time_limit 3
# 	- The time limit in seconds for measuring what is an
#	  autorejoin, and what is not.
# /set autorejoinpunish_kickban_message Kickban for autorejoining.
# 	- Kick reason, if kickban was selected.
# /set autorejoinpunish_knockout ON
# 	- Whether kick or knockout. As default, knockout is
#	  selected, so that the bans will be removed automatically.
# /set autorejoinpunish_knockout_time 60
# 	- Time in seconds how long a ban will be kept if
#	  knockout is selected.
# /set autorejoinpunish_knockout_message Temporary ban for autorejoining.
# 	- Kick reason, if knockout was selected.
# /set autorejoinpunish_channels
# 	- Space separated list of channels on which autorejoin punishment 
#	  be used will
# /set autorejoinpunish_only_own_kicks ON
#	- If set ON, only people kicked by you will be banned.
##
# Changelog:
# - 0.2: Better way of checking channels, /set autorejoinpunish_only_own_kicks added.
# - 0.1: Initial release.
##
# Happy banning! ;)
##

use strict;
use Irssi qw(settings_get_str settings_get_int settings_get_bool
timeout_add settings_add_int settings_add_str settings_add_bool
signal_add_first command server_find_tag);

use vars qw(%IRSSI $VERSION);
$VERSION = '0.3';
%IRSSI = (
	authors		=> 'Paul \'laaama\' Raade',
	contact 	=> 'paul\@raade.org',
	name		=> 'Autorejoin punisher',
	description	=> 'Kickbans or knockouts people who use autorejoin on kick.',
	license		=> 'BSD',
	url		=> 'http://www.raade.org/~paul/irssi/scripts/',
	changes		=> 'Changed signals to be added to the top of the list to make the script work with scripts that stop the signals (autorealname, for example).',
	changed		=> 'Thu 02 May 2002, 22:04:48 EEST'
);

my %victims;
my %bans;

sub message_kick { # Set a time stamp for people who are kicked.
	#  "message kick", SERVER_REC, char *channel, char *nick, char *kicker, char *address, char *reason
	my ($server, $channel, $nick, $kicker, $address, undef) = @_;
	if ((settings_get_bool('autorejoinpunish_only_own_kicks') == 0) || (settings_get_bool('autorejoinpunish_only_own_kicks') == 1 && ($kicker eq $server->{nick}) )) {
		foreach my $item (split(' ', lc(settings_get_str('autorejoinpunish_channels')))) {
			if ((lc $channel) eq $item) { $victims{$channel}{$nick} = time(); }
		}		
	}
}

sub message_join { # Check for recent kicks, 
	# "message join", SERVER_REC, char *channel, char *nick, char *address
	my ($server, $channel, $nick, $address) = @_;
	if ($victims{$channel}{$nick} && ((time()-$victims{$channel}{$nick}) <= settings_get_int('autorejoinpunish_time_limit'))) {
		if (settings_get_bool('autorejoinpunish_knockout') == 1) {
			$server->command('mode' . ' ' . $channel . ' +b *!' . $address);
			$server->command('kick' . ' ' . $channel . ' ' . $nick . ' ' . settings_get_str('autorejoinpunish_knockout_message'));
			$bans{$server->{tag}}{time()} = $channel . '/' . $address;
		} else {
			$server->command('mode' . ' ' . $channel . ' +b *!' . $address);
			$server->command('kick' . ' ' . $channel . ' ' . $nick . ' ' . settings_get_str('autorejoinpunish_kickban_message'));
		}
	}
	delete $victims{$channel}{$nick};
}

sub clean_list {
	my ($channelkey, $nickkey);
	if (%victims) {
		foreach $channelkey (keys %victims) {
			foreach $nickkey (keys %{$victims{$channelkey}}) {
				if ((time()-$victims{$channelkey}{$nickkey}) > settings_get_int('autorejoinpunish_time_limit')) {
					delete $victims{$channelkey}{$nickkey};
				}
			}
		}
	}
}

sub check_bans {
	my ($server, $timestamp);
	if (%bans) {
		foreach $server (keys %bans) {
			foreach $timestamp (keys %{$bans{$server}}) {
				if ((time()-$timestamp) > settings_get_int('autorejoinpunish_knockout_time')) {
					my ($channel, $address) = split(/\//, $bans{$server}{$timestamp});
					server_find_tag($server)->command('mode' . ' ' . $channel . ' -b *!' . $address);
					delete $bans{$server}{$timestamp};
				}
			}
		}
	}
}


settings_add_int  ('misc', 'autorejoinpunish_time_limit', '3');
settings_add_str  ('misc', 'autorejoinpunish_kickban_message', 'Kickban for autorejoining.');
settings_add_bool ('misc', 'autorejoinpunish_knockout', '1');
settings_add_int  ('misc', 'autorejoinpunish_knockout_time', '60');
settings_add_str  ('misc', 'autorejoinpunish_knockout_message', 'Temporary ban for autorejoining.');
settings_add_str  ('misc', 'autorejoinpunish_channels', '');
settings_add_bool ('misc', 'autorejoinpunish_only_own_kicks', '1');

signal_add_first 'message join' => 'message_join';
signal_add_first 'message kick' => 'message_kick';

timeout_add ('5000', 'check_bans', '');
timeout_add ('3600000', 'clean_list', '');
# 1h = 60min * 60s * 1000ms = 3600000ms
