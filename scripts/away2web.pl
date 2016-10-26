#!/usr/bin/perl

use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "2003100201";
%IRSSI = (
    authors     => "Oskari 'Okko' Ojala",
    contact     => "sorter.irssi-scripts\@okko.net",
    name        => "away2web",
    description => "Write /away information to a file to be used on web pages",
    license     => "BSD",
    changed     => "$VERSION",
);
use Irssi 20020324;

#
# Writes /away information to a file. A web page script (cgi / php / pl..) can
# then read the file and display online/offline information.
# 
# The web page script is left as an excersise for the user because the platforms
# vary. :-)
# 
# Tip: You can also modify this script to directly write HTML and then just include
# the file on your web page.
#
#
# Format of the file:
# First line:  Either "1" or "0". 0=Offline (away), 1=Online (not away).
# Second line: The away reason (message). If the user is Online, second line is
#              empty but exists.
#
# File is written to ~/.irssi/away2web-status.
#

sub catch_away {
	my $server = shift;

	open(STATUSFILE, q{>}, $ENV{'HOME'}.'/.irssi/away2web-status') || die ("away2web.pl: Could not open file for writing:".$!);

	if ($server->{usermode_away}) {
	    # User is offline.
	    print STATUSFILE "0\n";
	} else {
	    # User is online.
	    print STATUSFILE "1\n";
	}

	print STATUSFILE $server->{'away_reason'}."\n";

	close(STATUSFILE);

}

Irssi::signal_add("away mode changed", "catch_away");

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' (c) '.$IRSSI{authors}.' loaded';

# end of script.
