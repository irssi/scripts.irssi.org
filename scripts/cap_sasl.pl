use strict;
use Irssi;
use MIME::Base64;
use vars qw($VERSION %IRSSI);
use constant CHALLENGE_SIZE => 32;

$VERSION = "1.11";
%IRSSI = (
	authors => 'Michael Tharp (gxti), Jilles Tjoelker (jilles), Mantas Mikulėnas (grawity)',
	contact => 'grawity@gmail.com',
	name => 'cap_sasl.pl',
	description => 'Implements SASL authentication and enables CAP "multi-prefix"',
	license => 'GPLv2',
	url => 'http://ircv3.atheme.org/extensions/sasl-3.1',
);

my %sasl_auth = ();
my %mech = ();

sub irssi_abspath {
	my $f = shift;
	$f =~ s!^~/!$ENV{HOME}/!;
	if ($f !~ m!^/!) {
		$f = Irssi::get_irssi_dir()."/".$f;
	}
	return $f;
}

sub timeout;

sub server_connected {
	my $server = shift;
	if (uc $server->{chat_type} eq 'IRC') {
		$server->send_raw_now("CAP LS");
	}
}

sub event_cap {
	my ($server, $args, $nick, $address) = @_;
	my ($subcmd, $caps, $tosend, $sasl);

	$tosend = '';
	$sasl = $sasl_auth{$server->{tag}};
	if ($args =~ /^\S+ (\S+) :(.*)$/) {
		$subcmd = uc $1;
		$caps = ' '.$2.' ';
		if ($subcmd eq 'LS') {
			$tosend .= ' multi-prefix' if $caps =~ / multi-prefix /i;
			$tosend .= ' sasl' if $caps =~ / sasl /i && defined($sasl);
			$tosend =~ s/^ //;
			$server->print('', "CLICAP: supported by server:$caps");
			if (!$server->{connected}) {
				if ($tosend eq '') {
					$server->send_raw_now("CAP END");
				} else {
					$server->print('', "CLICAP: requesting: $tosend");
					$server->send_raw_now("CAP REQ :$tosend");
				}
			}
			Irssi::signal_stop();
		} elsif ($subcmd eq 'ACK') {
			$server->print('', "CLICAP: now enabled:$caps");
			if ($caps =~ / sasl /i) {
				$sasl->{buffer} = '';
				$sasl->{step} = 0;
				if ($mech{$sasl->{mech}}) {
					$server->send_raw_now("AUTHENTICATE " . $sasl->{mech});
					Irssi::timeout_add_once(7500, \&timeout, $server->{tag});
				} else {
					$server->print('', 'SASL: attempted to start unknown mechanism "' . $sasl->{mech} . '"');
				}
			}
			elsif (!$server->{connected}) {
				$server->send_raw_now("CAP END");
			}
			Irssi::signal_stop();
		} elsif ($subcmd eq 'NAK') {
			$server->print('', "CLICAP: refused:$caps");
			if (!$server->{connected}) {
				$server->send_raw_now("CAP END");
			}
			Irssi::signal_stop();
		} elsif ($subcmd eq 'LIST') {
			$server->print('', "CLICAP: currently enabled:$caps");
			Irssi::signal_stop();
		}
	}
}

sub event_authenticate {
	my ($server, $args, $nick, $address) = @_;
	my $sasl = $sasl_auth{$server->{tag}};
	return unless $sasl && $mech{$sasl->{mech}};

	$sasl->{buffer} .= $args;
	return if length($args) == 400;

	my $data = ($sasl->{buffer} eq '+') ? '' : decode_base64($sasl->{buffer});
	my $out = $mech{$sasl->{mech}}($sasl, $data);

	if (defined $out) {
		$out = ($out eq '') ? '+' : encode_base64($out, '');
		while (length $out >= 400) {
			my $subout = substr($out, 0, 400, '');
			$server->send_raw_now("AUTHENTICATE $subout");
		}
		if (length $out) {
			$server->send_raw_now("AUTHENTICATE $out");
		} else {
			# Last piece was exactly 400 bytes, we have to send
			# some padding to indicate we're done.
			$server->send_raw_now("AUTHENTICATE +");
		}
	} else {
		$server->send_raw_now("AUTHENTICATE *");
	}

	$sasl->{buffer} = "";
	Irssi::signal_stop();
}

sub event_saslend {
	my ($server, $args, $nick, $address) = @_;

	my $data = $args;
	$data =~ s/^\S+ :?//;
	# need this to see it, ?? -- jilles

	$server->print('', $data);
	if (!$server->{connected}) {
		$server->send_raw_now("CAP END");
	}
}

sub event_saslfail {
	my ($server, $args, $nick, $address) = @_;

	my $data = $args;
	$data =~ s/^\S+ :?//;

	if (Irssi::settings_get_bool('sasl_disconnect_on_fail')) {
		$server->print('', "$data - disconnecting from server", MSGLEVEL_CLIENTERROR);
		$server->disconnect();
	} else {
		$server->print('', "$data - continuing anyway");
		if (!$server->{connected}) {
			$server->send_raw_now("CAP END");
		}
	}
}

sub timeout {
	my $tag = shift;
	my $server = Irssi::server_find_tag($tag);
	if ($server && !$server->{connected}) {
		$server->print('', "SASL: authentication timed out", MSGLEVEL_CLIENTERROR);
		$server->send_raw_now("CAP END");
	}
}

sub cmd_sasl {
	my ($data, $server, $item) = @_;

	if ($data ne '') {
		Irssi::command_runsub ('sasl', $data, $server, $item);
	} else {
		cmd_sasl_show(@_);
	}
}

sub cmd_sasl_set {
	my ($data, $server, $item) = @_;

	if (my ($net, $u, $p, $m) = $data =~ /^(\S+) (\S+) (\S+) (\S+)$/) {
		if ($mech{uc $m}) {
			$sasl_auth{$net}{user} = $u;
			$sasl_auth{$net}{password} = $p;
			$sasl_auth{$net}{mech} = uc $m;
			Irssi::print("SASL: added $net: [$m] $sasl_auth{$net}{user} *");
		} else {
			Irssi::print("SASL: unknown mechanism $m", MSGLEVEL_CLIENTERROR);
		}
	} elsif ($data =~ /^(\S+)$/) {
		$net = $1;
		if (defined($sasl_auth{$net})) {
			delete $sasl_auth{$net};
			Irssi::print("SASL: deleted $net");
		} else {
			Irssi::print("SASL: no entry for $net");
		}
	} else {
		Irssi::print("SASL: usage: /sasl set <net> <user> <password or keyfile> <mechanism>");
	}
}

sub cmd_sasl_show {
	#my ($data, $server, $item) = @_;
	my @nets = keys %sasl_auth;
	for my $net (@nets) {
		Irssi::print("SASL: $net: [$sasl_auth{$net}{mech}] $sasl_auth{$net}{user} *");
	}
	Irssi::print("SASL: no networks defined") if !@nets;
}

sub cmd_sasl_save {
	#my ($data, $server, $item) = @_;
	my $file = Irssi::get_irssi_dir()."/sasl.auth";
	if (open(my $fh, ">", $file)) {
		chmod(0600, $file);
		for my $net (keys %sasl_auth) {
			printf $fh ("%s\t%s\t%s\t%s\n",
				$net,
				$sasl_auth{$net}{user},
				$sasl_auth{$net}{password},
				$sasl_auth{$net}{mech});
		}
		close($fh);
		Irssi::print("SASL: auth saved to '$file'");
	} else {
		Irssi::print("SASL: couldn't access '$file': $@");
	}
}

sub cmd_sasl_load {
	#my ($data, $server, $item) = @_;
	my $file = Irssi::get_irssi_dir()."/sasl.auth";
	if (open(my $fh, "<", $file)) {
		%sasl_auth = ();
		while (<$fh>) {
			chomp;
			my ($net, $u, $p, $m) = split(/\t/, $_, 4);
			$m ||= "PLAIN";
			if ($mech{uc $m}) {
				$sasl_auth{$net}{user} = $u;
				$sasl_auth{$net}{password} = $p;
				$sasl_auth{$net}{mech} = uc $m;
			} else {
				Irssi::print("SASL: unknown mechanism $m", MSGLEVEL_CLIENTERROR);
			}
		}
		close($fh);
		Irssi::print("SASL: cap_sasl $VERSION, auth loaded from '$file'");
	}
}

sub cmd_sasl_mechanisms {
	Irssi::print("SASL: mechanisms supported: " . join(", ", sort keys %mech));
}

Irssi::settings_add_bool('server', 'sasl_disconnect_on_fail', 1);

Irssi::signal_add_first('server connected', \&server_connected);
Irssi::signal_add('event cap', \&event_cap);
Irssi::signal_add('event authenticate', \&event_authenticate);
Irssi::signal_add('event 903', \&event_saslend);
Irssi::signal_add('event 904', \&event_saslfail);
Irssi::signal_add('event 905', \&event_saslend);
Irssi::signal_add('event 906', \&event_saslfail);
Irssi::signal_add('event 907', \&event_saslend);

Irssi::command_bind('sasl', \&cmd_sasl);
Irssi::command_bind('sasl load', \&cmd_sasl_load);
Irssi::command_bind('sasl save', \&cmd_sasl_save);
Irssi::command_bind('sasl set', \&cmd_sasl_set);
Irssi::command_bind('sasl show', \&cmd_sasl_show);
Irssi::command_bind('sasl mechanisms', \&cmd_sasl_mechanisms);

$mech{PLAIN} = sub {
	my ($sasl, $data) = @_;
	my $u = $sasl->{user};
	my $p = $sasl->{password};
	return join("\0", $u, $u, $p);
};

$mech{EXTERNAL} = sub {
	my ($sasl, $data) = @_;
	return $sasl->{user} // "";
};

if (eval {require Crypt::PK::ECC}) {
	my $mech = "ECDSA-NIST256P-CHALLENGE";

	$mech{'ECDSA-NIST256P-CHALLENGE'} = sub {
		my ($sasl, $data) = @_;
		my $u = $sasl->{user};
		my $f = $sasl->{password};
		$f = irssi_abspath($f);
		if (!-f $f) {
			Irssi::print("SASL: key file '$f' not found", MSGLEVEL_CLIENTERROR);
			return;
		}
		my $pk = eval {Crypt::PK::ECC->new($f)};
		if ($@ || !$pk || !$pk->is_private) {
			Irssi::print("SASL: no private key in file '$f'", MSGLEVEL_CLIENTERROR);
			return;
		}
		my $step = ++$sasl->{step};
		if ($step == 1) {
			if (length $data == CHALLENGE_SIZE) {
				my $sig = $pk->sign_hash($data);
				return $u."\0".$u."\0".$sig;
			} elsif (length $data) {
				return;
			} else {
				return $u."\0".$u;
			}
		}
		elsif ($step == 2) {
			if (length $data == CHALLENGE_SIZE) {
				return $pk->sign_hash($data);
			} else {
				return;
			}
		}
	};

	Irssi::command_bind("sasl keygen" => sub {
		my ($data, $server, $witem) = @_;

		my $print = $server
				? sub { $server->print("", shift, shift // MSGLEVEL_CLIENTNOTICE) }
				: sub { Irssi::print(shift, shift // MSGLEVEL_CLIENTNOTICE) };

		my $net = $server ? $server->{tag} : $data;
		if (!length $net) {
			Irssi::print("SASL: please connect to a server first",
						MSGLEVEL_CLIENTERROR);
			return;
		}

		my $f_name = lc "sasl-ecdsa-$net";
		   $f_name =~ s![ /]+!_!g;
		my $f_priv = Irssi::get_irssi_dir()."/$f_name.key";
		my $f_pub  = Irssi::get_irssi_dir()."/$f_name.pub";
		if (-e $f_priv) {
			$print->("SASL: refusing to overwrite '$f_priv'", MSGLEVEL_CLIENTERROR);
			return;
		}

		$print->("SASL: generating keypair for '$net'...");
		my $pk = Crypt::PK::ECC->new;
		$pk->generate_key("prime256v1");

		my $priv = $pk->export_key_pem("private");
		my $pub = encode_base64($pk->export_key_raw("public_compressed"), "");

		if (open(my $fh, ">", $f_priv)) {
			chmod(0600, $f_priv);
			print $fh $priv;
			close($fh);
			$print->("SASL: wrote private key to '$f_priv'");
		} else {
			$print->("SASL: could not write '$f_priv': $!", MSGLEVEL_CLIENTERROR);
			return;
		}

		if (open(my $fh, ">", $f_pub)) {
			print $fh $pub."\n";
			close($fh);
		} else {
			$print->("SASL: could not write '$f_pub': $!", MSGLEVEL_CLIENTERROR);
		}

		my $cmdchar = substr(Irssi::settings_get_str("cmdchars"), 0, 1);
		my $cmd = "msg NickServ SET PUBKEY $pub";

		if ($server) {
			$print->("SASL: updating your Irssi settings...");
			$sasl_auth{$net}{user} //= $server->{nick};
			$sasl_auth{$net}{password} = "$f_name.key";
			$sasl_auth{$net}{mech} = $mech;
			cmd_sasl_save(@_);
			$print->("SASL: submitting pubkey to NickServ...");
			$server->command($cmd);
		} else {
			$print->("SASL: update your Irssi settings:");
			$print->("%P".$cmdchar."sasl set $net <nick> $f_name.key $mech");
			$print->("SASL: submit your pubkey to $net:");
			$print->("%P".$cmdchar.$cmd);
		}
	});

	Irssi::command_bind("sasl pubkey" => sub {
		my ($data, $server, $witem) = @_;

		my $arg = $server ? $server->{tag} : $data;

		my $f;
		if (!length $arg) {
			Irssi::print("SASL: please select a server or specify a keyfile path",
						MSGLEVEL_CLIENTERROR);
			return;
		} elsif ($arg =~ m![/.]!) {
			$f = $arg;
		} else {
			if ($sasl_auth{$arg}{mech} eq $mech) {
				$f = $sasl_auth{$arg}{password};
			} else {
				$f = lc "sasl-ecdsa-$arg";
				$f =~ s![ /]+!_!g;
				$f = "$f.key";
			}
		}

		$f = irssi_abspath($f);
		if (!-e $f) {
			Irssi::print("SASL: keyfile '$f' not found", MSGLEVEL_CLIENTERROR);
			return;
		}

		my $pk = eval {Crypt::PK::ECC->new($f)};
		if ($@ || !$pk || !$pk->is_private) {
			Irssi::print("SASL: no private key in file '$f'", MSGLEVEL_CLIENTERROR);
			Irssi::print("(keys using named parameters or PKCS#8 are not yet supported)",
						MSGLEVEL_CLIENTERROR);
			return;
		}

		my $pub = encode_base64($pk->export_key_raw("public_compressed"), "");
		Irssi::print("SASL: loaded keyfile '$f'");
		Irssi::print("SASL: your pubkey is $pub");
	});
} else {
	Irssi::command_bind("sasl keygen" => sub {
		Irssi::print("SASL: cannot '/sasl keygen' as the Perl 'CryptX' module is missing",
					MSGLEVEL_CLIENTERROR);
	});

	Irssi::command_bind("sasl pubkey" => sub {
		Irssi::print("SASL: cannot '/sasl pubkey' as the Perl 'CryptX' module is missing",
					MSGLEVEL_CLIENTERROR);
	});
}

cmd_sasl_load();

# vim: ts=4:sw=4
