# See this script's repository at
# http://github.com/avar/irssi-bitlbee-facebook-rename for further
# information.

use strict;
use warnings;
use Irssi;
use Irssi::Irc;

our $VERSION = '0.01';
our %IRSSI = (
    authors => "Enno Boland",
    contact => 'g@s01.de',
    name => 'studivz-bitlbee-rename',
    description => 'Rename XMPP *vz.net network contacts in bitlbee to human-readable names based on http://github.com/avar/irssi-bitlbee-facebook-rename',
    license => 'GPL',
);

my $bitlbeeChannel = "&bitlbee";
my $vzhost = "vz.net";
my %nicksToRename = ();

sub message_join
{
  # "message join", SERVER_REC, char *channel, char *nick, char *address
  my ($server, $channel, $nick, $address) = @_;
  my ($username, $host) = split /@/, $address;

  if ($host eq $vzhost and $channel =~ m/$bitlbeeChannel/ and $nick =~ m/$username/)
  {
    $nicksToRename{$nick} = $channel;
    $server->command("whois -- $nick");
  }
}

sub whois_data
{
  my ($server, $data) = @_;
  my ($me, $nick, $user, $host) = split(" ", $data);

  if (exists($nicksToRename{$nick}))
  {
    my $channel = $nicksToRename{$nick};
    delete($nicksToRename{$nick});

    my $ircname = substr($data, index($data,':')+1);

    $ircname = munge_nickname( $ircname );

    if ($ircname ne $nick)
    {
      $server->command("msg $channel rename $nick $ircname");
      $server->command("msg $channel save");
    }
  }
}

sub munge_nickname
{
  my ($nick) = @_;

  $nick =~ s/ä/ae/g;
  $nick =~ s/ü/ue/g;
  $nick =~ s/ö/oe/g;
  $nick =~ s/ß/ss/g;
  $nick =~ s/[^A-Za-z0-9-]/_/g;
  $nick = "svz_" . $nick;
  $nick = substr $nick, 0, 24;

  return $nick;
}

Irssi::signal_add_first 'message join' => 'message_join';
Irssi::signal_add_first 'event 311' => 'whois_data';
