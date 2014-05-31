use strict;
use Irssi;
use Irssi::TextUI;
use vars qw($VERSION %IRSSI);
use Xmms;
use Xmms::Remote ();

#changed to recommended version system with onedigit.twodigits, sorry :)
$VERSION = '2.01';
%IRSSI = (
	authors => 'Mikachu',
	contact => 'Mikachu @ quakenet|freenode|arcnet|oftc',
	description => 'A script to show playing xmms song in channel or in a statusbar, and also control xmms. Be sure to read through the script to see all features.',
	name => 'l33t xmms music showing script',
	license => 'GPL',
	modules => 'Bundle::Xmms',
	sbitems => 'l33tmusic'
);

#Stuff i've added recently that i can remember:
#
#fixed the -c parameter, now you can do stuff like
#/l33tmusic -c / jump_to_timestr 1:24 to jump around
#and /l33tmusic -c / pause to pause, and /l33tmusic
#-c /echo get_playlist_pos to echo the position :)
#
#only answers to /ctcp music if xmms is actually on
#(if someone /ctcp music nick 2 it will show your current+2
#song in playlist as currently playing instead of saying
#that it is the second next song, oh well :)
#
#some stuff now take a numerical argument as an offset
#to the current position in the playlist
#
#Stuff i've added that i can't remember:
#
#if you expected to find something here you weren't thinking
#look below for stuff

#this function from nickcolor.pl
my @colors = qw/2 3 4 5 6 7 9 10 11 12 13/;
sub simple_hash {
  my ($string) = @_;
  chomp $string;
  my @chars = split //, $string;
  my $counter;

  foreach my $char (@chars) {
    $counter += ord $char;
  }

  $counter = $colors[$counter % 11];

  return $counter;
}

sub getvars {
	if ($_[0] =~ "songinfo") {
		my ($position, $title, $time, $status, $filename);
		my $xmmscontrol = Xmms::Remote->new;
		my $wantedpos = $_[0];
		$wantedpos =~ s/songinfo //;
		unless ($wantedpos =~ /^-?\d+$/ && (( $wantedpos + $xmmscontrol->get_playlist_pos <= $xmmscontrol->get_playlist_length-1 && $wantedpos >= 0) || 0-$wantedpos <= $xmmscontrol->get_playlist_pos && $wantedpos <= 0) ) {
			$wantedpos = 0;
		}
		my $wantedpos = $xmmscontrol->get_playlist_pos + $wantedpos;
		$title = $xmmscontrol->get_playlist_title($wantedpos);
		my $seconds = ($xmmscontrol->get_output_time/1000)%60;
		my $tmp = length($seconds);
		if($tmp == "1") {
			$seconds = "0" . $seconds;
		}
		$position = int($xmmscontrol->get_output_time/60000) . ":" . $seconds;
		$time = $xmmscontrol->get_playlist_timestr($wantedpos);
		if ($xmmscontrol->is_playing) {
			if ($xmmscontrol->is_paused) {
				$status = "Paused";
			} else {
				$status = "Playing";
			}
		} else {
			$status = "Stopped";
		}
		$filename = $xmmscontrol->get_playlist_file($wantedpos);
		
		$title =~ s/[\r\n]/ /g;
		$filename =~ s/[\r\n]/ /g;
		
		return($position, $title, $time, $status, $filename);
	} elsif ($_[0] =~ "filename") {
		my $xmmscontrol = Xmms::Remote->new;
		my $wantedpos = $_[0];
		$wantedpos =~ s/filename //;
		unless ($wantedpos =~ /^-?\d+$/ && (( $wantedpos + $xmmscontrol->get_playlist_pos <= $xmmscontrol->get_playlist_length-1 && $wantedpos >= 0) || 0-$wantedpos <= $xmmscontrol->get_playlist_pos && $wantedpos <= 0) ) {
			$wantedpos = 0;
		}
		$wantedpos = $xmmscontrol->get_playlist_pos + $wantedpos;
		$filename = $xmmscontrol->get_playlist_file($wantedpos);
		$filename =~ s/[\r\n]/ /g;
		return($filename);
	}
}

sub ctcp_info {
 if (Irssi::settings_get_bool('l33tctcp_enabled') && Xmms::Remote->new->is_running) {
	my ($server, $msg, $nick, $address, $channel) = @_;
	my ($p, $n, $t, $s) = getvars("songinfo $msg");
	my $reply = Irssi::settings_get_str('l33tctcpreply');
	$reply =~ s/(\$\w+)/$1/eeg;
	$server->command("^notice $nick $reply");
	Irssi::statusbar_items_redraw('l33tmusic');
 }
}

sub triggersend {
	my $trigger = Irssi::settings_get_str('l33ttrigger');
	if ($_[1] =~ /^$trigger/) {
		if (Irssi::settings_get_bool('l33ttrigger_enabled')) {
			$_[1] =~ s/$trigger //g;
			$_[1] = getvars("filename $_[1]");
			$_[0]->command("DCC SEND $_[2] \"$filename\"");
		} else {
			$_[0]->command("^notice $_[2] Trigger currently disabled");
		}
	}
}

sub themainthingie {
	if (Xmms::Remote->new->is_running) {
		my ($msg, $server, $nick, $address, $channel) = @_;
		my $command;
		my ($p, $n, $t, $s, $f) = getvars("songinfo 0");
		#The -m switch will echo the info in the status window,
		#I have this bound to meta-q :), takes a numerical argument
		#same as the -s switch
		if ($msg =~ "^-m") {
			$msg =~ s/^-m //;
			my ($p, $n, $t, $s, $f) = getvars("songinfo " . $msg);
			print CLIENTCRAP "" . simple_hash("$n") . "$n ($p / $t)";
			$command = "";
		#This allows a fully customized message, to be used in
		#aliases, since it's not fun to write the full thing every
		#time
		} elsif ($msg =~ "^-e") {
			$msg =~ s/^\-e //;
			$command = "$msg";
		#The -c switch is now fixed mostly, it seems that you
		#can do whatever you want, and if it happens to match
		#a proper command such as jump_to_timestr and you pass
		#the right parameter, it works, otherwise i made it not
		#crash anymore, weee :)
		} elsif ($msg =~ "^-c") {
			$msg =~ s/^\-c //;
			my $thingie;
			my ($msg, $reply, $param) = split(/ /, "$msg", 3);
			if ($param) {
				return unless eval {
					$thingie = Xmms::Remote->new->$reply($param);
				}
			} else {
				return unless eval {
					$thingie = Xmms::Remote->new->$reply;
				}
			}
			if ($thingie) {
				$command = "$msg $thingie";
			}
		#The -f switch has been removed, please use
		#/l33tmusic -e /colme or /colsay from the 
		#ascii.pl script to get better functionality

		#This switch will send the currently playing song to
		#the nick on the command line, takes a numerical
		#argument like the -m switch
		} elsif ($msg =~ "^-s") {
			$msg =~ s/^-s //;
			(my $friend, $msg) = split " ", $msg;
			$friend =~ s/ //;
			my ($p, $n, $t, $s, $f) = getvars("songinfo " . $msg);
			$server->command("dcc send $friend \"$f\"");
		#If a string was given, put it in front of the info, and
		#anything after a # after the info. If nothing is in front
		#of the #, throw in the string from the settings.
		} elsif ($msg) {
			my $msg2;
			$msg =~ s/(\$\w+)/$1/eeg;
			($msg, $msg2) = split "#", $msg;
			if ($msg =~ /^$/) {
				$msg = Irssi::settings_get_str('l33tstringplaying');
			}
			$command = "me $msg $n ($p / $t) $msg2";
		#Just go with the defaults
		} else {
			if ( $s eq "Playing" ) {
				$command = Irssi::settings_get_str('l33tstringplaying');
				$command = Irssi::settings_get_str('l33tstringaction') . " $command " . Irssi::settings_get_str('l33tstringsongformat');
			} else {
				$command = "echo Xmms is $s";
			}
		}
		$command =~ s/(\$\w+)/$1/eeg;
		$command =~ s/\s+/ /g;
		if ($command) {
			Irssi::active_win()->command("$command");
		}
	}else {
		Irssi::active_win()->command("echo Xmms isn't currently running");
	}
}

sub checkformpg123 {
	my ($msg, $server, $witem) = @_;
	if ($msg =~ /^Playing( MPEG stream from )?/) {
		$msg =~ s/Playing MPEG stream from //;
		$msg =~ s/Playing //;
		$msg =~ s/%20/ /g;
		$msg =~ s/\.(mp3|ogg)( \.\.\.)?//i;
		$msg =~ s/_/ /g;
		$msg =~ s/oc remix//i;
		$msg = Irssi::settings_get_str('l33tstringaction') . " " . Irssi::settings_get_str('l33tstringplayingmpg123') . " $msg";
		Irssi::signal_stop();
		Irssi::signal_remove('send text', 'checkformpg123');
		Irssi::signal_emit('send command', $msg, $server, $witem);
		Irssi::signal_add('send text', 'checkformpg123');
	}

}

my $statusbar_item;
my $refresh_tag;
my $scrollpos=0;
sub refresh_statusbar {
	my ($p, $no, $t, $s, $f) = getvars("songinfo 0");
	my $width=Irssi::active_win()->{width};
	my $n;
	my $others = Irssi::settings_get_str('l33tstatusbar');
	$others =~ s/\%.//g;
	$others =~ s/\$n//g;
	$others =~ s/(\$\w+)/$1/eeg;
	my $maxlength=$width - length($others);
	if (length($no) > $maxlength) {
		my $middlethingie = Irssi::settings_get_str('l33tmiddlethingie');
		$no = "$no $middlethingie";
		$n=substr(substr($no, $scrollpos, length($no)) . substr($no, 0, $scrollpos), 0, $maxlength);
		$scrollpos++;
		$scrollpos=0 if ($scrollpos + 1 > length($no));
	} else {
		$n = $no;
	}
	$n =~ s/\%/\%\%/g;
	$statusbar_item = Irssi::settings_get_str('l33tstatusbar');
	$statusbar_item =~ s/(\$\w+)/$1/eeg;
	Irssi::statusbar_items_redraw('l33tmusic');
}

sub l33tmusic_statusbar {
	my ($item, $get_size_only) = @_;
	$item->default_handler($get_size_only, "$statusbar_item", undef, 1);
}


Irssi::signal_add('send text', 'checkformpg123');
Irssi::command_bind('l33tmusic', 'themainthingie');
Irssi::settings_add_str('infopipe', 'l33tstringaction', '/me');
Irssi::settings_add_str('infopipe', 'l33tstringplayingmpg123', 'is listening to');
Irssi::settings_add_str('infopipe', 'l33tstringplaying', 'is listening to');
Irssi::settings_add_str('infopipe', 'l33tstatusbar', '$n ($p / $t)');
Irssi::settings_add_str('infopipe', 'l33tstatusbarrefresh', '500');
Irssi::settings_add_str('infopipe', 'l33tmiddlethingie', '*** ');
Irssi::settings_add_str('infopipe', 'l33tstringsongformat', '$n ($p / $t)');
Irssi::settings_add_str('infopipe', 'l33tctcpreply', 'I\'m listening to $n ($p / $t) Status: $s');
Irssi::settings_add_str('infopipe', 'l33ttrigger', '¡yourtriggerhere');
Irssi::settings_add_bool('infopipe', 'l33ttrigger_enabled', 0);
Irssi::settings_add_bool('infopipe', 'l33tctcp_enabled', 0);
Irssi::settings_add_bool('infopipe', 'l33twarning_read', 0);
Irssi::signal_add("ctcp msg music", "ctcp_info");
Irssi::signal_add_last("message public", "triggersend");
Irssi::statusbar_item_register('l33tmusic', undef, 'l33tmusic_statusbar');
$refresh_tag=Irssi::timeout_add(Irssi::settings_get_str('l33tstatusbarrefresh'), 'refresh_statusbar', undef);
unless (Irssi::settings_get_bool('l33twarning_read')) {
	print CLIENTCRAP "Type /set l33t to see all available settings. To remove this message, please type /set l33twarning_read on. Type /set l33t to list all options.";
	print CLIENTCRAP "If you want statusbar, add \'l33tmusic = { placement = \"top\"; items = { l33tmusic = { }; }; };\' to your config file, above \'topic = {\', and do a /reload.";
}
