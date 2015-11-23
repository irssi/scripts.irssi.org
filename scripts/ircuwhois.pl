use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = '1.2';

%IRSSI = (
	authors		=> 'Valentin Batz',
	contact		=> 'vb\@g-23.org',
	name		=> 'ircuwhois',
	description	=> 'show the accountname (330) and real host on ircu',
	license		=> 'GPLv2',
	url		=> 'http://www.hurzelgnom.homepage.t-online.de/irssi/scripts/quakenet.pl'
);

# adapted by Nei

Irssi::theme_register([
	'whois_auth',	'{whois account %|$1}',
	'whois_ip',	'{whois actualip %|$1}',
	'whois_host',	'{whois act.host %|$1}',
	'whois_oper',	'{whois privile. %|$1}',
	'whois_ssl',	'{whois connect. %|$1}'
]);

sub event_whois_default_event {
	#'server event', SERVER_REC, char *data, char *sender_nick, char *sender_address
	my ($server, $data, $snick, $sender) = @_;
	my $numeric = $server->parse_special('$H');
	if ($numeric eq '313') { &event_whois_oper }
	if ($numeric eq '330') { &event_whois_auth }
	if ($numeric eq '337') { &event_whois_ssl }
	if ($numeric eq '338') { &event_whois_userip }
}

sub event_whois_oper {
	my ($server, $data) = @_;
	my ($num, $nick, $privileges) = split(/ /, $data, 3);
	$privileges =~ s/^:(?:is an? )?//;
	$server->printformat($nick, MSGLEVEL_CRAP, 'whois_oper', $nick, $privileges);
	Irssi::signal_stop();
}

sub event_whois_auth {
	my ($server, $data) = @_;
	my ($num, $nick, $auth_nick, $isircu) = split(/ /, $data, 4);
	return unless $isircu =~ / as/; #:is logged in as
	$server->printformat($nick, MSGLEVEL_CRAP, 'whois_auth', $nick, $auth_nick);
	Irssi::signal_stop();
}

sub event_whois_ssl {
	my ($server, $data) = @_;
	my ($num, $nick, $connection) = split(/ /, $data, 3);
	$connection =~ s/^:(?:is using an? )?//;
	$server->printformat($nick, MSGLEVEL_CRAP, 'whois_ssl', $nick, $connection);
	Irssi::signal_stop();
}

sub event_whois_userip {
	my ($server, $data) = @_;
	my ($num, $nick, $userhost, $ip, $isircu) = split(/ /, $data, 5);
	return unless $isircu =~ /ctual /; #:Actual user@host, Actual IP
	$server->printformat($nick, MSGLEVEL_CRAP, 'whois_ip', $nick, $ip);
	$server->printformat($nick, MSGLEVEL_CRAP, 'whois_host', $nick, $userhost);
	Irssi::signal_stop();
}

sub debug {
	use Data::Dumper;
	Irssi::print(Dumper(\@_));
}
Irssi::signal_register({
	'whois oper' => [ 'iobject', 'string', 'string', 'string' ],
}); # fixes oper display in 0.8.10
Irssi::signal_add({
	'whois oper' => 'event_whois_oper',
	'event 313' => 'event_whois_oper',
	'event 330' => 'event_whois_auth',
	'event 337' => 'event_whois_ssl',
	'event 338' => 'event_whois_userip',
	'whois default event' => 'event_whois_default_event',
});

