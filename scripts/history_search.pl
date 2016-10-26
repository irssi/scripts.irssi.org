# Search within your typed history as you type (like ctrl-R in bash)
# Usage:
# * First do: /bind ^R /history_search
# * Then type ctrl-R and type what you're searching for
# * Optionally, you can bind something to "/history_search -forward" to go forward in the results

# Copyright 2007-2009  Wouter Coekaerts <coekie@irssi.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

use strict;
use Irssi 20070804;
use Irssi::TextUI;

use vars qw($VERSION %IRSSI);
$VERSION = '2.0';
%IRSSI = (
    authors     => 'Wouter Coekaerts',
    contact     => 'coekie@irssi.org',
    name        => 'history_search',
    description => 'Search within your typed history as you type (like ctrl-R in bash)',
    license     => 'GPLv2 or later',
    url         => 'http://wouter.coekaerts.be/irssi/',
    changed     => '17/01/09'
);

# is the searching enabled?
my $enabled = 0;
# the typed text (the query) last time a key was pressed
my $prev_typed;
# the position in the input of where the typed text started.
# everything before it is not typed by the user but added by this script as part of the result
my $prev_startpos;
# the current list of matches
my @matches;
# at what place are we in @matches?
my $current_match_index;

Irssi::command_bind('history_search', sub {
	my ($data, $server, $item) = @_;
	if ($data !~ /^ *(-forward)? *$/) {
		Irssi::print("history_search: Unknown arguments: $data");
		return;
	}
	my $forward = $1 eq '-forward';
	
	if (! $enabled) {
		$enabled = 1;
		$prev_typed = '';
		$prev_startpos = 0;
		@matches = ();
		$current_match_index = -1;
	} else {
		if ($forward) {
			if ($current_match_index + 1 < scalar(@matches)) {
				$current_match_index++;
			}
		} else { # backwards
			if ($current_match_index > 0) {
				$current_match_index--;
			}
		}
	}
});

Irssi::signal_add_last 'gui key pressed' => sub {
	my ($key) = @_;
	
	if ($key == 10 || $key == 27) { # enter or escape
		$enabled = 0;
	}

	return unless $enabled;
	
	# get the content of the input line
	my $prompt = Irssi::parse_special('$L');
	my $pos = Irssi::gui_input_get_pos();
	
	# stop if the cursor is before the position where the typing started (e.g. if user pressed backspace more than he typed characters)
	if ($pos < $prev_startpos) {
		$enabled = 0;
		return;
	}
	
	# get the part of the input line that the user typed (strip the part before and after which this script added)
	my $typed = substr($prompt, $prev_startpos, ($pos-$prev_startpos));
	
	if ($typed ne $prev_typed) { # something changed
		# find matches
		find_matches($typed);
		
		# start searching from the end again
		$current_match_index = scalar(@matches) - 1;
	}
	
	# if nothing was found, just show what the user typed
	# else, show the current match
	my $result = ($current_match_index == -1) ? $typed : $matches[$current_match_index];
		
	# update the input line
	my $startpos = index(lc($result), lc($typed));
	Irssi::gui_input_set($result);
	Irssi::gui_input_set_pos($startpos + length($typed));

	# remember for next time
	$prev_typed = $typed;
	$prev_startpos = $startpos;
};

# find matches for the given user-typed text, and put it in @matches
sub find_matches($) {
	my ($typed) = @_;
	if (Irssi::version() > 20090117) {
		$typed = lc($typed);
		my @history;
		if ($prev_typed ne '' && index($typed, lc($prev_typed)) != -1) { # previous typed plus more
			@history = @matches; # only search in previous results
		} else {
			@history = Irssi::active_win->get_history_lines();
		}
		@matches = ();
		for my $history_line (@history) {
			my $startpos = index(lc($history_line), $typed);
			if ($startpos != -1) {
				push @matches, $history_line;
			}
		}
	} else { # older irssi version, can only get the last match
		@matches = ();
		my $last_match = Irssi::parse_special('$!' . $typed . '!');
		if ($last_match ne '') {
			push @matches, $last_match;
		}
	}
}
