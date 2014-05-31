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

$VERSION = "0.03";

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'dancer_forwardfix.pl',
    description => 'This script will fix the Irssi problem with channel forwarding on the Dancer ircd.',
    license     => 'Public Domain',
    url         => 'http://irssi.hauwaerts.be/dancer_forwardfix.pl',
    changed     => 'Sun May  9 01:19:25 2004',
);

Irssi::theme_register([
    'fwfix_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.',
    'fwfix_reason', '%R>>%n %_Forwardfix:%_ $0 forwarded to $1'
]);

sub fix_379 {

    my ($server, $data) = @_;
    my ($nick, $mainchan, $fwdchan, $reason) = split(/ /, $data);

    if ($server && ($server->{'version'} =~ /dancer/)) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fwfix_reason', $mainchan, $fwdchan);
        Irssi::timeout_add_once(1000, sub { $server->command("PART $mainchan"); }, undef);
        Irssi::signal_stop;
    }
}

Irssi::signal_add('event 379', 'fix_379');

Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fwfix_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
