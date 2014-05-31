use strict;
use Net::SNMP;
use vars qw($VERSION %IRSSI);

# Changes:
# Apr 6:
# - Added debug option
# - Checks for remote OS type.. Windows' snmpd is somewhat different
# - Included load averages
# - Multiple hosts support
# Mar 13:
# - Typofixes

$VERSION = "2.00";
%IRSSI = (
	authors => "Rick (strlen) Jansen",
	contact => "strlen\@shellz.nl",
	name => "snmpup",
	description => "This script queries remote hosts (/snmpup <host1> <host2> <hostN>) running snmpd for it's uptime and cpu usage",
	license => "GPL/2",
	changed => "Sun Apr 6 17:57:28 CET 2002"
);

use Irssi;
sub snmpup {
	my ($input, $server, $data) = @_;

	# Assume $input are hostnames if no debug flag is given
	my (@hostnames, $debug, @mibs, $hostname);
	
	if ($input !~ /^\-d/) {
		@hostnames = split(" ",$input);
		$debug = 0;
	} else {
		$input =~ s/^\-d //;
		@hostnames = split(" ",$input);
		$debug = 1;
	}
	if (!@hostnames) { Irssi::print("snmpup: invalid syntax: $input"); return }

	my $hostUpTime = '1.3.6.1.2.1.25.1.1.0';
	my $sysSystem = '1.3.6.1.2.1.1.1.0';
	my $sysUpTime = '1.3.6.1.2.1.1.3.0';
	my $hrLoad = '1.3.6.1.2.1.25.3.3.1.2.1';
	my $laLoadInt1 = '1.3.6.1.4.1.2021.10.1.5.1';
	my $laLoadInt5 = '1.3.6.1.4.1.2021.10.1.5.2';
	my $laLoadInt15 = '1.3.6.1.4.1.2021.10.1.5.3';
	
	foreach $hostname (@hostnames) {
		my ($session, $error) = Net::SNMP->session(
					-hostname	=>	$hostname,
					-community	=>	'public',
					-port		=>	'161',
					);
		if (!defined($session)) {
			$server->command("/msg ".$data->{name}." Unable to create SNMP connection: $error");
			return;
		} elsif ($debug) {
			Irssi::print("Net::SNMP session created.");
		}

		my $a = $session->get_request(-varbindlist=>[$sysSystem]);

		my $system = $a->{$sysSystem};

		if ($debug) {
			Irssi::print("Remote system type is $system");
		}

		if ($system =~ /Windows/) { 
			@mibs = [$sysUpTime,$hrLoad];
		} else {
			@mibs = [$hostUpTime,$laLoadInt1,$laLoadInt5,$laLoadInt15];
		}

		my $result = $session->get_request(-varbindlist=>@mibs);

		if (!defined($result)) {
			my $err = $session->error;
			$server->command("/msg ".$data->{name}." SNMP get error: $err");
			$session->close();
		} else {
			my $host = $session->hostname; 
			my ($uptime, $load);
			if ($system =~ /Windows/) {
				$uptime = $result->{$sysUpTime};
				$load = sprintf("CPU Usage: %d%",$result->{$hrLoad});
			} else {
				$uptime = $result->{$hostUpTime};
				$load = sprintf("load averages: %.2f, %.2f, %.2f",
						   $result->{$laLoadInt1} / 100,
						   $result->{$laLoadInt5} / 100,
					   	$result->{$laLoadInt15} / 100);
			}
			$server->command("/msg ".$data->{name}." SNMP uptime for host '$host' is $uptime, $load");
			$session->close();
		}
		$session->close();
	}
}
Irssi::command_bind("snmpup","snmpup");
