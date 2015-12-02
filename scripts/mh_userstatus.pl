##############################################################################
#
# mh_userstatus.pl v1.01 (20151201)
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
# show in channels when users go away/back or oper/deoper
#
# will periodically check the channels you are on for users changing their
# away/oper status and print a line like:
#
# -!- <nick> [<userhost>] is now gone
# -!- <nick> [<userhost>] is now here
# -!- <nick> [<userhost>] is now oper
# -!- <nick> [<userhost>] is now not oper
#
# you can also list the currently away or opered users with the commands /whoa
# and /whoo respectively
#
# the following settings can finetune the scripts behavior:
#
# mh_userstatus_delay (default 5): aproximate delay between checking the
# channel (in minutes). you can set this to 0 to disable running /who if you
# use another script that already does a periodical /who on the channels you
# are on
#
# mh_userstatus_lag_limit (default 5): amount of lag (in seconds) where we skip
# checking the channel for status updates
#
# mh_userstatus_show_host (default ON): enable/disable showing userhosts
#
# mh_userstatus_show_mode (default ON): enable/disable showing modes (@%+) on
# nicks
#
# mh_userstatus_noact_gone (default OFF): enable/disable window activity when
# a user is gone
#
# mh_userstatus_noact_here (default OFF): enable/disable window activity when
# a user is here
#
# mh_userstatus_noact_oper (default OFF): enable/disable window activity when
# a user is opered
#
# mh_userstatus_noact_deop (default OFF): enable/disable window activity when
# a user is deoppered
#
# history:
#	v1.01 (20151201)
#		fixed bug when /whois spammed with status updates
#		added _noact_* and supporting code
#		added _show_mode and supporting code
#	v1.00 (20151129)
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

our $VERSION = '1.01';
our %IRSSI   =
(
	'name'        => 'mh_userstatus',
	'description' => 'show in channels when users go away/back or oper/deoper',
	'license'     => 'BSD',
	'authors'     => 'Michael Hansen',
	'contact'     => 'mh on IRCnet #help',
	'url'         => 'http://scripts.irssi.org / https://github.com/mh-source/irssi-scripts',
);

##############################################################################
#
# global variables
#
##############################################################################

our $userstatus_timeouts;
our $whois_in_progress;

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

   } else {

      $string = '';
   }

   return($string);
}

##############################################################################
#
# script functions
#
##############################################################################

sub get_delay
{
	my $delay = Irssi::settings_get_int('mh_userstatus_delay');

	if ($delay < 1)
	{
		$delay = 1;
	}

	$delay = $delay * 60000; # delay in minutes
	$delay = $delay + (int(rand(30000)) + 1);

	return($delay);
}

sub nick_prefix
{
	my ($nick) = @_;

	if (Irssi::settings_get_bool('mh_userstatus_show_mode'))
	{
		if ($nick->{'op'})
		{
			return('@');

		} elsif ($nick->{'halfop'})
		{
			return('%');

		}  elsif ($nick->{'voice'})
		{
			return('+');
		}
	}

	return('');
}

##############################################################################
#
# irssi timeouts
#
##############################################################################

sub timeout_request_who
{
	my ($args) = @_;
	my ($servertag, $channelname) = @{$args};

	if (exists($userstatus_timeouts->{$servertag}))
	{
		if (exists($userstatus_timeouts->{$servertag}->{$channelname}))
		{
			delete($userstatus_timeouts->{$servertag}->{$channelname});
		}
	}

	if (Irssi::settings_get_int('mh_userstatus_delay'))
	{
		my $server = Irssi::server_find_tag($servertag);

		if ($server)
		{
			my $lag_limit = Irssi::settings_get_int('mh_userstatus_lag_limit');

			if ($lag_limit)
			{
				$lag_limit = $lag_limit * 1000; # seconds to milliseconds
			}

			if ((not $lag_limit) or ($lag_limit > $server->{'lag'}))
			{
				my $channel = $server->channel_find($channelname);

				if ($channel)
				{
					$server->redirect_event('who',
						1,  # count
						'', # arg
						-1, # remote
						'', # failure signal
						{   # signals
							'event 352' => 'silent event who', # RPL_WHOREPLY
							''          => 'event empty',
						}
					);
					$channel->command('WHO ' . $channelname);
				}
			}

			my @args = ($servertag, $channelname);
			$userstatus_timeouts->{$servertag}->{$channelname} = Irssi::timeout_add_once(get_delay(), 'timeout_request_who', \@args);
		}
	}
}

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_channel_sync_last
{
	my ($channel) = @_;

	my $servertag   = lc($channel->{'server'}->{'tag'});
	my $channelname = lc($channel->{'name'});

	if (exists($userstatus_timeouts->{$servertag}))
	{
		if (exists($userstatus_timeouts->{$servertag}->{$channelname}))
		{
			return(1);
		}
	}

	if (Irssi::settings_get_int('mh_userstatus_delay'))
	{
		my @args = ($servertag, $channelname);
		$userstatus_timeouts->{$servertag}->{$channelname} = Irssi::timeout_add_once(get_delay(), 'timeout_request_who', \@args);
	}
}

sub signal_nicklist_gone_changed_last
{
	my ($channel, $nick) = @_;

	my $servertag = lc($channel->{'server'}->{'tag'});

	if (exists($whois_in_progress->{$servertag}))
	{
		if ($whois_in_progress->{$servertag})
		{
			return(1);
		}
	}

	if ($channel->{'synced'})
	{
		if ($nick->{'nick'} ne $channel->{'server'}->{'nick'})
		{
			my $format = '';

			if (Irssi::settings_get_bool('mh_userstatus_show_host'))
			{
				$format = '_host'
			}

			my $msglevel = 0;

			if ($nick->{'gone'})
			{
				if (Irssi::settings_get_bool('mh_userstatus_noact_gone'))
				{
					$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
				}

				$msglevel = $msglevel | Irssi::MSGLEVEL_PARTS;
				$channel->printformat($msglevel, 'mh_userstatus_gone' . $format, $nick->{'nick'}, $nick->{'host'}, nick_prefix($nick));

			} else {

				if (Irssi::settings_get_bool('mh_userstatus_noact_here'))
				{
					$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
				}

				$msglevel = $msglevel | Irssi::MSGLEVEL_JOINS;
				$channel->printformat($msglevel, 'mh_userstatus_here' . $format, $nick->{'nick'}, $nick->{'host'}, nick_prefix($nick));
			}
		}
	}
}

sub signal_nicklist_serverop_changed_last
{
	my ($channel, $nick) = @_;

	my $servertag = lc($channel->{'server'}->{'tag'});

	if (exists($whois_in_progress->{$servertag}))
	{
		if ($whois_in_progress->{$servertag})
		{
			return(1);
		}
	}

	if ($channel->{'synced'})
	{
		if ($nick->{'nick'} ne $channel->{'server'}->{'nick'})
		{
			my $format = '';

			if (Irssi::settings_get_bool('mh_userstatus_show_host'))
			{
				$format = '_host'
			}

			my $msglevel = 0;

			if ($nick->{'serverop'})
			{
				if (Irssi::settings_get_bool('mh_userstatus_noact_oper'))
				{
					$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
				}

				$msglevel = $msglevel | Irssi::MSGLEVEL_JOINS;
				$channel->printformat($msglevel, 'mh_userstatus_oper' . $format, $nick->{'nick'}, $nick->{'host'}, nick_prefix($nick));

			} else {

				if (Irssi::settings_get_bool('mh_userstatus_noact_deop'))
				{
					$msglevel = $msglevel | Irssi::MSGLEVEL_NO_ACT;
				}

				$msglevel = $msglevel | Irssi::MSGLEVEL_PARTS;
				$channel->printformat($msglevel, 'mh_userstatus_deop' . $format, $nick->{'nick'}, $nick->{'host'}, nick_prefix($nick));
			}
		}
	}
}

sub signal_event_311
{
	my ($server) = @_;

	if ($server)
	{
		$whois_in_progress->{lc($server->{'tag'})} = 1;
	}
}

sub signal_event_318
{
	my ($server) = @_;

	if ($server)
	{
		$whois_in_progress->{lc($server->{'tag'})} = 0;
	}
}

##############################################################################
#
# irssi command functions
#
##############################################################################

sub command_whoa
{
	my ($data, $server, $windowitem) = @_;

	if (ref($windowitem) ne 'Irssi::Irc::Channel')
	{
		Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_userstatus_error', 'Not a channel window');
		return(0);
	}

	if (not $windowitem->{'synced'})
	{
		$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_userstatus_error', 'Channel not synced, please wait');
		return(0);
	}

	my $count = 0;

	for my $nick (sort({ lc($a->{'nick'}) cmp lc($b->{'nick'}) } $windowitem->nicks()))
	{
		if ($nick->{'nick'} ne $windowitem->{'server'}->{'nick'})
		{
			my $format = '';

			if (Irssi::settings_get_bool('mh_userstatus_show_host'))
			{
				$format = '_host'
			}

			if ($nick->{'gone'})
			{
				$count++;
				$windowitem->printformat(Irssi::MSGLEVEL_PARTS, 'mh_userstatus_whoa_gone' . $format, $nick->{'nick'}, $nick->{'host'}, nick_prefix($nick));
			}
		}
	}

	$windowitem->printformat(Irssi::MSGLEVEL_PARTS, 'mh_userstatus_whoa', $count);
}

sub command_whoo
{
	my ($data, $server, $windowitem) = @_;

	if (ref($windowitem) ne 'Irssi::Irc::Channel')
	{
		Irssi::active_win->printformat(Irssi::MSGLEVEL_CRAP, 'mh_userstatus_error', 'Not a channel window');
		return(0);
	}

	if (not $windowitem->{'synced'})
	{
		$windowitem->printformat(Irssi::MSGLEVEL_CRAP, 'mh_userstatus_error', 'Channel not synced, please wait');
		return(0);
	}

	my $count = 0;

	for my $nick (sort({ lc($a->{'nick'}) cmp lc($b->{'nick'}) } $windowitem->nicks()))
	{
		if ($nick->{'nick'} ne $windowitem->{'server'}->{'nick'})
		{
			my $format = '';

			if (Irssi::settings_get_bool('mh_userstatus_show_host'))
			{
				$format = '_host'
			}

			if ($nick->{'serverop'})
			{
				$count++;
				$windowitem->printformat(Irssi::MSGLEVEL_JOINS, 'mh_userstatus_whoo_oper' . $format, $nick->{'nick'}, $nick->{'host'}, nick_prefix($nick));
			}
		}
	}

	$windowitem->printformat(Irssi::MSGLEVEL_JOINS, 'mh_userstatus_whoo', $count);
}

sub command_help
{
	my ($data, $server, $windowitem) = @_;

	$data = lc(trim_space($data));

	if ($data =~ m/^whoa$/i)
	{
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('WHOA', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('Shows all users in the current channel who are away.', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('See also: SET ' . uc('mh_userstatus') . ', WHO, WHOO', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);

		Irssi::signal_stop();

	} elsif ($data =~ m/^whoo$/i)
	{
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('WHOO', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('Shows all users in the current channel who are opers.', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('See also: SET ' . uc('mh_userstatus') . ', WHO, WHOA', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);

		Irssi::signal_stop();
	}
}

##############################################################################
#
# script on load
#
##############################################################################

Irssi::theme_register([
  'mh_userstatus_gone',           '$2{channick $0} is now {hilight gone}',
  'mh_userstatus_here',           '$2{channick_hilight $0} is now {hilight here}',
  'mh_userstatus_oper',           '$2{channick_hilight $0} is now {hilight oper}',
  'mh_userstatus_deop',           '$2{channick $0} is now {hilight not oper}',
  'mh_userstatus_gone_host',      '$2{channick $0} {chanhost $1} is now {hilight gone}',
  'mh_userstatus_here_host',      '$2{channick_hilight $0} {chanhost_hilight $1} is now {hilight here}',
  'mh_userstatus_oper_host',      '$2{channick_hilight $0} {chanhost_hilight $1} is now {hilight oper}',
  'mh_userstatus_deop_host',      '$2{channick $0} {chanhost $1} is now {hilight not oper}',
  'mh_userstatus_error',          '{error $0}',
  'mh_userstatus_whoa',           'A total of $0 users are {hilight gone}',
  'mh_userstatus_whoo',           'A total of $0 users are {hilight oper}',
  'mh_userstatus_whoa_gone',      '$2{channick $0} is {hilight gone}',
  'mh_userstatus_whoo_oper',      '$2{channick_hilight $0} is {hilight oper}',
  'mh_userstatus_whoa_gone_host', '$2{channick $0} {chanhost $1} is {hilight gone}',
  'mh_userstatus_whoa_oper_host', '$2{channick_hilight $0} {chanhost_hilight $1} is {hilight oper}',
]);

Irssi::settings_add_int('mh_userstatus',  'mh_userstatus_delay',     5);
Irssi::settings_add_int('mh_userstatus',  'mh_userstatus_lag_limit', 5);
Irssi::settings_add_bool('mh_userstatus', 'mh_userstatus_show_host', 1);
Irssi::settings_add_bool('mh_userstatus', 'mh_userstatus_show_mode', 1);
Irssi::settings_add_bool('mh_userstatus', 'mh_userstatus_noact_here', 0);
Irssi::settings_add_bool('mh_userstatus', 'mh_userstatus_noact_gone', 0);
Irssi::settings_add_bool('mh_userstatus', 'mh_userstatus_noact_oper', 0);
Irssi::settings_add_bool('mh_userstatus', 'mh_userstatus_noact_deop', 0);

for my $channel (Irssi::channels())
{
	if ($channel->{'synced'})
	{
		signal_channel_sync_last($channel);
	}
}

Irssi::signal_add_last('channel sync',              'signal_channel_sync_last');
Irssi::signal_add_last('nicklist gone changed',     'signal_nicklist_gone_changed_last');
Irssi::signal_add_last('nicklist serverop changed', 'signal_nicklist_serverop_changed_last');
Irssi::signal_add('event 311',                      'signal_event_311');
Irssi::signal_add('event 318',                      'signal_event_318');

Irssi::command_bind('whoa', 'command_whoa', 'mh_userstatus');
Irssi::command_bind('whoo', 'command_whoo', 'mh_userstatus');
Irssi::command_bind('help', 'command_help');

1;

##############################################################################
#
# eof mh_userstatus.pl
#
##############################################################################
