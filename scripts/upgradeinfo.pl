#
# Copyright (C) 2002-2021 by Peder Stray <peder.stray@gmail.com>
#

use strict;
use Irssi 20021204.1123;
use Irssi::TextUI;

use vars qw{$VERSION %IRSSI};
($VERSION) = '$Revision: 1.7.1 $' =~ / (\d+(\.\d+)+) /;
%IRSSI = (
	  name        => 'upgradeinfo',
	  authors     => 'Peder Stray',
	  contact     => 'peder.stray@gmail.com',
	  url         => 'https://github.com/pstray/irssi-upgradeinfo',
	  license     => 'GPL',
	  description => 'Statusbar item notifying you about updated binary',
	  sbitems     => 'upgradeinfo',
	 );

my($load_time) = 0;		# modification time of binary at load
my($file_time) = 0;		# modification time of binary file
my($timer) = 0;			# ID of current timer

sub cmd_upgradeinfo {
    my($param,$serv,$chan) = @_;

    print CLIENTCRAP sprintf ">> load: %s", scalar localtime $load_time;
    print CLIENTCRAP sprintf ">> file: %s", scalar localtime $file_time;
}

sub sig_setup_changed {
    my($interval) = Irssi::settings_get_int('upgrade_check_interval');

    Irssi::timeout_remove($timer);

    if ($interval < 1) {
	$interval = 0;
    }

    return unless $interval;

    $interval *= 1000;
    $timer = Irssi::timeout_add($interval, 'ui_check' , undef);
}

sub sb_upgradeinfo {
    my($item, $get_size_only) = @_;
    my $format = "";
    my($time);
    my($timefmt) = Irssi::settings_get_str('upgrade_time_format');

    $time = $file_time - $load_time;

    if ($time) {
	$time = sprintf($timefmt,
			$time/60/60/24,
			$time/60/60%24,
			$time/60%60,
			$time%60
		       );
	$time =~ s/^(0+\D+)+//;
	$format = "{sb %r$time%n}";
    }

    $item->default_handler($get_size_only, $format, undef, 1);
}

sub ui_check {
    $file_time = (stat Irssi::get_irssi_binary)[9];

    Irssi::statusbar_items_redraw('upgradeinfo');
}

Irssi::command_bind('upgradeinfo', 'cmd_upgradeinfo');

Irssi::settings_add_int('upgrade', 'upgrade_check_interval', 300);
Irssi::settings_add_str('upgrade', 'upgrade_time_format', '%d+%02d:%02d');

Irssi::signal_add('setup changed', 'sig_setup_changed');

Irssi::statusbar_item_register('upgradeinfo', undef, 'sb_upgradeinfo');

$load_time = (stat Irssi::get_irssi_binary)[9];
$file_time = $load_time;

sig_setup_changed;
