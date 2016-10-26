#!/usr/bin/perl


# You can freely redistribute this script, but don't change the IRSSI string
# ------------------------------------------------------------------------------
# now playing script for irssi and Orpheus mp3 player (recommended 1.4 or higher)
# lsof needed critically! (with correct permissions)
# mp3info needed, not cricital, but recommended (http://ibiblio.org/mp3info/)
# script painfully made by Wohmatak :)
# ------------------------------------------------------------------------------

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);  

$VERSION = '0.9';

%IRSSI = (
        authors         => 'Wohmatak',
        contact         => 'wohmatak@iglu.cz',
        name            => 'orphamp',
        description     => 'Displays the song played by orpheus',
        license         => 'GPL',
        url             => 'http://irssi.org/',
        changed         => 'Wed',
        commands        => '/np',
	
); 

Irssi::settings_add_str("misc", "np_lang", "en");
Irssi::settings_add_int("misc", "show_npinfo", 1); 

my $message;

sub info {
### onload message
print "--- Wohmatak's Orpheus now playing script loaded! ---\nTo show now playing song, use /np command";
print "You need lsof and mp3info in order to use orphamp script.";
### feedback
print "Feedback appreciated at wohmatak <at> iglu.cz, ICQ 70713105 or on IRCnet...";
### should I show info?
print "-----------------------------------------------------";
print "If you don't want to see this welcome message anymore, check show_npinfo irssi setting";
print "If you want now playing sentence in czech, check np_land irssi setting (currently en/cz supported)";
print "-----------------------------------------------------";
}

sub void {

### check, whether lsof works
if (!`lsof -Fc -b -S 2`) { die "lsof command hasn't been found on your computer! Please check whether it is installed & has correct permissions... Orphamp deactivated";}
### lsof command
my $raw = `lsof -S 2 -n -P -b | grep mpg123 | grep -i mp3 | grep REG | tail -n 1`;
### split after /
my @split = split(/\//,$raw);
### count the number of splits
my $pocet = $#split;
### filename into one variable & newline department
my $filename = "";
for (my $i=1; $i<=$pocet; ++$i) {
$filename .= "/";
$filename .= $split[$i];
}
chomp($filename);

### check, whether mp3info is installed
if (`mp3info` && $filename) {

    ## mp3info command, std_err to /dev/null 
    ## (we don't want those ugly error messages in irssi window, do we?:)
    my $artist = `mp3info -p %a "$filename" 2> /dev/null`;
    my $song = `mp3info -p %t "$filename" 2> /dev/null`;
    my $album = `mp3info -p %l "$filename" 2> /dev/null`;
    if (!$album) { $album = "unknown album";}
    my $year = `mp3info -p %y "$filename" 2> /dev/null`;
    if (!$year) { $year = "unknown year";}


    ## if there's no artist and song, display info from orpheus infopipe file (orpheus 1.4 needed)
    if (!$artist && !$song) 
    {
	    my $nazev = `cat ~/.orpheus/currently_playing`;
	    $message = "prehrava ".$nazev.""; 
    }
    
    else 
    {
	if (Irssi::settings_get_str("np_lang")  eq"en") 
	{
		     $message = "listens to ".$song." by ".$artist." ([".$year."] ".$album.")";
	}
	elsif (Irssi::settings_get_str("np_lang")  eq "cz") 
	{
		$message = "posloucha ".$song." od ".$artist." ([".$year."] ".$album.")";
	}
    }


}


### mp3info is not present (or we're playing a CD track)
else {
    if ($filename) 
    {
		 print "mp3info is not installed! please get it if you want to use orphamp script (http://ibiblio.org/mp3info/)"; 
    }

    my $nazev = `cat ~/.orpheus/currently_playing`;
    	if (Irssi::settings_get_str("np_lang") eq "en") 
	{
		     $message = "listens to ".$nazev.""; 
	}
	elsif (Irssi::settings_get_str("np_lang")  eq "cz") 
	{
		$message = "posloucha ".$nazev.""; 
	}
}

### echo the message to channel
my ($data, $server, $witem) = @_;
if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY"))
    { $witem->command("/me $message"); } 
    else { print "* ".$message;}
}

if (Irssi::settings_get_int("show_npinfo")) {
		info();
		}

Irssi::command_bind('np','void');
Irssi::command_bind('npinfo','info');
