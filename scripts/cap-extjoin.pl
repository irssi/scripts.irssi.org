# Support extended-joins in Irssi
# (c) 2012 Mike Quin <mike@elite.uk.com>
#
# Licensed under GNU General Public License version 2
#   <https://www.gnu.org/licenses/gpl-2.0.html>

use strict;
use warnings;
use Irssi;

our $VERSION = '0.9.0';
our %IRSSI = (
    authors	=> 'Mike Quin, Krytarik Raido',
    contact	=> 'mike@elite.uk.com, krytarik@tuxgarage.com',
    url		=> 'http://www.elite.uk.com/mike/irc/',
    name	=> 'cap-extjoin',
    description	=> 'Print account and realname information on joins where extended-join is available',
    license	=> 'GPLv2',
    changed	=> 'Sun Nov  6 12:34:04 CET 2016'
);

Irssi::theme_register([
  'join_extended' => '{channick_hilight $0} ({hilight $1}) {chanhost_hilight $2} has joined {channel $3}',
  'join_extended_account' => '{channick_hilight $0 [$1]} ({hilight $2}) {chanhost_hilight $3} has joined {channel $4}'
]);

my %servers;

sub event_join {
  my ($server, $data, $nick, $host) = @_;

  unless ($servers{$server->{tag}}->{'EXTENDED-JOIN'}
      and ! $server->netsplit_find($nick, $host)) {
    return;
  }

  Irssi::signal_stop();

  $data =~ /^(\S+) (\S+) :(.+)$/;
  my ($channel, $account, $realname) = ($1, $2, $3);

  if ($server->ignore_check($nick, $host, $channel, '', MSGLEVEL_JOINS)) {
    return;
  }

  my $chanrec = $server->channel_find($channel);
  if ($account ne '*') {
    $chanrec->printformat(MSGLEVEL_JOINS, 'join_extended_account', $nick, $account, $realname, $host, $channel);
  } else {
    $chanrec->printformat(MSGLEVEL_JOINS, 'join_extended', $nick, $realname, $host, $channel);
  }
}

sub extjoin_cap_reply {
  my ($server, $data) = @_;
  if ($data =~ /^\S+ ACK :extended-join\s*$/) {
    $servers{$server->{tag}}->{'EXTENDED-JOIN'} = 1;
  }
  elsif ($data =~ /^\S+ NAK :extended-join\s*$/) {
    $servers{$server->{tag}}->{'EXTENDED-JOIN'} = 0;
    Irssi::signal_stop();
  }
}

sub extjoin_connected {
  my ($server) = @_;
  $servers{$server->{tag}}->{'EXTENDED-JOIN'} = 0;
  $server->command("quote cap req :extended-join");
}

sub extjoin_disconnected {
  my ($server) = @_;
  delete $servers{$server->{tag}};
}

Irssi::signal_add_first('event cap', 'extjoin_cap_reply');

Irssi::signal_add({
  'event join' => 'event_join',
  'event connected' => 'extjoin_connected',
  'server disconnected' => 'extjoin_disconnected'
});

# On load enumerate the servers and try to turn on extended-join
foreach my $server (Irssi::servers()) {
  extjoin_connected($server);
}
