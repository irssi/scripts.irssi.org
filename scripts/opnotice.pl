# Opnotice script, by Terje Tjeldnes (terje@darkrealm.no)
# Compatible with bahamut (DALnet ircd) or any other ircd with
# support for the /notice @#channel syntax.
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
#
# Commands: /o <text> in a channel.

use strict;
use Irssi;

use vars qw($VERSION %IRSSI);

$VERSION = "0.1";

%IRSSI = (
	authors	=> "Terje \"xerath\" Tjeldnes",
	contact	=> "terje\@darkrealm.no",
	name	=> "Opnotice",
	url	=> "http://palantir.darkrealm.no/opnotice.pl",
	license	=> "GNU GPL v2",
	changed	=> "Thu Jul 25 00:19:09 CEST 2002"
);


sub cmd_opnotice {
my ($data, $server, $witem) = @_;

if (!$server || !$server->{connected}) {
      Irssi::print("Not connected to server");
      return;
}

if ($witem && ($witem->{type} eq "CHANNEL")) {
	chomp ($data);
	$witem->command("NOTICE \@".$witem->{name}." $data");
	}
	else {
		Irssi::print("Not in a channel, aborted");
	}
}

Irssi::command_bind('o', 'cmd_opnotice');


