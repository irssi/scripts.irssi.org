# DESCRIPTION
# Displays incoming ISDN calls to active window
# Looks even nicer with entries in 
# /etc/isdn/callerid.conf - see callerid.conf(5)
# 
# CHANGELOG
# 17.06.04
# Script now runs for several days without any
# problems. Added documentation.

use strict;
use Irssi;
use vars qw($VERSION %IRSSI); 
$VERSION = "0.3";
%IRSSI = (
        authors         => "Uli Baumann",
	contact         => "f-zappa\@irc-muenster.de",
	name            => "isdn",
	description     => "Displays incoming ISDN calls",
	license         => "GPL",
	changed	        => "Thu Jun 17 12:49:55 CEST 2004",
);

my $timer;

sub incoming_call()	# triggered by a timer; use of input_add
  {			# caused crash
  while (my $message = <ISDNLOG>)
    {
    chomp($message);
    if ($message =~ / Call to tei .* RING/)	# just incoming calls
      {
      my $from = $message;			# extract caller
      $from =~ s/.*Call to tei.*from (.*) on.*RING.*/$1/;
      my $to = $message;			# extract callee
      $to =~ s/.*Call to tei.*from .* on (.*)  RING.*/$1/;
      my $window = Irssi::active_win();		# write message to active win
      $window->print("%YISDN:%n call from $from");
      $window->print("      to $to");
      }     
    }
  }

sub isdn_unload()	# for a clean unload
  {
  close ISDNLOG;
  Irssi::timeout_remove($timer);
  }

# when starting, open the isdnlog file and set pointer to eof
open ISDNLOG, "< /var/log/isdn/isdnlog" or die "Can't open isdnlog";
seek ISDNLOG,0,2;
# install timeout for the incoming_call subroutine
$timer=Irssi::timeout_add(1000, \&incoming_call, \&args);

# disable timer and close file when script gets unloaded
Irssi::signal_add_first('command script unload','isdn_unload');

