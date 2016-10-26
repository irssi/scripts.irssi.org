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

$VERSION = "0.02";

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'hignore.pl',
    description => 'This script will add the HIGNORE command, if you use this command in a query it will ignore the host.',
    license     => 'Public Domain',
    url         => 'http://irssi.hauwaerts.be/hignore.pl',
    changed     => 'Wed Sep 17 23:51:38 CEST 2003',
);

## Comments and remarks.
#
# A little tip for this script.
#
#    Tip:     This script if verry usefull if you bind this to an F-key. For example if you get flooded
#             (by the little bastard dj_poison on Undernet) you'll just need to press F1 and it will 
#             ignore the hostmask and close the query.
#    Command: /BIND meta2-P key F1
#             /BIND F1 command eval hignore ; unquery
#
##

Irssi::theme_register([
    'loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.',
    'no_query', '%R>>%n %_HIGNORE:%_ The specified window isn\'t a query.',
    'no_host', '%R>>%n %_HIGNORE:%_ The specified query doesn\'t contain host information.'
]);

sub hignore {

    my $wintype = Irssi::active_win->{active}->{type};
    my $winaddr = Irssi::active_win->{active}->{address};

    if ($wintype ne "QUERY") {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'no_query');
    } else {
        if ($winaddr =~ /\b~?(.{1,10})@([a-zA-Z0-9_.-]+)\b/) {
            my ($user, $host) = ($1, $2);
            
            Irssi::command("IGNORE *!*\@$host");
        
        } else {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'no_host');
        }
    }
}

Irssi::command_bind('hignore', 'hignore');

Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
