# fullrain.pl - Irssi script for colorized fullwidth text
# Copyright (C) 2017 Kenneth B. Jensen <kenneth@jensen.cf>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 as 
# published by the Free Software Foundation.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


use strict;
use warnings;
use Encode qw(decode);
use Irssi qw(command_bind active_win);

our $VERSION = '1.0.0';
our %IRSSI = (
	authors     => 'kjensenxz',
	contact     => 'kenneth@jensen.cf',
	name        => 'fullrain',
	url         => 'http://github.com/kjensenxz',
	description => 'Prints colorized fullwidth text',
	license     => 'GNU GPLv3',

	# code borrowed from scripts:
	# 'fullwidth' by prussian <genunrest@gmail.com> 
	# http://github.com/GeneralUnRest/ || Apache 2.0 License
	# 'rainbow' by Jakub Jankowski <shasta@atn.pl>
	# http://irssi.atn.pl/ || GNU GPLv2 (or later) License
);
# colors
#  0 white
#  4 light red
#  8 yellow
#  9 light green
# 11 light cyan
# 12 light blue
# 13 light magenta
my @COLORS = (0, 4, 8, 9, 11, 12, 13);

sub make_fullcolor {
	my $str = decode('UTF-8', $_[0]);
	my $newstr = q();

	my $color = 0;
	my $prev = $color;
	foreach my $char (split //xms, $str) {
		if ($char =~ /\s/xms) {
			$newstr .= q( );
		}
		else {
			my $nchar = ord $char;
			while (($color = int rand scalar @COLORS) == $prev) {};
			$prev = $color;
			$newstr .= "\003" . $COLORS[$prev];
			# check if char is printing nonwhite ascii
			if ($nchar > ord ' ' && $nchar <= ord '~') {
				$newstr .= chr $nchar + 65_248;
			}
			else {
				$newstr .= $char . ' ';
			}
		}
	}
	return $newstr;
}

command_bind(rfsay => sub {
	my $say = make_fullcolor($_[0]);
	active_win->command("say $say"); #say what you want
	# but don't play games with my affection
});

command_bind(rfme => sub {
	my $say = make_fullcolor($_[0]);
	active_win->command("/me $say");
});

command_bind(rftopic => sub {
	my $say = make_fullcolor($_[0]);
	active_win->command("/topic $say");
});

command_bind(rfaway => sub {
	my $say = make_fullcolor($_[0]);
	active_win->command("/away $say");
});

1;

# changelog:
# 2017/03/28 (1.0.0): initial release
