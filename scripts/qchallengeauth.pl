use strict;
use warnings;
use Irssi;
use Digest::SHA qw(sha256_hex hmac_sha256_hex);
use vars qw($VERSION %IRSSI);
# $Id$

$VERSION = "1.0";

%IRSSI = (
    authors     => 'Doug Freed',
    contact     => 'dwfreed!#irssi@freenode',
    name        => 'qchallengeauth.pl',
    description => 'Authenticates you to QuakeNet\'s Q immediately on connect using CHALLENGEAUTH',
    license     => 'GPLv3+',
);

Irssi::settings_add_str('misc', 'quakenet_server_tag', 'QuakeNet');
Irssi::settings_add_str('misc', 'quakenet_username', '');
Irssi::settings_add_str('misc', 'quakenet_password', '');

Irssi::signal_add('server connected', 'server_connected');

sub server_connected() {
	my ($server) = @_;
	return unless ($server->{tag} eq Irssi::settings_get_str('quakenet_server_tag'));
	Irssi::signal_add_first('event connected', 'event_connected');
}

sub event_connected() {
	my ($server) = @_;
	return unless ($server->{tag} eq Irssi::settings_get_str('quakenet_server_tag'));
	Irssi::signal_add_first('message irc notice', 'message_irc_notice');
	Irssi::signal_remove('event connected', 'event_connected');
	$server->send_raw('PRIVMSG Q@cserve.quakenet.org :CHALLENGE');
	Irssi::signal_stop();
}

sub message_irc_notice() {
	my ($server, $message, $nick, $address, $target) = @_;
	return unless ($server->{tag} eq Irssi::settings_get_str('quakenet_server_tag'));
	return unless ($target eq $server->{nick});
	return unless ($nick eq 'Q');
	if ($message =~ /^CHALLENGE ([[:xdigit:]]+)/){
		Irssi::signal_stop();
		my $username = Irssi::settings_get_str('quakenet_username');
		my $hashed_password = sha256_hex(substr(Irssi::settings_get_str('quakenet_password'), 0, 10));
		my $key = sha256_hex("$username:$hashed_password");
		my $response = hmac_sha256_hex($1, $key);
		$server->send_raw("PRIVMSG Q\@cserve.quakenet.org :CHALLENGEAUTH $username $response HMAC-SHA-256");
	} else {
		Irssi::signal_remove('message irc notice', 'message_irc_notice');
		Irssi::signal_emit('event connected', $server);
	}
}
