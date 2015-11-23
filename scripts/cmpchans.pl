use strict;
use warnings;

our $VERSION = "0.5";
our %IRSSI = (
    authors     => 'Jari Matilainen, init[1]@irc.freenode.net',
    contact     => 'vague@vague.se',
    name        => 'cmpchans',
    description => 'Compare nicks in two channels',
    license     => 'Public Domain',
    url         => 'http://vague.se'
);

use Irssi::TextUI;
use Data::Dumper;

sub cmd_cmp {
  local $/ = " ";
  my ($args, $server, $witem) = @_;
  my (@channels) = split /\s+/, $args;

  my $server1 = $server;
  if ($channels[0] =~ s,(.*?)/,,)  {
      $server1 = Irssi::server_find_tag($1) || $server;
  }
  my $chan1 = $server1->channel_find($channels[0]);
  if(!$chan1) {
    Irssi::active_win()->{active}->print("You have to specify atleast one channel to compare nicks to");
    return;
  }

  my @nicks_1;
  my @nicks_2;

  @nicks_1 = $chan1->nicks() if(defined $chan1);

  if(not defined $channels[1]) {
    @nicks_2 = $witem->nicks();
  }
  else {
      if ($channels[1] =~ s,(.*?)/,,)  {
	  $server1 = Irssi::server_find_tag($1) || $server;
      }
    my ($chan2) = $server1->channel_find($channels[1]);
    @nicks_2 = $chan2->nicks() if(defined $chan2);
  }

  return if(scalar @nicks_1 == 0 || scalar @nicks_2 == 0);

  my %count = ();
  my @intersection;

  foreach (@nicks_1, @nicks_2) { $count{$_->{nick}}++; }
  foreach my $key (keys %count) {
    if($count{$key} > 1) {
      push @{\@intersection}, $key;
    }
  }

  my $common = join(", ", @intersection);
  $witem->print("Common nicks: " . $common);
}

Irssi::command_bind("cmp", \&cmd_cmp);
