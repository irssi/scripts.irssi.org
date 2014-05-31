# Irssi weather as statusbar item and forecast command

# Fixes in this version
#
# 1. Fixed issue with N/A&deg;F in the windchill/feelslike variable.
# 2. Added more information in the /forecast command.
# 3. Added an extended function for three day forecasts.
# 4. Moved the extended function info /forecast -e (yippie! FLAGS!)
# 5. Added a /forecast -o option to print the info to the active window
# 6. 2.0 has a TOTAL rewrite on how to get the data. We no longer use weather.com its now Geo::Weather data
# 7. Removed the three day extended forecast for the 2.0 version, will rewrite it later.
# 8. 2.1 now has 10 day extended forecast, takes slightly longer to load
# 9. 2.2 has returned to writing statusbar info to a file to save time in window switching
# 10. 2.3 allows theme customization of weather in statusbar (written for ardya)


# Use the following format in your theme file 
# weather_display = "$0%R>%n%_$2%_%G>%n$4";
#
# $0 is temperature
# $2 is feelslike (windchill/headindex)
# $4 is current conditions (windy or partly cloudy)

# - You have to modify this line to the path of your LWP-dir
use lib '/usr/lib/perl5/vendor_perl/5.6.1';
use Irssi;
use Irssi::TextUI;
use Geo::Weather;
use 5.6.0;

use vars qw($VERSION %IRSSI $zipcode $refresh $show_type $last_refresh $refresh_tag);

$VERSION = '2.3';
%IRSSI = (
    authors     => 'GrayWolf',
    contact     => 'graywolf@i-differ.net',
    name        => 'Weather.pl',
    description => 'Put local weather information in your statusbar as well as add a forecast command',
    license     => 'Public Domain'
);

#
## Variable defaults, can be changed with /set in Irssi, to save trouble I recommend setting your zipcode here
#
if (!$zipcode) {
  $zipcode = "46260";
}
$zip = $zipcode;
$country = "us";
$refresh = "900";
$show_type = "yes";
$in_celsius = "no";

#
## Bind our commands
#
Irssi::command_bind("weather", "show_usage");
Irssi::command_bind("forecast", "show_weather");
Irssi::command_bind("weathsecret", "get_weather_for_status");

#
## Usage information
#
sub show_usage {
    Irssi::print("[Usage] Forecast Statusbar script v$VERSION");
    Irssi::print("/weather : shows usage info");
    Irssi::print("/forecast <zipcode> : Show current forecast for <zipcode>");
    Irssi::print("/forecast -o <zipcode> : Show current forecast for <zipcode> in the active window \(print to channel\)");
    Irssi::print("/forecast -e <zipcode> : Show extended ten day forecast for <zipcode>");
    Irssi::print("/set weather_refresh : Sets how often the statusbar is updated");
    Irssi::print("/set weather_zip : The zipcode of the area you want displayed in the statusbar");
    Irssi::print("/set weather_show_type (yes/no) : Choose if you want to see F/C in the statusbar");
    Irssi::print("/set weather_in_celsius (yes/no) : Choose if you want to see the temperature in celsius");
    Irssi::print("/statusbar <bar> add weather : see /help statusbar for more information.");
}

#
## First thing run the status grab
#
get_weather_for_status();

#
## Get down to work
#
sub weather_us {
my $winfo = new Geo::Weather;
$winfo->{timeout} = 5; # set timeout to 5 seconds instead of the default of 10

# Get the $zip from a /forecast command
$zip = $_[0];

# Currently only the US is supported, hope to add more countries later
  if ( $country == "us" ) {
    # Lets go get the information
    my $current = $winfo->get_weather($zip);
    my $forecast = $winfo->report_forecast();

    $temperature = $current->{temp};
    $feelslike = $current->{heat};
    $description = $current->{cond};
    $wind = $current->{wind};
    $wind =~ s/\<br\>/\n/g;
    $wind =~ s/\<.+?\>//sg;
    $wind =~ s/&nbsp;//g;
    $dewp = $current->{dewp};
    $humi = $current->{humi};
    $visb = $current->{visb};
    $visb =~ s/\<br\>/\n/g;
    $visb =~ s/\<.+?\>//sg;
    $baro = $current->{baro};
    $baro =~ s/\<br\>/\n/g;
    $baro =~ s/\<.+?\>//sg;
    return($temperature,$feelslike,$description,$wind,$dewp,$humi,$visb,$baro,$forecast);
  } else {
    Irssi::print("Unable to get weather for $country");
    return(0,0,0);
  }
}

# Statusbar formatting
sub get_weather_for_status {

  ($temperature,$feelslike,$description,$therest) = weather_us($zipcode);

  # If the user doesn't want to see F in the statusbar lets strip that out
  if ( $show_type eq 'yes' ) {
    $temperature .= 'F';
    $feelslike .=  'F';
  }
  # If the user wants his temp in celsius lets convert it here
  if ($in_celsius eq 'yes') {
     $convert = $temperature;
     $convert =~ s/F//g;
     $temperature = ((5 / 9) * ($convert - 32));
     $temperature = sprintf('%d', $temperature);
     $feelcon = $feelslike;
     $feelcon =~ s/F//g;
     $feelslike = ((5 / 9) * ($feelcon - 32));
     $feelslike = sprintf('%d', $feelslike);
     # Now we have the temp in celsius, do they want to see the C?
     if ($show_type eq 'yes') {
       $temperature .= 'C';
       $feelslike .= 'C';
     }
  }
  chomp($temperature);
  chomp($feelslike);
  chomp($description);
  open STATUS_FILE, ">.irssi/weather.status" or die "Can't write to status file: $!";
  print STATUS_FILE "$temperature,$feelslike,$description";
  close STATUS_FILE;
}

# Status bar information

sub theme_format {
  open GET_STATUS, "<.irssi/weather.status" or die "Can't open status file: $!";

  my $themed = "";
  my $themecmd = "";

  while ($line = <GET_STATUS>) {
    ($temperature,$feelslike,$description) = split(/,/, $line);
  }
  chomp($description);
  $description =~ s/ /\_\_/g;
  $themed = Irssi::current_theme->format_expand("{weather_display $temperature  $feelslike  $description}",Irssi::EXPAND_FLAG_IGNORE_REPLACES);

  $statusbar_output = $themed;
  return $statusbar_output;
  Irssi::statusbar_items_redraw('weather');
  close GET_STATUS;
}

sub weather {
  my ($item, $get_size_only) = @_;

  $sbar_out = theme_format();
  $sbar_out =~ s/  /\//g;
  $sbar_out =~ s/\_\_/ /g;
  chomp($sbar_out);
  $item->default_handler($get_size_only, "{sb $sbar_out}", undef, 1 );
}

sub show_weather {
  my ($commands, $item, $witem) = @_;
  ($flag, $thezip) = split(/ /, $commands);
  if ($flag =~ /^\s*$/) {
    $thezip = $zipcode if $thezip < 1;
    ($temperature,$feelslike,$description,$wind,$dewp,$humi,$visb,$baro) = weather_us($thezip);
    Irssi::active_win()->print("Information for $thezip - Temp: $temperature, Feels Like: $feelslike, Currently: $description, Dew Point: $dewp, Humidity: $humi, Visibility: $visb, Pressure: $baro, Wind: $wind");
  } elsif ($flag =~ /^\d*$/) {
    $flag = $zipcode if $flag < 1;
    ($temperature,$feelslike,$description,$wind,$dewp,$humi,$visb,$baro) = weather_us($flag);
    Irssi::active_win()->print("Information for $flag - Temp: $temperature, Feels Like: $feelslike, Currently: $description, Dew Point: $dewp, Humidity: $humi, Visibility: $visb, Pressure: $baro, Wind: $wind");
    $flag = $zipcode;
    weather_us($flag);
  } elsif ($flag =~ /\-o/) {
    if ($witem) {
      $thezip = $zipcode if $thezip < 1;
      ($temperature,$feelslike,$description,$wind,$dewp,$humi,$visb,$baro) = weather_us($thezip);
      $witem->command("MSG ".$witem->{name}." Information for $thezip - Temp: $temperature, Feels Like: $feelslike, Currently: $description, Dew Point: $dewp, Humidity: $humi, Visibility: $visb, Pressure: $baro, Wind: $wind");
      $thezip = $zipcode;
      weather_us($thezip);
    }
  } elsif ($flag =~ /\-e/) {
    if ($witem) {
      $thezip = $zipcode if $thezip < 1;
      ($temperature,$feelslike,$description,$wind,$dewp,$humi,$visb,$baro,$forecast) = weather_us($thezip);
      my $count = 0;
      my $active = 0;
      my $day = 0;
      my @days = ();

      $forecast =~ s/\<.+?\>//sg;
      $forecast =~ s/&nbsp;//g;
      $forecast =~ s/&deg;/F/g;
      $forecast =~ s/FF/F/g;
      $forecast =~ s/^\s+//gm;

      @fore = split(/\n/, $forecast);
      $endres = undef;

      foreach $line (@fore) {
        if ($count > 3) {
          if ($active <= 4) {
            if ($active eq 0) {
              # This is necessary to prevent wrapping into the next call of /forecast -e
              $endres .= "\n";
            }
            chomp($line);
            $line =~ s/ \/ /\//g;
            $line =~ s/ \%/\% chance of precipitation/g;
            $endres .= "$line ";
            $active ++;
          } else {
            $active = 1;
            $day ++;
            if ($day < 11) {
              chomp($line);
              $line =~ s/ \/ /\//g;
              $line =~ s/ \%/\% chance of precipitation/g;
              $endres .= "\n$line";
            }
          }
        }
        $count ++;
      }
      
      @days = split(/\n/, $endres);
      Irssi::active_win()->print("Extended Ten Day Forecast for $thezip");
      Irssi::active_win()->print("$days[1]");
      Irssi::active_win()->print("$days[2]");
      Irssi::active_win()->print("$days[3]");
      Irssi::active_win()->print("$days[4]");
      Irssi::active_win()->print("$days[5]");
      Irssi::active_win()->print("$days[6]");
      Irssi::active_win()->print("$days[7]");
      Irssi::active_win()->print("$days[8]");
      Irssi::active_win()->print("$days[9]");
      Irssi::active_win()->print("$days[10]");
    }
  } else {
     Irssi::active_win()->print("Cannot print to the active window");
  }
}


sub refresh_weather {
    Irssi::statusbar_items_redraw('weather');
}

sub read_settings {
  $zipcode = Irssi::settings_get_str('weather_zip');
  $show_type = Irssi::settings_get_str('weather_show_type');
  $in_celsius = Irssi::settings_get_str('weather_in_celsius');
  $refresh = Irssi::settings_get_int('weather_refresh');
  $refresh = 1 if $refresh < 1;
  return if $refresh == $last_refresh;
  $last_refresh = $refresh;
  Irssi::timeout_remove($refresh_tag) if $refresh_tag;
  $refresh_tag = Irssi::timeout_add($refresh * 1000, 'get_weather_for_status', undef);
  $refresh_tag = Irssi::timeout_add($refresh * 1000, 'refresh_weather', undef);
}

Irssi::settings_add_int('misc', 'weather_refresh', $refresh);
Irssi::settings_add_str('misc', 'weather_zip', $zipcode);
Irssi::settings_add_str('misc', 'weather_show_type', $show_type);
Irssi::settings_add_str('misc', 'weather_in_celsius', $in_celsius);

Irssi::statusbar_item_register('weather', undef, 'weather');
Irssi::statusbars_recreate_items();

read_settings();
Irssi::signal_add('setup changed', 'read_settings');

#
## TODO
#
# 1. Add other countries -- (not sure if this will ever happen, feel free....)
# 2. Fix the read_settings so that changes are immediate -- (just update your zipcode at the top of the script and don't bug me)
# 3. Allow the extended function to show temps in C (currently only F) -- (I don't want to)
# 4. I want to add some type of error check for the zipcodes, so that you can't enter an invalid one
# 5. Make the lookup background or async so it doesn't tie up the irssi session -- (all I can find is fork() which requires a major rewrite.
#    Wait the 10 damn seconds you lazy gits.)
