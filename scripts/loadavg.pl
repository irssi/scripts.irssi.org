# system load average statusbar item
# using vm.loadavg mib or /proc/loadavg
#
# /statusbar window add loadavg
# /set loadavg_refresh

use strict;
use Irssi;
use Irssi::TextUI;
use vars qw($VERSION %IRSSI);

$VERSION="0.4";
%IRSSI = (
	authors	    => 'aki',
	contact	    => 'aki@evilbsd.info',
	name	    => 'loadavg',
	description => 'display a loadavg statusbar item using vm.loadavg mib or /proc/loadavg',
	sbitems	    => 'loadavg',
	license	    => 'public domain',
);

my ($timeout, $lavg);

sub reload { Irssi::statusbar_items_redraw('loadavg'); }

sub setup {
	my $time = Irssi::settings_get_int('loadavg_refresh');
	Irssi::timeout_remove($timeout);
	$timeout = Irssi::timeout_add($time, 'reload' , undef);
}

sub show {
	my ($item, $get_size_only) = @_;
	get(); chomp $lavg;
	$item->default_handler($get_size_only, "{sb ".$lavg."}", undef, 1);	
}

sub get {
	if ($^O eq 'freebsd' || $^O eq 'netbsd' || $^O eq 'openbsd' ) {
		$lavg=`sysctl vm.loadavg|cut -d" " -f3-5`;
	} elsif ($^O eq 'linux') { $lavg=`cat /proc/loadavg|cut -d" " -f1-3`; }
}

Irssi::statusbar_item_register('loadavg', '$0', 'show');
Irssi::settings_add_int('misc', 'loadavg_refresh', 15000);
Irssi::signal_add('setup changed', 'setup');
$timeout = Irssi::timeout_add(Irssi::settings_get_int('loadavg_refresh'), 'reload' , undef);
