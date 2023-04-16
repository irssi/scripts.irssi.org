use strict;
use warnings;
use Irssi;
use feature qw(fc);

use vars qw($VERSION %IRSSI);
$VERSION = "0.1";
%IRSSI = (
  authors     => 'vague',
  contact     => 'vague!#irssi@freenode on irc',
  name        => 'separate_messages',
  description => 'Print a black line between messages from different users',
  license     => 'GPL2',
  url         => 'https://vague.se',
  changed     => "14 Apr 10:00:00 CEST 2023",
);

my $prev_sender = {};
sub sig_message_public {
  my ($tag, $sender, $target) = (lc $_[0]->{tag}, lc $_[2], lc $_[4]);
  if(exists $prev_sender->{$tag}{$target} && $sender ne $prev_sender->{$tag}{$target}) {
    $_[0]->window_item_find($target)->window->print("") if Irssi::settings_get_bool('separate_user_messages');
  }
  $prev_sender->{$tag}{$target} = $sender;
}

Irssi::settings_add_bool('lookandfeel', 'separate_user_messages', 0);

Irssi::signal_add_first('message public', 'sig_message_public');
