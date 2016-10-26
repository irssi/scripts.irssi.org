#!/usr/bin/perl -w

## Bugreports and Licence disclaimer.
#
# For bugreports and other improvements contact Geert Hauwaerts <geert@irssi.org>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this script; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
##

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.08";

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'kline_warning.pl',
    description => 'This script shows a warning in the statuswindow if somebody preforms a /KlINE or /UNKLINE.',
    license     => 'GNU General Public License',
    url         => 'http://irssi.hauwaerts.be/kline_warning.pl',
    changed     => 'Wed Sep 17 23:00:11 CEST 2003',
);

## Comments and remarks.
#
# This script uses settings, by default the servernotice will be stripped out.
# If you still want to be able to see the servernotice use /SET or /TOGGLE
# to switch it on or off.
#
#    Setting: show_kline_snote
#
##

Irssi::theme_register([
    'kline_added', '%_Warning%_: %R>>%n %_$0%_ added a K-Line for %_$1%_ on $2',
    'tkline_added', '%_Warning%_: %R>>%n %_$0%_ added a temporary K-Line ($1) for %_$2%_ on $3',
    'expired', '%_Warning%_: %R>>%n Temporary K-Line for %_$0%_ expired on $1',
    'remove', '%_Warning%_: %R>>%n %_$0%_ removed the K-Line for %_$1%_ on $2',
    'kline_warning_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.'
]);

sub kline_warning {

    my ($dest, $text) = @_;

    return if (($text !~ /^NOTICE/));
    
    # Type IRCd:   Hybrid7
    # Homepage:    http://www.ircd-hybrid.com/
    # Needed flags: +s
    if ($text =~ /Notice -- (.*)!.*@.*{.*} added K-Line for \[(.*)\] \[.*\]/) {
        print_warning_kline($1, $2, $dest->{tag});
    } elsif ($text =~ /Notice -- \*\*\* Received K-Line for \[(.*)\] \[.*\], from (.*)!.*@.* on .*/) {
        print_warning_kline($2, $1, $dest->{tag});
    } elsif ($text =~ /Added K-Line \[.*@.*\]/) {
        Irssi::signal_stop();
    } elsif ($text =~ /Notice -- (.*)!.*@.*{.*} added temporary (.*). K-Line for \[(.*)\] \[.*\]/) {
        print_warning_tkline($1, $2, $3, $dest->{tag});
    } elsif ($text =~ /Added temporary .*. K-Line \[.*@.*\]/) {
        Irssi::signal_stop();
    } elsif ($text =~ /Notice -- Temporary K-line for \[(.*)\] expired/) {
        print_warning_expired($1, $dest->{tag});
    } elsif ($text =~ /Notice -- (.*)!.*@.*{.*} has removed the K-Line for: \[(.*)\]/) {
        print_warning_unkline($1, $2, $dest->{tag});
    } elsif ($text =~ /K-Line for \[(.*)\] is removed/) {
        Irssi::signal_stop();
    }
}

sub print_warning_kline {

    my ($nick, $host, $network) = @_;
    my $signalstop;
    
    $signalstop = Irssi::settings_get_bool('show_kline_snote');

    if ($signalstop == 0) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'kline_added', $nick, $host, $network);
        Irssi::signal_stop();
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'kline_added', $nick, $host, $network);
    }
}

sub print_warning_tkline {

    my ($nick, $duration, $host, $network) = @_;
    my $signalstop;
    
    $signalstop = Irssi::settings_get_bool('show_kline_snote');

    if ($signalstop == 0) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'tkline_added', $nick, $duration, $host, $network);
        Irssi::signal_stop();
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'tkline_added', $nick, $duration, $host, $network);
    }
}

sub print_warning_expired {

    my ($host, $network) = @_;
    my $signalstop;
    
    $signalstop = Irssi::settings_get_bool('show_kline_snote');

    if ($signalstop == 0) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'expired', $host, $network);
        Irssi::signal_stop();
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'expired', $host, $network);
    }
}

sub print_warning_unkline {
    
    my ($nick, $host , $network) = @_;
    my $signalstop;
    
    $signalstop = Irssi::settings_get_bool('show_kline_snote');

    if ($signalstop == 0) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'remove', $nick, $host, $network);
        Irssi::signal_stop();
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'remove', $nick, $host, $network);
    }
}

Irssi::signal_add_first('server event', 'kline_warning');
Irssi::settings_add_bool('warning', 'show_kline_snote' => 0);
Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'kline_warning_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
