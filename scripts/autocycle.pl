# Usage: /SET auto_regain_ops [On/Off]
#        /autocycle

use strict;
use vars qw($VERSION %IRSSI);

use Irssi 20020313 qw( settings_add_bool settings_get_bool servers command_bind timeout_add );
$VERSION = "0.4";
%IRSSI = (
   authors      => "Marcin Rozycki",
   contact      => "derwan\@irssi.pl",
   name         => "autocycle",
   description  => "Auto regain ops in empty opless channels",
   url          => "http://derwan.irssi.pl",
   license      => "GNU GPL v2",
   changed      => "Fri Jan  3 23:20:06 CET 2003"
);

sub check_channels {
   foreach my $server (servers) {
      if ($server->{usermode} !~ m/r/ and my @channels = $server->channels) {
         CHANNEL: while (my $channel = shift @channels) {
            my $modes = $channel->{mode};
            my $test = ($modes and $modes =~ m/a/) ? 1 : 0;
            if (!$test && $channel->{synced} && $channel->{name} !~ m/^[\+\!]/ && !$channel->{ownnick}->{op}) {
               foreach my $nick ($channel->nicks) {
                  ($nick->{nick} eq $server->{nick}) or goto CHANNEL;
               }
               $channel->print("Auto regain op in empty channel " . $channel->{name});
               $channel->command("cycle");
            }
         }
      }
   }
}

sub autocycle {
   if (settings_get_bool("auto_regain_ops")) {
      check_channels();
   }
}

settings_add_bool "misc", "auto_regain_ops", 1;
command_bind "autocycle", "check_channels";
timeout_add 60000, \&autocycle, undef;
autocycle;

