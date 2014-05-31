use Irssi;
use Irssi::TextUI;
use strict;

use vars qw($VERSION %IRSSI);

$VERSION="0.2.6";
%IRSSI = (
	authors=> 'BC-bd',
	contact=> 'bd@bc-bd.org',
	name=> 'nact',
	description=> 'Adds an item which displays the current network activity. Needs /proc/net/dev.',
	license=> 'GPL v2 or later',
	url=> 'https://bc-bd.org/svn/repos/irssi/trunk/',
);

#########
# INFO
###
#
#  Currently running on Linux, OpenBsd and FreeBsd.
#
#  Type this to add the item:
#
#    /statusbar window add nact
#
#  See
#  
#    /help statusbar
#
#  for more help on how to custimize your statusbar.
#  Add something like this to your theme file to customize to look of the item
#
#    nact_display = "$0%R>%n%_$1%_%G>%n$2";
#    
#  where $0 is the input, $1 the device and $2 the output. To customize the
#  outout of the /bw command add something like
#
#    nact_command = "$0)in:$1:out($2";
#
#  to your theme file.
#
##########
# THEME
####
#
# This is the complete list of parameters passed to the format:
#
#    $0: incomming rate
#    $1: name of the device, eg. eth0
#    $2: outgoing rate
#    $3: total bytes received
#    $4: total bytes sent
#    $5: sum of $4 and $5
#
#########
# TODO
###
#
# Make this script work on other unices, For that i need some infos on where
# to find the total amount of sent bytes on other systems. You may be so kind
# as to send me the name of such a file and a sample output of it.
#
#   or
#
# you can be so kind as to send me a patch. Fort that _please_ check that you
# do have the latest nact.pl and use these diff switches:
#
#   diff -uN nact.pl.new nact.pl.old 
#
############
# OPTIONS
######
#
# /set nact_command <command>
#   command: command to execute on /bw. example:
#
#     /set nact_command /say
#
# /set nact_devices <devices>
#   devices: space seperated list of devices to display
#
# /set nact_interval <n>
#   n: number of mili-seconds to wait before an update of the item
#
# /set nact_format <format>
#   format: a format string like the one with sprintf. examples: 
#
#     /set nact_format %d    no digits after the point at all
#     /set nact_format %.3f  3 digits after the point
#     /set nact_format %.5f  5 digits after the point
# 
# /set nact_unit <n>
#   n: set the unit to KiB, MiB, or GiB. examples:
#
#     /set nact_unit 0 calculate dynamically
#     /set nact_unit 1 set to KiB/s
#     /set nact_unit 2 set to MiB/s
#     /set nact_unit 3 set to GiB/s
#   
###
################

my $outString = "nact...";
my $outCmd = "nact...";
my (%in,%out,$timeout,$getBytes);

sub getBytesLinux() {
	my @list;
	my $ignore = 2;
	
	open(FID, "/proc/net/dev");

	while (<FID>) {
		if ($ignore > 0) {
			$ignore--;
			next;
		}

		my $line = $_;
		$line =~ s/[\s:]/ /g;
		@list = split(" ", $line);
		$in{$list[0]} = $list[1];
		$out{$list[0]} = $list[9];
	}

	close (FID);
}

sub getBytesOBSD() {
	my @list;
	
	open(FID, "/usr/bin/netstat -nib|");

	while (<FID>) {
		my $line = $_;
		@list = split(" ", $line);
		$in{$list[0]} = $list[4];
		$out{$list[0]} = $list[5];
	}

	close (FID);
}

sub getBytesFBSD() {
  my @list;
  my $olddev="";

  open(FID, "/usr/bin/netstat -nib|");
  while (<FID>) {
    my $line = $_;
    @list = split(" ", $line);
    next if $list[0] eq $olddev;
    $in{$list[0]} = $list[6];
    $out{$list[0]} = $list[9];
    $olddev=$list[0];
  }

  close (FID);
}

sub make_kilo($$$) {
	my ($what,$format,$unit) = @_;
	my ($effective);

	# determine the effective unit, either from forcing, or from dynamically
	# checking the size of the value
	if ($unit == 0) {
		if ($what >= 1024*1024*1024) {
			$effective = 3
		} elsif ($what >= 1024*1024) {
			$effective = 2
		} elsif ($what >= 1024) {
			$effective = 1
		} else {
			$effective = 0;
		}
	} else {
		$effective = $unit;
	}
	
	if ($effective >= 3) {
			return sprintf($format."%s", $what/(1024*1024*1024), "G");
	} elsif ($effective == 2) {
			return sprintf($format."%s", $what/(1024*1024), "M");
	} elsif ($effective == 1) {
			return sprintf($format."%s", $what/(1024), "K");
	} else {
		return sprintf($format, $what);
	}
}

sub sb_nact() {
	my ($item, $get_size_only) = @_;

	$item->default_handler($get_size_only, "{sb $outString}", undef, 1);
}

sub timeout_nact() {
	my ($out,$char);
	my $slice = Irssi::settings_get_int('nact_interval');
	my $format = Irssi::settings_get_str('nact_format');
	my $unit = Irssi::settings_get_int('nact_unit');
	my $theme = Irssi::current_theme();
	my %oldIn = %in;
	my %oldOut = %out;
	
	&$getBytes();
		
	$out = "";
	$outCmd = "";
		
	foreach (split(" ", Irssi::settings_get_str('nact_devices'))) {
		my $b_in = $in{$_};
		my $b_out = $out{$_};
		my $deltaIn = make_kilo(($b_in -$oldIn{$_})*1000/$slice,$format,$unit);
		my $deltaOut = make_kilo(($b_out -$oldOut{$_})*1000/$slice,$format,$unit);
		my $i = make_kilo($b_in,$format,$unit);
		my $o = make_kilo($b_out,$format,$unit);
		my $s = make_kilo($b_in +$b_out,$format,$unit);

		$out .= Irssi::current_theme->format_expand(
			"{nact_display $deltaIn $_ $deltaOut $i $o $s}",Irssi::EXPAND_FLAG_IGNORE_REPLACES);
		
		$outCmd .= Irssi::current_theme->format_expand(
			"{nact_command $deltaIn $_ $deltaOut $i $o $s}",Irssi::EXPAND_FLAG_IGNORE_REPLACES);
	}

	# perhaps this usage of $out as temp variable does fix those nasty
	# display errors
	$outString = $out;
	Irssi::statusbar_items_redraw('nact');
}

sub nact_setup() {
	my $slice = Irssi::settings_get_int('nact_interval');
	
	Irssi::timeout_remove($timeout);

	if ($slice < 10) {
		Irssi::print("nact.pl, ERROR nact_interval must be greater than 10");
		return;
	}

	$timeout = Irssi::timeout_add($slice, 'timeout_nact' , undef);
}

sub cmd_bw {
	my ($data, $server, $witem) = @_;

	if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {
		$witem->command(Irssi::settings_get_str('nact_command')." ".$outCmd);
	} else {
		Irssi::print("nact: command needs window of type channel or query.");
	}
}

Irssi::command_bind('bw','cmd_bw');

Irssi::signal_add('setup changed','nact_setup');

# register our item
Irssi::statusbar_item_register('nact', undef, 'sb_nact');

# register our os independant settings
Irssi::settings_add_int('misc', 'nact_interval', 10000);
Irssi::settings_add_str('misc', 'nact_format', '%.0f');
Irssi::settings_add_int('misc', 'nact_unit', 0);
Irssi::settings_add_str('misc', 'nact_command', 'me looks at the gauges:');

# os detection
my $os = `uname`;
if ($os =~ /Linux/) {
	Irssi::print("nact.pl, running on Linux, using /proc/net/dev");
	$getBytes = \&getBytesLinux;
	Irssi::settings_add_str('misc', 'nact_devices', "eth0 lo");
} elsif ($os =~ /OpenBSD/) {
	Irssi::print("nact.pl, running on OpenBSD, using netstat -nbi");
	$getBytes = \&getBytesOBSD;
	Irssi::settings_add_str('misc', 'nact_devices', "tun0");
} elsif ($os =~ /FreeBSD/) {
  Irssi::print("nact.pl, running on FreeBSD, using netstat -nbi");
  $getBytes = \&getBytesFBSD;
  Irssi::settings_add_str('misc', 'nact_devices', "rl0");
} else {
	Irssi::print("nact.pl, sorry no support for OS:$os");
	Irssi::print("nact.pl, If you know how to collect the needed data on your OS, mail me :)");
	$os = "";
}

if ($os ne "") {
	&$getBytes();
	nact_setup();
}

################
###
# Changelog
#
# Version 0.2.5
#  - added nact_command
#  - added /bw
#
# Version 0.2.4
#  - added FreeBSD support (by senneth)
#
# Version 0.2.3
#  - stray ' ' in the item (reported by darix). Add a " " at the end of your
#      nact_display if you have more than one interface listed.
#
# Version 0.2.2
#  - added missing use Irssi::TextUI (reported by darix)
#  - small parameter switch bug (reported by darix)
#
# Version 0.2.1
#  - added total number of bytes sent/received
#  
# Version 0.2.0
#  - runs now from autorun/ on openbsd
#  - changed nact_interval to mili-seconds
#  - added nact_format, nact_unit
#
# Version 0.1.2
#  - small typo in the docs
#
# Version 0.1.1
#  - introduced multiple os support
#  - added a theme thingie to make sascha happy ;)
#
# Version 0.1.0
#  - initial release
#
###
################
