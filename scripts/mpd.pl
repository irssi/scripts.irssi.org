# MPD Now-Playing Script for irssi
# Copyright (C) 2005 Erik Scharwaechter
# <diozaka@gmx.de>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 2
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# The full version of the license can be found at
# http://www.gnu.org/copyleft/gpl.html.
#
#
#######################################################################
# I'd like to thank Bumby <bumby@evilninja.org> for his impc script,  #
# which helped me a lot with making this script.                      #
#######################################################################
# Type "/np help" for a help page!                                    #
#######################################################################
# TODO:                                                               #
#######################################################################
# CHANGELOG:                                                          #
#  0.4: First official release                                        #
#  0.5: Info message if no song is playing                            #
#       Display alternative text if artist and title are not set      #
#       Some minor changes                                            #
#  0.6: Added some more format directives(time, album)                #
#       Added support for password authentication                     #
#  0.7: Added format directives for bitrate and volume                #
#       Fixed socket not timing out at specified interval             #
#######################################################################

use strict;
use IO::Socket;
use Irssi;

use vars qw{$VERSION %IRSSI %MPD};

$VERSION = "0.7";
%IRSSI = (
          name        => 'mpd',
          authors     => 'Erik Scharwaechter, Tobias Böhm, Mikkel Kroman',
          contact     => 'diozaka@gmx.de, code@aibor.de, mk@maero.dk',
          license     => 'GPLv2',
          description => 'print the song you are listening to',
         );

sub my_status_print {
    my($msg,$witem) = @_;

    if ($witem) {
        $witem->print($msg);
    } else {
        Irssi::print($msg);
    }
}

sub np {
    my($data,$server,$witem) = @_;

    if ($data =~ /^help/) {
        help();
        return;
    }

    $MPD{'port'}     = Irssi::settings_get_str('mpd_port');
    $MPD{'host'}     = Irssi::settings_get_str('mpd_host');
    $MPD{'password'} = Irssi::settings_get_str('mpd_password');
    $MPD{'timeout'}  = Irssi::settings_get_str('mpd_timeout');
    $MPD{'format'}   = Irssi::settings_get_str('mpd_format');
    $MPD{'alt_text'} = Irssi::settings_get_str('mpd_alt_text');

    my $socket = IO::Socket::INET->new(
                          Proto    => 'tcp',
                          PeerPort => $MPD{'port'},
                          PeerAddr => $MPD{'host'},
                          Timeout  => $MPD{'timeout'}
                          );

    if (not $socket) {
        my_status_print('No MPD listening at '.$MPD{'host'}.':'.$MPD{'port'}.'.', $witem);
        return;
    }


    my $ans = "";

    if ($MPD{'password'} =~ /^.+$/) {
        print $socket 'password ' . $MPD{'password'} . "\n";

        while (not $ans =~ /^(OK$|ACK)/) {
            $ans = <$socket>;
        }

        if ($ans =~ /^ACK \[...\] {.*?} (.*)$/){
            my_status_print('Auth Error: '.$1, $witem);
            close $socket;
            return;
        }
    }


    $MPD{'status'}   = "";
    $MPD{'artist'}   = "";
    $MPD{'album'}    = "";
    $MPD{'title'}    = "";
    $MPD{'filename'} = "";
    $MPD{'elapsed'}  = "";
    $MPD{'total'}    = "";
    $MPD{'volume'}   = "";
    $MPD{'bitrate'}  = "";

    my $ans = "";
    my $str = "";

    print $socket "status\n";
    while (not $ans =~ /^(OK$|ACK)/) {
        $ans = <$socket>;
        if ($ans =~ /^ACK \[...\] {.*?} (.*)$/){
            my_status_print($1, $witem);
            close $socket;
            return;
        } elsif ($ans =~ /^state: (.+)$/) {
            $MPD{'status'} = $1;
        } elsif ($ans =~ /^time: (\d+):(\d+)$/) {
            $MPD{'elapsed'} = sprintf("%01d:%02d", $1/60,$1%60);
            $MPD{'total'} = sprintf("%01d:%02d", $2/60,$2%60);
        } elsif ($ans =~ /^volume: (\d+)$/) {
            $MPD{'volume'} = $1
        } elsif ($ans =~ /^bitrate: (\d+)$/) {
            $MPD{'bitrate'} = $1
        }
    }

    if ($MPD{'status'} eq "stop") {
        my_status_print("No song playing in MPD.", $witem);
        close $socket;
        return;
    }

    print $socket "currentsong\n";
    $ans = "";
    while (not $ans =~ /^(OK$|ACK)/) {
        $ans = <$socket>;
        if ($ans =~ /file: (.+)$/) {
            my $filename = $1;
            $filename =~ s/.*\///;
            $MPD{'filename'} = $filename;
        } elsif ($ans =~ /^Artist: (.+)$/) {
            $MPD{'artist'} = $1;
        } elsif ($ans =~ /^Album: (.+)$/) {
            $MPD{'album'} = $1;
        } elsif ($ans =~ /^Title: (.+)$/) {
            $MPD{'title'} = $1;
        }
    }

    close $socket;

    if ($MPD{'artist'} eq "" and $MPD{'title'} eq "") {
        $str = $MPD{'alt_text'};
    } else {
        $str = $MPD{'format'};
    }

    $str =~ s/\%ARTIST/$MPD{'artist'}/g;
    $str =~ s/\%ALBUM/$MPD{'album'}/g;
    $str =~ s/\%TITLE/$MPD{'title'}/g;
    $str =~ s/\%FILENAME/$MPD{'filename'}/g;
    $str =~ s/\%ELAPSED/$MPD{'elapsed'}/g;
    $str =~ s/\%TOTAL/$MPD{'total'}/g;
    $str =~ s/\%BITRATE/$MPD{'bitrate'}/g;
    $str =~ s/\%VOLUME/$MPD{'volume'}/g;

    if ($witem && ($witem->{type} eq "CHANNEL" ||
                   $witem->{type} eq "QUERY")) {
        if($MPD{'format'} =~ /^\/me /) {
            $witem->command($str);
        } else {
            $witem->command("MSG ".$witem->{name}." $str");
        }
    } else {
        Irssi::print("You're not in a channel.");
    }
}


sub help {
   print '
 MPD Now-Playing Script
========================

by Erik Scharwaechter (diozaka@gmx.de)
extended by Tobias Böhm (code@aibor.de)

VARIABLES
  mpd_host      The host that runs MPD (localhost)
  mpd_port      The port MPD is bound to (6600)
  mpd_password  A password for a profile with at least read permissions - optional ()
  mpd_timeout   Connection timeout in seconds (5)
  mpd_format    The text to display (np: %%ARTIST - %%TITLE)
  mpd_alt_text  The Text to display, if %%ARTIST and %%TITLE are empty (np: %%FILENAME)

USAGE
  /np           Print the song you are listening to
  /np help      Print this text
';
}


Irssi::settings_add_str('mpd', 'mpd_host', 'localhost');
Irssi::settings_add_str('mpd', 'mpd_port', '6600');
Irssi::settings_add_str('mpd', 'mpd_password', '');
Irssi::settings_add_str('mpd', 'mpd_timeout', '5');
Irssi::settings_add_str('mpd', 'mpd_format', 'np: %ARTIST - %TITLE');
Irssi::settings_add_str('mpd', 'mpd_alt_text', 'np: %FILENAME');

Irssi::command_bind np        => \&np;
Irssi::command_bind 'np help' => \&help;

