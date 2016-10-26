#=================================================================================
#
# rhythmbox.pl
# script that allows you to control rhythmbox from irssi
#
#=================================================================================
# INITIAL SECTION
#=================================================================================
use Irssi;
use Irssi::Irc;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "1.30";

%IRSSI = (
	authors     =>  'Fogel',
	contact     =>  'fogel@fogel.netmark.pl',
	name        =>  'rhythmbox',
	description =>  'Rhythmbox now playing script',
	license     =>  'BSD',
	url         =>  "www.fogel.com.pl",
);
#=================================================================================
# NOW PLAYING SECTION
#=================================================================================
sub now_playing {

	my ($data, $server, $witem) = @_;


	my $title = `rhythmbox-client --print-playing-format %tt`;
	my $artist = `rhythmbox-client --print-playing-format %ta`;
	my $number = `rhythmbox-client --print-playing-format %tn`;
	my $duration = `rhythmbox-client --print-playing-format %td`;
	my $elapsed = `rhythmbox-client --print-playing-format %te`;
	my $album_title = `rhythmbox-client --print-playing-format %at`;
	my $album_artist = `rhythmbox-client --print-playing-format %aa`;
	my $album_year = `rhythmbox-client --print-playing-format %ay`;
	my $album_genre = `rhythmbox-client --print-playing-format %ag`;
	my $disc_number = `rhythmbox-client --print-playing-format %an`;

	if ($number =~ m/^\d*$/i) {
		
		my $output = "np: $artist - $title ($elapsed / $duration)"; # here set desired format of output

		if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {

			$witem->command("me $output")
		} else {
			Irssi::print("This is not a channel/query window");
		}

	} else {
		Irssi::print("rhythmbox is not playing anything at the moment.");
	}
}
#=================================================================================
# RHYTHMBOX CONTROL SECTION
#=================================================================================
sub pause {
	system("rhythmbox-client --pause");
}

sub play {
	system("rhythmbox-client --play");
}

sub next {
        system("rhythmbox-client --next");
}

sub previous {
        system("rhythmbox-client --previous");
}

sub volume_up {
        system("rhythmbox-client --volume-up");
} 

sub volume_down {
        system("rhythmbox-client --volume-down");
} 

sub volume {
        my $vol = `rhythmbox-client --print-volume`;
	Irssi::print("rhythmbox volume: $vol");
}

sub mute {
        system("rhythmbox-client --mute");
}

sub unmute {
        system("rhythmbox-client --unmute");
}
#=================================================================================
# HELP DISPLAY SECTION SECTION
#=================================================================================
sub help {
	
	Irssi::print("rhythmbox.pl - rhythmbox control script for irssi");
	Irssi::print("Copyright Michal \"Fogel\" Fogelman");
	Irssi::print("List of commands:");
	Irssi::print("/np - now playing - show others what are you listening to");
	Irssi::print("/pause, /play");
	Irssi::print("/prev, /next - previous/next track");
	Irssi::print("/vup, /vdown - volume up/down");
	Irssi::print("/volume - displays current volume level");
	Irssi::print("/mute, /unmute");
}
#=================================================================================
# COMMAND BINDINGS
#=================================================================================
Irssi::command_bind('np', 'now_playing');
Irssi::command_bind('pause', 'pause');
Irssi::command_bind('play', 'play');
Irssi::command_bind('next', 'next');
Irssi::command_bind('prev', 'previous');
Irssi::command_bind('vup', 'volume_up');
Irssi::command_bind('vdown', 'volume_down');
Irssi::command_bind('vol', 'volume');
Irssi::command_bind('mute', 'mute');
Irssi::command_bind('unmute', 'unmute');

Irssi::command_bind('rhythmbox_help', 'help');
#=================================================================================
# END OF FILE
#=================================================================================
