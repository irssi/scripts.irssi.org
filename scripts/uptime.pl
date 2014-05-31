# uptime - irssi 0.7.98.CVS 
#
#    $Id: uptime.pl,v 1.6 2003/02/04 02:43:06 peder Exp $
#
# Copyright (C) 2002, 2003 by Peder Stray <peder@ninja.no>
#

use strict;
use Irssi;
use Irssi::Irc;
use Irssi::TextUI;

# ======[ Script Header ]===============================================

use vars qw{$VERSION %IRSSI};
($VERSION) = '$Revision: 1.6 $' =~ / (\d+\.\d+) /;
%IRSSI = (
          name        => 'uptime',
          authors     => 'Peder Stray',
          contact     => 'peder@ninja.no',
          url         => 'http://ninja.no/irssi/uptime.pl',
          license     => 'GPL',
          description => 'Try a little harder to figure out client uptime',
	  sbitems     => 'uptime',
         );

# ======[ Variables ]===================================================

my($timer) = 0;			# ID of current timer

# ======[ Helper functions ]============================================

# --------[ uptime_linux ]----------------------------------------------

sub uptime_linux {
    my($sys_uptime);
    my($irssi_start);
    local(*FILE);

    open FILE, "< /proc/uptime";
    $sys_uptime = (split " ", <FILE>)[0];
    close FILE;

    open FILE, "< /proc/$$/stat";
    $irssi_start = (split " ", <FILE>)[21];
    close FILE;

    return $sys_uptime - $irssi_start/100;
}

# --------[ uptime_solaris ]--------------------------------------------

sub uptime_solaris {
    my($irssi_start);

    $irssi_start = time - (stat("/proc/$$"))[9];

    return $irssi_start;
}

# --------[ uptime ]----------------------------------------------------

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

# --------[ format_interval ]-------------------------------------------

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

# ======[ Commands ]====================================================

# --------[ cmd_uptime ]------------------------------------------------

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

# ======[ Signal Hooks ]================================================

# --------[ sig_setup_changed ]-----------------------------------------

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

# ======[ Statusbar Hooks ]=============================================

# --------[ sb_uptime ]-------------------------------------------------

sub sb_uptime {
    my($item, $get_size_only) = @_;
    my $format = "";
    my($uptime) = uptime(Irssi::parse_special('$sysname'));
    my($time) = format_interval($uptime);
    
    $format = "{sb %g$time%n}";
    
    $item->default_handler($get_size_only, $format, undef, 1);
}

# ======[ Timers ]======================================================

# --------[ uptime_refresh ]--------------------------------------------

sub uptime_refresh {
    Irssi::statusbar_items_redraw('uptime');
}

# ======[ Setup ]=======================================================

# --------[ Register commands ]-----------------------------------------

Irssi::command_bind('uptime', 'cmd_uptime');

# --------[ Register formats ]------------------------------------------

Irssi::theme_register(
[
 'uptime',
 '{line_start}{hilight Uptime:} $0 ($1)',
]);

# --------[ Register settings ]-----------------------------------------

Irssi::settings_add_int('upgrade', 'uptime_refresh_interval', 12);

# --------[ Register signals ]------------------------------------------

Irssi::signal_add('setup changed', 'sig_setup_changed');

# --------[ Register statusbar items ]----------------------------------

Irssi::statusbar_item_register('uptime', undef, 'sb_uptime');

# --------[ Other setup ]-----------------------------------------------

sig_setup_changed;

# ======[ END ]=========================================================

# Local Variables:
# header-initial-hide: t
# mode: header-minor
# end:
