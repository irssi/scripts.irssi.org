# include $whois_decip somewhere in your /FORMAT whois

use Irssi 20011207;
use strict;
use vars qw($VERSION %IRSSI); 

$VERSION = "1.2";

%IRSSI = (
    authors => "Espen Holm Nilsen",
    contact => "holm\@blackedge.org",
    name => "efnetorg",
    description => "Print the real IP address of efnet.org clients when they join/part channels, and whois.",
    license => "GPLv2 or later",
    url => "http://www.holmnilsen.com/"
);

my $whois_decip = "";

sub whois_signal {
  my ($server, $data, $nick, $host) = @_;
  my ($me, $nick, $user, $host) = split(" ", $data);
     if($host eq "chat.efnet.org") {
	$whois_decip = hex2dec($user);
	} else {
	$whois_decip = "";
	}
}

sub expando_decip {
  if($whois_decip ne "") {
  return "(" . $whois_decip . ")";
  } else {
  return $whois_decip;
  }
 }

sub hex2dec ($) {
  my ($hexip) = @_;
     my @iparr = split(//, $hexip);
     my $decip = hex($iparr[0] . $iparr[1]) . "." . hex($iparr[2] . $iparr[3]) . "." . hex($iparr[4] . $iparr[5]) . "." . hex($iparr[6] . $iparr[7]);
     return $decip;
}

sub client_part {
  my ($server, $channame, $nick, $host) = @_;
   $channame =~ s/^://;

   my $channel = $server->channel_find($channame);

   return unless ($host =~ /\@chat.efnet.org$/);
   my @hostz = split("\@", $host);

   my $ident = $hostz[0];
   my $decip = hex2dec($ident);
   $channel->printformat(MSGLEVEL_PARTS, 'part_efnetorg', $nick, $host, $decip, $channel->{name});
   Irssi::signal_stop();
   return 0;
}

sub client_join {
  my ($server, $channame, $nick, $host) = @_;
   $channame =~ s/^://;

   my $channel = $server->channel_find($channame);

   return unless ($host =~ /\@chat.efnet.org$/);
   my @hostz = split("\@", $host);

   my $ident = $hostz[0];
   my $decip = hex2dec($ident);
   $channel->printformat(MSGLEVEL_JOINS, 'join_efnetorg', $nick, $host, $decip, $channel->{name});
   Irssi::signal_stop();
   return 0;   

}

Irssi::theme_register([
'join_efnetorg', '{channick_hilight $0} {chanhost_hilight $1} ({hilight $2}) has joined {channel $3}',
'part_efnetorg', '{channick $0} {chanhost $1} ({hilight $2}) has left {channel $3}'
]);

Irssi::expando_create('whois_decip', \&expando_decip, { 'event 311' => 'None' } );
Irssi::signal_add_first('event 311', 'whois_signal');
Irssi::signal_add('message join', 'client_join');
Irssi::signal_add('message part', 'client_part');

