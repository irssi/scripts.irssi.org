#!/usr/bin/perl
# mirc_colour_popup irssi module
#
# Shows a mIRC-style colour popup when you hit ^C.
#
# usage:
#
# after loading the script, add the statusbar item somewhere convenient: 
#   /statusbar window add -after barstart colours
#

use strict;
use Irssi;
use Irssi::TextUI;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
    authors     => "Michael Kowalchuk",
    contact     => "michael.kowalchuk\@gmail.com",
    name        => "mirc_colour_popup",
    description => "Shows a mIRC-style colour popup when you hit ^C.",
    license     => "Public Domain",
    changed     => "9.26.2008",
);


my $vis;

my @colours = ('W','k','b','g','R','r','m','y','Y','G','c','C','B','P','K','w');

sub colours_sb {
	my ($item, $get_size_only) = @_;

	my $txt;
	if( $vis ) {
		$txt = join " ", map { "\%$colours[$_]$_" } 0 .. 15;
	}
	$item->default_handler($get_size_only, "{sb $txt}", undef, 1);
}


Irssi::signal_add_last 'gui key pressed' => sub {
	my ($key) = @_;

	if( not $vis and $key eq 3 ) {
		$vis = 1;
		Irssi::statusbar_items_redraw('colours');
	}

	elsif( $vis and $key ne 3 ) {
		$vis = undef;
		Irssi::statusbar_items_redraw('colours');
	}

};

Irssi::statusbar_item_register('colours', undef, 'colours_sb');


