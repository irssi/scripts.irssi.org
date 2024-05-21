use strict;
use warnings;

our $VERSION = '0.2'; # e53c766132d8f3a
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'conceal',
    description => 'conceals passwords on the input line',
    license     => 'ISC',
   );

use Encode ();
use Irssi;
use Irssi::TextUI;
die "This script requires Irssi 1.2.0\n"
    unless Irssi->can('gui_input_set_extent');

my $utf8;
my $cmdchars;

sub check_input {
    my $inputline = Irssi::parse_special('$L');
    if ($utf8) {
        Encode::_utf8_on($inputline);
    }
    Irssi::gui_input_set_extent(length $inputline, '%n');
    my $c = qr/^[\Q$cmdchars\E]/;
    for ($inputline) {
	if (m{${c}(?:(?:
		      (?:msg|quote) \s+ (?:nickserv|ns|\w\@\S+)
		    |quote) \s+ )?
	      (?: id(?:ent(?:ify)?)?
	        | (?:auth|login) \s+ (?:\S+) ) \s+ (\S+) (?:\s|$)}ix
	   ) {
	    Irssi::gui_input_clear_extents($-[1], $+[1] - $-[1]);
	    Irssi::gui_input_set_extents($-[1], $+[1] - $-[1], '%c%6', '%n');
	}
    }
}

sub setup_changed {
    $utf8 = lc Irssi::settings_get_str('term_charset') eq 'utf-8';
    $cmdchars = Irssi::settings_get_str('cmdchars');
}

setup_changed();
Irssi::signal_add('setup changed', 'setup_changed');
Irssi::signal_add_last('gui key pressed', 'check_input');
