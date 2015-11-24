use strict;
use Irssi ();
use vars qw(%IRSSI $VERSION);
$VERSION = '0.1';
%IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'dccrelay',
    description => 'Relays DCC messages. Originally written by greeny & mute for NoNameScript.',
    license     => 'GNU GPLv2 or later',
);

use constant NET => 0;
use constant NICK => 1;
use constant RESUME => 2;

sub lc1459 ($) {
	my $x = shift;
	$x =~ y/A-Z][\\^/a-z}{|~/;
	$x
}

my ($r_net, $r_nick) = ('', '');

my %relaying = ();

Irssi::settings_add_str('dccrel', 'dccrel_on', '');
Irssi::settings_add_bool('dccrel', 'dccrel_auto_on', 0);

Irssi::theme_register([
	relay_dcc_send => '{dcc DCC Relay SEND from {nick $0} [$1 port $2]: $3 [$4] {dcc to {nick $5/$6}}}',
	relay_dcc_rejected => '{dcc DCC Relay REJECT SEND from {nick $0} [$1] {dcc to {nick $2/$3}}}'
]);
Irssi::signal_add({
	'ctcp msg' => sub {
		my ($server, $data, $from, $host, $to) = @_;
		length($data) > 250 and return;
		my ($self, $network) = ($server->{'nick'}, $server->{'tag'});
		#Irssi::print(join '>>', @_);
		if (lc1459($to) eq lc1459($self) and $data =~ /^dcc ([^ ]+) /i) { # mss me & dcc
			my $func = lc $1;
			if ('send' eq $func) { # S -> R
				if (my ($file, $ip, $port, $size) = $data =~ /^dcc send (".*"|[^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)(?: |$)/i) {
					if (my $r_ser = Irssi::server_find_tag($r_net)) {
						$relaying{$file} = $relaying{$port} =[ $network => $from => 0];
						$r_ser->send_raw("PRIVMSG $r_nick :\001$data\001");
						my $h_ip = ($ip =~ /:/ ? "[$ip]" : inet_ntoa(inet_aton($ip)));
						#$server->print('', "DCC Relay SEND from $from [$h_ip port $port]: $file [$size] to $r_net/$r_nick", Irssi::MSGLEVEL_DCC);
						$server->printformat('', Irssi::MSGLEVEL_DCC, 'relay_dcc_send', $from, $h_ip, $port, $file, $size, $r_net, $r_nick);
						#Irssi::print(Dumper(\%relaying));
						Irssi::signal_stop();
					}
				}
			}
			elsif ('resume' eq $func) { # R -> S
				if (my ($fake, $port, $pos) = $data =~ /^dcc resume (".*"|[^ ]+) ([^ ]+) ([^ ]+)(?: |$)/i) {
					if (lc $network eq lc $r_net and lc1459($from) eq lc1459($r_nick)) {
						if (my $info = $relaying{$port}) { if (my $s_ser = Irssi::server_find_tag($info->[NET])) { # saw this
							my ($s_nick, $s_net) = ($info->[NICK], $info->[NET]);
							$info->[RESUME] = 1;
							$s_ser->send_raw("PRIVMSG $s_nick :\001$data\001");
							#$server->print('', "DCC Relay RESUME from $from [$pos] to $s_net/$s_nick", Irssi::MSGLEVEL_DCC);
							Irssi::signal_stop();
						} }
					}
				}
			}
			elsif ('accept' eq $func) { # S -> R
				if (my ($fake, $port, $pos) = $data =~ /^dcc accept (".*"|[^ ]+) ([^ ]+) ([^ ]+)(?: |$)/i) {
					if (my $info = $relaying{$port} and my $r_ser = Irssi::server_find_tag($r_net)) {
						if (lc $network eq lc $info->[NET] and lc1459($from) eq lc1459($info->[NICK]) and $info->[RESUME]) {
							$r_ser->send_raw("PRIVMSG $r_nick :\001$data\001");
							#$server->print('', "DCC Relay ACCEPT from $from [$pos] to $r_net/$r_nick", Irssi::MSGLEVEL_DCC);
							Irssi::signal_stop();
						}
					}
				}
			}
		}
	},
	'ctcp reply' => sub {
		my ($server, $data, $from, $host, $to) = @_;
		length($data) > 250 and return;
		my ($self, $network) = ($server->{'nick'}, $server->{'tag'});
		if (lc1459($to) eq lc1459($self) and $data =~ /^dcc ([^ ]+) /i) { # mss me & dcc
			my $func = lc $1;
			if ('reject' eq $func) { # R -> S
				if (my ($file) = $data =~ /^dcc reject send (".*"|[^ ]+)(?: |$)/i) {
					if (lc $network eq lc $r_net and lc1459($from) eq lc1459($r_nick)) {
						if (my $info = $relaying{$file}) { if (my $s_ser = Irssi::server_find_tag($info->[NET])) { # this too
							my ($s_nick, $s_net) = ($info->[NICK], $info->[NET]);
							@$info = ();
							$s_ser->send_raw("NOTICE $s_nick :\001$data\001");
							#$server->print('', "DCC Relay REJECT SEND from $from to $s_net/$s_nick", Irssi::MSGLEVEL_DCC);
							$server->printformat('', Irssi::MSGLEVEL_DCC, 'relay_dcc_rejected', $from, $file, $s_net, $s_nick);
							Irssi::signal_stop();
						} }
					}
				}
			}
		}
	}
});

Irssi::command_bind(
	dccrel => sub {
		my ($data) = @_;
		my ($state, $value) = split / /, $data, 2;
		if ($state =~ /^(?:on|off)$/i) {
			if ($value) {
				Irssi::command("SET dccrel_on $value");
			}
			if (lc $state eq 'off') {
				($r_net, $r_nick) = ('', '');
			}
			elsif (lc $state eq 'on') {
				my $settings = Irssi::settings_get_str('dccrel_on');
				($r_net, $r_nick) = split '/', $settings, 2;
			}
		}
		#else {
			Irssi::print("DCC Relay status: $r_net/$r_nick");
		#}
	}
);

if (Irssi::settings_get_bool('dccrel_auto_on')) {
	Irssi::command('DCCREL on');
}

