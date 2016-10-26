# Copyright (C) 02 October 2001  Author FoxMaSk <foxmask@phpfr.org>
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
#============================================================================
# This script manage a list of keywords 
# with their definition...
# The file, named "doc", is composed as follow : 
# keyword=definition
#
# Then, anyone on the channel can query the file and  
# if the keyword exists the script displays the definition, 
# if not ; the script /msg to $nick an appropriate message
#
# You can also, Add ; Modify or Delete definitions ; 
# but only *known* people can do it...
#
# To install it ; put the script in ~/.irssi/scripts and then 
# cd to autorun and make ln -s ../doc.pl .
#================================WARNING======================================
# Requirement : script friends.pl (http://irssi.atn.pl/friends/) version 2.3
# this one permit us to identify people who can  
# addd/modify/delete records in the file
#=============================================================================
#
# History : 
# Before using irssi and make this script ; i used (and continue to use)
# an eggdrop that use this feature of querying the file to help anyone
# on the channel to find online help on demand.
#
# Now :
# I will try to merge all my tcl scripts (that i use with my egg) for irssi.
# Then, irssi will be able to react _as_ an eggdrop, but with more functions.
#
# Todo : 
# 1)  make it work on multi-channel 
#
# Update :
# 
# make it work with latest friends.pl (http://irssi.atn.pl/friends/) version 2.3
#
# get_idx() give me the state "Friends or Not ?"
# instead of old is_friends() function
# 
#
# 2003/01/09
# changes Irssi::get_irssi_dir()."/doc"; instead of $ENVENV{HOME}/.irssi/doc";
# thanks to Wouter Coekaerts

use Irssi::Irc;
use Irssi;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "0.0.3"; 
%IRSSI = (
    authors => 'FoxMaSk',
    contact => 'foxmask@phpfr.org ',
    name => 'doc',
    description => 'manage tips ; url ; help in a doc file in the keyword=definition form',
    license => 'GNU GPL',
    url => 'http://team.gcu-squad.org/~odemah/'
);

#name of the channel where this feature will be used
my $channel   = "#phpfr";

#commands that manage the "doc" script
#query
my $cmd_query = "!doc";
#add
my $cmd_add   = "!doc+";
#delete
my $cmd_del   = "!doc-";
#modify
my $cmd_mod   = "!doc*";

#file name to store data
my $doc_file = Irssi::get_irssi_dir()."/doc";

#==========================END OF PARMS======================================

#init array
my @doc = ();
my $x = 0;

#The main function
sub doc_find {
    my ($server, $msg, $nick, $address, $target) = @_;

    my $keyword="";
    my $new_definition="";
    my $definition="";

    #flag if keyword is found
    my $find="";

    #*action* to do
    my $cmd="";
    #the string behind *action*
    my $line="";

    #to display /msg 
    my $info="";

    #split the *action* and the rest of the line
    ($cmd,$line) = split / /,$msg,2;

    if ($target eq $channel) {

        #to query
        if ($cmd eq $cmd_query) {
            $keyword = $line;
            
           ($find,$definition) = exist_doc($keyword);
            
            if ($find ne '') {
                my $newmsg = join("=",$keyword,$definition);
                $server->command("notice $target $newmsg");
            }
            #definition not found ; so we tell it to $nick
            else { 
                $info="$nick $keyword does not exist";
                info_doc($server,$info);
            }
        }

        else {
        #call of friends.pl script to determine if the current
        #$nick can manage the doc file
        #to add
            if ($cmd eq $cmd_add and Irssi::Script::friends::get_idx($channel,$nick,$address) != -1) {
                ($keyword,$new_definition) = split /=/,$line,2;
                ($find,$definition) = exist_doc($keyword);
            
                #definition not found ; so we add it
                if ($find eq '') { 
                    push(@doc,"$keyword=$new_definition");
                    save_doc();
                    $info="$nick added, thank you for your contribution";
                    info_doc($server,$info);

                #definition found ; so we tell it to the $nick
                } else {
                    $info="$nick $keyword already exists";
                    info_doc($server,$info);
                }
            }
            #to modify
            elsif ($cmd eq $cmd_mod and Irssi::Script::friends::get_idx($channel,$nick,$address) != -1) {
                ($keyword,$new_definition) = split /=/,$line,2;
                ($find,$definition) = exist_doc($keyword);
                 
                #definition not found ; so we can't modify it
                if ($find eq '') { 
                    $info="$nick $keyword does not exists, can not be modified";
                    info_doc($server,$info);
                } else {
                    del_doc($keyword) ;
                    push(@doc,"$keyword=$new_definition");
                    save_doc();
                    $info="$nick modified, thank you for your contribution";
                    info_doc($server,$info);
                }
            }
            #to delete
            elsif ($cmd eq $cmd_del and Irssi::Script::friends::get_idx($channel,$nick,$address) != -1) {
                    $keyword = $line;
                    ($find,$definition) = exist_doc($keyword);
                    if ($find ne '') {
                        del_doc($keyword);
                        save_doc();
                        $info="$nick definition has been removed";
                        info_doc($server,$info);
                    }
                    else {
                        $info="$nick $keyword does not exist, can't be deleted";
                        info_doc($server,$info);
                    }
            }

        }
    }
}


#load datas
sub load_doc {
    my $doc_line="";
    if (-e $doc_file) {
        @doc = ();
		Irssi::print("Loading doc from $doc_file");
        local *DOC; 
        open(DOC, q{<}, $doc_file);
        local $/ = "\n";
        while (<DOC>) { 
            chop(); 
            $doc_line = $_;
            push(@doc,$doc_line); 
        }
        close DOC;
		Irssi::print("Loaded " . scalar(@doc) . " record(s)");
	} else {
		Irssi::print("Cannot load $doc_file");
	}
}

#remove data
sub del_doc {
    my ($keyword) = @_;
    my $key_del="";
    my $def_del="";
    for ($x=0;$x < @doc; $x++) {
        ($key_del,$def_del) = split /=/,$doc[$x],2;
        if ( $key_del eq $keyword ) {
            splice (@doc,$x,1);
            last;
        }
    }
}

#store data inf "doc" file
sub save_doc {
    my $keyword=""; 
    my $definition="";
    if (-e $doc_file) {
        open(DOC, q{>}, $doc_file);
        for ($x=0;$x < @doc;$x++) {
            ($keyword,$definition) = split /=/,$doc[$x],2;
            print DOC "$keyword=$definition\n";
        }
        close DOC;
    }
}

#search if keyword already exists or not
sub exist_doc {
    my ($keyword) = @_;
    my $key="";
    my $def="";
    my $find="";
    for ($x=0;$x < @doc;$x++) {
        ($key,$def) = split /=/,$doc[$x],2;
        if ($key eq $keyword) {
            $find = "*";
            last;   
        }
    }
    return $find,$def;
}

#display /msg to $nick
sub info_doc {
    my ($server,$string) = @_;
    $server->command("/msg $string");
    Irssi::signal_stop();
}

load_doc();

Irssi::signal_add_last('message public', 'doc_find');
Irssi::print("Doc Management $VERSION loaded!");

