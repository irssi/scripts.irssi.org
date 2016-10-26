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

$VERSION = "1.07";

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'active_notice.pl',
    description => 'This script shows notices into the active channel unless it has its own window.',
    license     => 'GNU General Public License',
    url         => 'http://irssi.hauwaerts.be/active_notice.pl',
    changed     => 'Wed Sep 17 23:00:11 CEST 2003',
);

Irssi::theme_register([
    'active_notice_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.'
]);

sub notice_move {

    my ($dest, $text, $stripped) = @_;
    my $server = $dest->{server};

    return if (!$server || !($dest->{level} & MSGLEVEL_NOTICES) || $server->ischannel($dest->{target}));
  
    my $witem  = $server->window_item_find($dest->{target});
    my $awin = Irssi::active_win();

    return if $witem;

    $awin->print($text, MSGLEVEL_NOTICES);
  
    Irssi::signal_stop();
}

Irssi::signal_add('print text', 'notice_move');
Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'active_notice_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
