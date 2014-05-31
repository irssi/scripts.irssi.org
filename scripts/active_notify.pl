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

## Comments and remarks.
#
# This script uses settings, by default the broadcast will be set off.
# If you  want the notify message to be shown in all the windows use
# /SET or /TOGGLE to switch it on or off.
#
#    Setting: notify_broadcast
#
##

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.07";

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'active_notify.pl',
    description => 'This script will display notify messages into the active window or broadcast it so all the windows.',
    license     => 'GNU General Public License',
    url         => 'http://irssi.hauwaerts.be/active_notify.pl',
    changed     => 'Wed Sep 17 23:00:11 CEST 2003',
);

Irssi::theme_register([
    'notify_joined', '%_Notify%_: %R>>%n %_$0%_ [$1@$2] [$3] has joined /$4/.',
    'notify_left', '%_Notify%_: %R>>%n %_$0%_ [$1@$2] [$3] has parted /$4/.',
    'notify_new', '%_Notify%_: %R>>%n Added %_$0%_ to the notify list.',
    'notify_del', '%_Notify%_: %R>>%n Removed %_$0%_ from the notify list.',
    'active_notify_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.'
]);

sub notify_joined {
    
    my ($server, $nick, $user, $host, $realname, $awaymsg) = @_;
    my $broadcast = Irssi::settings_get_bool('notify_broadcast');
    my $window = Irssi::active_win();

    if ($broadcast) {
        foreach my $bwin (Irssi::windows) {
            $bwin->printformat(MSGLEVEL_CLIENTCRAP, 'notify_joined', $nick, $user, $host, $realname, $server->{tag});
        }
    } else {
        $window->printformat(MSGLEVEL_CLIENTCRAP, 'notify_joined', $nick, $user, $host, $realname, $server->{tag});
    }

    Irssi::signal_stop();
}

sub notify_left {
    
    my ($server, $nick, $user, $host, $realname, $awaymsg) = @_;
    my $broadcast = Irssi::settings_get_bool('notify_broadcast');
    my $window = Irssi::active_win();

    if ($broadcast) {
        foreach my $bwin (Irssi::windows) {
            $bwin->printformat(MSGLEVEL_CLIENTCRAP, 'notify_left', $nick, $user, $host, $realname, $server->{tag});
        }
    } else {
        $window->printformat(MSGLEVEL_CLIENTCRAP, 'notify_left', $nick, $user, $host, $realname, $server->{tag});
    }

    Irssi::signal_stop();
}

sub notify_new {
    
    my ($nick) = @_;
    my $broadcast = Irssi::settings_get_bool('notify_broadcast');
    my $window = Irssi::active_win();
    my ($aw_ch, $ircnet, $mask, $ict);
    
    if ($broadcast) {
        foreach my $bwin (Irssi::windows) {
            $bwin->printformat(MSGLEVEL_CLIENTCRAP, 'notify_new', $nick->{mask});
        }
    } else {
        $window->printformat(MSGLEVEL_CLIENTCRAP, 'notify_new', $nick->{mask});
    }

    Irssi::signal_stop();
}

sub notify_del {
    
    my ($nick) = @_;
    my $broadcast = Irssi::settings_get_bool('notify_broadcast');
    my $window = Irssi::active_win();
    
    if ($broadcast) {
        foreach my $bwin (Irssi::windows) {
            $bwin->printformat(MSGLEVEL_CLIENTCRAP, 'notify_del', $nick->{mask});
        }
    } else {
        $window->printformat(MSGLEVEL_CLIENTCRAP, 'notify_del', $nick->{mask});
    }

    Irssi::signal_stop();
}

Irssi::signal_add_first('notifylist joined', 'notify_joined');
Irssi::signal_add_first('notifylist left', 'notify_left');

## BUG, BUG, BUG! Warning!
#
# [16:02] [-] Irssi: Starting query in Freenode with cras
# [16:04] :cras: it crashes every time it gets into 'notifylist remove' signal?
# [16:04] :Geert: yes
# [16:05] :Geert: the notifylist new too
# [16:06] :cras: even if they didn't do anything?
# [16:06] :Geert: indeed
# [16:06] :Geert: Try for yourself :)
# [16:06] :Geert: joined & remove signals are working great
# [16:07] :cras: i guess it doesn't like the notifylist_rec ..
# [16:08] :Geert: So, what should I do now? :)
# [16:10] :cras: try cvs update?
# [16:10] :cras: i fixed one possible cause for it
# [16:10] :cras: and can't see another one :)
# [16:11] :Geert: Well, It's a scriptrequest from someone. So I'll just comment that feature
# [16:11] :Geert: Are you sure it works in the cvs?
# [16:11] :cras: well, 70% sure :)
# [16:12] :Geert: Let's hope so :P
#
# Uncomment the next two lines. ONLY if you have the CVS version.
#
#Irssi::signal_add_first('notifylist new', 'notify_new');
#Irssi::signal_add_first('notifylist remove', 'notify_del');
#
##

Irssi::settings_add_bool('notify', 'notify_broadcast' => 0);
Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'active_notify_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
