# amarok by Tobias 'camel69' Wulff

use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "1.0";
%IRSSI = (
    authors     => "Tobias 'camel69' Wulff",
    contact     => "camel69(at)codeeye.de",
    name        => "amaroK (via ssh)",
    description => "Retrievs song infos and controls amaroK via dcop, optionally running on another computer via ssh",
    license     => "Public Domain",
    commands	=> "amarok",
    url		=> "http://www.codeeye.de/irssi/"
);

use Irssi;

Irssi::settings_add_bool('amarok', 'amarok_use_ssh', 1);
Irssi::settings_add_str('amarok', 'amarok_ssh_client', 'localhost');
Irssi::settings_add_str('amarok', 'amarok_dcop_user', '');

sub show_help {
    my $help = $IRSSI{name}." ".$VERSION."
/amarok song [loud]
    Prints the artist and title of the song which is currently played.
    If the argument loud is given, all users in the current channel can
    see what song you are currently listening.
/amarok time [loud]
    Prints the total time of the song as well as the played time
    and remaining time. Same behaviour for given argument loud
    as above.
/amarok pause
    Pauses (or unpauses) the current song.
/amarok play
    Plays the current song (again).
/amarok stop
    Stops the current song.
/amarok next
    Skips to the next song.
/amarok prev
    Skips to the previous song.
/amarok seek [+|-]secs|min:secs
    Seeks to the given position. If + or - is given amaroK seeks
    relatively the amount of minutes and/or seconds to the
    current position.
/amarok vol [0 to 100]
    Prints or changes the output volume of amaroK.
/amarok mute
    Toggles between volume 0 and the last used volume.
/amarok help
    Prints this help text.

Settings you can change with /SET
    amarok_use_ssh:    Enable or disable remote amaroK'ing
    amarok_ssh_client: IP or hostname of the remote pc
    amarok_dcop_user:  user who is running dcop and amaroK";
    
    print CLIENTCRAP $help;
}

my $preprint = '%Bamarok%n> ';

# Load settings
my $amarok_use_ssh = Irssi::settings_get_bool('amarok_use_ssh');
my $ssh_client = Irssi::settings_get_str('amarok_ssh_client');
my $dcop_user = Irssi::settings_get_str('amarok_dcop_user');

sub cmd {
    my ($postcmd) = @_;
    my $dcop_precmd = 'dcop --user '.$dcop_user.' amarok player';

    if ($amarok_use_ssh == 1) {
        #print "ssh ".$ssh_client." '".$dcop_precmd." ".$postcmd."'";
        return `ssh $ssh_client '$dcop_precmd $postcmd'`;
    } else {
        #print $dcop_precmd.' '.$postcmd;
        return `$dcop_precmd $postcmd`;
    }
}

sub amarokSong {
    my($witem, $me_cmd) = @_;
    if ($me_cmd == 1) {
        if (!$witem or $witem->{type} ne 'CHANNEL') {
	    print CLIENTCRAP $preprint."The option 'loud' can only be used in channels.";
            return;
	}
    }
    
    my $artist = cmd('artist');
    my $title = cmd('title');
    my $text = 'listening to '.$artist.' - '.$title;
    $text =~ s/\n//g;

    if ($me_cmd == 1) {
        $witem->command("ME is ".$text);
    } else {
        print CLIENTCRAP $preprint.$text;
    }
}

sub amarokTime {
    my ($witem, $me_cmd) = @_;
    if ($me_cmd == 1 and (!$witem or $witem->{type} ne 'CHANNEL')) {
        print CLIENTCRAP $preprint."The option 'loud' can only be used in channels.";
        return;
    }
    
    # Zeiten in Sekunden holen
    my $time_total_secs = cmd('trackTotalTime');
    my $time_played_secs = cmd('trackCurrentTime');
    my $time_remaining_secs = $time_total_secs - $time_played_secs;

    # Zeiten in richtige Minutenangabe umwandeln
    my @time_total = (0, $time_total_secs % 60);
    $time_total[0] = ($time_total_secs - $time_total[1]) / 60;
    my @time_played = (0, $time_played_secs % 60);
    $time_played[0] = ($time_played_secs - $time_played[1]) / 60;
    my @time_remaining = (0, $time_remaining_secs % 60);
    $time_remaining[0] = ($time_remaining_secs - $time_remaining[1]) / 60;

    # Text bauen und ausgeben
    # Gesamtzeit
    my $text = 'Total time of track is '.$time_total[0].':';
    if ($time_total[1] < 10) { $text .= '0'; }
    $text .= $time_total[1];

    # Gespielte Zeit
    $text .= ' (played: '.$time_played[0].':';
    if ($time_played[1] < 10) { $text .= '0'; }
    $text .= $time_played[1];
    
    # Verbleibende Zeit
    $text .= ' / remaining: '.$time_remaining[0].':';
    if ($time_remaining[1] < 10) { $text .= '0'; }
    $text .= $time_remaining[1].')';
    
    if ($me_cmd == 1) {
        $witem->command("SAY ".$text);
    } else {
        print CLIENTCRAP $preprint.$text;
    }
}

sub amarokSeek {
    my($time) = @_;
    
    # format correct?
    # just seconds: + or -, some numbers (seconds)
    # mm:ss format: + or -, some numbers (minutes), :, 2 numbers (seconds)
    if ($time !~ /^(\+|-)?[0-9]+$/ and
        $time !~ /^(\+|-)?[0-9]+:[0-9]{2}$/) {
        print CLIENTCRAP $preprint.'%RERROR%n: Wrong time format (see help for correct format)!';
	return;
    }
    
    my $origtime = cmd('trackCurrentTime');

    # Assume there's no + or -
    my $seek_sign = '';
    
    # Check for + or - in $time
    # If a sign is found save it in $seek_sign and remove
    # it from $time.
    $_ = $time;
    if (/^\+/) {
	$seek_sign = '+';
	$time =~ s/^\+//g;
    } elsif (/^-/) {
	$seek_sign = '-';
	$time =~ s/^-//g;
    }

    # Now split $timearg at ':' if there's one
    my @timeparts = split(/:/, $time);

    # time has format mm:ss
    if (defined $timeparts[1]) {
	# Convert $time into secs
        $time = 60 * $timeparts[0] + $timeparts[1];
    }

    # if there's a + or - recalc $time
    if ($seek_sign eq '+') {
        $time = $origtime + $time;
    } elsif ($seek_sign eq '-') {
        $time = $origtime - $time;
    }
    
    # print and do it
    cmd('seek '.$time);
    my $newtime = cmd('currentTime');
    chomp($newtime);
    print CLIENTCRAP $preprint.'Seeked to '.$newtime.'.';
}

sub cmd_amarok {
    my ($args, $server, $witem) = @_;
    my @arg = split(/ /, $args);
    
    # enough arguments?
    if (scalar(@arg) == 0) {
        print CLIENTCRAP $preprint.'%RERROR%n: not enough arguments!';
	return;
    }

    my $loud = 0;
    if (defined $arg[1] && $arg[1] eq 'loud') { $loud = 1; }
    
    # is amaroK running?
    # if so, is it currently playing?
    # status = 0: stopped
    #        = 1: paused
    #        = 2: playing
    my $status = cmd('status');
    if ($status eq 'call failed') {
        print CLIENTCRAP $preprint.'%RERROR%n: amaroK is not running!';
	return;
    } elsif ($status == 0 && $arg[0] ne 'play' && $arg[0] ne 'help' && $arg[0] ne 'vol' && $arg[0] ne 'mute') {
        print CLIENTCRAP $preprint.'%RERROR%n: amaroK is not playing yet!';
	print CLIENTCRAP $preprint.'Only the play, vol, mute and help commands are available.';
	return;
    }
    
    # amaroK is running and playing or some commands are available though.
    if ($arg[0] eq 'song') {
        amarokSong($witem, $loud);
    } elsif ($arg[0] eq 'time') {
        amarokTime($witem, $loud);
    } elsif ($arg[0] eq 'pause') {
        cmd('pause');
	if ($status == 1) {
	    print CLIENTCRAP $preprint.'Song unpaused.';
	} elsif ($status == 2) {
	    print CLIENTCRAP $preprint.'Song paused.';
        }
    } elsif ($arg[0] eq 'next') {
        cmd('next');
	print CLIENTCRAP $preprint.'Skipped to next song.';
    } elsif ($arg[0] eq 'prev') {
        cmd('prev');
	print CLIENTCRAP $preprint.'Skipped to previous song.';
    } elsif ($arg[0] eq 'play') {
        cmd('play');
	print CLIENTCRAP $preprint.'Playing song.';
    } elsif ($arg[0] eq 'stop') {
        cmd('stop');
	print CLIENTCRAP $preprint.'Song stopped.';
    } elsif ($arg[0] eq 'seek') {
        if (!(defined $arg[1])) {
	    print CLIENTCRAP $preprint.'Not enough arguments.';
	} else {
	    amarokSeek($arg[1]);
	}
    } elsif ($arg[0] eq 'vol') {
        if (!(defined $arg[1])) {
	    my $o_vol = cmd('getVolume');
	    chomp($o_vol);
	    print CLIENTCRAP $preprint.'Current volume is '.$o_vol.'%%.';
	} else {
	    if ($arg[1] < 0 or $arg[1] > 100) {
	        print CLIENTCRAP $preprint.'Given volume is out of range (0-100)';
		return;
	    }
	    cmd('setVolume '.$arg[1]);
	    print CLIENTCRAP $preprint.'Volume changed to '.$arg[1].'%%.';
	}
    } elsif ($arg[0] eq 'mute') {
        cmd('mute');
	print CLIENTCRAP $preprint.'Mute toggled.';
    } elsif ($arg[0] eq 'help') {
        show_help();
    } else {
        print CLIENTCRAP $preprint.'%RERROR%n: Unknown command!';
    }
}

Irssi::command_bind('amarok' => \&cmd_amarok);

foreach my $cmd ('song', 'time', 'pause', 'play', 'stop', 'next', 'prev', 'seek', 'vol', 'mute', 'help') {
    Irssi::command_bind('amarok '.$cmd =>
        sub { cmd_amarok("$cmd ".$_[0], $_[1], $_[2]); } );
}
 
print CLIENTCRAP $preprint.$IRSSI{name}.' '.$VERSION.' loaded: type /amarok help for help';
