#!/usr/bin/perl
# X is the Undernet bot
# This script is meant to make X commands easier and faster to use.
# 
# Copyright 2003 Clément Hermann <clement.hermann@free.fr>
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use vars qw($VERSION %IRSSI);

use Irssi qw(command_bind signal_add);

$VERSION = '0.2';
%IRSSI = (
authors     => 	'Clément "nodens" Hermann',
contact     => 	'clement.hermann@free.fr',
name        => 	'Xcmd',
description => 	'makes Undernet\'s X commands easier and faster to use',
license     => 	'GPLv2',
changed     => 	$VERSION,
commands    => 	'xcmd',
);

sub help {
	Irssi::print("xcmd launch an X command (/MSG X <command>), using the current windows as channel name.");
	Irssi::print("Any command that have a <channel> parameter can be used.");
	Irssi::print("/Xcmd showcommands show X commands for the current channel.");
}
	
sub xcommand {
	my ($data, $server, $witem) = @_;
	my $channel;
	
	if (! $data) {
		&help;
	} else {
		my @params = split (/ /,$data);
		my $cmd = shift @params;
		my $args = join (" ",@params);
	
		if ($witem && ($witem->{type} eq "CHANNEL")) {
			$channel = $witem->{name};
			$witem->command("MSG X $cmd $channel $args");
		} else {
			Irssi::print("No active channel in window");
		}
	}
}

Irssi::command_bind('xcmd', 'xcommand');

Irssi::print("Xcmd $VERSION by nodens. Try /xcmd for help");
