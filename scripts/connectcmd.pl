use strict;
use Irssi 20020101.0250 ();

use vars qw($VERSION %IRSSI);
$VERSION = "0.2";
%IRSSI = (
    authors     => "Ian Peters",
    contact     => "itp\@ximian.com",
    name        => "Connect Command",
    description => "run arbitrary shell commands while [dis]connecting to a server",
    license     => "Public Domain",
    url         => "http://irssi.org/",
    changed     => "2017-03-18"
);

my %preconn_actions;
my %postconn_actions;
my %disconn_actions;

sub load_actions {
  my $fi;

  open $fi, '<', "$ENV{HOME}/.irssi/connectcmd_actions";

  while (<$fi>) {
    my @lines = split "\n";
    foreach my $line (@lines) {
      my ($server, $type, $action) = split ":", $line;
      if ($type eq "preconn") {
	      $preconn_actions{$server} = $action;
      } elsif ($type eq "postconn") {
	      $postconn_actions{$server} = $action;
      } elsif ($type eq "disconn") {
	      $disconn_actions{$server} = $action;
      }
    }
  }

  close $fi;
}

sub save_actions {
  my $fa;
  open $fa, q{>}, "$ENV{HOME}/.irssi/connectcmd_actions";

  foreach my $server (keys %preconn_actions) {
    print $fa "$server:preconn:$preconn_actions{$server}\n";
  }
  foreach my $server (keys %postconn_actions) {
    print $fa "$server:postconn:$postconn_actions{$server}\n";
  }
  foreach my $server (keys %disconn_actions) {
    print $fa "$server:disconn:$disconn_actions{$server}\n";
  }

  close $fa;
}

sub sig_server_looking {
  my ($server) = @_;

  if (my $action = $preconn_actions{$server->{'address'}}) {
    system ($action);
  }
}

sub sig_server_connected {
  my ($server) = @_;

  if (my $action = $postconn_actions{$server->{'address'}}) {
    system ($action);
  }
}

sub sig_server_disconnected {
  my ($server) = @_;

  if (my $action = $disconn_actions{$server->{'address'}}) {
    system ($action);
  }
}

sub cmd_connectcmd {
  my ($data, $server, $witem) = @_;
  
  #my ($op, $type, $server, $action) = split " ", $data;
  $data =~ m/^(\S*)\s+(\S*)\s+(\S*)\s+(.*)$/;
  my $op=$1;
  my $type=$2;
  my $server=$3;
  my $action=$4;

  $op = lc $op;

  if (!$op) {
    Irssi::print ("No operation given");
  } elsif ($op eq "add") {
    if (!$type) {
      Irssi::print ("Type not specified [preconn|postconn|disconn]");
    } elsif (!$server) {
      Irssi::print ("Server not specified");
    } elsif (!$action) {
      Irssi::print ("Action not specified");
    } else {
      if ($type eq "preconn") {
	$preconn_actions{$server} = $action;
	Irssi::print ("Added preconnect action of $action on $server");
	save_actions;
      } elsif ($type eq "postconn") {
	$postconn_actions{$server} = $action;
	Irssi::print ("Added postconnect action of $action on $server");
	save_actions;
      } elsif ($type eq "disconn") {
	$disconn_actions{$server} = $action;
	Irssi::print ("Added disconnect action of $action on $server");
	save_actions;
      } else {
	Irssi::print ("Unrecognized trigger $type [preconn|postconn|disconn]");
      }
    }
  } elsif ($op eq "remove") {
    if (!$type) {
      Irssi::print ("Type not specified [preconn|postconn|disconn]");
    } elsif (!$server) {
      Irssi::print ("Server not specified");
    } else {
      if ($type eq "preconn") {
	delete ($preconn_actions{$server});
	Irssi::print ("Removed preconnect action on $server");
	save_actions;
      } elsif ($type eq "postconn") {
	delete ($postconn_actions{$server});
	Irssi::print ("Removed postconnect action on $server");
	save_actions;
      } elsif ($type eq "disconn") {
	delete ($disconn_actions{$server});
	Irssi::print ("Removed disconnect action on $server");
	save_actions;
      } else {
	Irssi::print ("Unrecognized trigger $type [preconn|postconn|disconn]");
      }
    }
  } elsif ($op eq "list") {
    Irssi::print ("Preconnect Actions:");
    foreach my $server (keys %preconn_actions) {
      Irssi::print ("$server  $preconn_actions{$server}");
    }
    Irssi::print ("Postconnect Actions:");
    foreach my $server (keys %postconn_actions) {
      Irssi::print ("$server  $postconn_actions{$server}");
    }
    Irssi::print ("Disconnect Actions:");
    foreach my $server (keys %disconn_actions) {
      Irssi::print ("$server  $disconn_actions{$server}");
    }
  }
}

load_actions();

Irssi::command_bind ('connectcmd', 'cmd_connectcmd');

Irssi::signal_add ('server looking', 'sig_server_looking');
Irssi::signal_add ('server connected', 'sig_server_connected');
Irssi::signal_add ('server disconnected', 'sig_server_disconnected');
