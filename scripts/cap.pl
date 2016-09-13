use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
	authors => 'dwfreed',
	contact => 'dwfreed@mtu.edu',
	name => 'cap',
	description => 'Prints caps; derived from cap_sasl.pl by Michael Tharp (gxti), Jilles Tjoelker (jilles), and Mantas Mikulėnas (grawity)',
	license => 'GPLv2',
	url => 'none yet',
);

sub event_cap {
	my ($server, $args, $nick, $address) = @_;
	my ($subcmd, $caps);

	if ($args =~ /^\S+ (\S+) :(.*)$/) {
		$subcmd = uc $1;
		$caps = ' '.$2.' ';
		if ($subcmd eq 'LS') {
			$server->print('', "CLICAP: supported by server:$caps");
		} elsif ($subcmd eq 'ACK') {
			$server->print('', "CLICAP: now enabled:$caps");
		} elsif ($subcmd eq 'NAK') {
			$server->print('', "CLICAP: refused:$caps");
		} elsif ($subcmd eq 'LIST') {
			$server->print('', "CLICAP: currently enabled:$caps");
		}
	}
}
Irssi::signal_add('event cap', \&event_cap);
