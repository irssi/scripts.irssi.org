#!/usr/bin/perl
# Support extended-joins
# (C) 2012 Mike Quin <mike@elite.uk.com>
# Licensed under the GNU General Public License Version 2 ( https://www.gnu.org/licenses/gpl-2.0.html )


use Irssi;
use strict;
use Data::Dumper;
use vars qw($VERSION %IRSSI); 
$VERSION = "0.8.15";
%IRSSI = (
    authors	=> "Mike Quin",
    contact	=> "mike at elite.uk.com",
    name	=> "cap-extjoin",
    description	=> "Print accountname and realname information on joins where extended-join is available",
    license	=> "GPLv2",
    url		=> "http://www.elite.uk.com/mike/irc/",
    changed	=> "Fri Feb  4 10:35:32 UTC 2011"
);

Irssi::theme_register([
  'join', '{channick_hilight $0} {chanhost_hilight $1} has joined {channel $2}',
  'join_realname', '{channick_hilight $0} ({hilight $1}) {chanhost_hilight $2} has joined {channel $3}',
  'join_account_realname', '{channick_hilight $0 [$1]} ({hilight $2}) {chanhost_hilight $3} has joined {channel $4}',
]);

my %servers;

sub event_join {
  my ($server, $data, $nick, $host) = @_;

  return unless ($servers{$server->{tag}}->{'EXTENDED-JOIN'} == 1);
  Irssi::signal_stop();

  my ($channel, $account, $realname);
  if ($data=~/(\S+) (\S+) :(.*)/) {
    $channel=$1;
    $account=$2;
    $realname=$3;
  } elsif ($data=~/:(\S+)/) {
    # We will still see regular JOINS when users' hostnames change, so we handle them as well
    $channel=$1;
  } 

  my $chanrec = $server->channel_find($channel);
  if ($chanrec && $realname && $account && $account ne '*') {
       $chanrec->printformat(MSGLEVEL_JOINS, 'join_account_realname', $nick, $account, $realname, $host, $channel);
  } elsif ($chanrec && $realname) {
       $chanrec->printformat(MSGLEVEL_JOINS, 'join_realname', $nick, $realname, $host, $channel);
  } elsif ($chanrec) {
       $chanrec->printformat(MSGLEVEL_JOINS, 'join', $nick, $host, $channel);
  }
}

sub extjoin_cap_reply {
        my ($server, $data, $server_name) = @_;
        if ($data =~ /ACK :.*extended-join/) {
                $servers{$server->{tag}}->{'EXTENDED-JOIN'} = 1;
        }
}

sub extjoin_connected {
        my $server = shift;
        $servers{$server->{tag}}->{'EXTENDED-JOIN'} = 0;
        $server->command("^quote cap req :extended-join");
}

sub extjoin_disconnected {
  my $server = shift;
  delete $servers{$server->{tag}};
}

Irssi::signal_add ( {
	'event join' => \&event_join, 
        'event cap', 'extjoin_cap_reply',
        'event connected', 'extjoin_connected',
	'server disconnected' => \&extjoin_disconnected } );

# On load enumerate the servers and try to turn on extended-join
foreach my $server (Irssi::servers()) {
        %servers = ();
        extjoin_connected($server);
}


