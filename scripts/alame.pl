use Irssi;
use Irssi::Irc;
use strict;
use warnings;
use vars qw($VERSION %IRSSI);
$VERSION="0.0.1";
%IRSSI = (
	authors	=> 'Christian \'mordeth\' Weber',
	contact	=> 'mordeth\@mac.com',
	name	=> 'alame',
	description	=> 'Converts towards lame speech',
	license	=> 'GPL v2',
	url	=> 'http://',
);


# USAGE:
# /alame <text>
# writes "text" in lamespeech to the current channel

sub cmd_lamer {
  my ($data, $server, $witem) = @_;
  if (!$server || !$server->{connected}) {
    Irssi::print("Not connected to server");
    return;
  }
  if ($data) {
    my $x; $_=$data; s/./$x=rand(6); $x>3?lc($&):uc($&)/eg; s/a/4/gi; s/c/(/gi;
    s/d/|)/gi; s/e/3/gi; s/f/|=/gi; s/h/|-|/gi; s/i/1/gi; s/k/|</gi;
    s/l/|_/gi; s!m!/\\/\\!gi; s!n!/\\/!gi; s/o/0/gi; s/s/Z/gi; s/t/7/gi;
    s/u/|_|/gi; s!v!\\/!gi; s!w!\\/\\/!gi; #s/w/\/\//gi;
    $witem->command("/SAY $_");
  }
}

Irssi::command_bind('alamer', 'cmd_lamer');
