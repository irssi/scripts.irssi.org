###
#
# binary_time.pl
#
# Description: 
# This script prints the timestamp in binary as follows:
# 09:25 would be 01001:011001
# 23:49 would be 10111:110001
#
# Bugs:
# If there are any bugs, please email me at aaron.toponce@gmail.com, and I'll get to them as I can.
# Please provide the irrsi version that you are using when the bug occurred, as well as a thorough
# description of how you noticed the bug.  This means providing details of other scripts that you
# are using including themes.  Please be as detailed as possible.  It is my attempt to recreate the
# bug.  I make no assurance that I will fix the bug, but I will make my best attempt at locating it.
#
# Contact:
# 	IRC:    #irssi on freenode
# 	Email:  aaron.toponce@gmail.com
#	Jabber: aaron.toponce@gmail.com 
#
# Change release:
#	- 20060826 : Initial release
###

use Irssi;
use strict;

use vars qw($VERSION %IRSSI);

$VERSION="20060826";
%IRSSI = (
	authors		=> 'Aaron Toponce, Knut Auvor Grythe',
	contact		=> 'aaron.toponce@gmail.com, irssi@auvor.no',
	name		=> 'binary_time',
	description	=> 'Prints the timestamp in binary format',
	license		=> 'GPL',
);

my $old_timestamp_format = Irssi::settings_get_str('timestamp_format');

sub hour2bin {
	my $str = unpack("B32", pack("N", shift));
	$str =~ s/^0{27}(?=\d)//;   # remove unecessary leading zeros (we only need 5 digits for the hour)
	return $str;
}

sub min2bin {
	my $str = unpack("B32", pack("N", shift));
	$str =~ s/^0{26}(?=\d)//;   # remove unecessary leading zeros (we only need 6 digits for the minute)
	return $str;
}

sub convert_to_binary
{
	# Get the hour and minute from the localtime on the users machine.
	my $hour = (localtime)[2];
	my $minute = (localtime)[1];
	
	my $new_time = hour2bin($hour) . "." . min2bin($minute);
	Irssi::command("^set timestamp_format $new_time");
}

sub script_unload {
	my ($script,$server,$witem) = @_;
	Irssi::command("^set timestamp_format $old_timestamp_format");
}

Irssi::timeout_add(1000, 'convert_to_binary', undef);
Irssi::signal_add_first('command script unload', 'script_unload');
