#####################
#
# irssi autoreminder script.
# Copyright (C) Terry Lewis
# Terry Lewis <mrkennie@kryogenic.co.uk>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#####################
#
# Auto reminder script for irssi
# This is really a first attempt at an irssi script,
# really more of a hack I suppose, to auto remind 
# someone at certain intervals.
# It will not remind at every interval defined, so its 
# kinda less annoying, but hopefully effective.
#
# To start:
#     /start <nick> <"reminder message"> [interval] 
#     (<> = required, [] = optional)
# reminder Message must use "" parenthasis.
#
# to stop reminding use /stop
#
# I know the code is not fantastic but I will appreciate
# any patches for improvements, just mail them to me if
# you do improve it :)
#
# I use a rather nice script called cron.pl by Piotr 
# Krukowiecki which I found at http://www.irssi.org/scripts/
# so I can start and stop the script at certain times.
# I hope someone finds this useful, Enjoy =)
#
#####################

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '0.01';
%IRSSI = (
    authors     => 'Terry Lewis',
    contact     => 'terry@kryogenic.co.uk',
    name        => 'Auto Reminder',
    description => 'This script ' .
                   'Reminds people ' .
                   'to do stuff! :)',
    license     => 'GPLv2',
);

my($timeout_tag, $timeout, $state, @opts, $date, @time, @hour, $start_hour, $end_hour);


#default state 0 meaning we are not started yet
$state = 0;


# /start <nick> <"message"> [interval]
sub cmd_start {
    if($state != 1){
        my($data,$server,$channel) = @_;
        @opts = split(/\s\B\"(.*)\b\"/, $data);
	
	if($opts[0] ne ''){  
	    if($opts[1] ne ''){
	        if($opts[0] =~ /\s/g){
	            Irssi::print("Invalid username");
            	}elsif($opts[1] eq ''){
	            Irssi::print("You must type a message to send");
                }else{
	        
	            $state = 1;

	            if($opts[2] =~ /[0-9]/g){
		        $opts[2] =~ s/\s//g;
		        $timeout = $opts[2];
                        timeout_init($timeout);
	            }else{
		        Irssi::print("Invalid interval value, using defaults (15mins)") unless $opts[2] eq '';
		        $timeout = "900000";
		        timeout_init($timeout);
		    }
		    Irssi::print "Bugging $opts[0] with message \"$opts[1]\" every \"$timeout ms\"";
	        }
            }else{
	         Irssi::print ("Usage: /start nick \"bug_msg\" [interval] (interval is optional)");
	    }
	}else{
	    Irssi::print ("Usage: /start nick \"bug_msg\" [interval] (interval is optional)");
	}
	
    }else{
        Irssi::print "Already started";
    }
}

# /stop
sub cmd_stop {
    if($state == 1){
        $state = 0;
	Irssi::print "No longer bugging $opts[0]";
	Irssi::timeout_remove($timeout_tag);
	$timeout_tag = undef;
    }else{
      Irssi::print "Not started";
    }
}

sub timeout_init {
    if($state == 1){
    
        Irssi::timeout_remove($timeout_tag);
        $timeout_tag = undef;
        $timeout_tag = Irssi::timeout_add($timeout, "remind_them", "");
    }
}

sub remind_them {
    if($state == 1){
        my (@servers) = Irssi::servers();    
        
	# make it random, so we dont remind at every defined interval
        my $time = rand()*3;

        if($time < 1){
            $servers[0]->command("MSG $opts[0] Hi, this is an automated reminder, $opts[1]");
	}
        timeout_init($timeout);
    }
}


Irssi::command_bind('start', \&cmd_start);
Irssi::command_bind('stop', \&cmd_stop);

