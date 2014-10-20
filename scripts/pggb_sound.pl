## This is the IRSSI-version!
## OK, here we go.
## For bugs/suggestions/help contact me at duck@cs.uni-frankfurt.de
##
## This script does nothing usefull but is extremely usefull to me ;-).
## It should handle CTCP SOUNDs correctly - even if the waves are stored
## in subdirs and/or on SMB shares.
## It can also initiate CTCP SOUNDs, handle sound requests and request
## waves automatically.
##
## This is my first perl script. Please be kind to me ;-).
## I built it on top of someone else's work, but I don't know whom...

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "0.2.3.23b";
%IRSSI = (
	  authors	=> 'Adam Duck',
	  contact	=> 'duck@cs.uni-frankfurt.de',
	  name		=> 'PGGB_sound',
	  description	=> 'does CTCP SOUNDs and other similar things.',
	  license	=> 'GPLv2',
	  url		=> '',
	 );

Irssi::settings_add_bool('PGGB', 'SOUND_autosend',	1);
Irssi::settings_add_bool('PGGB', 'SOUND_autoget',	0);
Irssi::settings_add_bool('PGGB', 'SOUND_play',		1);
Irssi::settings_add_int( 'PGGB', 'SOUND_display',	5);
Irssi::settings_add_str( 'PGGB', 'SOUND_hilight',	'(none)');
Irssi::settings_add_str( 'PGGB', 'SOUND_DCC',		'(none)');
Irssi::settings_add_str( 'PGGB', 'SOUND_dir',		'~/.irssi/');
Irssi::settings_add_str( 'PGGB', 'SOUND_command',	'play');
my $autoget	= Irssi::settings_get_bool("SOUND_autoget");

# You can use <nothing>, ".gz" or ".bz2" as extension, the script will
# honour it accordingly. I chose ".gz" because it should be available
# on most systems ...
# Btw, this is NOT the time consuming part. It's `parse_dir'.
my $cachefile	= $ENV{HOME} . "/.irssi/wavdir.cache.gz";

########################################
# Changelog
# Sat 23 Mar 2002, 12:26:39	fixed stupid bug in sound_autosend
#
# ------------------------------------------------------------
# Don't edit below this line unless you are prepared to code!
# ------------------------------------------------------------

use File::Listing;
use File::Basename;

Irssi::command_bind("sound", "sound_command");
Irssi::signal_add_last("complete word", "sound_complete");
Irssi::signal_add("event privmsg", "sound_autosend");
Irssi::signal_add("ctcp msg", "CTCP_sound");
Irssi::signal_add('print text', 'hilight_sound');
Irssi::signal_add('dcc created', 'DCC_sound');
#IRC::add_message_handler("PRIVMSG", "sound_autoget");


Irssi::theme_register([
		       'ctcp', '{ctcp {hilight $0} $1}'
		      ]);

sub help {
  Irssi::print("USAGE: /sound setup|<somewav>(.wav)?");
  Irssi::print("\nsetup: creates the (vital) cache file.");
  Irssi::print("Please setup all variables through the /SET command (they all begin with \"SOUND_\").");
  Irssi::print("\nIf you have copied new waves to your sounddir, be sure to run \"/sound setup\" again!");
}

sub find_wave {
  unless ( -e "$cachefile" ) {
    Irssi::print("Cache file not found...");
    create_cache();}
  my $sound = shift(@_);
  unless ($sound =~ /^.*\.wav$/i) {$sound = $sound . ".*.wav"}
  my $LISTING;
  if ( -r $cachefile ) {
    if ($cachefile =~ /\.gz$/i)		{ open(LISTING, "-|", "zcat $cachefile") }
    elsif ($cachefile =~ /\.bz2$/i)	{ open(LISTING, "-|", "bzcat $cachefile") }
    else				{ open(LISTING, "-|", "cat $cachefile") };
  } else {
    Irssi::print("Cache file not readable. Nani?!?");
    return;}
  my @dir = parse_dir(\*LISTING, '+0001');
  close(LISTING);
  my $result = [];
  for (@dir) {
    my ($fName, $fType, $fSize, $fMtime, $fMode) = @$_;
    if (basename($fName) =~ /^$sound$/i) {
      #Irssi::print "$fName, $fType, $fSize, $fMtime, $fMode";
      push @$result, $fName;}}
  return @$result;
}

sub create_cache {
  my $sounddir	= Irssi::settings_get_str("SOUND_dir") . "/";
  # we need the "LC_CTYPE=en" here because dir_parse is unable
  # to parse things like "Mär 3" (German locale) ...
  Irssi::print("Creating $cachefile (this could take a while...)");
  my $command = "/exec LC_CTYPE=en ls -lR $sounddir";
  if ($cachefile =~ /\.gz$/i)		{ $command = $command . " | gzip" }
  elsif ($cachefile =~ /\.bz2$/i)	{ $command = $command . " | bzip2" }
  Irssi::command("$command > $cachefile");
}

sub onoff { shift(@_) ? return "ON" : return "OFF"; }

sub sound_command {
  my $sounddir	= Irssi::settings_get_str("SOUND_dir") . "/";
  my $soundcmd	= Irssi::settings_get_str("SOUND_command");

  my ($data, $server, $witem) = @_;
  $data =~ /([\w\.]+)(.*)/;
  my $sound	= $1;
  my $rest	= $2;
  $rest =~ s/ *//;
  unless ($rest eq "") { $rest = " " . $rest;};
  if ($sound =~ /^setup$/i)	{ create_cache(); return; }
  if (!($sound =~ /.*\.wav/i))	{ $sound = $sound . ".wav";}
  if ($witem && ($witem->{type} eq "CHANNEL" ||
		 $witem->{type} eq "QUERY")) {
    my $wavefile = (find_wave($sound))[0];
    if ( -r $wavefile ) {
      $witem->command("/CTCP $witem->{name} SOUND ".lc(basename($wavefile))."$rest");
      my $playcmd = system("$soundcmd $wavefile &");			# that's not so good ...
    } else {
      $witem->print("\"$sound\" not found in \"$sounddir\" or cache file too old."); }
  } else {
    Irssi::print "There's no point in running a \"CTCP SOUND\" command here."; }
  return 1;
}

sub sound_complete {
  my ($complist, $window, $word, $linestart, $want_space) = @_;
  if ($linestart =~ /^\/sound$/) {
    my $coli = [];
    for (find_wave($word)) { push(@$coli, basename($_)); }
    my $max = Irssi::settings_get_int('SOUND_display');
    if (@$coli > $max) {
      $window->print("@$coli[0..($max-1)] ...");
    } else {
      push @$complist, @$coli; }}}

sub sound_autosend {
  if (!Irssi::settings_get_bool("SOUND_autosend")) { return 0; }
  my ($server, $data, $nick, $address) = @_;
  my $myname = $server->{nick};

  $data =~ /(.*) :!$myname +(.*\.wav)/i;
  if ($2 eq "") { return 0; }
  my $channel	= $1;
  my $wavefile	= (find_wave($2))[0];
  if ($wavefile ne "") {
    Irssi::print("DCC sending $wavefile to $nick");
    $server->command("/DCC SEND $nick $wavefile");
  } else {
    $server->send_message($nick, "Sorry, $nick. $2 not found.", 1);
  }
  return 1;
}

sub hilight_sound {
  my ($dest, $text, $stripped) = @_;
  my $server = $dest->{server};
  unless ($server->{usermode_away}) {
    my $hiwave = Irssi::settings_get_str('SOUND_hilight');
    if (($hiwave ne '(none)') &&
	($dest->{level} & (MSGLEVEL_HILIGHT|MSGLEVEL_MSGS)) &&
	($dest->{level} & MSGLEVEL_NOHILIGHT) == 0) {
      play_wave(find_wave($hiwave));}}}

sub DCC_sound {
  my $dcc = shift(@_);
  my $server = $dcc->{server};
  Irssi::print("$dcc->{type}");
  unless ($server->{usermode_away} || ($dcc->{type} eq "SEND")) {
    my $hiwave = Irssi::settings_get_str('SOUND_DCC');
    if ($hiwave ne '(none)') {
      play_wave(find_wave($hiwave));}}}

sub play_wave {
  my $wave = shift(@_);
  my $sndcmd = Irssi::settings_get_str("SOUND_command");
  if (-r "$wave") {
    system("$sndcmd \"$wave\" &");}}

sub sound_autoget {
  if (!$autoget) { return 0; }
  my $sounddir	= Irssi::settings_get_str("SOUND_dir") . "/";

  my $line = shift (@_);
  #:nick!host PRIVMSG channel :message
  $line =~ /:(.*)!(\S+) PRIVMSG (.*) :(.*)/i;

  my $name = $1;
  my $channel = $3;
  my $text = $4;
  my $name = "$name";
  my @wordlist = split(' ',$4);

  if ($wordlist[0] eq "\001SOUND") {
    my $tempsound = $wordlist[1];
    $tempsound =~ s/[\r \001 \n]//;
    IRC::print($tempsound);
    if (!open(TEMPFILE, "<", $sounddir.$tempsound)) {
      IRC::send_raw("PRIVMSG $name :!$name $tempsound\r\n");
    } else {
      close(TEMPFILE);
    }
  }
  return 0;
}

sub CTCP_sound {
  my $play	= Irssi::settings_get_bool("SOUND_play");
  my $soundcmd	= Irssi::settings_get_str("SOUND_command");

  my ($server, $args, $nick, $addr, $target) = @_;
  $args =~ /^SOUND (.*\.wav)(.*)$/i;
  if ($1 eq "") { return 0; }

  my $sound	= $1;
  my $wavfile	= (find_wave($1))[0];
  my $output	= "";
  my $rest = $2;
  $rest =~ s/^ *//;
  if ( $rest ne "" ) {					# this one is for P&P & co.
    $output = $output . $rest
  } else {
    $output = $output . " plays $sound";
  }
  if ($wavfile eq "") {
    $output = $output . " (not found)";
    if ($autoget) {
      Irssi::send_raw("PRIVMSG $nick :!$nick $sound\r\n");
    }
  } else {
    if ($play) {
      system("$soundcmd \"$wavfile\" &");
    } else {
      $output = $output . " (muted)";
    }
  }
  my $wItem = $server->window_find_item($target);
  $wItem->printformat(MSGLEVEL_CTCPS, 'ctcp', $nick, $output);
  Irssi::signal_stop();
}
