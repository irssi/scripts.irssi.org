use strict;
use vars qw($VERSION %IRSSI);
# Consolidate Irssi Player
#
# Copyright (C) 2009 Dani Soufi
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# Change Log:
# v2.2:
#       - change the audacious and audtool command name
# v2.0.1b:
#       - Cleaning some unusefull code.
#       - Show an error when a command is executed in a wrong window, instead of exiting silently.
# v2.0.0:
#       - Start/Play(Toggle)/Stop/Pause/Unpause/Next/Previous/Volume MOC Player control functions are added.
#       - MOC Player support is implemented.
# v1.1.2:
#       - The script is now meant to be a bit more intelligent in dealing with song tags and different user song display settings.
#       - Display album name in --details if it exists.
# v1.1.0:
#       - Script's name is renamed to Consolidate Irssi Player on global basis to expand it's use in the future.
#       - Removed cmd_shuffle{} and cmd_repeat{} functions since they aren't supported anymore by Audacious2.
#       - Added use --details flag for bitrate and frequency details in current playing song.
#       - Added Jump to specific song in the playing list according to track number.
#       - Added Volume control support from Irssi.
#       - Updated the script to work with the newest Audacious v2 and audtool2 available.
# v1.0.4:
#       - Added Repeat on/off capability
#       - Added Shuffle on/off capability
#       - Fixed script output handling for audacious version in case audacious isn't running
#       - If encountered a problem with audacious version, try changing `audacious --version` to `audtool -v`
# v1.0.3:
#       - Added Playlist functionality
#       - Added Song details (Bitrate/Frequency/Length/Volume)
#       - Current song notice with song details (Optional)
# v1.0.2:
#       - The script now handles warning support if you got audacious not running
#       - Added track number, current time elapse and total track time
#       - Added Stop functionality
# v1.0.1:
#       - Added ability to autonotify the channel after skipping a song (optional)
#       - Added Skip/Play/Pause/Resume calls
#
# How To Use?
# Copy your script into ~/.irssi/scripts/ directory
# Load your script with /script load audacious in your Irssi Client
# Type '/audacious help' in any channel for script commands
# For autoload insert your script into ~/.irssi/scripts/autorun/ directory
# Even better would be if you placed them in ~/.irssi/scripts/ and created symlinks in autorun directory
#
use Irssi;
use IPC::Open3;

$VERSION = '2.2';
%IRSSI = (
   authors      =>   "Dani Soufi (compengi)",
   contact      =>   "IRC: Freenode network, #ubuntu-lb",
   name         =>   "Consolidate Irssi Player",
   description  =>   "Controls Audacious2 and MOCP from Irssi",
   license      =>   "GNU General Public License",
   url          =>   "http://git.peersnode.net/",
   changed      =>   "2019-01-20",
);

#################################################################################
# Please do not change anything below this, unless you know what you are doing. #
#################################################################################

# command names of audacious and audtool
my $c_audtool="audtool";
my $c_audacious="audacious";

# Give an error when a command is used where it was not supposed to, instead
# of exiting silently. Much better this way.
sub cmd_err {
   print "Error: This command can't be executed in this window.";
}

sub cmd_aud_song {
   my ($data, $server, $witem) = @_;
	# Get current song information.
  if ($witem && ($witem->{type} eq "CHANNEL")) {
   my ($position, $song, $current, $total, $artist, $album, $title,
       $total, $bitrate, $frequency, $album);

   chomp($position = `$c_audtool --playlist-position`);
   chomp($song = `$c_audtool --current-song`);
   chomp($current = `$c_audtool --current-song-output-length`);
   chomp($total = `$c_audtool --current-song-length`);
   chomp($artist = `$c_audtool --current-song-tuple-data artist`);
   chomp($album = `$c_audtool current-song-tuple-data album`);
   chomp($title = `$c_audtool --current-song-tuple-data title`);
   chomp($total = `$c_audtool --current-song-length`);
   chomp($bitrate = `$c_audtool --current-song-bitrate-kbps`);
   chomp($frequency = `$c_audtool --current-song-frequency-khz`);
   chomp($album = `$c_audtool current-song-tuple-data album`);
   

   # Read output.
   my ( $wtr, $rdr, $err );
   my $pid = open3( $wtr, $rdr, $err,
                    $c_audtool, '--current-song-tuple-data', 'file-name') or die $!;

   # Make it global.
   my $file;
   {
                local $/;
                $file = <$rdr>;
                $file =~ s/\.(?i:mp3|cda|aa3|ac3|aif|ape|med|mpu|wave|mpc|oga|wma|ogg|wav|aac|flac)\n//;
   }

    if (`ps -C $c_audacious` =~ /audacious/) {
      if ($data ne "--details") {
        
	# If we notice that the user sorted his playlist
        # by song title, we will try to be nice and parse
        # the existing artist for him.
        if ($song !~ /$artist/) {
          # If $song is different from $album,
          # we add the artist to output line.
          # Else strip the album from $song.
          if ($song !~ /$album/) {
            # If we have no song tags, $song will be set to the file's name.
            # In this case, we drop the file's extension know to us and print it.
            if ($song =~ /$file/) {
              $witem->command("/me is listening to: $file ($current/$total)");
            }
            else {
            $witem->command("/me is listening to: $artist - $song ($current/$total)");
            }
          }
          else {
            $song =~ s/$album - //im;
            $witem->command("/me is listening to: $artist - $song ($current/$total)");
          }
        }
        else {
          $witem->command("/me is listening to: $artist - $title ($current/$total)");
        }
      }
      # Show more details in our output.
      if ($data eq "--details") {

        # Check against an empty string.
        # If it's empty, we don't print it.
        if ($album ne "") {
          # Make sure $song doesn't match $artist.
          # Else we print the $song as it is.
          if ($song !~ /$artist/) {
            # If $song is different from $album,
            # we add the artist to output line.
            # Else strip the album from $song.
            if ($song !~ /$album/) {
              if ($song =~ /$file/) {
                $witem->command("/me is listening to: $artist - $song from $album ($current/$total) [$bitrate Kbps/$frequency KHz]");
              }
            }
            else {
              $witem->command("/me is listening to: $artist - $title from $album ($current/$total) [$bitrate Kbps/$frequency KHz]");
            }
          }
          elsif ($song =~ /\[ $album \]/) {
            $witem->command("/me is listening to: $artist - $title from $album ($current/$total) [$bitrate Kbps/$frequency KHz]");
          }
          else {
            $song =~ s/$album - //im;
            $witem->command("/me is listening to: $song from $album ($current/$total) [$bitrate Kbps/$frequency KHz]");
          }
        }
        elsif ($song =~ /$file/) {
          $witem->command("/me is listening to: $file ($current/$total) [$bitrate Kbps/$frequency KHz]");
        }
        else {
          $witem->command("/me is listening to: $artist - $title ($current/$total) [$bitrate Kbps/$frequency KHz]");
        }
      }
    }
    else {
      $witem->print("Audacious is not currently running.");
    }
   return 1;
  }
  else {
     cmd_err();
  }
}

sub cmd_aud_next {
   my ($data, $server, $witem) = @_;
	# Skip to the next track.
   if ($witem && ($witem->{type} eq "CHANNEL")) {
    if (`ps -C audacious` =~ /audacious/) {
      my $next = `$c_audtool --playlist-advance`;

      $witem->print("Skipped to next track.");
    }
    else {
      $witem->print("Can't skip to next track. Check your Audacious.");
    }
   return 1;
   }
   else {
      cmd_err();
   }
}

sub cmd_aud_previous {
   my ($data, $server, $witem) = @_;
	# Skip to the previous track.
   if ($witem && ($witem->{type} eq "CHANNEL")) {
    if (`ps -C $c_audacious` =~ /audacious/) {
      my $reverse = `$c_audtool --playlist-reverse`;

      $witem->print("Skipped to previous track.");
   }
    else {
      $witem->print("Can't skip to next track. Check your Audacious.");
    }
   return 1;
   }
   else {
      cmd_err();
   }
}

sub cmd_aud_play {
   my ($data, $server, $witem) = @_;
	# Start playback.
   if ($witem && ($witem->{type} eq "CHANNEL")) {
    if (`ps -C $c_audacious` =~ /audacious/) {
      my $play = `$c_audtool --playback-play`;

      $witem->print("Started playback.");
   }
    else {
      $witem->print("Playback can't be performed now.");
    }
   return 1;
   }
   else {
      cmd_err();
   }
}

sub cmd_aud_pause {
   my ($data, $server, $witem) = @_;
	# Pause playback.
   if ($witem && ($witem->{type} eq "CHANNEL")) {
    if (`ps -C $c_audacious` =~ /audacious/) {
      my $pause = `$c_audtool --playback-pause`;

      $witem->print("Paused playback.");
   }
    else {
      $witem->print("Pause can be only performed when Audacious is running.");
    }
   return 1;
   }
   else {
      cmd_err();
   }
}

sub cmd_aud_stop {
   my ($data, $server, $witem) = @_;
	# Pause playback.
   if ($witem && ($witem->{type} eq "CHANNEL")) {
    if (`ps -C $c_audacious` =~ /audacious/) {
      my $stop = `$c_audtool --playback-stop`;

      $witem->print("Stopped playback.");
   }
    else {
      $witem->print("This way you can't start Audacious.");
    }
   return 1;
   }
   else {
      cmd_err();
   }
}

sub cmd_aud_volume {
   my ($data, $server, $witem) = @_;
        # Set volume and make sure the value is an integer
	# that lays between 0 and 100.
   if ($witem && ($witem->{type} eq "CHANNEL")) {
    if (`ps -C $c_audacious` =~ /audacious/) {

     if ($data eq "") {
      $witem->print("Use /audacious volume <value> to set a specific volume value");
     }
     elsif ($data < 0 or $data > 100) {
       $witem->print("Given value is out of range [0-100].");
       return 0;
     }
     elsif ($data =~ /^[\d]+$/) {
       system $c_audtool,'--set-volume', $data;
       my $volume = `$c_audtool --get-volume`;
       chomp($volume);
       $witem->print("Volume is changed to $volume%%");
     }
     else {
       $witem->print("Please use a value [0-100] instead.");
     }
   }
    else {
      $witem->print("Volume can't be set in the current state.");
    }
   return 1;
   }
   else {
      cmd_err();
   }
}

sub cmd_aud_jump {
   my ($data, $server, $witem) = @_;
        # Jump to a specific track, making sure that
	# the selected track number exists.
   if ($witem && ($witem->{type} eq "CHANNEL")) {
    if (`ps -C $c_audacious` =~ /audacious/) {

     if ($data eq "") {
      $witem->print("Use /audacious jump <track> number to jump to it in your playlist.");
     }
     elsif ($data =~ /^[\d]+$/) {
       # Many thanks to Khisanth for this awesome fix!
       my ( $wtr, $rdr, $err );
       my $pid = open3( $wtr, $rdr, $err,
                        $c_audtool, '--playlist-jump', $data) or die $!;
       my $output;
       {
          local $/;
          $output = <$rdr>;
       }
       if ($output =~ /invalid/) {
        $witem->print("Track #$data isn't found in your playlist.");
       }
       else {
         $witem->print("Jumped to track #$data.");
       }
     }
     else {
       $witem->print("Please use a valid integer.");
     }
    }
    else {
     $witem->print("Start your audacious first.");
    }
   return 1;
   }
   else {
      cmd_err();
   }
}

sub cmd_aud_playlist {
   my ($data, $server, $witem) = @_;
	# Displays entire playlist loaded.
   if (`ps -C $c_audacious` =~ /audacious/) {
    my $display = `$c_audtool --playlist-display`;
    chomp($display);

    Irssi::print("$display");
   }
   else {
    $witem->print("Start your player first.");
    }
   return 1; 
}

sub cmd_aud_search {
   my ($data, $server, $witem) = @_;

   if ($witem && ($witem->{type} eq "CHANNEL")) {
    if (`ps -C $c_audacious` =~ /audacious/) {
     my $playlist = `$c_audtool --playlist-display`;
     my @matches;

     for (split /\n/, $playlist) {
      push @matches, $_ if /$data/i;
     }
     if (@matches) {
      $witem->print("Search Results:");
      for (@matches) {
       $_ =~ s/^\s+|\s+$//g;
       $witem->print("$_");
      }
     }
     else {
       $witem->print("Couldn't find any match(s) for your keyword '$data'.");
     }
    }
    else {
      $witem->print("Audacious is not running.");
    }
   }
   else {
      cmd_err();
   }
}


sub cmd_aud_details {
   my ($data, $server, $witem) = @_;

   # Displays current song's details.
   if ($witem && ($witem->{type} eq "CHANNEL")) {
    if (`ps -C $c_audacious` =~ /audacious/) {
     my ($bitrate, $frequency, $length, $volume);

     chomp($bitrate = `$c_audtool --current-song-bitrate-kbps`);
     chomp($frequency = `$c_audtool --current-song-frequency-khz`);
     chomp($length = `$c_audtool --current-song-length`);
     chomp($volume = `$c_audtool --get-volume`);

    $witem->print("Current song details: rate: $bitrate kbps - freq: $frequency KHz - l: $length min - vol: $volume%%");
   }
   else {
    $witem->print("Your player doesn't seem to be running");
    }
   return 1;
  }
  else {
     cmd_err();
  }
}

sub cmd_aud_version {
   my ($data, $server, $witem) = @_;

   my ($audtool, $audacious);
   chop($audtool = `$c_audtool --version`);
   chop($audacious = `$c_audacious --version`);

   # Displays version information to the channel.
   if ($witem && ($witem->{type} eq "CHANNEL")) {

    if ($data eq "--audtool") {
      $witem->command("/me is running: Consolidate Irssi Player v$VERSION with $audtool");
    }
    elsif ($data eq "--audacious") {
      $witem->command("/me is running: Consolidate Irssi Player v$VERSION with $audacious"); 
    }
   return 1;
  }
  else {
     Irssi::print("Consolidate Irssi Player v$VERSION on $audacious with $audtool");
  }
}

sub cmd_audacious {
   my ($data, $server, $witem) = @_;
    if ($data =~ m/^[(song)|(next)|(previous)|(play)|(pause)|(stop)|(help)|(volume)|(jump)|(playlist)|(details)|(about)|(search)]/i) {
      Irssi::command_runsub('audacious', $data, $server, $witem);
    }
    else {
      Irssi::print("Use /audacious <option> or check /help audacious for the complete list");
    }
}

sub cmd_aud_help {
   my ($data, $server) = @_;
	# Displays usage screen.
      Irssi::print("* /audacious song                 - Displays the current playing song in a channel.");
      Irssi::print("* /audacious song --details       - Displays bitrate and frequency with the current playing song.");
      Irssi::print("* /audacious next                 - Skips to the next song.");
      Irssi::print("* /audacious previous             - Skips to the previous song.");
      Irssi::print("* /audacious play                 - Starts playback.");
      Irssi::print("* /audacious pause                - Pauses playback.");
      Irssi::print("* /audacious stop                 - Stops playback.");
      Irssi::print("* /audacious volume <value>       - Sets volume [0-100].");
      Irssi::print("* /audacious jump <track>         - Jumps to specified track.");
      Irssi::print("* /audacious playlist             - Displays entire playlist.");
      Irssi::print("* /audacious search <keyword>     - Searches for the keyword in your playlist and displays the results.");
      Irssi::print("* /audacious details              - Displays current song's details.");
      Irssi::print("* /audacious version --audtool    - Displays version of the script and audtool in the channel.");
      Irssi::print("* /audacious version --audacious  - Displays version of the script and audacious in the channel.");
}

sub cmd_moc_song {
   my ($data, $server, $witem) = @_;
    if ($witem && ($witem->{type} eq "CHANNEL")) {

     if (`ps -C mocp` =~ /mocp/) {

       my $mocp = `mocp -i`;
       $mocp =~ /^State: (.*)$/m;
       my $state = $1;
       $mocp =~ /.*Title: (.*).*/;
       my $title = $1;
       $mocp =~ /.*TotalTime: (.*).*/;
       my $totaltime = $1;
       $mocp =~ /.*CurrentTime: (.*).*/;
       my $currenttime = $1;

      if ($data ne "--details") {
       if ($state eq '' || $state eq 'STOP') {
        $witem->print("MOC is not playing.");
       }
       else {
         $witem->command("/me is listening to: $title ($currenttime/$totaltime)");
       }
      }
 
      if ($data eq "--details") {
       if ($state eq '' || $state eq 'STOP') {
        $witem->print("MOC is not playing.");
       }
       else {
         $mocp =~ /.*Bitrate: (.*).*/;
         my $bitrate = $1;
         $mocp =~ /.*Rate: (.*).*/;
         my $rate = $1;
         $witem->command("/me is listening to: $title ($currenttime/$totaltime) [$bitrate/$rate]");
       }
      }
     }
     else {
       $witem->print("MOC is not started.");
     }
     return 1;
    }
    else {
       cmd_err();
    }
}

sub cmd_moc_next {
  my ($data, $server, $witem) = @_;
      # Advance to next track in playlist.
  if ($witem && ($witem->{type} eq "CHANNEL")) {

   if (`ps -C mocp` =~ /mocp/) {
    my $mocp = `mocp -i`;
    $mocp =~ /^State: (.*)$/m;
    my $state = $1;

    if ($state eq '' || $state eq 'STOP') {
        $witem->print("MOC is not playing.");
    }
    else {
      my $next = `mocp -f`;
      $witem->print("Skipped to next track.");
    }
   }
   else {
     $witem->print("Can't skip to next track. Check your MOC Player.");
   }
   return 1;
  }
  else {
     cmd_err();
  }
}

sub cmd_moc_previous {
  my ($data, $server, $witem) = @_;
      # Skip to previous track in playlist.
  if ($witem && ($witem->{type} eq "CHANNEL")) {

   if (`ps -C mocp` =~ /mocp/) {
    my $mocp = `mocp -i`;
    $mocp =~ /^State: (.*)$/m;
    my $state = $1;

    if ($state eq '' || $state eq 'STOP') {
        $witem->print("MOC is not playing.");
    }
    else {
      my $next = `mocp -r`;
      $witem->print("Skipped to previous track.");
    }
   }
   else {
     $witem->print("Can't skip to previous track. Check your MOC Player.");
   }
   return 1;
  }
  else {
     cmd_err();
  }
}

sub cmd_moc_play_toggle {
   my ($data, $server, $witem) = @_;
       # Start playback.
   if ($witem && ($witem->{type} eq "CHANNEL")) {

    if (`ps -C mocp` =~ /mocp/) {
     my $mocp = `mocp -i`;
     $mocp =~ /^State: (.*)$/m;
     my $state = $1;

     if ($state eq '' || $state eq 'STOP') {
         $witem->print("MOC is not playing.");
     }
     elsif ($state eq 'PLAY') {
       my $play_toggle = `mocp -G`;
       $witem->print("Paused playing song.");
     }
     else {
       my $play = `mocp -G`;
       $witem->print("Started playback.");
     }
   }
   else {
      $witem->print("Playback can't be performed now.");
    }
    return 1;
   }
   else {
      cmd_err();
   }
}

sub cmd_moc_pause {
   my ($data, $server, $witem) = @_;
	# Pause playback.
   if ($witem && ($witem->{type} eq "CHANNEL")) {

    if (`ps -C mocp` =~ /mocp/) {
     my $mocp = `mocp -i`;
     $mocp =~ /^State: (.*)$/m;
     my $state = $1;

     if ($state eq '' || $state eq 'STOP') {
         $witem->print("MOC is not playing.");
     }
     elsif ($state eq 'PAUSE') {
       $witem->print("The song is already paused.");
     }
     else {
       my $pause = `mocp -P`;
       $witem->print("Paused playback.");
     }
   }
   else {
      $witem->print("Pause can be only performed when your MOC Player is running.");
    }
   return 1;
   }
   else {
      cmd_err();
   }
}

sub cmd_moc_unpause {
   my ($data, $server, $witem) = @_;
	# Unpause playback, if and only if the previous song was paused.
   if ($witem && ($witem->{type} eq "CHANNEL")) {

    if (`ps -C mocp` =~ /mocp/) {
     my $mocp = `mocp -i`;
     $mocp =~ /^State: (.*)$/m;
     my $state = $1;

     if ($state eq '' || $state eq 'STOP') {
         $witem->print("MOC is not playing.");
     }
     elsif ($state eq 'PAUSE') {
       my $pause = `mocp -U`;
       $witem->print("Unpaused playback.");
     }
     else {
       $witem->print("Can't unpause your playing song.");
     }
   }
   else {
      $witem->print("Unpause can be only performed when your MOC Player is running.");
    }
   return 1;
   }
   else {
      cmd_err();
   }
}

sub cmd_moc_stop {
   my ($data, $server, $witem) = @_;
	# Stop the current playing song.
   if ($witem && ($witem->{type} eq "CHANNEL")) {

    if (`ps -C mocp` =~ /mocp/) {
     my $mocp = `mocp -i`;
     $mocp =~ /^State: (.*)$/m;
     my $state = $1;

     if ($state eq '' || $state eq 'STOP') {
         $witem->print("MOC is not playing.");
     }
     else {
       my $stop = `mocp -s`;
       $witem->print("Stopped playback.");
     }
   }
    else {
      $witem->print("This way you can't stop a song. Double check your player.");
    }
   return 1;
   }
   else {
      cmd_err();
   }
}

sub cmd_moc_volume {
   my ($data, $server, $witem) = @_;
        # Set volume and make sure the value is an integer
	# that lays between 0 and 100.
   if ($witem && ($witem->{type} eq "CHANNEL")) {
    if (`ps -C mocp` =~ /mocp/) {

     if ($data eq "") {
      $witem->print("Use /mocp volume <value> to set a specific volume value");
     }
     elsif ($data < 0 or $data > 100) {
       $witem->print("Given value is out of range [0-100].");
       return 0;
     }
     elsif ($data =~ /^[\d]+$/) {
       system 'mocp','-v', $data;
       $witem->print("Volume is changed to $data%%");
     }
     else {
       $witem->print("Please use a value [0-100] instead.");
     }
   }
    else {
      $witem->print("Volume can't be set when MOC Player is not functioning.");
    }
   return 1;
   }
   else {
      cmd_err();
   }
}

sub cmd_moc {
   my ($data, $server, $witem) = @_;
    if ($data =~ m/^[(song)|(next)|(previous)|(play)|(pause)|(unpause)|(stop)|(help)|(volume)]/i) {
      Irssi::command_runsub('mocp', $data, $server, $witem);
    }
    else {
      Irssi::print("Use /mocp <option> or check /help mocp for the complete list");
    }
}

sub cmd_moc_help {
   my ($data, $server) = @_;
	# Displays usage screen.
      Irssi::print("* /mocp song                 - Displays the current playing song in a channel.");
      Irssi::print("* /mocp song --details       - Displays bitrate and frequency with the current playing song.");
      Irssi::print("* /mocp next                 - Skips to the next song.");
      Irssi::print("* /mocp previous             - Skips to the previous song.");
      Irssi::print("* /mocp play                 - Starts playback.");
      Irssi::print("* /mocp pause                - Pauses playback.");
      Irssi::print("* /mocp stop                 - Stops playback.");
      Irssi::print("* /mocp volume <value>       - Sets volume [0-100].");
}

Irssi::command_bind ('audacious song', 'cmd_aud_song');
Irssi::command_bind ('audacious next', 'cmd_aud_next');
Irssi::command_bind ('audacious previous', 'cmd_aud_previous');
Irssi::command_bind ('audacious play', 'cmd_aud_play');
Irssi::command_bind ('audacious pause', 'cmd_aud_pause');
Irssi::command_bind ('audacious stop', 'cmd_aud_stop');
Irssi::command_bind ('audacious help', 'cmd_aud_help');
Irssi::command_bind ('audacious volume', 'cmd_aud_volume');
Irssi::command_bind ('audacious jump', 'cmd_aud_jump');
Irssi::command_bind ('audacious playlist', 'cmd_aud_playlist');
Irssi::command_bind ('audacious details', 'cmd_aud_details');
Irssi::command_bind ('audacious version', 'cmd_aud_version');
Irssi::command_bind ('audacious', 'cmd_audacious');
Irssi::command_bind ('mocp song', 'cmd_moc_song');
Irssi::command_bind ('mocp next', 'cmd_moc_next');
Irssi::command_bind ('mocp previous', 'cmd_moc_previous');
Irssi::command_bind ('mocp play', 'cmd_moc_play_toggle');
Irssi::command_bind ('mocp pause', 'cmd_moc_pause');
Irssi::command_bind ('mocp unpause', 'cmd_moc_unpause');
Irssi::command_bind ('mocp stop', 'cmd_moc_stop');
Irssi::command_bind ('mocp help', 'cmd_moc_help');
Irssi::command_bind ('mocp volume', 'cmd_moc_volume');
Irssi::command_bind ('mocp', 'cmd_moc');
Irssi::command_bind ('audacious search', 'cmd_aud_search');

Irssi::print("Consolidate Irssi Player v$VERSION is loaded successfully.");

# vim:set expandtab sw=2 ts=2:
