# vim: ft=perl
use strict;
use warnings;

use Irssi qw(theme_register signal_add servers);

our $VERSION = '1.01';
our %IRSSI = (
    authors     => 'ilbelkyr',
    contact     => 'ilbelkyr on freenode, ilbelkyr@shalture.org',
    name        => 'account-notify',
    description => 'Display account identification status changes using CAP account-notify',
    license     => 'CC0 1.0 <https://creativecommons.org/publicdomain/zero/1.0/legalcode>',
    changed     => 'Sun Nov 04 00:42:42 CET 2017',
);

theme_register([
        account_identified   => '{channick_hilight $0} has identified as {hilight $2}',
        account_unidentified => '{channick $0} has unidentified',
    ]);

sub on_account {
    my ( $server, $account, $nick, $userhost ) = @_;

    $account =~ s/^://;

    # Print the notification to all shared channels, and the nick's query if any
    for my $c ( $server->channels ) {
        print_account( $c, $account, $nick, $userhost ) if $c->nick_find($nick);
    }
    my $q = $server->query_find($nick);
    print_account( $q, $account, $nick, $userhost ) if defined $q;
}

sub print_account {
    my ( $witem, $account, $nick, $userhost ) = @_;

    if ( $account ne '*' ) {
        $witem->printformat( MSGLEVEL_NICKS, 'account_identified', $nick, $userhost, $account );
    }
    else {
        $witem->printformat( MSGLEVEL_NICKS, 'account_unidentified', $nick, $userhost );
    }
}

sub on_connected {
    my ($server) = @_;

    if ( $server->{chat_type} eq 'IRC' ) {
        $server->irc_server_cap_toggle( 'account-notify', 1 );
    }
}

signal_add({
        'event account'   => \&on_account,
        'event connected' => \&on_connected,
    });

# When we are loaded, try to enable account-notify on all servers.
# ...But complain if this irssi is too old
if ( !Irssi::Irc::Server->can('irc_server_cap_toggle') ) {
    die 'This script requires a more recent Irssi exposing the client capability API to Perl';
}

for my $server ( servers() ) {
    on_connected($server);
}
