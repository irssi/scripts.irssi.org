###########################################################################
# ak FTP-Ad v1.4
# Copyright (C) 2003 ak
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  
# 02111-1307, USA.
# Or check out here, eh ;) -> http://www.gnu.org/licenses/gpl.html    //ak
###########################################################################

# code follows .. nothing to do here for you,
# just load the script into irssi with /script load akftp.pl
# and enter /akftp for more information
#############################################################

use strict;
use Irssi 20021117.1611 ();
use vars qw($VERSION %IRSSI);
	$VERSION = "1.4";
	%IRSSI = (
	        authors     => "ak",
	        contact     => "ocb23\@freenet.removethis.de",
	        name        => "ak FTP-Ad",
	        description => "Full configurable FTP advertiser for Irssi",
	        license     => "GPLv2",
	        url         => "http://members.tripod.com.br/archiv/",
	);


use Irssi qw(
	settings_get_bool settings_add_bool
	settings_get_str  settings_add_str
	settings_get_int  settings_add_int
	print
);

sub cmd_list {
        my ($server, $msg, $nick, $mask, $target) = @_;
	my ($c1, $c2, $trigger, $targets);
	$trigger=settings_get_str('akftp_trigger');
	$targets=settings_get_str('akftp_channels');

	if (!settings_get_bool('akftp_enable_add')) { return 0 }
        if(!($target =~ $targets)) { return 0 }
	elsif ($msg=~/^$trigger/){
		$c1=settings_get_str('akftp_color1');
		$c2=settings_get_str('akftp_color2');
		$server->command("^NOTICE ".$nick." ".$c1."=(".$c2."FTP Online".$c1.")= \@(".
		$c2.settings_get_str('akftp_host').$c1.") Port:(".$c2.settings_get_str('akftp_port').
		$c1.") Login:(".$c2.settings_get_str('akftp_login').$c1.") Pass:(".
		$c2.settings_get_str('akftp_pass').$c1.") Quicklink: ".$c2.
		"ftp://".settings_get_str('akftp_login').":".settings_get_str('akftp_pass')."\@".
		settings_get_str('akftp_host').":".settings_get_str('akftp_port')."/".
		$c1." Notes:(".$c2.settings_get_str('akftp_notes').$c1.")");
		# Irssi::signal_stop();
 	}
}

sub cmd_akftp {
	print("%r.--------------------<%n%_ak FTP-Ad for Irssi%_%r>--------------------<");
	print("%r|%n Configure the script with %_/set%_ commands, to see all values,");
	print("%r|%n you can type \"%_/set akftp%_\".");
	print("%r|%n You can configure multiple chans by separating them with %_|%_");
	print("%r|%n You have to specify the colors with \"%_CTRL+C##%_\". where %_##%_");
	print("%r|%n must be numbers between %_00%_ and %_15%_! Prefix 0-9 with a zero!");
	print("%r|%n Note that \"%_/set akftp%_\" will show empty variables for colors,");
	print("%r|%n even if they are already set.");
	print("%r`------------------------------------------------------------->");
}

settings_add_bool('akftp', 'akftp_enable_add', 0);
settings_add_str('akftp', 'akftp_login', "username");
settings_add_str('akftp', 'akftp_pass', "password");
settings_add_str('akftp', 'akftp_host', "your.dyndns-or-static.ip");
settings_add_str('akftp', 'akftp_notes', "Don't hammer!");
settings_add_str('akftp', 'akftp_channels', "#chan1|#chan2");
settings_add_int('akftp', 'akftp_port', "21");
settings_add_str('akftp', 'akftp_color1', "\00303");
settings_add_str('akftp', 'akftp_color2', "\00315");
settings_add_str('akftp', 'akftp_trigger', "!list");

Irssi::signal_add_last('message public', 'cmd_list');
Irssi::command_bind('akftp', 'cmd_akftp');

#EOF
