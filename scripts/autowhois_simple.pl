# Simple and LIGHT version of script /WHOIS'ing all who
# send you a private message. Makes /WHOIS once per person, 
# only when the query window has been created 
# and therefore works only with irssi with
# default query window behaviour.
use strict;
use Irssi;
use vars qw($VERSION %IRSSI); 

$VERSION = "0.1";
%IRSSI = (
    authors=> "Janne Mikola",
    contact=> "janne\@mikola.info",
    name=> "autowhois_simple",
    description=> "/WHOIS anyone querying you automatically.",
    license=> "GPL",
    url=> "http://www.mikola.info",
    changed=> "14th of July, 2008",
    changes=> "v0.1: Initial release"
);

my $handle_this_query = 0;

# Checks the birth of a new query window.
sub new_query {
    $handle_this_query = 1;
}

# Does the WHOIS if privmsg is in a new query window.
sub make_whois {
    if($handle_this_query) {
	my ($server, $msg, $nick, $addr) = @_;
	$server->command("whois $nick");
	$handle_this_query = 0;
    }
}

Irssi::signal_add_first('query created', 'new_query');
Irssi::signal_add('message private', 'make_whois');
