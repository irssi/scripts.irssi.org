#
#  winnum.pl
#	Goto a window by its reference number with /##
#
#
#  Commands:
#	/<window #>  Go to window
#

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '1.0.0';
%IRSSI = (
	authors         => 'Trevor "tee" Slocum',
	contact         => 'tslocum@gmail.com',
	name            => 'WinNum',
	description     => 'Goto a window by its reference number with /##',
	license         => 'GPLv3',
	url             => 'https://github.com/tslocum/irssi-scripts',
	changed         => '2014-05-01'
);

sub winnum_default_command {
	my ($command, $server) = @_;

	$command =~ s/^\s+//;
	$command =~ s/\s+$//;
	my $winnum = ($command =~ /(\w+)/)[0];

	if ($winnum =~ /^\d+$/) {
		my $window = Irssi::window_find_refnum($winnum);
		$window->set_active if $window;

		Irssi::signal_stop();
	}
}

Irssi::signal_add_first("default command", "winnum_default_command");

print $IRSSI{name} . ': v' .  $VERSION . ' loaded. Enter %9/<window #>%9 to goto a window.';
