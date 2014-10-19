# handle 005 and 010 server messages and reconnect to that server
#
# 2002 Thomas Graf <irssi@reeler.org>

use strict;
use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI);

$VERSION = "0.1";
%IRSSI = (
    authors     => 'Thomas Graf',
    contact     => 'irssi@reeler.org',
    name        => 'redirect',
    description => 'handle 005 and 010 server messages and reconnect to that server',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.reeler.org/',
);

sub sig_servermsg
{
    my ($server, $line) = @_;

    if ( $line =~ /^005\s.*Try\sserver\s(.*?),.*port\s(.*?)$/ ||
         $line =~ /^010\s.*?\s(.*?)\s(.*?)\s/ ) {

        my $redirect = $1;
        my $port = $2;

        Irssi::print "Server suggests to redirect to $redirect $port";

        if ( Irssi::settings_get_bool("follow_redirect") ) {
            $server->command("SERVER $redirect $port");
        }
    }
}

Irssi::settings_add_bool("server", "follow_redirect", 1);

Irssi::signal_add_last('server event', 'sig_servermsg');
