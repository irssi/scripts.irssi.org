# Nickmix - Perturbates your nick to avoid being collided of be split-riders
#	    trying to guess your nick (this normally includes banning them
#	    and setting the channel +i)
#


use strict;

use vars qw ($VERSION %IRSSI);

$VERSION = 'v0.1';
%IRSSI = (
          name        => 'nickmix-c0ffee',
          authors     => 'c0ffee',
          contact     => 'c0ffee@penguin-breeder.org',
          url         => 'http://www.penguin-breeder.org/irssi/',
          license     => 'GPLv2, not later',
          description => 'Perturbates your nick, use /nickmix nick/len where len is the number of chars you want to keep from your orig nick. use /stopmix to stop. Always issue the commands in a window of the server you want to mix in.'
         );


use Irssi;


my %mix;
my %nick;
my %len;
my %servers;

my @valid_chars = (split //, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789[]{}`_-\\');

sub nickmix {
  my ($data, $mask, $cnt) = @_;

  $data =~ s/$mask/"$1" . join "", (map { $valid_chars[rand @valid_chars] } (1..$cnt))/e;
  return $data;

}

sub mixer {
  my $new_nick;
  
  $new_nick = nickmix($nick{$_},"(.\{$len{$_}\}).*",length($nick{$_}) - $len{$_}),
  $servers{$_}->command("NICK $new_nick") foreach (keys %mix);

}

sub cmd_nickmix {
  my ($data, $server, $channel) = @_;

  Irssi::print("Not connected to a server."), return if not $server;

  if ($data eq "") {
    Irssi::print "mixing $nick{$_} on $servers{$_}->{chatnet}" foreach (keys %mix);
    return;
  }

  Irssi::print("Invalid format: usage: /nickmix nick/keep (keep is an int)"),
    return if $data !~ /^\S+\/\d+$/;

  $mix{$server->{chatnet}} = $data;

  ($nick{$server->{chatnet}},$len{$server->{chatnet}}) = $data =~ /^(\S+)\/(\d+)$/;
  $servers{$server->{chatnet}} = $server;

  Irssi::print("Now mixing $nick{$server->{chatnet}} on $server->{chatnet}");

}

sub cmd_stopmix {

  my ($data, $server, $channel) = @_;

  Irssi::print("Not connected to a server."), return if not $server;


  Irssi::print("Invalid format: usage: /stopmix"),
    return if $data !~ /^\s*$/;

  Irssi::print("Stop mixing $nick{$server->{chatnet}} on $server->{chatnet}");
  delete $mix{$server->{chatnet}};
}

Irssi::command_bind("stopmix", "cmd_stopmix");
Irssi::command_bind("nickmix", "cmd_nickmix");

Irssi::print("Nickmix $VERSION loaded...");

Irssi::timeout_add(30000,'mixer',0);
