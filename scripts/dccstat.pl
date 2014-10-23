use strict;
use Irssi::Irc;
use Irssi 20020217; # Irssi 0.8.0
use vars qw($VERSION %IRSSI);
$VERSION = "1.52";
%IRSSI = (
    authors     => "Matti 'qvr' Hiljanen",
    contact     => 'matti\@hiljanen.com',
    contributors => 'stefan@pico.ruhr.de, dieck@gmx.de, peder@ifi.uio.no',
    name        => "dccstat",
    description => "Shows verbose or short information of dcc send/gets on statusbar (speed, size, eta etc.)",
    license     => "GPL, Version 2",
    url         => "http://matin.maapallo.org/softa/irssi",
    sbitems     => "dccstat"
);

# Theme settings:
#   sb_dccstat = "{sb $0-}";
#       $0 = sb_ds_short(_waiting)/sb_ds_normal(_waiting)
#   sb_ds_short = "$0%G:%n$1%Y@%n$2kB/s%G:%n$4%G:%n$3";
#       $0 = G/S
#       $1 = filename
#       $2 = transfer speed
#       $3 = percent
#       $4 = progressbar
#   sb_ds_short_waiting = "$0%G:%n$1 $2 $3 waiting";
#       $0 = G/S
#       $1 = filename
#       $2 = to/from
#       $3 = nick
#   sb_ds_normal = "$0 $1: '$2' $3 of $4 [$8] $9 ($5) $6kB/s ETA: $7";
#       $0 = GET/SEND
#       $1 = nick
#       $2 = filename
#       $3 = transferred amount
#       $4 = full filesize
#       $5 = percent
#       $6 = speed
#       $7 = ETA
#       $8 = progressbar
#       $9 = rotator thingy :)
#   sb_ds_normal_waiting = "$0 $1: '$2' $3 $4 $5 waiting";
#       $0 = GET/SEND
#       $1 = nick
#       $2 = filename
#       $3 = full filesize
#       $4 = to/from
#       $5 = nick
#   sb_ds_separator = ", ";
#
# TODO:
#   new ideas more than welcome :) 
# 
# FAQ:
#   Q: my input line gets cleared every time dcc send/get starts or ends,
#   why's that?!
#   A: it's a bug in irssi which is already fixed in cvs (2002-03-24 Sunday 20:06)
#   so the solution: upgrade to cvs or live with it and wait until the next stable release
#


use Irssi::TextUI;
use strict;

my $dccstat_refresh=5;
my ($refresh_tag, $old_refresh, $new_refresh, $displayed_since);
my $visible = -1;
my $displaying = 0;
my @rot_bar = ('|', '/', '-', '\\\\\\\\');
my $rot_bar_n = 0;
my %dccstat;

sub cmd_print_help {
     Irssi::print(
     "%_Dccstat.pl Help:%_\n\n".
     "Statusbar called dccstat should have appeared when you loaded this script,\n".
     "now you need to add the dccstat item into that statusbar:\n".
     "      /statusbar dccstat add dccstat\n".
     "      /save\n\n".
     " The default verbose mode will produce output like this:  \n".
     "      [GET nick: 'foobar.avi' 5500kB of 11MB (50%) 99kB/s ETA: 00:03:00]\n".
     " and the short mode looks like this:\n".
     "      [G:foobar.avi\@99kB/s:(50%)]\n\n".
     " %_/SETs:%_\n".
     "  /set dccstat_refresh <secs> (default: 5)\n".
     "  /set dccstat_short_mode <ON/OFF> (default: OFF)\n".
     "      shorter output and doesn't show DCCs: None when there are no GET/SENDs\n".
     "  /set dccstat_hide_sbar_when_inactive <ON/OFF> (default: OFF)\n".
     "      hides the statusbar called dccstat when there are no GET/SENDs\n".
     "  /set dccstat_auto_short_limit (default: 2)\n".
     "      amount of dcc sends/gets we can have before we automagically switch to short mode\n".
     "      (when all the info wouldn't fit to statusbar). setting it to 0 will disable it.\n".
     "  /set dccstat_progbar_width (default: 10)\n".
     "      progressbar width in chars\n".
     "  /set dccstat_progbar_transferred (default: '%%g=%%n')\n".
     "  /set dccstat_progbar_position (default: '%%y>%%n')\n".
     "  /set dccstat_progbar_remaining (default: '%%r-%%n')\n".
     "  /set dccstat_cycle_through_transfers (default: OFF)\n".
     "      cycle trough the transfers (ON) or show all transfers at the same time (OFF, default)\n".
     "  /set dccstat_cycle_through_transfers_refresh <secs> (default: 5)\n".
     "      how long to show one transfer at  a time\n".
     "  /set dccstat_filename_max_length (default: 17)\n".
     "  /set dccstat_filename_max_length_shortmode (default: 10)\n".
     "      how much to show of a filename in normal and short modes\n\n".
     "  /set dccstat_EXPERIMENTAL_fast_refresh (default: OFF)\n".
     "      use very experimental and super fast refreshing, will probably consume all cpu power,\n".
     "      depending on your connection speed. but hey, it's fun :)\n".
     "  /set dccstat_debug (default: OFF)\n".
     "      show debug messages\n".
     " \n".
     "\nSee also: STATUSBAR, DCC and theme help in the actual script"
     ,MSGLEVEL_CRAP);
}
     
sub debug {
    my ($text) = @_;
    return unless Irssi::settings_get_bool('dccstat_debug');
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = 
      localtime(time);
    $sec = sprintf("%02d", $sec);
    $min = sprintf("%02d", $min);
    $hour = sprintf("%02d", $hour);
    Irssi::print("DEBUG(%_Dccstat.pl%_): ".$text." [$hour:$min:$sec]");
}

sub startup_check {
    debug("START-UP - DEBUG IS ON");
    my @dccs = Irssi::Irc::dccs();
    my $act;
    foreach my $dcc (@dccs) { $act=$dcc if $dcc->{type} eq "SEND" || $dcc->{type} eq "GET"; };
    dcc_connected($act);
}

sub dcc_connected {
    debug("entering dcc_connected");
    my ($dcc) = @_;
    return unless $dcc->{type} eq "SEND" || $dcc->{type} eq "GET";
    debug("removing dcc connected -signal");
    Irssi::signal_remove('dcc connected', 'dcc_connected');
    my $refresh_msecs = (Irssi::settings_get_int('dccstat_refresh')*1000);
    $refresh_msecs = ($dccstat_refresh*1000) if $refresh_msecs < 1000;
    debug("adding normal timeout..");
    $refresh_tag=Irssi::timeout_add($refresh_msecs, 'refresh_dccstat', undef);
    $old_refresh=Irssi::settings_get_int('dccstat_refresh');
    Irssi::signal_add_last('dcc destroyed', 'dcc_checklast');
    refresh_dccstat();
}

sub dcc_setupcheck {
   $new_refresh = Irssi::settings_get_int('dccstat_refresh');
   if ($new_refresh != $old_refresh) {
      debug("setting a new refresh timeout");
	  $new_refresh = ($new_refresh*1000);
	  Irssi::timeout_remove($refresh_tag);
	  $new_refresh = ($dccstat_refresh*1000) if $new_refresh < 1000;
	  $refresh_tag=Irssi::timeout_add($new_refresh, 'refresh_dccstat', undef);
	  $old_refresh=Irssi::settings_get_int('dccstat_refresh');
   }
   refresh_dccstat();
}

sub dcc_checklast {
    my @dccs     = Irssi::Irc::dccs();
    my $count    = dcc_getcount();
    debug("check for last, count is '$count'");
    return unless $count == 0;
    debug("was last, removing timeout '$refresh_tag'");
    Irssi::timeout_remove($refresh_tag);
    Irssi::signal_remove('dcc destroyed', 'dcc_checklast');
    Irssi::signal_add('dcc connected', 'dcc_connected');
    refresh_dccstat();
}

# this function calculates the average speed of the last 10 seconds.
# i think that's better than irssis default way of calculating the 
# average speed from the whole transfer
sub dcc_calcSpeed {
   my @dccs = Irssi::Irc::dccs();
   foreach my $dcc (@dccs) {
      next unless $dcc->{type} eq "SEND" || $dcc->{type} eq "GET";
      my $id = "$dcc->{created}" . "$dcc->{addr}" . "$dcc->{port}";
      if (defined($dccstat{$id}{'speed'})) {
         my $old = $dccstat{$id}{'position'};
         my $current = $dcc->{transfd};
         my $speed = (($current-$old)/10);
         unless ($dccstat{$id}{'speed'} == "-1" && ($current-$old) == 0) {
            $dccstat{$id}{'speed'} = $speed;
         }
         $dccstat{$id}{'position'} = $current;
      } else {
         # new dcc
         my $id = "$dcc->{created}" . "$dcc->{addr}" . "$dcc->{port}";
         debug("creating dcc hash '$id'");
         $dccstat{$id}{'speed'} = "-1";
         $dccstat{$id}{'position'} = "0";
      }
   }

    # let's remove old hashes
    foreach my $hash (keys %dccstat) {
       my $keep = 0;
       foreach my $dcc (@dccs) {
          my $id = "$dcc->{created}" . "$dcc->{addr}" . "$dcc->{port}";
          $keep = 1 if ($hash == $id);
       }
       if ($keep) {
          debug("dcc '$hash' is still active, it's speed is '" . $dccstat{$hash}{'speed'} . "'");
       } else {
          debug("deleting dcc '$hash'");
          delete $dccstat{$hash};
       }
    }     
}

### this function originally implemented by dieck@gmx.de
sub dcc_calculateETA {
    my $dcc = $_[0];
    my ($dccspeed, $dccleft, $going, $dccsecs, $dcctime);
    
    # calculate current speed
    $going=(time-$dcc->{starttime});
    $going=1 if $going==0;
    my $id = "$dcc->{created}" . "$dcc->{addr}" . "$dcc->{port}";
    if (defined($dccstat{$id})) {
       $dccspeed=$dccstat{$id}{'speed'};
    } else {
       $dccspeed = -1;
    }
    ## speed in bytes/sec
    if ($dccspeed > 0) {
    
       # calculate left transfer size
       $dccleft = ($dcc->{size}-$dcc->{transfd});
       ## size left in byte
    
       $dccspeed=1 if $dccspeed==0;
       $dccsecs = $dccleft / $dccspeed;  
    
       $dcctime =  sprintf("%02d:%02d:%02d", int($dccsecs/60/60), int($dccsecs/60%60), int($dccsecs%60));
    } elsif ($dccspeed == "0") {
       $dcctime = "stalled";
    } elsif ($dccspeed == "-1") {
       $dcctime = "???";
    } else {
       # panic!
       $dcctime = "error!";
    }
    return $dcctime; 
}

### this function originally implemented by stefan_tomanek@web.de 
sub dcc_progbar {
    my ($dcc) = @_;
    my ($filebar, $nobar);
    my $barwidth = Irssi::settings_get_int('dccstat_progbar_width');
    my $char1 = Irssi::settings_get_str('dccstat_progbar_transferred');
    my $char2 = Irssi::settings_get_str('dccstat_progbar_position');
    my $char3 = Irssi::settings_get_str('dccstat_progbar_remaining');
    if ($dcc->{size} > 0) {
        my $width_per_size = ($barwidth) / $dcc->{size};
        my $transf_chars = sprintf("%.0f",($width_per_size * $dcc->{transfd}));
        $filebar = $char1 x $transf_chars; 
        $nobar = $char3 x ($barwidth - $transf_chars - 1);
        return "${filebar}${char2}${nobar}";
    } else {
        return $barwidth x $char3;
    }
}

sub dcc_calculateSIZE {
    my $fsize = $_[0];
    my ($size, $unit, $div);
    
    if       ($fsize >= 1024*1024*1024)  { $size = $fsize/1024/1024/1024; $unit = "GB"; $div = 2; }
    elsif    ($fsize >= 1024*1024)       { $size = $fsize/1024/1024; $unit = "MB";  $div = 2; }
    elsif    ($fsize >= 1024)            { $size = $fsize/1024; $unit = "kB"; $div = 0; }
    else                                 { $size = $fsize; $unit = "B"; $div = 0; }
    $size = sprintf("%.${div}f", $size);
    return "${size}${unit}";
}

sub dcc_getcount { 
    my @dccs  = Irssi::Irc::dccs();
    my $count = 0;
    foreach my $dcc (@dccs) { $count++ if $dcc->{type} eq "GET" || $dcc->{type} eq "SEND"; }
    return $count;
}

sub dccstat {
    #debug("going into main function"); 
    my ($item, $get_size_only) = @_;
    my @dccs=Irssi::Irc::dccs();
    my (@results, $results);
    my $mode      = Irssi::settings_get_bool('dccstat_short_mode');
    my $exp_flags = Irssi::EXPAND_FLAG_IGNORE_EMPTY | Irssi::EXPAND_FLAG_IGNORE_REPLACES;
    my $theme     = Irssi::current_theme();
    my $format    = $theme->format_expand("{sb_dccstat}");
    my $count     = dcc_getcount();
    if ($count>0) {
	my $sendcount=0;
	my $getcount=0;
	my (
	    $dccpercent,   $dccspeed,      $dcctype,   $going, 
	    $dccnick,      $dccfile,       $FooOfBar,  $str, 
	    $fsize,        $transize,      $dcceta,    $from, 
	    $to,           $direction,     $prep,      $autolimit,
	    $separator,    $dccprogbar,    $dccrotbar
	   );
	foreach my $dcc (@dccs) {
	    next unless $dcc->{type} eq "SEND" || $dcc->{type} eq "GET";
	    # if count is above the autolimit, we'll force the mode to short
        # but not if we're cycling through transfers.
        if (not Irssi::settings_get_bool('dccstat_cycle_through_transfers')) {
           $autolimit=Irssi::settings_get_int('dccstat_auto_short_limit');
	       $mode=1 if $count > $autolimit && $autolimit > 0;
        }
	    
	    $sendcount++ if $dcc->{type} eq "SEND";
	    $getcount++ if $dcc->{type} eq "GET";
	    
	    $dccpercent = ($dcc->{size} == 0) ? "(0%)" : sprintf("%.1f", $dcc->{transfd}/$dcc->{size}*100)."%%";
	    
       $going = (time-$dcc->{starttime});
	   $going = 1 if $going==0;
        
	    my $id = "$dcc->{created}" . "$dcc->{addr}" . "$dcc->{port}";
        if (defined($dccstat{$id})) {
           $dccspeed = $dccstat{$id}{'speed'};
        } else {
           $dccspeed = -1;
        }
        if ($dccspeed >= 0) {
           $dccspeed = sprintf("%.2f", ($dccspeed/1024));
        } else {
           $dccspeed = sprintf("%.2f", ($dcc->{transfd}-$dcc->{skipped})/$going/1024);
        }
              
        $dcctype = $dcc->{type};
	    
	    $dccnick = $dcc->{nick};
	    $dccnick =~ s/\\/\\\\/g;
	    $dccfile = $dcc->{arg};
	    $dccfile =~ s/ /\240/g;
	    $dccfile =~ s/\\/\\\\/g; 
	    
	    # if filename is longer than 17 chars, we'll show only the first 15 chars
	    # and in short mode we'll show only 8 chars
        # (lengths are now configurable, but the idea is the same)
	    my $max_normal = Irssi::settings_get_int('dccstat_filename_max_length');
        my $max_short = Irssi::settings_get_int('dccstat_filename_max_length_shortmode');
	    if (!$mode) { 
           $dccfile=substr($dccfile, 0, $max_normal-2).".." if (length($dccfile) > $max_normal); 
        } else {
           $dccfile=substr($dccfile, 0, $max_short-2).".." if (length($dccfile) > $max_short); 
        }
	    
	    $fsize      = dcc_calculateSIZE($dcc->{size});
	    $transize   = dcc_calculateSIZE($dcc->{transfd});
	    $dccprogbar = dcc_progbar($dcc);
	    $dccprogbar =~ s/ /\240/g;
	    $dcceta     = dcc_calculateETA($dcc);
	    
	    if ($dcctype eq "GET") { $direction = "G"; $prep = "from"; }
	    if ($dcctype eq "SEND") { $direction = "S"; $prep = "to"; }
	    
	    $dccrotbar  = $rot_bar[$rot_bar_n];
	    
	    # short mode?
	    if ($mode) {
		# theme?
		if ($format) {
		    if ($dcc->{starttime} > 0) {
			$str = $theme->format_expand("{sb_ds_short $direction $dccfile $dccspeed $dccpercent $dccprogbar $dccrotbar}", $exp_flags);
		    } else {
			$str = $theme->format_expand("{sb_ds_short_waiting $direction $dccfile $prep $dccnick}", $exp_flags);
		    }
		} else {
		    $str = "$direction%G:%n$dccfile";
		    $str .= ($dcc->{starttime} > 0) ? "%G@%n${dccspeed}kB/s%G:%n$dccprogbar%G:%n$dccrotbar%G:%n$dccpercent" : " $prep $dccnick waiting";
		}
	    } else {
		if ($format) {
		    if ($dcc->{starttime} > 0) {
			$str = $theme->format_expand("{sb_ds_normal $dcctype $dccnick $dccfile $transize $fsize $dccpercent $dccspeed $dcceta $dccprogbar $dccrotbar}", $exp_flags);
		    } else {
			$str = $theme->format_expand("{sb_ds_normal_waiting $dcctype $dccnick $dccfile $fsize $prep $dccnick}", $exp_flags);
		    }
		} else {
		    $str = "$dcctype $dccnick: '$dccfile'";
		    $str .= ($dcc->{starttime} > 0) ? " $transize of $fsize [$dccprogbar] $dccrotbar ($dccpercent) ${dccspeed}kB/s ETA: $dcceta" : " $fsize $prep $dccnick waiting";
		}
	    }
	    push @results,$str;
	}
	if (not Irssi::settings_get_bool('dccstat_cycle_through_transfers')) {
	    $separator = ($theme->format_expand("{sb_ds_separator}")) ? $theme->format_expand("{sb_ds_separator}") : ", ";
	    $results   = join("$separator", @results);
	} else {
	    if (scalar(@results)-1 < $displaying) { $displaying = 0 };
	    $results = @results[$displaying];
        if (not $get_size_only) {
           if ((time-$displayed_since) >= (Irssi::settings_get_int('dccstat_cycle_through_transfers_refresh'))) {
              debug("refreshing cycle display");
              $displaying++;
              $displayed_since = time;
           }
        }
	}
    } else {
	$results="%_DCCs:%_ None" if !$mode;
    }
    if ($format) {
	if ($count > 0) {
	    $results = "{sb_dccstat $results}"
	} else {
	    $results = "{sb_dccstat $results}" unless $mode;
	}
    } else {
	if ($count > 0) {
	    $results = "{sb $results}";
	} else {
	    $results = "{sb $results}" unless $mode;
	}
    }
    $item->default_handler($get_size_only, "$results", undef, 1);
}

sub refresh_dccstat {
    #debug("refreshing item");
    my $hide      = Irssi::settings_get_bool('dccstat_hide_sbar_when_inactive');
    my $count     = dcc_getcount();
    
    if ($hide && $count == 0) {
	if ($visible == -1 || $visible == 1) {
	    Irssi::command("statusbar dccstat disable");
	    debug("disabling statusbar");
	    $visible = 0;
	}
	return;
    }
    if ($visible == 0 || $visible == -1) {
	Irssi::command("statusbar dccstat enable");
	debug("enabling statusbar");
	$visible = 1;
    }
    Irssi::statusbar_items_redraw('dccstat');
    $rot_bar_n++;
    $rot_bar_n %= @rot_bar;
    
}

my $fref = 0;
sub dcc_fast_refresh {
    if (Irssi::settings_get_bool('dccstat_EXPERIMENTAL_fast_refresh')) 
    {
       refresh_dccstat();
       $fref++;
       debug("transfer updated! ($fref)");
    }
}

Irssi::settings_add_int($IRSSI{'name'}, "dccstat_refresh", $dccstat_refresh);
Irssi::settings_add_bool($IRSSI{'name'}, 'dccstat_short_mode', 0);
Irssi::settings_add_bool($IRSSI{'name'}, 'dccstat_hide_sbar_when_inactive', 0);
Irssi::settings_add_int($IRSSI{'name'}, 'dccstat_auto_short_limit', 2);
Irssi::settings_add_int($IRSSI{'name'}, 'dccstat_progbar_width', 10);
Irssi::settings_add_str($IRSSI{'name'}, 'dccstat_progbar_transferred', '%g=%n');
Irssi::settings_add_str($IRSSI{'name'}, 'dccstat_progbar_position', '%y>%n');
Irssi::settings_add_str($IRSSI{'name'}, 'dccstat_progbar_remaining', '%r-%n');
Irssi::settings_add_bool($IRSSI{'name'}, 'dccstat_cycle_through_transfers', 0);
Irssi::settings_add_int($IRSSI{'name'}, 'dccstat_cycle_through_transfers_refresh', 10);
Irssi::settings_add_bool($IRSSI{'name'}, 'dccstat_EXPERIMENTAL_fast_refresh', 0);
Irssi::settings_add_bool($IRSSI{'name'}, 'dccstat_debug', 0);
Irssi::settings_add_int($IRSSI{'name'}, 'dccstat_filename_max_length', 17);
Irssi::settings_add_int($IRSSI{'name'}, 'dccstat_filename_max_length_shortmode', 10);

Irssi::command_bind('dccstat', 'cmd_print_help');

Irssi::statusbar_item_register('dccstat', undef, 'dccstat');
Irssi::timeout_add('10000', 'dcc_calcSpeed', undef);
Irssi::signal_add('dcc connected', 'dcc_connected');
Irssi::signal_add( 
		  { 
		   'setup changed'       =>  \&dcc_setupcheck,
		   'dcc request'         =>  \&refresh_dccstat,
		   'dcc created'         =>  \&refresh_dccstat,
		   'dcc destroyed'       =>  \&refresh_dccstat,
		   'dcc transfer update' =>  \&dcc_fast_refresh,
		  } 
		 );

# Startup
startup_check();
refresh_dccstat();

# lets save some global variables
$old_refresh    = Irssi::settings_get_int('dccstat_refresh');

Irssi::print("Dccstat.pl loaded - /dccstat for help");

# EOF
