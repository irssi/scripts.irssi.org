# based on irssi mouse patch by mirage: http://darksun.com.pt/mirage/irssi/
# It should probably indeed be done in C, and go into irssi, or as a module,
# but I translated it to perl just for the fun of it, and to prove it's possible maybe

use strict;
use Irssi qw(signal_emit settings_get_str active_win signal_stop settings_add_str settings_add_bool settings_get_bool signal_add signal_add_first);
use Math::Trig;

use vars qw($VERSION %IRSSI);

$VERSION = '0.0.0';
%IRSSI = (
	authors  	=> 'Wouter Coekaerts',
	contact  	=> 'wouter@coekaerts.be',
	name    	=> 'trigger',
	description 	=> 'experimental perl version of the irssi mouse patch',
	license 	=> 'GPLv2',
	url     	=> 'http://wouter.coekaerts.be/irssi/',
	changed  	=> '2005-11-21',
);

# minor changes by Soliton:
# added mouse_enable and mouse_disable functions to make for example copy & pasting possible for a second after clicking with the left mouse button
# also changed the mouse button for the gestures to the right button

my $mouse_xterm_status = -1; # -1:off 0,1,2:filling mouse_xterm_combo
my @mouse_xterm_combo; # 0:button 1:x 2:y
my @mouse_xterm_previous; # previous contents of mouse_xterm_combo

sub mouse_enable {
	print STDERR "\e[?1000h"; # start tracking 
}

sub mouse_disable {
	print STDERR "\e[?1000l"; # stop tracking 
	Irssi::timeout_add_once(2000, 'mouse_enable', undef); # turn back on after 1 sec
}

# Handle mouse event (button press or release)
sub mouse_event {
	my ($b, $x, $y, $oldb, $oldx, $oldy) = @_;
	my ($xd, $yd);
	my ($distance, $angle);

	#print "DEBUG: mouse_event $b $x $y";

	# uhm, in the patch the scrollwheel didn't work for me, but this does:
	if ($b == 64) {
		cmd("mouse_scroll_up");
	} elsif ($b == 65) {
		cmd("mouse_scroll_down")
	}

	# proceed only if a button is being released
	return if ($b != 3);

	# if it was a mouse click of the left button (press and release in the same position)
	if ($x == $oldx && $y == $oldy && $oldb == 0) {
		#signal_emit("mouse click", $oldb, $x, $y);
		#mouse_click($oldb, $x, $y);
		mouse_disable();
		return;
	}

	# otherwise, find mouse gestures on button
	return if ($oldb != 2);
	$xd = $x - $oldx;
	$yd = -1 * ($y - $oldy);
	$distance = sqrt($xd*$xd + $yd*$yd);
	# ignore small gestures
	if ($distance < 3) {
		return;
	}
	$angle = asin($yd/$distance) * 180 / 3.14159265358979;
	if ($angle < 20 && $angle > -20 && $xd > 0) {
		if ($distance <= 40) {
			cmd("mouse_gesture_right");
		} else {
			cmd("mouse_gesture_bigright");
		}
	} elsif ($angle < 20 && $angle > -20 && $xd < 0) {
		if ($distance <= 40) {
			cmd("mouse_gesture_left");
		} else {
			cmd("mouse_gesture_bigleft");
		}
	} elsif ($angle > 40) {
		cmd("mouse_gesture_up");
	} elsif ($angle < -40) {
		cmd("mouse_gesture_down");
	}
}

sub cmd
{
	my ($setting) = @_;
	signal_emit("send command", settings_get_str($setting), active_win->{'active_server'}, active_win->{'active'});
}


signal_add_first("gui key pressed", sub {
	my ($key) = @_;
	if ($mouse_xterm_status != -1) {
		if ($mouse_xterm_status == 0) {
			@mouse_xterm_previous = @mouse_xterm_combo;
		}
		$mouse_xterm_combo[$mouse_xterm_status] = $key-32;
		$mouse_xterm_status++;
		if ($mouse_xterm_status == 3) {
			$mouse_xterm_status = -1;
			# match screen coordinates
			$mouse_xterm_combo[1]--;
			$mouse_xterm_combo[2]--;
			# TODO signal_emit("mouse event", $mouse_xterm_combo[0], $mouse_xterm_combo[1], $mouse_xterm_combo[2], $mouse_xterm_previous[0], $mouse_xterm_previous[1], $mouse_xterm_previous[2]);
			mouse_event($mouse_xterm_combo[0], $mouse_xterm_combo[1], $mouse_xterm_combo[2], $mouse_xterm_previous[0], $mouse_xterm_previous[1], $mouse_xterm_previous[2]);
		}
		signal_stop();
	}
});

sub sig_command_script_unload {
	my $script = shift;
	if ($script =~ /(.*\/)?$IRSSI{'name'}(\.pl)? *$/) {
		print STDERR "\e[?1000l"; # stop tracking
	}
}
Irssi::signal_add_first('command script load', 'sig_command_script_unload');
Irssi::signal_add_first('command script unload', 'sig_command_script_unload');

if ($ENV{"TERM"} !~ /^rxvt|screen|xterm(-color)?$/) {
	die "Your terminal doesn't seem to support this.";
}

print STDERR "\e[?1000h"; # start tracking

Irssi::command("/^bind meta-[M /mouse_xterm"); # FIXME evil
Irssi::command_bind("mouse_xterm", sub {$mouse_xterm_status = 0;});

settings_add_str("lookandfeel", "mouse_gesture_up", "/window last");
settings_add_str("lookandfeel", "mouse_gesture_down", "/window goto active");
settings_add_str("lookandfeel", "mouse_gesture_left", "/window prev");
settings_add_str("lookandfeel", "mouse_gesture_bigleft", "/eval window prev;window prev");
settings_add_str("lookandfeel", "mouse_gesture_right", "/window next");
settings_add_str("lookandfeel", "mouse_gesture_bigright", "/eval window next;window next");
settings_add_str("lookandfeel", "mouse_scroll_up", "/scrollback goto -10");
settings_add_str("lookandfeel", "mouse_scroll_down", "/scrollback goto +10");
