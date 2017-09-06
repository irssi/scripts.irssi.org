##############################################################################
#
# mh_sbuserinfo.pl v1.06 (20170424)
#
# Copyright (c) 2015-2017  Michael Hansen
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
# statusbar item that shows user count (opers, ops, halfops, voice and total) and limit info (with opless/limit warning) in channels
#
# displays in the statusbar the number of users and the limit of the channel,
# with several settings for finetuning:
#
# default settings: [Users: <users>(*<users_oper>:@<users_op>:+<users_voice>:<users_rest>)/<limit>(<limitusers>)]
# "/<limit>(<limitusers>)" will only show when there is a limit set.
# "(<limitusers>)" shows the difference between the limit and current
# users (this can be negative if the limit is lower than users)
#
# (if you do not already have another script running a periodical who on channels,
# you will need one (autowho.pl from irssi.org for example). otherwise oper/away
# counts will not update correctly (if you do not use oper/away details you can ignore
# this))
#
# setting mh_sbuserinfo_format_group_begin (default '(') and
# setting mh_sbuserinfo_format_group_end'  (default ')'); change the characters grouping
# details
#
# setting mh_sbuserinfo_format_sep (default ':'): change the : seperator to another string
#
# setting mh_sbuserinfo_format_div (default '/'): change the / divider to another string
#
# setting mh_sbuserinfo_show_prefix (default 'Users: '): set/unset the prefix
# in the window item
#
# setting mh_sbuserinfo_show_details (default ON): enable/disable showing a
# detailed breakout of users into opers, ops, halfops, voice and normal
# (further customisable with _show_details_*)
#
# setting mh_sbuserinfo_show_details_mode (default ON): enable/disable
# prefixing opers, ops, halfops and voice with *@%+ when details are enabled
#
# setting mh_sbuserinfo_format_mode_away  (default 'z'),
# setting mh_sbuserinfo_format_mode_oper  (default '*'),
# setting mh_sbuserinfo_format_mode_op    (default '@'),
# setting mh_sbuserinfo_format_mode_ho    (default '%%'),
# setting mh_sbuserinfo_format_mode_vo    (default '+') and
# setting mh_sbuserinfo_format_mode_other (default ''): change the mode prefix
# for each of away, oper, op, halfdop, voice and others
#
# setting mh_sbuserinfo_show_details_halfop (default OFF): enable/disable
# showing halfops when details are enabled
#
# setting mh_sbuserinfo_show_details_oper (default ON): enable/disable
# showing opers when details are enabled
#
# setting mh_sbuserinfo_show_details_away (default ON): enable/disable
# showing users away when details are enabled
#
# setting mh_sbuserinfo_show_details_difference (default ON): enable/disable
# showing the "(<limitusers>)"
#
# setting mh_sbuserinfo_show_warning_opless' (default ON): change the colour
# of "<users_op>" if channel is opless
#
# setting mh_sbuserinfo_show_warning_limit (default ON): change the colour
# of "<limit>" if channel is above, at or close to the limited amount of users
#
# setting mh_sbuserinfo_show_warning_limit_percent (default 0): number in
# percent (0-100) of users relative to the limit before a limit warning is
# triggered (if set to 0 see mh_sbuserinfo_show_warning_limit_difference)
#
# setting mh_sbuserinfo_show_warning_limit_difference (default 5): when
# mh_sbuserinfo_show_warning_limit_percent is 0, use this absolute value
# as the difference warning trigger instead of percentage
#
# setting mh_sbuserinfo_warning_format (default '%Y'): the colour used for
# warnings. see http://www.irssi.org/documentation/formats
#
# to configure irssi to show the new statusbar item in a default irssi
# installation type '/statusbar window add -after window_empty mh_sbuserinfo'.
# see '/help statusbar' for more details and do not forget to '/save'
#
# history:
#
#	v1.06 (20170424)
#		added 'sbitems' to irssi header for better scriptassist.pl support (github issue #1)
#		added _show_details_away/_format_mode_away and supporting code
#		some description and documentation changes
#
#	v1.05 (20161106)
#		added setting _show_details_oper and supporting code
#		added setting _format_sep and supportingf code
#		added setting _format_div and supporting code
#		added setting _group_begin and _format_group_end and supporting code
#		added setting _format_mode_oper, _format_mode_op, _format_mode_ho, _format_mode_vo and _format_mode_other, and supporting code
#		added settting _show_warning_limit_difference and supporting code (changing _show_warning_limit_percent behavior)
#		changed default of _show_warning_limit_percent from 95 to 0
#
#	v1.04 (20151225)
#		added setting _show_details_difference and supporting code
#		changed _show_warning_limit_percent default from 90 to 95
#		added changed field to irssi header
#		added a few comments
#
#	v1.03 (20151201)
#		added setting _show_prefix and supporting code
#		changed setting _show_details_mode default to ON
#		updated documentation
#
#	v1.02 (20151127)
#		only show item when channel is synced
#		cleaned out redundant code
#
#	v1.01 (20151127)
#		call statusbar_redraw directly in signals
#		now using elsif
#		removed timeout on load
#
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

our $VERSION = '1.06';
our %IRSSI   =
(
	'name'        => 'mh_sbuserinfo',
	'description' => 'statusbar item that shows user count (opers, ops, halfops, voice and total) and limit info (with opless/limit warning) in channels',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'http://scripts.irssi.org / https://github.com/mh-source/irssi-scripts',
	'changed'     => 'Mon Apr 24 09:34:36 CEST 2017',
	'sbitems'     => 'mh_sbuserinfo',
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
			#
			# only redraw if triggered by active channel
			#
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
			$format            = Irssi::settings_get_str('mh_sbuserinfo_show_prefix');
			my $users          = 0;
			my $users_op       = 0;
			my $users_ho       = 0;
			my $users_vo       = 0;
			my $users_oper     = 0;
			my $users_gone     = 0;
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

				if ($nick->{'serverop'})
				{
					$users_oper++;
				}

				if ($nick->{'gone'})
				{
					$users_gone++;
				}
			}

			$format .= $users;

			my $format_sep = Irssi::settings_get_str('mh_sbuserinfo_format_sep');
			my $format_div = Irssi::settings_get_str('mh_sbuserinfo_format_div');

			my $format_group_begin = Irssi::settings_get_str('mh_sbuserinfo_format_group_begin');
			my $format_group_end   = Irssi::settings_get_str('mh_sbuserinfo_format_group_end');

			if (Irssi::settings_get_bool('mh_sbuserinfo_show_details'))
			{
				$format .= $format_group_begin;

				my $showmode = Irssi::settings_get_bool('mh_sbuserinfo_show_details_mode');

				if (Irssi::settings_get_bool('mh_sbuserinfo_show_details_away'))
				{
					if ($showmode)
					{
						$format .= Irssi::settings_get_str('mh_sbuserinfo_format_mode_away');
					}

					$format .= $users_gone . $format_sep
				}

				if (Irssi::settings_get_bool('mh_sbuserinfo_show_details_oper'))
				{
					if ($showmode)
					{
						$format .= Irssi::settings_get_str('mh_sbuserinfo_format_mode_oper');
					}

					$format .= $users_oper . $format_sep
				}

				if (Irssi::settings_get_bool('mh_sbuserinfo_show_warning_opless') and (not $users_op))
				{
					$format .= $warning_format;
				}

				if ($showmode)
				{
					$format .= Irssi::settings_get_str('mh_sbuserinfo_format_mode_op');
				}

				$format .= $users_op . '%n' . $format_sep;

				if (Irssi::settings_get_bool('mh_sbuserinfo_show_details_halfop'))
				{
					#
					# add halfops to ops so users calculation below matches
					#
					$users_op += $users_ho;

					if ($showmode)
					{
						$format .= Irssi::settings_get_str('mh_sbuserinfo_format_mode_ho');
					}

 					$format .= $users_ho . $format_sep;
				}

				if ($showmode)
				{
					$format .= Irssi::settings_get_str('mh_sbuserinfo_format_mode_vo');;
				}

				$format .= $users_vo . $format_sep;

				if ($showmode)
				{
					$format .= Irssi::settings_get_str('mh_sbuserinfo_format_mode_other');;
				}

				$format .= ($users - ($users_op + $users_vo)) . $format_group_end;
			}

			my $limit = $channel->{'limit'};

			if ($limit)
			{
				$format .= $format_div;

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

					if ($setting_percent)
					{

						my $percent = int(($users / $limit) * 100);

						if ($percent >= $setting_percent)
						{
							$format .= $warning_format;
						}
					} else
					{
						my $setting_percent = Irssi::settings_get_int('mh_sbuserinfo_show_warning_limit_difference');

						my $difference = ($limit - $users);

						if ($setting_percent < 0)
						{
							$setting_percent = 0;
						}

						if ($difference < $setting_percent)
						{
							$format .= $warning_format;
						}
					}
				}

				if (Irssi::settings_get_bool('mh_sbuserinfo_show_details_difference'))
				{
					$limit .= $format_group_begin . ($limit - $users) . $format_group_end;
				}

				$format .= $limit . '%n';
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

Irssi::settings_add_bool('mh_sbuserinfo', 'mh_sbuserinfo_show_details',                  1);
Irssi::settings_add_bool('mh_sbuserinfo', 'mh_sbuserinfo_show_details_mode',             1);
Irssi::settings_add_bool('mh_sbuserinfo', 'mh_sbuserinfo_show_details_halfop',           0);
Irssi::settings_add_bool('mh_sbuserinfo', 'mh_sbuserinfo_show_warning_opless',           1);
Irssi::settings_add_bool('mh_sbuserinfo', 'mh_sbuserinfo_show_warning_limit',            1);
Irssi::settings_add_int( 'mh_sbuserinfo', 'mh_sbuserinfo_show_warning_limit_percent',    0);
Irssi::settings_add_int( 'mh_sbuserinfo', 'mh_sbuserinfo_show_warning_limit_difference', 5);
Irssi::settings_add_str( 'mh_sbuserinfo', 'mh_sbuserinfo_warning_format',                '%Y');
Irssi::settings_add_str( 'mh_sbuserinfo', 'mh_sbuserinfo_show_prefix',                   'Users: ');
Irssi::settings_add_bool('mh_sbuserinfo', 'mh_sbuserinfo_show_details_difference',       1);
Irssi::settings_add_bool('mh_sbuserinfo', 'mh_sbuserinfo_show_details_oper',             1);
Irssi::settings_add_bool('mh_sbuserinfo', 'mh_sbuserinfo_show_details_away',             1);
Irssi::settings_add_str( 'mh_sbuserinfo', 'mh_sbuserinfo_format_sep',                    ':');
Irssi::settings_add_str( 'mh_sbuserinfo', 'mh_sbuserinfo_format_div',                    '/');
Irssi::settings_add_str( 'mh_sbuserinfo', 'mh_sbuserinfo_format_group_begin',            '(');
Irssi::settings_add_str( 'mh_sbuserinfo', 'mh_sbuserinfo_format_group_end',              ')');
Irssi::settings_add_str( 'mh_sbuserinfo', 'mh_sbuserinfo_format_mode_oper',              '*');
Irssi::settings_add_str( 'mh_sbuserinfo', 'mh_sbuserinfo_format_mode_away',              'z');
Irssi::settings_add_str( 'mh_sbuserinfo', 'mh_sbuserinfo_format_mode_op',                '@');
Irssi::settings_add_str( 'mh_sbuserinfo', 'mh_sbuserinfo_format_mode_ho',                '%%');
Irssi::settings_add_str( 'mh_sbuserinfo', 'mh_sbuserinfo_format_mode_vo',                '+');
Irssi::settings_add_str( 'mh_sbuserinfo', 'mh_sbuserinfo_format_mode_other',             '');

Irssi::signal_add_last('channel sync',         'statusbar_redraw');
Irssi::signal_add_last('channel mode changed', 'statusbar_redraw');
Irssi::signal_add_last('nick mode changed',    'statusbar_redraw');
Irssi::signal_add_last('nicklist new',         'statusbar_redraw');
Irssi::signal_add_last('nicklist remove',      'statusbar_redraw');
Irssi::signal_add_last('setup changed',        'signal_setup_changed_last');
Irssi::signal_add_last('window changed',       'signal_window_changed_last');

Irssi::statusbar_item_register('mh_sbuserinfo', '', 'statusbar_userinfo');

1;

##############################################################################
#
# eof mh_sbuserinfo.pl
#
##############################################################################
