###############################################################################
#
# Shows WHOIS: info including realname and channel names on joins to 
# channels.
# 
# This script is based on the autorealname script, and shares a little
# code and many ideas with that script. I use the same globals as they do,
# but with totally different fields because their structure was not really
# easy to adapt to a situation where more info is used on one query.
#
# Rewrote all that code, except for parts of request_whois and some init code
#
# I would like to thank Timo 'cras' Sirainen and Bastian Blank for writing
# the autorealname script. It was a good example.
#
# The script contains very simple flood protection in the form that it will
# not allow for more then $max_queued_requests per server at one time to be
# running. It tries to be smart about netsplits, so this should be okay.
# We have a 5-second timeout to make sure we really don't flood, ans also to
# make sure that we don't wait indefinitely for answers that won't come.
#
# Themes:
#   You can change the way the WHOIS messages look using the /format command,
#   For example:
#   /FORMAT ji_whois_success %GWHOIS:%n {channick_hilight $0} \
#           is "{hilight $1}"%n on {channel $2} 
#
#   Will add a green WHOIS: to the line to make it stand out, save your
#   formatting in irssi using '/SAVE -formats'
#
#   Add 'server: "{hilight $3}"' to the format string to also print the
#   server name (Thanks to Svein Skogen for suggesting this)
#
#   Add 'flags: "{hilight $4}"' to the format string to also print 
#   some additional flags for the user. These flags are tailored for
#   some unknown irc network but also work quite well on IRCNet and EFNet
#   after the 'idle' modifications I added to them. Thanks to
#   Francesco Rolando for providing me with the initial patch.
#
# Commands (/JOININFO ...)
#   INFO  -  Show info on and contents of the current cache of this script
#   GC    -  Manually run the garbage collector once
#   FORCE -  Fake join of a nick to a chan (/JOININFO FORCE ichiban) use with
#            care. Useful for testing theme changes, timeouts and the garbage
#            collector on a quiet day or network. Will ignore your own nick.
#   HELP  -  Shows help
# 
# Settings
#   /SET whois_expire_time       # time to expire one saves record
#                                # until this age has been reched no
#                                # new WHOISs will be put on the server
#
#   /SET whois_max_requests      # max concurrent requests per server
#                                # flood protection, keep low
#
#   /SET whois_timeout_ms        # timeout after which a whois is lost (ms)
#                                # (default: 5000)
#
#   /SET whois_gc_interval_ms    # run gc ever x MS (default: 300000)
#                                # Requires script reload when changed.
#
#   /SET whois_debug             # 0 = show no debug info, 1 = debug info
#
#   /SET whois_printing_level    # Level at which all non-debug output is
#                                # printed, influences logging and IGNORE
#                                # (default: JOINS)
#
# ChangeLog:
# - Tue Jul 15 2003, pbijdens
#   Initial release version 0.5.1
# - Thu Jul 17 2003, pbijdens
#   Version 0.5.2
#   Added garbage collection for the stored info.
#   Added /AWINFO and /AWGC commands to show info and to run the garbage
#   collector manually respectively
#   Added timeout for the putserv WHOIS making sure we do not record too many
#   jobs as BUSY.
# - Thu Jul 17 2003, pbijdens
#   Version 0.5.3
#   Added settings (whois_...) to the irssi config so there is no need to
#   modify the script when changing them
# - Thu Jul 17 2003, pbijdens
#   Version 0.5.5
#   Making sure the settings are reloaded when they are changed. Added a
#   signal handler for that
# - Thu Jul 17 2003, pbijdens
#   Version 0.6.0
#   Added setting for whois_debug
#   Added theme support
#   Bugfix for servers sending 401 without 318 no need to wait for
#   timeout anymore on those
#   Added configurable printing level for the realname+channel messages.
#   use /SET whois_printing_level
#   Added /AWFORCE command (see above)
# - Mon Jul 28 2003, pbijdens
#   Version 0.6.1
#   Various updates and bug fixes
#   Changed awforce command to strip spaces
# - Wed Aug 13 2003, pbijdens
#   Version 0.7.0
#   Fixed typo in comment line
#   Changed /AW* commands to be /JOININFO <subcommand> and added a
#   /JOININFO HELP command. Renamed some subs to make their purpose
#   more clear.
# - Wed Feb 2 2004, pbijdens
#   Added features for filtering channels from the list, and adding
#   support for hilighting channels in colors.
# - Mon Mar 8 2004, pbijdens
#   Fixed bug where also on SILCNET the WHOIS queries would be run, now
#   this service is restricted to IRC networks. Thanks to Tony den Haan
#   for supplying this patch.
# - Mon Mar 8 2004, pbijdens
#   Added support for printing the servername also in the output for those
#   who want to see it. Thanks to Svein Skogen for suggesting this and
#   sending me a patch.
#   NOTE: Requires you to add {hilight $3} to your format string manually.
#   By default the information is not diplayed.
# - Mon Mar 8 2004, pbijdens
#   Added support for additional flags to the WHOIS output. This is stuff
#   like IrcOP, Away, Idle and more. Thanks to Francesco Rolando for
#   providing the additional patch, which I modified.
#   NOTE: Requires you to add {hilight $4} to your format string manually.
#   By default the information is not diplayed.
# - Tue Mar 1 2005, pbijdens
#   Updated the script for compliance with a wider range of servers,
#   and removed some functionality that generally did not work, or break
#   on some servers. Been runing on 4 networks now with these patches for
#   many months, declaring stable and releasing 1.0.
#
################################################################################

use Irssi 20011207;
use strict;
use vars qw($VERSION %IRSSI); 
use integer;

################################################################################

$VERSION = "1.0.0";
%IRSSI = (
    authors => "Pieter-Bas IJdens",
    contact => "irssi-scripts\@nospam.mi4.org.uk",
    name    => "joininfo",
    description => "Reports WHOIS information and channel list for those who join a channel",
    license => "GPLv2 or later",
    url     => "http://pieter-bas.ijdens.com/irssi/",
    changed => "2005-03-10"
);

################################################################################

# Note that all settings below can and should be changed with /SET, see
# /joininfo help or /set whois

# The maximum acceeptable age for a cached whois record is 60 seconds
# after this amount of time the cache record is discareded
my $whois_maxage = 60;

# The maximum number of requests queued at a time, if the queue reaches
# a lrger size, ignore new requets until we have space left. This could
# happen in a netjoin preceded by a very long netsplit 
my $max_queued_requests = 7;

# Timeout after which a whois request is assumed not having been answered
# by the server. In milliseconds
my $whois_timeout = 5000;

# Interval for the times at which GC takes place automatically. In milliseconds
my $whois_gc_interval = 300000;

# Debug poutput on or off
my $whois_debug = 0;

# Output level (the whois_printing_level_n is the numeric information for the
# output level)
my $whois_printing_level = "JOINS";
my $whois_printing_level_n;

################################################################################

# Cached records per server, plus information about the amount of queued
# reuests
my %servers;

################################################################################

# Registers the theme messages with irssi so they can be changed later by the
# user using the /FORMAT command
sub register_messages
{
    Irssi::theme_register([
        'ji_whois_success',
            '{channick_hilight $0} is "{hilight $1}"%n on {channel $2}',
        'ji_whois_list_header',
            'Server: {hilight $0} ($1 pending)', 
        'ji_whois_list_nick',
            '{channick_hilight $0} is "{hilight $1}"%n on {channel $2}', 
        'ji_whois_list_status',
            'Status: $0; Record age: $1s; Server tag: $2'
    ]);
}

################################################################################

# Register the settings we use, and specify a DEFAULT for when Irssi
# did not have them saved yet. Allows users to use /SET later.
sub register_settings
{
    Irssi::settings_add_int(
        "joininfo",
        "whois_expire_time",
        $whois_maxage
    );
    Irssi::settings_add_int(
        "joininfo",
        "whois_max_requests",
        $max_queued_requests
    );
    Irssi::settings_add_int(
        "joininfo",
        "whois_timeout_ms",
        $whois_timeout
    );
    Irssi::settings_add_int(
        "joininfo",
        "whois_gc_interval_ms",
        $whois_gc_interval
    );
    Irssi::settings_add_int(
        "joininfo",
        "whois_debug",
        $whois_debug
    );
    Irssi::settings_add_str(
        "joininfo",
        "whois_printing_level",
        $whois_printing_level
    );
}

################################################################################

# Now (re-)read the settings, those saved in the config will be returned,
# unless not present in which case the default will be returned
# This function is called once on script start, and later is run as an
# event handler when irssi notifies us of a change in settings.
sub load_settings
{
    $whois_maxage = Irssi::settings_get_int("whois_expire_time");
    $max_queued_requests = Irssi::settings_get_int("whois_max_requests");
    $whois_timeout = Irssi::settings_get_int("whois_timeout_ms");
    $whois_gc_interval = Irssi::settings_get_int("whois_gc_interval_ms");
    $whois_debug = Irssi::settings_get_int("whois_debug");
    $whois_printing_level = Irssi::settings_get_str("whois_printing_level");

    $whois_printing_level = uc($whois_printing_level);
    $whois_printing_level =~ s/[^A-Z]//gi;

    my($definedlvl);
    eval("\$definedlvl = defined(MSGLEVEL_" . $whois_printing_level. ");");

    if (!$definedlvl)
    {
        Irssi::print(
            "%RJOININFO:%n illegal /set whois_printing_level, see /help levels".
            " for more informations. Assuming JOINS in stead of ".
            "\"$whois_printing_level\"."
        );
        $whois_printing_level = "JOINS";
        $whois_printing_level_n = MSGLEVEL_JOINS;
        return;
    }

    eval("\$whois_printing_level_n = MSGLEVEL_" . $whois_printing_level . ";");

    if ($whois_printing_level_n == 0)
    {
        Irssi::print(
            "%RJOININFO:%n illegal /set whois_printing_level, see /help levels".
            " for more informations. Assuming JOINS in stead of ".
            "\"$whois_printing_level\"."
        );
        $whois_printing_level = "JOINS";
        $whois_printing_level_n = MSGLEVEL_JOINS;
        return;
    }
}

################################################################################

# We keep records of all nicks that ever joined a channel in our memory,
# without ever freeing them up. This can get quite large over time, therefore
# evere once in a while we go out and remove the garbage
#
# Now this function also corrects the pending counter in case strange things
# happen on strange nets
sub garbage_collector
{
    my($runtime) = time();

    foreach my $tag (keys(%servers))
    {
        my($busy) = 0;
        my($rec) = $servers{$tag};

        foreach my $nick (keys %{$rec->{nicks}})
        {
            my($age) = $runtime - $rec->{nicks}->{$nick}->{record_time};

            if ($rec->{nicks}->{$nick}->{busy})
            {
                # Re-calculate the number of pending requests
                $busy = $busy + 1;

                # we can safely delete it because 600 seconds should have
                # caused a good oldfashioned ping timeout anyway
                # if the server is not still going to respond after 10 
                # minutes we can crash for all I care
                if ($age > 600)
                {
                    Irssi::print(
                        "%RWHOIS:%n Giving up on %c$nick%n, because 600 " .
                        "seconds have passed since we first asked %c$tag%n.%N"
                    ) if ($whois_debug);

                    # We have one request less to process now
                    $busy = $busy - 1;

                    # Drop the request completely and forget all about this
                    # nick
                    delete $rec->{nicks}->{$nick};
                }
            }
            elsif ($age >= 2 * $whois_maxage)
            {
                delete $rec->{nicks}->{$nick};
            }

            $rec->{processing} = $busy;
        }
    }
}

################################################################################

# This is a very simple job to warp the call to the garbage collector. Used to
# be self-scheduling, but irssi happily does that for us
#
# Pointless function, waste of memory, need one of those in every good
# program, here is mine.
sub aw_gc_scheduler
{
    garbage_collector();
}

################################################################################

# Show information about the autowhois stuff and about who we still know
# Basically displays the cache contents. Some stuff may still be in the cache
# though it is already outdated, The barbage collector will take care of 
# those entries
sub cmd_joininfo_info
{
    my($runtime) = time();

    foreach my $tag (keys(%servers))
    {
        my($rec) = $servers{$tag};

        Irssi::printformat(
            MSGLEVEL_CRAP,
            'ji_whois_list_header',
            $tag,
            $rec->{processing}
        );

        foreach my $nick (keys %{$rec->{nicks}})
        {
            my($age) = $runtime - $rec->{nicks}->{$nick}->{record_time};
            my($status) = "OK";

            if ($rec->{nicks}->{$nick}->{busy})
            {
                $status = "BUSY";
            }
            elsif ($rec->{nicks}->{$nick}->{aborted})
            {
                $status = "ABORTED";

                if ($rec->{nicks}->{$nick}->{known})
                {
                    $status = $status . " but KNOWN";
                }
            }
            else
            {
                $status = "COMPLETE";
            }

            Irssi::printformat(
                MSGLEVEL_CRAP,
                'ji_whois_list_nick',
                $nick,
                $rec->{nicks}->{$nick}->{realname},
                $rec->{nicks}->{$nick}->{channels},
                $rec->{nicks}->{$nick}->{server},
                $rec->{nicks}->{$nick}->{flags}
            );
            Irssi::printformat(
                MSGLEVEL_CRAP,
                'ji_whois_list_status',
                $status,
                $age,
                $tag
            );
        }
    }
}

################################################################################

# A timeout is put for this function just after the WHOIS has been sent to
# the server. When the server does not reply, then we will mark the action as
# aborted. If a reply still ariives later (due to lag) that is not a problem
# as it will simply be reported then. The only thing this function makes sure
# of is that the system is not marked busy anymore so other WHOIS requests
# can go through
sub server_whois_timeout
{
    my ($server, $nick) = @{$_[0]};
    my $rec = $servers{$server->{tag}};

    if ((defined($rec->{nicks}->{$nick}))
        && ($rec->{nicks}->{$nick}->{busy} == 1)
    )
    {
        $rec->{nicks}->{$nick}->{aborted} = 1;
        $rec->{nicks}->{$nick}->{busy} = 0;

        $rec->{processing} = $rec->{processing} - 1;

        Irssi::print(
            "%RWHOIS:%n whois timeout for nick %C$nick%n ".
            "(still running $rec->{processing} requests)"
        ) if ($whois_debug);
    }

    # Run once, so we remove this job
    Irssi::timeout_remove($rec->{nicks}->{$nick}->{timeout_job});
}

################################################################################

# Put a whois request on the server (for one nick only) if and only if the
# number of outstanding rrequests on that server is not too high
#
# Also installs an event handler for the next related SHOIS event that the
# server throws at us
sub request_whois
{
    my ($server, $nick) = @_;
    my $rec = $servers{$server->{tag}};

    return if $server->{chat_type} ne "IRC";

    if ($rec->{processing} > $max_queued_requests)
    {
        Irssi::print(
            "%RWHOIS:%n Ignoring WHOIS request for %C$nick%n (too busy)%N"
        ) if ($whois_debug);
        record_reset($server, $nick);
        return;
    }

    $server->redirect_event(
        "whois",
        1,
        $nick,
        0, 
        "redir autowhois_default",
        {
            "event 311" => "redir autowhois_realname",
            "event 319" => "redir autowhois_channels",
            "event 312" => "redir autowhois_server",
            "event 301" => "redir autowhois_away",
            "event 307" => "redir autowhois_identified",
            "event 275" => "redir autowhois_ssl",
            "event 310" => "redir autowhois_irchelp",
            "event 313" => "redir autowhois_ircop",
            "event 325" => "redir autowhois_ircbot",
            "event 317" => "redir autowhois_idle",
#           "event 263" => "redir autowhois_busy",
            "event 318" => "redir autowhois_end",
            "event 401" => "redir autowhois_unknown",
            "" => "event empty"
        }
    );

    $rec->{processing} = $rec->{processing} + 1;

    # This format requests additional information on $nick
    # used to be: $server->send_raw("WHOIS $nick :$nick");
    $server->send_raw("WHOIS $nick");

    $rec->{nicks}->{$nick}->{timeout_job} = Irssi::timeout_add(
                                                $whois_timeout,
                                                \&server_whois_timeout,
                                                [$server, $nick]
                                            );
}

################################################################################

# A whois record is built as and when server messages with info for a specific
# user arrive. After the WHOIS END message has arrived for that user, we can
# report the stored whois information with this function.
sub report_stored_whois_info
{
    my ($server, $nick) = @_;
    my $rec = $servers{$server->{tag}};

    if (!defined($rec->{nicks}->{$nick}))
    {
        Irssi::print(
            "%RWHOIS:%n Report called for undefined hash %C$nick%N"
        ) if ($whois_debug);
        return;
    }

    foreach my $channame (@{$rec->{nicks}->{$nick}->{queued_channels}})
    {
        my $chanrec = $server->channel_find($channame);

        if ($chanrec)
        {
            $rec->{nicks}->{$nick}->{flags} =~ s/[ ]{1,}$//;

            $chanrec->printformat(
                $whois_printing_level_n,
                'ji_whois_success',
                $nick,
                $rec->{nicks}->{$nick}->{realname},
                $rec->{nicks}->{$nick}->{channels},
                $rec->{nicks}->{$nick}->{server},
                $rec->{nicks}->{$nick}->{flags}
            );
        }
        else
        {
            Irssi::print(
                "%RWHOIS:%n chanrec not found for %W$channame%n :-(%N"
            ) if ($whois_debug);
        }
    }

    $rec->{nicks}->{$nick}->{queued_channels} = [];
}

################################################################################

# Create an empty record for this nick on that server, we will gradually fill
# out this record as and when we go along.
sub record_reset
{
    my ($server, $nick) = @_;
    my $rec = $servers{$server->{tag}};

    if (defined($rec->{nicks}->{$nick}))
    {
        delete $rec->{nicks}->{$nick};
    }

    $rec->{nicks}->{$nick} =
    {
        record_time     => time(),
        queued_channels => [],
        realname        => "(unknown)",
        channels        => "(unknown)",
        server          => "(unknown)",
        flags           => "",
        aborted         => 0,
        busy            => 0,
        known           => 0,
        timeout_job     => 0
    };
}

################################################################################

# Sent when a user joins a channel we are on, whic is where we check if we
# have the user info cached, if it is still valid, and if not we put
# a WHOIS request on the server for this user and are done.
sub event_join
{
    my ($server, $channame, $nick, $host) = @_;

    return if $server->{chat_type} ne "IRC";
    
    $channame =~ s/^://;
    my $rec = $servers{$server->{tag}};

    return if ($nick eq $server->{nick});

    return if ($server->netsplit_find($nick, $host));

    if (!defined($rec->{nicks}->{$nick}))
    {
        # If the nick has no requests joined yet, we will create a new
        # empty record for the nick, so we can assume later it does
        # exist
        record_reset($server, $nick);
    }

    if (($rec->{nicks}->{$nick}->{known})
        && ((time() - $rec->{nicks}->{$nick}->{record_time}) <= $whois_maxage)
    )
    {
        # If we asked less than whois_maxage seconds ago for a WHOIS on this
        # nick, we will not re-issue a request.
        #
        # NOTE: When a person (manually) joins multiple channels you are
        #       on, this may cause you not seeing all channels in the
        #       channel list, You can set this to something like 5
        #       seconds to reduce the probability of this happening
        push @{$rec->{nicks}->{$nick}->{queued_channels}}, $channame;

        report_stored_whois_info($server, $nick);
    }
    elsif ($rec->{nicks}->{$nick}->{busy} == 1)
    {
        # If we already issued a WHOIS request for this nick but did not
        # receive a result yet, we just push this channel name on the
        # list of channels that want a report when the result is known
        push @{$rec->{nicks}->{$nick}->{queued_channels}}, $channame;
    }
    else
    {
        # Finally, we are not already processing this nick, and either
        # we have no information for it, or the information we have is
        # too old, so we send a WHOIS request to the server.
        push @{$rec->{nicks}->{$nick}->{queued_channels}}, $channame;

        $rec->{nicks}->{$nick}->{busy} = 1;

        request_whois($server, $nick);
    }
}

################################################################################

# Implementation of the WFORCE <nick> command. Useful for testing purposes
# only, for example to see if the theme changes you made are correct, if the
# timeouts are interpreted properly, and if the garbage collector works
sub cmd_joininfo_force
{
    my ($data, $server, $window) = @_;
    $data =~ s/^[ ]{1,}//g;
    $data =~ s/[ ]{1,}$//g;

    if (!$server || !$server->{connected})
    {
        Irssi::print("Not connected.");
        return;
    }

    if ($window->{type} ne "CHANNEL")
    {
        Irssi::print("Not a channel window.");
        return;
    }

    event_join($server, $window->{name}, $data, "testuser\@test.example.com");
}

################################################################################

# Event handler for the whois realname line returned by the server. When we
# issue a whois request, we bind an event handler for whois info for that
# nick.
#
# Does nothing, except for updating the record for that nick.
sub event_whois_realname
{
    my ($server, $data) = @_;
    my ($num, $nick, $user, $host, $empty, $realname) = split(/ +/, $data, 6);
    $realname =~ s/^://;
    my $rec = $servers{$server->{tag}};

    $rec->{nicks}->{$nick}->{realname} = $realname;
}

################################################################################

# Event handler for the whois channels line returned by the server. When we
# issue a whois request, we bind an event handler for whois info for that
# nick.
#
# Does nothing, except for updating the record for that nick.
sub event_whois_channels
{
    my ($server, $data) = @_;
    my ($num, $nick, $channels) = split(/ +/, $data, 3);
    $channels =~ s/^://;
    my $rec = $servers{$server->{tag}};

    $channels =~ s/[ ]{1,}$//;
    $rec->{nicks}->{$nick}->{channels} = $channels;
}

################################################################################

# Event handler for the whois server line returned by the server. When we
# issue a whois request, we bind an event handler for whois info for that
# nick.
#
# Does nothing, except for updating the record for that nick.
#
# NOTE: In the default report the server is not repported, it is however
# stored in the record, so if you need it, you can simply update the
# reporting function to show it.
sub event_whois_server
{
    my ($server, $data) = @_;
    my ($num, $nick, $serverstr) = split(/ +/, $data, 3);
    $serverstr =~ s/^://;
    my $rec = $servers{$server->{tag}};

    $serverstr =~ s/ :.*$//;

    $rec->{nicks}->{$nick}->{server} = $serverstr;
}

################################################################################

# This is the end of the whois request, all info available we should have
# now, so we mark the record as know, not bust, timestamp it so we can
# expire it later and we report back to the user on those channels waiting
# for whois info for nick
#
# Note that a No Such Nick error is not always followed by a WHOIS END.
# hyb7-based servers interpret the RFC differently from for example hyb6
# and the IRCNet servers and will not send the WHOIS END line, but just
# the No Such Nick error (401).
sub event_whois_end
{
    my($server, $data) = @_;
    my ($num, $nick, $serverstr) = split(/ +/, $data, 3);
    my $rec = $servers{$server->{tag}};

    $rec->{nicks}->{$nick}->{record_time} = time();
    $rec->{nicks}->{$nick}->{known} = 1;
    $rec->{nicks}->{$nick}->{busy} = 0;

    if (!$rec->{nicks}->{$nick}->{aborted})
    {
        $rec->{processing} = $rec->{processing} - 1;
    }

    report_stored_whois_info($server, $nick);
}

################################################################################

# Some servers (hyb7) do not send an end of whois when the nick is
# not known, they just send a 401 unknown message. Ircnet sends both, hyb6
# sends both, but other servers seem to interpret the RFC differently. We
# just treat this event_whois_unknown as a 318 tag, and mark the lookup
# aborted (which it is in some way)
sub event_whois_unknown
{
    my($server, $data) = @_;
    my ($num, $nick, $serverstr) = split(/ +/, $data, 3);
    my $rec = $servers{$server->{tag}};

    # Fill out the record with some bogus information, so when we
    # end up reporting it, we can at least see what is going on.
    $rec->{nicks}->{$nick}->{record_time} = time();
    $rec->{nicks}->{$nick}->{known} = 1;
    $rec->{nicks}->{$nick}->{busy} = 0;
    $rec->{nicks}->{$nick}->{realname} = "(unknown)";
    $rec->{nicks}->{$nick}->{channels} = "(unknown)";
    $rec->{nicks}->{$nick}->{server}   = "(unknown)";
    $rec->{nicks}->{$nick}->{flags}    = "(unknown)";

    if (!$rec->{nicks}->{$nick}->{aborted})
    {
        $rec->{processing} = $rec->{processing} - 1;
        $rec->{nicks}->{$nick}->{aborted} = 1;
    }

    report_stored_whois_info($server, $nick);
}

################################################################################

# If the server is busy
sub event_whois_busy
{
    my($server, $data) = @_;
    my($num, $nick, $serverstr) = split(/ +/, $data, 3);
    my($rec) = $servers{$server->{tag}};

    Irssi::print("******************* SERVER BUSY *******************************");
}

################################################################################

# No clue what this is for, maybe I should read the irssi documentation
# (if it existed....)
#
# Judging from the debug output this function is never called.
sub event_whois_default
{
    my($server, $nick) = @_;
    my $rec = $servers{$server->{tag}};

    Irssi::print(
        "%RWHOIS:%n Got event_whois_default, ignoring."
    ) if ($whois_debug);
}

################################################################################

# Some chat networks support extra falgs for their users and display those
# in WHOIS results. The following fields allow this information to be
# stored in the channel records and to be displayed as well.

sub event_whois_away
{
    my ($server, $data) = @_;
    my $rec = $servers{$server->{tag}};
    my ($num, $nick, $msg) = split(/ +/, $data, 3);
    $msg =~ s/^://;
    $rec->{nicks}->{$nick}->{flags} = $rec->{nicks}->{$nick}->{flags}."Away ";
}

################################################################################

sub event_whois_identified
{
    my ($server, $data) = @_;
    my $rec = $servers{$server->{tag}};
    my ($num, $nick, $msg) = split(/ +/, $data, 3);
    $msg =~ s/^://;
    $rec->{nicks}->{$nick}->{flags} = $rec->{nicks}->{$nick}->{flags}."NickREG ";
}

################################################################################

sub event_whois_ssl
{
    my ($server, $data) = @_;
    my $rec = $servers{$server->{tag}};
    my ($num, $nick, $msg) = split(/ +/, $data, 3);
    $msg =~ s/^://;
    $rec->{nicks}->{$nick}->{flags} = $rec->{nicks}->{$nick}->{flags}."SSL ";
}

################################################################################

sub event_whois_irchelp
{
    my ($server, $data) = @_;
    my $rec = $servers{$server->{tag}};
    my ($num, $nick, $msg) = split(/ +/, $data, 3);
    $msg =~ s/^://;
    $rec->{nicks}->{$nick}->{flags} = $rec->{nicks}->{$nick}->{flags}."IrcHELP ";
}

################################################################################

sub event_whois_ircop
{
    my ($server, $data) = @_;
    my $rec = $servers{$server->{tag}};
    my ($num, $nick, $msg) = split(/ +/, $data, 3);
    $msg =~ s/^://;
    $rec->{nicks}->{$nick}->{flags} = $rec->{nicks}->{$nick}->{flags}."IrcOP ";
}

################################################################################

sub event_whois_ircbot
{
    my ($server, $data) = @_;
    my $rec = $servers{$server->{tag}};
    my ($num, $nick, $msg) = split(/ +/, $data, 3);
    $msg =~ s/^://;
    $rec->{nicks}->{$nick}->{flags} = $rec->{nicks}->{$nick}->{flags}."IrcBOT ";
}

################################################################################

sub number_to_timestr
{
    my($number) = @_;
    my ($result) = "";

    # Force integer
    $number = 1 * $number;

    my($days) = $number / 86400;
    $number = $number % 86400;
    my($hours) = $number / 3600;
    $number = $number % 3600;
    my($minutes) = $number / 60;
    $number = $number % 60;
    my($seconds) = $number;

    if ($days) { $result = $result . "${days}d"; }
    if ($hours || $result) { $result = $result . "${hours}h"; }
    if ($minutes || $result) { $result = $result . "${minutes}m"; }
    $result = $result . "${seconds}s";

    return $result;
}

################################################################################

sub event_whois_idle
{
    my ($server, $data) = @_;
    my $rec = $servers{$server->{tag}};
    my ($num, $nick, $msg) = split(/ +/, $data, 3);
    $msg =~ s/^://;

    if ($msg =~ /^([0-9]{1,}) ([0-9]{1,}) :.*$/)
    {
        my($idle) = 1 * $1;
        my($signon) = 1 * $2;

        $rec->{nicks}->{$nick}->{flags} = $rec->{nicks}->{$nick}->{flags}
            . "Idle=" . number_to_timestr($idle). " ";
    }
    elsif ($msg =~ /^([0-9]{1,}) :.*$/)
    {
        my($idle) = 1 * $1;

        $rec->{nicks}->{$nick}->{flags} = $rec->{nicks}->{$nick}->{flags}
            . "Idle=" . number_to_timestr($idle). " ";
    }
    else
    {
        $rec->{nicks}->{$nick}->{flags} = $rec->{nicks}->{$nick}->{flags}."SameSRV ";
    }
}

################################################################################

# Initializes a server record for the autowhois. Either called when a server
# does connect to the network, or on script load for all connected servers at
# that time
sub event_connected
{
    my($server) = @_;

    $servers{$server->{tag}} = {
        processing => 0,    # waiting reply for WHOIS request
        nicks => {}         # nick => [ #chan1, #chan2, .. ]
    };
}

################################################################################

# Deletes a server record for the autowhois. We do this on disconnect
sub event_disconnected
{
    my($server) = @_;

    delete $servers{$server->{tag}};
}

################################################################################

# Implementation of what I call the /JOININFO umbrella command. Below
# we bind all subcommands for this command already, so all we need to
# do is hand off the event to irssi again so it can call the right
# implementation function for it.
sub cmd_joininfo
{
    my ($data, $server, $item) = @_;
    $data =~ s/\s+$//g;
    Irssi::command_runsub ('joininfo', $data, $server, $item);
}

################################################################################

# Shows help
sub cmd_joininfo_help
{
    Irssi::print( <<EOF

JOININFO FORCE <nick>
JOININFO GC
JOININFO INFO
JOININFO HELP

JOININFO FORCE <nick>
  Fakes the join of a certain nick to the channel, and shows you
  what the WHOIS line would look like.
JOININFO GC
  Forces running the garbage collector once
JOININFO INFO
  Shows the WHOIS cache as it exists. Note that records in the cache
  may be outdated but not deleted yet by the garbage collector
JOININFO HELP
  This page

Example:
 JOININFO FORCE ichiban

Settings:
  Use /SET to change whois_expire_time, whois_max_requests,
  whois_timeout_ms, whois_gc_interval_ms, whois_debug, or
  whois_printing_level

These settings:
  Use /FORMAT to change ji_whois_success, ji_whois_list_header,
  ji_whois_list_nick, or ji_whois_list_status

Note: If you want to hilight certain channels in the output, just use
/HILIGHT -level JOINS #channel

See also: HILIGHT
EOF
    , MSGLEVEL_CLIENTCRAP);
}

################################################################################

# Tegister messages for /FORMAT and theme support
register_messages();

# Register settings for /SET support
register_settings();

# Load the previously stored settings from the config file, will be called
# again later each time the settings change
load_settings();

################################################################################

# Mark all currently connected servers as connected
foreach my $server (Irssi::servers()) 
{
    event_connected($server);
}

################################################################################

# Add and register our signal handlers
Irssi::signal_add(
{   'server connected'              => \&event_connected,
    'server disconnected'           => \&event_disconnected,
    'message join'                  => \&event_join,
    'redir autowhois_realname'      => \&event_whois_realname,
    'redir autowhois_channels'      => \&event_whois_channels,
    'redir autowhois_server'        => \&event_whois_server,
    'redir autowhois_away'          => \&event_whois_away,
    'redir autowhois_identified'    => \&event_whois_identified,
    'redir autowhois_ssl'           => \&event_whois_ssl,
    'redir autowhois_irchelp'       => \&event_whois_irchelp,
    'redir autowhois_ircop'         => \&event_whois_ircop,
    'redir autowhois_ircbot'        => \&event_whois_ircbot,
    'redir autowhois_idle'          => \&event_whois_idle,
    'redir autowhois_end'           => \&event_whois_end,
    'redir autowhois_unknown'       => \&event_whois_unknown,
    'redir autowhois_busy'          => \&event_whois_busy,
    'setup changed'                 => \&load_settings }
);

################################################################################

# Schedule the garbase collector to run every whois_gc_interval ms
Irssi::timeout_add(
    $whois_gc_interval,
    \&aw_gc_scheduler,
    0
);

################################################################################

# OLD STYLE COMMANDS ARE DISABLED AND REPLACED BY /JOININFO WITH SUB-COMMANDS
# Bind the /AWFORCE, /AWGC and /AWINFO commands. Uncomment the next three lines
# if you would like to keep the old-style commands
### Irssi::command_bind("awforce", "cmd_joininfo_force");
### Irssi::command_bind("awgc", "garbage_collector");
### Irssi::command_bind("awinfo", "cmd_joininfo_info");

Irssi::command_bind("joininfo force", \&cmd_joininfo_force);
Irssi::command_bind("joininfo gc", \&garbage_collector);
Irssi::command_bind("joininfo info", \&cmd_joininfo_info);
Irssi::command_bind("joininfo help", \&cmd_joininfo_help);
Irssi::command_bind("joininfo", \&cmd_joininfo);

################################################################################
### EOF
