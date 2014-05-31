use strict;
use vars qw($VERSION %IRSSI);

use Irssi qw(signal_add_last settings_add_bool settings_add_str
                             settings_get_bool settings_get_str);
$VERSION = '1.00';
%IRSSI = (
    authors     => 'Juerd',
    contact     => 'juerd@juerd.nl',
    name        => 'German Uppercased Tab Stuff',
    description => 'Adds the uppercased version of the tab completes',
    license     => 'Public Domain',
    url         => 'http://juerd.nl/irssi/',
    changed     => 'Sat May 18 21:40 CET 2002',
);

signal_add_last 'complete word' => sub {
    my ($complist, $window, $word, $linestart, $want_space) = @_;
    push @$complist, ucfirst $word;
}

