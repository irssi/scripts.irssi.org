#
# Copyright (C) 2002-2021 by Peder Stray <peder.stray@gmail.com>
#

use strict;
use Irssi;
use Irssi::Irc;
use Irssi::TextUI;

use vars qw{$VERSION %IRSSI};
($VERSION) = '$Revision: 1.6.1 $' =~ / (\d+(\.\d+)+) /;
%IRSSI = (
	  name        => 'uptime',
	  authors     => 'Peder Stray',
	  contact     => 'peder.stray@gmail.com',
	  url         => 'https://github.com/pstray/irssi-uptime',
	  license     => 'GPL',
	  description => 'Try a little harder to figure out client uptime',
	  sbitem      => 'uptime',
	 );

my($timer) = 0;			# ID of current timer

sub uptime_linux {
    my($sys_uptime);
    my($irssi_start);
    local(*FILE);

    open FILE, "<", "/proc/uptime";
    $sys_uptime = (split " ", <FILE>)[0];
    close FILE;

    open FILE, "<", "/proc/$$/stat";
    $irssi_start = (split " ", <FILE>)[21];
    close FILE;

    return $sys_uptime - $irssi_start/100;
}

sub uptime_solaris {
    my($irssi_start);

    $irssi_start = time - (stat("/proc/$$"))[9];

    return $irssi_start;
}

sub uptime {
    my($sysname) = @_;
    my($time);

    if ($sysname eq 'Linux') {
	$time = uptime_linux;
    } elsif ($sysname eq 'SunOS') {
	$time = uptime_solaris;
    } else {
	$time = time - $^T;
    }

    return $time;
}

sub format_interval {
    my($interval) = @_;

    my(@interval,$str);
    for (60, 60, 24, 365) {
	push @interval, $interval%$_;
	$interval = int($interval/$_);
    }
    $str = sprintf "%dy %dd %dh %dm %ds", $interval, @interval[3,2,1,0];
    $str =~ s/^(0. )+//;

    return $str;
}

sub cmd_uptime {
    my($data,$server,$witem) = @_;
    my($sysname) = Irssi::parse_special('$sysname');
    my($uptime) = uptime($sysname);
    my($str) = format_interval($uptime);

    if ($data && $server) {
	$server->command("MSG $data uptime: $str");
    } elsif ($witem && ($witem->{type} eq "CHANNEL" ||
			$witem->{type} eq "QUERY")) {
	$witem->command("MSG ".$witem->{name}." uptime: $str");
    } else {
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'uptime',
			   $str, $sysname);
    }
}

sub sig_setup_changed {
    my($interval) = Irssi::settings_get_int('uptime_refresh_interval');

    Irssi::timeout_remove($timer);

    if ($interval < 1) {
	$interval = 0;
    }

    return unless $interval;

    $interval *= 1000;
    $timer = Irssi::timeout_add($interval, 'uptime_refresh' , undef);
}

sub sb_uptime {
    my($item, $get_size_only) = @_;
    my $format = "";
    my($uptime) = uptime(Irssi::parse_special('$sysname'));
    my($time) = format_interval($uptime);

    $format = "{sb %g$time%n}";

    $item->default_handler($get_size_only, $format, undef, 1);
}

sub uptime_refresh {
    Irssi::statusbar_items_redraw('uptime');
}

Irssi::command_bind('uptime', 'cmd_uptime');

Irssi::theme_register(
[
 'uptime',
 '{line_start}{hilight Uptime:} $0 ($1)',
]);

Irssi::settings_add_int('upgrade', 'uptime_refresh_interval', 12);

Irssi::signal_add('setup changed', 'sig_setup_changed');

Irssi::statusbar_item_register('uptime', undef, 'sb_uptime');

sig_setup_changed;
