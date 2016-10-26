#!/usr/bin/perl

# amaroknp.pl (0.1)

# This is a simple script for irssi which (attempts to) show the current song played
# by amaroK in the current channel or query window. It should output something like
# this: <@mynick> np: Artist - Song (1:34 / 4:05). This script has been tested to work 
# with amaroK 0.9, KDE 3.2.1 and irssi 0.8.9 (on Linux). Might not work with older
# versions of amaroK.

# !! The only thing you might want to change is $dcopbin (line 45) !!
# !! and the format of $output (line 102) !!
 
# TODO
# - Cleaning up this mess :)
# - Setting options
# - Simple controls (play, pause, next, previous..)

use vars qw($VERSION %IRSSI);
use Irssi;
use strict;
$VERSION = '0.10';
%IRSSI = (
    authors	=> 'Tuukka Lukkala',
    contact	=> 'ragdim at mbnet dot fi',
    name	=> 'amaroknp',
    description	=> 'Shows the song playing in amaroK in the active window (channel or query).',
    license	=> 'GPL',
    url		=> 'http://koti.mbnet.fi/ragdim/amaroknp/',
    changed	=> 'Tue Mar 30 23:20 EET 2004',
);

# !! Adjust this to the full path of dcop if it's not in your PATH. eg. /opt/kde/bin/dcop !!
my $dcopbin = "dcop";

# Let's check if we have dcop..
if (!`$dcopbin`) {
	die "Couldn't find dcop executable.. Make sure dcop is in your PATH or edit dcoppath in the script";
}

sub cmd_amaroknp_help {

print "";
print "amaroknp script v0.1 for irssi";
print "To announce the current song, type: /amarok";
print "Requires KDE and amaroK";
print "";

}

sub cmd_amaroknp {

	my ($data, $server, $witem) = @_;
	my $playing; 			# Whether amaroK is playing something or not
	my $song; 			# The song currently playing
	my $timenow;			# Current position in the song
	my $timetotal;			# Total length of teh song
	my $minutes;			# Current time converted to full minutes
	my $seconds;			# Current time converted to seconds
	my $minutestotal;		# Total amount of minutes
	my $secondstotal;		# Total amount of seconds
	my $output;			# The format in which all this is going -> channel
	my $amaroktest;			# To see if amarok is running or not
	my $amarokNOTrunning;		# Don't ask me.. :z

	# ..and if amaroK is running (fix)
	$amaroktest = `$dcopbin amarok 2> /dev/null`;
	chomp($amaroktest);
	if ($amaroktest =~ s/^$/No such application: 'amarok'/) {
		print "amaroK isn't running?";
		$amarokNOTrunning="nope";
	}
	# if amaroK is running, let's get teh infos!
	if (!$amarokNOTrunning) {
		$playing = `$dcopbin amarok default isPlaying`;
		chomp($playing);
		if ($playing eq 'false') {
		print "amaroK isn't playing anything =I";
		}

		else {
			# Get some infos
			$song = `$dcopbin amarok default nowPlaying`;
			chomp($song);
			$timenow = `$dcopbin amarok default trackCurrentTime`;
			# Converting times to a more readable format
			$minutes = ($timenow/60)%60;
			$seconds = $timenow%60;
			# Add the leading zero
			if ($seconds < 10) {
				$seconds = "0" . $seconds;
			}
			$timetotal = `$dcopbin amarok default trackTotalTime`;
			$timetotal = $timetotal/1000;
			$minutestotal = ($timetotal/60)%60;
			$secondstotal = $timetotal%60;
			# Here too
			if ($secondstotal < 10) {
				$secondstotal = "0" . $secondstotal;
			}
			# The way it's gonna show up when we do /amarok
			$output = "np: $song ($minutes:$seconds / $minutestotal:$secondstotal)";
		}

		if ($output) {
			if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {
				$witem->command("MSG ".$witem->{name}." $output");
			}
			else {
				Irssi::print("This is not a channel/query window :b");
			}
		}
	}
}
Irssi::command_bind('amarok', 'cmd_amaroknp');
Irssi::command_bind('amarokhelp', 'cmd_amaroknp_help');