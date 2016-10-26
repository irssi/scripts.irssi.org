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

$VERSION = "0.05";

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'fuckem.pl',
    description => 'Simulates the BitchX /FUCKEM command. Deop/Dehalfop everyone on the channel including you.',
    license     => 'GNU General Public License',
    url         => 'http://irssi.hauwaerts.be/fuckem.pl',
    changed     => 'Wed Sep 17 23:00:11 CEST 2003',
);

Irssi::theme_register([
    'fuckem_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.'
]);

sub fuckem {

    my ($data, $server, $channel) = @_;
    my ($hops, $ops, $hcount, $ocount, $mode, $users);

    if (!$server) {
        $channel->print("You are not connected to a server.");
        return;
    } elsif  (!$channel || $channel->{type} ne "CHANNEL") {
        $channel->print("No active channel in this window.");
        return;
    } elsif (!$channel->{ownnick}{op}) {
        $channel->print("You're no channel operator.");
        return;
    }

    foreach my $nick ($channel->nicks()) {
        if ($nick->{halfop}) {
            $hops .= "$nick->{nick} ";
            $hcount++;
        } elsif ($nick->{op}) {
            $ops .= "$nick->{nick} ";
            $ocount++;
        }
    }

    if ($ops) {
        $mode .= 'o' x $ocount;
        $users .= "$ops ";
    }

    if ($hops) {
        $mode .= 'h' x $hcount;
        $users .= "$hops ";
    }
    
    $mode .= 'o';
    $users .= "$server->{nick}";
    
    $channel->command("mode -$mode $users");
}

Irssi::command_bind('fuckem', 'fuckem');
Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fuckem_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
