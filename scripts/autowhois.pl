# /WHOIS all the users who send you a private message.
use strict;
use Irssi;
use vars qw($VERSION %IRSSI); 
$VERSION = "1.2";
%IRSSI = (
    authors	=> "Timo \'cras\' Sirainen",
    contact	=> "tss\@iki.fi",
    name	=> "autowhois",
    description	=> "/WHOIS all the users who send you a private message.",
    license	=> "Public Domain",
    url		=> "http://irssi.org/",
    changed	=> "2014-10-17",
);

my ($lastfrom, $lastquery);

sub msg_private_first {
  my ($server, $msg, $nick, $address) = @_;

  $lastquery = $server->query_find($nick);
}

sub msg_private {
  my ($server, $msg, $nick, $address) = @_;

  return if $lastquery || $lastfrom eq $nick;

  $lastfrom = $nick;
  $server->command("whois $nick");
}

Irssi::signal_add_first('message private', 'msg_private_first');
Irssi::signal_add('message private', 'msg_private');
