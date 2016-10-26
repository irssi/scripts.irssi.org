#!/usr/bin/perl
use strict;
use Irssi;
use Net::DNS;
use vars qw($VERSION %IRSSI);

$VERSION = "0.0.1";
%IRSSI = (
    authors     => "Sebastian 'yath' Schmidt",
    contact     => "yath+irssiscripts\@yath.de",
    name        => "Tor autodetection for Irssi",
    description => "This script will automatically detect people using the ".
                   "Tor anonymity network and append \".TOR\" to their ".
                   "hostname, to make things like /ignore -time 3600 ".
                   "*!*\@*.TOR possible (e.g. when your favourite ".
                   "channel gets flooded).",
    license     => "Public domain"
);

use constant {
    HOSTSUFFIX => ".TOR",
    DNSBL      => "tor-irc.dnsbl.oftc.net",
    CACHETIME  => 3600,
};

my %cache;

sub resolve_host($) {
    my $hostname = shift;
    return $hostname if "$hostname." =~ (/^(\d{1,3}\.){4}$/); # yes, that sucks

    my $res = Net::DNS::Resolver->new();
    my $q = $res->search($hostname, "A");
    return unless $q;
    return map { $_->address } grep { $_->type eq "A" } $q->answer;
}

sub reverse_addr($) {
    return join(".", reverse(split(/\./, $_[0])));
}

sub istor($) {
    my $hostname = shift;
    if (exists($cache{$hostname})) {
        if (time >= $cache{$hostname}->[0]) {
            delete $cache{$hostname};
        } else {
            return $cache{$hostname}->[1];
        }
    }

    my $result = 0;

    foreach my $addr (resolve_host($hostname)) {
        if (grep /^127\.0\.0\.1$/,
                resolve_host(reverse_addr($addr).".".DNSBL)) {
            $result = 1;
            last;
        }
    }

    $cache{$hostname} = [time+CACHETIME, $result];
    return $result;
}

sub handler_server_event {
    my ($server, $data, $sender_nick, $sender_addr) = @_;
    return unless ($sender_nick ne "" and $sender_addr =~ /.+@(.+)/);
    $sender_addr .= HOSTSUFFIX if istor($1);
    Irssi::signal_continue($server, $data, $sender_nick, $sender_addr);
}

Irssi::signal_add("server event", \&handler_server_event);
