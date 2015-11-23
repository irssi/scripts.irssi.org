use strict;
use Irssi ();
use vars qw($VERSION %IRSSI);

$VERSION = '1.0';

%IRSSI = (
	authors		=> 'Wouter Coekaerts',
	contact		=> 'coekie@irssi.org',
	name		=> 'messages_bottom',
	description	=> 'makes all window text start at the bottom of windows',
	license		=> q(send-me-beer-or-i'll-sue-you-if-you-use-it license),
	url		=> 'http://bugs.irssi.org/index.php?do=details&id=290'
);

##########################
#
# add this line to the very top of your ~/.irssi/startup file:
#
# 	script exec Irssi::active_win->print('\n' x Irssi::active_win->{'height'}, Irssi::MSGLEVEL_NEVER)
#
#

Irssi::signal_add_last
	'window created' => sub {
		my $win = shift;
		$win->print(
			"\n" x $win->{'height'},
			Irssi::MSGLEVEL_NEVER ) }
