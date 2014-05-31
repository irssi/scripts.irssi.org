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
    name        => 'keybindings.pl',
    description => 'This script will set the proper keybindings on /AZERTY and /QWERTY.',
    license     => 'Public Domain',
    url         => 'http://irssi.hauwaerts.be/keybindings.pl',
    changed     => 'Tue Nov  4 16:49:20 CET 2003',
);

Irssi::theme_register([
    'loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.',
    'bound',  '%R>>%n %_Keybindings:%_ Loaded the $0 keybindings.'
]);

sub azerty {

    Irssi::command("^BIND meta-a change_window 11");
    Irssi::command("^BIND meta-p change_window 20");
    Irssi::command("^BIND meta-m change_window 30");
    Irssi::command("^BIND meta-Z change_window 31");
    Irssi::command("^BIND meta-z change_window 12");
    Irssi::command("^BIND meta-s change_window 22");
    Irssi::command("^BIND meta-d change_window 23");
    Irssi::command("^BIND meta-f change_window 24");
    Irssi::command("^BIND meta-g change_window 25");
    Irssi::command("^BIND meta-h change_window 26");
    Irssi::command("^BIND meta-j change_window 27");
    Irssi::command("^BIND meta-k change_window 28");
    Irssi::command("^BIND meta-l change_window 29");
    Irssi::command("^BIND meta-A change_window 32");
    Irssi::command("^BIND meta-E change_window 33");
    Irssi::command("^BIND meta-R change_window 34");
    Irssi::command("^BIND meta-T change_window 35");
    Irssi::command("^BIND meta-Y change_window 36");
    Irssi::command("^BIND meta-U change_window 37");
    Irssi::command("^BIND meta-I change_window 38");
    Irssi::command("^BIND meta-O change_window 39");
    Irssi::command("^BIND meta-P change_window 40");
    Irssi::command("^BIND meta-Q change_window 41");
    Irssi::command("^BIND meta-q change_window 21");
    Irssi::command("^BIND meta-S change_window 42");
    Irssi::command("^BIND meta-D change_window 43");
    Irssi::command("^BIND meta-F change_window 44");
    Irssi::command("^BIND meta-G change_window 45");
    Irssi::command("^BIND meta-H change_window 46");
    Irssi::command("^BIND meta-J change_window 47");
    Irssi::command("^BIND meta-K change_window 48");
    Irssi::command("^BIND meta-L change_window 49");
    Irssi::command("^BIND meta-M change_window 50");
    Irssi::command("^BIND meta-& change_window 1");
    Irssi::command("^BIND meta-é change_window 2");
    Irssi::command("^BIND meta-\" change_window 3");
    Irssi::command("^BIND meta-' change_window 4");
    Irssi::command("^BIND meta-( change_window 5");
    Irssi::command("^BIND meta-§ change_window 6");
    Irssi::command("^BIND meta-è change_window 7");
    Irssi::command("^BIND meta-! change_window 8");
    Irssi::command("^BIND meta-ç change_window 9");
    Irssi::command("^BIND meta-à change_window 10");
    Irssi::command("^BIND meta-x command window last");
    Irssi::command("^BIND meta-N command /mark");

    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'bound', 'azerty');
}

sub qwerty {

    Irssi::command("^BIND meta-a change_window 21");
    Irssi::command("^BIND meta-p change_window 20");
    Irssi::command("^BIND meta-m change_window 30");
    Irssi::command("^BIND meta-Z change_window 31");
    Irssi::command("^BIND meta-w change_window 12");
    Irssi::command("^BIND meta-s change_window 22");
    Irssi::command("^BIND meta-d change_window 23");
    Irssi::command("^BIND meta-f change_window 24");
    Irssi::command("^BIND meta-g change_window 25");
    Irssi::command("^BIND meta-h change_window 26");
    Irssi::command("^BIND meta-j change_window 27");
    Irssi::command("^BIND meta-k change_window 28");
    Irssi::command("^BIND meta-l change_window 29");
    Irssi::command("^BIND meta-A change_window 32");
    Irssi::command("^BIND meta-E change_window 33");
    Irssi::command("^BIND meta-R change_window 34");
    Irssi::command("^BIND meta-T change_window 35");
    Irssi::command("^BIND meta-Y change_window 36");
    Irssi::command("^BIND meta-U change_window 37");
    Irssi::command("^BIND meta-I change_window 38");
    Irssi::command("^BIND meta-O change_window 39");
    Irssi::command("^BIND meta-P change_window 40");
    Irssi::command("^BIND meta-Q change_window 41");
    Irssi::command("^BIND meta-q change_window 11");
    Irssi::command("^BIND meta-S change_window 42");
    Irssi::command("^BIND meta-D change_window 43");
    Irssi::command("^BIND meta-F change_window 44");
    Irssi::command("^BIND meta-G change_window 45");
    Irssi::command("^BIND meta-H change_window 46");
    Irssi::command("^BIND meta-J change_window 47");
    Irssi::command("^BIND meta-K change_window 48");
    Irssi::command("^BIND meta-L change_window 49");
    Irssi::command("^BIND meta-M change_window 50");
    Irssi::command("^BIND meta-& change_window 1");
    Irssi::command("^BIND meta-é change_window 2");
    Irssi::command("^BIND meta-\" change_window 3");
    Irssi::command("^BIND meta-' change_window 4");
    Irssi::command("^BIND meta-( change_window 5");
    Irssi::command("^BIND meta-§ change_window 6");
    Irssi::command("^BIND meta-è change_window 7");
    Irssi::command("^BIND meta-! change_window 8");
    Irssi::command("^BIND meta-ç change_window 9");
    Irssi::command("^BIND meta-à change_window 10");
    Irssi::command("^BIND meta-x command window last");
    Irssi::command("^BIND meta-N command /mark");

    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'bound', 'qwerty');
}

Irssi::command_bind('azerty', 'azerty');
Irssi::command_bind('qwerty', 'qwerty');

Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});

