use strict;
use warnings;
use POSIX;
use Irssi;

our $VERSION = "0.40";
our %IRSSI = (
    authors     => 'Jean-Yves Lefort, Larry "Vizzie" Daffner, Kees Cook, '
                   . 'vague, Krytarik Raido',
    contact     => 'jylefort@brutele.be, vizzie@airmail.net, kc@outflux.net, '
                   . 'vague!#irssi@freenode, krytarik@tuxgarage.com',
    url         => 'https://bitbucket.org/krytarik/irssi-scripts',
    name        => 'Away',
    description => 'Away with reason, unaway, and autoaway',
    license     => 'BSD',
    changed     => '2017-12-07 09:23:04 +0100',
);

# /SET
#
#	away_reason		if you are not away and type /AWAY without
#				arguments, this string will be used as
#				your away reason
#
#	away_timeout		time before marking away, only actions
#				listed in "away_activity_level"
#				will reset the timeout
#
#	away_activity_level	if you are away and you type a message
#				belonging to one of these levels, you'll be
#				automatically unmarked away
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
# (c) 2017 vague (vague!#irssi@freenode)
#
# (c) 2017 Krytarik Raido (krytarik@tuxgarage.com)

my ($reason, $timeout, $actlevel, $timeout_tag);

sub away {
  my ($args, $server) = @_;

  unless ($server && $server->{connected}) {
    return;
  }

  if (!$server->{usermode_away}) {
    # stop autoaway
    if ($timeout_tag) {
      Irssi::timeout_remove($timeout_tag);
      $timeout_tag = 0;
    }
    # go away
    unless ($args) {
      $server->command("AWAY -all " . strftime($reason, localtime));
      Irssi::signal_stop();
    }
  }
  else {
    # come back
    reset_timer();
  }
}

sub auto_timeout {
  $timeout_tag = 0;

  foreach my $server (Irssi::servers()) {
    if ($server->{connected} && !$server->{usermode_away}) {
      $server->command("AWAY -all " . strftime($reason, localtime));
      last;
    }
  }
}

sub cond_unaway {
  my ($server, $level) = @_;

  if ($actlevel & $level) {
    if ($server->{usermode_away}) {
      # come back from away
      $server->command("AWAY -all");
    }
    else {
      # bump the autoaway timeout
      reset_timer();
    }
  }
}

sub reset_timer {
  if ($timeout_tag) {
    Irssi::timeout_remove($timeout_tag);
    $timeout_tag = 0;
  }

  if ($timeout) {
    $timeout_tag = Irssi::timeout_add_once($timeout, "auto_timeout", "");
  }
}

sub message_own_public {
  my ($server) = @_;
  cond_unaway($server, MSGLEVEL_PUBLIC);
}

sub message_own_private {
  my ($server) = @_;
  cond_unaway($server, MSGLEVEL_MSGS);
}

sub message_irc_own_action {
  my ($server) = @_;
  cond_unaway($server, MSGLEVEL_ACTIONS);
}

sub message_irc_own_notice {
  my ($server) = @_;
  cond_unaway($server, MSGLEVEL_NOTICES);
}

sub message_dcc_own {
  my ($dcc) = @_;
  cond_unaway($dcc->{server}, MSGLEVEL_DCCMSGS);
}

sub message_dcc_own_action {
  my ($dcc) = @_;
  cond_unaway($dcc->{server}, MSGLEVEL_DCCMSGS | MSGLEVEL_ACTIONS);
}

sub setup_changed {
  $reason   = Irssi::settings_get_str("away_reason");
  if(my $t = Irssi::settings_get_time("autoaway")) {
    warn("Setting misc/autoaway has been renamed to away/away_timeout");
    $timeout = $t;
  }
  else {
    $timeout  = Irssi::settings_get_time("away_timeout");
  }
  if(my $l = Irssi::settings_get_level("autounaway_level")) {
    warn("Setting misc/autounaway_level has been renamed to away/away_activity_level");
    $actlevel = $l;
  }
  else {
    $actlevel = Irssi::settings_get_level("away_activity_level");
  }
  reset_timer();
}

Irssi::settings_add_str("misc",   "away_reason", "");
Irssi::settings_add_time("misc",  "autoaway", "");
Irssi::settings_add_level("misc", "autounaway_level", "");
Irssi::settings_add_str("away",   "away_reason", "Away since %F %T %z");
Irssi::settings_add_time("away",  "away_timeout", "20mins");
Irssi::settings_add_level("away", "away_activity_level", "PUBLIC MSGS ACTIONS DCCMSGS");

setup_changed();

Irssi::signal_add({
  "message own_public"     => "message_own_public",
  "message own_private"    => "message_own_private",
  "message irc own_action" => "message_irc_own_action",
  "message irc own_notice" => "message_irc_own_notice",
  "message dcc own"        => "message_dcc_own",
  "message dcc own_action" => "message_dcc_own_action",
  "setup changed"          => "setup_changed",
});

Irssi::command_bind("away", "away");
