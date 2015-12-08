##############################################################################
#
# mh_sbsplitmode.pl v1.03 (20151208)
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
# provides a statusbar item showing if your server is in splitmode and /splitmode to show details
#
# will show an indicator if your active server is in splitmode, with
# optional details. there is also a command /splitmode that will list
# the status of all servers being watched. since /stats d is disabled
# for regular users on most irc networks, i have provided a setting to
# tell which networks we will çheck - currently only IRCnet is in the
# list. if you do not have the privileges it will tell you that splitmode
# is unavailable.
#
# settings:
#
# mh_sbsplitmode_delay (default 5): Aproximate delay (in minutes) between
# checking /stats d
#
# mh_sbsplitmode_networks (default IRCnet): a comma-seperated list of networks
# we will check for splitmode
#
# mh_sbsplitmode_show_details (default ON): show how many servers (s:) and/or
# users (u:) are missing before we go out of splitmode
#
# mh_sbsplitmode_lag_limit (default 5): amount of lag (in seconds) where we skip
# checking the server for splitmode
#
# to configure irssi to show the new statusbar item in a default irssi
# installation type '/statusbar window add -after window_empty mh_sbsplitmode'.
# see '/help statusbar' for more details and do not forget to '/save'
#
# history:
#	v1.03 (20151208)
#		cleaned up useless code.
#	v1.02 (20151207)
#		fixed bug where the timeout never got started
#		added a few comments
#	v1.01 (20151203)
#		added _lag_limit and supporting code to skip /stats d on lag
#		will now print server is in splitmode in all relevant windows
#	v1.00 (20151201)
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
	'name'        => 'mh_sbsplitmode',
	'description' => 'provides a statusbar item showing if your server is in splitmode and /splitmode to show details',
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

our $state;

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

sub request_stats_d
{
	my ($server) = @_;

	if (ref($server) eq 'Irssi::Irc::Server')
	{
		if ($server->{'connected'})
		{
			for my $networkname (split(',', Irssi::settings_get_str('mh_sbsplitmode_networks')))
			{
				if (lc($networkname) eq lc($server->{'chatnet'}))
				{
					my $lag_limit = Irssi::settings_get_int('mh_sbsplitmode_lag_limit');

					if ($lag_limit)
					{
						$lag_limit = $lag_limit * 1000; # seconds to milliseconds
					}

					if ((not $lag_limit) or ($lag_limit > $server->{'lag'}))
					{
						$server->redirect_event('mh_sbsplitmode stats d',
							1,  # count
							'', # arg
							-1, # remote
							'', # failure signal
							{   # signals
								'event 248' => 'redir mh_sbsplitmode stats d',
								'event 481' => 'redir mh_sbsplitmode stats d',
								''          => 'event empty',
							}
						);
						$server->send_raw("stats d");
						last;
					}
				}
			}
		}
	}
}

sub request_stats_d_all
{
	for my $server (Irssi::servers())
	{
		request_stats_d($server);
	}
}

sub state_remove_server
{
	my ($server) = @_;

	if (exists($state->{lc($server->{'tag'})}))
	{
		delete($state->{lc($server->{'tag'})});
	}
}

##############################################################################
#
# irssi timeouts
#
##############################################################################

sub timeout_request_stats_d
{
	request_stats_d_all();

	my $delay = Irssi::settings_get_int('mh_sbsplitmode_delay');

	if ($delay > 60)
	{
		$delay = 60;

	} elsif ($delay < 1)
	{
		$delay = 1;
	}

	$delay = ($delay * 60000); # in minutes
	$delay = $delay + (int(rand(30000)) + 1);

	Irssi::timeout_add_once($delay, 'timeout_request_stats_d', undef);
}

##############################################################################
#
# irssi signal handlers
#
##############################################################################

sub signal_redir_stats_d
{
	my ($server, $data, $sender) = @_;

	if ($data =~ /.* S:([0-9]*).* SS:[0-9]*\/([0-9]*)\/([0-9]*).* SU:[0-9]*\/([0-9]*)\/([0-9]*).*/)
	{
		my $servertag = lc($server->{'tag'});
		my $old_s     = 0;

		if (exists($state->{$servertag}))
		{
			$old_s = $state->{$servertag}->{'s'}
		}

		$state->{$servertag}->{'s'}      = int($1);
		$state->{$servertag}->{'ss_min'} = int($2);
		$state->{$servertag}->{'ss_cur'} = int($3);
		$state->{$servertag}->{'su_min'} = int($4);
		$state->{$servertag}->{'su_cur'} = int($5);

		Irssi::statusbar_items_redraw('mh_sbsplitmode');

		#
		# print to all relevant windows when server enters/leaves splitmode
		#

		if ($old_s != $state->{$servertag}->{'s'})
		{
			my $format_server = $server->{'tag'} . '/' . $server->{'real_address'};
           	my $format_data   = '';

			if ($state->{$servertag}->{'s'})
			{
				$format_data = 'is in';

			} else {

				$format_data = 'is no longer in';
			}

			for my $window (Irssi::windows())
			{
				if (exists($window->{'active_server'}))
				{
					if (lc($window->{'active_server'}->{'tag'}) eq $servertag)
					{
						$window->printformat(Irssi::MSGLEVEL_CRAP | Irssi::MSGLEVEL_NO_ACT, 'mh_sbsplitmode_info', $format_server, $format_data);
					}
				}
			}
		}
	} elsif ($data =~ /.*permission.*/i)
	{
		my $servertag                    = lc($server->{'tag'});
		$state->{$servertag}->{'s'}      = -1;
		$state->{$servertag}->{'ss_min'} = 0;
		$state->{$servertag}->{'ss_cur'} = 0;
		$state->{$servertag}->{'su_min'} = 0;
		$state->{$servertag}->{'su_cur'} = 0;

		Irssi::statusbar_items_redraw('mh_sbsplitmode');
	}
}

sub signal_setup_changed_last
{
	Irssi::statusbar_items_redraw('mh_sbsplitmode');
}

##############################################################################
#
# irssi command functions
#
##############################################################################

sub command_splitmode
{
	my ($data, $server, $windowitem) = @_;

	if ($state)
	{
		for my $servertag (keys($state))
		{
			$server = Irssi::server_find_tag($servertag);

			if ($server)
			{
				my $format_server = $server->{'tag'} . '/' . $server->{'real_address'};
				my $format_data   = '';
				my $format_detail = '';

				if ($state->{$servertag}->{'s'} < 0)
				{
					$format_data = 'Splitmode unavailable';

				} else {

					if ($state->{$servertag}->{'s'})
					{
						$format_data = 'In splitmode';

						if ($state->{$servertag}->{'s'} > 1)
						{
							$format_data = $format_data . ' since ' . localtime($state->{$servertag}->{'s'});
						}

					} else {

						$format_data = 'Not in splitmode';
					}

					$format_detail = 'servers:' . $state->{$servertag}->{'ss_cur'} . '/' . $state->{$servertag}->{'ss_min'} . ' users:' . $state->{$servertag}->{'su_cur'} . '/' . $state->{$servertag}->{'su_min'};
				}

				Irssi::active_win->printformat(MSGLEVEL_CRAP, 'mh_sbsplitmode_line', $format_server, $format_data, $format_detail);
			}
		}

	} else {

		Irssi::active_win->printformat(MSGLEVEL_CRAP, 'mh_sbsplitmode_error', 'No servers');

	}
}

sub command_help
{
	my ($data, $server, $windowitem) = @_;

	$data = lc(trim_space($data));

	if ($data =~ m/^splitmode$/i)
	{
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('SPLITMODE', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('Shows the splitmode status of all watched servers.', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('Splitmode occurs when a servers users or server links goes below a predefined value.', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('See also: SET ' . uc('mh_sbsplitmode') .', STATS', Irssi::MSGLEVEL_CLIENTCRAP);
		Irssi::print('', Irssi::MSGLEVEL_CLIENTCRAP);

		Irssi::signal_stop();
	}
}

##############################################################################
#
# statusbar item handlers
#
##############################################################################

sub statusbar_splitmode
{
	my ($statusbaritem, $get_size_only) = @_;

	my $server = Irssi::active_server();
	my $format = '';

	if ($server)
	{
		if ($state)
		{
			my $servertag = lc($server->{'tag'});

			if (exists($state->{$servertag}))
			{
				if ($state->{$servertag}->{'s'} < 0)
				{
					$format = 'Splitmode unavailable';

				} elsif ($state->{$servertag}->{'s'})
				{
					$format = 'Splitmode';

					if (Irssi::settings_get_bool('mh_sbsplitmode_show_details'))
					{
						if ($state->{$servertag}->{'ss_cur'} < $state->{$servertag}->{'ss_min'})
						{
							$format = $format . ' s:' . ($state->{$servertag}->{'ss_min'} - $state->{$servertag}->{'ss_cur'});
						}

						if ($state->{$servertag}->{'su_cur'} < $state->{$servertag}->{'su_min'})
						{
							$format = $format . ' u:' . ($state->{$servertag}->{'su_min'} - $state->{$servertag}->{'su_cur'});
						}
					}
				}
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

Irssi::settings_add_int('mh_sbsplitmode',  'mh_sbsplitmode_delay',        5);
Irssi::settings_add_str('mh_sbsplitmode',  'mh_sbsplitmode_networks',     'IRCnet');
Irssi::settings_add_bool('mh_sbsplitmode', 'mh_sbsplitmode_show_details', 1);
Irssi::settings_add_int('mh_sbsplitmode',  'mh_sbsplitmode_lag_limit',    5);

Irssi::theme_register([
	'mh_sbsplitmode_line',  '{server $0}: $1 {comment $2}',
	'mh_sbsplitmode_info',  '{server $0} $1 {hilight splitmode}',
	'mh_sbsplitmode_error', '{error $0}',
]);

Irssi::Irc::Server::redirect_register('mh_sbsplitmode stats d',
	0, # remote
	0, # timeout
	{  # start signals
		'event 248' => -1, # RPL_STATSDEFINE  stats d line
		'event 481' => -1, # ERR_NOPRIVILEGES error no privileges
 	},
	{  # stop signals
		'event 219' => -1, # RPL_ENDOFSTATS end of stats
	},
	undef # optional signals
);

Irssi::statusbar_item_register('mh_sbsplitmode', '', 'statusbar_splitmode');

Irssi::signal_add('redir mh_sbsplitmode stats d', 'signal_redir_stats_d');
Irssi::signal_add_last('event connected',         'request_stats_d');
Irssi::signal_add('server disconnected',          'state_remove_server');
Irssi::signal_add_last('setup changed',           'signal_setup_changed_last');

Irssi::command_bind('splitmode', 'command_splitmode', 'mh_sbsplitmode');
Irssi::command_bind('help',      'command_help');

timeout_request_stats_d();

1;

##############################################################################
#
# eof mh_sbsplitmode.pl
#
##############################################################################
