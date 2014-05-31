use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";

%IRSSI = (
    authors=> "Chris \'raz\' Hoogenboezem",
    contact=> "chrish\@carrier6.com",
    name=> "accountname",
    description=> "Instead of displaying semi-raw data, a /whois now gives a tidy accountname on Asuka/lain servers (if applicable).",
    license=> "Feel free to alter anything conform your own liking.",
);

Irssi::theme_register([tidyaccount => ' account  : $0']);

sub event_tidyaccount {
	my @auth = split(/ +/, $_[1]);
	$_[0]->printformat((split(/ +/, $_[1]))[1], MSGLEVEL_CRAP, 'tidyaccount', ((substr($auth[3],0,1) eq ":") ? $auth[2] : $auth[5]));
	Irssi::signal_stop();
}

Irssi::signal_add('event 330', 'event_tidyaccount');