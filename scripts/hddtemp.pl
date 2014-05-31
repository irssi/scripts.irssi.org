########
# INFO
#
# Type this to add the item:
#
# /statusbar window add hddtemp
#  
# See
# 
# /help statusbar
#
#
# If you want to use this script install the hddtemp daemon on the host
# you like to monitor and set it up, You can use multiple hosts aswell.
#
# Example:
# /set hddtemp_hosts host1 host2 host3
# /set hddtemp_ports 7634 7635 7553
# 
# If all the daemons run all on the same port you can set a single port, 
# It will be used for all hosts.
#
# Example:
# /set hddtemp_ports 7634
#
# There are 2 coloring threshold settings hddtemp_threshold_green
# and hddtemp_threshold_red. If the temperature is higher than 
# green and lower then red the color will be yellow.
#
# Example:
# /set hddtemp_threshold_green 35
# /set hddtemp_threshold_red 45
# 
# (I don't know if the unit retured by the daemon depends on the 
#  locale. I've Celsius values here.)
# 
# 
# There is a setting for the degree sign.
# Since there is a difference between 8bit and utf-8 
# you can set it to what you prefer
#
########
# CHANGES:
# 0.13 - added forking (not blocking irrsi while fetching the temperatures)
#######
# TODO: themeing support
#

use strict;
use Irssi;
use IO::Socket::INET;
use POSIX;

use vars qw($VERSION %IRSSI);
$VERSION = "0.14";
%IRSSI = (
    authors     => "Valentin Batz",
    contact     => "vb\@g-23.org",
    name        => "hddtemp",
    description => "adds a statusbar item which shows temperatures of harddisks (with multiple hddtemp-hosts support)",
    license     => "GPLv2",
    changed     => "2004-06-21",
    url         => "http://hurzelgnom.bei.t-online.de/irssi/scripts/hddtemp.pl",
    sbitems     => "hddtemp"
);

my $forked;
my $pipe_tag;
my $outstring = 'hddtemp...';

sub get_data {
	my $lines;
	my @hosts = split(/ /, Irssi::settings_get_str("hddtemp_hosts"));
	my @ports = split(/ /, Irssi::settings_get_str("hddtemp_ports"));
	print "hi";
	while(scalar(@hosts) > scalar(@ports)){
		push @ports, @ports[0];
	}
	my $i=0;
	for ($i;$i<scalar(@hosts);$i++) {
		my $sock = IO::Socket::INET->new(PeerAddr => @hosts[$i],  
						 PeerPort => @ports[$i], 
						 Proto => 'tcp',
						 Timeout => 10);
		#skip dead hosts
		next unless $sock;
		while( $_ = $sock->getline()) {
			$lines .= $_.';';
		}
	}
	return $lines;
}

sub get_temp {
	my ($rh, $wh);
	pipe($rh, $wh);
	return if $forked;
	my $pid = fork();
	if (!defined($pid)) {
	    Irssi::print("Can't fork() - aborting");
	    close($rh); close($wh);
	    return;
	}
  	$forked = 1;
	if ($pid > 0) {
		#parent 
		close($wh);
		Irssi::pidwait_add($pid);
		$pipe_tag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, $rh);
		return;
	}
	
	my $lines;
	eval {
		#child
		$lines = get_data();
		#write the reply
		print ($wh $lines);
		close($wh);
	};
	POSIX::_exit(1);
}

sub pipe_input {
	my $rh=shift;
	my $linesx=<$rh>;
	close($rh);
	Irssi::input_remove($pipe_tag);
	$forked = 0;
	my %temps;
	my $green = Irssi::settings_get_int("hddtemp_threshold_green");
	my $red = Irssi::settings_get_int("hddtemp_threshold_red");
	my $degree = Irssi::settings_get_str("hddtemp_degree_sign");
	unless ($linesx) {
		return(0);
	}
	my ($hdd, $model, $temp, $unit);
	my $i=0;
	foreach my $lines (split(';', $linesx)) {
		foreach my $line (split(/\|\|/, $lines)) {
			#remove heading/traling | 
			$line =~ s/^\|//;
			$line =~ s/\|$//;
			
			($hdd, $model, $temp, $unit) = split(/\|/,$line,4);
			
			$hdd =~ s/(.*)\/(.*)$/$2/;
			#different colors for different termperatures
			if ($temp <= $green) {
				$temps{$i.':'.$hdd} = '%g'.$temp.'%n'.$degree.$unit;
			} elsif ($temp > $green && $temp < $red) {
				$temps{$i.':'.$hdd} = '%y'.$temp.'%n'.$degree.$unit;
			} elsif ($temp >= $red) {
				$temps{$i.':'.$hdd} = '%r'.$temp.'%n'.$degree.$unit;
			}
		}
		$i++;
	}
	my $out='';
	foreach (sort keys %temps) {
		$out .= "$_: $temps{$_} ";
	}
	$out=~s/\s+$//;
	# temporal use of $out to prevent statusbar drawing errors
	$outstring=$out;
	Irssi::statusbar_items_redraw('hddtemp');
}

sub sb_hddtemp() {
	my ($item, $get_size_only) = @_;
	$item->default_handler($get_size_only, "{sb $outstring}", undef, 1); 
} 

Irssi::timeout_add(15000, \&get_temp, undef);
Irssi::statusbar_item_register('hddtemp', undef, 'sb_hddtemp');
Irssi::settings_add_str("hddtemp", "hddtemp_hosts","localhost");
Irssi::settings_add_str("hddtemp", "hddtemp_ports","7634");
Irssi::settings_add_int("hddtemp", "hddtemp_threshold_green", 35);
Irssi::settings_add_int("hddtemp", "hddtemp_threshold_red", 45);
Irssi::settings_add_str("hddtemp", "hddtemp_degree_sign","°");
Irssi::signal_add("setup changed", \&get_temp);
get_temp();
