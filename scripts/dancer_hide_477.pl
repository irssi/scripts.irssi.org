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
    name        => 'dancer_hide_477.pl',
    description => 'This script hides the 477 numerics from the dancer IRCd.',
    license     => 'GNU General Public License',
    url         => 'http://irssi.hauwaerts.be/dancer_hide_477.pl',
    changed     => 'Fri Mar 12 19:46:24 2004',
);

Irssi::theme_register([
    'dancer_hide_477_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.'
]);

sub hide_477 {

    my ($server, $data) = @_;
    my ($num, $nick, $auth_nick) = split(/ +/, $_[1], 3);

    if ($server && ($server->{'version'} =~ /dancer/)) {
        Irssi::signal_stop();
    }
}

Irssi::signal_add('event 477', 'hide_477');
Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'dancer_hide_477_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
