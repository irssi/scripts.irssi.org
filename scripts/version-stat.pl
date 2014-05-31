#!/usr/bin/perl -w
# shows top[0-9]+ irc client versions in a channel
#  by c0ffee 
#    - http://www.penguin-breeder.org/?page=irssi

#<scriptinfo>
use vars qw($VERSION %IRSSI);

use Irssi 20020120;
$VERSION = "0.1";
%IRSSI = (
    authors	=> "c0ffee",
    contact	=> "c0ffee\@penguin-breeder.org",
    name	=> "version-stats",
    description	=> "shows top[0-9]+ irc client versions in a channel",
    license	=> "Public Domain",
    url		=> "http://www.penguin-breeder.org/?page=irssi",
    changed	=> "Sun Apr 14 17:30 GMT 2002",
);
#</scriptinfo>

my %versions;
my $tag;
my $running = 0;

sub version_reply {
  my ($server, $data, $nick, $addr, $target) = @_;

  $versions{$data} = 1 + $versions{$data} if $running;

  if (not Irssi::settings_get_bool('mute_version_reply') or not $running) {
 

     Irssi::signal_emit("default ctcp reply", $server, "VERSION $data", $nick, $addr, $target);

  }
 

}

sub show_stats {

  my ($data) = @_;
  my @stats = map "$versions{$_},$_", sort { $versions{$b} <=> $versions{$a} } keys %versions;
  my ($top,$best,$cnt,$v,$foo,$bar);
  $running = 0;

  ($top,$best) = $data =~ /(.*)\/(.*)/;

  Irssi::print("VERSION stats:");
 
  Irssi::timeout_remove($tag);

  foreach (1..$top) {
    last if not defined $stats[$_ - 1];
    ($cnt,$v) = $stats[$_ - 1] =~ /(.*?),(.*)/;
    $bar = $cnt * 20 / $best;
    $foo = "|" x $bar . "." x (20 - $bar),
    Irssi::print("$_. [$foo]: ($cnt) $v");
  }
  
}

sub cmd_vstat {
  my ($data, $server, $channel) = @_;
  my ($period, $top,@nicks,$num);

  Irssi::print("usage: /vstat period-in-secs top-n"), return
    if not (($period, $top) = $data =~ /(\d+)\s+(\d+)/);

  @nicks = $channel->nicks();

  $num = @nicks;

  $tag = Irssi::timeout_add($period * 1000, 'show_stats', "$top/$num");

  undef %versions;
  $running = 1;

  $server->send_raw("PRIVMSG $channel->{name} :\001VERSION\001");
  Irssi::print("Starting version collection in $channel->{name}");

}

Irssi::signal_add_last('ctcp reply version', 'version_reply');
Irssi::command_bind('vstat', 'cmd_vstat');
Irssi::settings_add_bool('misc', 'mute_version_reply', 1);
