#!/usr/bin/perl

# ignore_log.pl (ignore_log -- send [some] ignored events to log), Version 0.1
# this script is dedicated to bormann@IRCNET.
#
# Copyleft (>) 2004 jsn <jason@nichego.net>
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

use strict;
use Irssi;

use	POSIX qw/strftime/ ;

use vars qw($VERSION %IRSSI);

$VERSION = "0.1";
%IRSSI = (
	authors		=> 'Dmitry "jsn" Kim',
	contact		=> 'jason@nichego.net',
	name		=> 'ignore_log',
	description	=> 'script to log ignored messages',
	license		=> 'GPL',
	url		=> 'http://',
	changed		=> '2004-09-10',
	changes		=> 'initial version'
);

Irssi::print("*****\n* $IRSSI{name} $VERSION loaded.");
Irssi::print("*  use `/set ignore_log <filename>' to configure") ;
Irssi::print("*  use `/set ignore_log none' to disable ignore logging") ;

sub	handle_public {
	my	($srv, $msg, $nick, $addr, $tgt) = @_;
	return if lc(Irssi::settings_get_str("ignore_log")) eq "none" ;
	write_log($nick, $msg, $tgt)
	    if $srv->ignore_check($nick, $addr, $tgt, $msg, MSGLEVEL_PUBLIC) ;
}

sub	handle_private {
	my	($srv, $msg, $nick, $addr) = @_;
	return if lc(Irssi::settings_get_str("ignore_log")) eq "none" ;
	write_log($nick, $msg)
	    if $srv->ignore_check($nick, $addr, "", $msg, MSGLEVEL_MSGS) ;
}

sub	write_log {
    	my	($nick, $msg, $tgt) = @_ ;
	$tgt ||= "->" ;
	my	($lfile) = glob Irssi::settings_get_str("ignore_log");
	if (open(LF, ">>$lfile")) {
	    my	$ts = strftime("%D %H:%M", localtime()) ;
	    print LF "[$ts] $tgt $nick $msg\n" ;
	    close LF ;
	} else {
	    Irssi::active_win()->print("can't open file `$lfile': $!") ;
	}
}

Irssi::settings_add_str("ignore_log", "ignore_log", "~/.irssi/ignore.log");

Irssi::print("*  logging ignored users to `" .
	Irssi::settings_get_str("ignore_log") . "'") ;

Irssi::signal_add_first("message public", "handle_public") ;
Irssi::signal_add_first("message private", "handle_private") ;

