use strict;
use warnings;

our $VERSION = '2.0'; # ed9e98e5d63cfb3
our %IRSSI = (
    authors     => 'Nei',
    name        => 'cap_sasl_fail',
    description => 'Disconnect from server if SASL authentication fails.',
    license     => 'GNU GPLv2 or later',
   );

use Irssi 20150920;
use version;

my %disconnect_next;

my $irssi_version = qv(Irssi::parse_special('v$J') =~ s/-.*//r);
die sprintf "Support for Irssi v%vd has not been written yet.\n", $irssi_version
    if $irssi_version > v0.8.20;

Irssi::signal_register({'server sasl fail' => [qw[iobject string]]});
Irssi::signal_add_first('server sasl fail' => 'sasl_fail_failed');
Irssi::signal_add_first('server sasl failure' => 'sasl_failure');
Irssi::signal_add_first('server cap end' => 'server_cap_end' );

sub sasl_fail_failed {
    Irssi::signal_emit('server sasl failure', @_);
}

sub sasl_failure {
    my ($server, $reason) = @_;
    &Irssi::signal_continue;
    my $disconnect = Irssi::settings_get_bool('sasl_disconnect_on_fail');
    my $reconnect = Irssi::settings_get_bool('sasl_reconnect_on_fail');
    if ($disconnect || $reconnect) {
	$server->send_raw_now('QUIT');
    }
    unless ($reason =~ /timed out/ || $reconnect) {
	$disconnect_next{ $server->{tag} } = 1;
    }
}

sub server_cap_end {
    my ($server) = @_;
    $server->disconnect
	if delete $disconnect_next{ $server->{tag} };
}

Irssi::settings_add_bool('server', 'sasl_disconnect_on_fail', 1);
Irssi::settings_add_bool('server', 'sasl_reconnect_on_fail', 0);
