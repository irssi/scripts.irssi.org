use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '20071209';
%IRSSI = (
    authors     => '',
    contact     => '',
    name        => 'oops',
    description =>
'turns \'ls\' in the beginning of a sent line into the names or whois commands',
    license => 'Public Domain',
);

sub send_text {

    #"send text", char *line, SERVER_REC, WI_ITEM_REC
    my ( $data, $server, $witem ) = @_;
    if ( $witem
        && ( $witem->{type} eq "CHANNEL" )
        && ( $data =~ /(^ls |^ls$)/ ) )
    {
        $witem->command("names $witem->{name}");
        Irssi::signal_stop();
    }
    if ( $witem && ( $witem->{type} eq "QUERY" ) && ( $data =~ /(^ls |^ls$)/ ) )
    {
        $witem->command("whois $witem->{name}");
        Irssi::signal_stop();
    }
}

Irssi::signal_add 'send text' => 'send_text'
