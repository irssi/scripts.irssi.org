use strict;
use vars qw($VERSION %IRSSI);

use Irssi;

$VERSION = '1.00';
%IRSSI = (
	authors		=> 'Cybertinus',
	contact		=> 'cybertinus@cybertinus.nl',
	name		=> 'Greeter',
	description	=> 'This script allows ' .
			   'you to greet the channel ' .
			   'You\'re joining with the ' .
			   'command /hello. The text ' .
			   'it shows depends on the time ' .
			   'you\'re living.',
	license		=> 'GPL2',
	changed		=> "2005-05-25 13:42:00 GMT+1+DST"
);

sub hello
{
	my($data, $server, $witem, $time, $text) = @_;
	return unless $witem;
	# $witem (window item) may be undef.
	
	# getting the current hour off the day
	$time = (localtime(time))[2];
	
	if($time >= 18)
	{
		$text = Irssi::settings_get_str("evening_message");
	}
	elsif($time >= 12)
	{
		$text = Irssi::settings_get_str("afternoon_message");
	}
	elsif($time >= 6)
	{
		$text = Irssi::settings_get_str("morning_message");
	}
	elsif($time >= 0)
	{
		$text = Irssi::settings_get_str("night_message")
	}
	$server->command("MSG $witem->{name} $text $data");
	
}

Irssi::command_bind hello => \&hello;

Irssi::settings_add_str("greeter", "evening_message", "good evenening");
Irssi::settings_add_str("greeter", "afternoon_message", "good afternoon");
Irssi::settings_add_str("greeter", "morning_message", "good morning");
Irssi::settings_add_str("greeter", "night_message", "good night");
