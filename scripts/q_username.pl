# Prints the Q username in right format

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
$VERSION = "0.1";
%IRSSI = (
    authors=> "Teemu \'jamov\' Koskinen",
    contact=> "teemu.koskinen\@mbnet.fi",
    name=> "q_username",
    description=> "Prints the Q username in right format",
    license=> "Public Domain",
);

Irssi::theme_register([whois_auth => ' authnick : $1']);

sub event_whois_auth {
	my ($server, $data) = @_;
	my ($num, $nick, $auth_nick) = split(/ +/, $_[1], 3);
        $auth_nick =~ s/\:is authed as //;

	$server->printformat($nick, MSGLEVEL_CRAP, 'whois_auth', $nick, $auth_nick);
	Irssi::signal_stop();
}

Irssi::signal_add('event 330', 'event_whois_auth');
