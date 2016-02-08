# awaybar.pl -- initially built for Irssi 0.8.9
# thanks to mood.pl for practically allowing me to copy the approach..
#
# Usage:
#
# Creating the away bar
# This assumes you have adv_windowlist, and that we add before it's window named 'awl_0'
# /set awl_shared_sbar RIGHT
# /statusbar window add -after lag -priority 10 -alignment right awl_shared
# /sbar awl_shared add -before awl_0 -alignment right awaybar
#
# Appearance
# To set the look and feel of the awaybar, and save it to your .theme file:
# /format sb_awaybar "%1%Waway: ${0-}"
# /save

use strict;
use Irssi;
use Irssi::TextUI;
use vars qw($VERSION %IRSSI);

$VERSION = "0.1.1";
%IRSSI = (
    authors     => 'Simon Shine',
    contact     => 'http://shine.eu.org/',
    name        => 'awaybar',
    description => 'Provides a menubar item with away message',
    license     => 'Public domain',
);

Irssi::statusbar_item_register('awaybar', 0, 'awaybar');
Irssi::signal_add('away mode changed', 'awaybar_redraw');

sub awaybar {
    my ($item, $get_size_only) = @_;
    my $away_reason = !Irssi::active_server() ? undef : Irssi::active_server()->{away_reason};

    if (defined $away_reason && length $away_reason) {
        my %r = ('\{' => '(',
                 '\}' => ')',
                 '%' => '%%',);
        $away_reason =~ s/$_/$r{$_}/g for (keys %r);

        my $format = "{sb_awaybar $away_reason}";

        $item->{min_size} = $item->{max_size} = length($away_reason);
        $item->default_handler($get_size_only, $format, 0, 1);
    } else {
        $item->{min_size} = $item->{max_size} = 0;
    }
}

sub awaybar_redraw {
    Irssi::statusbar_items_redraw('awaybar');
}
