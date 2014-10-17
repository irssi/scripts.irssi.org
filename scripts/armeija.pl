#!/usr/bin/perl -w
# script to ignore boring messages in irc
# it has a list of keywords which on a public message will cause someone
# to be ignored for 60 seconds (changeable). also it ignores (tries to)
# every message back to ignored people.
#  - flux@inside.org

# check out my other irssi-stuff at http://xulfad.inside.org/~flux/software/irssi/

use strict;
use Irssi;

use vars qw($VERSION %IRSSI);
$VERSION = "0.4";
%IRSSI = (
    authors     => "Erkki Seppälä",
    contact     => "flux\@inside.org",
    name        => "Armeija Ignore",
    description => "Ignores people bringin up boring/repeated subjects, plus replies.",
    license     => "Public Domain",
    url         => "http://xulfad.inside.org/~flux/software/irssi/",
    changed     => "Tue Mar  5 00:06:35 EET 2002"
);


use Irssi::Irc;

my $log = 0;
my $logFile = "$ENV{HOME}/.irssi/armeija.log";

my $retrigger = 0;
my $wordFile = "$ENV{HOME}/.irssi/armeija.words";
my $channelFile = "$ENV{HOME}/.irssi/armeija.channels";
my $overflowLimit = 3;

my @channels = ("#linux.fi");

my @keywords = (

# armeija
  "\\barmeija", "\\brynkky", "\\bintti", "\\bintissä", "\\bgines", "\\btj\\b"
, "\\bsaapumiserä", "\\bvarus(mies|nainen|täti)", "\\bvemppa", "\\bvempula"
, "\\bvempa", "\\bveksi", "\\bsulkeiset", "\\bsulkeisi"
, "\\bvlv\\b", "\\bhl\\b"

# offtopic
, "\\bsalkkari", "\\bsalatut eläm". "\\bsalattuja eläm"

# urheilu
,"\\bhiiht", "\\bhiihd", "\\bformula", "\\bolympia"

);

my %infected;
my $timeout = 60;

my $who = "";
my $why = "";

sub p0 {
  my $a = $_[0];
  while (length($a) < 2) {
    $a = "0$a";
  }
  return $a;
}

sub why {
  if ($who ne "") {
    Irssi::print "$who was ignored: $why";
  }
}

sub public {
  my ($server, $msg, $nick, $address, $target) = @_;

  local *F;

  my $now = time;

  my $skip = 1;
  foreach my $channel (@channels) {
    if (lc($target) eq lc($channel)) {
      $skip = 0;
      last;
    }
  }

  if ($skip) {
    return 0;
  }

  # check for keywords

  my $count = 0;
  foreach my $word (@keywords) {
    if ($msg =~ /$word/i) {
      ++$count;
    }
  }

  if (($count >= 1) && ($count < $overflowLimit)) {
    Irssi::print "Ignoring $nick";
    $why = $msg;
    $who = $nick;
    if ($log) {
      open(F, q{>>}, $logFile);
      my @t = localtime($now);
      $t[5] += 1900;
      print F "$t[5]-", p0($t[4] + 1), "-", p0($t[3]), " ",
	p0($t[2]), ":", p0($t[1]), ":", p0($t[0]), " $who/$target: $why\n";
      close(F);
    }
    if ($retrigger || !exists $infected{$nick}) {
      $infected{$nick} = $now + $timeout;
    }
    Irssi::signal_stop();
    return 1;
  }

  # check and expire old ignores 
  if (exists $infected{$nick}) {
    if ($infected{$nick} < $now) {
      Irssi::print "Timed out: $nick";
      delete $infected{$nick};
    } else {
      Irssi::signal_stop();
      return 1;
    }
  }

  # check for messages targetted to ignored people
  foreach my $nick (keys %infected) {
    if ($msg =~ /^$nick/i) {
      # ignore messages to these people
      Irssi::signal_stop();
      return 1;
    }
  }

  return 0;
}

sub logging {
  my (@args) = @_;
  if (@args) {
    if ($args[0] eq "on") {
      $log = 1;
      Irssi::print("Armeija-logging on to file $logFile");
    } elsif ($args[0] eq "off") {
      $log = 0;
      Irssi::print("Armeija-logging stopped");
    } else {
      $logFile = $args[0];
      Irssi::print("Armeija-logfile set to $logFile");
    }
  } else {
    Irssi::print("usage: armeija log [on|off|new log file name]"); 
    Irssi::print("Log is " . ($log ? "on" : "off") . ", logfile is $logFile");
  }
}

sub load {
  local $/ = "\n";
  local *F;
  if (open(F, q{<}, $wordFile)) {
    @keywords = ();
    while (<F>) {
      chomp;
      push @keywords, $_;
    }
    close(F);
  } else {
    Irssi::print("Failed to open wordfile $wordFile\n");
  }
  if (open(F, q{<}, $channelFile)) {
    @channels = ();
    while (<F>) {
      chomp;
      push @channels, $_;
    }
    close(F);
  }
}

sub save {
  local *F;
  if (open(F, q{>}, $wordFile)) {
    for (my $c = 0; $c < @keywords; ++$c) {
      print F $keywords[$c], "\n";
    }
    close(F);
  }
  if (open(F, q{>}, $channelFile)) {
    for (my $c = 0; $c < @channels; ++$c) {
      print F $channels[$c], "\n";
    }
    close(F);
  }
}

sub retrigger {
  if (@_ == 1) {
    if ($_[0] eq "on") {
      Irssi::print "Armeija retrigger on";
      $retrigger = 1;
    } elsif ($_[0] eq "off") { 
      Irssi::print "Armeija retrigger off";
      $retrigger = 0;
    } else {
      Irssi::print("Invalid armeija trigger state");
    }
  } else {
    Irssi::print("usage: /armeija retrigger [on|off]");
  }
}

sub armeija {
  my (@args) = split(" ", $_[0]);
  if (@args) {
    if ($args[0] eq "why") {
      why();
    } elsif ($args[0] eq "log") {
      my @a = @args;
      shift @a;
      logging(@a);
    } elsif ($args[0] eq "load") {
      load();
    } elsif ($args[0] eq "save") { 
      save();
    } elsif ($args[0] eq "+word") {
      my @a = @args;
      shift @a;
      push @keywords, join(" ", @a);
      save();
    } elsif ($args[0] eq "-word") {
      my @a = @args;
      shift @a;
      for (my $c = 0; $c < @keywords; ++$c) {
        for (my $d = 0; $d < @a;) {
          if ($a[$d] eq $keywords[$c]) {
            splice @keywords, $c, 1;
          } else { 
            ++$d;
          }
        }
      }
      save();
    } elsif ($args[0] eq "words") {
      Irssi::print(join(", ", @keywords));
    } elsif ($args[0] eq "retrigger") {
      my @a = @args;
      shift @a;
      retrigger(@a);
    } else {
      Irssi::print("Invalid armeija command");
    }
  } else {
    Irssi::print("Armeija usage: armeija [log [off|on|filename]|load|save|+word word|-word word|words]");
  }
}

Irssi::signal_add("message public", "public");
Irssi::command_bind("armeija", "armeija");

Irssi::print "Armeija-ignore v$VERSION by $IRSSI{contact}";
load();
