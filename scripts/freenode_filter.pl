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

$VERSION = "0.06";

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'default.pl',
    description => 'This script will filter some Freenode IRCD (Dancer) servernotices.',
    license     => 'GNU General Public License',
    url         => 'http://irssi.hauwaerts.be/freenode_filter.pl',
    changed     => 'Wed Sep 17 23:00:11 CEST 2003',
);

Irssi::theme_register([
    'window_missing', '%_Warning%_: %R>>%n You are missing the %_FILTER%_ window. Use %_/WINDOW NEW HIDDEN%_ and %_/WINDOW NAME FILTER%_ to create it.',
    'filter', '{servernotice $0} $1',
    'freenode_filter_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.'
]);

sub check_filter {
    
    if (!Irssi::window_find_name("FILTER")) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'window_missing');
        return 0;
    }
    
    return 1;
}

sub parse_snote {

    my ($dest, $text) = @_;

    return if (($text !~ /^NOTICE/));

    if ($text =~ /Notice -- Client connecting:/) {
        filter_snote($dest, $text);
    } elsif ($text =~ /Notice -- Illegal nick/) {
        filter_snote($dest, $text);
    } elsif ($text =~ /Notice -- Invalid username:/) {
        filter_snote($dest, $text);
    } elsif ($text =~ /Notice -- X-line Warning/) {
        filter_snote($dest, $text);
    } elsif ($text =~ /Notice -- Kick from/) {
        filter_snote($dest, $text);
    } elsif ($text =~ /Notice -- Client exiting:/) {
        filter_snote($dest, $text);
    } elsif ($text =~ /Notice -- (.*) confirms kill/) {
        filter_snote($dest, $text);
    } elsif ($text =~ /Notice -- Remove from/) {
        filter_snote($dest, $text);
    } elsif ($text =~ /Notice -- Flooder (.*)/) {
        filter_snote($dest, $text);
    } elsif ($text =~ /Notice -- Received KILL message for/) {
        filter_snote($dest, $text);
    }
    
    if ($text =~ /Notice -- (.*) has removed the K-Line for:/) {
        active_snote($dest, $text);
    } elsif ($text =~ /Notice -- (.*) added K-Line for/) {
        active_snote($dest, $text);
    }
}

sub filter_snote {
    
    my ($server, $snote) = @_;
    my $win = Irssi::window_find_name("FILTER");
    my $ownnick = $server->{nick};
    
    $snote =~ s/^NOTICE $ownnick ://;

    if (!check_filter()) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'window_missing');
        return;
    }

    $win->printformat(MSGLEVEL_SNOTES, 'filter', $server->{real_address}, $snote);
    Irssi::signal_stop();
}

sub active_snote {
    
    my ($server, $snote) = @_;
    my $ownnick = $server->{nick};
    my $win = Irssi::active_win();
    
    $snote =~ s/^NOTICE $ownnick ://;

    $win->printformat(MSGLEVEL_SNOTES, 'filter', $server->{real_address}, $snote);
    Irssi::signal_stop();
}

check_filter();

Irssi::signal_add_first('server event', 'parse_snote');
Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'freenode_filter_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
