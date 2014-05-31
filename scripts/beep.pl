# $Id: beep.pl,v 1.9 2002/07/04 13:18:02 jylefort Exp $

use Irssi 20020121.2020 ();
$VERSION = "1.01";
%IRSSI = (
	  authors     => 'Jean-Yves Lefort',
	  contact     => 'jylefort\@brutele.be, decadix on IRCNet',
	  name        => 'beep',
	  description => 'Replaces your terminal bell by a command specified via /set; adds a beep_when_not_away setting',
	  license     => 'BSD',
	  url         => 'http://void.adminz.be/irssi.shtml',
	  changed     => '$Date: 2002/07/04 13:18:02 $ ',
);

# /set's:
#
#	beep_when_not_away	opposite of builtin beep_when_away
#
#	beep_command		if not empty, the specified command will be
#				executed instead of the normal terminal bell
# changes:
#
#	2002-07-04	release 1.01
#			* signal_add's uses a reference instead of a string
#
#	2002-04-25	release 1.00
#			* increased version number
#
#	2002-01-24	initial release

use strict;

sub beep {
  my $server = Irssi::active_server;
  if ($server && ! $server->{usermode_away}
      && ! Irssi::settings_get_bool("beep_when_not_away")) {
    Irssi::signal_stop();
  } else {
    if (my $command = Irssi::settings_get_str("beep_command")) {
      system($command);
      Irssi::signal_stop();
    }
  }
}

Irssi::settings_add_bool("lookandfeel", "beep_when_not_away", 0);
Irssi::settings_add_str("misc", "beep_command",
			"esdplay ~/sound/events/beep.wav &");

Irssi::signal_add("beep", \&beep);
