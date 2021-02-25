#/usr/bin/perl -w
########################################################################
#
# iMPD - irssi MPD controller
# Copyright (C) 2004 Shawn Fogle (starz@antisocial.com)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
########################################################################
#
# iMPD - irssi MPD
#
# Requirements: mpc, mpd (http://musicpd.org) 
#
# Please report b00gs to http://www.musicpd.org/forum/viewtopic.php?t=19
# Get the latest and greatest from pulling the module at musicpd's 
# SVN (module iMPD).
#
# OK, This is the a script for irssi/mpc/mpd for people who want to 
# control mpd from irssi. It's very bloated, and featureful, but this
# is a good thing because it's just a perl script and you really don't 
# ever need to use anything that's in here that doesn't pertain to you.
# If you need it (or want it) it's most likely in here. 
#
# I am up for suggestions, alot of this may not work for you, and
# I will not fix it unless you tell me about it.
#
# I do not believe in backwards compatibility if that means it gets in 
# the way of development, so this is probably needs the latest and 
# greatest due to changes in mpc/mpd.
#
########################################################################
#                           Changes
########################################################################
#          
#  0.0.0m->0.0.0n
#
#  - Added Move / Crossfade
#
#  - Fixed problems with finding mpc if it's in your path.
#
#  - Began work on AddNext (Adding next in the queue, unless it's on
#    random or shuffle, don't know if it will ever be added but this
#    release needs to make it out soon to fix path b00g.
#
#  - Finally attached the GPL to make this fully GPLv2 compatible
#
########################################################################
#           Buglist / Wishlist / Todo (In no particular order)
########################################################################
#
# - Have to be able to tell if MPD goes down, so it can gracefully 
#   shutdown the statusbar, so it doesn't try and access mpc every
#   5 seconds (gets even worse if mpdbar_refresh is faster than 
#   default). This will more than likely be fixed by the MPD module.
#   Note to self: Script unloading self leads to _bad_problems ;p
#
# - Update issues will go away in 0.11.0 (see musicpd.org) due to 
#   update being non-blocking from there on out (hopefully ;p)
#
########################################################################
# You don't need to edit below this unless you know what you're doing :)
########################################################################

use File::Basename;
use Irssi;
use Irssi::TextUI;
use strict;
use vars qw($VERSION %ENABLED %SAVE_VARS %IRSSI %COUNT %SET);

$VERSION = '0.0.0o';
%IRSSI = (
	  authors     => 'Santabutthead',
	  contact     => 'starz@antisocial.com',
	  name        => 'iMPD',
	  description => 'This controls Music Player Daemon from the familiar irssi interface',
	  sbitems     => 'mpdbar',
	  license     => 'GPL v2',
	  url         => 'http://www.musicpd.org'
	  );

# Create $SET{'mpc_override'}="/outside/path" if mpc's not in your path

### DO NOT EDIT THESE! Use /set mpd_host /set mpd_port ### 

$SET{'port'} = "2100";
$SET{'host'} = "127.0.0.1";

### Let's go ahead and set this up, so irssi doesn't have a tantrum ###

Irssi::signal_add('setup changed' => \&read_settings);
Irssi::settings_add_bool('misc', 'mpdbar_bottom', 0);
Irssi::settings_add_bool('misc', 'mpdbar_top', 0);
Irssi::settings_add_bool('misc', 'mpdbar_window', 0);
Irssi::settings_add_bool('misc', 'current_window', '0');
Irssi::settings_add_int('misc', 'output_window', '1');
Irssi::settings_add_int('misc', 'mpd_port', '2100');
Irssi::settings_add_str('misc', 'mpd_host', '127.0.0.1');
Irssi::signal_add_first('command script unload', \&cleanup);
Irssi::signal_add_first('command script load', \&cleanup);
Irssi::signal_add('setup changed' => \&mpdbar_refresh);
# Keep the $2- to treat spaces right
Irssi::statusbar_item_register('mpdbar', '{sb $0 $1 $2-}', 'mpdbar_setup');
Irssi::statusbars_recreate_items();

#######################################################################

print "For usage information on iMPD type /mhelp";

sub add { 
    if ($_[0]) {
	&read_settings;
	my $j;
	&current_window;
	if ($_[0] =~ /^album\s/ or $_[0]=~ /^filename\s/ or $_[0]=~ /^title\s/ or $_[0]=~ /^artist\s/ ) {
	    my @i = split / /, $_[0];
	    $j = $i[0];
	    $_[0] =~ s/^(\w+)\s//;
	} else { 
	    $j = "filename";
	}
	Irssi::command( "$SET{'intrairssi'} search $j \Q$_[0]\E | $SET{'intrashell'} add" );    
	&set_active;
    } else {
	print "%W/madd (album|artist|filename|title) {search term} {search term}..%w";
	print " - Search for {search term} and automagically add it to the end of the queue";
	print " - This command does not support play number. (it doesn't make sense)";
	print " - If not specified it will use filename by default";
    }
}

sub addall {
    &read_settings;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} add \"\"" );
    &set_active;
}

sub addallPlay {
    &read_settings;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} add \"\" && $SET{'intrashell'} play" );
    &mpdbar_refresh; # Impatience
    &set_active;
}

sub addallShufflePlay {
    &read_settings;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} add \"\" && $SET{'intrashell'} shuffle && $SET{'intrashell'} play" );
    &mpdbar_refresh; # Impatience
    &set_active;
}

sub addNext {  # This does not work yet, but doesn't hurt being here until it does :)
    if ($_[0]) {
	&read_settings;
	my $j;
	&current_window;
	&song_count;
	if ($_[0] =~ /^album\s/ or $_[0]=~ /^filename\s/ or $_[0]=~ /^title\s/ or $_[0]=~ /^artist\s/ ) {
	    my @i = split / /, $_[0];
	    $j = $i[0];
	    $_[0] =~ s/^(\w+)\s//;
	} else { 
	    $j = "filename";
	}
	Irssi::command( "$SET{'intrairssi'} search $j \Q$_[0]\E | $SET{'intrashell'} add" );    
	my $new_pos =~ $COUNT{'song'}++;
	my $playcount =~ $COUNT{'playlist'}++;
	Irssi::command( "$SET{'intrairssi'} mpc $playcount $new_pos");
	#random detect stuff here;
	&set_active;
    } else {
	print "%W/maddnext (album|artist|filename|title) {search term} {search term}..%w";
	print " - Search for {search term} and automagically add it to the next position in";
        print " - the queue. This command does not support play number. (it doesn't make sense)";
	print " - If not specified it will use filename by default";
    }
}

sub addPlay { 
    if ($_[0]) {
	&read_settings;
	my $j;
	&current_window;
	if ($_[0]=~ /^album\s/ or $_[0]=~ /^filename\s/ or $_[0]=~ /^title\s/ or $_[0]=~ /^artist\s/ ) {
	    my @i = split / /, $_[0];
	    $j = $i[0];
	    $_[0] =~ s/^(\w+)\s//;
	} else { 
	    $j = "filename";
	}
	Irssi::command( "$SET{'intrairssi'} search $j \Q$_[0]\E | $SET{'intrashell'} add && $SET{'intrashell'} play" );
	&mpdbar_refresh; # Impatience
	&set_active;
    } else {
	print "%W/map (add play) (album|artist|filename|title) {search term} {search term}..%w";
	print " - Search for {search term} and automagically add it to the end of the queue";
	print " - This command does not support play number. (it doesn't make sense)";
	print " - If not specified it will use filename by default";
    }
}

sub addShuffle { 
    if ($_[0]) {
	&read_settings;
	my $j;
	&current_window;
	if ($_[0] =~ /^album\s/ or $_[0]=~ /^filename\s/ or $_[0]=~ /^title\s/ or $_[0]=~ /^artist\s/ ) {
	    my @i = split / /, $_[0];
	    $j = $i[0];
	    $_[0] =~ s/^(\w+)\s//;
	} else { 
	    $j = "filename";
	}
	Irssi::command( "$SET{'intrairssi'} search $j \Q$_[0]\E | $SET{'intrashell'} add && $SET{'intrashell'} shuffle" );
	&set_active;
    } else {
	print "%W/mas (add shuffle) (album|artist|filename|title) {search term} {search term}..%w";
	print " - Search for {search term} and automagically add it to the end of the queue";
	print " - This command does not support play number. (it doesn't make sense)";
	print " - If not specified it will use filename by default";
    }
}

sub addShufflePlay { 
    if ($_[0]) {
	&read_settings;
	my $j;
	&current_window;
	if ($_[0] =~ /^album\s/ or $_[0]=~ /^filename\s/ or $_[0]=~ /^title\s/ or $_[0]=~ /^artist\s/ ) {
	    my @i = split / /, $_[0];
	    $j = $i[0];
	    $_[0] =~ s/^(\w+)\s//;
	} else { 
	    $j = "filename";
	}
	Irssi::command( "$SET{'intrairssi'} search $j \Q$_[0]\E | $SET{'intrashell'} add && $SET{'intrashell'} shuffle && $SET{'intrashell'} play" );
	&mpdbar_refresh; # Impatience
	&set_active;
    } else {
	print "%W/masp (add shuffle play) (album|artist|filename|title) {search term} {search term}..%w";
	print " - Search for {search term} and automagically add it to the end of the queue";
	print " - This command does not support play number. (it doesn't make sense)";
	print " - If not specified it will use filename by default";
    }
}


sub cleanup {
    my ($file) = Irssi::get_irssi_dir."/iMPD.conf";

    open CONF, ">", $file;
    for my $net (sort keys %SAVE_VARS) {
	print CONF "$net\t$SAVE_VARS{$net}\n";
	close CONF;
    }
    Irssi::command( "statusbar mpdbar disable" );
  }
 
sub clear {
    &read_settings;
    &current_window;    
    Irssi::command( "$SET{'intrairssi'} clear" );
    &mpdbar_refresh; # Impatience
    &set_active;
}

sub clearAddAllPlay {
    &read_settings;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} clear && $SET{'intrashell'} add \"\" && $SET{'intrashell'} play" );
    &mpdbar_refresh; # Impatience
    &set_active;
}

sub clearAddAllShufflePlay {
    &read_settings;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} clear && $SET{'intrashell'} add \"\" && $SET{'intrashell'} shuffle && $SET{'intrashell'} play" );
    &mpdbar_refresh; # Impatience
    &set_active;
}

sub clearAddPlay { 
    if ($_[0]) {
	&read_settings;
	my $j;
	&current_window;
	if ($_[0] =~ /^album\s/ or $_[0]=~ /^filename\s/ or $_[0]=~ /^title\s/ or $_[0]=~ /^artist\s/ ) {
	    my @i = split / /, $_[0];
	    $j = $i[0];
	    $_[0] =~ s/^(\w+)\s//;
	} else { 
	    $j = "filename";
	}
	Irssi::command( "$SET{'intrairssi'} clear && $SET{'intrashell'} search $j \Q$_[0]\E | $SET{'intrashell'} add && $SET{'intrashell'} play" );
	&mpdbar_refresh; # Impatience
	&set_active;
    } else {
	print "%W/mcap (clear add play) (album|artist|filename|title) {search term} {search term}..%w";
	print " - Search for {search term} and automagically add it to the end of the queue";
	print " - This command does not support play number. (it doesn't make sense)";
	print " - If not specified it will use filename by default";
    }
}

sub clearAddShufflePlay { 
    if ($_[0]) {
	&read_settings;
	my $j;
	&current_window;
	if ($_[0] =~ /^album\s/ or $_[0]=~ /^filename\s/ or $_[0]=~ /^title\s/ or $_[0]=~ /^artist\s/ ) {
	    my @i = split / /, $_[0];
	    $j = $i[0];
	    $_[0] =~ s/^(\w+)\s//;
	} else { 
	    $j = "filename";
	}
	Irssi::command( "$SET{'intrairssi'} clear && $SET{'intrashell'} search $j \Q$_[0]\E | $SET{'intrashell'} add && $SET{'intrashell'} shuffle && $SET{'intrashell'} play" );
	&mpdbar_refresh; # Impatience
	&set_active;
    } else {
	print "%W/mcasp (clear add shuffle play) (album|artist|filename|title) {search term} {search term}..%w";
	print " - Search for {search term} and automagically add it to the end of the queue";
	print " - This command does not support play number. (it doesn't make sense)";
	print " - If not specified it will use filename by default";
    }
}

sub clearback {
    &read_settings;
    &song_count;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} del $COUNT{'sr1'}" );
    &set_active;
}

sub crossfade {
    &read_settings;
    if ($_[0] =~ m/\d{1,4}/) {
	&current_window;
	Irssi::command( "$SET{'intrairssi'} crossfade $_[0]" );
	&mpdbar_refresh; # Impatience
	&set_active;
    } else {
	print "%W/mcrossfade <num> %w- Number of seconds to crossfade between songs";
    }
}

sub current_status{
    &read_settings;
    &current_window;
    my $i = `$SET{'intrashell'}`;
    chomp($i);
    $SET{'active'}->print( $i );
    &set_active;
    return;
}

sub current_window {
    $SET{'active'} = Irssi::active_win();
    if (! $SET{'current'}) {
	Irssi::window_find_refnum($SET{'output'})->set_active;
      }
}

sub delete {
    if($_[0]) {
	my (@i,$j,$k);
	@i = split / /, $_[0]; 
	$j = shift(@i);

	&read_settings;
	&current_window;
	# You may ask why? This is for the future when del (hopefully) has useful output
	$k = "$SET{'intrairssi'} playlist | grep \"$j\" | $SET{'intrashell'} del";
	$_[0] =~ s/^(\w+)\s//; 
	$k = "$k && $SET{'intrashell'} playlist | grep \"$_[0]\" | $SET{'intrashell'} del";
	Irssi::command( "$k" );
	&set_active;
    } else {
	print"%W/mdel {search term} {search term}..%w";
        print" - Search for {search term} and automagically";
	print" - delete it from the queue";
    }
}

sub iMPD_help {
my $mpd_help = <<MPD_HELP;
    %r---=[ %WMusic Control Commands %r]=---%w
    %W/mmute                      %w- Mutes/Unmutes the volume
    %W/mnext                      %w- Starts playing next song on playlist
    %W/mpause                     %w- Pauses playing
    %W/mplay <number>             %w- Starts MPD (with optional number of song 
                                              to start on)
    %W/mprev                      %w- Previous Song
    %W/mstop <minutes> <m|h|d>    %w- Stops the current playlist, 
                                  options are minutes, hours and days, seconds 
                                  are the default
    %W/mupdate                    %w- Update MPD Database
    %W/mvolume <value> (0-100)    %w- Sets the volume on the OSS mixer
                                  to <value> (0-100)

    %r---=[ %WSearch Commands %r]=---%w
    %W/madd (album|artist|filename|title) {search term} {search term} ..%w
                                %w- Search for {search term} and automagically 
                                    add it to the end of the queue, upto 5 search terms
                                - If not specified it will use filename by default
    %W/mdel {search term} {search term} ..%w
                                %w- Search for {search term} and automagically 
                                    delete it from the queue
    %W/msearch (album|artist|filename|title) {search term} {search term}..%w
                                %w- Search for {search term}
                                - If not specified it will use filename by default

    %r---=[ %WNavigation/Playlist Commands %r]=---%w
    %W/maddall                    %w- Add all known music to the playlist
    %W/mclear                     %w- Clear the current playlist
    %W/mclearback                 %w- Clears all songs before the current playing song
    %W/mcrossfade <num>           %w- Number of seconds to crossfade between songs
    %W/mls [<directory>]          %w- Lists all files/folders in <directory>
    %W/mmove <num> <num>          %w- Move song on playlist
    %W/mplaylist <range>          %w- Print entire playlist if there's no range
                                - Otherwise will print the range (i.e. 1-10)
    %W/mplaylistls                %w- List available playlists
    %W/mplaylistload <file>       %w- Load playlist <file>
    %W/mplaylistrm <file>         %w- Remove (delete) playlist <file>
    %W/mplaylistsave <file>       %w- Save playlist <file>
    %W/mpls {search term} {search term}...%w
                                %w- Playlist search {search term}
    %W/mseek <num>                %w- Seeks to the spot specified for the current file, in terms of percent time (0-100)
    %W/mshuffle                   %w- Shuffle the MPD playlist
    %W/mrandom                    %w- Play the playlist randomly 
    %W/mwipe                      %w- Remove all songs but the one currently playing

    %r---=[ %WMiscellaneous Commands %r]=---%w
    %W/mhelp                      %w- This screen
    %W/mloud                      %w- Show everyone in the current window the MPD stats
    %W/mlouder                    %w- Show everyone in the current window the MPD stats
                                      *use with caution*
    %W/minfo                      %w- Show MPD Status in the status window
    %W/mrm <num> <num>..          %w- Remove song from the current playlist (by number 
                                %w- or number range)
 See Also: /mhelpadv
           /mhelpmpdbar
           /set mpd_host mpd_port
           /set mpd_current_window mpd_output_window (EXPERIMENTAL)
MPD_HELP
print $mpd_help;
}

sub iMPD_helpAdv{
my $mpd_help_advanced = <<MPD_HELP_ADVANCED;
    %r---=[ %WCombination Commands %r]=---%w
    These do not take play arguments.
    %W/map {search term} {search term} ..     %w- Add, Play
    %W/maap                                   %w- Addall, Play
    %W/maasp                                  %w- Addall, Shuffle, Play
    %W/mas {search term} {search term} ..     %w- Add, Shuffle
    %W/masp {search term} {search term} ..    %w- Add, Shuffle, Play
    %W/mcap {search term} {search term} ..    %w- Clear, Add, Play
    %W/mcaap                                  %w- Clear, Addall, Play
    %W/mcaasp                                 %w- Clear, Addall, Shuffle, Play
    %W/mcasp {search term} {search term} ..   %w- Clear, Add, Shuffle, Play 
    %W/mwa {search term} {search term} ..     %w- Wipe, Add, 
    %W/mwaa                                   %w- Wipe, Addall
    %W/mwaas                                  %w- Wipe, Addall, Shuffle
    %W/mwas {search term} {search term} ..    %w- Wipe, Add, Shuffle

 See Also: /set mpd_port mpd_host
           /set mpd_current_window mpd_output_window (EXPERIMENTAL)
MPD_HELP_ADVANCED
print $mpd_help_advanced;
}

sub load_settings {
    my ($file) = Irssi::get_irssi_dir."/iMPD.conf";
    
    open CONF, "<", $file;
    while (<CONF>) {
	my($net,$val) = split;
	if ($net && $val) {
	    $SAVE_VARS{$net} = $val;
	}
	close CONF;
    }
}

# For those who want to be loud/annoying :)
sub loud {
    &read_settings;
    my ($i,$j);
    my @split = `$SET{'intrashell'}`;

    if (! $split[1]) {
	Irssi::print( "iMPD is not currently playing" );
	  return;
      }
    
    $i = basename $split[0]; 
    $i =~ s/[_]/ /g;
# Feel free to put your personal PERL regexps here ;p
# Experiment with these to do some wicked stuff to your loud output.
#    $i =~ s/.mp3//ig;
#    $i =~ s/.flac//ig;
#    $i =~ s/.flc//ig;
#    $i =~ s/.ogg//ig;
#    $i =~ s/^\p{0,2}//;
#    $i =~ s/[.]//g;
    $i = substr($i,0,-1);
    
    Irssi::active_win->command( "/me is listening to $i" );
    close Reader;
}

sub louder {
    &read_settings;
    my @split=`$SET{'intrashell'}`;
    chomp(@split);
    Irssi::active_win->command( "/say $split[0]" );
    Irssi::active_win->command( "/say $split[1]" );
    Irssi::active_win->command( "/say $split[2]" );
    close Reader;
}

sub ls {
    if ($_[0]) {
	&read_settings;
	&current_window;
	$_[0] =~ "\Q$_[0]\E";
	$_[0] =~ s/^\\//; # Rid of beginning / it doesn't delimit correctly.
	$_[0] =~ s/\///; # Help out the degenerates.
	Irssi::command( "$SET{'intrairssi'} ls " . "\Q$_[0]\E" );
	&set_active;
    } else {
	print "%W/mls [<directory>] %w- Lists all files/folders in <directory>.";
    }
}

sub lsplaylists {
    &read_settings;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} lsplaylists" );
    &set_active;
}

sub move {
    &read_settings;
    if ($_[0] =~ m/\d{1,2}\s{1,2}/) {
	&current_window;
	Irssi::command( "$SET{'intrairssi'} move $_[0]" );
	&mpdbar_refresh; # Impatience
	&set_active;
    } else {
	print "%W/mmove <num> <num>          %w- Move song on playlist";
    }
}

sub mpdbar_help {
my $mpdbarhelp = <<MPDBAR_HELP;
 mpdbar was made to be a simple way to get your statusbar up and 
 to hide it when it's not playing. If you feel that I'm not being
 flexable enough in my choices you're free to setup a statusbar
 without these commands or present me with an idea for a new
 mpdbar command. But the current ones are:

 /set mpdbar_bottom on -
     This command will (obviously) display a mpdbar on the bottom.

 /set mpdbar_refresh <num> -
     This command will set the refresh in seconds, it defaults to 
     5 seconds, you might be able to set it higher although I don't
     recommend setting it higher if your mpd server is across a 
     network (of any kind ;p).

 /set mpdbar_top on
     This command will (obviously) display a mpdbar on the top.

 /set mpdbar_window on
     This command will (not-so-obviously) display a mpdbar next to your
     current window statusbar.
MPDBAR_HELP
print $mpdbarhelp;
}

sub mpdbar_get_stats {
### Variable map  ###
# $SET{'stat_time'}-Time/Percent(change)
# $SET{'stat_current'}-Status(change)
# $SET{'songbase'}-basename filename
    if(Irssi::settings_get_bool('mpdbar_bottom') or 
       Irssi::settings_get_bool('mpdbar_top') or
       Irssi::settings_get_bool('mpdbar_window')) {
	&read_settings;
		
	($SET{'stat1'},$SET{'stat2'},$SET{'stat3'}) = undef;
	($SET{'stat1'},$SET{'stat2'},$SET{'stat3'}) = `$SET{'intrashell'}`;
	chomp($SET{'stat1'},$SET{'stat2'},$SET{'stat3'});

	if ($SET{'stat2'} =~ m/(\d{1,5}\:\d{1,2}\s\(\d{1,3}\%\))/) {
	    $SET{'stat_time'} = $1;	
	}
	if ($SET{'stat2'} =~ m/\[(\w+)\]/) {
	    $SET{'stat_current'} = $1;
	}
	if($SET{'stat2'} and $SET{'stat1'} =~ m/\//g) { # Not sure if this will have an effect :/
	    $SET{'songbase'} = basename $SET{'stat1'};
	} else {
	    $SET{'songbase'} = $SET{'stat1'};
	}
    }
}
    
sub mpdbar_refresh {    
    if(Irssi::settings_get_bool('mpdbar_bottom') or 
       Irssi::settings_get_bool('mpdbar_top') or
       Irssi::settings_get_bool('mpdbar_window')) {
	&mpdbar_get_stats;
	if (Irssi::settings_get_bool('mpdbar_bottom') and Irssi::settings_get_bool('mpdbar_top')) {
	    Irssi::print( "Have not implemented ability to mpdbar top and bottom at the same time" );
	      Irssi::print( "That's fine though, I'll just set it to the bottom for you for now" );
	      Irssi::settings_set_bool('mpdbar_bottom',1);
	      Irssi::settings_set_bool('mpdbar_top',0);
	  }
	if (Irssi::settings_get_bool('mpdbar_window') and $SET{'stat2'}) {
	    $ENABLED{'window'} = "1";
	    Irssi::command( "statusbar window add mpdbar" );
	    Irssi::command( "statusbar window enable mpdbar" );
	} else {
	    if($ENABLED{'window'} == 1) {
		Irssi::command( "statusbar window remove mpdbar" );
		  $ENABLED{'window'} = 0;
	      }
	}
	if (Irssi::settings_get_bool('mpdbar_bottom') and $SET{'stat2'} and ! $ENABLED{'top'}) {
	    $ENABLED{'bottom'} = "1";
	    Irssi::command( "statusbar mpdbar placement bottom" );
	    Irssi::command( "statusbar mpdbar position 2" );
	    Irssi::command( "statusbar mpdbar enable" );
	    Irssi::command( "statusbar mpdbar add mpdbar" );
	    Irssi::command( "statusbar mpdbar visible active" );
	} else {
	    if($ENABLED{'bottom'} == 1){
		Irssi::command( "statusbar mpdbar remove mpdbar" );
		  Irssi::command( "statusbar mpdbar disable" );
		  $ENABLED{'bottom'} = 0;
	      }
	}
	if (Irssi::settings_get_bool('mpdbar_top') and $SET{'stat2'} and ! $ENABLED{'bottom'}) {
	    $ENABLED{'top'} = "1";
	    Irssi::command( "statusbar mpdbar placement top" );
	    Irssi::command( "statusbar mpdbar position 2" );
	    Irssi::command( "statusbar mpdbar enable" );
	    Irssi::command( "statusbar mpdbar add mpdbar" );
	    Irssi::command( "statusbar mpdbar visible active" );
	} else {
	    if($ENABLED{'top'} == 1){
		Irssi::command( "statusbar mpdbar remove mpdbar" );
		  Irssi::command( "statusbar mpdbar disable" );
		  $ENABLED{'top'} = 0;
	      }     
	}
    }
}

sub mpdbar_setup {	
    my ($item, $get_size_only) = @_;
    if (! $SET{'stat2'}) { # If it's not on
	$item->default_handler($get_size_only, undef, "$SET{'stat2'}", 1);
    } else {
	$SET{'stat_current'} =~ s/$SET{'stat_current'}/\u\L$SET{'stat_current'}/;
	$item->default_handler($get_size_only, undef, "$SET{'stat_current'} $SET{'songbase'} $SET{'stat_time'}", 1);
    }
}

sub mute {
    &read_settings;
    &current_window;

    my @i = `$SET{'intrashell'}`;
    my $j;
    # This next conditional is for when the music is not playing
    if (exists $i[2]) {
	$j = $i[2]; 
    } else {
	$j = $i[0];
    }
    if ($j =~ m/volume\:\s{0,2}(\d{1,3})\%/) {
	$j = $1;
    }

    if ($j != 0 and ! $SAVE_VARS{'muted'} == 0) {
	print "Warning: Not currently muted, although it said it was";
	delete $SAVE_VARS{'muted'}
    }
    if ($j == 0 and ! $SAVE_VARS{'muted'}) {
	print "Error: Volume is currently muted, but I don't know how it got there. Manually set the volume please.";
	delete $SAVE_VARS{'muted'};
    }
    if (!$SAVE_VARS{'muted'}) {
	$SAVE_VARS{'muted'} = $j;
	`$SET{'intrashell'} volume 0`;
	print "Sound is muted, to unmute just hit /mmute again";
    } else {
	`$SET{'intrashell'} volume $SAVE_VARS{'muted'}`;
	print "Reset the volume back to it's originial position ($SAVE_VARS{'muted'}%)";
	delete $SAVE_VARS{'muted'};
    }
}

sub next {
    &read_settings;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} next" );
    &set_active;
    &mpdbar_refresh; # Impatience
}

sub pause {
    &read_settings;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} pause" );
    &mpdbar_refresh; # Impatience
    &set_active;
}

sub play {
    &read_settings;
    my $i;
    &current_window;
    if ($_[0] =~ m/\d{1,6}/) {
	$i = $_[0];
    }
    Irssi::command( "$SET{'intrairssi'} play $i" );
    &mpdbar_refresh; # Impatience
    &set_active;
}

sub playlist {
    &read_settings;
    my @playlist;
    if ($_[0] =~ m/\d{1,6}\-\d{1,6}/) {
	my ($head,$tail);
	my @playlist = `$SET{'intrashell'} playlist`;
	($head, $tail) = split /-/, $_[0]; 

	# OK, just understand I'm here for you if you're 
	# tired enough to let this happen to you.
	if($head > $tail) {
	    my $i;
	    $i = $head;
	    $head = $tail;
	    $tail = $i;
	}

	$head =~ $head--;
	$tail = $tail - $head;
	chomp $head;
	chomp $tail;
	
	@playlist = splice(@playlist,$head,$tail);
	my $i = pop(@playlist);
	chomp $i;
	push (@playlist,$i);
	print @playlist;
    } else {
	&current_window;
	Irssi::command( "$SET{'intrairssi'} playlist" );
	&set_active;
    }
}

sub playlist_load {
    if ($_[0]) {
	&read_settings;
	&current_window;
	Irssi::command( "$SET{'intrairssi'} load \Q$_[0]\E" );
	&set_active;
    } else {
	print "%W/mplaylistload <file> %w- Load playlist <file>";
    }
}

sub playlist_remove {
    if ($_[0]) {
	&read_settings;
	&current_window;
	Irssi::command( "$SET{'intrairssi'} rm \Q$_[0]\E" );
	&set_active;
    }
}

sub playlist_save {
    if ($_[0]) {
	&read_settings;
	&current_window;
	Irssi::command( "$SET{'intrairssi'} save \Q$_[0]\E" );
	&set_active;
    } else {
	print "%W/mplaylistsave <file> %w- Save playlist <file>";
    }
}

sub playlistsearch {
    if ($_[0]) {
	&read_settings;
	my @i = split / /, $_[0];
	&current_window;
	foreach(@i) {
	    Irssi::command( "$SET{'intrairssi'} playlist | grep $_" );
	  }
	&set_active;
    } else {
	print "%W/pls {search term} {search term}..%w";
	print " - Search for {search term} and automagically and show the playlist entry";
    }    
}

sub previous {
    &read_settings;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} prev" );
    &mpdbar_refresh; # Impatience
    &set_active;
}

sub random{
    &read_settings;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} random" );
    &set_active;
}

sub read_settings {    
    ($SET{'mbar_time'}) && Irssi::timeout_remove($SET{'mbar_time'});
    $SET{'mbar_time'}=Irssi::timeout_add(Irssi::settings_get_int('mpdbar_refresh') * 1000, 'mpdbar_refresh', undef);

    $SET{'current'} = Irssi::settings_get_bool('current_window');
    $SET{'output'} = Irssi::settings_get_int('output_window');
    
    if (Irssi::settings_get_int( "mpd_port" )) {
	$SET{'port'} = Irssi::settings_get_int( "mpd_port" );
	$SET{'port'} = "MPD_PORT=$SET{'port'}"
	}
    if (Irssi::settings_get_str( "mpd_host" )) {
	$SET{'host'} = Irssi::settings_get_str( "mpd_host" );
	$SET{'host'} = "MPD_HOST=$SET{'host'}"
    }
    my $MPC_BIN;
    if ( ! -x $SET{'mpc_override'} ) {
	my @paths = split/:/,$ENV{'PATH'};
	
	foreach(@paths) {
	    my $path = $_;
	    if( -x "$path" . "/" . "mpc" ) {
		$MPC_BIN = "$path/mpc";
	    }
	}
    } else {
	$MPC_BIN = $SET{'mpc_override'};
    }

    if (! $MPC_BIN) {
	print "mpc was not found in any of the known paths";
	print "mpc is required to use this script, please download it from http://musicpd.org/files.php";
    }   

    $SET{'intrashell'} = "$SET{'port'} $SET{'host'} $MPC_BIN";
    $SET{'intrairssi'} = "exec - $SET{'intrashell'}";
}

sub repeat {
    &read_settings;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} repeat" );
    &set_active;
}

sub remove_song {
    &read_settings;
    if ($_[0] =~ m/\d{1,6}/ or $_[0] =~ m/\d{1,6}\-\d{1,6}/) {
	&current_window;
	Irssi::command( "$SET{'intrairssi'} del $_[0]" );
	&mpdbar_refresh; # Impatience
	&set_active;
    } else {
	print "%W/mrm <num> <num>.. %w- Remove song from the current playlist (by number)";
	print "%w                   - Note that <num> can be a range also";
    }
}

sub search { 
    if ($_[0]) {
	&read_settings;
	my $j;
	&current_window;
	if ($_[0] =~ /^album\s/ or $_[0]=~ /^filename\s/ or $_[0]=~ /^title\s/ or $_[0]=~ /^artist\s/ ) {
	    my @i = split / /, $_[0];
	    $j = $i[0];
	    $_[0] =~ s/^(\w+)\s//;
	} else { 
	    $j = "filename";
	}
	Irssi::command( "$SET{'intrairssi'} search $j \Q$_[0]\E" );
	&set_active;
    } else {
	print "%W/search (album|artist|filename|title) {search term} {search term}..%w";
	print " - Search for {search term} and automagically add it to the end of the queue";
        print " - If not specified it will use filename by default";
    }
}

sub seek {
    &read_settings;
    if ($_[0] =~ m/\d{1,3}/) {
	&current_window;
	Irssi::command( "$SET{'intrairssi'} seek $_[0]" );
	&mpdbar_refresh; # Impatience
	&set_active;
    } else {
	print "%W/mseek <num> %w- Seeks to the spot specified for the current file, in terms of percent time (0-100)";
    }
}

sub set_active { 
    if (! $SET{'current'}) { 
	$SET{'active'}->set_active; 
    }
}    

sub shuffle{
    &read_settings;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} shuffle" );
    &set_active;
}

sub song_count {
    %COUNT = undef;
    
    my @counts = `$SET{'intrashell'}`;
    chomp(@counts);

    if ($counts[1] =~ m/\#(\d{1,6})\//) {
	$COUNT{'song'} = $1;
    }
    if ($counts[1] =~ m/\/(\d{1,6})\s/) { 
	$COUNT{'playlist'} = $1;
    } 
    if ($COUNT{'song'} > 1) {
	my $i = $COUNT{'song'} - 1;
	$COUNT{'sr1'} = "1-$i";
    }
    if ($COUNT{'song'} < $COUNT{'playlist'}){# and $COUNT{'song'} != $COUNT{'playlist'}) {
	my $i = $COUNT{'song'} + 1;
	$COUNT{'sr2'} = "$i-$COUNT{'playlist'}";
    }
}

sub stop {
    &read_settings;
    my ($i,$time);
    if ($_[0]) {
	my $unit;
	($time, $unit) = split / /, $_[0]; 
	if ($unit =~ /minute/i or $unit =~ /minutes/i) {
	    $time = ($time * 60);
	}
	if ($unit =~ /hour/i or $unit =~ /hours/i) {
	    $time = ($time * 86400);
	}
	#ok. it's ridiculous to use this script for days, but in any case here ya go.
	if ($unit =~ /day/i or $unit =~ /days/i) {
	    $time = ($time * 2073600);
	}
	$time = $time . "s";
	$i = "exec - /bin/sleep $time && $SET{'intrashell'} stop";
    } else {
	$i = "$SET{'intrairssi'} stop";
    }
    &current_window;
    Irssi::command( "$i" );
    &mpdbar_refresh; # Impatience
    &set_active;
}

sub update {
    &read_settings;
    &current_window;
    Irssi::command( "$SET{'intrairssi'} update" );
    Irssi::print( "Irssi will not be accepting commands while updating" );
    &set_active;
}

sub volume {
    &read_settings;
    &current_window;
    my (@i,$j);
    if ($_[0] =~ m/\d{1,3}/) {
	@i = `$SET{'intrashell'} volume $_[0]`;
    } else {
	@i = `$SET{'intrashell'}`;
    }
    # This next conditional is for when the music is not playing
    if (exists $i[2]) {
	$j = $i[2]; 
    } else {
	$j = $i[0];
    }
    if ($j =~ m/volume\:\s{0,2}(\d{1,3})\%/) {
	$j = $1;
    }
    # OK, if anyone wants to tell me _why_ this seems to be the only way
    # to get a "%" on the end please feel free (suspected to be due to
    # color codes
    if ($_[0]) {
	Irssi::print( "The volume is at $j%" . "%" );
    } else {
	$SET{'active'}->print( "The volume is at $j%" . "%" );  
      }
    &set_active;
}

sub wipe {
    &read_settings;
    &current_window;
    &song_count;
    if($COUNT{'sr1'} or $COUNT{'sr2'}) {
	Irssi::command( "$SET{'intrairssi'} del $COUNT{'sr1'} $COUNT{'sr2'}" );
      } else {
	  Irssi::print( "Can't wipe when there's only one song in the playlist" );
	}
    &set_active;
}

sub wipeAdd{
    if ($_[0]) {
	&read_settings;
	&song_count;
	my $j;
	if ($_[0] =~ /^album\s/ or $_[0]=~ /^filename\s/ or $_[0]=~ /^title\s/ or $_[0]=~ /^artist\s/ ) {
	    my @i = split / /, $_[0];
	    $j = $i[0];
	    $_[0] =~ s/^(\w+)\s//;
	} else { 
	    $j = "filename";
	}
	&current_window;
	if($COUNT{'sr1'} or $COUNT{'sr2'}) {
	    Irssi::command( "$SET{'intrairssi'} del $COUNT{'sr1'} $COUNT{'sr2'} && $SET{'intrashell'} search $j \Q$_[0]\E | $SET{'intrashell'} add" );
	  } else { # Do the thinking for the person
	      Irssi::command( "$SET{'intrairssi'} search $j \Q$_[0]\E | $SET{'intrashell'} add" );    
	    }
	&set_active;
    } else {
	print "%W/mwa (wipe add) (album|artist|filename|title) {search term} {search term}..%w";
	print " - Search for {search term} and automagically add it to the end of the queue";
	print " - This command does not support play number. (it doesn't make sense)";
	print " - If not specified it will use filename by default"
	}
}

sub wipeAddall{
    &read_settings;
    &song_count;
    &current_window;
    if($COUNT{'sr1'} or $COUNT{'sr2'}) {
	Irssi::command( "$SET{'intrairssi'} del $COUNT{'sr1'} $COUNT{'sr2'} && $SET{'intrashell'} add \"\"" );
      } else {
	  Irssi::command( "$SET{'intrairssi'} add \"\"" );
	}	  
    &set_active;
}

sub wipeAddallShuffle{
    &read_settings;
    &song_count;
    &current_window;
    if($COUNT{'sr1'} or $COUNT{'sr2'}) {
	Irssi::command( "$SET{'intrairssi'} del $COUNT{'sr1'} $COUNT{'sr2'} && $SET{'intrashell'} add \"\" && $SET{'intrashell'} shuffle" );
      } else {
	Irssi::command( "$SET{'intrairssi'} add \"\" && $SET{'intrashell'} shuffle" );
      }
    &set_active;
}

sub wipeAddShuffle{
    if ($_[0]) {
	&read_settings;
	my $j;
	if ($_[0] =~ /^album\s/ or $_[0]=~ /^filename\s/ or $_[0]=~ /^title\s/ or $_[0]=~ /^artist\s/ ) {
	    my @i = split / /, $_[0];
	    $j = $i[0];
	    $_[0] =~ s/^(\w+)\s//;
	} else { 
	    $j = "filename";
	}
	&song_count;
	&current_window;
	if($COUNT{'sr1'} or $COUNT{'sr2'}) {
	    Irssi::command( "$SET{'intrairssi'} del $COUNT{'sr1'} $COUNT{'sr2'} && $SET{'intrashell'} search $j \Q$_[0]\E | $SET{'intrashell'} add && $SET{'intrashell'} shuffle" );
	  } else {
	      Irssi::command( "$SET{'intrairssi'} search $j \Q$_[0]\E | $SET{'intrashell'} add && $SET{'intrashell'} shuffle" );
	    }
	&set_active;
    } else {
	print "%W/mwas (wipe add shuffle) (album|artist|filename|title) {search term} {search term}..%w";
	print " - Search for {search term} and automagically add it to the end of the queue";
	print " - This command does not support play number. (it doesn't make sense)";
	print " - If not specified it will use filename by default";
	}
}
Irssi::settings_add_int('misc', 'mpdbar_refresh', '5');

&load_settings;
&mpdbar_refresh;

Irssi::command_bind madd => \&add;
Irssi::command_bind maddall => \&addall;
# Irssi::command_bind maddnext => \&addNext;
Irssi::command_bind maap => \&addallPlay;
Irssi::command_bind maasp => \&addallShufflePlay;
Irssi::command_bind mas => \&addShuffle;
Irssi::command_bind masp => \&addShufflePlay;
Irssi::command_bind map => \&addPlay;
Irssi::command_bind mclear => \&clear;
Irssi::command_bind mclearback => \&clearback;
Irssi::command_bind mcaap => \&clearAddAllPlay;
Irssi::command_bind mcaasp => \&clearAddAllShufflePlay;
Irssi::command_bind mcap => \&clearAddPlay;
Irssi::command_bind mcasp => \&clearAddShufflePlay;
Irssi::command_bind mdel => \&delete;
Irssi::command_bind mls => \&ls;
Irssi::command_bind mhelp => \&iMPD_help;
Irssi::command_bind mhelpadv => \&iMPD_helpAdv;
Irssi::command_bind minfo => \&current_status;
Irssi::command_bind mloud => \&loud;
Irssi::command_bind mlouder => \&louder;
Irssi::command_bind mmute => \&mute;
Irssi::command_bind mnext => \&next;
Irssi::command_bind mpause => \&pause;
Irssi::command_bind mhelpmpdbar => \&mpdbar_help;
Irssi::command_bind mmove => \&move;
Irssi::command_bind mplay => \&play;
Irssi::command_bind mplaylist => \&playlist;
Irssi::command_bind mpls => \&playlistsearch;
Irssi::command_bind mplaylistls => \&lsplaylists;
Irssi::command_bind mplaylistload => \&playlist_load;
Irssi::command_bind mplaylistrm => \&playlist_remove;
Irssi::command_bind mplaylistsave => \&playlist_save;
Irssi::command_bind mprev => \&previous;
Irssi::command_bind mrandom => \&random;
Irssi::command_bind mrepeat => \&repeat;
Irssi::command_bind mrm => \&remove_song;
Irssi::command_bind mseek => \&seek;
Irssi::command_bind msearch => \&search;
Irssi::command_bind mshuffle => \&shuffle;
Irssi::command_bind mstop => \&stop;
Irssi::command_bind mupdate => \&update;
Irssi::command_bind mvolume => \&volume;
Irssi::command_bind mwa => \&wipeAdd;
Irssi::command_bind mwaa => \&wipeAddall;
Irssi::command_bind mwaas => \&wipeAddallShuffle;
Irssi::command_bind mwas => \&wipeAddShuffle;
Irssi::command_bind mwipe => \&wipe;
