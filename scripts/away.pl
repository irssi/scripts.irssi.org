# $Id: away.pl,v 1.6 2003/02/25 08:48:56 nemesis Exp $

use Irssi 20020121.2020 ();
$VERSION = "0.23";
%IRSSI = (
	  authors     => 'Jean-Yves Lefort, Larry "Vizzie" Daffner, Kees Cook',
	  contact     => 'jylefort@brutele.be, vizzie@airmail.net, kc@outflux.net',
	  name        => 'away',
	  description => 'Away with reason, unaway, and autoaway',
	  license     => 'BSD',
	  changed     => '$Date: 2003/02/25 08:48:56 $ ',
);

# /SET
#
#	away_reason		if you are not away and type /AWAY without
#				arguments, this string will be used as
#				your away reason
#
#       autoaway                number of seconds before marking away,
#                               only actions listed in "autounaway_level"
#                               will reset the timeout.
#
#	autounaway_level	if you are away and you type a message
#				belonging to one of these levels, you'll be
#				automatically unmarked away
#
#				levels considered:
#
#				DCC		a dcc chat connection has
#						been established
#				PUBLICS		a public message from you
#				MSGS		a private message from you
#				ACTIONS		an action from you
#				NOTICES		a notice from you
#
# changes:
#       2003-02-24
#                       0.23?
#                       merged with autoaway script
#
#	2003-01-09	release 0.22
#			* command char independed
#
#	2002-07-04	release 0.21
#			* signal_add's uses a reference instead of a string
#
# todo:
#
#	* rewrite the away command to support -one and -all switches
#       * make auto-away stuff sane for multiple servers
#       * make auto-away reason configurable
#
# (c) 2003 Jean-Yves Lefort (jylefort@brutele.be)
#
# (c) 2000 Larry Daffner (vizzie@airmail.net)
#     You may freely use, modify and distribute this script, as long as
#      1) you leave this notice intact
#      2) you don't pretend my code is yours
#      3) you don't pretend your code is mine
#
# (c) 2003 Kees Cook (kc@outflux.net)
#      merged 'autoaway.pl' and 'away.pl'
#
# BUGS:
#  - This only works for the first server

use strict;
use Irssi;
use Irssi::Irc;			# for DCC object

my ($autoaway_sec, $autoaway_to_tag, $am_away);

sub away {
  my ($args, $server, $item) = @_;

  if ($server)
  {
    if (!$server->{usermode_away})
    {
      # go away
      $am_away=1;

      # stop autoaway
      if (defined($autoaway_to_tag)) {
        Irssi::timeout_remove($autoaway_to_tag);
        $autoaway_to_tag = undef();
      }

      if (!defined($args))
      {
        $server->command("AWAY " . Irssi::settings_get_str("away_reason"));
        Irssi::signal_stop();
      }
    }
    else
    {
      # come back
      $am_away=0;
      reset_timer();
    }

  }
}

sub cond_unaway {
  my ($server, $level) = @_;
  if (Irssi::level2bits(Irssi::settings_get_str("autounaway_level")) & $level)
  {
    #if ($server->{usermode_away})
    if ($am_away)
    {
      # come back from away
      $server->command("AWAY");
    }
    else
    {
      # bump the autoaway timeout
      reset_timer();
    }
  }
}

sub dcc_connected {
  my ($dcc) = @_;
  cond_unaway($dcc->{server}, MSGLEVEL_DCC) if ($dcc->{type} eq "CHAT");
}

sub message_own_public {
  my ($server, $msg, $target) = @_;
  cond_unaway($server, MSGLEVEL_PUBLIC);
}

sub message_own_private {
  my ($server, $msg, $target, $orig_target) = @_;
  cond_unaway($server, MSGLEVEL_MSGS);
}

sub message_irc_own_action {
  my ($server, $msg, $target) = @_;
  cond_unaway($server, MSGLEVEL_ACTIONS);
}

sub message_irc_own_notice {
  my ($server, $msg, $target) = @_;
  cond_unaway($server, MSGLEVEL_NOTICES);
}

#
# /AUTOAWAY - set the autoaway timeout
#
sub away_setupcheck {
  $autoaway_sec = Irssi::settings_get_int("autoaway");
  reset_timer();
}


sub auto_timeout {
  my ($data, $server) = @_;
  my $msg = "autoaway after $autoaway_sec seconds";

  Irssi::timeout_remove($autoaway_to_tag);
  $autoaway_to_tag=undef;

  Irssi::print($msg);

  $am_away=1;

  my (@servers) = Irssi::servers();
  $servers[0]->command("AWAY $msg");
}

sub reset_timer {
    if (defined($autoaway_to_tag)) {
      Irssi::timeout_remove($autoaway_to_tag);
      $autoaway_to_tag = undef;
    }
    if ($autoaway_sec) {
      $autoaway_to_tag = Irssi::timeout_add($autoaway_sec*1000,
                                                "auto_timeout", "");
    }
}

Irssi::settings_add_str("misc", "away_reason", "not here");
Irssi::settings_add_str("misc", "autounaway_level", "PUBLIC MSGS ACTIONS DCC");
Irssi::settings_add_int("misc", "autoaway", 0);

Irssi::signal_add("dcc connected",          \&dcc_connected);
Irssi::signal_add("message own_public",     \&message_own_public);
Irssi::signal_add("message own_private",    \&message_own_private);
Irssi::signal_add("message irc own_action", \&message_irc_own_action);
Irssi::signal_add("message irc own_notice", \&message_irc_own_notice);
Irssi::signal_add("setup changed"       =>  \&away_setupcheck);

Irssi::command_bind("away",     "away");

away_setupcheck();

