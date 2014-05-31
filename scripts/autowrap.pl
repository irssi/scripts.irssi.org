use strict;
use Text::Wrap;

use vars qw($VERSION %IRSSI);
$VERSION = '2007031900';
%IRSSI = (
	authors		=> 'Bitt Faulk',
	contact		=> 'lxsfx3h02@sneakemail.com',
	name		=> 'autowrap',
	description	=> 'Automatically wraps long sent messages into multiple shorter sent messages',
	license		=> 'BSD',
	url		=> 'none',
	modules		=> 'Text::Wrap',
);

sub event_send_text () {
	my ($line, $server_rec, $wi_item_rec) = @_;
	my @shortlines;
	if (length($line) <= 400) {
		return;
	} else {
		# split line, recreate multiple "send text" events
		local($Text::Wrap::columns) = 400;
		@shortlines = split(/\n/,wrap('','',$line));
		foreach (@shortlines) {
			if ($_ >= 400) {
				Irssi::print("autowrap: unable to split long line.  sent as-is");
				return;
			}
		}
		foreach (@shortlines) {
			Irssi::signal_emit('send text', $_,  $server_rec, $wi_item_rec);
		}
		Irssi::signal_stop();
	}
}

Irssi::signal_add_first('send text', "event_send_text");
