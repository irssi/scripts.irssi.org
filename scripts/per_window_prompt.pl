# Keeps a prompt per window.

# Copyright 2007  Wouter Coekaerts <coekie@irssi.org>
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
$VERSION = '1.0';
%IRSSI = (
    authors     => 'Wouter Coekaerts',
    contact     => 'coekie@irssi.org',
    name        => 'per_window_prompt',
    description => 'Keeps a prompt per window',
    license     => 'GPLv2 or later',
    url         => 'http://wouter.coekaerts.be/irssi/',
    changed     => '04/08/07'
);

my %prompts;

my $in_command = 0;
my $win_before_command;
my $win_before_command_deleted;
my $unloading = 0;

# key to use to identify window
sub winkey {
	my ($win) = @_;
	return defined($win) ? $win->{'_irssi'} : 0;
}

sub get_prompt {
	return {
			text => Irssi::parse_special('$L'),
			pos => Irssi::gui_input_get_pos()
	};
}

sub set_prompt {
	my ($prompt) = @_;
	if (defined($prompt)) {
		Irssi::gui_input_set($prompt->{text});
		Irssi::gui_input_set_pos($prompt->{pos});
	} else {
		Irssi::gui_input_set('');
	}	
}

Irssi::signal_add_last 'window changed' => sub {
	my ($win, $oldwin)= @_;
	if (!$in_command) {
		if ($oldwin) {
			$prompts{winkey($oldwin)} = get_prompt();
		}
		set_prompt($prompts{winkey($win)});
	}
};

sub UNLOAD {
	$unloading = 1;
}

# needed when switching windows by command
Irssi::signal_add_first 'gui key pressed' => sub {
	my ($key) = @_;
	
	if ($key == 10 && ! $in_command) {
		$win_before_command = winkey(Irssi::active_win);
		$win_before_command_deleted = 0;
		$in_command = 1;
		Irssi::signal_continue(@_);
		if ($unloading) {
			return; # avoid crash when unloading by command
		}
		$in_command = 0;
		my $win_after_command = winkey(Irssi::active_win);
		
		if ($win_before_command != $win_after_command) {
			if (! $win_before_command_deleted) {
				$prompts{$win_before_command} = get_prompt();
			}
			set_prompt($prompts{$win_after_command})
		}
	}
};

Irssi::signal_add_first 'window destroyed' => sub {
	my ($win) = @_;
	delete $prompts{winkey($win)};
	if ($win_before_command == winkey($win)) {
		$win_before_command_deleted = 1;
	}
};
