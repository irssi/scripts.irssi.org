###############################################################################
# Find script that searches your local files and sends them to users
# Copyright (C) 2003  Thomas Karlsson
#
# Findbot script, which responds to @find commands in irc channels
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
# Thomas Karlsson (findbot@planet.eu.org)
###############################################################################
# The file collection at the end of this file is made by Henrik Andreasson
# findbot@han.pp.se
# 
###############################################################################
# Description:
#
# This script loads into an Irssi client and then monitors selected channels
# and replies to public channel commands.
# The commands are:
# @find :	searches the summaryfile after file "@find birthday" looks for
#		a file containing birthday.
# @<botnick>-stats : Replies with the users queue.
# @<botnick>-remove : Will remove the users whole queue
# @<botnick>-remove 2 : Will remove queue position 2 from the queue
# @<botnick>-help : Will message the help to the user.
# !<botnick> <filename> :Will queue the file. For eg."!santa_claus jingle.bells.mp3"
#
###############################################################################
# Installation:
#
# AT THE END OF THIS FILE IS ALL INSTALLATION INSTRUCTIONS!!
# 
# Variables:
# findbot_channels - Space separated channels (#mp3 #othermp3)
# findbot_summaryfile - Full path to the "mymp3s.txt" file (/misc/mp3/mymp3s.txt)
# findbot_sendlist - Full path and filename to the list that is sent to clients
# findbot_maxresults - Max findresults returned to the requesting client
# findbot_maxqueue - Max files allowed in the queue
# findbot_maxsends - Max simultanous sends allowed
# findbot_maxuserqueue - Max queued files per Nick
# findbot_maxusersends - Max simultanous sends per Nick
# findbot_showbanner - Present a banner in every "findbot_channels" channel
# findbot_bannertime - How many seconds between each banner
# findbot_minspeed - Minimum CPS for a send, 10000 means 10kb/s, 0 means disabled
# findbot_mustbeinchannel - If ON, the user is required to be in the channel during download
# findbot_debuglevel - Debuglevel, Higher value equals more debugoutput
# findbot_enabled - Set ON or OFF
# findbot_timeslots - When the server should be enabled (sat=10:00-18:00sun=00:00-23:59)
#		      If a day can't be found the bot will be ON by default
# findbot_voicegetpriority - If ON then voiceuserusers and ops will get priority in the queue.
#			Ops get 20 in priority and voice gets 10. I.e ops are more prioritized than voice
#
# Admincommands:
# /findbotqueue  - Shows you the whole queue in the findbot window
# /findbotremove - Admin removes queueitems
# /findbotreset  - If you like you can specify how many sends the script thinks it have. This was just added
#                  if you wanted to send somefiles your self without the script sending files.
# /findbotreload - Reloads the summaryfile if you have added files
# /findbotactivesends - Show which users are currently having a download
#
###############################################################################
# TODO or maybe features
#
# * When requesting it SHOULD be case sensitive
# * Support CTCP SLOTS and CTCP MP3, seems unnecessary to help windows-mirc users :)
#   Slots Free Next Queues Max Sendspeed Files
#   4     4    NOW  0      999 0         120575 36856591362 0 1073595728 1
# * Make an ignore and ban function
# * Should the users see the whole que or just their own files?
# * If there is a netsplit all downloads will be cancelled if an active user disappered
# * If one send is below like 4kb/s then change findbot_maxsends to one more, so we use the bandwidth
# * DONE Servers (i.e +v) should get priority, but how? First in queue?
# * DONE Fix admin_showqueue to really show VIP instead of 1
###############################################################################
# CHANGES
#
# 1.57	* Added a VIP function which allows +v users to be first in line to get a file
# 	* Remove a users queue if they get kicked (only if findbot_mustbeinchannel is ON)
#	* Fixed a bug when a user with a download changed nick.
# 1.56  * The findbot_maxqueue now works
#	* Sending files with spaces in them, now works
# 1.55	* Minor changes
# 1.54	* Added support to update the mp3list without restarting the bot (/findbotreload)
# 1.53	* Fixed some debug output
# 1.52	* Fixed some typos
#	* Now people can't look for * . etc. Now a searchpattern MUST contain atleast 1 normal character
#	* Fixed so you can change banner time without restarting the bot
# 1.50	* Added a timeslot function
#	* Added logging support. Now logging to file. Must specify filename and path INSIDE this script
# 1.06	* "Optimized" search. Instead of opening and read the whole summaryfile everytime
#	  someone searched the script reads the file once at startup.
#	* Fixed more regular expressions
#	* Added multiserver support, i.e you can have the bot on two nets and two different channels
# 1.05	* Added a new perlscript at the end of this file.
#	  It searches your mp3s and makes the 2 necessary files.
#	  The script is made by Henrik Andreasson (findbot@han.pp.se)
# 1.04	* Changed so the files contains full path to mp3s
#	* findbot_maxsends was ignored under some circumstanses
#	* Added so debugoutput shows which file are sent
#	* Sending to client "Now sending you file...." only if they accually are in the channel
# 1.03	* Changed a "for-loop" one bit
#	* If findbot_minimumspeed was disabled, then the user could leave channel
#	  and still get files even if findbot_mustbeinchannel was enabled
#	* Forgot to write to debugwindow if someone downloaded the whole list
#	* Corrected some bad english :)
#	* Fixed more regular expressions
#	* The user will be told the queueposition when requesting a file
#	* Fixed some queueproblems
#	* Added some errormessages if someone types !nickname in a private message
# 1.01	* Do not reply with "no match" if no match was found to avoid unnecessary spam
#	* Removed alot of commented code
#	* Changed the description of the script
#	* Changed the "results found" string a bit.
#	* Added a new value findbot_sendlist and separated the filelist and the one which accually is sent to the users
#	* Fixed some regular expressions to fit the new searchfiles
#	* Bug fix. If someone resumed a file, they always will be under findbot_minspeed in the start
#	* Didn't search if someone typed @FIND (in uppercase)
#	* Ops the url wasn't right. There is no ~ in the address :)
# 1.0	Release
###############################################################################
use Irssi;
use Irssi::Irc;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "1.57";

%IRSSI = (
    authors     =>  "Thomas Karlsson",
    contact     =>  "findbot\@planet.eu.org",
    name        =>  "Findbot",
    description =>  "Public command \@find script",
    license     =>  "GPL",
    url         =>  "http://hem.passagen.se/thka2315/",
);

my %nickqueue = ();	# Queuenumber + nickname
my %filequeue = ();	# Queuenumber + filename
my %servertagqueue = (); # Queuenumber + array with servertag,voiceprio,extrafield
my %activesends = ();	# nickname + 1 The user is here if he has an active send
my $lastqueuenumber = 0;	# Holds the last queueitem
my %scriptdetect = ();
my $timeout_tag;
my $banner_timeout;
my $currentsends = 0;
my $servertag;
my $globalstart = 0;
my $globalvippos = 0;
my $debuglevel;
my %bannedpeople = ();	# This will contain banned people and time of ban
my @bigarray;		# In here the whole filelist will reside
my @daynames = qw(Sun Mon Tue Wed Thu Fri Sat);
my $logfile = "findbot.log";
my $scriptdetecttime = "3"; # Three seconds must pass before a new filerequest is issued, after a DCC CLOSE
my $showscriptdetect = 1;
my $lastbannerprint = time();	# The last time the banner was printed into monitored channels

sub timeslotenabled {
	my $weekday = shift;		# Save weekday
	my $slothour = shift;		# Save hours
	my $slotminute = shift;		# Save minutes

	$weekday = $daynames[$weekday];
	my $timeslotstring = Irssi::settings_get_str('findbot_timeslots');
	if ( $timeslotstring =~ /$weekday/i ) {
		if ( $timeslotstring =~ m/.*$weekday=(.?.):(.?.)(a\.?m\.?|p\.?m\.?)?-(.?.):(.?.)(a\.?m\.?|p\.?m\.?)?.*/i ) {
			my $fromhour = $1;
			my $frommin = $2;
			my $fromampm = $3;
			my $tohour = $4;
			my $tomin = $5;
			my $toampm = $6;
			if ( $fromampm =~ /p/i ) { $fromhour += 12; }		# If it is a pm time add 12 to get 24h format
			if ( $toampm =~ /p/i ) { $tohour += 12; }		# If it is a pm time add 12 to get 24h format
			my $midnightfrom = ( $fromhour * 60 ) + $frommin;		# Get minutes from midnight
			my $midnightto = ( $tohour * 60 ) + $tomin;		# Get minutes from midnight
			my $inputtime = ( $slothour * 60 ) + $slotminute;		# Get minutes from midnight
			debugprint(20,"inputtime:$inputtime midfrom:$midnightfrom midto:$midnightto");
			if ( $inputtime <= $midnightto && $inputtime >= $midnightfrom ) {
				return 1;					# The time is between the timeenabled slot
			} else {
				return 0;					# Time was outside. Bot should be off.
			}
		} else {
			return 0;	# Hmm didnt get the times in that day, maybe wrong input from user
		}	
	} else {
		return 1;	# If the current day wasn't found in findbot_timeslots then return true, i.e bot is default ON.
	}
	return 0;		# Return false i.e 
}

sub private_get {
	(my $server, my $message, my $nick, my $address) = @_;
	if ( $message =~ /^!$server->{nick}\ .*/i ) {
		$server->command("/MSG " . $nick . " Please request files in the channel, not personally to me. Type \@$server->{nick}-help in channel for help");
	} elsif ( $message =~ /^\@$server->{nick}.*/i ) {
		$server->command("/MSG " . $nick . " Please request my filelist in the channel, not personally to me. Type \@$server->{nick}-help in channel for help");
	} elsif ( $message =~ /^\@find.*/i ) {
		$server->command("/MSG " . $nick . " Please search files in the channel, not personally to me. Type \@$server->{nick}-help in channel for help");
	}
}

sub check_user_queued_items {
	my $user = shift;					# Get the nickname to check
	my $localsrvtag = shift;
	my $counter = 0;					# Reset the counter
	for ( my $i=1; $i <= $lastqueuenumber; $i++ ) { # Loop through entire queue
		if ( $nickqueue{$i} eq $user && $localsrvtag eq $servertagqueue{$i}[0] ) {
			$counter++;
		}
	}
	return $counter;
}

sub already_queued_file {
	my $checknick = shift;
	my $checkfile = shift;
	my $srvtag = shift;
	my $alreadyqueued = 0;
	for ( my $i=1; $i <= $lastqueuenumber; $i++ ) {	# Loop through entire queue
		if ( $nickqueue{$i} eq $checknick && $filequeue{$i} eq $checkfile && $servertagqueue{$i}[0] eq $srvtag) { # Check if its queued
			$alreadyqueued = 1;		# Yep it was
		}
	}
	if ( $alreadyqueued ) { return 1; } else { return 0; } # Return true if queued else false
}

sub add_file_to_queue {
	(my $addnick, my $addfile, my $srvtag, my $priority) = @_;			# Split nickname and filename into two variables
	$lastqueuenumber++;
	$nickqueue{$lastqueuenumber} = $addnick;	# for eg. $nickqueue{1} = 'El_Tomten'
	$filequeue{$lastqueuenumber} = $addfile;	# for eg. $filequeue{1} = '/misc/legal-mp3s/happy.birthday.mp3'
	if ( ! Irssi::settings_get_bool('findbot_voicegetpriority') ) { $priority = 0; }
	my @field = ($srvtag,$priority,"To be used later, maybe");
	$servertagqueue{$lastqueuenumber} = \@field;	# for eg. $servertagqueue{1} = 'stockholm'
	if ( $priority > 1 ) {		# Did a priority user queued the file
		fix_vip_position($priority);	# Move vip position up to number one, or just after the last already existing vip position
	}
}

sub fix_vip_position {
	my $priority = shift;		# Get priority from input
	my ($tnickqueue,$tfilequeue,$tservertagqueue);
	if ( $lastqueuenumber eq 1 ) { return; }	# If the queue only have one entry, why try to make it a priority?
	for ( my $i = $lastqueuenumber; $i > 1; $i--) {
		if ( $servertagqueue{$i-1}[1] >= $priority ) { $globalvippos = $i; last; } # Is the queue entry before a vip entry? Lets quit the prioritymove
		$tnickqueue = $nickqueue{$i-1};			# Backup entry
		$tfilequeue = $filequeue{$i-1};
		$tservertagqueue = $servertagqueue{$i-1};

		$nickqueue{$i-1} = $nickqueue{$i};		# Move entry up
		$filequeue{$i-1} = $filequeue{$i};
		$servertagqueue{$i-1} = $servertagqueue{$i};
		
		$nickqueue{$i} = $tnickqueue;			# Restore entry ( the two entris have now changed place )
		$filequeue{$i} = $tfilequeue;
		$servertagqueue{$i} = $tservertagqueue;
	}
}

sub remove_queueitem {
	my $queueitem = shift;
	if (defined($nickqueue{$queueitem}) && defined($filequeue{$queueitem} && defined($servertagqueue{$queueitem})) ) { # Is there really a queueitem here?
		for ( my $i = $queueitem; $i <= Irssi::settings_get_int('findbot_maxqueue'); $i++) {
			if ( defined($nickqueue{$i+1}) && defined($filequeue{$i+1}) && defined($servertagqueue{$i+1}) ) { # Move up in queue if there is one
				$nickqueue{$i} = $nickqueue{$i+1};			# Move up in queue
				$filequeue{$i} = $filequeue{$i+1};			# Move up in queue
				$servertagqueue{$i} = $servertagqueue{$i+1};		# Move up in queue
			}
				
		}
		delete $nickqueue{$lastqueuenumber};		# Delete the last entry. It has been moved up one slot
		delete $filequeue{$lastqueuenumber};		# Delete the last entry. It has been moved up one slot
		delete $servertagqueue{$lastqueuenumber};	# Delete the last entry. It has been moved up one slot
		$lastqueuenumber--;				# Since we removed a queue item the lastqueuenumber decreases
	} else { debugprint(10,"debug: No remove $queueitem"); }
}

sub user_have_max_active_sends {
	my $nickname = shift;					# Save the nick
	my $localserver = shift;				# Save current servertag
	if ( $activesends{$nickname} < Irssi::settings_get_int('findbot_maxusersends') ) {
		return 0;					# The user didn't have enough sends
	} else {
		return 1;					# The user have NOT an active send
	}
}

sub user_is_in_active_channel {
	my $nickname = shift;
	my $srvtag = shift;
	my $find_channels = Irssi::settings_get_str('findbot_channels'); # What channels to monitor
        my @checkchannels = split (/ /, $find_channels); # Split into an array

	foreach my $localserver ( Irssi::servers() ) {		# Loop through all connected servers
		foreach my $singlechan ( @checkchannels ) {	# Loop through all monitored channels
			my $channel = $localserver->channel_find($singlechan);	# Get a channelobject
			if ( defined($channel) && defined($channel->nick_find($nickname)) ) {	# Is the nick there?
				return 1;	# User are in monitored channels # Yep is was
			} 
        	}
	}
		return 0;	# User have left monitored channels

}

sub nicefilename {
        my $filename = shift;

        if ( $filename =~ /.*\/(.*)\ *:.*/g ) { # If filelist is made by "file"
		debugprint(15,"Summary file is made by the program file");
                return $1;
        } elsif ( $filename =~ /.*\/(.*)$/g ) { # If filelist is Not made by file
		debugprint(15,"Summary file is NOT made by the program file");
                return $1;
        }
}

sub strippath {
	my $filename = shift;			# Get parameter into $filename

	$filename =~ s/.*\/(.*)/$1/g;		# Remove everything until the last /
	return $filename;			# Return the stripped line
}

sub debugprint {
	(my $dbglvl,my $debugmessage) = @_;	# Save input to variables
	$debuglevel = Irssi::settings_get_int('findbot_debuglevel');
	my $win;
	if ( ! ($win = Irssi::window_find_name($IRSSI{name})) ) { # If the windows doesn't exist
		$win = Irssi::Windowitem::window_create($IRSSI{name},1);
	}
	if ( $dbglvl <= $debuglevel ) {
		$win->set_name($IRSSI{name});	# Select the window
		$win->print($debugmessage,MSGLEVEL_CLIENTCRAP);
		my $debugtid = localtime(time);
		open (LOGFILE,">>", $logfile);
		print LOGFILE "$debugtid: $debugmessage\n";
		close (LOGFILE);
	}
}

sub process_queue {
	if (Irssi::settings_get_bool('findbot_enabled') ) { # Is the findbot enabled?
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time); # Get current time
		if ( ! timeslotenabled($wday,$hour,$min) ) {		# If NOT true the bot is offline
			debugprint(15,"The bot is Offline due to timerestrictions in findbot_timeslots");
			return 0;
		}
		print_banner();
		if ( $currentsends < Irssi::settings_get_int('findbot_maxsends') ) {    # Check if we'll send another file simultanously
			my $i = 1;
			while ( $i <= $lastqueuenumber ) {
				if ( ! user_have_max_active_sends($nickqueue{$i},$servertagqueue{$i}[0]) ) { # If NOT user have max active sends
					my $nicefile = nicefilename($filequeue{$i});
					if ( user_is_in_active_channel($nickqueue{$i},$servertagqueue{$i}[0]) ) { # Are the user in a monitored channel?
						debugprint(10,"[ADMIN] $nickqueue{$i} are in monitored channels, sending $nicefile");
						my $localserver = Irssi::server_find_tag($servertagqueue{$i}[0]);
						$localserver->command("/QUOTE NOTICE " . $nickqueue{$i} . " :Sending you the requested file: $nicefile");
						$localserver->command("/DCC SEND $nickqueue{$i} \"$filequeue{$i}\"" );
						remove_queueitem($i);
						last;	# Exit the loop
					} else {
						debugprint(10,"[ADMIN] $nickqueue{$i} is NOT in monitored channels. Removing queueentry $filequeue{$i}");
						remove_queueitem($i);
					 } # Remove the queued item if the user have parted the channel
				} else { # A user had too many sends, increase $i by one to check next queue pos.
					$i++;	# Increase by one so we can loop through whole queue
				}
			} # End while or for
		}
	}
	check_dcc_speed_and_in_channel();			# Check minimumspeed
}

sub dcc_created {
	(my $dcc) = @_;	# Put active dcc in variable

	debugprint(15,"dcc_created was called");
	if ( $dcc->{type} eq "SEND" ) {				# Is it a SEND?
		if ( defined( $activesends{$dcc->{nick}} ) ) {
			$activesends{$dcc->{nick}} = $activesends{$dcc->{nick}} + 1;
		} else {
			$activesends{$dcc->{nick}} = 1;
		}
		$currentsends++;
	}
}

sub dcc_closed {
	(my $dcc) = @_; # Put active dcc in variable

	debugprint(15,"dcc_closed was called");
	if ( $dcc->{type} eq "SEND" && defined ($activesends{$dcc->{nick}}) ) {	# Is it a SEND and a findbot SEND?
		my $tiden = time();
		$tiden = $tiden - $dcc->{starttime};
		if ( $tiden > 0 ) {
			my $kbsec = $dcc->{transfd} / $tiden;
		} else {
			$tiden = 1;
			my $kbsec = $dcc->{transfd} / $tiden;
		}
		if ( $dcc->{transfd} == 0 ) {		# If transfered byts are zero, then it was probably aborted
			debugprint(10,"[ADMIN] SEND aborted Nick: $dcc->{nick} File: $dcc->{arg}");
		} else {
			debugprint(10,"[ADMIN] SEND done Nick: $dcc->{nick} File: $dcc->{arg} Bytes: $dcc->{transfd} Time(sec): $tiden Speed: " . calc_kb_sec($tiden,$dcc->{transfd}) . " KB/s");
		}
		if ($activesends{$dcc->{nick}} == 1) {
			delete $activesends{$dcc->{nick}};
		} else {
			 $activesends{$dcc->{nick}} = $activesends{$dcc->{nick}} - 1;
		}
		$currentsends--;
		$scriptdetect{$dcc->{nick}} = time();		# Record the time when dcc was closed
	}
}

sub calc_kb_sec {
	my $seco = shift;
	my $bytest = shift;

my 	$kbsec = $bytest / $seco / 1000;
	$kbsec =~ s/(.*\..?.?).*/$1/;

	return $kbsec;
}

sub dcc_destroyed {
        (my $dcc) = @_; # Put active dcc in variable

	debugprint(15,"dcc_destroyed was called");
}

sub check_dcc_speed_and_in_channel {
#	my $localserver = Irssi::server_find_tag($servertag); # Get serverobject
	my $minimumspeed = Irssi::settings_get_int('findbot_minspeed');
	my $channelcheck = Irssi::settings_get_bool('findbot_mustbeinchannel');
	foreach my $dccconnection (Irssi::Irc::dccs()) {
		if ( $dccconnection->{type} eq "SEND" &&  defined($activesends{$dccconnection->{nick}}) && ($dccconnection->{transfd} - $dccconnection->{skipped}) > 50000) { # Check if its a findbot send.
			my $bytetransferred = $dccconnection->{transfd} - $dccconnection->{skipped};
			my $timedownloaded = time() - $dccconnection->{starttime};
			if ( $timedownloaded == 0 ) { $timedownloaded++; } # Fix for Illegal division by zero
			my $currentcps = sprintf("%02d",($bytetransferred / $timedownloaded)); # Get current CPS
			if ( $currentcps < $minimumspeed && $minimumspeed > 0 ) {	# Check if below minimumspeed
				my $localserver = Irssi::server_find_tag($dccconnection->{servertag});
				$localserver->command("/QUOTE NOTICE $dccconnection->{nick} :Minimum CPS is $minimumspeed and you only have $currentcps. Closing your connection");
				$localserver->command("/DCC CLOSE SEND $dccconnection->{nick}");
				debugprint(10,"[ADMIN] $dccconnection->{nick} ($currentcps) is below minimumspeed($minimumspeed). Closing...");
			} elsif ( $channelcheck ) {
				if ( ! user_is_in_active_channel($dccconnection->{nick},$dccconnection->{servertag}) ) {
					debugprint(10,"[ADMIN] $dccconnection->{nick} has LEFT monitored channels, closing SEND");
					my $localserver = Irssi::server_find_tag($dccconnection->{servertag});
					$localserver->command("/DCC CLOSE SEND $dccconnection->{nick}");
					# Just close without warning, why bother to tell him if he's left.
				}
			}
		}
	}
}

sub nickname_changed {
	my ($chan, $newnick, $oldnick) = @_;

	foreach my $queuepos (keys(%nickqueue)) {	# Go through all nicks in my queuelist to see if we're affected
		if ( $nickqueue{$queuepos} eq $oldnick ) {	# Check the nick
			$nickqueue{$queuepos} = $newnick->{nick};	# Insert the new nick in that position
			debugprint(10,"[ADMIN] Nickchange $nickqueue{$queuepos} -> $newnick->{nick}");
		}
	}
	if ( defined($activesends{$oldnick}) ) {		# He has an active send
		$activesends{$newnick->{nick}} = $activesends{$oldnick}; # Make a new entry so he can't evade the dcc speed check
		delete $activesends{$oldnick};
	}
}

sub user_got_kicked {
	my ($kchannel,$knick,$kkicker,$kaddress,$kreason) = @_;
	my $mustbeinchannel = Irssi::settings_get_bool('findbot_mustbeinchannel');
	
	if ( $mustbeinchannel ) {				# Are we to punish this kicked user?
		foreach my $queuepos (keys(%nickqueue)) {	# Go through all nicks in my queuelist to see if we're affected
			if ( $nickqueue{$queuepos} eq $knick ) {	# Check the nick if the kicked user has a queue.
				debugprint(10,"[ADMIN] $knick was KICKED. Removing queueposition $queuepos $filequeue{$queuepos}");
				remove_queueitem($queuepos);	# Removes the users queue
			}
		}
	}
}

sub print_banner {
	my $timenow = time();
	my $timecalc = Irssi::settings_get_str('findbot_bannertime') + $lastbannerprint;
#	debugprint(10,"print_banner function... now: $timenow last: $lastbannerprint timecalc: $timecalc");
	if ( $timenow > $timecalc ) {
		$lastbannerprint = time();		# Reset timer
		my $find_channels = Irssi::settings_get_str('findbot_channels'); # What channels to monitor
		my @checkchannels = split (/ /, $find_channels); # Split into an array
		if ( Irssi::settings_get_bool('findbot_showbanner') ) { # Check if I will print the banner
			debugprint(10,"[ADMIN] Sending banner to monitored channels");
			my $showvoiceprio = "OFF";
			if (Irssi::settings_get_bool('findbot_voicegetpriority') ) {
				$showvoiceprio = "ON";
			}
			foreach my $localserver ( Irssi::servers() ) {
				my $bannerad = "For my list of $#bigarray files type: \@" . $localserver->{nick} . ", Sends: $currentsends/" . Irssi::settings_get_int('findbot_maxsends') . " , Queue: $lastqueuenumber/" . Irssi::settings_get_int('findbot_maxqueue') . ", Voicepriority: $showvoiceprio, For help: \@" . $localserver->{nick} . "-help";
				foreach my $singlechan ( @checkchannels ) {	# Loop through all monitored channels
					my $channel = $localserver->channel_find($singlechan);	# Get the channelobject
					if ( defined($channel) ) { # Am I in the specific channel, if so its defined
						$channel->command("/MSG $singlechan $bannerad" . " Using: Irssi " . $IRSSI{name} . " v$VERSION"); # Print banner
					} # End if
				} # End foreach channel
			} # End foreach server
		} # End if
	} # End check if I'll print the banner
}

sub admin_showqueue {
	debugprint(10,"[ADMIN] Show queue");
	debugprint(10,"[ADMIN] Current sends are: $currentsends");
	for ( my $i = 1; $i <= $lastqueuenumber; $i++ ) { # Loop through the queue
		debugprint(10,"[ADMIN] ($i) $nickqueue{$i}:$filequeue{$i}:$servertagqueue{$i}[0]:Prio $servertagqueue{$i}[1]");
#		if ( $servertagqueue{$i}[1] > 0 ) {	# Is this a VIP entry?
#			debugprint(10,"[ADMIN] ($i) $nickqueue{$i}:$filequeue{$i}:$servertagqueue{$i}[0]:VIP queued($servertagqueue{$i}[1])");
#		} else {
#			debugprint(10,"[ADMIN] ($i) $nickqueue{$i}:$filequeue{$i}:$servertagqueue{$i}[0]:Normal queued");
#		}
	}
	debugprint(10,"[ADMIN] End of list");
}

sub admin_reset {
	my $howmany = shift;
	if ( $howmany =~ /\d+/ ) {
		$currentsends = $howmany;	# Reset current sends
		debugprint(10,"[ADMIN] Current sends are now set to $currentsends");
	} else {
		debugprint(10,"[ADMIN] Specify how many sends there are now");
	}
}

#sub start_findbot {
#	my($data,$localserver,$witem) = @_;

#	if ( $localserver != 0 ) {
#		$servertag = $localserver->{tag};		# Remeber on which server the findbot is on
#		$globalstart = 1;
#		debugprint(10,"Findserver is started");
#	} else {
#		debugprint(10,"Please start the server in a window where I can get hold of a servertag");
#3	}
#}

sub admin_removequeue {
	my $queueposition = shift;
	if ( $queueposition =~ /\d+/ ) {
		remove_queueitem($queueposition);
		debugprint(10,"[ADMIN] Removed position $queueposition");
	} else {
		debugprint(10,"[ADMIN] Specify which queueitem should be removed");
	}
}

sub admin_activesends {
		debugprint(10,"[ADMIN] Listing active dccsends");
	foreach my $send (keys(%activesends)) {
		debugprint(10,"[ADMIN] $send ($activesends{$send})");
	}
		debugprint(10,"[ADMIN] End of list");
}

sub admin_reload {
	if ( -r Irssi::settings_get_str('findbot_summaryfile') ) {
	        open (FINDFILE, "<", Irssi::settings_get_str('findbot_summaryfile')); # Open the file
	        @bigarray = <FINDFILE>;                         # Load it whole into memory :)
	        close (FINDFILE);
		debugprint(10,"[ADMIN] Summary file has been reloaded into memory.");
	} else {        
	        debugprint(10,"[ADMIN] The Summaryfile cannot be read. Please check if the path is correct and the file is accually there.");
	}
}

sub send_ctcp_slots {
# Not implemented yet
}

sub sanitize_input {
	my $tainted_input = shift;
	$tainted_input =~ s/[\^\\\[\]\$\(\)\?\+\/\|\'\}\{]+/\./g; # Translate ^\[]$()?+ to .
	return $tainted_input;		# Return regularexpression sanitized input
}

sub find_public {
	my ($server, $msg, $nick, $address, $targetchan) = @_;		# Save all input to variables
	my $find_channels = Irssi::settings_get_str('findbot_channels');# What channels to monitor
	my $find_file = Irssi::settings_get_str('findbot_summaryfile');	# Filename which holds all the files
	my $mp3list = Irssi::settings_get_str('findbot_sendlist');	# The nice list which is sent to users
	my $max_results = Irssi::settings_get_int('findbot_maxresults');# Get max results retured to client
	my $userqueuelimit = Irssi::settings_get_int('findbot_maxuserqueue'); # Get userqueue limit
	my $serverqueuelimit = Irssi::settings_get_int('findbot_maxqueue'); # Get server maxqueue
	my @checkchannels = split (/ /, $find_channels);		# Split into an array

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time); # Get current time

	my $validchan = 0;
	foreach my $singlechan ( @checkchannels ) {
		if ( $singlechan eq $targetchan ) {
			$validchan = 1;
		}
	}

	if ( $validchan && Irssi::settings_get_bool('findbot_enabled') && timeslotenabled($wday,$hour,$min) ) {	# Did the user say something in one of our channels?
		my $mynick = $server->{nick};
		if ( $msg =~ /^\ *\@find\ +.+/i ) { 			# Was it a @find command?
			$msg =~ s/^\ *\@find\ (.*)/$1/i;		# Remove @find space spaces infront of it
			$msg =~ tr/*/\ /;				# Translate * to spaces
			$msg =~ s/[\ \+]+/\.\*/g;			# Translate ALL spaces to .*
			$msg = sanitize_input($msg);
			debugprint(10,"$nick is searching for $msg");
			my @matched;
#			if ( length($msg) > 2  && $msg =~ m/[a-z]+/i) { # MUST be over 2 chars and contain atleast 1 or more normal characters
				@matched = grep (/$msg/i,@bigarray);		# Search for the matches
#			} else {
#				debugprint(10,"[ADMIN] $nick tried to search with too wide searchpattern ($msg)");
#				return;
#			}
			my $matchcount = 0;				# Reset a counter
			my $found_results = $#matched;			# Return how many hits
			$found_results++;				# If nomatch then it is -1
			if ( $found_results > 0 ) {	# Print number of results to the user
				debugprint(10,"Found $found_results matches");
				$server->command("/QUOTE PRIVMSG " . $nick . " :Found $found_results matching files. Using: $IRSSI{name} v$VERSION for Irssi");
			}
			foreach my $match (@matched) {			# Loop through each file match
				$match = strippath($match);		# Remove the path and keep filename and mp3info
				$match =~ s/:/\ \ \ :\ \ /;		# Replace the ":" with "   :  "
				if ( $matchcount < $max_results ) { 	# Is the matchlimit reached and is it a mp3 file?
					$matchcount++;			# Increase by one
					$server->command("/QUOTE PRIVMSG " . $nick . " :!$mynick $match");
				} else {				# Limit reached!
					$server->command("/QUOTE PRIVMSG " . $nick . " :Resultlimit by " . $max_results . " reached. Download my list for more, by typing \@$server->{nick}");
					close (FINDFILE);
					return;
				}
			}
#			if ( $matchcount == 0 ) {
#				$server->command("/QUOTE NOTICE " . $nick . " :No match found.");
#			}
		} elsif ( $msg =~ /^\ *!$server->{nick}.*/i ) {		# Send file trigger
			my $localsrvtag = $server->{tag};		# Get current servertag
			debugprint(20,"$nick tries to queue $msg");	# Just debugoutput
			$msg =~ s/\ *!$server->{nick}\ *(.*)/$1/;	# Remove the trigger
			$msg =~ tr/\(\)/\.\./;				# Translate all () to . (any char)
			$msg = sanitize_input($msg);
			my @matched = grep (/$msg/i,@bigarray);		# Get the real path from the file
			if ( $matched[0] eq "" ) {
				$server->command("/QUOTE NOTICE " . $nick . " :That file does not exist");
				return;
			}
			my $realfile = $matched[0]; 			# Append the real path to the relative path
			$realfile =~ s/(.*)\ +:.*/$1/;			# Remove : and beyoned
			
			my $scriptrequest = time() - $scriptdetect{$nick};
			if ( $scriptrequest <= $scriptdetecttime && $showscriptdetect ) {
				debugprint(10,"[ADMIN] Requestscript detected on $nick");
				# return;	# 
			}
			chomp ($realfile);
			if ( check_user_queued_items($nick,$localsrvtag) < $userqueuelimit ) { # Is it below allowed user queue limit
				if ( already_queued_file($nick,$realfile,$localsrvtag) ) {
					$server->command("/QUOTE PRIVMSG " . $nick . " :You have already queued that file!");
				} else {
					my $priority = 1;			# Default prio
					if ( $lastqueuenumber < $serverqueuelimit ) {
						foreach my $vchannel ($server->channels()) {	# Loop through all joined channels
							if ( $vchannel->{name} eq $targetchan ) {	# Did he say it in a monitored channel
								my $nickrec = $vchannel->nick_find($nick);
								if ( $nickrec->{voice} ) {
									$priority = 10;	# A voiced user get 10 prioritypoints
								} # Voiced user?
								if ( $nickrec->{op} ) {
									$priority = 20; # An op get 20 prioritypoints
								}
								last;		# Skip rest of loop
							}
						}
						add_file_to_queue($nick,$realfile,$localsrvtag,$priority);	# Add file to queue
						if ( Irssi::settings_get_bool('findbot_voicegetpriority') && $priority > 1 ) {
							$server->command("/QUOTE PRIVMSG " . $nick . " :Added file to VIP queueposition $globalvippos.");
							debugprint(10,"[ADMIN] $nick VIP queued: $realfile");
						} else {
							$server->command("/QUOTE PRIVMSG " . $nick . " :Added file to queueposition $lastqueuenumber.");
							debugprint(10,"[ADMIN] $nick queued: $realfile");
						}
					} else {
						$server->command("/QUOTE PRIVMSG " . $nick . " :The serverqueue is full. Please try again in a few minutes.");
						debugprint(10,"[ADMIN] Queue is FULL.");
					}
				}
			} else {						# Tell the user the user queue limit is reached
				$server->command("/QUOTE PRIVMSG " . $nick . " :You have reached the " . $userqueuelimit . " files queue limit.");
				debugprint(10,"[ADMIN] $nick has reached his queuelimit");
			}
		} elsif ( ($msg =~ /^\ *\@$server->{nick}-stats.*/i) || ($msg =~ /^\ *\@$server->{nick}-que.*/i) ) {
			debugprint(10,"[ADMIN] $nick checked queuepositions");
			$server->command("/QUOTE PRIVMSG " . $nick . " :Sending you, your queuepositions");
			for ( my $i = 1; $i <= $lastqueuenumber; $i++ ) { # Loop through the queue
				if ( $nickqueue{$i} eq $nick ) {
					my $nicefile = nicefilename($filequeue{$i});
					$server->command("/QUOTE PRIVMSG " . $nick . " :Pos $i, $nicefile");
				}
			}
		} elsif ( $msg =~ /^\ *\@$server->{nick}-remove.*/i ) {
			if ( $msg =~ /\ *\@$server->{nick}-remove\ *([\d]+)/ ) { # We have a number
				my $qitem = $1;
				debugprint(10,"[ADMIN] $nick is trying to remove queueposition $qitem");
				if ( $nickqueue{$qitem} eq $nick ) {	# Check if the item is owned by the user
					remove_queueitem($qitem);	# Remove the requested queueitem
					$server->command("/QUOTE NOTICE " . $nick . " :Item $qitem has");
				} else {	# Unauthorized removal
					debugprint(10,"[ADMIN] $nick tried to remove other peoples files from queue");
					$server->command("/QUOTE NOTICE " . $nick . " :You can't remove other peoples queueitems");
				}
			} else {			# We dont have a number, ie remove the whole user queue
				debugprint(10,"[ADMIN] $nick has removed all own queueitems");
				for ( my $i = 1; $i <= $lastqueuenumber; $i++ ) { # Loop through the queue
					if ( $nickqueue{$i} eq $nick ) {
						remove_queueitem($i);
					}
				}
				$server->command("/QUOTE NOTICE " . $nick . " :Your whole queue have been deleted");
			}
		} elsif ( $msg =~ /^\ *\@$server->{nick}$/i ) {
			if ( -r $mp3list ) {				# Check if the file is still there
				debugprint(10,"[ADMIN] $nick requested my list: $mp3list");
				$server->command("/QUOTE NOTICE " . $nick . " :Sending you my full list...");
				$server->command("/DCC SEND $nick $mp3list" );
			} else {
				debugprint(5,"[WARNING] the $mp3list doesn't exist!");
				$server->command("/QUOTE NOTICE " . $nick . " :Something wicked happened. My list has disappeared and i have notified the bot owner.");
			}
		} elsif ( ($msg =~ /^\ *\@$server->{nick}\ *help\ *$/i) || ($msg =~ /^\ *\@$server->{nick}-help\ *$/i) ) {
			debugprint(10,"[ADMIN] $nick requested HELP");
			$server->command("/QUOTE PRIVMSG " . $nick . " :Public channel commands:");
			$server->command("/QUOTE PRIVMSG " . $nick . " :\@find [searchpattern] : Searches my database for that file");
			$server->command("/QUOTE PRIVMSG " . $nick . " :!$server->{nick} [file] : Queues that file and it will be sent to you when its your turn");
			$server->command("/QUOTE PRIVMSG " . $nick . " :\@$server->{nick}-stats : Shows you your queuepositions");
			$server->command("/QUOTE PRIVMSG " . $nick . " :\@$server->{nick}-que : Shows you your queuepositions");
			$server->command("/QUOTE PRIVMSG " . $nick . " :\@$server->{nick}-remove : Clears all your queued files");
			$server->command("/QUOTE PRIVMSG " . $nick . " :\@$server->{nick}-remove 2 : Clear your queueposition 2");
			$server->command("/QUOTE PRIVMSG " . $nick . " :$IRSSI{name} v$VERSION $IRSSI{url}");
		} else {
			return; # Just ordinary chatter
		}
	}
	return;	# Just in case
}

sub check_vital_configuration {
	my $configerror = 0;
	if ( Irssi::settings_get_str('findbot_channels') eq "" ) {
		$configerror = 1;
		Irssi::print("The setting findbot_channels is empty.");
	} elsif (  Irssi::settings_get_str('findbot_summaryfile') eq "" ) {
		$configerror = 1;
                Irssi::print("The setting findbot_summaryfile is empty.");
	} elsif (  Irssi::settings_get_str('findbot_sendlist') eq "" ) {
		$configerror = 1;
                Irssi::print("The setting findbot_sendlist is empty.");
	} elsif (  Irssi::settings_get_int('findbot_maxresults') == 0 ) {
                $configerror = 1;         
                Irssi::print("The setting findbot_maxresults is empty.");
        } elsif (  Irssi::settings_get_int('findbot_maxqueue') == 0 ) {
                $configerror = 1;         
                Irssi::print("The setting findbot_maxqueue is empty.");
        } elsif (  Irssi::settings_get_int('findbot_maxsends') == 0 ) {
                $configerror = 1;         
                Irssi::print("The setting findbot_maxsends is empty.");
        } elsif (  Irssi::settings_get_int('findbot_maxuserqueue') == 0 ) {
                $configerror = 1;         
                Irssi::print("The setting findbot_maxuserqueue is empty.");
        } elsif (  Irssi::settings_get_int('findbot_maxusersends') == 0 ) {
                $configerror = 1;         
                Irssi::print("The setting findbot_maxusersends is empty.");
        } elsif (  Irssi::settings_get_int('findbot_bannertime') == 0 ) {
                $configerror = 1;
                Irssi::print("The setting findbot_bannertime is empty.");
        }
	if ($configerror) {
		Irssi::print("Please correct the settings first. The server will be disabled");
		Irssi::print("You have to reload the script when the settings are correct");
		Irssi::timeout_remove($timeout_tag);
		Irssi::timeout_remove($banner_timeout);
	}
}

########
# Main #
########

Irssi::settings_add_str("misc", "findbot_channels", "");	# Add a variable inside of irssi
Irssi::settings_add_str("misc", "findbot_summaryfile", "");	# Add a variable inside of irssi
Irssi::settings_add_int("misc", "findbot_maxresults", "");	# Add a variable inside of irssi
Irssi::settings_add_str("misc", "findbot_sendlist", "");	# Add a variable inside of irssi
Irssi::settings_add_int("misc", "findbot_maxqueue", "");	# Add a variable inside of irssi
Irssi::settings_add_int("misc", "findbot_maxsends", "");	# Add a variable inside of irssi
Irssi::settings_add_int("misc", "findbot_maxuserqueue", "");	# Add a variable inside of irssi
Irssi::settings_add_int("misc", "findbot_maxusersends", "");	# Add a variable inside of irssi
Irssi::settings_add_bool("misc", "findbot_showbanner", "");	# Add a variable inside of irssi
Irssi::settings_add_int("misc", "findbot_bannertime", "");	# Add a variable inside of irssi
Irssi::settings_add_bool("misc", "findbot_enabled", "");	# Add a variable inside of irssi
Irssi::settings_add_bool("misc", "findbot_voicegetpriority", "");	# Add a variable inside of irssi
Irssi::settings_add_int("misc", "findbot_minspeed", "");	# Add a variable inside of irssi
Irssi::settings_add_int("misc", "findbot_debuglevel", 10);	# Add a variable inside of irssi
Irssi::settings_add_bool("misc", "findbot_mustbeinchannel", "");
Irssi::settings_add_str("misc", "findbot_timeslots", "");	# Add a variable inside of irssi
Irssi::signal_add_last('message public', 'find_public');	# Hook up a function to public chatter
Irssi::signal_add_last('message private', 'private_get');	# Hook up a function to public chatter
Irssi::signal_add_last('dcc created', 'dcc_created');		# Hook when a dcc is created
Irssi::signal_add_last('dcc closed', 'dcc_closed');		# Hook when a dcc is closed
Irssi::signal_add_last('dcc destroyed', 'dcc_destroyed');
Irssi::signal_add('nicklist changed', 'nickname_changed');
Irssi::signal_add('message kick', 'user_got_kicked');
Irssi::command_bind('findbotqueue', 'admin_showqueue');
Irssi::command_bind('findbotremove', 'admin_removequeue');
Irssi::command_bind('findbotreset', 'admin_reset');
Irssi::command_bind('findbotreload', 'admin_reload');
Irssi::command_bind('findbotactivesends', 'admin_activesends');

check_vital_configuration();	# Run a subroutine to check all variables before starting
if ( -r Irssi::settings_get_str('findbot_summaryfile') ) {
	open (FINDFILE, "<", Irssi::settings_get_str('findbot_summaryfile'));	# Open the file
	@bigarray = <FINDFILE>; 			# Load it whole into memory :)
	close (FINDFILE);
} else {
	debugprint(10,"The Summaryfile cannot be read. Please check if the path is correct and the file is accually there.");
}
# my $slots_timeout = Irssi::timeout_add(600000, "send_ctcp_slots", ""); # Not implemented yet
$timeout_tag = Irssi::timeout_add(5000, "process_queue", "");	# Add a timeout value the process the queue
#my $bannertime = Irssi::settings_get_int('findbot_bannertime');
#$banner_timeout = Irssi::timeout_add($bannertime * 1000, "print_banner", ""); # Set timeout for banner
Irssi::print("Findbot script v$VERSION by $IRSSI{'authors'} loaded!"); # Show version and stuff when it has been loaded

if ( Irssi::settings_get_bool('findbot_enabled') ) {
	Irssi::print("Findserver is Online");
} else {
	Irssi::print("Findserver is Offline");
}
debugprint (5,"[ADMIN] Findbot fileserver has been loaded!");


#############################
# INSTALLATION INSTRUCTIONS
#############################
# - Making of the "findbot_summaryfile" and "findbot_sendlist"
# 	Run the perlscript below to create the summaryfile and sendlist
#
# - Install it in Irssi
# 	Put the script in your Irssi scripts directory (~.irssi/scripts)
# 	Start Irssi and load it. (/run findbot.pl)
# 	Now start setting all vital variables by using the command /set
#	set the "findbot_summaryfile" and "findbot_sendlist" to the files you just have created with
#	the perlscript below.
#	Dont forget to set all the other variables


####### Here is the script #########

# #!/usr/bin/perl 

# if not supplied on cmd line this is the values
#$MP3PATH = "/misc/glftpd/site/mp3/";
#$NICK    = "Donken";
#($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
#
#$year    = sprintf("%04d",$year+1900);
#$mon     = sprintf("%02d",$mon + 1);
#$mday    = sprintf("%02d",$mday);
#$DATE    = "$year-$mon-$mday";
#$LIST    = $NICK . "_mp3s_list.txt";
#$CMD     = $NICK . "_mp3s_cmd.txt";
#$padding = 50;	# How many pad-characters should it be
#
#if( "x" ne  "x$ARGV[0]" ){ $NICK    = $ARGV[0]; }
#if( "x" ne  "x$ARGV[1]" ){ $MP3PATH = $ARGV[1]; }
#if( "x" ne  "x$ARGV[2]" ){ $LIST    = $ARGV[2]; }
#if( "x" ne  "x$ARGV[3]" ){ $CMD     = $ARGV[3]; }
#
#print "Using nick: $NICK\n";
#print "Finding under supplied mp3path $MP3PATH\n";
#@INPUT=`find $MP3PATH -follow -type f`;
#print "Find done\n";
#print "Summaryfile: $LIST\n";
#print "Sendlist:    $CMD\n";
#
#print "Generating lists done/total mp3 files\n";
#open(LIST,">$LIST"); 
#open(CMD,">$CMD");
#
#print LIST "### List generated: $DATE I have a total of $#INPUT mp3s ###\n";
#print CMD  "### List generated: $DATE I have a total of $#INPUT mp3s ###\r\n";
#print CMD  "### This list was created by Findbot for Irssi\r\n";
#print CMD  "### http://irssi.org/scripts\r\n";
#
#$CHECKDIR=""; 
#$CNT=0;
#
## arrays start 0 and If I have 10 mp3 without +1 it would stat you have 9 ...
#$TOTAL = $#INPUT + 1; 
#
#sub padline {
#	$filename = shift;
#	$filelength = length($filename);
#	$paddchar = "=";
#	if ( $filelength <= $padding ) {
#		for ( $counter = $filelength; $counter < $padding; $counter++ ) {
#			$paddchar .= "=";
#		}
#	}
#	return $paddchar;
#}
#
#foreach( @INPUT ){
#        $CNT++; 
#	print "\r$CNT/" . $TOTAL;
#        chomp $_; 
#
#	$FILE=$_; 
#	$DIR=$_; 
#	$FILEwPATH=$_;
#
#        $FILE =~ s/.*\/(.*)/$1/g; # only the file
#        $DIR =~ s/(.*)\/.*/$1/g; # only the dir
#
#        $STAT_OF_FILE = `file -b "$FILEwPATH"`; # the info about the file
#	$STAT_OF_FILE =~ s#/##gio; # remove /
#        chomp $STAT_OF_FILE;
#
#        print LIST "$FILEwPATH : $STAT_OF_FILE\n"; # output to the LIST-file
#	if( "$DIR" ne "$CHECKDIR" ){ 
#	        # output to the CMD-file 
#		print CMD "\r\n=================================================\r\n";
#		$CHECKDIR = $DIR; print CMD "Files in $DIR\r\n"; 
#		print CMD "=================================================\r\n\r\n";
#	}
#        print CMD "!$NICK $FILE " . padline($FILE) . " $STAT_OF_FILE\r\n"; # output to the CMD-file
#}
#print CMD "EOF\r\n";
#print LIST "EOF\r\n";
#close LIST,CMD;
#print "\nList generation done\n";

