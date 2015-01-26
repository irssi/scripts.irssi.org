# trackbar.pl
#
# Track what you read last when switching to a window.
#
#    Copyright (C) 2003  Peter Leurs
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
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# 
# This little script will do just one thing: it will draw a line each time you
# switch away from a window. This way, you always know just upto where you've
# been reading that window :) It also removes the previous drawn line, so you
# don't see double lines.
#
# Usage: 
#
#     The script works right out of the box, but if you want you can change
#     the working by /set'ing the following variables:
#
#     trackbar_string            The characters to repeat to draw the bar
#                                    "---" => U+2500 => a line
#                                    "===" => U+2550 => a double line
#                                    "___" => U+2501 => a wide line
#                                    "# #" => U+25ad.U+0020 => a white rectangle and a space
#     trackbar_style             The style for the bar, %r is red for example
#                                See formats.txt that came with irssi
#     trackbar_hide_windows      Comma seperated list of window names where the
#                                trackbar should not be drawn.
#     trackbar_timestamp         Prints a timestamp at the start of the bar
#     trackbar_timestamp_styled  When enabled, the timestamp respects
#                                trackbar_style
#
#     /tb or /tb scroll is a command that will scroll to trackbar.
#
#     /tb mark is a command that will redraw the line at the bottom.  However!
#     This requires irssi version after 20021228.  otherwise you'll get the
#     error redraw: unknown command, and your screen is all goofed up :)
#
#     /upgrade & buf.pl notice: This version tries to remove the trackbars
#     before the upgrade is done, so buf.pl does not restore them, as they are
#     not removeable afterwards by trackbar.  Unfortunately, to make this work,
#     trackbar and buf.pl need to be loaded in a specific order. Please
#     experiment to see which order works for you (strangely, it differs from
#     configuration to configuration, something I will try to fix in a next
#     version) 
#
# Authors:
#   - Main maintainer & author: Peter 'kinlo' Leurs
#   - Many thanks to Timo 'cras' Sirainen for placing me on my way
#   - on-upgrade-remove-line patch by Uwe Dudenhoeffer
#   - trackbar resizing by Michiel Holtkamp (02 Jul 2012)
#   - scroll to trackbar, window excludes, and timestamp options by Nico R.
#     Wohlgemuth (22 Sep 2012)
#
# Version history:
#  1.7: - Added /tb scroll, trackbar_hide_windows, trackbar_timestamp_timestamp
#         and trackbar_timestamp_styled
#  1.6: - Work around Irssi resize bug, please do /upgrade! (see below)
#  1.5: - Resize trackbars in all windows when terminal is resized
#  1.4: - Changed our's by my's so the irssi script header is valid
#       - Removed utf-8 support.  In theory, the script should work w/o any
#         problems for utf-8, just set trackbar_string to a valid utf-8 character
#         and everything *should* work.  However, this script is being plagued by
#         irssi internal bugs.  The function Irssi::settings_get_str does NOT handle
#         unicode strings properly, hence you will notice problems when setting the bar
#         to a unicode char.  For changing your bar to utf-8 symbols, read the line sub.
#  1.3: - Upgrade now removes the trackbars. 
#       - Some code cleanups, other defaults
#       - /mark sets the line to the bottom
#  1.2: - Support for utf-8
#       - How the bar looks can now be configured with trackbar_string 
#         and trackbar_style
#  1.1: - Fixed bug when closing window
#  1.0: - Initial release
#
# Contacts
#  https://github.com/mjholtkamp/irssi-trackbar
#
# Known bugs:
#  - if you /clear a window, it will be uncleared when returning to the window
#  - changing the trackbar style is only visible after returning to a window
#    however, changing style/resize takes in effect after you left the window.
#
# Whishlist/todo:
#  - instead of drawing a line, just invert timestamp or something, 
#    to save a line (but I don't think this is possible with current irssi)
#  - <@coekie> kinlo: if i switch to another window, in another split window, i 
#              want the trackbar to go down in the previouswindow in  that splitwindow :)
#  - < bob_2> anyway to clear the line once the window is read?
#  - < elho> kinlo: wishlist item: a string that gets prepended to the repeating pattern
#
# BTW: when you have feature requests, mailing a patch that works is the fastest way
# to get it added :p

# IRSSI RESIZE BUG:
# when resizing from a larger window to a smaller one, the width of the
# trackbar causes some lines at the bottom not to be shown. This only happens
# if the trackbar was not the last line. This glitch can be 'fixed' by
# resetting the trackbar to the last line (e.g. by switching to another window
# and back) and then resize twice (e.g. to a bigger size and back). Of course,
# this is not convenient for the user.
# This script works around this problem by printing not one, but two lines and
# then removing the second line. My guess is that irssi does something to the
# previous line (or the line cache) whenever a line is 'completed' (i.e. the
# EOL is sent). When only one line is printed, it is not 'completed', but when
# printing the second line, the first line is 'completed'. The second line is
# still not completed, but since we delete it straight away, it doesn't matter.
#
# Some effects from older versions (<1.6) of trackbar.pl can still screw up your
# buffer so we recommend to restart your irssi, or do an "/upgrade". After
# installing this version of trackbar.pl

use strict;
use 5.6.1;
use Irssi;
use Irssi::TextUI;
use POSIX qw(strftime);
use utf8;
use vars qw(%IRSSI $VERSION);
$VERSION = "1.7";

%IRSSI = (
    authors     => "Peter 'kinlo' Leurs, Uwe Dudenhoeffer, " .
                   "Michiel Holtkamp, Nico R. Wohlgemuth",
    contact     => "irssi-trackbar\@supermind.nl",
    name        => "trackbar",
    description => "Shows a bar where you've last read a window",
    license     => "GPLv2",
    url         => "http://github.com/mjholtkamp/irssi-trackbar/",
    changed     => "Tue, 22 Sep 2012 14:33:31 +0000",
);

my %config;

my $screen_resizing = 0;   # terminal is being resized

# This could be '(status)' if you want to hide the status window
Irssi::settings_add_str('trackbar', 'trackbar_hide_windows' => '');
$config{'trackbar_hide_windows'} = Irssi::settings_get_str('trackbar_hide_windows');

Irssi::settings_add_str('trackbar', 'trackbar_string' => '-');
$config{'trackbar_string'} = Irssi::settings_get_str('trackbar_string');

Irssi::settings_add_str('trackbar', 'trackbar_style' => '%K');
$config{'trackbar_style'} = Irssi::settings_get_str('trackbar_style');

Irssi::settings_add_bool('trackbar', 'trackbar_timestamp' => 0);
$config{'trackbar_timestamp'} = Irssi::settings_get_bool('trackbar_timestamp');

Irssi::settings_add_bool('trackbar', 'trackbar_timestamp_styled' => 1);
$config{'trackbar_timestamp_styled'} = Irssi::settings_get_bool('trackbar_timestamp_styled');

$config{'timestamp_format'} = Irssi::settings_get_str('timestamp_format');

Irssi::signal_add(
    'setup changed' => sub {
        $config{'trackbar_string'} = Irssi::settings_get_str('trackbar_string');
        $config{'trackbar_style'}  = Irssi::settings_get_str('trackbar_style');
        $config{'trackbar_hide_windows'} = Irssi::settings_get_str('trackbar_hide_windows');
        $config{'trackbar_timestamp'} = Irssi::settings_get_bool('trackbar_timestamp');
        $config{'trackbar_timestamp_styled'} = Irssi::settings_get_bool('trackbar_timestamp_styled');
        $config{'timestamp_format'} = Irssi::settings_get_str('timestamp_format');
        if ($config{'trackbar_style'} =~ /(?<!%)[^%]|%%|%$/) {
            Irssi::print(
                "trackbar: %RWarning!%n 'trackbar_style' seems to contain "
                . "printable characters. Only use format codes (read "
                . "formats.txt).", MSGLEVEL_CLIENTERROR);
        }
    }
);

Irssi::signal_add(
    'window changed' => sub {
        my (undef, $oldwindow) = @_;

        my @hidden = split(',', $config{'trackbar_hide_windows'});

        # remove whitespace around window names
        s{^\s+|\s+$}{}g foreach @hidden;

        if ($oldwindow && !($oldwindow->{'name'} ~~ @hidden)) {
            my $line = $oldwindow->view()->get_bookmark('trackbar');
            $oldwindow->view()->remove_line($line) if defined $line;
            $oldwindow->print(line($oldwindow->{'width'}), MSGLEVEL_NEVER);
            $oldwindow->view()->set_bookmark_bottom('trackbar');
        }
    }
);

# terminal resize code inspired on nicklist.pl
sub sig_terminal_resized {
	if ($screen_resizing) {
		# prevent multiple resize_trackbars from running
		return;
	}
	$screen_resizing = 1;
	Irssi::timeout_add_once(10,\&resize_trackbars,[]);
}

sub resize_trackbars {
	my $active_win = Irssi::active_win();
	for my $window (Irssi::windows) {
		next unless defined $window;
		my $line = $window->view()->get_bookmark('trackbar');
		next unless defined $line;

		# first add new trackbar line, then remove the old one. For some reason
		# this works better than removing the old one, then adding a new one
		$window->print_after($line, MSGLEVEL_NEVER, line($window->{'width'}));
		my $next = $line->next();
		$window->view()->set_bookmark('trackbar', $next);
		$window->view()->remove_line($line);

		# This hack exists to work around a bug: see IRSSI RESIZE BUG above.
		# Add a line after the trackbar and delete it immediately
		$window->print_after($next, MSGLEVEL_NEVER, line(1));
		$window->view()->remove_line($next->next);
	}
	$active_win->view()->redraw();
	$screen_resizing = 0;
}

Irssi::signal_add('terminal resized' => \&sig_terminal_resized);

sub line {
    my $width  = shift;
    my $string = $config{'trackbar_string'};

    my $tslen = 0;

    if ($config{'trackbar_timestamp'}) {
        $tslen = int(1 + length $config{'timestamp_format'});
    }

    if (!defined($string) || $string eq '') {
        $string = '-';
    }

    # There is a bug in (irssi's) utf-8 handling on config file settings, as you 
    # can reproduce/see yourself by the following code sniplet:
    #
    #   my $quake = pack 'U*', 8364;    # EUR symbol
    #   Irssi::settings_add_str 'temp', 'temp_foo' => $quake;
    #   $a= length($quake);
    #       # $a => 1
    #   $a= length(Irssi::settings_get_str 'temp_foo');
    #       # $a => 3
	#	$a= utf8::is_utf8(Irssi::settings_get_str 'temp_foo');
	#		# $a => false

	utf8::decode($string);

	if ($string =~ m/---/) {
		$string = pack('U*', 0x2500);
	}

	if ($string =~ m/===/) {
		$string = pack('U*', 0x2550);
	}

	if ($string =~ m/___/) {
		$string = pack('U*', 0x2501);
	}

	if ($string =~ m/# #/) {
		$string = pack('U*', 0x25ad)." ";
	}

    my $length = length $string;

    my $times = $width / $length - $tslen;
    $times = int(1 + $times) if $times != int($times);
    $string =~ s/%/%%/g;

    if ($tslen) {
        # why $config{'timestamp_format'} won't work here?
        my $ts = strftime(Irssi::settings_get_str('timestamp_format')." ", localtime);

        if ($config{'trackbar_timestamp_styled'}) {
            return $config{'trackbar_style'} . $ts . substr($string x $times, 0, $width);
        } else {
            return $ts . $config{'trackbar_style'} . substr($string x $times, 0, $width);
        }
    } else {
		return $config{'trackbar_style'} . substr($string x $times, 0, $width);
    }
}

# Remove trackbars on upgrade - but this doesn't really work if the scripts are not loaded in the correct order... watch out!

Irssi::signal_add_first('session save' => sub {
	for my $window (Irssi::windows) {
		next unless defined $window;
		my $line = $window->view()->get_bookmark('trackbar');
		$window->view()->remove_line($line) if defined $line;
	}
}
);

sub cmd_mark {
    my $window = Irssi::active_win();
    my $line = $window->view()->get_bookmark('trackbar');
    $window->view()->remove_line($line) if defined $line;
    $window->print(line($window->{'width'}), MSGLEVEL_NEVER);
    $window->view()->set_bookmark_bottom('trackbar');
    Irssi::active_win()->view()->redraw();
}

# mark all visible windows with a line
sub cmd_mark_visual {
    my $w= Irssi::active_win();
	my $refs =$w->{refnum};
	my $refa;

	cmd_mark();

	do {
        Irssi::command('window down');
    	$w= Irssi::active_win();
		$refa =$w->{refnum};

		if ($refs != $refa) {
			cmd_mark();
		}

	} while ($refs != $refa)
}

#  /tb or /trackbar
sub cmd_tb {
   if ($#_ >=0 ) {
       my $sc = shift @_;
	   $sc =~ s/\s+$//;

       if ($sc eq "mark") {
          cmd_mark();
       } elsif ($sc eq "help") {
           cmd_help("trackbar");
       } elsif ($sc eq "vmark") {
		   cmd_mark_visual();
       } else {
           cmd_scroll();
       }
   }
}

sub cmd_scroll {
	my $window = Irssi::active_win();
	my $line = $window->view()->get_bookmark('trackbar');
	$window->view()->scroll_line($line) if defined $line;
}

sub cmd_help {
   my $help = <<HELP;
/trackbar or /tb
    /tb mark
       - Set the trackbar of the current window at the bottom
    /tb vmark
       - Set the trackbar on all visible windows
    /tb scroll
       - Scroll to where the trackbar is right now
    /tb help
       - this help
    /tb
       - Same as /tb scroll
HELP
   if ($_[0] =~ m/^tb/ or $_[0] =~ m/^trackbar/ ) {
      Irssi::print($help, MSGLEVEL_CLIENTCRAP);
      Irssi::signal_stop;
   }
}

Irssi::command_bind('tb', 'cmd_tb');
Irssi::command_bind('tb help', 'cmd_tb');
Irssi::command_bind('tb mark', 'cmd_tb');
Irssi::command_bind('tb scroll', 'cmd_tb');
Irssi::command_bind('tb vmark', 'cmd_tb');

Irssi::command_bind('trackbar', 'cmd_tb');
Irssi::command_bind('trackbar help', 'cmd_tb');
Irssi::command_bind('trackbar mark', 'cmd_tb');
Irssi::command_bind('trackbar scroll', 'cmd_tb');
Irssi::command_bind('trackbar vmark', 'cmd_tb');

Irssi::command_bind('mark', 'cmd_mark');
#Irssi::command_bind('scroll', 'cmd_scroll');
Irssi::command_bind('help', 'cmd_help');
