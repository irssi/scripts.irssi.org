#!/usr/bin/perl

use strict;
use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI); 

$VERSION = "0.0.1";
%IRSSI = (
    authors     => 'Filippo \'godog\' Giunchedi',
    contact     => 'filippo\@esaurito.net',
    name        => 'kblamehost',
    description => 'Kicks (and bans) people with >= 4 dots in theirs hostname',
    license     => 'GNU GPLv2 or later',
    url         => 'http://esaurito.net',
);

# TODO
# add ban support

# all settings are space-separated
Irssi::settings_add_str('misc','kblamehost_channels',''); # channels with kicklamehost enabled
Irssi::settings_add_str('misc','kblamehost_exclude',''); # regexps with hostnames excluded
Irssi::settings_add_str('misc','kblamehost_dots','4'); # dots >= an host will be marked as lame
Irssi::settings_add_str('misc','kblamehost_kickmsg','Lame host detected, change it please!'); # on-kick message
Irssi::settings_add_str('misc','kblamehost_ban','0'); # should we ban that lame host?

sub event_join
{
    my ($channel, $nicksList) = @_;
    my @nicks = @{$nicksList};
    my $server = $channel->{'server'};
    my $channelName = $channel->{name};
	my $channel_enabled = 0;
	my @channels = split(/ /,Irssi::settings_get_str('kblamehost_channels'));
	my @excludes = split(/ /,Irssi::settings_get_str('kblamehost_exclude'));
	
	foreach (@channels)
	{
		$channel_enabled = 1 if($_ eq $channelName);
	}
	
	foreach (@nicks)
	{
		my $hostname = substr($_->{host},index($_->{host},'@')+1);
		my @dots = split(/\./,$hostname); # yes i know, it's the number on fields in 
										  # hostname, but array counts from 0 so element's count is number of dots
		my $is_friend = 0;
		
		foreach my $exclude (@excludes)
		{
			$is_friend = 1 if ($hostname =~ $exclude);
		}

		if( $#dots >= Irssi::settings_get_str('kblamehost_dots') && $channel_enabled == 1 && $is_friend == 0)
		{
			# Irssi::print("lamehost ($hostname) by $_->{nick} detected on $channelName, kicking...");
			$server->command("kick $channelName $_->{nick} Irssi::settings_get_str('kblamehost_kickmsg')");
			$server->command("ban $channelName $_->{nick}") if ( Irssi::settings_get_str('kblamehost_ban') );
		}
	}
}

Irssi::signal_add_last("massjoin", "event_join");
