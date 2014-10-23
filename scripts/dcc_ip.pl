#!/usr/bin/perl -w
# dcc_ip.pl v0.5 - Copyright (c) ak5 2004
# License: Public Domain :-)
#
# this scripts gets the current IP before sending a dcc..
# useful, if you connect through a BNC f.e.
# just load it and it will do it's job if dcc_ip_interface is set correct.
# 

# This means: If you are connecting through a router:
#          /set dcc_ip_interface router
# (NOT the IP of your router, just the word "router".
#
# If you're on dialup or something other and you see your external
# IP address listed in 'ifconfig's output, 
#          /set dcc_ip_interface <interface>
# (for example ppp0)
#
# requires: /sbin/ifconfig ;) If you have a router, you need lynx also.
#
##########

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
    $VERSION = '0.5';
    %IRSSI = (
        authors     => 'ak5',
        contact     => 'meister@hq.kroenk.remove-this-because-of-spam.de',
        name        => 'dcc_ip',
        description => 'This script sets dcc_own_ip when starting a DCC send or chat.'.
		       'set dcc_ip_interface to your external interface, f.e. ppp0.'.
		       'If you are connecting though a router, set it to "router"',
        license     => 'Public Domain',
	url	    => 'http://hq.kroenk.de/?gnu/irssi',
	source      => 'http://hq.kroenk.de/?gnu/irssi/dcc_ip.pl/plaintext',
	changed     => 'Sa 26 Jun 2004 22:27:08 CEST',
    );

sub dcc_ip {
    my ($args, $shash, $c, $iface, $cmd, @arg, @ip) = @_;
    @arg = split(" ", $args);
    if (@arg[0] eq "send" || @arg[0] eq "chat") {
        $iface = Irssi::settings_get_str('dcc_ip_interface');
	
	if ($iface eq "router") {
		$cmd = `lynx -dump -nolist http://ipid.shat.net/iponly/`;
		$cmd =~ s/[a-zA-Z:\ \n]//g;
	} else {
		$cmd = `/sbin/ifconfig $iface | head -n 2 | tail -n 1`;
		$cmd =~ s/^[a-zA-Z\ ]*\://;
		$cmd =~ s/\ .*$//;
		$cmd =~ s/\n//;
	}
	Irssi::command("^set dcc_own_ip ".$cmd);

    }
};

Irssi::settings_add_str('dcc_ip', 'dcc_ip_interface', "ppp0");
Irssi::command_bind ('dcc', 'dcc_ip');
#EOF
