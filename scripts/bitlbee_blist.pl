use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '0.4';
%IRSSI = (
    authors	=> 'Tijmen "timing" Ruizendaal',
    contact	=> 'tijmen.ruizendaal@gmail.com',
    name	=> 'bitlbee_blist',
    description	=> '/blist <all|online|offline|away> <word>,  greps <word> from blist for bitlbee',
    license	=> 'GPLv2',
    url		=> 'http://the-timing.nl/stuff/irssi-bitlbee',
    changed	=> '2006-10-27',
);

my $bitlbee_server_tag = "localhost";
my $bitlbee_channel = "&bitlbee";
my ($list, $word);

get_channel();

Irssi::signal_add_last 'channel sync' => sub {
        my( $channel ) = @_;
        if( $channel->{topic} eq "Welcome to the control channel. Type \x02help\x02 for help information." ){
                $bitlbee_server_tag = $channel->{server}->{tag};
                $bitlbee_channel = $channel->{name};
        }
};

sub get_channel {
	my @channels = Irssi::channels();
	foreach my $channel(@channels) {
		if ($channel->{topic} eq "Welcome to the control channel. Type \x02help\x02 for help information.") {
			$bitlbee_channel = $channel->{name};
			$bitlbee_server_tag = $channel->{server}->{tag};
			return 1;
		}
	}
	return 0;
}

sub blist {
  my ($args, $server, $winit) = @_;
  ($list, $word) = split(/ /, $args, 2);
  if (Irssi::active_win->{'active'}->{'name'} eq $bitlbee_channel) {
    Irssi::active_win()->command("msg $bitlbee_channel blist $list");
    Irssi::signal_add('event privmsg', 'grep');  
  } else {
    print "Only use in $bitlbee_channel.";
  }
}

sub grep {
  my ($server, $data, $nick, $address) = @_;
  my ($target, $text) = split(/ :/, $data, 2);
  if ($text =~ /$word/ && $target =~ /$bitlbee_channel/){
    ##do nothing
  } else {Irssi::signal_stop();}
  if ($text =~ /buddies/ && $target =~/$bitlbee_channel/){Irssi::signal_remove('event privmsg', 'grep');} 
}

Irssi::command_bind('blist','blist');
