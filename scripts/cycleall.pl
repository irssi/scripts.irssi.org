use strict;
use vars qw($VERSION %IRSSI);

use Irssi qw( servers command_bind channels);

$VERSION = "0.1";
%IRSSI = (
   authors      => "Steve Clement",
   contact      => "steve\@localhost.lu",
   name         => "cycleall",
   description  => "Cycles ALL your channels on ALL your servers (excluding ^[+/!/&])",
   license      => "MIT",
   changed      => "Mon Jun 22 16:07:28 CEST 2015"
);

sub cycle_all_channels {
  my ($data, $server, $channel) = @_;
  foreach my $server (servers) {
    Irssi::print "%GEntered%c:%n check_channels";
    for (channels) {
      my $chatnet = $_->{server}->{chatnet} || $_->{server}->{tag};
        if ($_->{name} !~ m/^[\+\!\&]/ ) {
          Irssi::print "%GCycling channel%c:%n $_->{name}";
          $_->command("cycle");
        }
    }
  }
}

Irssi::print "%GLoading%c:%n reCycle";
Irssi::command_bind("cycleall", "cycle_all_channels");