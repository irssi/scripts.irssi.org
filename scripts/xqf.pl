# $Id: xqf.pl,v 0.14 2004/07/03 14:52:50 mizerou Exp $
#
# XQF to Irssi/Licq script. Idea from an X-Chat script (xqf-xchat).
#
# Portions of away_verbose used with permission from Koenraad Heijlen.
#
# ChangeLog:
# 0.14:
#  - !aping lookups coded (uses Socket)
#  - bugfix: when passing stuff to licq_fifo and licq not running
# 0.13:
#  - first public release, updates to follow.
#  - remove control codes in licq away message
# 0.12:
#  - incorporated a lightweight hack of away_verbose
#    - no longer uses 'awe' and 'gone', all internally handled
#  - some servers use whitespace in beginning of name, fixed
#  - case-insensitive variables in setting 'xqfAwayMessage'
#  - redundant settings removed, code cleanups
# 0.11:
#  - licq support added
#  - uses the 'awe' and 'gone' commands from away_verbose for now
# 0.10:
#  - basics completed
#
# TODO:
#  - a way to detect when you're back from the game?
#  - timer checks to update licq and irssi (compare server addr)?
#  - plans to convert mIRC script 'autoping' to perl (parts of it)
#
# Bugs/Ideas/Improvements:
#  - report the above to mizerou @ irc.freenode.net/#fiend
#	or irc.enterthegame.com/#fiend
#
use strict;
use Socket;

use vars qw($VERSION %IRSSI);
use Irssi qw(command_bind active_win);

$VERSION = '0.14';
%IRSSI = (
    authors	=> 'mizerou',
    contact	=> 'mizerou@telus.net',
    name	=> 'XQF',
    description	=> 'automatically sends xqf data to irssi and optionally licq',
    license	=> 'GPLv2',
    url		=> 'none',
    changed	=> 'Sat June 05 05:12 MST 2004',
    modules	=> 'Socket',
    commands	=> 'xqf'
);

# setup irssi settings
Irssi::settings_add_str('xqf', 'xqfLaunchInfo' => $ENV{HOME}.'/.qf/LaunchInfo.txt');
Irssi::settings_add_str('xqf', 'xqfLicqFifo' => $ENV{HOME}.'/.licq/licq_fifo');
Irssi::settings_add_str('xqf', 'xqfChannels', 'foo|bar');
Irssi::settings_add_str('xqf', 'xqfAwayMessage', 'Playing $game ($mod) @ $name ($addr)');
Irssi::settings_add_bool('xqf', 'xqfSetLicq', 0);
Irssi::signal_add_last("message public", "xqfPing");

# global vars
my ($game, $name, $addr, $mod);
my %xqfAway;
my $timeout = Irssi::timeout_add_once(4000, 'checkLaunchInfo', undef);

# remove LaunchInfo on startup
if (-e Irssi::settings_get_str('xqfLaunchInfo')) {
  unlink Irssi::settings_get_str('xqfLaunchInfo');
}

# /xqf: handles returning from games
command_bind xqf => sub {
  if ($xqfAway{'away'}) {
    my (@servers) = Irssi::servers();
    if (-e Irssi::settings_get_str('xqfLaunchInfo')) {
      unlink Irssi::settings_get_str('xqfLaunchInfo');
    }
    $timeout = Irssi::timeout_add_once(4000, 'checkLaunchInfo', undef);
    $servers[0]->command("AWAY");
    xqfBack();
    return;
  } else {
    active_win->print("XQF\\ You aren't currently playing a game.");
    return;
  }
  return 0;
};

# checks if user has launched a game from xqf
sub checkLaunchInfo {
  if (!-e Irssi::settings_get_str('xqfLaunchInfo')) {
    $timeout = Irssi::timeout_add_once(4000, 'checkLaunchInfo' , undef);
    return;
  } else {
    my (@servers) = Irssi::servers();
    Irssi::timeout_remove($timeout);
    my $xqfMessage = fetchLaunchInfo();
    $servers[0]->command("AWAY " . $xqfMessage);
    xqfAway($xqfMessage);
    active_win->print("XQF\\ Please type /xqf when you have finished playing.");
    return;
  }
  return 0;
}

# parses and returns data from LaunchInfo.txt
sub fetchLaunchInfo {
  my $reply;

  open(FH, "<", Irssi::settings_get_str('xqfLaunchInfo'));
  my @LaunchInfo = <FH>;
  close (FH);

  foreach my $line (@LaunchInfo) {
    ($game = $line) =~ s/^GameType (.+)\n/$1/ if ($line =~ /^GameType/);
    ($name = $line) =~ s/^ServerName (.+)\n/$1/ if ($line =~ /^ServerName/);
    ($addr = $line) =~ s/^ServerAddr (.+)\n/$1/ if ($line =~ /^ServerAddr/);
    ($mod = $line) =~ s/^ServerMod (.+)\n/$1/ if ($line =~ /^ServerMod/);
  }
  s/^\s+// for ($game, $name, $addr, $mod);

  $reply = Irssi::settings_get_str('xqfAwayMessage');
  $reply =~ s/(\$\w+)/lc($1)/eego;	# case insensitive
  return ($reply);			# return the users custom reply
}

#
# functions below were borrowed from away_verbose.pl and modified to suit my needs
# used with permission from Koenraad Heijlen <koenraad@ulyssis.org>
#

# converts unix time into human readable format
sub xqfSecs2Text {
  my $xqfAwayTexts = "wk,wks,day,days,hr,hrs,min,mins,sec,secs";
  my ($secs) = @_;
  my ($wk_,$wks_,$day_,$days_,$hr_,$hrs_,$min_,$mins_,$sec_,$secs_) = (0,1,2,3,4,5,6,7,8,9,10);
  my @texts = split(/,/, $xqfAwayTexts);

  my $mins = int($secs / 60); $secs -= ($mins * 60);
  my $hrs = int($mins / 60); $mins -= ($hrs * 60);
  my $days = int($hrs / 24); $hrs -= ($days * 24);
  my $wks = int($days / 7); $days -= ($wks * 7);
  my $text = (($wks > 0) ? (($wks > 1) ? "$wks $texts[$wks_] " : "$wks $texts[$wk_] ") : "");
  $text .= (($days > 0) ? (($days > 1) ? "$days $texts[$days_] " : "$days $texts[$day_] ") : "");
  $text .= (($hrs > 0) ? (($hrs > 1) ? "$hrs $texts[$hrs_] " : "$hrs $texts[$hr_] ")  : "");
  $text .= (($mins > 0) ? (($mins > 1) ? "$mins $texts[$mins_] " : "$mins $texts[$min_] ") : "");
  $text .= (($secs > 0) ? (($secs > 1) ? "$secs $texts[$secs_] " : "$secs $texts[$sec_] ") : "");
  $text =~ s/ $//;
  return ($text);
}

# sets away status on irssi and licq
sub xqfAway {
  my ($text, $witem) = @_;
  my $xqfChannels = Irssi::settings_get_str('xqfChannels');

  $xqfAway{'time'} = time;
  $xqfAway{'reason'} = "$text";
  $xqfAway{'away'} = 1;
  foreach my $server (Irssi::servers) {
    foreach my $chan ($server->channels) {
      if ((($server->{chatnet} .":". $chan->{name}) =~ /$xqfChannels/i)) {
        $server->command("DESCRIBE $chan->{name} is away: $text");
      }
    }
  }

  if (Irssi::settings_get_bool('xqfSetLicq')) {
    $text =~ s/\p{IsCntrl}//g;
    active_win->command("exec -name xqfLicq echo 'status na \"$text\"' > " . Irssi::settings_get_str('xqfLicqFifo')); # 0.14: bugfix
    active_win->command("exec -close xqfLicq");    
  }
}

# returns from away status on irssi and licq
sub xqfBack { 
  my ($text) = @_;
  my $xqfChannels = Irssi::settings_get_str('xqfChannels');

  foreach my $server (Irssi::servers) {
    foreach my $chan ($server->channels) {
      if ((($server->{chatnet} .":". $chan->{name}) =~ /$xqfChannels/i)) {
        $server->command("DESCRIBE $chan->{name} has returned from: $xqfAway{'reason'} after " . xqfSecs2Text(time - $xqfAway{'time'}));
      }
    }
  }
  if (Irssi::settings_get_bool('xqfSetLicq')) {
    active_win->command("exec -name xqfLicq echo 'status online' > " . Irssi::settings_get_str('xqfLicqFifo')); # 0.14: bugfix
    active_win->command("exec -close xqfLicq");
  }
  $xqfAway{'time'} = 0;
  $xqfAway{'reason'} = "";
  $xqfAway{'away'} = 0;
}
        
# handle !aping requests
sub xqfPing {
  my ($server, $host, $nick, $address, $channel) = @_;
  my ($xqfChannels) = Irssi::settings_get_str('xqfChannels');
  my ($average_ping);

  if ($channel !~ /$xqfChannels/i) { return; }
  if ($host !~ /^!aping/) { return; }
  $host =~ s/^!aping //;

  if ($xqfAway{'away'}) {
    $server->command("msg $channel No pinging while gaming");
    return;
  }

  # we make sure the host is real
  my ($inetaddr) = gethostbyname($host);
  if (!$inetaddr) {
    $server->command("msg $channel I can't find $host");
    return;
  }
  my $addr = inet_ntoa(scalar gethostbyname($host));

  my @ping = `/bin/ping -w 2 -i .5 -c 3 $addr`;
  my $average_line = $ping[-1];

  if ($average_line !~ m#^.+= \S+/(\S+)/\S+/.*#) {
    if ($average_line !~ /^rtt.*/) {
      $server->command("msg $channel Could not connect to $host");
      return;
    } else {
      $server->command("msg $channel Could not parse results from ping");
      return;
    }
  } else {
    $average_ping = "${1}ms";
  }
  $server->command("msg $channel $host = $average_ping");
  return;
}

# EOF
