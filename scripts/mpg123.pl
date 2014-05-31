# Display current mpg123 track to channel
# you should run mpg123 as,
# mpg123 --verbose file1 file2 2> ~/.irssi/scripts/mpg123.log
# or just put this on a file 

#   #--- mpg123a file ---#
#   #!/bin/sh
#   mpg123 --verbose * 2> ~/.irssi/scripts/mpg123.log

# save it as mpg123a and make it executable
# chmod a+x mpg123a
#
# execute it on the directory you have your mp3 files
# ./mpg123a


#
# HOWTO use "mpg123 script" from Irssi:
# /mpg123 [#channel] [-h|--help]
#
# This script works with no problems on mpg123 Version 0.59r
# bugs: if u call it from the "status" window, it ill crash the script, since you arent currently on a channel. 
# It ill crash the script not the Irssi program, so u shall re-run it.


use Irssi;
use Irssi::Irc;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "0.01+1";
%IRSSI = (
    authors     => 'Ricardo Mesquita',
    contact	=> 'ricardomesquita@netcabo.pt',
    name        => 'mpg123',
    description => 'Display current mpg123 track',
    url		=> 'http://pwp.netcabo.pt/ricardomesquita/irssi',
    license     => 'GPLv2',
    changed	=> 'Mon Nov 27 18:00:00 CET 2006'
);

my $mpg123file = glob "~/.irssi/scripts/mpg123.log";


sub cmd_mpg123 {
	my ($data, $server, $witem) = @_;
	my ($mpg123msg, $mpg123linha, $channel);

	my $showhelp="mpg123 irssi script version $VERSION\n/mpg123 [#channel] [-h|--help]";
	
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
		
		open (f, $mpg123file) || return;

		while ($mpg123linha=<f>) {		
			
			chomp($mpg123linha);
			if ($mpg123linha=~/playing/i) {
				$mpg123linha =~s/(.*)stream from\s(.*)\.(.*)\s(.*)/\2\.\3/;
				$mpg123msg="on MPG123 playing $mpg123linha";
			}

			chomp($mpg123linha);
			if ($mpg123linha =~/time:\s/i) {
				$mpg123linha=~s/[\s]frame#.*,\s(.*),/\1/i;
				$mpg123linha=~s/time:\s(\d\d).(\d\d).(\d\d)..(\d\d).(\d\d).(\d\d)./\[\1:\2.\3\]/i;	
				$mpg123msg.=" $mpg123linha";
			}
		}
		close(f);
		$mpg123msg =~ s/[\r\n]/ /g;
		$server->command("action ".  $channel . " $mpg123msg");
	}	
}

Irssi::command_bind('mpg123', 'cmd_mpg123');
