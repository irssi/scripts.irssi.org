# Internet Time statusbar item.
# See http://www.timeanddate.com/time/internettime.html

# /STATUSBAR window ADD itime

use strict;
use Irssi::TextUI;

use vars qw($VERSION %IRSSI $itime_ratio $current_itime);

$VERSION = '0.9';
%IRSSI = (
    authors     => 'Johan "Ion" Kiviniemi',
    contact     => 'ion at hassers.org',
    name        => 'itime',
    description =>
'Internet Time statusbar item. See http://www.timeanddate.com/time/internettime.html',
    license => 'Public Domain',
    url     => 'http://ion.amigafin.org/scripts/',
    changed => 'Tue Mar 12 22:20 EET 2002',
);

$itime_ratio   = 1000 / 86400;
$current_itime = get_itime();

sub get_itime {
    my ($s, $m, $h) = gmtime time + 3600;
    my $itime = $itime_ratio * (3600 * $h + 60 * $m + $s);
    return sprintf '@%03d', int $itime;
}

sub itime {
    my ($item, $get_size_only) = @_;
    $item->default_handler($get_size_only, undef, $current_itime, 1);
}

sub refresh_itime {
    my $itime = get_itime();
    return if $itime eq $current_itime;
    $current_itime = $itime;
    Irssi::statusbar_items_redraw('itime');
}

Irssi::statusbar_item_register('itime', '{sb $0}', 'itime');
Irssi::statusbars_recreate_items();
Irssi::timeout_add(5000, 'refresh_itime', undef);
