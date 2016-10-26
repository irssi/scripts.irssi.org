use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "2.3.1";
%IRSSI = (
    authors     => "Matti 'qvr' Hiljanen, Piotr 'Pieta' Szymanski",
    contact     => "matti\@hiljanen.com, pieta\@osiedle.net.pl",
    contributors => "bd\@bc-bd.org",
    name        => "wa",
    description => "shows what WinAmp is playing with /wa command",
    license     => "Public Domain",
    commands    => "wa",
    url         => "http://matin.maapallo.org/softa/irssi",
);
#
# Requires httpQ >= 1.8 (http://www.kostaa.com/)
# Requires also WinAmp2 plugin manager if you want to use it with WinAmp3
# (Component ID: 118230 @ winamp.com)
# 
# /SET httpq_ to configure the script
#   /SET httpq_command sets the command which is executed on /wa
#   the following expandos can be used with it:
#   %T (time)
#   %F (file name)
#   %P (percent)
#   %S (song name)
#   %L (lower cased song name)
#   httpq_command -setting was originally contributed by bd@bc-bd.org
#
# /SET httpq_trigger_ to configure the (very lame) public trigger
#   /SET httpq_trigger_command has all the same expandos as httpq_command
#   with some extra ones:
#   %N (nick that triggered the script)
#   %C (channel where the script was triggered)
#
# Known BUGS:
#   WinAmp 2 plugin manager doesn't get the name of the song that's first in 
#   playlist, nothing that I can do about it.. But other than that, it should work 
#   just fine.
# 
# Piotr Szymanski:
# 
# When using httpq_v3 you'd always get error (httpq returns 0 after sending a
# '/getoutputtime', '/getplaylistpos', '/getplaylisttitle' and '/ getplaylistfile'
# because of wrong args used in previous version). I just added proper args for 
# version 3 of httpq. Now it should work just fine.
#

use Socket;

my($waport, $wahost, $wapass, $di);

sub getstat($$$) {
    my ($host, $port, $data) = @_;
    $data = "$data HTTP/1.0\r\n\r\n";

   if (socket(SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp'))) {
        if (connect(SOCK, sockaddr_in($port, inet_aton($host)))) {
              unless (send(SOCK, $data, 0)) {
              Irssi::print("Unable to write to the socket: $!", MSGLEVEL_CLIENTERROR);
              return;
              }
        } else {
              Irssi::print("Unable to connect to the socket: $!", MSGLEVEL_CLIENTERROR);
              return;
        }
        } else {
        Irssi::print("Connection to $host failed: $!", MSGLEVEL_CLIENTERROR);
        return;
        }

# uncomment this for slow networks
#    sleep(1);
   
    my @lines = <SOCK>;
    close(SOCK);
    my $result = join("", @lines);
    $result =~ s/^HTTP.*\n//g;
    $result =~ s/^Server.*\n//g;
    $result =~ s/^Content.*\n//g;
    $result =~ s/^\r//g;
    $result =~ s/[\r,\n]//g;
    return $result;
}
    
sub check_version   {
   $wapass = Irssi::settings_get_str('httpq_password');
   $wahost = Irssi::settings_get_str('httpq_host');
   $waport = Irssi::settings_get_int('httpq_port');
my (undef,$version) = split(/x/, getstat($wahost, $waport, "GET /getversion?p=$wapass"));

if ($version >= 3000) {
   return 1000000;
} else {
   return 1;
}
}
sub parse_times ($$) {
   my $emulatorbug = check_version();
   my ($position, $length) = @_;
    $position = sprintf("%02d", int(($position/1000/60))).":"
       .sprintf("%02d", ($position/1000%60));
    if ($length eq "-1") {
       if ($di) {
          $length = "/di.fm";
       } else {
          $length = "/netradio";
       }
    } elsif ($length eq "0") {
       $length = "/sid";
    } else {
       $length = "/".sprintf("%02d", int(($length/$emulatorbug/60))).":"
          .sprintf("%02d", ($length/$emulatorbug%60));
    }
    my $result = "$position$length";
    return $result;
}

sub mkpercent ($$) {
   my $emulatorbug = check_version();
   my ($position, $length) = @_;
   my $result;
   my $numbers;
   if ($length eq "-1" || $length eq "0") {
      $result = "0";
   } else {
      $numbers = sprintf("%.0f",((($position/1000)/($length/$emulatorbug))*100));
      $result = "(${numbers}%)";
   }
   if ($numbers>100 || $numbers<0) {
      $result = "(wtf?)";
   }
   return $result;
}

sub vol_control($) {
   $wapass = Irssi::settings_get_str('httpq_password');
   $wahost = Irssi::settings_get_str('httpq_host');
   $waport = Irssi::settings_get_int('httpq_port');

   my ($direction) = @_;
   if (!$direction) {
      Irssi::print("Usage: /vol <up|down>");
      return; 
   }
   
   if ($direction eq "up") {
      Irssi::print("Vol up..") if getstat($wahost, $waport, "GET /volumeup?p=$wapass");
   } elsif ($direction eq "down") {
      Irssi::print("Vol down..") if getstat($wahost, $waport, "GET /volumedown?p=$wapass");
   }
}


# this function from bd@bc-bd.org
sub expand {
   my ($string, %format) = @_;
   my ($exp, $repl);
   $string =~ s/%$exp/$repl/g while (($exp, $repl) = each(%format));
   return $string;
}

sub main_wa {
   $wapass = Irssi::settings_get_str('httpq_password');
   $wahost = Irssi::settings_get_str('httpq_host');
   $waport = Irssi::settings_get_int('httpq_port');
   my $status = getstat($wahost, $waport, "GET /isplaying?p=$wapass");
   if ($status eq "1") {
      my $position = getstat($wahost, $waport, "GET /getoutputtime?p=$wapass&frmt=0"); #changed arg 'a' to 'frmt'/Pieta
      my $length = getstat($wahost, $waport, "GET /getoutputtime?p=$wapass&frmt=1"); #changed arg 'a' to 'frmt'/Pieta
      my $emulatorbug = check_version();
      my $song = getstat($wahost, $waport, "GET /getplaylisttitle?p=$wapass&index=" #changed arg 'a' to 'index'/Pieta
            .getstat($wahost, $waport, "GET /getplaylistpos?p=$wapass"));
      my $file = getstat($wahost, $waport, "GET /getplaylistfile?p=$wapass&index=" #changed arg 'a' to 'index'/Pieta
            .getstat($wahost, $waport, "GET /getplaylistpos?p=$wapass"));
      if ($emulatorbug > 1 && getstat($wahost, $waport, "GET /getplaylistpos?p=$wapass") == 0) {
         $song = "WA2 plugin emulator error";
         $file = "WA2 plugin emulator error";
      }
      # di.fm
      if ($song =~ /\s?\(D.?I.?G.?I.?T.?A.?L.?L.?Y.?-.?I.?M.?P.?O.?R.?T.?E.?D.*?\)/i) {
         $song =~ s/\s?\(D.?I.?G.?I.?T.?A.?L.?L.?Y.?-.?I.?M.?P.?O.?R.?T.?E.?D.*?\)//i;
	 $di = 1;
      } else {
	 $di = 0;
      }
      my $lc = lc($song);
      my $time = parse_times($position, $length);
      my $percent = mkpercent($position, $length);
      if (!$percent) {
         $percent = '';
      }
      #my $final = "np: '$song' [$time$percent]";
      
      my $final = expand(Irssi::settings_get_str("httpq_command"),
            "S", $song,
            "T", $time,
            "P", $percent,
            "F", $file,
            "L", $lc);
      
      Irssi::active_win()->command("$final");
   } elsif ($status eq "3") {
         Irssi::print("WinAmp is paused.");
   } else {
      Irssi::print("WinAmp isn't playing any song.");
   }
}

sub trigger{
      my($server,$text,$nick,$hostmask,$channel)=@_;
      return unless Irssi::settings_get_bool('httpq_trigger_enabled');
      my $trigger = Irssi::settings_get_str('httpq_trigger_string');
      $trigger = "!lame" if !$trigger;
      return unless ($text =~ /^$trigger$/);
      
      # now just a copy and paste of most of the main_wa function
      # this sucks, if you figure out a better way PLEASE send me a patch :)
      
      $wapass = Irssi::settings_get_str('httpq_password');
      $wahost = Irssi::settings_get_str('httpq_host');
      $waport = Irssi::settings_get_int('httpq_port');
      my $status = getstat($wahost, $waport, "GET /isplaying?p=$wapass");
      if ($status eq "1") {
         my $position = getstat($wahost, $waport, "GET /getoutputtime?p=$wapass&frmt=0"); #changed arg 'a' to 'frmt'/Pieta
         my $length = getstat($wahost, $waport, "GET /getoutputtime?p=$wapass&frmt=1"); #changed arg 'a' to 'frmt'/Pieta
         my $emulatorbug = check_version();
         my $song = getstat($wahost, $waport, "GET /getplaylisttitle?p=$wapass&index=" #changed arg 'a' to 'index'/Pieta
               .getstat($wahost, $waport, "GET /getplaylistpos?p=$wapass"));
         my $file = getstat($wahost, $waport, "GET /getplaylistfile?p=$wapass&index=" #changed arg 'a' to 'index'/Pieta
               .getstat($wahost, $waport, "GET /getplaylistpos?p=$wapass"));
         if ($emulatorbug > 1 && getstat($wahost, $waport, "GET /getplaylistpos?p=$wapass") == 0) {
            $song = "WA2 plugin emulator error";
            $file = "WA2 plugin emulator error";
         }
	 # di.fm
         if ($song =~ /\s?\(D.?I.?G.?I.?T.?A.?L.?L.?Y.?-.?I.?M.?P.?O.?R.?T.?E.?D.*?\)/i) {
            $song =~ s/\s?\(D.?I.?G.?I.?T.?A.?L.?L.?Y.?-.?I.?M.?P.?O.?R.?T.?E.?D.*?\)//i;
            $di = 1;
         } else {
            $di = 0;
         }
         my $lc = lc($song);
         my $time = parse_times($position, $length);
         my $percent = mkpercent($position, $length);
         if (!$percent) {
            $percent = '';
         }

         my $final = expand(Irssi::settings_get_str("httpq_trigger_command"),
               "S", $song,
               "T", $time,
               "P", $percent,
               "N", $nick,
               "F", $file,
               "C", $channel,
               "L", $lc);

        $server->command("$final");
        }
}

#
# the statusbar item code used to be here, but i doubt anyone ever used it so
# i removed it completely. it was buggy and, imo, useless :)
#

Irssi::command_bind('wa', 'main_wa');
Irssi::command_bind('vol', 'vol_control');

Irssi::settings_add_str('misc', 'httpq_password', "password");
Irssi::settings_add_str('misc', 'httpq_host', "hostname");
Irssi::settings_add_int('misc', 'httpq_port', "4800");
Irssi::settings_add_str('misc', 'httpq_command', "say np: '%S' [%T %P]");

#trigger settings
Irssi::settings_add_bool('misc', 'httpq_trigger_enabled', 0);
Irssi::settings_add_str('misc', 'httpq_trigger_string', "!lame");
Irssi::settings_add_str('misc', 'httpq_trigger_command', "notice %N np: '%S' [%T %P]");
Irssi::signal_add_last("message public","trigger");

#EOF
