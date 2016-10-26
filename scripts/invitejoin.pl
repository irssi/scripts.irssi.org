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

$VERSION = "0.01";

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'invitejoin.pl',
    description => 'This script will join a channel if somebody invites you to it.',
    license     => 'Public Domain',
    url         => 'http://irssi.hauwaerts.be/invitejoin.pl',
    changed     => 'Sun Apr 11 12:38:18 2004',
);

## Comments and remarks.
#
# This script uses settings.
# Use /SET to change the value or /TOGGLE to switch it on or off.
#
#    Setting:     invitejoin
#    Description: If this setting is turned on, you will join the channel
#                 when invite to.
#
##


Irssi::theme_register([
    'invitejoin_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.',
    'invitejoin_invited', '%R>>%n %_Invitejoin:%_ Joined $1 (Invited by $0).'
]);

sub invitejoin {
    
    my ($server, $channel, $nick, $address) = @_;
    my $invitejoin = Irssi::settings_get_bool('invitejoin');

    if ($invitejoin) {
        $server->command("join $channel");
        
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invitejoin_invited', $nick, $channel);
        Irssi::signal_stop();
    }
}

Irssi::signal_add('message invite', 'invitejoin');

Irssi::settings_add_bool('invitejoin', 'invitejoin' => 1);

Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invitejoin_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
