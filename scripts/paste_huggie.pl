# Paste script for irssi
# (C) Simon Huggins 2002
# huggie@earth.li

# Reformat pasted text ready to paste onto channels.

# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc., 59
# Temple Place, Suite 330, Boston, MA 02111-1307  USA
#

use strict;

use vars qw($VERSION %IRSSI);
    
use Irssi 20020217.1542 (); # Version 0.8.1
$VERSION = "0.5";
%IRSSI = (
authors     => "Simon Huggins",
contact     => "huggie-irssi\@earth.li",
name        => "Paste",
description => "Paste reformats long pieces of text typically pasted into your client from webpages so that they fit nicely into your channel.  Width of client may be specified",
license     => "GPLv2",
url         => "http://the.earth.li/~huggie/irssi/",
changed     => "Sat Mar  9 10:59:49 GMT 2002",
);

use Irssi::Irc;
use Text::Wrap;
use Text::Tabs;
use POSIX qw(strftime);

=pod

=head1 paste.pl

B<paste.pl> - a script for irssi to manage reformatting before pasting to channels

To stop people pasting from webpages with very poor formatting this script
allows you to reformat as you paste.

=head1 USAGE

Load the script then create a new unused window and paste your text into it.
The defaults should be reasonable so then B</paste> will paste it in the
current window (either by saying it to the current channel, msging it to the
current recipient in a query window or by printing it up as client messages
in a blank window).

Try altering I<paste_width> (0 is the autoformatted default based on your
nick length) to affect the width of the pasted text.

Alter I<paste_prefix> to change the prefix added to each line (B</set -clear
paste_prefix> to remove it altogether).

Set I<paste_showbuf> to show the lines pasted into the buffer as you paste it.

=head1 AUTHOR

Send suggestions to Simon Huggins <huggie@earth.li>

=cut

my $pastewin;

BEGIN {
	$pastewin = Irssi::window_find_name('paste');
	if (!$pastewin) {
		Irssi::command("window new hide");
		Irssi::command("window name paste");
		$pastewin = Irssi::window_find_name('paste');
	}
	$pastewin->print(">>> Paste your buffer here to start <<<");
}

Irssi::settings_add_bool("paste","paste_showbuf",0);
Irssi::settings_add_int("paste","paste_width",0);
Irssi::settings_add_str("paste","paste_prefix",">> ");

{
	my @buffer;
	my $buf=0;
	my $last_ts;

sub event_send_text {
	my ($line, $server, $windowitem) = @_;

	return if $windowitem;

	if ($last_ts < (time() - 60)) {
		@buffer=();
		$buf= 0;
		$pastewin->print("Buffer cleared!");
	}
	$line =~ s/^\s+/ /;
	$line =~ s/\s+$/ /;
	$buffer[$buf] .= $line." ";

	if (!$line and $buffer[$buf] ne "") {
		$buf++;
	}

	if (Irssi::settings_get_bool("paste_showbuf")) {
		$pastewin->print($line,MSGLEVEL_CLIENTCRAP);
	}
	$last_ts = time();

	Irssi::signal_stop();
}

sub paste {
	my ($data, $server, $witem) = @_;

	my $offset;

	if (!$buf and $buffer[0] eq "") {
		$pastewin->print("No buffer to paste!",MSGLEVEL_HILIGHT);
		return;
	}

	my $anyoldwin = Irssi::active_win();
	my $width = Irssi::settings_get_int("paste_width");
	my $prefix = Irssi::settings_get_str("paste_prefix");
	my $prefixlen = length($prefix);
	if ($width > 0) {
		if ($width < 3+$prefixlen) {
			$pastewin->print("paste_width is too small ($width<".
					(3+$prefixlen).")!",
					MSGLEVEL_HILIGHT);
			return;
		}
		$Text::Wrap::columns = $width;
	} else {
		if ($server->{nick}) {
			$offset+=length($server->{nick})+$prefixlen+15;
		}
		$Text::Wrap::columns = $anyoldwin->{'width'} - $offset;
		if ($Text::Wrap::columns < 3+$prefixlen) {
			$pastewin->print("Width would be too small (".
					$Text::Wrap::columns."<".
					(3+$prefixlen).", window width was ".
					$anyoldwin->{'width'}.
					")!",
					MSGLEVEL_HILIGHT);
			return;
		}
	}

	foreach my $outbuffer (@buffer) {
		$outbuffer =~ s/^\s*//;
		$outbuffer =~ s/\s*$//;
		$outbuffer = wrap("","", $outbuffer);
		$outbuffer = expand($outbuffer);

		if ($witem) {
			foreach (split '\n', $outbuffer) {
				$witem->command("say ".$prefix.$_);
			}
		} else {
			foreach (split '\n', $outbuffer) {
				$anyoldwin->print($prefix.$_, MSGLEVEL_HILIGHT);
			}
		}
	}
}

sub clear_buffer {
	@buffer = ();
	$buf = 0;
	$pastewin->print("Buffer cleared!");
}

}

Irssi::signal_add_first("send text", "event_send_text");
Irssi::command_bind("paste", "paste");
Irssi::command_bind("clear_buffer", "clear_buffer");
