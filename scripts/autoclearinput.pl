#
#  autoclearinput.pl
#	Automatically clears pending input when you are away.
#
#
#  Settings:
#	/SET autoclear_sec <seconds>  (0 to disable, 30 by default)
#
#  Commands:
#	/AUTOCLEARED, /CLEARED  Retrieve the last cleared line of input
#

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '1.0.1';
%IRSSI = (
	authors         => 'Trevor "tee" Slocum',
	contact         => 'tslocum@gmail.com',
	name            => 'AutoClearInput',
	description     => 'Automatically clears pending input when you are away.',
	license         => 'GPLv3',
	url             => 'https://github.com/tslocum/irssi-scripts',
	changed         => '2014-05-13'
);

my ($autoclear_tag, $autoclear_last_input);

sub autoclear_key_pressed {
	return if (Irssi::settings_get_int("autoclear_sec") <= 0);

	if (defined($autoclear_tag)) {
		Irssi::timeout_remove($autoclear_tag);
	}

	$autoclear_tag = Irssi::timeout_add_once(Irssi::settings_get_int("autoclear_sec") * 1000, "autoclear_timeout", "");
}

sub autoclear_timeout {
	return if (Irssi::settings_get_int("autoclear_sec") <= 0);

	my $autoclear_current_input = Irssi::parse_special('$L');
	$autoclear_current_input =~ s/^\s+//;
	$autoclear_current_input =~ s/\s+$//;
	if ($autoclear_current_input ne "") {
		$autoclear_last_input = Irssi::parse_special('$L');
	}

	Irssi::gui_input_set("");
}

sub autoclear_retrieve {
	if (defined($autoclear_last_input)) {
		Irssi::timeout_add_once(50, "autoclear_retrieve_workaround", "");
	} else {
		Irssi::print($IRSSI{name} . ': No input has been cleared yet.');
	}
}

sub autoclear_retrieve_workaround {
	return if (!defined($autoclear_last_input));

	Irssi::gui_input_set($autoclear_last_input);
	Irssi::gui_input_set_pos(length($autoclear_last_input));
}

Irssi::settings_add_int("misc", "autoclear_sec", 30);
Irssi::signal_add_last("gui key pressed", "autoclear_key_pressed");
Irssi::command_bind("autocleared", "autoclear_retrieve");
Irssi::command_bind("cleared", "autoclear_retrieve");

print $IRSSI{name} . ': v' .  $VERSION . ' loaded. Pending input ' .
	(Irssi::settings_get_int("autoclear_sec") > 0
	? ('will be cleared after %9' . Irssi::settings_get_int("autoclear_sec") . ' seconds%9 of idling.')
	: 'clearing is currently %9disabled%9.');
print $IRSSI{name} . ': Configure this delay with: /SET autoclear_sec <seconds>  [0 to disable]';
print $IRSSI{name} . ': Retrieve the last cleared line of input with: /CLEARED';
