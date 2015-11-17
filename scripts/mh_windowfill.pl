##############################################################################
#
# mh_windowfill.pl v1.01 (20151116)
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
# known issues:
# 	- /CLEAR will reset to top-down
#	- it is possible to confuse the script into not filling with a combination
#	  of script load/unloads and window resizes. but it requires effort
#
# history:
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

our $VERSION = '1.01';
our %IRSSI   =
(
	'name'        => 'mh_windowfill',
	'description' => 'fill windows so scrolling starts bottom-up instead of top-down (screenshots in source)',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'irc://open.ircnet.net',
);

##############################################################################
#
# global variables
#
##############################################################################

our $windowfill_running = 0;

##############################################################################
#
# script functions
#
##############################################################################

sub windowfill($)
{
	my ($window) = @_;

	if (ref($window) ne 'Irssi::UI::Window')
	{
		die();
	}

	#
	# fill window with empty lines and move already printed lines to the bottom
	#
	if (($window->view()->{'ypos'} + 2) <= $window->{'height'})
	{
		while (($window->view()->{'ypos'} + 2) <= $window->{'height'})
		{
			$window->print('', MSGLEVEL_CLIENTCRAP | MSGLEVEL_NEVER | MSGLEVEL_NO_ACT | MSGLEVEL_NOHILIGHT);
		}

		my $linecount  = $window->{'height'};
		my $line       = $window->view()->get_lines();

		while ((ref($line) eq 'Irssi::TextUI::Line') and $linecount)
		{
			my $linetext = $line->get_text(1);

			if ($linetext ne '')
			{
				# reprint line
				$window->print($linetext, MSGLEVEL_CLIENTCRAP | MSGLEVEL_NEVER | MSGLEVEL_NO_ACT | MSGLEVEL_NOHILIGHT);
				$line = $line->next();
				$window->view()->remove_line($line->prev());

			} else {

				# skip empty line
				$line = $line->next();
			}

			$linecount--;
		}
	}

	return(1);
}

sub windowfill_all()
{
	#
	# fill all windows with empty lines
	#
	for my $window (Irssi::windows())
	{
		if (ref($window) ne 'Irssi::UI::Window')
		{
			die();
		}

		windowfill($window);
	}

	return(1);
}

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_mainwindow_resized_last()
{
	if ($windowfill_running)
	{
		#
		# fill all windows with empty lines
		#
		windowfill_all();
	}

	return(1);
}

Irssi::signal_add_last('mainwindow resized', 'signal_mainwindow_resized_last');

sub signal_window_created_last($)
{
	my ($window) = @_;

	if (ref($window) ne 'Irssi::UI::Window')
	{
		die();
	}

	if ($windowfill_running)
	{
		#
		# fill created window with empty lines
		#
		windowfill($window);
	}

	return(1);
}

Irssi::signal_add_last('window created', 'signal_window_created_last');

##############################################################################
#
# script on load
#
##############################################################################

sub script_on_load($)
{
	my ($undef) = @_;

	if (defined($undef))
	{
		die();
	}

	if ($windowfill_running)
	{
		die();
	}

	windowfill_all();
	$windowfill_running = 1;

	return(1);
}

#
# start script in a timeout to avoid printing before irssis "loaded script"
#
if (not Irssi::timeout_add_once(10, 'script_on_load', undef))
{
	die();
}

1;

##############################################################################
#
# eof mh_windowfill.pl
#
##############################################################################
