# irssiBlaster 1.6
# Copyright (C) 2003 legion
# 
# "Now Playing" (mp3blaster) in Irssi and more.
# 
# - mp3blaster (http://www.stack.nl/~brama/mp3blaster.html)
# - irssi (http://irssi.org)
# for /npsend (EXPERIMENTAL):
# - lsof (ftp://vic.cc.purdue.edu/pub/tools/unix/lsof/)
#
# NOTE: these applications are available in any linux distribution.
# 
# should work with any version (i'm using irssi 0.8.8 & mp3blaster 3.2.0)
# bug reports,features requests or comments -> a.lepore@email.it
#
# License:
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or any later version. www.gnu.org
#
#################################################################################
# *** USAGE:
# 
# /np			: display the "Artist - Song" played in current window,
# 			  any argument is printed after the song name (i.e. you own comment).
#
# /npa			: like /np, but prints "Artist - Album [Year]".
# 			  If there isn't an appropriate album tag,print nothing.
# 			  
# /anp			: /np in all channels.
#
# /anpa			: /npa in all channels.
#
# /npinfo		: display all available info for the current file.
#
# /cleanbar		: clean the statubar item (until the next song).
# 
# /npsend NICK		: *EXPERIMENTAL* (irssi often CRASH)
# 			  send the current played file to NICK user.
# 			  maybe it will be usable in version 2.0.
# 			  
# 
# *** SETTINGS:
#
# blaster_bar ON/OFF		: statusbar item activation.
# 				  ATTENTION:
# 				  you also have to add the item 'blaster' to your statusbar.
# 				  see: http://irssi.org/?page=docs&doc=startup-HOWTO#c12
# 				  example:
# 				  /statusbar window add -priority "-10" -alignment right blaster
#
# blaster_infos_path FILE	: the file with infos (mp3blaster -f FILE).
# 				  default is ~/.infoz
# 				  
# blaster_bar_prefix STRING	: the bar prefix to filename. default is "playing:"
# 
# blaster_prefix		: the /np prefix to filename. default is "np:"
# 
#################################################################################
# Changelog:
#
# 1.6:
# - /npinfo.
# - /cleanbar.
# - /anpa.
# - /npa.
# - help fixes. $infofile is now /tmp/irssiblaster.
# - /npsend (EXPERIMENTAL).
# - /np [comment].
# - /anp.
# - BUGFIX: no spaces at the end of the filenames.
# - added code comments.
# - prefixes can be changed.
# - statusbar realtime print.
# - 'mp3blaster_infos_path' is now 'blaster_infos_path'.
# 
# 1.0:
# - initial release.
#
# TODO:
# - working /npsend
# - (automatic) /cleanbar
# - support for others stuff (album,time..)
# - /help
# - use strict;
#################################################################################

#use strict;
use Irssi;
use Irssi::TextUI;
use vars qw($VERSION %IRSSI);

$VERSION = '1.6';
%IRSSI = (
	authors		=> 'legion',
	contact		=> 'a.lepore@email.it',
	name		=> 'irssiBlaster',
	description	=> 'Display the song played by mp3blaster in channels and statusbar. See the top of the file for usage.',
	license		=> 'GNU GPLv2 or later',
	changed		=> 'Fri Oct 31 12:22:08 CET 2003',
);



sub get_info {

	my $infofile = Irssi::settings_get_str('blaster_infos_path');
	open (FILE, $infofile); # open and read file with infos
	@all = <FILE>;
	close (FILE);

	@artist = grep (/^artist/, @all); # get the lines with tag infos
	@title = grep (/^title/, @all);
	@album = grep (/^album/, @all);
	@year = grep (/^year/, @all);
	@name = grep (/^path/, @all);     # get the line with filename

} ##

sub get_allinfo {

	my $infofile = Irssi::settings_get_str('blaster_infos_path');
	open (FILE, $infofile);
	@all = <FILE>;
	close (FILE);

	@name = grep (/^path/, @all);
	$name = $name[0];
	$name =~ s/^path //;
	chomp $name;
	@status = grep (/^status/, @all);
	$status = $status[0];
	$status =~ s/^status //;
	chomp $status;
	@artist = grep (/^artist/, @all);
	$artist = $artist[0];
	$artist =~ s/^artist //;
	chomp $artist;
	@title = grep (/^title/, @all);
	$title = $title[0];
	$title =~ s/^title //;
	chomp $title;
	@album = grep (/^album/, @all);
	$album = $album[0];
	$album =~ s/^album //;
	chomp $album;
	@year = grep (/^year/, @all);
	$year = $year[0];
	$year =~ s/^year //;
	chomp $year;
	@comment = grep (/^comment/, @all);
	$comment = $comment[0];
	$comment =~ s/^comment //;
	chomp $comment;
	@mode = grep (/^mode/, @all);
	$mode = $mode[0];
	$mode =~ s/^mode //;
	chomp $mode;
	@format = grep (/^format/, @all);
	$format = $format[0];
	$format =~ s/^format //;
	chomp $format;
	@bitrate = grep (/^bitrate/, @all);
	$bitrate = $bitrate[0];
	$bitrate =~ s/^bitrate //;
	chomp $bitrate;
	@samplerate = grep (/^samplerate/, @all);
	$samplerate = $samplerate[0];
	$samplerate =~ s/^samplerate //;
	chomp $samplerate;
	@length = grep (/^length/, @all);
	$length = $length[0];
	$length =~ s/^length //;
	chomp $length;
	@next = grep (/^next/, @all);
	$next = $next[0];
	$next =~ s/^next //;
	chomp $next;

} ##

sub get_status {

	my $infofile = Irssi::settings_get_str('blaster_infos_path');
	open (FILE, $infofile);
	@all = <FILE>;
	close (FILE);

	@status = grep (/^status/, @all);
} ##

sub get_tag_info {

	$artist = $artist[0]; # is an one-element array
	$artist =~ s/^artist //; # remove prefixes
	chomp $artist;           # remove last char (for correct printing)
	$title = $title[0];
	$title =~ s/^title //;
	chomp $title;
	$album = $album[0];
	$album =~ s/^album //;
	chomp $album;
	$year = $year[0];
	$year =~ s/^year //;
	chomp $year;

	$prefix = Irssi::settings_get_str('blaster_prefix');
	$barprefix = Irssi::settings_get_str('blaster_bar_prefix');

} ##

sub get_name_info {

	$name = $name[0];
	$name =~ s/^path //;  # remove prefix
	$name =~ s/\.mp3$//i; # remove extensions
	$name =~ s/\.ogg$//i;
	$name =~ s/_/ /g;     # change underscores to spaces
	chomp $name;

	$prefix = Irssi::settings_get_str('blaster_prefix');
	$barprefix = Irssi::settings_get_str('blaster_bar_prefix');

} ##

sub noinfo_error {

	my $infofile = Irssi::settings_get_str('blaster_infos_path');
	# print help if the info file is not valid
	Irssi::print(
	"%9IrssiBlaster:%_ \"$infofile\" is not a valid info file. %9Make sure%_ %Rmp3blaster -f $infofile%n %9is running!!!%_\n".
	"%9IrssiBlaster:%_ (Hint: put %9alias mp3blaster='mp3blaster -f $infofile'%_ in your ~/.bashrc )"
	, MSGLEVEL_CRAP);

} ##




sub cmd_np { # /np stuff

get_info;

if (@artist && @title) { # if file has a an id3tag

	get_tag_info;
	
	my ($comment, $server, $witem) = @_; # np: blabla in current window (copied from other scripts..)
	if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {
		$witem->command("me $prefix $artist - $title $comment");
	}
	else {
		Irssi::print("$prefix $artist - $title $comment", MSGLEVEL_CRAP); # or print in client level if no active channel/query
	}
}

elsif (@name) { # if there isn't id3tag we use the filename

	get_name_info;
	
	my ($comment, $server, $witem) = @_;
	if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {
		$witem->command("me $prefix $name $comment");
	}
	else {
		Irssi::print("$prefix $name $comment", MSGLEVEL_CRAP);
	}
}
	
else { noinfo_error; }

} ##

sub cmd_npall { # /anp stuff

get_info;

if (@artist && @title) {

	get_tag_info;

	my ($comment, $server, $witem) = @_;
	Irssi::command("foreach channel /me $prefix $artist - $title $comment");
}

elsif (@name) {
	
	get_name_info;

	my ($comment, $server, $witem) = @_;
	Irssi::command("foreach channel /me $prefix $name $comment");
}

else { noinfo_error; }

} ##

sub cmd_npalbum { # /npa stuff

if (@artist && @album) {
		
	get_tag_info;

	if ($year) { $year = "[$year]"; }

	my ($comment, $server, $witem) = @_;
	if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {
		$witem->command("me $prefix $artist - $album $year $comment");
	}
	else {
		Irssi::print("$prefix $artist - $album $year $comment", MSGLEVEL_CRAP);
	}
}
else {
	Irssi::print("%9IrssiBlaster:%_ filename has no album tag.", MSGLEVEL_CRAP);
}
} ##

sub cmd_npalbumall { # /anpa stuff

get_info;

if (@artist && @album) {

	get_tag_info;

	if ($year) { $year = "[$year]"; }

	my ($comment, $server, $witem) = @_;
	Irssi::command("foreach channel /me $prefix $artist - $album $year $comment");
}
else {
        Irssi::print("%9IrssiBlaster:%_ filename has no album tag.", MSGLEVEL_CRAP);
}
} ##

sub cmd_info {

get_allinfo;

$tot = $length/60; # calculating minutes:seconds
@tot = split(/\./, $tot);
$min = $tot[0];
$sec = $min*60;
$secs = $length-$sec;

Irssi::print("\n%9IrssiBlaster - File Info:%_", MSGLEVEL_CRAP);
Irssi::print("%9F%_ile%9:%_ $name", MSGLEVEL_CRAP);
Irssi::print("%9S%_tatus%9:%_ $status", MSGLEVEL_CRAP);
if ($artist) { Irssi::print("%9A%_rtist%9:%_ $artist", MSGLEVEL_CRAP); }
if ($title) { Irssi::print("%9T%_itle%9:%_ $title", MSGLEVEL_CRAP); }
if ($album) { Irssi::print("%9A%_lbum%9:%_ $album", MSGLEVEL_CRAP); }
if ($year) { Irssi::print("%9Y%_ear%9:%_ $year", MSGLEVEL_CRAP); }
if ($comment) { Irssi::print("%9C%_omment%9:%_ $comment", MSGLEVEL_CRAP); }
Irssi::print("%9-%_----------%9-%_", MSGLEVEL_CRAP);
if ($secs =~ /^.{1}$/) { Irssi::print("%9L%_ength%9:%_ $min\:0$secs", MSGLEVEL_CRAP); }
else { Irssi::print("%9L%_ength%9:%_ $min\:$secs", MSGLEVEL_CRAP); }
if ($format =~ /0$/) { Irssi::print("%9F%_iletype%9:%_ $format (Ogg/Vorbis?)", MSGLEVEL_CRAP); }
else { Irssi::print("%9F%_iletype%9:%_ $format", MSGLEVEL_CRAP); }
Irssi::print("%9R%_ate%9:%_ $bitrate\kb/$samplerate\Khz", MSGLEVEL_CRAP);
if ($mode) { Irssi::print("%9M%_ode%9:%_ $mode", MSGLEVEL_CRAP); }
if ($next) { Irssi::print("%9N%_ext in playlist%9:%_ $next", MSGLEVEL_CRAP); }

} ##

#######################################################################################

sub bar_np { # statusbar stuff

my ($item, $get_size_only) = @_;

my $bar_activation = Irssi::settings_get_str('blaster_bar');
if ($bar_activation =~ /^on$/i) { # display in bar only if /set blaster_bar = ON

get_info;

if (@artist && @title) {

	get_tag_info;
	
	# print in statusbar
	$item->default_handler($get_size_only, "{sb $barprefix $artist - $title}", undef, 1);
}

elsif (@name) {

	get_name_info;
	
	$item->default_handler($get_size_only, "{sb $barprefix $name}", undef, 1);
}

else { 
	$item->default_handler($get_size_only, undef, undef, 1);
}
}
} ##

sub refresh {
	Irssi::statusbar_items_redraw('blaster'); # refresh statusbar
	Irssi::statusbars_recreate_items();
} ##

sub cmd_cleanbar { # /cleanbar stuff

my $infofile = Irssi::settings_get_str('blaster_infos_path');
unlink $infofile;

} ##

sub cmd_send { # /npsend stuff

	get_info;

	my @name = grep (/^path/, @all);
	my $name = $name[0];
	$name =~ s/path //;
	chomp $name;

	# get the full path of the file from 'lsof' (i have lsof 4.64)
	my @open_files = grep (/$name$/, `lsof -c mp3blaste -F n`);
	$open_files[0] =~ s/^n//;
	my $filename = $open_files[0];
	chomp $filename;

	my ($target, $server, $witem) = @_;
	$server->command("DCC SEND $target \"$filename\""); # /dcc send

} ##


Irssi::settings_add_str('irssiBlaster', 'blaster_infos_path', '/tmp/irssiblaster'); # register settings
Irssi::settings_add_str('irssiBlaster', 'blaster_prefix', 'np:');
Irssi::settings_add_str('irssiBlaster', 'blaster_bar_prefix', 'playing:');
Irssi::settings_add_str('irssiBlaster', 'blaster_bar', 'OFF');
Irssi::command_bind('np', 'cmd_np'); # register /commands
Irssi::command_bind('anp', 'cmd_npall');
Irssi::command_bind('npa', 'cmd_npalbum');
Irssi::command_bind('anpa', 'cmd_npalbumall');
Irssi::command_bind('npinfo', 'cmd_info');
Irssi::command_bind('cleanbar', 'cmd_cleanbar');
Irssi::command_bind('npsend', 'cmd_send');
Irssi::statusbar_item_register('blaster', undef, 'bar_np'); # register statusbar item
Irssi::timeout_add(1000, 'refresh', undef); # refresh every 1 second
