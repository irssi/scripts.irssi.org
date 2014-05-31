# This script was originally written by Mike McDonald of 
# FoxChat.Net for the X-Chat Client to be used by Opers 
# to Kline/kill spam bots that message you  or say in 
# open channel -
# "Come watch me on my webcam and chat /w me :-) http://some.domain.com/me.mpg".
# 
# This is my first script so I'm sure there is a more
# efficient way of doing this.
#
# --------[ Note ]-------------------------------------------------------------
# I symlink this to my ~/.irssi/scripts/autorun
# Just know that it will not work if you are not op'd.
#
#------------------------------------------------------------------------------

use Irssi;
use strict;
use vars qw($VERSION %IRSSI $SCRIPT_NAME);

%IRSSI = (
    authors       => 'Daemon @ ircd.foxchat.net',
    name          => 'Spam Bot Killer',
    description   => 'Oper script to kill Spam Bots.',
    license       => 'Public Domain'
);
($VERSION) = '$Revision: 1.2 $' =~ / (\d+\.\d+) /;

$SCRIPT_NAME = 'Spam Bot Killer';

# ======[ Credits ]============================================================
#
# Thanks to:
#
# Mike - For letting me use parts of his bot_killer.pl which was written for 
# the X-Chat client.
#
# Garion - Let me use parts of his "ho_easykline" to make this work with 
# Irssi and gave me - 
# return unless $server->{server_operator};
# so the script won't try to run if you aren't oper'd.
#
# mannix and lestefer of ircd.foxchat.net for letting me kline them :)
#
#------------------------------------------------------------------------------
    sub event_privmsg
    {
    # $data = "nick/#channel :text"
        my ($server, $data, $nick, $host, $user, $address) = @_;
	

	# Set Temp K-Line time here in minutes.
	my $klinetime = 1440;
	my $msg = "Spamming is lame ... go spam somewhere else.";
        my ($target, $text) = split(/ :/, $data, 2);

        if ($text =~ /chat \/w me/ || / \/me.mpg/)
        {
# --------[ Notice ]-----------------------------------------------------------
	  # Uncomment this line if you  don't want to use temp klines 
	  # and comment the following line.

	  # $server->command("quote kline $host :$msg");

	    $server->command("quote kline $klinetime $host :$msg");

#------------------------------------------------------------------------------

	      Irssi::print("K-lined $nick :$msg");

	  # Do a Kill in case they are on another server 
	  # and the local Kline doesn't get them.

	  $server->command("quote kill $nick :$msg");
        }
    }

Irssi::signal_add("event privmsg", "event_privmsg");

Irssi::print("\00311::          Spam Bot Killer loaded              ::\003\n");
Irssi::print("\00311::You can only use this script if you are Oper. ::\003\n");
