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

$VERSION = "0.10";

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'away_hilight_notice.pl',
    description => 'This script will notice your away message to the person who just hilighted you.',
    license     => 'GNU General Public License',
    url         => 'http://irssi.hauwaerts.be/away_hilight_notice.pl',
    changed     => 'Wed Dec 31 15:37:24 2003',
);

## Comments and remarks.
#
# This script uses settings. The default time between notices sent to the
# same person are 3600 seconds or once an hour. Use /SET to change the
# timeout value.
#
#    Setting: away_hilight_notice_timeout
#
##

Irssi::theme_register([
    'away_hilight_notice_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.'
]);

my %lasthilight;
my $timeout;
my $ctimeout;

sub away_hilight_notice {

    my ($dest, $text, $stripped) = @_;
    my $server = $dest->{server};
    my ($hilight) = Irssi::parse_special('$;');

    return if (!$server || !($dest->{level} & MSGLEVEL_HILIGHT) || ($dest->{level} & (MSGLEVEL_MSGS|MSGLEVEL_NOTICES|MSGLEVEL_SNOTES|MSGLEVEL_CTCPS|MSGLEVEL_ACTIONS|MSGLEVEL_JOINS|MSGLEVEL_PARTS|MSGLEVEL_QUITS|MSGLEVEL_KICKS|MSGLEVEL_MODES|MSGLEVEL_TOPICS|MSGLEVEL_WALLOPS|MSGLEVEL_INVITES|MSGLEVEL_NICKS|MSGLEVEL_DCC|MSGLEVEL_DCCMSGS|MSGLEVEL_CLIENTNOTICE|MSGLEVEL_CLIENTERROR)));

    if ($server->{usermode_away}) {

        if (!$lasthilight{lc($hilight)}{'last'}) {
      	    $lasthilight{lc($hilight)}{'last'} = time();
      	    $server->command("^NOTICE $hilight I'm sorry, but I'm away ($server->{away_reason})");
            return;
         }

        $timeout = time() - $lasthilight{lc($hilight)}{'last'};
        $ctimeout = Irssi::settings_get_str('away_hilight_notice_timeout');

        if ($timeout > $ctimeout) {
            $lasthilight{lc($hilight)}{'last'} = time();
            $server->command("^NOTICE $hilight I'm sorry, but I'm away ($server->{away_reason})");
        }
    }
}

sub clear_associative_array {

    my ($server) = @_;

    if (!$server->{usermode_away}) {
        %lasthilight = ();
    }
}

Irssi::signal_add('print text', 'away_hilight_notice');
Irssi::signal_add('away mode changed', 'clear_associative_array');
Irssi::settings_add_str('away', 'away_hilight_notice_timeout' => 3600);
Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'away_hilight_notice_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
