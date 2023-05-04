use strict;
use warnings;
use Irssi;
use IO::Socket;
use Data::Dumper;
no autovivification;
use feature qw(fc);

use vars qw($VERSION %IRSSI);
$VERSION = "0.5";
%IRSSI = (
  authors     => 'vague',
  contact     => 'vague!#irssi@freenode on irc',
  name        => 'identd',
  description => 'Identd script for irssi',
  license     => 'GPL2',
  url         => 'https://vague.se',
  changed     => "04 May 15:00:00 CEST 2023",
);

my $handle = undef;
my $connectrec;
my $ident_server;
my $started = 0;
my $verbose = 0;

sub VERBOSE { $verbose };

sub cmd_help {
  my ($args, $server, $witem) = @_;
  if($args =~ /^identd\b/i) {
    Irssi::print ( <<SCRIPTHELP_EOF
%_Description:%_

Handles identd responses during server connections.
Port 113 from the outside has to be portforwarded to identd_port for
the script to work. The port has to be above 1024 or irssi will complain.
Another option is to run irssi as root but that is strongly discouraged.

%_Available settings:%_

    identd_port         - the port the identd server is listening on
    identd_length       - maximum length of the username to return
    identd_resolve_mode - the available modes to use are:
                            * !random - username is a identd_length
                              long random string consisting of 0-9a-z
                            * !username - use the logged in user's name
                            * it's up to you, identd_length characters are
                              used
    identd_verbose      - print status messages when identd is listening
                          to connections
    identd_strict_conn  - verify an incoming connection is from a server we are
                          connecting to

SCRIPTHELP_EOF
                        ,MSGLEVEL_CLIENTCRAP);
    Irssi::signal_stop;
  }
}

sub start_ident_server {
  my $port = Irssi::settings_get_int('identd_port') // 8113;
  Irssi::print("Identd - starting...") if VERBOSE;
  $ident_server = IO::Socket::INET->new( Proto => 'tcp', LocalAddr => '0.0.0.0' , LocalPort => $port, Listen => SOMAXCONN, ReusePort => 1) or print "Can't bind to port $port, $@";
  if(!$ident_server) {
    Irssi::print("Identd - couldn't start server, $@", MSGLEVEL_CLIENTERROR) if VERBOSE;
    $started = 0;
    return;
  }

  Irssi::print(sprintf("Identd - waiting for connections on %s:%s...", $ident_server->sockhost, $ident_server->sockport)) if VERBOSE;
  $handle = Irssi::input_add($ident_server->fileno, INPUT_READ, 'handle_connection', $ident_server);
}

sub handle_connection {
  return unless $started;
  my $sock = $_[0]->accept;
  my $iaddr = inet_aton($sock->peerhost); # or whatever address
  my $peer  = gethostbyaddr($iaddr, AF_INET) // $sock->peerhost;
  Irssi::print(sprintf("Identd - handling connection from %s(%s)", $peer, $sock->peerhost)) if VERBOSE;
  my $strict = Irssi::settings_get_bool('identd_strict_conn');
  Irssi::print(($peer =~ /(\w+)\.\w+$/i)[0]) if VERBOSE;
  if($strict && (!exists $connectrec->{($peer =~ /(\w+)\.\w+$/i)[0]} && !exists $connectrec->{$peer})) {
    Irssi::print("Identd - $peer not found in access list");
    close $sock;
    return;
  }

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
  $incoming =~ s/\s*//g;
  $incoming .= ":USERID:UNIX:" . $username . "\n";
  print $sock $incoming;
  close $sock;
  chomp $incoming;
  Irssi::print("Identd - responded to $peer with '$incoming'") if VERBOSE;
}

sub sig_server_connecting {
  my ($server,$ip) = @_;

  Irssi::print("Identd - server connecting: " . $server->{address}) if VERBOSE;
  $connectrec->{$server->{tag}} = $ip;
  $connectrec->{$server->{address}} = $ip;
  start_ident_server unless $started++;
}


sub sig_event_connected {
  my ($server) = @_;

  Irssi::print("Identd - server done connecting: " . $server->{address}) if VERBOSE;
  print Dumper($connectrec) if VERBOSE;
#  print Dumper($server) if VERBOSE;

  delete $connectrec->{$server->{address}};
  delete $connectrec->{$server->{tag}};

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
Irssi::settings_add_bool('identd', 'identd_verbose', 0);
Irssi::settings_add_bool('identd', 'identd_strict_conn', 0);

Irssi::command_bind_first('help', 'cmd_help');

Irssi::signal_add_first('server looking', 'sig_server_connecting');
Irssi::signal_add_last('event connected', 'sig_event_connected');
Irssi::signal_add_last('server connect failed', 'sig_event_connected');
Irssi::signal_add('setup changed', 'sig_setup_changed');

sig_setup_changed();
