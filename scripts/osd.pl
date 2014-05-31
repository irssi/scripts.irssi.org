use strict;
use IO::Handle;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '0.3.3';
%IRSSI = (
	authors     => 'Jeroen Coekaerts, Koenraad Heijlen',
	contact     => 'vipie@ulyssis.org, jeroen@coekaerts.be',
	name        => 'osd',
	description => 'An OnScreenDisplay (osd) it show\'s who is talking to you, on what IRC Network.',
	license     => 'BSD',
	url         => 'http://vipie.studentenweb.org/dev/irssi/',
	changed     => '2004-01-09'
);

#--------------------------------------------------------------------
# Changelog
# 2004-01-09 
#  - fix a typo in the help (M.G.Kishalmi)
# TODO :
#
# * a setting that let's you display the text? (exploits?!)
#
#--------------------------------------------------------------------


#--------------------------------------------------------------------
# Public Variables
#--------------------------------------------------------------------
my %myHELP = ();

#--------------------------------------------------------------------
# Help function
#--------------------------------------------------------------------
sub cmd_help { 
	my ($about) = @_;

	%myHELP = (
		osd_test => "
osd_test

Displays a small test message on screen
",

		osd_reload => "
osd_reload

Restarts the osd_cat program, it's especially need when
have CHANGED settings. They DO NOT take effect UNTIL you RELOAD.
",

		osd => "
OSD 

You can display on screen who is paging/msg'ing you on IRC.

When you CHANGE the settings you SHOULD use /osd_reload to let these changes
take effect.

Settings:
---------

* osd_color  	(default: blue)
Currently the setting is: " . Irssi::settings_get_str('osd_color') . "

It should be a valid X color, the list in normally located in /etc/X11/rgb.txt.

* osd_font  	(default: -*-helvetica-medium-r-\*-\*-\*-320-\*-\*-\*-\*-\*-\*)
Currently the setting is: " . Irssi::settings_get_str('osd_font') . "

These fonts are available when you installed the microsoft font pack :-)
-microsoft-tahoma-bold-r-normal-*-\*-320-\*-\*-p-\*-\*-\*
-microsoft-verdana-bold-r-normal-\*-\*-320-\*-\*-p-\*-\*-\*

This font is available on every linux install with the adobe fonts. 
-*-helvetica-medium-r-\*-\*-\*-320-\*-\*-\*-\*-\*-\*

*  osd_align	(default: right)
Currently the setting is: " . Irssi::settings_get_str('osd_align') . "

left|right|center (horizontal alignment)

* osd_place	(default: top)
Currently the setting is: " . Irssi::settings_get_str('osd_place') . "

top|bottom|middle (vertical alginment)

* osd_offset	(default: 100)
Currently the setting is: " . Irssi::settings_get_str('osd_offset') . "

The vertical offset from the screen edge set in osd_place.

* osd_indent	(default: 100)
Currently the setting is: " . Irssi::settings_get_str('osd_indent') . "

The horizontal offset from the screen edge set in osd_align.

* osd_shadow	(default: 0)
Currently the setting is: " . Irssi::settings_get_str('osd_shadow') . "

Set the shadow offset, if the offset is 0, the shadow is disabled.

* osd_delay	(default: 4)
Currently the setting is: " . Irssi::settings_get_str('osd_delay') . "

How many seconds should the message remain on screen.

* osd_age	(default: 4)
Currently the setting is: " . Irssi::settings_get_str('osd_age') . "

Time in seconds before old scroll lines are discarded.

* osd_lines	(default: 5)
Currently the setting is: " . Irssi::settings_get_str('osd_lines') . "

Number of lines to display on screen at one time.

* osd_DISPLAY	(default: :0.0)
Currently the setting is: " . Irssi::settings_get_str('osd_DISPLAY') . "

On what \$DISPLAY should the osd connect. (this makes tunneling possible)

* osd_showactivechannel	(default: yes)
Currently the setting is: " . Irssi::settings_get_str('osd_showactivechannel') . "

When set to yes, OSD will be triggered even if the channel is the active channel.
When set to yes, OSD will be triggered if you send a message from your own nick.

You can test the OSD settings with the 'osd_test' command!
he 'osd_test' to test them.

",
);

	if ( $about =~ /(osd_reload|osd_test|osd)/i ) { 
		Irssi::print($myHELP{lc($1)});
	} 
}

#--------------------------------------------------------------------
# Irssi::Settings
#--------------------------------------------------------------------

Irssi::settings_add_str('OSD', 'osd_color', "blue");

#These fonts are available when you installed the microsoft font pack :-)
#Irssi::settings_add_str('OSD', 'osd_font', "-microsoft-tahoma-bold-r-normal-\*-\*-320-\*-\*-p-\*-\*-\*");
#Irssi::settings_add_str('OSD', 'osd_font', "-microsoft-verdana-bold-r-normal-\*-\*-320-\*-\*-p-\*-\*-\*");
#This font is available on every linux install with the adobe fonts. 
Irssi::settings_add_str('OSD', 'osd_font', "-*-helvetica-medium-r-\*-\*-\*-320-\*-\*-\*-\*-\*-\*");

Irssi::settings_add_str('OSD', 'osd_age', "4");
Irssi::settings_add_str('OSD', 'osd_align', "right");
Irssi::settings_add_str('OSD', 'osd_delay', "4");
Irssi::settings_add_str('OSD', 'osd_indent', "100");
Irssi::settings_add_str('OSD', 'osd_lines', "5");
Irssi::settings_add_str('OSD', 'osd_offset', "100");
Irssi::settings_add_str('OSD', 'osd_place', "top");
Irssi::settings_add_str('OSD', 'osd_shadow', "0");
Irssi::settings_add_str('OSD', 'osd_DISPLAY', ":0.0");
Irssi::settings_add_str('OSD', 'osd_showactivechannel', "yes");

#--------------------------------------------------------------------
# initialize the pipe, test it.
#--------------------------------------------------------------------

sub init {
	pipe_open();
	osdprint("OSD Loaded.");
}

#--------------------------------------------------------------------
# open the OSD pipe
#--------------------------------------------------------------------

sub pipe_open {
	my $place;		
	my $version;
	my $command;

	$version = `osd_cat -h 2>&1` or die("The OSD program can't be started, check if you have osd_cat installed AND in your path.");
	$version =~ /Version:\s*(.*)\s*/;
	$version = $1;
	#Irssi::print "Version: $version";

	if ( $version =~ /^2.*/ ) { 
		# the --pos argument seems to be broken on 2.0.X
		if ( Irssi::settings_get_str('osd_place') eq "top" ) { 
			$place = "-p top"; 
		} elsif ( Irssi::settings_get_str('osd_place') eq "bottom") { 
			$place = "-p bottom"; 
		} else { 
			$place = "-p middle"; 
		}
	} else {
		if ( Irssi::settings_get_str('osd_place') eq "top" ) { 
			$place = "--top"; 
		} else { 
			$place = "--bottom"; 
		}
	}
	
	$command = "|DISPLAY=".Irssi::settings_get_str('osd_display') .
		" osd_cat $place " .
		" --color=".Irssi::settings_get_str('osd_color').
		" --delay=".Irssi::settings_get_str('osd_delay').
		" --age=".Irssi::settings_get_str('osd_age').
		" --font=".quotemeta(Irssi::settings_get_str('osd_font')).
		" --offset=".Irssi::settings_get_str('osd_offset').
		" --shadow=".Irssi::settings_get_str('osd_shadow'). 
		" --lines=".Irssi::settings_get_str('osd_lines').
		" --align=".Irssi::settings_get_str('osd_align');

	if ( $version =~ /^2.*/ ) {
		$command .= " --indent=".Irssi::settings_get_str('osd_indent');
	}
	open( OSDPIPE, $command ) 
		or print "The OSD program can't be started, check if you have osd_cat installed AND in your path.";
	OSDPIPE->autoflush(1);
}

#--------------------------------------------------------------------
# Private message parsing
#--------------------------------------------------------------------

sub priv_msg {
	my ($server,$msg,$nick,$address,$target) = @_;
	if ((Irssi::settings_get_str('osd_showactivechannel') =~ /yes/) or
	   not (Irssi::active_win()->get_active_name() eq "$nick") ) {
			osdprint($server->{chatnet}.":$nick");
	}
}

#--------------------------------------------------------------------
# Public message parsing
#--------------------------------------------------------------------

sub pub_msg {
	my ($server,$msg,$nick,$address, $channel) = @_;
	my $show;

	if (Irssi::settings_get_str('osd_showactivechannel') =~ /yes/) {
		$show = 1;
	} elsif(uc(Irssi::active_win()->get_active_name()) eq uc($channel)) {
		$show = 0;
	}

	if ($show) {
		my $onick= quotemeta "$server->{nick}";
		my $pat ='(\:|\,|\s)'; # option...
		if($msg =~ /^$onick\s*$pat/i){
			osdprint("$channel".":$nick");
		}
	}
}

#--------------------------------------------------------------------
# The actual printing
#--------------------------------------------------------------------

sub osdprint {
	my ($text) = @_;
	if (not (OSDPIPE->opened())) {pipe_open();}
	print OSDPIPE "$text\n";
	OSDPIPE->flush();
}

#--------------------------------------------------------------------
# A test command.
#--------------------------------------------------------------------

sub cmd_osd_test {
	osdprint("Testing OSD");
}

#--------------------------------------------------------------------
# A command to close and reopen OSDPIPE
#  so options take effect without needing to unload/reload the script
#--------------------------------------------------------------------

sub cmd_osd_reload {
	close(OSDPIPE);
	pipe_open();
	osdprint("Reloaded OSD");
}

#--------------------------------------------------------------------
# Irssi::signal_add_last / Irssi::command_bind
#--------------------------------------------------------------------

Irssi::signal_add_last("message public", "pub_msg");
Irssi::signal_add_last("message private", "priv_msg");

Irssi::command_bind("osd_reload","cmd_osd_reload", "OSD");
Irssi::command_bind("osd_test","cmd_osd_test", "OSD");
Irssi::command_bind("help","cmd_help", "Irssi commands");

#--------------------------------------------------------------------
# The command that's executed at load time.
#--------------------------------------------------------------------

init();

#--------------------------------------------------------------------
# This text is printed at Load time.
#--------------------------------------------------------------------

Irssi::print("Use /help osd for more information."); 


#- end
