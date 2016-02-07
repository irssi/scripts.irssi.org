##############################################################################
#
# mh_windowfill.pl v1.07 (20160207)
#
# Copyright (c) 2015, 2016  Michael Hansen
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
#
#	without script: http://escaflowne.hro.nl/~mh/mh_windowfill_without.png
#	                or
#	                http://rud0lf.webatu.com/mh_windowfill_without.png
#
#	with script:    http://escaflowne.hro.nl/~mh/mh_windowfill_with.png
#	                or
#	                http://rud0lf.webatu.com/mh_windowfill_with.png
#
# history:
#
#	v1.07 (20160207)
#		changed url of screenshots because picpaste have a weird definition of forever
#		added namespace to MSGLEVEL
#	v1.06 (20151220)
#		added changed field to irssi header
#	v1.05 (20151206)
#		added a few comments
#	v1.04 (20151128)
#		call windowfill* directly from signals
#		removed on load timeout
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

our $VERSION = '1.07';
our %IRSSI   =
(
	'name'        => 'mh_windowfill',
	'description' => 'fill windows so scrolling starts bottom-up instead of top-down (screenshots linked in source)',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'http://scripts.irssi.org / https://github.com/mh-source/irssi-scripts',
	'changed'     => 'Sun Feb  7 18:24:50 CET 2016',
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
		$window->print('', Irssi::MSGLEVEL_NEVER);
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

		#
		# count lines we need to move
		#
		while ($line)
		{
			$linecount++;
			$line = $line->next();
		}

		windowfill_fill($window);

		$line = $window->view()->get_lines();

		#
		# move lines down
		#
		while ($linecount)
		{
			my $linetext = $line->get_text(1);
			$line        = $line->next();
			$window->print($linetext, Irssi::MSGLEVEL_NEVER);
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

Irssi::signal_add_last('mainwindow resized', 'windowfill_all');
Irssi::signal_add_last('window created',     'windowfill');

Irssi::command_bind('clear', 'command_clear');

windowfill_all();

1;

##############################################################################
#
# eof mh_windowfill.pl
#
##############################################################################
