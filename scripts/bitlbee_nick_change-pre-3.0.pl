use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '1.2';
%IRSSI = (
    authors	=> 'Tijmen "timing" Ruizendaal',
    contact	=> 'tijmen.ruizendaal@gmail.com',
    name	=> 'bitlbee_nick_change-pre-3.0',
    description	=> 'Shows an IM nickchange in an Irssi way. (in a query and in the bitlbee channel). (For bitlbee 1.2.x)',
    license	=> 'GPLv2',
    url		=> 'http://the-timing.nl/stuff/irssi-bitlbee',
    changed	=> '2006-10-27',
);

my $bitlbee_channel = "&bitlbee";
my $bitlbee_server_tag = "localhost";

Irssi::signal_add_last 'channel sync' => sub {
        my( $channel ) = @_;
        if( $channel->{topic} eq "Welcome to the control channel. Type \x02help\x02 for help information." ){
                $bitlbee_server_tag = $channel->{server}->{tag};
                $bitlbee_channel = $channel->{name};
        }
};

get_channel();

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

sub message {
  my ($server, $msg, $nick, $address, $target) = @_;
  if($server->{tag} eq $bitlbee_server_tag) {
    if($msg =~ /User.*changed name to/) {
      $nick = $msg;
      $nick =~ s/.* - User `(.*)' changed name to.*/$1/;
      my $window = $server->window_find_item($nick);  
      
      if ($window) {
        $window->printformat(MSGLEVEL_CRAP, 'nick_change',$msg);
        Irssi::signal_stop();
      } else {
        my $window = $server->window_find_item($bitlbee_channel);
        $window->printformat(MSGLEVEL_CRAP, 'nick_change',$msg);
        Irssi::signal_stop();
      }
    }
  }    
}

Irssi::signal_add_last ('message public', 'message');

Irssi::theme_register([
  'nick_change', '$0'
 ]);
