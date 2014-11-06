# countdown.pl

# adds public countdown command

# ver 1.0 
#   - initial release

use Irssi;
use strict;
use Time::Local;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
    authors     => 'Mikko \'Quidz\' Salmi',
    name        => 'countdown',
    contact	=> 'mikko@quidz.net',
    description => 'adds public channel command for counting down something',
    license     => 'Public Domain',
    changed	=> 'Thu Aug 8 12:06:46 EET 2002'
);

Irssi::settings_add_str('misc','countdown_target','2003 01 01 00 00 00');
Irssi::settings_add_str('misc','countdown_message','New year 2003:');
Irssi::settings_add_str('misc','countdown_command','!countdown');
Irssi::settings_add_str('misc','countdown_chan','#countdown');

sub sig_public {
	my ($server, $msg, $nick, $address, $target) = @_;
	my $ctarget = Irssi::settings_get_str("countdown_target");
	my $cinfo = Irssi::settings_get_str("countdown_message");
	my $ccmd = Irssi::settings_get_str("countdown_command");
	my $cchan = Irssi::settings_get_str("countdown_chan");
	if ($msg eq $ccmd and lc($target) eq lc($cchan))
	{
		if ($ctarget =~ /^(\d+?) (\d+?) (\d+?) (\d+?) (\d+?) (\d+?)$/)
		{
			my $sec = timelocal($6,$5,$4,$3,$2-1,$1-1900);
			$sec -= time;
			my $min = ($sec/60)-(($sec%60)/60);
			my $hour = ($min/60)-(($min%60)/60);
			my $day = ($hour/24)-(($hour%24)/24);
			$sec = ($sec%60);
			$min = ($min%60);
			$hour = ($hour%24);
			if ($day) { $cinfo = $cinfo." $day d"; }
			if ($hour) { $cinfo = $cinfo." $hour h"; }
			if ($min) { $cinfo = $cinfo." $min m"; }
			if ($sec) { $cinfo = $cinfo." $sec s"; }
			$server->command("msg $target $cinfo");
		} else
		{
			Irssi::print("Error: countdown.pl misc.countdown_target should be format <year> <month> <day> <hour> <minute> <second>");
		}
	}
}

Irssi::signal_add_last('message public', 'sig_public');
Irssi::print("Script : countdown.pl loaded");
