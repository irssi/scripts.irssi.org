##############################################################################
#
# mh_windowfill.pl v1.03 (20151125)
#
# Copyright (c) 2015  Michael Hansen
#
# Permission to use, copy, modify, and distribute this software
# for any purpose with or without fee is hereby granted, provided
# that the above copyright notice and this permission notice
# appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL
# THE AUTHOR BE LIABLE FOR  ANY SPECIAL, DIRECT, INDIRECT, OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
# NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
##############################################################################
#
# fill windows so scrolling starts bottom-up instead of top-down
#
# screenshots:
#	without script: http://picpaste.com/cfda32a34ea96e16dcb3f2d956655ff6.png
#	with script:    http://picpaste.com/e3b84ead852e3e77b12ed69383f1f80c.png
#
# history:
#	v1.03 (20151125)
#		cleaned up /clear
#		added view()->redraw() to windowfill()
#		optimistically changed url
#	v1.02 (20151118)
#		new windowfill routine
#		fixed /clear
#	v1.01 (20151116)
#		source cleanup
#	v1.00 (20151116)
#		initial release
#

use v5.14.2;

use strict;

##############################################################################
#
# irssi head
#
##############################################################################

use Irssi 20100403;
use Irssi::TextUI;

our $VERSION = '1.03';
our %IRSSI   =
(
	'name'        => 'mh_windowfill',
	'description' => 'fill windows so scrolling starts bottom-up instead of top-down (screenshots in source)',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'http://scripts.irssi.org',
);

##############################################################################
#
# script functions
#
##############################################################################

sub windowfill_fill
{
	my ($window) = @_;

	while ($window->view()->{'empty_linecount'})
	{
		$window->print('', MSGLEVEL_NEVER);
	}
}

sub windowfill_fill_all
{
	for my $window (Irssi::windows())
	{
		windowfill_fill($window);
	}
}

sub windowfill
{
	my ($window) = @_;

	#
	# fill window with empty lines and move already printed lines to the bottom
	#
	if ($window->view()->{'empty_linecount'})
	{
		my $line      = $window->view()->get_lines();
		my $linecount = 0;

		while ($line)
		{
			$linecount++;
			$line = $line->next();
		}

		windowfill_fill($window);

		$line = $window->view()->get_lines();

		while ($linecount)
		{
			my $linetext = $line->get_text(1);
			$line        = $line->next();
			$window->print($linetext, MSGLEVEL_NEVER);
			$window->view()->remove_line($line->prev());
			$linecount--;
		}

		$window->view()->redraw();
	}
}

sub windowfill_all
{
	for my $window (Irssi::windows())
	{
		windowfill($window);
	}
}

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_mainwindow_resized_last
{
	windowfill_all();
}

sub signal_window_created_last
{
	my ($window) = @_;

	windowfill($window);
}

##############################################################################
#
# irssi command functions
#
##############################################################################

sub command_clear
{
	my ($data, $server, $windowitem) = @_;

		Irssi::signal_continue($data, $server, $windowitem);
		windowfill_fill_all();
}

##############################################################################
#
# script on load
#
##############################################################################

sub script_on_load
{
	Irssi::signal_add_last('mainwindow resized', 'signal_mainwindow_resized_last');
	Irssi::signal_add_last('window created',     'signal_window_created_last');

	Irssi::command_bind('clear', 'command_clear');

	windowfill_all();
}

#
# start script in a timeout to avoid printing before irssis "loaded script"
#
Irssi::timeout_add_once(10, 'script_on_load', undef);

1;

##############################################################################
#
# eof mh_windowfill.pl
#
##############################################################################
