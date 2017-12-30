#
# 2017-12-30 bcattaneo:
#  - initial release
#

use Irssi;
use Irssi::Irc;
use strict;
use vars qw($VERSION %IRSSI);

#
# List of commands:
#	/np - now playing
#	/ddplay - Start playback
#	/ddstop - Stop playback
#	/ddpause - Pause playback
#	/ddnext - Next song in playlist
#	/ddprev - Previous song in playlist
#	/ddrandom - Random song in playlist
#
# Settings:
#	/set deadbeef_format [Formatting syntax for "now playing" command]
# For more info, see https://github.com/DeaDBeeF-Player/deadbeef/wiki/Title-formatting
#

our $VERSION = '1.0.0';
our %IRSSI = (
  authors     => 'bcattaneo',
  contact     => 'c@ttaneo.uy',
  name        => 'deadbeef',
  url         => 'http://github.com/bcattaneo',
  description => 'deadbeef control and now playing script',
  license     => 'Public Domain',
  #changed     => "2017-12-30",
);

Irssi::settings_add_str('deadbeef', 'deadbeef_format' => '%a - %t');

my $deadbeef = "deadbeef.pl";

#########################
## Now playing command ##
#########################
sub now_playing {
	my ($data, $server, $witem) = @_;
	my $format = Irssi::settings_get_str('deadbeef_format');
	my $output = (split("\n",`deadbeef --nowplaying "$format" 2>&1`))[-1];

	if ($output ne "nothing" )
	{
		if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY"))
		{
			$witem->command("me nowplaying: $output")
		}
		else
		{
			Irssi::print("%_$deadbeef%_ - Not a channel/query!");
		}
	}
	else
	{
		Irssi::print("%_$deadbeef%_ - Play something!");
	}
}

##############
## Controls ##
##############
sub play {
	system("deadbeef --play &> /dev/null");
}

sub stop {
	system("deadbeef --stop &> /dev/null");
}

sub pause {
	system("deadbeef --pause &> /dev/null");
}

sub next {
	system("deadbeef --next &> /dev/null");
}

sub prev {
	system("deadbeef --prev &> /dev/null");
}

sub random {
	system("deadbeef --prev &> /dev/null");
}

#####################
## Command binding ##
#####################
Irssi::command_bind('np', 'now_playing');
Irssi::command_bind('dbplay', 'play');
Irssi::command_bind('dbstop', 'stop');
Irssi::command_bind('dbpause', 'pause');
Irssi::command_bind('dbnext', 'next');
Irssi::command_bind('dbprev', 'prev');
Irssi::command_bind('dbrandom', 'random');
