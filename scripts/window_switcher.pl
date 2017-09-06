# window_switcher: makes switching windows easy
#
# Usage:
# * Add the statusbar item:
#   /STATUSBAR window add window_switcher
# * Type /ws followed by a window number or part of a window or channel name.
# * When the right item is at the first place in the statusbar, press enter.
# * For faster usage, do "/BIND ^G multi erase_line;insert_text /ws ",
#    type ctrl-G, and start typing...

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
use Irssi;
use Irssi::TextUI;

use vars qw($VERSION %IRSSI);
$VERSION = '1.0';
%IRSSI = (
    authors     => 'Wouter Coekaerts',
    contact     => 'coekie@irssi.org',
    name        => 'window_switcher',
    description => 'makes switching windows easy',
    sbitems     => 'window_switcher',
    license     => 'GPLv2 or later',
    url         => 'http://wouter.coekaerts.be/irssi/',
    changed     => '29/07/07'
);

sub window_switcher_sb {
	my ($sbItem, $get_size_only) = @_;

	my $prompt = Irssi::parse_special('$L');
	my $cmdchars = Irssi::parse_special('$K');
	
	my $sb = '';
	
	if ($prompt =~ /^(.)ws (.+)$/i && index($cmdchars,$1) != -1) {
		my $arg = $2;
		my $wins = find_wins($arg);
		
		foreach my $win (@$wins) {
			$sb .= $win->{text} . ' ';
		}
		$sb =~ s/ $//;
	}
	
	$sbItem->default_handler($get_size_only, "{sb $sb}", undef, 1);
}

sub find_wins {
	my ($arg) = @_;
	my @wins;
	foreach my $window (Irssi::windows()) {
		my @items = $window->items();
		my $regex = qr/^(.*?)(\Q$arg\E)(.*)$/i;
		
		my $match = 0;
		my $text;
		my $refnumtext = $window->{refnum};
		my $itemname;
		
		if ($window->{refnum} eq $arg) {
			$match = 1;
			if ($window->{name} ne '') {
				$text = $window->{name};
			} elsif (scalar(@items) > 0) {
				$text = $items[0]->{visible_name};
			} else {
				$text = '';
			}
			$refnumtext = "%G$refnumtext%n";
		} elsif ($window->{name} =~ $regex) {
			($match, $text) = do_match($1, $2, $3);
		} else {
			foreach my $item (@items) {
				if ($item->{visible_name} =~ $regex) {
					($match, $text) = do_match($1, $2, $3);
					$itemname = $item->{name};
					last;
				}
			}
		}
		
		if ($match) {
			push @wins, {
				match => 1000 * $match + $window->{refnum},
				refnum => $window->{refnum},
				text => "$refnumtext:$text",
				itemname => $itemname
			};
		}
	}
	
	@wins = sort {$a->{match} <=> $b->{match}} @wins;
	return \@wins;
}

sub do_match {
	my ($begin, $mid, $end) = @_;
	my $match;
	if ($begin eq '' || $begin eq '#') {
		$match = ($end eq '') ? 2 : 3;
	} else {
		$match = 4;
	}
	return ($match, "%g$begin%G$mid%g$end%n");
}

Irssi::command_bind('ws', sub {
	my ($data, $server, $win) = @_;
	my $wins = find_wins($data);
	if (scalar(@$wins) > 0) {
		my $win = $wins->[0];
		Irssi::command('window goto ' . $win->{refnum});
		if (defined($win->{itemname})) {
			Irssi::command('window item goto ' . $win->{itemname});
		}
	}
});

Irssi::statusbar_item_register ('window_switcher', 0, 'window_switcher_sb');

my $scheduled = 0;
Irssi::signal_add_last 'gui key pressed' => sub {
	unless ($scheduled) {
		$scheduled = 1;
		Irssi::timeout_add_once(100, sub {
			Irssi::statusbar_items_redraw ('window_switcher');
			$scheduled = 0;
		}, []);
	}
};
