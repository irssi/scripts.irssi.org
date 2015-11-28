##############################################################################
#
# mh_sbuserinfo.pl v1.02 (20151127)
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
# statusbar item that shows users and limit info in channels
#
# displays in the statusbar the number of users and the limit of the channel,
# with several settings for finetuning:
#
# default settings: [<users>(<users_op>:<users_voice>:<users_rest>)/<limit>]
# "/<limit>" will only show when there is a limit set
#
# setting mh_sbuserinfo_show_details (default ON): enable/disable showing a
# detailed breakout of users into ops, halfops, voice and normal
#
# setting mh_sbuserinfo_show_details_mode (default OFF): enable/disable
# prefixing ops, halfops and voice with @%+ when details are enabled
#
# setting mh_sbuserinfo_show_details_halfop (default OFF): enable/disable
# showing halfops when details are enabled
#
# setting mh_sbuserinfo_show_warning_opless' (default ON): change the colour
# of "<users_op>" if channel is opless
#
# setting mh_sbuserinfo_show_warning_limit (default ON): change the colour
# of "<limit>" if channel is above, at or close to the limited amount of users
#
# setting mh_sbuserinfo_show_warning_limit_percent (default 90): number in
# percent (0-100) of users relative to the limit before a limit warning is
# triggered
#
# setting mh_sbuserinfo_warning_format (default '%Y'): the colour used for
# warnings. see http://www.irssi.org/documentation/formats
#
# to configure irssi to show the new statusbar item in a default irssi
# installation type '/statusbar window add -after window_empty mh_sbuserinfo'.
# see '/help statusbar' for more details and do not forget to '/save'
#
# history:
#	v1.02 (20151127)
#		only show item when channel is synced
#		cleaned out redundant code
#	v1.01 (20151127)
#		call statusbar_redraw directly in signals
#		now using elsif
#		removed timeout on load
#	v1.00 (20151126)
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

our $VERSION = '1.02';
our %IRSSI   =
(
	'name'        => 'mh_sbuserinfo',
	'description' => 'statusbar item that shows users and limit info in channels',
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

sub statusbar_redraw
{
	my ($channel) = @_;

	if (ref($channel) eq 'Irssi::Irc::Channel')
	{
		my $window        = Irssi::active_win();
		my $channelactive = $window->{'active'};

		if (ref($channelactive) eq 'Irssi::Irc::Channel')
		{
			if (lc($channelactive->{'server'}->{'tag'}) eq lc($channel->{'server'}->{'tag'}))
			{
				if (lc($channel->{'name'}) eq lc($channelactive->{'name'}))
				{
					if ($channelactive->{'synced'})
					{
						Irssi::statusbar_items_redraw('mh_sbuserinfo');
					}
				}
			}
		}
	}
}

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_setup_changed_last
{
	statusbar_redraw(Irssi::active_win->{'active'});
}

sub signal_window_changed_last
{
	my ($window, $window_old) = @_;

	statusbar_redraw($window->{'active'});
}

##############################################################################
#
# statusbar item handlers
#
##############################################################################

sub statusbar_userinfo
{
	my ($statusbaritem, $get_size_only) = @_;

	my $format  = '';
	my $window  = Irssi::active_win();
	my $channel = $window->{'active'};

	if (ref($channel) eq 'Irssi::Irc::Channel')
	{
		if ($channel->{'synced'})
		{
			my $users          = 0;
			my $users_op       = 0;
			my $users_ho       = 0;
			my $users_vo       = 0;
			my $warning_format = Irssi::settings_get_str('mh_sbuserinfo_warning_format');

			for my $nick ($channel->nicks())
			{
				$users++;

				if ($nick->{'op'})
				{
					$users_op++;

				} elsif ($nick->{'halfop'})
				{
					$users_ho++;

				} elsif ($nick->{'voice'})
				{
					$users_vo++;
				}
			}

			$format = $users;

			if (Irssi::settings_get_bool('mh_sbuserinfo_show_details'))
			{
				$format = $format . '(';

				my $showmode = Irssi::settings_get_bool('mh_sbuserinfo_show_details_mode');

				if (Irssi::settings_get_bool('mh_sbuserinfo_show_warning_opless') and (not $users_op))
				{
					$format = $format . $warning_format;
				}

				if ($showmode)
				{
					$format = $format . '@';
				}

				$format = $format . $users_op . '%n:';

				if (Irssi::settings_get_bool('mh_sbuserinfo_show_details_halfop'))
				{
					# add halfops to ops so users calculation below matches
					$users_op = $users_op + $users_ho;

					if ($showmode)
					{
						$format = $format . '%%';
					}

 					$format = $format . $users_ho . ':';
				}

				if ($showmode)
				{
					$format = $format . '+';
				}

				$format = $format . $users_vo . ':' . ($users - ($users_op + $users_vo)) . ')';
			}

			my $limit = $channel->{'limit'};

			if ($limit)
			{
				$format = $format . '/';

				if (Irssi::settings_get_bool('mh_sbuserinfo_show_warning_limit'))
				{
					my $setting_percent = Irssi::settings_get_int('mh_sbuserinfo_show_warning_limit_percent');

					if ($setting_percent > 100)
					{
						$setting_percent = 100;

					} elsif  ($setting_percent < 0)
					{
						$setting_percent = 0;
					}

					my $percent = int(($users / $limit) * 100);

					if ($percent >= $setting_percent)
					{
						$format = $format . $warning_format;
					}
				}

				$format = $format . $limit . '%n';
			}
		}
	}

	$statusbaritem->default_handler($get_size_only, '{sb ' . $format . '}', '', 0);
}

##############################################################################
#
# script on load
#
##############################################################################

Irssi::settings_add_bool('mh_sbuserinfo', 'mh_sbuserinfo_show_details', 1);
Irssi::settings_add_bool('mh_sbuserinfo', 'mh_sbuserinfo_show_details_mode', 0);
Irssi::settings_add_bool('mh_sbuserinfo', 'mh_sbuserinfo_show_details_halfop', 0);
Irssi::settings_add_bool('mh_sbuserinfo', 'mh_sbuserinfo_show_warning_opless', 1);
Irssi::settings_add_bool('mh_sbuserinfo', 'mh_sbuserinfo_show_warning_limit', 1);
Irssi::settings_add_int( 'mh_sbuserinfo', 'mh_sbuserinfo_show_warning_limit_percent', 90);
Irssi::settings_add_str( 'mh_sbuserinfo', 'mh_sbuserinfo_warning_format', '%Y');

Irssi::statusbar_item_register('mh_sbuserinfo', '', 'statusbar_userinfo');

Irssi::signal_add_last('channel sync',         'statusbar_redraw');
Irssi::signal_add_last('channel mode changed', 'statusbar_redraw');
Irssi::signal_add_last('nick mode changed',    'statusbar_redraw');
Irssi::signal_add_last('nicklist new',         'statusbar_redraw');
Irssi::signal_add_last('nicklist remove',      'statusbar_redraw');
Irssi::signal_add_last('setup changed',        'signal_setup_changed_last');
Irssi::signal_add_last('window changed',       'signal_window_changed_last');

1;

##############################################################################
#
# eof mh_sbuserinfo.pl
#
##############################################################################
