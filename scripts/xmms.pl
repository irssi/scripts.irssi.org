# XMMS-InfoPipe front-end - allow /np [dest]
#
#   Thanks to ak for suggestions and even changes.
#
#   /set xmms_fifo <dest of xmms-infopipe fifo>
#   /set xmms_format <format of printed text>
#   /set xmms_format_streaming <format for streams>
#   /set xmms_print_if_stopped <ON|OFF>
#   /set xmms_format_time <time format> - default is %m:%s
# 
#   xmms_format* takes these arguments:
#       Variable    Name        Example
#   ----------------------------------------------------
#   Song specific:
#       %status     Status          Playing
#       %title      Title           Blue Planet Corporation - Open Sea
#       %file       File            /mp3s/blue planet corporation - open sea.mp3
#       %length     Length          9:13
#       %pos        Position        0:08
#       %bitrate    Bitrate         160kbps
#       %freq       Sampling freq.  44.1kHz
#       %pctdone    Percent done    1.4%
#       %channels   Channels        2
#   Playlist specific:
#       %pl_total   Total entries
#       %pl_current Position in playlist
#       ¤pl_pctdone Playlist Percent done
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
$VERSION = "2.0";
%IRSSI = {
    authors     => 'Simon Shine',
    contact     => 'simon@blueshell.dk',
    name        => 'xmms',
    description => 'XMMS-InfoPipe front-end - allow /np [-help] [dest]',
    license     => 'Public Domain',
    changed     => '2004-01-15'
};

Irssi::settings_add_str('xmms', 'xmms_fifo', '/tmp/xmms-info');
Irssi::settings_add_str('xmms', 'xmms_format', 'np: %title at %bitrate [%pos of %length]');
Irssi::settings_add_str('xmms', 'xmms_format_streaming', 'streaming: %title at %bitrate [%file]');
Irssi::settings_add_str('xmms', 'xmms_format_time', '%m:%s');
Irssi::settings_add_bool('xmms', 'xmms_print_if_stopped', 'yes');

Irssi::command_bind('np', \&cmd_xmms);
Irssi::command_bind('xmms', \&cmd_xmms);
# Tab completition
Irssi::command_bind('np help', \&cmd_xmms);
Irssi::command_bind('xmms help', \&cmd_xmms);

sub cmd_xmms {
    my ($args, $server, $witem) = @_;

    $args =~ s/^\s+//;
    $args =~ s/\s+$//;

    if ($args =~ /^help/) {
      print CRAP q{
Valid format strings for xmms_format and xmms_format_streaming:
    %%status, %%title, %%file, %%length, %%pos, %%bitrate,
    %%freq, %%pctdone, %%channels, %%pl_total, %%pl_current

Example: /set xmms_format np: %%title at %%bitrate [%%pctdone]

Valid format string for xmms_format_time:
    %%m, %%s

Example: /set xmms_format_time %%m minutes, %%s seconds
};
      return;
    }

    my ($xf) = Irssi::settings_get_str('xmms_fifo');
    if (!-r $xf) {
        if (!-r '/tmp/xmms-info') {
            Irssi::print "Couldn't find a valid XMMS-InfoPipe FIFO.";
            return;
        }
        $xf = '/tmp/xmms-info';
    }

    my %xi;

    open(XMMS, $xf);
    while (<XMMS>) {
        chomp;
        my ($key, $value) = split /: /, $_, 2;
        $xi{$key} = $value;
    }
    close(XMMS);

    my %fs;

    # %status
    $fs{'status'} = $xi{'Status'};
    # %title
    if ($fs{'status'} ne "Playing") {
        if (Irssi::settings_get_bool('xmms_print_if_stopped')) {
            $fs{'title'} = sprintf('(%s) %s', $fs{'status'}, $xi{'Title'});
        } else {
            Irssi::print "XMMS is currently not playing.";
            return;
        }
    } else {
        $fs{'title'} = $xi{'Title'};
    }
    # %file
    $fs{'file'} = $xi{'File'};
    # %length
    $fs{'length'} = &format_time($xi{'Time'});
    # %pos
    $fs{'pos'} = &format_time($xi{'Position'});
    # %bitrate
    $fs{'bitrate'} = sprintf("%.0fkbps", $xi{'Current bitrate'} / 1000);
    # %freq
    $fs{'freq'} = sprintf("%.1fkHz", $xi{'Samping Frequency'} / 1000);
    # %pctdone
    if ($xi{'uSecTime'} > 0) {
        $fs{'pctdone'} = sprintf("%.1f%%%%", ($xi{'uSecPosition'} / $xi{'uSecTime'}) * 100);
    } else {
        $fs{'pctdone'} = "0.0%%";
    }
    # %channels
    $fs{'channels'} = $xi{'Channels'};
    # %pl_total
    $fs{'pl_total'} = $xi{'Tunes in playlist'};
    # %pl_current
    $fs{'pl_current'} = $xi{'Currently playing'};
    # %pl_pctdone
    $fs{'pl_pctdone'} = sprintf("%.1f%%%%", ($fs{'pl_current'} / ($fs{'pl_total'} ? $fs{'pl_total'} : 1)) * 100);


    my ($format) = ($xi{'uSecTime'} == "-1") ?
        Irssi::settings_get_str('xmms_format_streaming') :
        Irssi::settings_get_str('xmms_format');
    foreach (keys %fs) {
        $format =~ s/\%$_/$fs{$_}/g;
    }

    # sending it.
    if ($server && $server->{connected} && $witem &&
        ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {
        if ($args eq "") {
            $witem->command("/SAY $format");
        } else {
            $witem->command("/MSG $args $format");
        }
    } else {
        Irssi::print($format);
    }
}

sub format_time {
    my ($m, $s) = split /:/, @_[0], 2;
    my ($format) = Irssi::settings_get_str('xmms_format_time');
    $format =~ s/\%m/$m/g;
    $format =~ s/\%s/$s/g;
    return $format;
}
