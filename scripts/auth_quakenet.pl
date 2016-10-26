# vim: ft=perl
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

## Settings:
#
# quakenet_account (string) = ( [<servertag>:]<username>:<password> )*
#
#   Your QuakeNet account details, in format <username>:<password>. Example:
#
#       /set quakenet_account [fishking]:iLOVEfish12345
#
#   Different accounts for different Irssi "networks" ("server tags") can be
#   set in format <servertag>:<username>:<password> (space-separated). The
#   account with empty (or missing) <servertag> will be used as the default
#   account for all other connections.)
#
# quakenet_auth_allowed_mechs (string) = any
#
#   List of allowed mechanisms, separated by spaces.
#   Can be "any" to allow all supported mechanisms.
#
#   Currently supported:
#      HMAC-SHA-256 (Digest::SHA)
#      HMAC-SHA-1   (Digest::SHA1)
#      HMAC-MD5     (Digest::MD5)
#      LEGACY-MD5   (Digest::MD5 without HMAC)
#
#   Note: LEGACY-MD5 is excluded from "any"; if you want to use it, specify
#   it manually.
#
## To trigger the script manually, use:
## /msg Q@cserve.quakenet.org challenge

$VERSION = "1.0";
%IRSSI = (
	authors     => 'Mantas Mikulėnas',
	contact     => 'grawity@gmail.com',
	name        => 'auth_quakenet_challenge.pl',
	description => "Implements QuakeNet's CHALLENGE authentication",
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
	url         => 'http://purl.net/net/grawity/irssi.html',
);

require Digest::HMAC;

my @preferred_mechs = qw(HMAC-SHA-256 HMAC-SHA-1 HMAC-MD5);

my %supported_mechs = ();

eval {
	require Digest::SHA;
	$supported_mechs{"HMAC-SHA-256"} = sub {
		hmac(\&Digest::SHA::sha256_hex, \&Digest::SHA::sha256, @_);
	};
};

eval {
	require Digest::SHA1;
	$supported_mechs{"HMAC-SHA-1"} = sub {
		hmac(\&Digest::SHA1::sha1_hex, \&Digest::SHA1::sha1, @_);
	};
};

eval {
	require Digest::MD5;
	$supported_mechs{"HMAC-MD5"} = sub {
		hmac(\&Digest::MD5::md5_hex, \&Digest::MD5::md5, @_);
	};
	$supported_mechs{"LEGACY-MD5"} = sub {
		Irssi::print("WARNING: LEGACY-MD5 should not be used.");
		my ($challenge, $username, $password) = @_;
		Digest::MD5::md5_hex($password . " " . $challenge);
	};
};

if (scalar keys %supported_mechs == 0) {
	die "No mechanisms available. Please install these Perl modules:\n"
		." - Digest::HMAC\n"
		." - Digest::SHA, Digest::SHA1, Digest::MD5 (at least one)\n";
}

sub hmac {
	my ($fnhex, $fnraw, $challenge, $username, $password) = @_;
	my $key = &$fnhex($username . ":" . &$fnhex($password));
	Digest::HMAC::hmac_hex($challenge, $key, $fnraw);
}

sub lcnick {
	my $str = shift;
	$str =~ tr/[\\]/{|}/;
	lc $str;
}

sub get_account {
	my ($servertag) = @_;
	my $accounts = Irssi::settings_get_str("quakenet_account");
	my ($defuser, $defpass) = (undef, undef);
	for my $acct (split /\s+/, $accounts) {
		my ($tag, $user, $pass);

		my @acct = split(/:/, $acct);
		if (@acct == 3) {
			($tag, $user, $pass) = @acct;
		} elsif (@acct == 2) {
			($tag, $user, $pass) = ("*", @acct);
		} else {
			next;
		}

		if (lc $tag eq lc $servertag) {
			return ($user, $pass);
		}
		elsif ($tag eq "*" or $tag eq "") {
			($defuser, $defpass) = ($user, $pass);
		}
	}
	return ($defuser, $defpass);
}

Irssi::signal_add_last("event 001" => sub {
	my ($server, $evargs, $srcnick, $srcaddr) = @_;
	return unless $srcnick =~ /\.quakenet\.org$/;

	my ($user, $pass) = get_account($server->{tag});
	return if !length($pass);

	$server->print("", "Authenticating to Q");
	$server->send_message('Q@cserve.quakenet.org', "CHALLENGE", 1);
});

Irssi::signal_add_first("message irc notice" => sub {
	my ($server, $msg, $nick, $address, $target) = @_;
	return unless $server->mask_match_address('Q!*@cserve.quakenet.org', $nick, $address);

	if ($msg =~ /^CHALLENGE ([0-9a-f]+) (.+)$/) {
		Irssi::signal_stop();

		my $challenge = $1;
		my @server_mechs = split(" ", $2);

		my ($user, $pass) = get_account($server->{tag});
		return if !length($pass);

		$user = lcnick($user);
		$pass = substr($pass, 0, 10);

		my $mech;
		my @allowed_mechs = ();
		my $allowed_mechs = uc Irssi::settings_get_str("quakenet_auth_allowed_mechs");
		if ($allowed_mechs eq "ANY") {
			# @preferred_mechs is sorted by strength
			@allowed_mechs = @preferred_mechs;
		} else {
			@allowed_mechs = split(/\s+/, $allowed_mechs);
		}

		# choose first mech supported by both sides
		for my $m (@allowed_mechs) {
			if (grep {$_ eq $m} @server_mechs &&
			    grep {$_ eq $m} (keys %supported_mechs)) {
				$mech = $m;
				last;
			}
		}

		if (!defined $mech) {
			$server->print("", "Authentication failed (no mechanisms available)");
			$server->print("", "  Server offers:   ".join(", ", @server_mechs));
			$server->print("", "  Client supports: ".join(", ", keys %supported_mechs));
			$server->print("", "  Restricted to:   ".join(", ", @allowed_mechs));
			return;
		}

		my $authfn = $supported_mechs{$mech};

		my $response = &$authfn($challenge, $user, $pass);
		$server->send_message('Q@cserve.quakenet.org', "CHALLENGEAUTH $user $response $mech", 1);
	}
	
	elsif ($msg =~ /^You are now logged in as (.+?)\.$/) {
		Irssi::signal_stop();
		$server->print("", "Authentication successful, logged in as $1");
	}

	elsif ($msg =~ /^Username or password incorrect\.$/) {
		Irssi::signal_stop();
		$server->print("", "Authentication failed (username or password incorrect)");
	}
});

Irssi::settings_add_str("misc", "quakenet_auth_allowed_mechs", "any");
Irssi::settings_add_str("misc", "quakenet_account", "");
if (Irssi::settings_get_str("quakenet_account") eq "") {
	Irssi::print("Set your QuakeNet account using /set quakenet_account username:password");
}
