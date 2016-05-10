##############################################################################
#
# mh_hold_mode.pl v1.07 (20160510)
#
# Copyright (c) 2007, 2015, 2016  Michael Hansen
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
# Emulation of ircII per-window hold_mode
#
# upgrading from v0.xx to v1.xx:
#
# the statusbar item have changed name from mh_more to mh_sbmore, you
# can remove the old item with '/statusbar window remove mh_more' and
# follow the instructions below to add the new item
#
# should you not like the new item look, you can revert it back to the
# old style with the setting mh_hold_mode_more_oldstyle
#
# previously the default window hold_mode and scroll_always were hardcoded
# they are now setable in irssi (see settings below)
#
# instructions:
#
# add the mh_sbmore statusbar item with '/statusbar window add -after window_empty mh_sbmore'
# (For better control of the placement of mh_sbmore see '/HELP STATUSBAR'
#
# mh_sbmore *should* fully replace Irssi's standard more, so you could
# remove it with '/STATUSBAR WINDOW REMOVE more'
#
# when the script is loaded it will reset all windows and scroll them
# to the last line (without losing backlog) and from then on you will
# have to do '/HOLD_MODE ON' or '/HOLD_MODE OFF' in a given window to
# enable/disable hold_mode for it (off by default)
#
# should the buffer become too much for you to bother to read it, you
# can jump to the bottom with '/HOLD_MODE FLUSH' (although '/CLEAR'
# will do the same)
#
# when hold_mode is on, it will scroll until the last line you said or
# command you send, then hold untill you press enter (and depending on
# the 'scroll_always' value it will either scroll on any enter, or only on
# enter with empty commandline). enter will scroll by 1 page (minus 1 line)
# unless you have moved around in the scrollback buffer with pg-up/dn, in
# which case it will scroll to where you left (except when you pg-dn to
# end of buffer, this will reset the scroll stop point to that line)
#
# (also, you can reset the point to scroll to at any time by just
# pressing enter when in "live" view, the current line will then be set
# as the scroll stop point)
#
# it is not a true-to-ircII hold_mode emulation, as some things are slightly
# different, over time they might be made optional to be able to go back
# to as close to ircII as possible.
#
# (i hope i didn't forget anything :-)
#
# settings:
#
# mh_hold_mode_more_oldstyle (default OFF): switch between old and new
# style more statusbar item
#
# mh_hold_mode_default_hold_mode (default OFF): change the default hold_mode
# setting for new windows
#
# mh_hold_mode_default_scroll_always (default ON): change the default scroll_always
# setting for new windows
#
# history:
#
#	v1.07 (20160510)
#		corrected typo in instructions
#		added space to old-style more so it looks better
#	v1.06 (20160503)
#		fixed call to missing sub
#	v1.05 (20160211)
#		moved default settings from hardcoded to irssi settings _default_hold_mode and _default_scroll_always
#	v1.04 (20160126)
#		added mh_hold_mode_more_oldstyle and supporting code
#		added namespace to MSGLEVEL
#		code cleanup
#	v1.03 (20151226)
#		now using 'key send_line' instead of 'gui key pressed'
#		added /help
#		fixed '/hold_mode toggle', it didnt do anything before
#		code cleanup
#		added changed field to irssi header
#		changed url
#	v1.02 (20151210)
#		now accepts both 10 and 13 as keycode for enter, required to work in upcoming irssi
#	v1.01 (20151204)
#		nicer (imho) mh_sbmore
#	v1.00 (20151201)
#		cleanup and re-release, this have been in active use since 2007 without any issues
#	v0.12 (unknown 2007)
#		added scroll_always option: /HOLD_MODE scroll_always [on|off|toggle]
#		Defaults to always scroll on, even if the line is not empty when you
#		press enter - the ircII way. If you like to only scroll on empty lines
#		set '/HOLD_MODE scroll_always off'
#		added '/HOLD_MODE toggle' for ircII emulation completenes
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
	'name'        => 'mh_hold_mode',
	'description' => 'Emulation of ircII per-window hold_mode',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'http://scripts.irssi.org / https://github.com/mh-source/irssi-scripts',
	'changed'     => 'Tue May 10 19:09:32 CEST 2016',
);

##############################################################################
#
# global variables
#
##############################################################################

our %config;

our $lastcommand = '';
our $more        = 0;

##############################################################################
#
# common support functions
#
##############################################################################

sub trim_space
{
	my ($string) = @_;

	if (defined($string))
	{
		$string =~ s/^\s+//g;
		$string =~ s/\s+$//g;

	} else
	{
		$string = '';
	}

	return($string);
}

##############################################################################
#
# script functions
#
##############################################################################

sub config_window_get
{
	my ($windowrec) = @_;

	if ($windowrec)
	{
		my $windowid = $windowrec->{'_irssi'};

		if (!exists($config{'WINDOW'}{$windowid}))
		{
			if (Irssi::settings_get_bool('mh_hold_mode_default_hold_mode'))
			{
				$config{'WINDOW'}{$windowid}{'hold_mode'} = 1;

			} else
			{
				$config{'WINDOW'}{$windowid}{'hold_mode'} = 0;
			}

			if (Irssi::settings_get_bool('mh_hold_mode_default_scroll_always'))
			{
				$config{'WINDOW'}{$windowid}{'scroll_always'} = 1;

			} else
			{
				$config{'WINDOW'}{$windowid}{'scroll_always'} = 0;
			}

		}

		return(\%{$config{'WINDOW'}{$windowid}});
	}

	return(undef);
}

sub config_window_del
{
	my ($windowrec) = @_;

	if ($windowrec)
	{
		my $windowid = $windowrec->{'_irssi'};

		if (exists($config{'WINDOW'}{$windowid}))
		{
			delete($config{'WINDOW'}{$windowid});
			return(1);
		}
	}

	return(undef);
}

sub window_bookmark_compare
{
	my ($bookmark1, $bookmark2) = @_;

	if ($bookmark1 and $bookmark2)
	{
		if ($bookmark1->{'_irssi'} == $bookmark2->{'_irssi'})
		{
			return(1);
		}
	}

	return(0);
}

sub window_refresh
{
	my $windowrec = Irssi::active_win();

	if (not $windowrec->view()->{'empty_linecount'})
	{
		my $bookmark = $windowrec->view()->get_bookmark('mh_hold_mode');

		if (not $bookmark)
		{
			$windowrec->view()->set_bookmark('mh_hold_mode', $windowrec->view()->{'startline'});
			$bookmark = $windowrec->view()->get_bookmark('mh_hold_mode');

			if (not $bookmark)
			{
				return(0);
			}
		}

		$windowrec->view()->scroll_line($bookmark);
		statusbar_more_redraw();
	}
}

sub window_scroll
{
	my $windowrec = Irssi::active_win();

	my $bookmark = $windowrec->view()->{'startline'};
	window_refresh();
	my $bookmark_new = $windowrec->view()->{'startline'};

	if (window_bookmark_compare($bookmark_new, $bookmark))
	{
		$windowrec->view()->scroll(($windowrec->{'height'} - 1));

		if ($windowrec->view()->{'bottom'})
		{
			$windowrec->view()->set_bookmark_bottom('mh_hold_mode');

		} else
		{
			$windowrec->view()->set_bookmark('mh_hold_mode', $windowrec->view()->{'startline'});
		}
	}

	statusbar_more_redraw();
}

sub statusbar_more_redraw
{
	Irssi::statusbar_items_redraw('mh_sbmore');
}

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_key_send_line_first
{
	$lastcommand  = Irssi::parse_special('$L');
	my $windowrec = Irssi::active_win();

	if (($lastcommand eq '' or config_window_get($windowrec)->{'scroll_always'}) and $more)
	{
		window_scroll();
	}
}

sub signal_key_send_line_last
{
	my $windowrec = Irssi::active_win();

	if  (config_window_get($windowrec)->{'hold_mode'})
	{
		if ($windowrec->view()->{'bottom'})
		{
			$windowrec->view()->set_bookmark_bottom('mh_hold_mode');

			if ($more)
			{
				$windowrec->view()->scroll($more);
				window_refresh();
			}

		} else
		{
			window_refresh();
		}
	}
}

sub signal_window_changed_last
{
	my ($windowrec_new, $windowrec_old) = @_;

	if (config_window_get($windowrec_new)->{'hold_mode'})
	{
		window_refresh();
	}
}

sub signal_print_text_last
{
	my ($textdest, $text, $stripped) = @_;

	my $windowrec = Irssi::active_win();
	my $window    = config_window_get($windowrec);

	if ($textdest->{'window'}->{'refnum'} == $windowrec->{'refnum'} and config_window_get($windowrec)->{'hold_mode'} and $more <= $windowrec->{'height'})
	{
		window_refresh();
	}
}

##############################################################################
#
# irssi command functions
#
##############################################################################

sub command_hold_mode
{
	my ($data, $server, $windowitem) = @_;

	my $windowrec  = Irssi::active_win();
	my $window     = config_window_get($windowrec);
	my $showstatus = 1;

	if (defined($data))
	{
		$data = trim_space($data);

		if ($data ne '')
		{
			if ($data =~ m/^toggle$/i)
			{
				if (not $window->{'hold_mode'})
				{
					$window->{'hold_mode'} = 1;

				} else
				{
					$window->{'hold_mode'} = 0;
				}

			} elsif ($data =~ m/^on$/i)
			{
				$window->{'hold_mode'} = 1;
				$windowrec->view()->set_bookmark_bottom('mh_hold_mode');
				window_refresh();

			} elsif ($data =~ m/^off$/i)
         	{
            	$window->{'hold_mode'} = 0;
				$windowrec->view()->set_bookmark_bottom('mh_hold_mode');
				window_refresh();

			} elsif ($data =~ m/^flush$/i)
			{
				$showstatus = 0;
				$windowrec->view()->set_bookmark_bottom('mh_hold_mode');
				window_refresh();

			} elsif ($data =~ m/^scroll_always(.*)$/i)
			{
				$showstatus = 0;

				if (defined($1))
				{
					$data = trim_space($1);

					if ($data =~ m/^toggle$/i)
					{
						$data = (($window->{'scroll_always'}) ? 'off' : 'on' );
					}

					if ($data =~ m/^on$/i)
					{
						$window->{'scroll_always'} = 1;

					} elsif ($data =~ m/^off$/i)
					{
						$window->{'scroll_always'} = 0;
					}
				}

				$windowrec->print('hold_mode (' . (($window->{'hold_mode'}) ? 'on' : 'off' ) . '): scroll_always is ' . (($window->{'scroll_always'}) ? 'on' : 'off' ), Irssi::MSGLEVEL_CLIENTCRAP);
			}
		}
	}

	if ($showstatus)
	{
		$windowrec->print('hold_mode is ' . (($window->{'hold_mode'}) ? 'on' : 'off' ), Irssi::MSGLEVEL_CLIENTCRAP);
	}
}

sub command_help
{
	my ($data, $server, $windowitem) = @_;

	$data = lc(trim_space($data));

	if ($data =~ m/^hold_mode$/i)
	{
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('HOLD_MODE %|[on|off|toggle|flush]', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('HOLD_MODE %|scroll_always [on|off|toggle]', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('%|Show/enable/disable/toggle/flush status of window hold_mode or show/enable/disable/toggle the scroll_always setting.', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);

		Irssi::signal_stop();
	}
}

##############################################################################
#
# statusbar item handlers
#
##############################################################################

sub statusbar_more
{
	my ($statusbaritem, $get_size_only) = @_;

	my $window = Irssi::active_win();

	my $local_more = 0;

	$local_more = ($window->view()->{'ypos'} - $window->view()->{'height'} + $window->view()->{'empty_linecount'} + 1);
	$more       = $local_more;

	if ($more)
	{
		my $format = "{sb $more more}";

		if (Irssi::settings_get_bool('mh_hold_mode_more_oldstyle'))
		{
				$format = " -- $more more --";
		}

		$statusbaritem->default_handler($get_size_only, $format, '', 0);

	} else
	{
		$statusbaritem->default_handler($get_size_only, '', '', 0);
	}
}

##############################################################################
#
# script on load
#
##############################################################################

Irssi::settings_add_bool('mh_hold_mode', 'mh_hold_mode_more_oldstyle',         0);
Irssi::settings_add_bool('mh_hold_mode', 'mh_hold_mode_default_hold_mode',     0);
Irssi::settings_add_bool('mh_hold_mode', 'mh_hold_mode_default_scroll_always', 1);

Irssi::signal_add_last('window created',   'config_window_get');
Irssi::signal_add_last('window destroyed', 'config_window_del');
Irssi::signal_add_first('key send_line',   'signal_key_send_line_first');
Irssi::signal_add_last('key send_line',    'signal_key_send_line_last');
Irssi::signal_add_last('window changed',   'signal_window_changed_last');
Irssi::signal_add_last('print text',       'signal_print_text_last');

Irssi::command_bind('hold_mode', 'command_hold_mode', 'mh_hold_mode');
Irssi::command_bind('help',      'command_help');

Irssi::statusbar_item_register('mh_sbmore', '', 'statusbar_more');
Irssi::statusbars_recreate_items();

Irssi::command('^SET SCROLL ON');

for my $window (Irssi::windows)
{
	$window->view()->set_scroll(1);
	$window->view()->set_bookmark_bottom('mh_hold_mode');
	config_window_get($window);
}

statusbar_more_redraw();
Irssi::command('^REDRAW');

Irssi::timeout_add(1000, 'statusbar_more_redraw', undef);

1;

##############################################################################
#
# eof mh_hold_mode.pl
#
##############################################################################
