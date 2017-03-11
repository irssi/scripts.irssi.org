# Simple script to highlight links in public messages

use strict;
use vars qw($VERSION %IRSSI);

# Dev. info ^_^
$VERSION = "0.1";
%IRSSI = (
	authors     => "Stefan Heinemann",
	contact     => "stefan.heinemann\@codedump.ch",
	name        => "hilite url",
	description => "Simple script that highlights URL",
	license     => "GPL",
	url         => "http://senseless.codedump.ch",
);

sub hilite_url {
	my ($server, $data, $nick, $mask, $target) = @_;

	# Add Colours
	$data =~ s/(https?:\/\/[^\s]+)/\e[4;34m\1\e[00m/g;

	# Let it flow
	Irssi::signal_continue($server, $data, $nick, $mask, $target);
}

# Hook me up
Irssi::signal_add('message public', 'hilite_url');
