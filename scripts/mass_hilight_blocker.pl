# disable hilighting of mass-hilights
# (messages which contain a lot of nicknames)
#
# DESCRIPTION
# sometimes a jester annoys a channel with a message
# containing a lot of nicks that are in that channel. 
# this script prevents hilighting of a window in this
# case. number of nicks in the message is user
# configurable in the variable mass_highlight_threshold.
# 
# CHANGELOG
# * 01.05.2004
# fixed problems with nicks containing brackets
# added comments, description and this changelog :)
# * 30.05.2004
# first version of the script

use strict;
use Irssi;
use vars qw($VERSION %IRSSI); 
$VERSION = "0.4";
%IRSSI = (
        authors         => "Uli Baumann",
	contact         => "f-zappa\@irc-muenster.de",
	name            => "mass_hilight_blocker",
	description     => "Disables hilighting for messages containing a lot of nicknames",
	license         => "GPL",
	changed	        => "Sun Nov 11 15:30:00 CET 2018",
);


sub sig_printtext {
  my ($dest, $text, $stripped) = @_;	# our parameters
  my $window = $dest->{window};		# where irssi wants to output
  my $num_nicks=-1;			# don't count target's nick
  my $max_num_nicks=Irssi::settings_get_int('mass_hilight_threshold');

  if ($dest->{level} & MSGLEVEL_HILIGHT)# we solely look at hilighted messages
    {
      my $server  =  $dest->{server};	# get server and channel for target
      my $channel =  $server->channel_find($dest->{target});
      
      foreach my $nick ($channel->nicks()) # walk through nicks
        {
          $nick = $nick->{nick};
          if ($text =~ /\Q$nick/)		# does line contain this nick?
            {$num_nicks++;}		# then increase counter
        }
      
      if ($num_nicks>=($max_num_nicks)) # all criteria match?
        {
          $dest->{level} = MSGLEVEL_CLIENTCRAP;
          Irssi::signal_continue($dest, $text, $stripped);		# continue with changed level
          $window->print('mass-hilighting in above message ('.$num_nicks.' nicks)',MSGLEVEL_CLIENTCRAP);
        }
    }
}

# tell irssi to use this and initialize variable if necessary

Irssi::signal_add_first('print text', 'sig_printtext');
Irssi::settings_add_int('misc','mass_hilight_threshold',3);
