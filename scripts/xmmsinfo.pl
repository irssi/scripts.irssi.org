#!/usr/bin/perl

# $Id: xmmsinfo.pl,v 1.1.1.1 2002/03/24 21:00:55 tj Exp $
#
# Copyright (0) 2002 Tuomas Jormola <tjormola@cc.hut.fi
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
# $Log: xmmsinfo.pl,v $
# Revision 1.1.1.1  2002/03/24 21:00:55  tj
# Initial import.
#
#
# TODO:
# * Configurable string to print (%t = title, %a = artist ...)

use strict;
use Irssi;
use Irssi::XMMSInfo;
use vars qw($VERSION %IRSSI);

# global variables
$VERSION = sprintf("%d.%02d", q$Revision: 1.1.1.2 $ =~ /^.+?(\d+)\.(\d+)/);
%IRSSI = (
	authors		=> 'Tuomas Jormola',
	contact		=> 'tjormola@cc.hut.fi',
	name		=> 'XMMSInfo',
	description	=> '/xmmsinfo to tell what you\'re currently playing',
	license		=> 'GPLv2',
	url			=> 'http://shakti.tky.hut.fi/stuff.xml#irssi',
	changed		=> '2006-1027T18:00+0300',
);

if(runningUnderIrssi()) {
	Irssi::settings_add_str('misc', 'xmms_info_pipe', '/tmp/xmms-info');
	Irssi::command_bind('xmmsinfo', 'commandXmmsInfo');
	Irssi::print("$IRSSI{name} $VERSION loaded, /xmmsinfo -help");
} else {
	(my $s = $0) =~ s/.*\///;
	$ARGV[0] || die("Usage: $s <file>\n");
	commandXmmsInfo();
}

# command handler
sub commandXmmsInfo {
	my($args, $server, $target) = @_;

	if(lc($args) eq "-help") {
		Irssi::print("XMMSInfo $VERSION by $IRSSI{authors} <$IRSSI{contact}>");
		Irssi::print("");
		Irssi::print("Displays what your XMMS is playing using information");
		Irssi::print("provided by the XMMS InfoPipe plugin");
		Irssi::print("<URL:www.iki.fi/wwwwolf/code/xmms/infopipe.html");
		Irssi::print("");
		Irssi::print("Usage: /xmmsinfo [TARGET]");
		Irssi::print("If TARGET is given, the info is sent there, othwerwise to");
		Irssi::print("the current active channel/query or Irssi status window");
		Irssi::print("if you have no channel/query window active.");
		Irssi::print("Target can be nick name or channel name");
		Irssi::print("");
		Irssi::print("Configuration: /set xmms_info_pipe <file>");
		Irssi::print("Define filename of the pipe where from the InfoPipe output is read");
		Irssi::print("Default is /tmp/xmms-info");
		return;
	}

	my($p) = runningUnderIrssi() ? Irssi::settings_get_str('xmms_info_pipe') : $ARGV[0];
	my($i) = XMMSInfo->new;
	$i->getInfo(pipe => $p);

	my($o) = "XMMS: " . $i->getStatusString;

	if($i->isFatalError) {
		$o .= ": " . $i->getError;
	} elsif($i->isXmmsRunning) {
		my($t) = $i->infoTitle || "(unknown song)";
		my($a) = $i->infoArtist || "(unknown artist)";
		my($g) = lc($i->infoGenre) || "(unknown genre)";
		my($pos) = $i->infoMinutesNow . "m" . $i->infoSecondsNowLeftover."s";
		my($tot) = $i->infoMinutesTotal . "m" . $i->infoSecondsTotalLeftover."s";
		my($per) = $i->infoPercentage;
		my($b) = $i->infoBitrate . "kbps";
		my($f) = $i->infoFrequency . "kHz";
		$o .= " $g tune $t by $a." if ($i->isPlaying || $i->isPaused);
		$o .= " Played $pos of total $tot ($per%)." if $i->isPlaying;
		$o .= " [$b/$f]" if ($i->isPlaying || $i->isPaused);
	}

	if(!runningUnderIrssi()) {
		print "$o\n";
	} elsif($i->isFatalError || !$server || !$server->{connected} || (!$args && !$target)) {
		Irssi::print($o);
	} else {
		$o =~ s/[\r\n]/ /g; # remove newline characters
		my($t) = $args || $target->{name};
		$server->command("msg $t $o");
	}

}

sub runningUnderIrssi {
	$0 eq '-e';
}

# END OF SCRIPT
