##############################################################################
#
# mh_invite.pl v1.02 (20160305)
#
# Copyright (c) 2016  Michael Hansen
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
# print invites in server, channel, query and active window
#
# invites are printet in the following format:
#
# <nick> [<userhost>] invites you to <network>/<channel>
#
# settings:
#
# mh_invite_show_network (default ON): enable/disable showing the
# <network>/ part of the printet line
#
# mh_invite_show_host (default ON): enable/disable showing the
# [<userhost>] part of the printet line
#
# mh_invite_server (default ON): enable/disable printing the line
# in the relevant server window
#
# mh_invite_channel (default ON): enable/disable printing the line
# in all shared channels of the inviter if they exist
#
# mh_invite_query (default ON): enable/disable printing the line
# in queries with the inviter if they exist
#
# mh_invite_active (default ON): enable/disable printing the line
# in the active window (however, we will always print in the active
# window if we didnt print to a server, query or channel, even if this
# is disabled)
#
# mh_invite_no_act_server (default OFF): enable/disable not setting
# window activity when printing in a server window
#
# mh_invite_no_act_channel (default OFF): enable/disable not
# setting window activity when printing in a channel window
#
# mh_invite_no_act_query (default OFF): enable/disable not setting
# window activity when printing in a query window
#
# history:
#
#	v1.02 (20160305)
#		added scripts.irssi.org to url
#	v1.01 (20160213)
#		edited comment whitespace
#	v1.00 (20160104)
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

{ package Irssi::Nick }

our $VERSION = '1.02';
our %IRSSI   =
(
	'name'        => 'mh_invite',
	'description' => 'print invites in server, channel, query and active window',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'http://scripts.irssi.org / https://github.com/mh-source/irssi-scripts',
	'changed'     => 'Sat Mar  5 15:23:47 CET 2016',
);

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_message_invite_last
{
	my ($server, $channelname, $nickname, $userhost) = @_;

	my $msglevel    = Irssi::MSGLEVEL_CRAP;
	my $printactive = 1;
	my $printed     = 0;
	my $format      = 'mh_invite_line_';

	if (Irssi::settings_get_bool('mh_invite_show_host'))
	{
		$format = $format . 'h';
	}

	if (Irssi::settings_get_bool('mh_invite_show_network'))
	{
		$format = $format . 'n';
	}

	if (Irssi::settings_get_bool('mh_invite_server'))
	{
		if (Irssi::settings_get_bool('mh_invite_no_act_server'))
		{
			$server->printformat('(status)', $msglevel | Irssi::MSGLEVEL_NO_ACT, $format, $nickname, $userhost, $channelname, $server->{'tag'});

		} else
		{
			$server->printformat('(status)', $msglevel, $format, $nickname, $userhost, $channelname, $server->{'tag'});
		}

		$printed = 1;

		if (Irssi::active_win()->{'name'} eq '(status)')
		{
			$printactive = 0;
		}
	}

	if (Irssi::settings_get_bool('mh_invite_channel'))
	{
		for my $channel ($server->channels())
		{
			if ($channel->nick_find($nickname))
			{
				if (Irssi::settings_get_bool('mh_invite_no_act_channel'))
				{
					$channel->printformat($msglevel | Irssi::MSGLEVEL_NO_ACT, $format, $nickname, $userhost, $channelname, $server->{'tag'});

				} else
				{
					$channel->printformat($msglevel, $format, $nickname, $userhost, $channelname, $server->{'tag'});
				}

				$printed = 1;

				if (ref(Irssi::active_win()->{'active'}) eq 'Irssi::Irc::Channel')
				{
					if (Irssi::active_win()->{'active'}->{'name'} eq $channel->{'name'})
					{
						$printactive = 0;
					}
				}
			}
		}
	}

	if (Irssi::settings_get_bool('mh_invite_query'))
	{
		for my $query ($server->queries())
		{
			if ($query->{'name'} eq $nickname)
			{
				if (Irssi::settings_get_bool('mh_invite_no_act_query'))
				{
					$query->printformat($msglevel | Irssi::MSGLEVEL_NO_ACT, $format, $nickname, $userhost, $channelname, $server->{'tag'});

				} else
				{
					$query->printformat($msglevel, $format, $nickname, $userhost, $channelname, $server->{'tag'});
				}

				$printed = 1;

				if (ref(Irssi::active_win()->{'active'}) eq 'Irssi::Irc::Query')
				{
					if (Irssi::active_win()->{'active'}->{'name'} eq $query->{'name'})
					{
						$printactive = 0;
					}
				}
			}
		}
	}

	if (($printactive and Irssi::settings_get_bool('mh_invite_active')) or (not $printed))
	{
		Irssi::active_win->printformat($msglevel, $format, $nickname, $userhost, $channelname, $server->{'tag'});
	}

	Irssi::signal_stop();
}

##############################################################################
#
# script on load
#
##############################################################################

Irssi::theme_register([
    'mh_invite_line_',      '{nick $0} invites you to {channel $2}',
    'mh_invite_line_h',     '{nick $0} {nickhost $1} invites you to {channel $2}',
    'mh_invite_line_n',     '{nick $0} invites you to {server $3}/{channel $2}',
    'mh_invite_line_hn',    '{nick $0} {nickhost $1} invites you to {server $3}/{channel $2}',
]);

Irssi::settings_add_bool('mh_invite', 'mh_invite_show_network',   1);
Irssi::settings_add_bool('mh_invite', 'mh_invite_show_host',      1);
Irssi::settings_add_bool('mh_invite', 'mh_invite_server',         1);
Irssi::settings_add_bool('mh_invite', 'mh_invite_channel',        1);
Irssi::settings_add_bool('mh_invite', 'mh_invite_query',          1);
Irssi::settings_add_bool('mh_invite', 'mh_invite_active',         1);
Irssi::settings_add_bool('mh_invite', 'mh_invite_no_act_server',  0);
Irssi::settings_add_bool('mh_invite', 'mh_invite_no_act_channel', 0);
Irssi::settings_add_bool('mh_invite', 'mh_invite_no_act_query',   0);

Irssi::signal_add_last('message invite', 'signal_message_invite_last');

1;

##############################################################################
#
# eof mh_invite.pl
#
##############################################################################
