use Irssi 20010920.0000 ();
$VERSION = "2.01";
%IRSSI = (
    authors     => 'From irssi source, modified by David Leadbeater (dg)',
    name        => 'clones',
    description => '/CLONES - Display clones in the active channel (with added options)',
    license     => 'Same as Irssi',
    url         => 'http://irssi.dgl.yi.org/',
);

use strict;

sub cmd_clones {
  my ($data, $server, $channel) = @_;

  my $min = $data =~ /\d/ ? $data : Irssi::settings_get_int('clones_min_show');

  if (!$channel || $channel->{type} ne 'CHANNEL') {
    Irssi::print('No active channel in window');
    return;
  }

  my %hostnames = {};
  my $ident = Irssi::settings_get_bool('clones_host_only');
  
  foreach my $nick ($channel->nicks()) {
	my $hostname;
	if($ident) {
	   ($hostname = $nick->{host}) =~ s/^[^@]+@//;
	}else{
	   $hostname = $nick->{host};
	}

	$hostnames{$hostname} ||= [];
	push( @{ $hostnames{$hostname} }, $nick->{nick});
  }

  my $count = 0;
  foreach my $host (keys %hostnames) {
	next unless ref($hostnames{$host}) eq 'ARRAY'; # sometimes a hash is here
    my @clones = @{ $hostnames{$host} };
    if (scalar @clones >= $min) {
      $channel->print('Clones:') if ($count == 0);
      $channel->print("$host: " . join(' ',@clones));
      $count++;
    }
  }

  $channel->print('No clones in channel') if ($count == 0);
}

Irssi::command_bind('clones', 'cmd_clones');
Irssi::settings_add_bool('misc', 'clones_host_only', 1);
Irssi::settings_add_int('misc', 'clones_min_show', 2);

