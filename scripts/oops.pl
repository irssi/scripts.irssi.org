use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '20180707';
%IRSSI = (
    authors     => '',
    contact     => '',
    name        => 'oops',
    description =>
    'turns \'ll\' and \'ls\' in the beginning of a sent line into the names or whois commands',
    license => 'Public Domain',
    );

sub send_text {
    my $pattern = qr/(^(ll|ls)\s*$)/;

    #"send text", char *line, SERVER_REC, WI_ITEM_REC
    my ( $data, $server, $witem ) = @_;
    if($data =~ $pattern) {
        if($witem->{type} eq "CHANNEL")
        {
            $witem->command("names $witem->{name}");
            Irssi::signal_stop();
        }
        elsif($witem->{type} eq "QUERY")
        {
            $witem->command("whois $witem->{name}");
            Irssi::signal_stop();
        }
    }
}

Irssi::signal_add 'send text' => 'send_text'
