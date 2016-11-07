#!/usr/bin/perl
# mirc_colour_popup irssi module
#
# Shows a mIRC-style colour popup when you hit ^C.
#
# usage:
#
# after loading the script, add the statusbar item somewhere convenient:
#   /statusbar prompt add -before input -alignment right colours
#

use strict;
use warnings;
use Irssi;
use Irssi::TextUI;
use vars qw($VERSION %IRSSI);

$VERSION = "1.1"; # 6c78efbfcb07c71
%IRSSI = (
    authors     => "Michael Kowalchuk, Nei",
    contact     => "michael.kowalchuk\@gmail.com",
    name        => "mirc_colour_popup",
    description => "Shows a mIRC-style colour popup when you hit ^C.",
    license     => "Public Domain",
);


my $vis;
my ($efg, $ebg) = (-1, -1);
my $ext_colour = Irssi::version >= 20140701;

my @colours = ('W','k','b','g','R','r','m','y','Y','G','c','C','B','P','K','w');

if ($ext_colour) {
    @colours = (
	qw(0F 00 01 02 0C 04 05 06 0E 0A 03 0B 09 0D 08 07),
	qw(20 36 3C 26 16 1D 17 18 11 22 21 31),
	qw(30 46 4I 2C 1C 1J 1E 19 12 33 32 41),
	qw(40 56 5O 3I 1I 1X 1L 1H 13 45 43 51),
	qw(60 6C 6U 4U 1U 2Y 1Z 2N 15 5B 65 62),
	qw(67 6J 6V 5V 2V 3Y 2Z 3N 2B 5H 6B 69),
	qw(6L 6R 6X 5X 4X 4Y 4Z 4T 4N 5N 6N 6G),
	qw(10 7B 7D 7F 7H 7J 7M 7P 7S 7W 6Z),'n');
}

sub colours_sb {
	my ($item, $get_size_only) = @_;

	my $txt = '';
	if( $vis ) {
	    unless ($ext_colour) {
		$txt = join " ", map { "\%$colours[$_]$_" } 0 .. 15;
	    } else {
		my $sc = $ebg >= 0 && $ebg < 99 ? $ebg : $efg;
		$txt = join " ", map { '%'.($ebg>=0?'x':'X').$colours[$_].(0+$_).'%n' }
		    $sc >= 0 ? grep /^0?$sc/, '00' .. '99' : ('00' .. '15');
		$txt =~ s/%[xX]n/%n/g;
	    }
	}
	$item->default_handler($get_size_only, "%0{sb $txt}", '', 1);
}

Irssi::signal_add_last 'gui key pressed' => sub {
	my ($key) = @_;
	my $text = Irssi::parse_special('$L');
	if ((substr $text, 0, Irssi::gui_input_get_pos()) =~ /\cC(?:(\d{1,2})(?:,(\d{1,2}))?|\d{1,2}(,))?$/) {
		my ($fg, $bg) = ($1//-1, $2//($3?99:-1));
		if ($fg != $efg || $bg != $ebg || not $vis ) {
			$vis = 1;
			($efg, $ebg) = ($fg, $bg);
			Irssi::statusbar_items_redraw('colours');
		}
	}
	elsif( $vis ) {
		$vis = undef;
		($efg, $ebg) = (-1, -1);
		Irssi::statusbar_items_redraw('colours');
	}

};

Irssi::statusbar_item_register('colours', '$0', 'colours_sb');


