###############################################################################
# badword.pl
# Copyright (C) 2002  Jan 'fissie' Sembera <fis@ji.cz>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
###############################################################################
# This is configurable badword script. It may be configured to ban immediately
# when first badword is detected, or it may count badwords and if number of 
# badwords of given nick exceeds limit, ban him. Badword count may also be
# expired if no badword is seen for specified period of time. Optional 
# verbosity (let's call it logging) may be enabled as well
#
# Runtime variables:
#
# badword_channels = list of channels where script is active, separated by space
# badword_words = list of 'bad words' that trigger this, separated by space
# badword_reason = reason used in kick when count exceeds permitted limit
# badword_limit = if number of detected badwords reaches this number, ban'em. 
#                 Set 1 to immediately kickban.
# badword_clear_delay = if no badword is detected from user for time specified
#                       here (in seconds), clear his counter. Set 0 to disable.
# badword_verbose = turns on/off logging features
# badword_ban_delay = ban after number of kicks specified here. 0 - disables
#                     banning, 1 - ban immediately, ... 
###############################################################################
#
# Changelog:
#
# Jun 4 2002
#    - added ban delaying feature
#
###############################################################################
use Irssi;
use Irssi::Irc;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "0.0.3";

%IRSSI = (
    authors     =>  "Jan 'fissie' Sembera",
    contact     =>  "fis\@ji.cz",
    name        =>  "badword",
    description =>  "Configurable badword kickbanning script",
    license     =>  "GPL v2 and any later",
    url         =>  "http://fis.bofh.cz/devel/irssi/",
);

my %nick_dbase;

sub sig_public {
  my ($server, $msg, $nick, $address, $target) = @_;
  my $watch_channels = Irssi::settings_get_str('badword_channels');
  my $watch_words    = Irssi::settings_get_str('badword_words');

  my @chanz = split (/ /, $watch_channels); 
  my @wordz = split (/ /, $watch_words); 
  
  my $nickrec = $server->channel_find($target)->nick_find($nick);
  my $nickmode = $nickrec->{op} ? "@" : $nickrec->{voice} ? "+" : "";

  my $aux = 0;

  if (! ($nickmode eq "")) {
    return;
  }

  foreach my $ch (@chanz) {
    if ($ch eq $target) {
      $aux = 1;
    }
  }

  if ($aux == 0) { 
    return;
  } 

  $aux = 0; 
  foreach my $bw (@wordz) {
#   if (($msg =~ /\ $bw/) || ($msg =~ /^$bw/)) {
    if ($msg =~ /$bw/) {
      $aux = 1;
    } 
  }

  if ($aux == 0) {
    return;
  }

  # Ok, here comes badword, check record

  my $luser = $nick_dbase{$nick}{$target};
  
  if (!$luser) {
    $nick_dbase{$nick}{$target}{'count'} = 1;
    $nick_dbase{$nick}{$target}{'kcount'} = 0;
    $nick_dbase{$nick}{$target}{'stamp'} = time();
  } else {
    if ((Irssi::settings_get_int('badword_clear_delay') != 0) && (($nick_dbase{$nick}{$target}{'stamp'})+(Irssi::settings_get_int('badword_clear_delay'))) < time()) {
      $nick_dbase{$nick}{$target}{'count'} = 1;
      if (Irssi::settings_get_bool('badword_verbose') == 1) { Irssi::print('BW: Expired for '.$nick.' with hostmask '.$address.' on channel '.$target); }
    } else {
      $nick_dbase{$nick}{$target}{'count'} = ($nick_dbase{$nick}{$target}{'count'})+1; 
    }
    $nick_dbase{$nick}{$target}{'stamp'} = time();
  }

  $luser = $nick_dbase{$nick}{$target}{'count'};

  if (Irssi::settings_get_bool('badword_verbose') == 1) { Irssi::print('BW: Detected badword from nick '.$nick.' with hostmask '.$address.' on channel '.$target.' - '.$nick_dbase{$nick}{$target}{'count'}.' times'); }
 
  if ($luser == Irssi::settings_get_int('badword_limit')) {
    $nick_dbase{$nick}{$target}{'count'} = 0;
    # Ban'em!
    my @host = split(/\@/, $address);
    if (($host[0] =~ /\~/) || ($host[0] =~ /\-/) || ($host[0] =~ /\=/) || ($host[0] =~ /\^/)) { $host[0] = "*"; }
    my $mask = '*!'.$host[0].'@'.$host[1];
    $nick_dbase{$nick}{$target}{'kcount'} = ($nick_dbase{$nick}{$target}{'kcount'})+1; 
    if ((Irssi::settings_get_int('badword_ban_delay') > 0) && (Irssi::settings_get_int('badword_ban_delay') == $nick_dbase{$nick}{$target}{'kcount'})) {
      $server->command('mode '.$target.' +b '.$mask);
      $nick_dbase{$nick}{$target}{'kcount'} = 0;
      if (Irssi::settings_get_bool('badword_verbose') == 1) { Irssi::print('BW: Nick '.$nick.' with mask '.$mask.' punished for badwording on channel '.$target.' - banned'); } 
    } else {
      if (Irssi::settings_get_bool('badword_verbose') == 1) { Irssi::print('BW: Nick '.$nick.' with mask '.$mask.' punished for badwording on channel '.$target.' - kicked'); }
    }
    $server->command('quote kick '.$target.' '.$nick.' :'.Irssi::settings_get_str('badword_reason'));
  } 
}

sub sig_nick {
  my ($server, $newnick, $nick, $address) = @_;

  $newnick = substr ($newnick, 1) if ($newnick =~ /^:/);
  my $count = $nick_dbase{$nick}; 
  if ($count) {
    $nick_dbase{$nick} = undef;
    $nick_dbase{$newnick} = $count; 
    if (Irssi::settings_get_bool('badword_verbose') == 1) { Irssi::print('BW: Tranferred badwords from '.$nick.' to '.$newnick); }
  }
}

Irssi::settings_add_str("misc", "badword_channels", "");
Irssi::settings_add_str("misc", "badword_words", "");
Irssi::settings_add_str("misc", "badword_reason", "BW: badword limit exceeded"); 
Irssi::settings_add_int("misc", "badword_limit", 3);
Irssi::settings_add_int("misc", "badword_clear_delay", 3600);
Irssi::settings_add_int("misc", "badword_ban_delay", 1);
Irssi::settings_add_bool("misc", "badword_verbose", 0); 

Irssi::signal_add_last('message public', 'sig_public');
Irssi::signal_add_last('event nick', 'sig_nick');
