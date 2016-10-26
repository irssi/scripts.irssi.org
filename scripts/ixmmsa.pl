#!/usr/bin/perl

# ixmmsa.pl (iXMMSa - irssi XMMS announce), Version 0.3
#
# Copyleft (>) 2002 Kristof Korwisi <kk@manoli.im-dachgeschoss.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# The complete text of the GNU General Public License can be found
# on the World Wide Web: <URL:http://www.gnu.org/licenses/gpl.html>

use Xmms();
use Xmms::Remote ();
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.2+1";
%IRSSI = (
	authors		=> 'Kristof Korwisi',
	contact		=> 'kk@manoli.im-dachgeschoss.de',
	name		=> 'iXMMSa',
	description	=> '/xmms announces which _file_ is currently playing. E.g.  Currently playing: "Kieran Halpin & Band - Mirror Town.mp3"',
	license		=> 'GPL',
	url		=> 'http://manoli.im-dachgeschoss.de/~kk/',
	changed		=> '2006-10-27',
	changes		=> 'added some comments, added $announce_message:_*-stuff',
);

Irssi::print("*****\n* $IRSSI{name} $VERSION loaded.\n* Type /xmms to announce currently played file.\n*****");

sub cmd_xmms {

	my ($data, $server, $witem) = @_; 
	my $xmms_remote = Xmms::Remote->new;

        my $announce_message_front = "Currently playing:";      # announce message in front of the filename playing
	my $announce_message_after = "";                        # announce message after the filename playing
			

	$filename= $xmms_remote->get_playlist_file($xmms_remote->get_playlist_pos);


	$filename =~ s/.*\///g;					# removes path
	$filename =~ s/^$/Nothing's playing/;			# in case there's nothing to listen to ;-)
	$filename =~ s/[\r\n]/ /g;				# remove newline characters

	if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {
		$witem->command("MSG ".$witem->{name}." $announce_message_front \"$filename\" $announce_message_after");
	} else {
		Irssi::print("Not on active channel/query");
	}
}

Irssi::command_bind('xmms', 'cmd_xmms');
