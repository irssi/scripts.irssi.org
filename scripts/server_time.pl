# Summary
# -------
#
# irssi does not yet support the IRCv3 server-time extension (specified at
# https://ircv3.net/specs/extensions/server-time-3.2.html), so this plugin
# fills that hole. The plugin does not work for all kinds of messages, but
# query messages and channel messages you receive with a servertime attached
# will show the servertime properly (rather than the time you received the
# message).
#
# Instructions
# ------------
#
# This script is intended to be loaded before connecting to a server; then it
# will request the server-time capability upon connecting. Make sure to include
# it in your autorun directory (~/.irssi/scripts/autorun/).
#
# Changelog
# ---------
#
# 0.1
#   - Initial release
# 1.0
#   - Forked by John Sullivan (without explicit cooperation from original
#     author).
#   - Removed dependency on DateTime::Format::ISO8601 (because it is not
#     shipped in Brew's Perl by default it's overkill anyways).
#   - Prepared it for inclusion in https://scripts.irssi.org.
#
# License
# -------
# Copyright (C) 2016 Adrian Keet (arkeet@gmail.com)
# Copyright (C) 2018 John Sullivan (johnsullivan.pem@gmail.com)
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.


use strict;
use Irssi;
use DateTime;
use DateTime::TimeZone;

our $VERSION = '1.0';
our %IRSSI = (
    authors     => 'Adrian Keet & John Sullivan',
    contact     => 'johnsullivan.pem@gmail.com',
    name        => 'server_time',
    description => 'Implements the IRCv3 "server-time" capability',
    license     => 'MIT',
    url         => 'https://github.com/itsjohncs/irssi-server-time',
);

sub parse_servertime {
    my ($servertime, ) = @_;

    # Matches exactly YYYY-MM-DDThh:mm:ss.sssZ as specified in the server time spec
    my ($year, $month, $day, $hour, $minute, $second, $milliseconds) =
        ($servertime =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})\.(\d{3})Z$/);
    if ($year) {
        return DateTime->new(
            year => $year,
            month => $month,
            day => $day,
            hour => $hour,
            minute => $minute,
            second => $second,
            nanosecond => $milliseconds * 1000000,
            time_zone => "UTC",
        );
    } else {
        return undef;
    }
}

# Parse the @time tag on a server message
sub server_incoming {
    my ($server, $line) = @_;

    if ($line =~ /^\@time=([\S]*)\s+(.*)$/) {
        my $servertime = $1;
        $line = $2;

        my $tz = DateTime::TimeZone->new(name => 'local');

        my $ts = parse_servertime($servertime);
        unless ($ts) {
            Irssi::print("Badly formatted servertime: $servertime");
            return;
        }
        $ts->set_time_zone($tz);

        my $orig_format = Irssi::settings_get_str('timestamp_format');
        my $format = $orig_format;

        # Prepend the date if it differs from the current date.
        my $now = DateTime->now();
        $now->set_time_zone($tz);
        if ($ts->ymd() ne $now->ymd()) {
            $format = '[%F] ' . $format;
        }

        my $timestamp = $ts->strftime($format);

        Irssi::settings_set_str('timestamp_format', $timestamp);
        Irssi::signal_emit('setup changed');

        Irssi::signal_continue($server, $line);

        Irssi::settings_set_str('timestamp_format', $orig_format);
        Irssi::signal_emit('setup changed');
    }
}

# Request the server-time capability during capability negotiation
sub event_cap {
    my ($server, $args, $nick, $address) = @_;

    if ($args =~ /^\S+ (\S+) :(.*)$/) {
        my $subcmd = uc $1;
        if ($subcmd eq 'LS') {
            my @servercaps = split(/\s+/, $2);
            my @caps = grep {$_ eq 'server-time' or $_ eq 'znc.in/server-time-iso'} @servercaps;
            my $capstr = join(' ', @caps);
            if (!$server->{connected}) {
                $server->send_raw_now("CAP REQ :$capstr");
            }
        }
    }
}

Irssi::signal_add_first('server incoming', \&server_incoming);
Irssi::signal_add('event cap', \&event_cap);
