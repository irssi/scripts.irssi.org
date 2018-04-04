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

$VERSION = '1.02';
%IRSSI = (
    authors	=> 'ulbkold',
    contact	=> 'solaris@sundevil.de',
    name	=> 'washnicks',
    description	=> 'Removes annoying characters from nicks',
    license	=> 'GPL',
    url		=> 'n/a',
    changed	=> '2018-04-04',
);

# Channel list
my @channels;

#main event handler
sub wash_nick {
  my ($server, $data, $nick, $address, $target) = @_;
  my ($channel, $msg) = split(/ :/, $data,2);
  my $oldnick=$nick;

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
	 $nick =~ s/_//;
	 $nick =~ s/\`//;
	 $nick =~ s/3/e/;
	 $nick =~ s/0/O/;
	 $nick =~ s/1/i/;
	 $nick =~ s/4/a/;
	 $nick = lc($nick);
	 
         # fail safe
         if ($oldnick ne $nick) {
           # emit signal
           Irssi::signal_emit("event privmsg", $server, $data,
                  $nick, $address, $target);

           #and stop
           Irssi::signal_stop();
         }
       }
     }
   } 
  
}

Irssi::settings_add_str('washnicks', 'washnicks_channels', '#fof');

sub update_config {
  @channels=split(/ /,Irssi::settings_get_str('washnicks_channels'));
}

update_config();

Irssi::signal_add('setup changed', 'update_config');
Irssi::signal_add('event privmsg', 'wash_nick');
