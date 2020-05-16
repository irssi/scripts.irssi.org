#!/usr/bin/env false
##############################################################################
#
# mh_secureonlychan_489 v1.00
#
# Copyright (c) 2020  Michael Hansen
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
##############################################################################
#
# Fix for Irssi not fully supporting numeric 489 ERR_SECUREONLYCHAN.
#
# see https://github.com/irssi/irssi/issues/1193 for details about the issue.
#
# This script will display an error message in the status-window if you try to
# join a secure only channel without a secure connection. If you have the
# setting autoclose_windows off, you will still get the old raw message in the
# channel-window too.
#
# The script will die gracefully with a message if loaded in a version of
# Irssi that already have the source-code fixed (ABI version 29 or higher).
#
# see https://github.com/irssi/irssi/pull/1196 for details about the code fix.
#
##############################################################################

use v5.14.2;

use strict;
use warnings;

use Irssi ();

##############################################################################
#
# Irssi script header
#
##############################################################################

our $VERSION = '1.00';
our %IRSSI   =
(
	'name'        => 'mh_secureonlychan_489',
	'description' => 'Fix for Irssi not fully supporting numeric 489 ERR_SECUREONLYCHAN',
	'url'         => 'https://github.com/irssi/scripts.irssi.org/tree/master/scripts',
	'license'     => 'ISC/BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh (IRCnet)',
	'changed'     => '2020-05-16',
);

##############################################################################
#
# Irssi signal handler
#
##############################################################################

sub signal_server_event
{
	my ($serverrec, $data, $nick, $address) = @_;

	if (substr($data, 0, 3) eq '489')
	{
		(undef, undef, my $channelname, $data) = split(/ /, $data, 4);

		# numeric 489 is also used as ERR_VOICENEEDED, make sure this is an actual ERR_SECUREONLYCHAN
		if (substr($data, 0, 20) eq ':Cannot join channel')
		{
			$serverrec->printformat('(status)', Irssi::MSGLEVEL_CRAP(), 'joinerror_secureonlychan_489',  $channelname);
		}
	}

	return(1);
}

##############################################################################
#
# script on load
#
##############################################################################

# selfdestruct if Irssi is new enough to have the source-code fixed for this issue
if (Irssi::parse_special('$abiversion') and (Irssi::parse_special('$abiversion') >= 28))
{
	die('The script is not needed for this version of Irssi.' . "\n");
}

Irssi::theme_register(['joinerror_secureonlychan_489', 'Cannot join to channel {channel $0} (Secure clients only)']);
Irssi::signal_add_last("server event", 'signal_server_event');

1;

##############################################################################
#
# eof
#
##############################################################################
