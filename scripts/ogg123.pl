# Display current ogg123 track to channel
# you should run ogg123 as,
# ogg123 --verbose file1 file2 2> ~/.irssi/scripts/ogg123.log
# or just put this on a file 

#   #--- ogg123a file ---#
#   #!/bin/sh
#   ogg123 --verbose * 2> ~/.irssi/scripts/ogg123.log

# save it as ogg123a and make it executable
# chmod a+x ogg123a
#
# execute it on the directory you have your .ogg files
# ./ogg123a


#
# HOWTO use "ogg123 script" from Irssi:
# /ogg123 [#channel] [-h|--help]
#
# bugs: if u call it from the "status" window, it ill crash the script, since you arent currently on a channel. 
# It ill crash the script not the Irssi program, so u shall re-run it.
#
# **** note ****
# Yeah i now that this is a copy of mpg123.pl script ;D
# to be true it was just a question of doing %s/mpg/ogg/gi and small changes on the regexp, 
# but its workable, the mpg123 author doenst complain, so who really cares?!  =:)  
# isnt what all ppl is doing since recent events moving all... mv *.mp3 *.ogg

use Irssi;
use Irssi::Irc;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "0.01+1";
%IRSSI = (
    authors     => 'Ricardo Mesquita',
    contact	=> 'ricardomesquita@netcabo.pt',
    name        => 'ogg123',
    description => 'Display current ogg123 track',
    url		=> 'http://pwp.netcabo.pt/ricardomesquita/irssi',
    license     => 'GPLv2',
    changed	=> 'Mon Nov 27 18:00:00 CET 2006'
);

my $ogg123file = glob "~/.irssi/scripts/ogg123.log";


sub cmd_ogg123 {
	my ($data, $server, $witem) = @_;
	my ($ogg123msg, $ogg123linha, $channel);

	my $showhelp="ogg123 irssi script version $VERSION\n/ogg123 [#channel] [-h|--help]";
	
	if ($data=~/-h|--help/) {
		Irssi::print($showhelp);
		return
	} else {		
		if ($data=~ /#./) {
			$channel = $data;
		} else {
			if ($witem->{name} ne "") {
				$channel = $witem->{name};	
			}
		}
		
		open (f, $ogg123file) || return;

		while ($ogg123linha=<f>) {		
			
			chomp($ogg123linha);
			if ($ogg123linha=~/Playing:/i) {
				$ogg123linha =~s/(.*)Playing:\s(.*)/\2/;
				$ogg123msg="on ogg123 playing $ogg123linha";
			}

			chomp($ogg123linha);
			if ($ogg123linha =~/Title:/i) {
				$ogg123linha =~s/(.*)Title:\s(.*)/\2/;
				$ogg123msg="on ogg123 playing $ogg123linha";
			}

			chomp($ogg123linha);
			if ($ogg123linha =~/Artist:/i) {
				$ogg123linha =~s/(.*)Artist:\s(.*)/\2/;
				$ogg123msg.=" - $ogg123linha";
			}
		}
		close(f);
		$ogg123msg =~ s/[\r\n]/ /g;
		$server->command("action ".  $channel . " $ogg123msg");
	}	
}

Irssi::command_bind('ogg123', 'cmd_ogg123');
