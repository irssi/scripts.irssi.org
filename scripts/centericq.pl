# $Id: centericq.pl,v 1.0.0 2002/10/19 13:15:49 Garion Exp $
use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "1.0.0";
%IRSSI = (
    authors     => "Joost \"Garion\" Vunderink",
    contact     => "joost\@carnique.nl",
    name        => "centericq",
    description => "Staturbar item which indicates how many new messages you have in your centericq",
    license     => "Public Domain",
    url         => "http://irssi.org, http://scripts.irssi.org",
);

# centericq new messages statusbar item
# for irssi 0.8.4 by Timo Sirainen
#
# This statusbar item checks whether you have unread messages in
# ~/.centericq/, and if so, displays a status in your statusbar.
# Example status: [ICQ: JamesOff-1,Linn-3,Paul-4]
#
# Use:
# /script load centericq
# /statusbar <name> add centericq
#
# Known bugs:
# - It only works for ICQ and MSN in centericq.
# - The refreshing is not optimal. You'll need to swap windows to make
#   the statusbar item disappear if you've read the messages.
# - You have to reload the script if you add new people in centericq.
# - Works only with centericq in ~/.centericq/
#
# TODO:
# - Use only the first N letters of the nickname instead of the full
#   nickname.

use Irssi;
use Irssi::TextUI;

my $icqdir = $ENV{'HOME'} . "/.centericq";
my ($last_refresh_time, $refresh_tag);
my $statusbar_item;

# The following vars are all hashes with key the name of the dir in
# ~/.centericq/ of that person
 
my %lastreads;    # Timestamp of the last read message, per nick
my %numunreads;   # Number of unread messages, per nick
my %historyts;    # Timestamp of the history file of each nick
my %lastreadts;   # Timestamp of the lastread file of each nick
my %friendnicks;  # The nicknames of the friends


#######################################################################
# This is the function that will be called each N seconds, where
# N is given by the centericq_refresh_time setting.

sub refresh_centericq {
  check_new_friends();

  my @friends = keys(%lastreads);
  my ($friend, $changed) = ("", 0);
  foreach $friend (@friends) {
    if (history_changed($friend) || lastread_changed($friend)) {
      $changed = 1; 
      update_status($friend);
    }
  }

  if ($changed) {
    update_statusbar_item();
  }

  # Adding new timeout to make sure that this function will be called
  # again
  if ($refresh_tag) {
    Irssi::timeout_remove($refresh_tag)
  }
  my $time = Irssi::settings_get_int('centericq_refresh_time');
  $refresh_tag = Irssi::timeout_add($time*1000, 'refresh_centericq', undef);
}


#######################################################################
# Checks if any new friends have been added. Not yet functional.

sub check_new_friends {
  #Irssi::print("Checking if there are any new friends...");
}

#######################################################################
# Checks if the last modified date/time of the lastread file has changed.
# A -lot- more efficient than reading and processing the whole file :)

sub lastread_changed {
  my ($friend) = @_;

  my $lr = get_lastread($friend);
  if ($lr != $lastreads{$friend}) {
    #Irssi::print("Lastread of $friendnick{$friend} changed from $lastreads{$friend} to $lr.");
    $lastreads{$friend} = $lr;
    return 1;
  }

  return 0;
}

#######################################################################
# Checks if the last modified date/time of the history file has changed.
# A -lot- more efficient than reading and processing the whole file :)

sub history_changed {
  my ($friend) = @_;
  my $ts = get_historyts($friend);
  if ($ts != $historyts{$friend}) {
    #Irssi::print("History ts of $friendnick{$friend} changed from $historyts{$friend} to $ts.");
    $historyts{$friend} = $ts;
    return 1;
  }

  return 0;
}

#######################################################################
# Reads the last read message and determines the number of unread
# messages of $friend.

sub update_status {
  my ($friend) = @_;
  $lastreads{$friend}   = get_lastread($friend);
  $numunreads{$friend}  = get_numunreads($friend);
}

#######################################################################
# Gets the number of unread messages of all nicks and puts them together
# in a nice statusbar string.
# It then requests a statusbar item redraw.

sub update_statusbar_item {
  #Irssi::print("Updating statusbaritem...");
  $statusbar_item = "";

  my @keys = keys(%lastreads);
  my ($key, $status);

  foreach $key(@keys) {
    if ($numunreads{$key} > 0) {
      #Irssi::print("$friendnick{$key} has $numunreads{$key} unreads.");
      $status .= $friendnicks{$key} . "-" . $numunreads{$key} . ",";
    }
  }
  $status =~ s/,$//;
  if (length($status) > 0) {
    $statusbar_item = "ICQ: " . $status; 
    Irssi::statusbar_items_redraw('centericq');
  }
}


#######################################################################
# This is the function called by irssi to obtain the statusbar item
# for centericq.

sub centericq {
  my ($item, $get_size_only) = @_;

  if (length($statusbar_item) == 0) {
    # no icq - don't print the [ICQ] at all
    if ($get_size_only) {
      $item->{min_size} = $item->{max_size} = 0;
    }
  } else {
    $item->default_handler($get_size_only, undef, $statusbar_item, 1);
  }
}

#######################################################################
# Initialization of the hashes with the useful data.

sub init {
  if (!opendir(ICQDIR, $icqdir)) {
    Irssi::print("There is no directory $icqdir, which is needed for this script.");
    return 0;
  }
 
  my ($icqfriends, $msnfriends) = (0, 0); 
  while (my $filename = readdir(ICQDIR)) {
    # ICQ friends
    if ($filename =~ /^[0-9]+$/ && $filename !~ /^0$/) {
      $icqfriends++;
      init_friend($filename);
    }
    # MSN friends
    if ($filename =~ /^m.+/ && $filename !~ /^modelist$/ ) {
      $msnfriends++;
      init_friend($filename);
    }
  }
  Irssi::print("Watching $icqfriends ICQ friends and $msnfriends MSN friends.");

  closedir(ICQDIR);
  return 1;
}

#######################################################################
# Initialises all data of $friend

sub init_friend {
  my ($friend) = @_;

  $lastreads{$friend}   = get_lastread($friend);
  $numunreads{$friend}  = get_numunreads($friend);
  #$filesizes{$friend}   = get_filesize($friend);
  $friendnicks{$friend}  = get_nickname($friend);
  $historyts{$friend}   = get_historyts($friend);
  #Irssi::print("Initilialized $friendnick{$friend}.");
}

#######################################################################
# Returns the last read message of $friend

sub get_lastread {
  my ($friend) = @_;
  my $lastreadfile = $icqdir . "/" . $friend . "/lastread"; 

  open(F, "<", $lastreadfile) || return 0; #die("Could not open $lastreadfile.");;
  my $lastrd = <F>;
  close(F);
  chop($lastrd);
  #Irssi::print("Found lastread $lastrd of $friend from $lastreadfile.");

  return $lastrd;
}

#######################################################################
# Returns the number of unread messages for $friend

sub get_numunreads {
  my ($friend) = @_;
  my $lr = $lastreads{$friend};
  # Unknown last read message - return 0.
  if ($lr == 0) {
    return 0;
  }

  my $msgfile = $icqdir . "/" . $friend . "/history";
  open(F, "<", $msgfile) || return 0; #die("Could not open $msgfile.");
  my @lines = <F>;
  chop(@lines);
  close(F);

  my $numlines = @lines;

  # read all lines up to the lastread message
  my $line;
  my $bla = 0;
  do {
    $line = shift(@lines);
    $bla++;
  } while ($line ne $lr);
  
  # now count the number of times that "MSG" is found on a line below
  # a line with "IN"
  my $count = 0;
  my $incoming = 0;
  my $verify = 0;
  my $bli = 0;
  
  for (@lines) {
    $bli++;
    # Sometimes 2 messages get in at the same time. Remove this so-called
    # new message if it has the same time as the last read message.
    if ($verify == 1) {
      if ($_ =~ /$lr/) {
        $count--;
      }
      $verify = 0;
    }
    # A line with "IN" has been found; check if the next line is "MSG".
    if ($incoming == 1) {
      if ($_ =~ /^MSG/) {
        $count++;
	$verify = 1;
      }
      $incoming = 0;
    }
    # Check for "IN".
    if ($_ =~ /^IN/) {
      $incoming = 1;
    }
  }

  return $count;
}

#######################################################################
# Returns the nickname of a friend. This is taken from the 46th line
# of the info file. Let's hope that centericq does not change its
# config file format.

sub get_nickname {
  my ($friend) = @_;

  my $infofile = $icqdir . "/" . $friend . "/info";
  open(F, "<", $infofile) || return $friend; #die("Could not open $msgfile.");
  my @lines = <F>;
  chop(@lines);
  close(F);
 
  return $lines[45];
}

#######################################################################
# Returns the timestamp of the history file of $friend.

sub get_historyts {
  my ($friend) = @_;
  my $histfile = $icqdir . "/" . $friend .  "/history";
  my @stat = stat($histfile);
  return $stat[9];
}

#######################################################################
# Adding stuff to irssi

Irssi::settings_add_int('misc', 'centericq_refresh_time', 120);
#Irssi::settings_add_bool('misc', 'centericq_debug', 0);
Irssi::statusbar_item_register('centericq', '{sb $0-}', 'centericq');

#######################################################################
# Startup functions

if (init() == 0) {
  Irssi::print("You need centericq for this script.");
  return 0;
}
update_statusbar_item();
refresh_centericq();

Irssi::print("Centericq statusbar item loaded.");

#######################################################################
