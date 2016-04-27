#!/usr/bin/perl -w
#
# recentdepart.pl
#
# irssi script
# 
# This script, when loaded into irssi, will filter quit and parted messages
# for channels listed in recdep_channels for any nick whos last message was
# more then a specified time ago.
#
# It also filters join messages showing only join messages for nicks who recently
# parted.
#
# [settings]
# recdep_channels
#     - Should contain a list of chatnet and channel  names that recentdepart
#        should monitor.  Its format is a spcae delimited list of chatnet/#channel
#        pairs.  Either chatnet or channel are optional but adding a / makes it
#        explicitly recognized as a chatnet or a channel name.  A special case is just a
#        "*" which turns it on globally.
#
#        "#irrsi #perl"                 - enables filtering on the #irssi and #perl
#                                          channels on all chatnets.
#
#        "freenode IRCNet/#irssi"       - enables filtering for all channels on frenode
#                                          and only the #irssi channel on IRCNet.
#
#        "freenode/"                    - force "freenode" to be interpreted as the chatnet
#                                          name by adding a / to the end.
#
#        "/freenode"                    - forces "freenode" to be interpreted as the channel
#                                          by prefixing it with the / delimiter.
#
#         "*"                           - globally enables filtering.
#
# recdep_period
#     - specifies the window of time, after a nick last spoke, for which quit/part
#        notices will be let through the filter. 
#
# recdep_rejoin
#     - specifies a time period durring which a join notice for someone rejoining will
#        be shown.  Join messages are filtered if the nicks part/quit message was filtered
#        or if the nick is gone longer then the rejoin period.
#        Set to 0 to turn off filtering of join notices.
#
# recdep_nickperiod
#     - specifies a window of time like recdep_period that is used to filter nick change
#        notices. Set to 0 to turn off filtering of nick changes.
#
# recdep_use_hideshow
#     - whether to use hideshow script instead of ignoring
#

use strict;
use warnings;
use Irssi;
use Irssi::Irc;

our $VERSION = "0.7";
our %IRSSI = (
    authors     => 'Matthew Sytsma',
    contact     => 'spiderpigy@yahoo.com',
    name        => 'Recently Departed',
    description => 'Filters quit/part/join/nick notices based on time since last message. (Similar to weechat\'s smartfilter).',
    license     => 'GNU GPLv2 or later',
    url         => '',
);

# store a hash of configure selected servers/channels
my %chanlist;
# Track recent times by server/nick/channel
# (it is more optimal to go nick/channel then channel/nick because some quit signals are by server not by channel.
#  We will only have to loop through open channels that a nick has spoken in which should be less then looping
#  through all the monitored channels looking for the nick.
my %nickhash=();
# Track recent times for parted nicks by server/channel/nick
my %joinwatch=();
my $use_hide;

sub on_setup_changed {
    my %old_chanlist = %chanlist;
    %chanlist = ();
    my @pairs = split(/ /, Irssi::settings_get_str("recdep_channels"));

    $use_hide = Irssi::settings_get_bool("recdep_use_hideshow");
    foreach (@pairs)
    {
        my ($net, $chan, $more) = split(/\//);
        if ($more)
        {
            /\/(.+)/;
            $chan = $1;
        }
#        Irssi::active_win()->print("Initial Net: $net  Chan: $chan");
        if (!$net)
        {
            $net = '*';
        }

        if ($net =~ /^[#!@&]/ && !$chan)
        {
            $chan = $net;
            $net = "*";
        }

        if (!$chan)
        {
            $chan = "*";
        }

        $chanlist{$net}{$chan} = 1;
    }

    # empty the storage in case theres a channel or server we are no longer filtering
    %nickhash=();
    %joinwatch=();
}

sub check_channel
{
    my ($server, $channel) = @_;

    # quits dont have a channel so we need to see if this server possibly contains this channel
    if (!$channel || $channel eq '*')
    {
        # see if any non chatnet channel listings are open on this server
        if (keys %{ $chanlist{'*'} })
        {
            foreach my $chan (keys %{ $chanlist{'*'} })
            {
                if ($chan eq '*' || $server->channel_find($chan))
                {
                    return 1;
                }
            }
        }

        #  see if there were any channels listed for this chatnet
        if (keys %{ $chanlist{$server->{'chatnet'}} })
        {    return 1;    }
        else
        {    return 0;    }
    }

    # check for global channel matches and pair matches
    return (($chanlist{'*'}{'*'}) ||
            ($chanlist{'*'}{$channel}) ||
            ($chanlist{$server->{'chatnet'}}{'*'}) ||
            ($chanlist{$server->{'chatnet'}}{$channel}));
}

# Hook for quitting
sub on_quit
{
	my ($server, $nick, $address, $reason) = @_;

        if ($server->{'nick'} eq $nick)
        {  return;   }

	if (check_channel($server, '*'))
        {
            my $recent = 0;
            foreach my $chan (keys %{ $nickhash{$server->{'tag'}}{lc($nick)} })
            {
                 if (time() - $nickhash{$server->{'tag'}}{lc($nick)}{$chan} < Irssi::settings_get_int("recdep_period"))
                 {
                     $recent = 1;

                     if (Irssi::settings_get_int("recdep_rejoin") > 0)
                     {
                         $joinwatch{$server->{'tag'}}{$chan}{lc($nick)} = time();
                     }
                 }
            }

            delete $nickhash{$server->{'tag'}}{lc($nick)};

            if (!$recent)
            {
                $use_hide ? $Irssi::scripts::hideshow::hide_next = 1
		    : Irssi::signal_stop();
            }
	}
}

# Hook for parting
sub on_part 
{
	my ($server, $channel, $nick, $address, $reason) = @_;

        # cleanup if its you who left a channel
        if ($server->{'nick'} eq $nick)
        {
            # slightly painfull cleanup but we shouldn't hit this as often
            foreach my $nickd (keys %{ $nickhash{$server->{'tag'}} })
            {
                delete $nickhash{$server->{'tag'}}{$nickd}{$channel};
                if (!keys(%{ $nickhash{$server->{'tag'}}{$nickd} }))
                {
                    delete $nickhash{$server->{'tag'}}{$nickd};
                }
            }
            delete $joinwatch{$server->{'tag'}}{$channel};
        }
	elsif (check_channel($server, $channel))
        {
            if (!defined $nickhash{$server->{'tag'}}{lc($nick)}{$channel} || time() - $nickhash{$server->{'tag'}}{lc($nick)}{$channel} > Irssi::settings_get_int("recdep_period"))
            {
                $use_hide ? $Irssi::scripts::hideshow::hide_next = 1
		    : Irssi::signal_stop();
            }
            elsif (Irssi::settings_get_int("recdep_rejoin") > 0)
            {
                $joinwatch{$server->{'tag'}}{$channel}{lc($nick)} = time();
            }

            delete $nickhash{$server->{'tag'}}{lc($nick)}{$channel};
            if (!keys(%{ $nickhash{$server->{'tag'}}{lc($nick)} }))
            {
                delete $nickhash{$server->{'tag'}}{lc($nick)};
            }
	}
}

# Hook for public messages.
sub on_public
{
	my ($server, $msg, $nick, $addr, $target) = @_;

        if (!$target) { return; }
        if ($nick =~ /^#/) { return; }

        if ($server->{'nick'} eq $nick) { return; }

	if (check_channel($server, $target))
        {
            $nickhash{$server->{'tag'}}{lc($nick)}{$target} = time();
	}
}

# Hook for people joining
sub on_join 
{
	my ($server, $channel, $nick, $address) = @_;

        if ($server->{'nick'} eq $nick)
        {  return;   }

        if (Irssi::settings_get_int("recdep_rejoin") == 0)
        {   return;  }

	if (check_channel($server, $channel))
        {
            if (!defined $joinwatch{$server->{'tag'}}{$channel}{lc($nick)} || time() - $joinwatch{$server->{'tag'}}{$channel}{lc($nick)} > Irssi::settings_get_int("recdep_rejoin"))
            {
                $use_hide ? $Irssi::scripts::hideshow::hide_next = 1
		    : Irssi::signal_stop();
            }
	}

        # loop through and delete all old nicks from the rejoin hash
        # this should be a small loop because it will only inlude nicks who recently left channel and who
        # passed the part message filter
        foreach my $nickd (keys %{ $joinwatch{$server->{'tag'}}{$channel} })
        {
           if (time() - $joinwatch{$server->{'tag'}}{$channel}{lc($nickd)} < Irssi::settings_get_int("recdep_rejoin"))
           {   next;   }

           delete $joinwatch{$server->{'tag'}}{$channel}{lc($nickd)};
        }
        if (!keys(%{ $joinwatch{$server->{'tag'}}{$channel} }))
        {
            delete $joinwatch{$server->{'tag'}}{$channel};
        }
}

# Hook for nick changes
sub on_nick 
{
        my ($server, $new, $old, $address) = @_;

        if ($server->{'nick'} eq $old || $server->{'nick'} eq $new)
        {  return;   }
   
        if (check_channel($server, '*'))
        {
            my $recent = 0;
            foreach my $chan (keys %{ $nickhash{$server->{'tag'}}{lc($old)} })
            {
                 if (time() - $nickhash{$server->{'tag'}}{lc($old)}{$chan} < Irssi::settings_get_int("recdep_nickperiod"))
                 {
                     $recent = 1;
                 }
            }

            if (!$recent && Irssi::settings_get_int("recdep_nickperiod") > 0)
            {
                $use_hide ? $Irssi::scripts::hideshow::hide_next = 1
		    : Irssi::signal_stop();
            }

           delete $nickhash{$server->{'tag'}}{lc($old)}; 
        }
}


# Hook for cleanup on server quit
sub on_serverquit
{
        my ($server, $msg) = @_;

        delete $nickhash{$server->{'tag'}};
        delete $joinwatch{$server->{'tag'}};
}

# Setup hooks on events
Irssi::signal_add_last("message public", "on_public");
Irssi::signal_add_last("message part", "on_part");
Irssi::signal_add_last("message quit", "on_quit");
Irssi::signal_add_last("message nick", "on_nick");
Irssi::signal_add_last("message join", "on_join");
Irssi::signal_add_last("server disconnected", "on_serverquit");
Irssi::signal_add_last("server quit", "on_serverquit");
Irssi::signal_add('setup changed', "on_setup_changed");

# Add settings
Irssi::settings_add_str("recdentpepart", "recdep_channels", '*');
Irssi::settings_add_int("recdentpepart", "recdep_period", 600);
Irssi::settings_add_int("recdentpepart", "recdep_rejoin", 120);
Irssi::settings_add_int("recdentpepart", "recdep_nickperiod", 600);
Irssi::settings_add_bool("recdentpepart", "recdep_use_hideshow", 0);
on_setup_changed();
