use strict;
use vars qw($VERSION %IRSSI);

use Irssi::TextUI;

$VERSION = "0.4";
%IRSSI = (
    authors     => "Alexander Wirt",
    contact     => "formorer\@formorer.de",
    name        => "apm",
    description => "Shows your battery status in your Statusbar",
    sbitems     => "power",
    license     => "GNU Public License",
    url         => "http://www.formorer.de/code",
);


#
#apm.pl 
#	apm.pl is a small script for displaying your Battery Level in irssi.
#	Just load the script and do a /statusbar window add apm
#	and a small box [BAT: +/-XX%] should be displayed this is only possible 
#	on Computers where /proc/apm or /proc/acpi is existing. 
#	The + or - indicates if battery is charging or discharging.
#
#	/set power_refresh <sec>    changes the refreshing time of the display
#
#
#	Changelog:
#
#	0.3 - Added support for ACPI and enhanced APM support
#	0.2 - Added apm_refresh and some documentation
#	0.1 - Initial Release





my ($refresh, $last_refresh, $refresh_tag) = (10);

my ($acpi,$apm) = 0;


if (-r "/proc/acpi") { $acpi = "yes" }
if (-r "/proc/apm") { $apm = "yes" }

exit unless ($apm or $acpi);


sub get_apm {
	open(RC, q{<}, "/proc/apm");
		my $line = <RC>;
	close RC;
	my ($ver1, $ver2, $sysstatus, $acstat, $chargstat, $batstatus, $prozent, $remain) = split(/\s/,$line);

	if ($acstat eq "0x01") { return "+$prozent" } else { return "-$prozent" }
}

sub get_acpi {
	open(RC, q{<}, "/proc/acpi/ac_adapter/ACAD/state");
		my $line = <RC>;
	close RC;
	my ($text,$state) = split (/:/,$line);
	$state =~ s/\s//g;

	open (RC, q{<}, "/proc/acpi/battery/BAT0/info");
	my ($text,$capa,$ein);
	while (my $line = <RC>) {
		if ($line =~ /last full capacity/) {
			($text, $capa,$ein) = split (/:/,$line);
			$capa =~ s/\s//g;
		}
	}
	open (RC, q{<}, "/proc/acpi/battery/BAT0/state"); 
	my ($text,$remain,$ein);
	while (my $line = <RC>) {
		if ($line =~ /remaining capacity/) {
			($text, $remain,$ein) = split (/:/,$line);
			$remain =~ s/\s//g;
		}
	}
	my $pstate = $remain / $capa * 100;
	$pstate = sprintf("%2i", $pstate);

	if ($state eq "off-line") { $pstate = "-$pstate%"; } else { $pstate = "+$pstate%"; }
	return $pstate;
}


sub power {
	my ($item, $get_size_only) = @_;
	my $pstate;
	if ($apm) {
		$pstate = get_apm();
	} else {
		$pstate = get_acpi();
	}
	$item->default_handler($get_size_only, undef, "BAT:$pstate", 1 );
}


sub set_power {
	$refresh = Irssi::settings_get_int('power_refresh');
	$refresh = 1 if $refresh < 1;
	return if $refresh == $last_refresh;
	$last_refresh = $refresh;
	Irssi::timeout_remove($refresh_tag) if $refresh_tag;
	$refresh_tag = Irssi::timeout_add($refresh*1000, 'refresh_power', undef);

}


sub refresh_power {
	Irssi::statusbar_items_redraw('power');
}

Irssi::statusbar_item_register('power', '{sb $0-}', 'power');
Irssi::statusbars_recreate_items();

Irssi::settings_add_int('misc', 'power_refresh', $refresh);
set_power();
Irssi::signal_add('setup changed', 'set_power');
