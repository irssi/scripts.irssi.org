# identd_resolve_mode has three possible modes for identd generation:
# 1. !random
#    a random string will be created containing [a-z0-9]
# 2. !username
#    $ENV{USER} will be used
# 3. freeform
#    any other text will be used as is
# 
# The identd will be truncated to identd_length characters before the response is sent
#
# For the script to work, the defined port, identd_port, has to be accessible from the
# internet. Make sure it is portforwarded in the router or firewall, or otherwise
# visible to the irc servers you are connecting to.
#
# Beware that on *nix a non-privileged user can't bind to ports below 1024.

use strict;
use warnings;
use Irssi;
use IO::Socket;
use Data::Dumper;
no autovivification;
use feature qw(fc);

use vars qw($VERSION %IRSSI);
$VERSION = "0.2";
%IRSSI = (
  authors     => 'vague',
  contact     => 'vague!#irssi@freenode on irc',
  name        => 'identd',
  description => 'Identd script for irssi',
  license     => 'GPL2',
  url         => 'https://vague.se',
  changed     => "25 Jul 20:00:00 CEST 2017",
);

my $handle = undef;
my $connectrec;
my $ident_server;
my $started = 0;
my $verbose = 0;

sub VERBOSE { $verbose };

sub start_ident_server {
  my $port = Irssi::settings_get_int('identd_port') // 8113;
  Irssi::print("Identd - starting...") if VERBOSE;
  $ident_server = IO::Socket::INET->new( Proto => 'tcp', LocalAddr => '0.0.0.0' , LocalPort => $port, Listen => SOMAXCONN, ReusePort => 1) or print "Cam't bind to port $port, $@";
  if(!$ident_server) {
    Irssi::print("Identd - couldn't start server, $@", MSGLEVEL_CLIENTERROR) if VERBOSE;
    $started = 0;
    return;
  }

  Irssi::print(sprintf("Identd - waiting for connections on %s:%s...", $ident_server->sockhost, $ident_server->sockport)) if VERBOSE;
  $handle = Irssi::input_add($ident_server->fileno, INPUT_READ, 'handle_connection', $ident_server);
}

sub handle_connection {
  my $sock = $_[0]->accept;
  my $iaddr = inet_aton($sock->peerhost); # or whatever address
  my $peer  = gethostbyaddr($iaddr, AF_INET);
  Irssi::print("Identd - handling connection from $peer") if VERBOSE;
  return unless exists $connectrec->{$peer};

  my $username;
  my $username_mode = fc(Irssi::settings_get_str('identd_resolve_mode'));
  my $wl = Irssi::settings_get_int('identd_length') // 10;
  if($username_mode eq '!random') {
    my @chars = ('a'..'z',0..9);
    for(1 .. $wl) {
      $username .= $chars[int(rand(@chars))];
    }
  }
  elsif($username_mode eq '!username') {
    $username = substr +($ENV{USER} // 'unknown'), 0, $wl;
  }
  else {
    $username = substr $username_mode, 0, $wl;
  }

  $sock->autoflush(1);
  my $incoming = <$sock>;
  $incoming =~ s/\r\n//;
  $incoming .= " : USERID : OTHER : " . $username . "\n";
  print $sock $incoming;
  close $sock;
  chomp $incoming;
  Irssi::print("Identd - responded to $peer with '$incoming'") if VERBOSE;
}

sub sig_server_connecting {
  my ($server,$ip) = @_;

  Irssi::print("Identd - server connecting: " . $server->{address}) if VERBOSE;
  $connectrec->{$server->{address}} = $server;
  start_ident_server unless $started++;
}


sub sig_event_connected {
  my ($server) = @_;

  Irssi::print("Identd - server done connecting: " . $server->{address}) if VERBOSE;
  delete $connectrec->{$server->{address}};

  if(!keys %$connectrec) {
    Irssi::print("Identd - shutting down...") if VERBOSE;
    Irssi::input_remove($handle) if $handle;
    $ident_server->close if $ident_server;
    $started = 0;
  }
}

sub sig_setup_changed {
  $verbose = Irssi::settings_get_bool('identd_verbose');
}

Irssi::settings_add_str('identd', 'identd_resolve_mode', '!username');
Irssi::settings_add_int('identd', 'identd_port', 8113);
Irssi::settings_add_int('identd', 'identd_length', 10);
Irssi::settings_add_bool('identd', 'identd_verbose', 'FALSE');

Irssi::signal_add_first('server looking', 'sig_server_connecting');
Irssi::signal_add_last('event connected', 'sig_event_connected');
Irssi::signal_add_last('server connect failed', 'sig_event_connected');
Irssi::signal_add('setup changed', 'sig_setup_changed');

sig_setup_changed();
