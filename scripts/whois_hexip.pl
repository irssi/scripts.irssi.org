#!/usr/bin/perl
# whois_hexip irssi module
# written by Michael Kowalchuk <michael_kowalchuk@umanitoba.ca>
#
# Every time a WHOIS or WHOWAS is run, this script checks the
# ident and realname for a hex encoded IP address, then decodes
# it, optionally reverses it, and adds it to the printed WHOIS
# result. Useful for looking at CGI::IRC clients.
#
# dns lookups are blocking, so if you find them to be slow, disable
# lookups with the whois_hexip_lookup option.
#
# usage:
#
# put this script into your autorun directory and/or load it with
#  /SCRIPT LOAD whois_hexip
#
# there is 1 setting:
#  /set whois_hexip_lookup ON/OFF
#
# lookup means attempt to get the hostname; if it is off you will
# only get the IP address
#
#
# changes:
#  24.12.2005 fix msg levels so the hexip won't end up in the wrong win
#  10.10.2005 allowed idents to start with ~
#  07.09.2005 limit to 32 bit numbers
#  28.07.2005 changed realname matching to look for 0 or 1 non-word
#             characters on either side of the hexadecimal number
#             for less false-positives
#  13.07.2005 added max_realname_nonhex
#  12.07.2005 initial release
#

use strict;
use Irssi;
use Socket;


use vars qw($VERSION %IRSSI);

$VERSION = "1.4";
%IRSSI = (
    authors     => "Michael Kowalchuk",
    contact     => "michael_kowalchuk\@umanitoba.ca",
    name        => "whois_hexip",
    description => "Every time a WHOIS or WHOWAS is run, this script checks the ident and realname for a hex encoded IP address, then decodes it, reverses it, and adds it to the printed WHOIS/WHOWAS result. Useful for looking at CGI::IRC clients.",
    license     => "MIT",
    url         => "http://home.cc.umanitoba.ca/~umkowa17/junk/whois_hexip.pl",
    changed     => "12.24.2005",
);

my $hexreg = "[A-Fa-f0-9]+";

sub event_server_event {
	my ($server, $text) = @_;

	# Look up the ident and whois
	my @items = split(/ /,$text);

	my $ident = $items[2];
	$ident =~ s/^~//;
	
	# CGI::IRC can put the IP in the WHOIS too!  Thanks mef
	my $whois = join(" ",  @items[5 .. @items] );
	$whois =~ s/^://; # Remove the initial :
	$whois =~ s/\s+$//; # and any trailing whitespace

	# Set $num to whatever string holds the hex ip, with
	# priority given to the ident
	my @numarray = undef;
	@numarray = ($ident =~ /^\~?($hexreg)$/ );
	@numarray = ($whois =~ /^($hexreg)$/) if @numarray eq 0;
	@numarray = ($whois =~ /^[^\w]($hexreg)[^\w]$/) if @numarray eq 0;

	my $num = $numarray[0] if @numarray gt 0;	

	if( $num and length($num) <= 8 ) {
		my $ip = inet_aton(hex $num);
		my $display = gethostbyaddr($ip, AF_INET)
			if Irssi::settings_get_bool($IRSSI{'name'}."_lookup");

		# If there's a DNS timeout rather than an NXDOMAIN,
		# you get an empty string rather than undefined
		if( not defined $display or ( $display eq "" )  ) {
			$display = inet_ntoa($ip)
		}
	
		$server->printformat($items[1], MSGLEVEL_CRAP, $IRSSI{'name'},
						$items[1], $display );
	}
}


Irssi::theme_register([$IRSSI{'name'} => '{whois hexip %|$1}']);

Irssi::signal_add_last('event 311', 'event_server_event'); # WHOIS
Irssi::signal_add_last('event 314', 'event_server_event'); # WHOWAS

Irssi::settings_add_bool('misc', $IRSSI{'name'} . '_lookup', 1);

