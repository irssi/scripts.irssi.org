# /AUTOAWAY <n> - Mark user away after <n> seconds of inactivity
# /AWAY - play nice with autoaway
# New, brighter, whiter version of my autoaway script. Actually works :)
# (c) 2000 Larry Daffner (vizzie@airmail.net)
#     You may freely use, modify and distribute this script, as long as
#      1) you leave this notice intact
#      2) you don't pretend my code is yours
#      3) you don't pretend your code is mine
#
# share and enjoy!

# A simple script. /autoaway <n> will mark you as away automatically if
# you have not typed any commands in <n> seconds. (<n>=0 disables the feature)
# It will also automatically unmark you away the next time you type a command.
# Note that using the /away command will disable the autoaway mechanism, as
# well as the autoreturn. (when you unmark yourself, the autoaway wil
# restart again)

# Thanks to Adam Monsen for multiserver and config file fix

use Irssi;
use Irssi::Irc;

use vars qw($VERSION %IRSSI);
$VERSION = "0.3";
%IRSSI = (
    authors => 'Larry "Vizzie" Daffner',
    contact => 'vizzie@airmail.net',
    name => 'Automagic away setting',
    description => 'Automatically goes  away after defined inactivity',
    license => 'BSD',
    url => 'http://www.flamingpackets.net/~vizzie/irssi/',
    changed => 'Tue Oct 19 14:41:15 CDT 2010',
    changes => 'Applied multiserver/store config patch from Adam Monsen'
);

my ($autoaway_sec, $autoaway_to_tag, $autoaway_state);
$autoaway_state = 0;

#
# /AUTOAWAY - set the autoaway timeout
#
sub cmd_autoaway {
  my ($data, $server, $channel) = @_;
  
  if (!($data =~ /^[0-9]+$/)) {
    Irssi::print("autoaway: usage: /autoaway <seconds>");
    return 1;
  }
  
  $autoaway_sec = $data;
  
  if ($autoaway_sec) {
    Irssi::settings_set_int("autoaway_timeout", $autoaway_sec);
    Irssi::print("autoaway timeout set to $autoaway_sec seconds");
  } else {
    Irssi::print("autoway disabled");
  }
  
  if (defined($autoaway_to_tag)) {
    Irssi::timeout_remove($autoaway_to_tag);
    $autoaway_to_tag = undef;
  }

  if ($autoaway_sec) {
    $autoaway_to_tag =
      Irssi::timeout_add($autoaway_sec*1000, "auto_timeout", "");
  }
}

#
# away = Set us away or back, within the autoaway system
sub cmd_away {
  my ($data, $server, $channel) = @_;
  
  if ($data eq "") {
    $autoaway_state = 0;
    # If $autoaway_state is 2, we went away by typing /away, and need
    # to restart autoaway ourselves. Otherwise, we were autoaway, and
    # we'll let the autoaway return take care of business.

    if ($autoaway_state eq 2) {
      if ($autoaway_sec) {
	$autoaway_to_tag =
	  Irssi::timeout_add($autoaway_sec*1000, "auto_timeout", "");
      }
    }
  } else {
    if ($autoaway_state eq 0) {
      Irssi::timeout_remove($autoaway_to_tag);
      $autoaway_to_tag = undef;
      $autoaway_state = 2;
    }
  }
}

sub auto_timeout {
  my ($data, $server) = @_;

  # we're in the process.. don't touch anything.
  $autoaway_state = 3;
  foreach my $server (Irssi::servers()) {
      $server->command("/AWAY autoaway after $autoaway_sec seconds");
  }

  Irssi::timeout_remove($autoaway_to_tag);
  $autoaway_state = 1;
}

sub reset_timer {
   if ($autoaway_state eq 1) {
     $autoaway_state = 3;
     foreach my $server (Irssi::servers()) {
         $server->command("/AWAY");
     }
     
     $autoaway_state = 0;
   } 
  if ($autoaway_state eq 0) {
    if (defined($autoaway_to_tag)) {
      Irssi::timeout_remove($autoaway_to_tag);
      $autoaway_to_tag = undef();
    }
    if ($autoaway_sec) {
      $autoaway_to_tag = Irssi::timeout_add($autoaway_sec*1000
					    , "auto_timeout", "");
    }
  }
}

Irssi::settings_add_int("misc", "autoaway_timeout", 0);

$autoaway_default = Irssi::settings_get_int("autoaway_timeout");
if ($autoaway_default) {
  $autoaway_to_tag =
    Irssi::timeout_add($autoaway_default*1000, "auto_timeout", "");

}

Irssi::command_bind('autoaway', 'cmd_autoaway');
Irssi::command_bind('away', 'cmd_away');
Irssi::signal_add('send command', 'reset_timer');
