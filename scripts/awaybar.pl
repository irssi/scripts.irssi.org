# awaybar.pl -- initially built for Irssi 0.8.9
# thanks to mood.pl for practically allowing me
# to copy the approach..
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

        #my $format = $theme->format_expand("{sb_awaybar $away_reason}");
        my $format = "{sb Away: $away_reason}";

        $item->{min_size} = $item->{max_size} = length($away_reason);
        $item->default_handler($get_size_only, $format, 0, 1);
    } else {
        $item->{min_size} = $item->{max_size} = 0;
    }
}

sub awaybar_redraw {
    Irssi::statusbar_items_redraw('awaybar');
}
