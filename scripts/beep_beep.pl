#!/usr/bin/irssi
#
# irssi beep replace script (tested with irssi v0.8.8.CVS (20030126-1726))
# (C) 2002-2004 Ge0rG@IRCnet (Georg Lukas <georg@op-co.de>)
# inspired and tested by Macrotron@IRCnet (macrotron@president.eu.org)

# added beep_flood to irssi settings: beep_cmd will be run not more often
# then every $beep_flood milliseconds

# fixed memory leak with timeout_add (made irssi waste 80mb and more after a day of IRC)
# added > /dev/null, thx to Luis Oliveira
# fixed timeout handling bug, thx to frizop@charter.net

$VERSION = "0.10";
%IRSSI = (
    authors	=> "Georg Lukas",
    contact	=> "georg\@op-co.de",
    name	=> "beep_beep",
    description	=> "runs arbitrary command instead of system beep, includes flood protection",
    license	=> "Public Domain",
    url		=> "http://op-co.de/irssi/",
);

use Irssi;

my $might_beep = 1, $to_tag;

sub beep_overflow_timeout() {
	$might_beep = 1;
	Irssi::timeout_remove($to_tag);
}

sub beep_beep() {
	my $beep_cmd = Irssi::settings_get_str("beep_cmd");
	if ($beep_cmd) {
		if ($might_beep) {
			my $beep_flood = Irssi::settings_get_int('beep_flood');
			$beep_flood = 1000 if $beep_flood < 0;
			Irssi::timeout_remove($to_tag);
			$to_tag = Irssi::timeout_add($beep_flood, 'beep_overflow_timeout', undef);
			system($beep_cmd);
			$might_beep = 0;
		}
		Irssi::signal_stop();
	}
}

Irssi::settings_add_str("lookandfeel", "beep_cmd", "play ~/.irssi/scripts/beep_beep.wav > /dev/null &");
Irssi::settings_add_int("lookandfeel", "beep_flood", 250);
Irssi::signal_add("beep", "beep_beep");

