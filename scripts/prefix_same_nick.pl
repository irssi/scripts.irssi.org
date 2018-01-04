#
# 2018-01-03 bcattaneo:
#  - initial release
#

use Irssi;
use Irssi::Irc;
use strict;
use vars qw($VERSION %IRSSI);

#
# Usage:
# Load this script, and you'll notice
# all successive messages now appear
# "grouped" for each nickname.
#
# Settings:
# /set prefix_same_nick [Grouping prefix (e.g.: ">", "-" or just empty)]
#
# Script made originally to solve this issue (enhancement):
# https://github.com/irssi/irssi/issues/800
# But I thought it is a great idea! Thanks eti0
#

# Please notice this script breaks "nickcolor.pl".
# If you need nickcolor, please check "nickcolor_with_prefix.pl"

our $VERSION = '1.0.0';
our %IRSSI = (
  authors     => 'bcattaneo',
  contact     => 'c@ttaneo.uy',
  name        => 'prefix_same_nick',
  url         => 'http://github.com/bcattaneo',
  description => 'group successive messages',
  license     => 'Public Domain',
  #changed     => "2018-01-03",
);

Irssi::settings_add_str('misc', 'prefix_same_nick' => '-');
my %saved_nicks; # To store each channel's last nickname

sub prefix_them {
  my ($server, $msg, $nick, $address, $target) = @_;
  my $prefix = Irssi::settings_get_str('prefix_same_nick');

  # We check if it's the same nickname for current target
  if ($saved_nicks{$target} eq $nick)
  {
    # Grouped message
    $server->command('/^format pubmsg ' . $prefix . ' $1');
  }
  else
  {
    # Normal message
    $server->command('/^format pubmsg {pubmsgnick $2 {pubnick $0}}$1');
    $saved_nicks{$target} = $nick;
  }

}

sub prefix_me {
  my ($server, $msg, $target) = @_;
  my $nick = $server->{nick};
  my $prefix = Irssi::settings_get_str('prefix_same_nick');

  # We check if it's the same nickname for current target
  if ($saved_nicks{$target} eq $nick)
  {
    # Grouped message
    $server->command('/^format own_msg ' . $prefix . ' $1');
  }
  else
  {
    # Normal message
    $server->command('/^format own_msg {ownmsgnick $2 {ownnick $0}}$1');
    $saved_nicks{$target} = $nick;
  }

}

Irssi::signal_add('message public', 'prefix_them');
Irssi::signal_add('message own_public', 'prefix_me');
