use strict;

our $VERSION = '1.00';
our %IRSSI = (
    authors     => 'Juerd',
    contact     => '#####@juerd.nl',
    name        => 'autonickprefix',
    description => "Change 'nick: ' prefix if the nick is changed while you're still editing.",
    license     => 'Any OSI',
);

use Irssi::TextUI;
use Irssi qw(
    signal_add active_win settings_get_str parse_special 
    gui_input_get_pos gui_input_set gui_input_set_pos
);

signal_add 'nicklist changed' => sub {
    my ($chan, $newnick, $oldnick) = @_;
    $newnick = $newnick->{nick};

    # Ignore other channels than current
    my $viewing = active_win->{active} or return;
    $viewing->{_irssi} == $chan->{_irssi} or return;

    my $char  = settings_get_str 'completion_char';
    my $pos   = gui_input_get_pos;

    # Incomplete nick could be something else.
    $pos >= length("$oldnick$char") or return;

    my $delta = length($newnick) - length($oldnick);

    my $input = parse_special '$L';
    $input =~ s/^\Q$oldnick$char/$newnick$char/ or return;

    gui_input_set     $input;
    gui_input_set_pos $pos + $delta;
};
