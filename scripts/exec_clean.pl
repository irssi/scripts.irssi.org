# $Id: exec-clean.pl,v 1.6 2002/07/04 13:18:02 jylefort Exp $

use strict;
use Irssi 20020121.2020 ();
use vars qw($VERSION %IRSSI);
$VERSION = "1.01";
%IRSSI = (
	  authors     => 'Jean-Yves Lefort',
	  contact     => 'jylefort\@brutele.be, decadix on IRCNet',
	  name        => 'exec-clean',
	  description => 'Adds a setting to automatically terminate a process whose parent window has been closed',
	  license     => 'BSD',
	  url         => 'http://void.adminz.be/irssi.shtml',
	  changed     => '$Date: 2002/07/04 13:18:02 $ ',
);

# /set's:
#
#	autokill_orphan_processes
#
#		guess :)
#
# changes:
#
#	2002-07-04	release 1.01
#			* signal_add's uses a reference instead of a string
#
#	2002-04-25	release 1.00
#			* increased version number
#
#	2002-01-28	initial release
#
# todo:
#
#	* kill the process using a better method (TERM -> sleep -> KILL etc)

use Irssi::UI;

sub window_destroyed {
  my ($window) = @_;

  foreach (Irssi::UI::processes()) {
    if ($_->{target_win}->{refnum} == $window->{refnum}
	&& Irssi::settings_get_bool("autokill_orphan_processes")) {
      kill 15, $_->{pid};
      return;
    }
  }
}

Irssi::signal_add("window destroyed", \&window_destroyed);
Irssi::settings_add_bool("misc", "autokill_orphan_processes", 1);
