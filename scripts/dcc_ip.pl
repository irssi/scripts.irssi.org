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
use Socket;
use vars qw($VERSION %IRSSI);
    $VERSION = '0.6';
    %IRSSI = (
        authors     => 'ak5, bw1',
        contact     => 'meister@hq.kroenk.remove-this-because-of-spam.de',
        name        => 'dcc_ip',
        description => 'This script sets dcc_own_ip when starting a DCC send or chat.'.
		       'set dcc_ip_interface to your external interface, f.e. ppp0.'.
		       'If you are connecting though a router, set it to "router"',
        license     => 'Public Domain',
	url	    => 'http://hq.kroenk.de/?gnu/irssi',
	source      => 'http://hq.kroenk.de/?gnu/irssi/dcc_ip.pl/plaintext',
	changed     => '2019-02-17',
    );

# ip of the nat interface as a string;
my $router_ip;
# state of whois
my $router_c=0;
# arguments of the dcc command
my $router_args;

sub dcc_ip {
    my ($args, $shash, $c, $iface, $cmd, @arg, @ip) = @_;
    @arg = split(" ", $args);
    if (@arg[0] eq "send" || @arg[0] eq "chat") {
        $iface = Irssi::settings_get_str('dcc_ip_interface');
        if ($router_c == 0) {
            if ($iface eq "router") {
                mywhois($args, $shash, $c);
                Irssi::signal_stop();
                $router_c=1;
                $router_args = $args;
                return;
            } else {
                $cmd = `/sbin/ifconfig $iface | head -n 2 | tail -n 1`;
                $cmd =~ s/^[a-zA-Z\ ]*\://;
                $cmd =~ s/\ .*$//;
                $cmd =~ s/\n//;
            }
            Irssi::command("^set dcc_own_ip ".$cmd);
        } else {
            $router_c =0;
        }
    }
};

sub mywhois {
    my ($args, $server, $witem) = @_;
    my $nick =$server->{nick};
    $server->redirect_event("whois", 1, $nick, 0, undef, {
        "event 311" => "redir whos",
        "event 318" => "redir whosend",
        "" => "event empty"}
    );
    $server->send_raw("WHOIS " . $nick);
}

sub sig_whos {
    my ($server, $data) = @_;
    my @r = split(/\s/,$data);
    $router_ip = $r[3];
}

sub sig_whosend {
    my ($server, $data) = @_;

    if ( defined $router_ip ) {
        if ( !( $router_ip =~ m/\d+\.\d+\.\d+\.\d+/ ||
                ($router_ip =~ m/[0-9a-fA-F:]+/ && $router_ip =~ m/:.*:/ ))) {
            my $packed_ip = gethostbyname($router_ip);
            if (defined $packed_ip) {
                $router_ip = inet_ntoa($packed_ip);
            } else {
                $router_ip = undef;
            }
        }
    }
    if ( defined $router_ip ) {
        Irssi::settings_set_str("dcc_own_ip", $router_ip);
        $server->command('dcc '.$router_args );
    }
}

Irssi::signal_add('redir whos', \&sig_whos);
Irssi::signal_add('redir whosend', \&sig_whosend);

Irssi::settings_add_str('dcc_ip', 'dcc_ip_interface', "ppp0");
Irssi::command_bind ('dcc', 'dcc_ip');
#EOF

# vim:set ts=8 sw=4 expandtab:
