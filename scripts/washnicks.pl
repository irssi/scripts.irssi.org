# washnicks.pl
#
# Removes annoying characters from nicks
#
# TODO: 
#    - Don't use the function if only the first letter is upper case
#      

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;

$VERSION = '1.01';
%IRSSI = (
    authors	=> 'ulbkold',
    contact	=> 'solaris@sundevil.de',
    name	=> 'washnicks',
    description	=> 'Removes annoying characters from nicks',
    license	=> 'GPL',
    url		=> 'n/a',
    changed	=> '12 April 2002 14:44:11',
);

# Channel list
my @channels = ('#fof');

#main event handler
sub wash_nick {
  my ($server, $data, $nick, $address, $target) = @_;
  my ($channel, $msg) = split(/ :/, $data,2);

  # if the current channel is in the list...
   for (@channels) { 
     if ($_ eq $channel) {
       # ... check the nick 
       # if the nick contains one of these characters or upper case letters
       # enter the changing function
       if ( $nick =~/[A-Z]|\||\\|\]|\[|\^|-|\`|3|0|1|4|_/ ) {
	 $nick =~ s/\|//;
	 $nick =~ s/\\//;
	 $nick =~ s/\]//;
	 $nick =~ s/\[//;
	 $nick =~ s/\^//;
	 $nick =~ s/-//;
	 $nick =~ s/-//;
	 $nick =~ s/\`//;
	 $nick =~ s/3/e/;
	 $nick =~ s/0/O/;
	 $nick =~ s/1/i/;
	 $nick =~ s/4/a/;
	 $nick = lc($nick);
	 
	 # emit signal
	 Irssi::signal_emit("event privmsg", $server, $data,
			    $nick, $address, $target);
	 
	 #and stop
	 Irssi::signal_stop();
       }
     }
   } 
  
}


Irssi::signal_add('event privmsg', 'wash_nick');
