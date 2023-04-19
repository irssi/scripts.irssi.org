use strict;
use warnings;
use Irssi;
use feature qw(fc);

use vars qw($VERSION %IRSSI);
$VERSION = "0.2";
%IRSSI = (
  authors     => 'vague',
  contact     => 'vague!#irssi@libera.chat on irc',
  name        => 'separate_messages',
  description => 'Print a black line between messages from different users',
  license     => 'GPL2',
  url         => 'https://vague.se',
  changed     => "14 Apr 10:00:00 CEST 2023",
);

my $prev_sender = {};
sub separate_messages {
  my ($tag, $sender, $target, $mode) = @_;
  my $server = Irssi::server_find_tag($tag);
  my $windowname = $mode ? $target : $sender;

  if(exists $prev_sender->{$tag}{$windowname} && $sender ne $prev_sender->{$tag}{$windowname}) {
    $server->window_item_find($windowname)->print("") if Irssi::settings_get_bool('separate_user_messages');
  }
  $prev_sender->{$tag}{$windowname} = $sender;
}

sub sig_message {
  separate_messages(lc $_[0]->{tag}, lc $_[2], lc $_[4], 0);
}

sub sig_message_own {
  separate_messages(lc $_[0]->{tag}, lc $_[0]->{nick}, lc $_[2], 0);
}

sub sig_message_own_special {
  separate_messages(lc $_[0]->{tag}, lc $_[0]->{nick}, lc $_[2], 1);
}

Irssi::settings_add_bool('lookandfeel', 'separate_user_messages', 0);

Irssi::signal_add_first('message public', 'sig_message');
Irssi::signal_add_first('message private', 'sig_message');
Irssi::signal_add_first('message own_public', 'sig_message_own');
Irssi::signal_add_first('message own_private', 'sig_message_own_special');
