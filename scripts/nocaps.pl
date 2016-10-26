# nocaps.pl
#
# Stops people SHOUTING ON IRC
#
# Settings:
#    caps_replace: How to notify you something was changed. Default is 
#                  "<caps>text</caps>". 'text' is replaced with what they said.
#    caps_sensitivity: If the line is this shorter than this, all caps is
#                      allowed. Default = 6
#    caps_percent: If the line has more than this percent caps in it, it's
#                  transformed to lowercase. Default = 80.
#
# Thanks to Johan "Ion" Kiviniemi from #irssi for some of the stuff
#
# Example output (all these lines were all caps originally):
#  [@NoTopic] Boomskdfhh£$(&* [caps]
#  [@NoTopic] Boomfdkjh. Kdfhkdf. Kddkh. [caps]
#  [@NoTopic] Jamesoff: Boom*£&$&*£hdfjkhjfksdfljdksjgfkj*&^£* [caps]
#

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;

$VERSION = '1.01';
%IRSSI = (
    authors	=> 'JamesOff, Ion',
    contact	=> 'james@jamesoff.net',
    name	=> 'nocaps',
    description	=> 'Replaces lines in ALL CAPS with something easier on the eyes',
    license	=> 'Public Domain',
    url		=> 'http://www.jamesoff.net',
    changed	=> '22 March 2002 12:34:38',
);


sub isAllCaps {
	my ($msg) = @_;
	#strip out everything that's not letters
	$msg =~ s/[^A-Za-z]+//g;

	#msgs with no letters in are a waste of time
	return 0 if (!length($msg));
	my $capsonly = $msg;
	
	#only caps
	$capsonly =~ s/[^A-Z]+//g;

	#if it's all caps and less than caps_sensitivity, return 0
	my $minimum = Irssi::settings_get_str('caps_sensitivity');
	return 0 if ((length($capsonly) < $minimum));
	
	#check percentage
	my $percentage = Irssi::settings_get_str('caps_percent');
	if (((length($capsonly) / length($msg)) * 100) > $percentage) {
		#too many caps!
		return 1;
	}

	return 0;
}

#main event handler
sub caps_message {
	my ($server, $data, $nick, $address) = @_;
	my ($target, $msg) = split(/ :/, $data,2);

	if (isAllCaps($msg)) {
		#bleh, a line in ALL CAPS£*$&(*(£$&
		$msg =~ tr/A-Z/a-z/;

		# foo bar biz. blah quux. -> Foo bar biz. Blah quux.
		$msg =~ s/(^\s*|[.!?]\s+)(\w)/$1 . uc $2/eg;

		# Nick: hello -> Nick: Hello.
		$msg =~ s/^(\S+:\s*)(\w)/$1 . uc $2/e;

		#:<d|p|o> --> capital letter (for |Saruman| )
		$msg =~ s/([=:;][dpo])/uc $1/eg;

		my $replacement = Irssi::settings_get_str('caps_replace');
		$replacement =~ s/text/$msg/;

		#re-emit the signal to make Irssi display it
		Irssi::signal_emit('event privmsg', ($server, "$target :$replacement", $nick, $address));
		#and stop
		Irssi::signal_stop();
	}
}

Irssi::signal_add('event privmsg', 'caps_message');

Irssi::settings_add_str('misc', 'caps_replace', "<caps>text</caps>");
Irssi::settings_add_str('misc', 'caps_sensitivity', "6");
Irssi::settings_add_str('misc', 'caps_percent', "80");
