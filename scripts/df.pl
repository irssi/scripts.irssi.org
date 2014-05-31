use Irssi;
use Irssi::TextUI;
use strict;

use vars qw($VERSION %IRSSI);

$VERSION="0.1.0";
%IRSSI = (
	authors=> 'Jochem Meyers',
	contact=> 'jochem.meyers@gmail.com',
	name=> 'df',
	description=> 'Adds an item which displays the current disk usage.',
	license=> 'GPL v2 or later',
	url=> 'http://kaede.kicks-ass.net/irssi.html',
);

#########
# INFO
###
#
#  Type this to add the item:
#
#    /statusbar window add df
#
#  See
#  
#    /help statusbar
#
#  for more help on how to custimize your statusbar.
#
#  If you want to change the way the item looks, browse down to where it reads
#
#  $output .= ' [' . $device . ': A: ' . $avail{$device} . ' U%%: ' . $use{$device} . ']';
#
#  and add or remove any of the following:
#  $size{$device} is the total size of the drive
#  $used{$device} is the total amount of used space
#  $avail{$device} is the amount of available space
#  $use{$device} is the percentage of space used
#  $mount{$device} is the mount point
#
#  Next version, if I ever get around to making one, will have an easier system of changing the 
#  way the statusbar item looks.
#
#  There's a command defined, /dfupdate, which will instantly update the statusbar item. If you
#  want this information printed in the statuswindow, use /exec df -h in any window :).
#
############
# OPTIONS
######
#
#  The irssi command /set can be used to change these settings (more to follow):
#  * df_refresh_time (default: 60)
#      The number of seconds between updates.
#
###
#########
# TODO
###
#
#  - Add format support so the display is more easily customizable.
#  - Add a list of devices to display.
#  - Add a setting that'll let user define the switches to pass to df?
#
#########

#definte variables
my $output;
my ($df_refresh_tag);
my $sbitem;
my (%size, %used, %avail, %use, %mount);

#get information about the harddrives
sub getDiskInfo()
{
	my @list;
	my $skip_line_one = 1;

	open(FID, "/bin/df -h|");
	while (<FID>)
	{
		if ($skip_line_one > 0)
		{
			$skip_line_one--;
			next;
		}
		my $line = $_;
		$line =~ s/[\s:]/ /g;
		@list = split(" ", $line);
		$list[0] =~ s/\/dev\///g;
		$size{$list[0]} = $list[1];
		$used{$list[0]} = $list[2];
		$avail{$list[0]} = $list[3];
		$use{$list[0]} = $list[4];
		$mount{$list[0]} = $list[5];
		$skip_line_one--;
		if ($skip_line_one < -100) {
			Irssi::print("More than 100 drives, this can't be.");
			return;
		}
	}
	close(FID);
}

#called by irssi to get the statusbar item
sub sb_df()
{
	my ($item, $get_size_only) = @_;
	$item->default_handler($get_size_only, "{sb $sbitem}", undef, 1);
}

sub test()
{
	refresh_df();
}
#refresh the statusbar item
sub refresh_df()
{
	getDiskInfo();
	$output = "";
	$sbitem = "";
	my @devices = keys(%size);
	my $device;
	foreach $device (@devices)
	{
		$output .= ' [' . $device . ': A: ' . $avail{$device} . ' U%%: ' . $use{$device} . ']';
	}
	$sbitem = 'DF' . $output;
	Irssi::statusbar_items_redraw('df');
	if ($df_refresh_tag)
	{
		Irssi::timeout_remove($df_refresh_tag)
	}
	my $time = Irssi::settings_get_int('df_refresh_time');
	$df_refresh_tag = Irssi::timeout_add($time*1000, 'refresh_df', undef);
}

#register the statusbar item
Irssi::statusbar_item_register('df', undef, 'sb_df');

#add settings
Irssi::settings_add_int('misc', 'df_refresh_time', 60);

Irssi::command_bind('dfupdate','test');

#run refresh_df() once so sbitem has a value
refresh_df();

################
###
# Changelog
# Version 0.1.0
#  - initial release
#
###
################
