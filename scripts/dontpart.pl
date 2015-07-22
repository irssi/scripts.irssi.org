use Irssi;
use Irssi::Irc;
use strict;
use vars qw($VERSION %IRSSI %config);
$config{clientcount} = 0;


$VERSION = "0.5";
%IRSSI = (
    authors     => 'ray powell',
    contact => 'rpowell1@uchicago.edu',
    name        => 'filter part',
    description => 'Filter out part messages if connected to irssi proxy, prevents clients like adium from disconnecting your proxy.',
    license     => 'GPLv3',
);

sub event_part {
    if ( $config{clientcount} > 0 ){ 
        Irssi::signal_stop() ;
        Irssi::print('>Proxy Client sent part.');
    }
  }
sub client_connect {
   $config{clientcount}++;
   Irssi::print("Proxy Client Connected. Currently Connected: $config{clientcount}");
}
sub client_disconnect {
   $config{clientcount}-- unless $config{clientcount} == 0;
   Irssi::print("Proxy Client Disconnected. Currently Connected:  $config{clientcount}");
}

Irssi::signal_add("event part", "event_part");
Irssi::signal_add_last('proxy client connected', 'client_connect');
Irssi::signal_add_last('proxy client disconnected', 'client_disconnect');
