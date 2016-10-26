use strict;
use Irssi;
use Irssi::Irc;

use vars qw($VERSION %IRSSI);

$VERSION = "1.0.0";
%IRSSI   = (
	authors     => 'Roeland Nieuwenhuis',
	contact     => 'irc@trancer.nl',
	name        => 'netswitch',
	description => 'Set all windows not bound to a network to a specified network.',
	license     => 'BSD',
	url         => 'http://trancer.nl',
	changed     => 'Mon May 24 2010',
);

sub cmd_netswitch {
	my $netname = shift;
	my $destserv;

	if ($netname eq "") {
		$destserv = Irssi::active_server() if $netname eq "";
	} else {
		my $cn = Irssi::server_find_tag($netname);
		unless ($cn) {
			Irssi::active_win->print("Unknown network: $netname");
  	  return;
		} 
		$destserv = $cn;
	}

	for my $win (Irssi::windows()) {
		for my $witem($win->items or $win) {
			$witem->change_server($destserv) unless defined $witem->{'type'} && ($witem->{'type'} eq "CHANNEL" || $witem->{'type'} eq "QUERY");
		}
	}
	Irssi::active_win->print("All windows changed network to $destserv->{'tag'}");
}

Irssi::active_win->print("%GNetswitcher $VERSION loaded%n. Use /netswitch <netname> to switch all windows that are not CHANNEL or QUERY to <netname>. If you call /netswitch without arguments it will switch to the network of the active window.");

Irssi::command_bind("netswitch", "cmd_netswitch");
