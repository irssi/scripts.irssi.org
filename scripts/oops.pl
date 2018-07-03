use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '20071209';
%IRSSI = (
    authors     => '',
    contact     => '',
    name        => 'oops',
    description =>
'turns \'ll\' and \'ls\' in the beginning of a sent line into the names or whois commands',
    license => 'Public Domain',
);

sub send_text {
    my $pattern = qr/(^ll |^ll$|^ls |^ls$)/;

    #"send text", char *line, SERVER_REC, WI_ITEM_REC
    my ( $data, $server, $witem ) = @_;
    if ( $witem
        && ( $witem->{type} eq "CHANNEL" )
        && ( $data =~ $pattern ) )
    {
        $witem->command("names $witem->{name}");
        Irssi::signal_stop();
    }
    if ( $witem && ( $witem->{type} eq "QUERY" ) && ( $data =~ $pattern ) )
    {
        $witem->command("whois $witem->{name}");
        Irssi::signal_stop();
    }
}

Irssi::signal_add 'send text' => 'send_text'
