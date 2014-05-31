# nopl.pl
#
# Removes polish national diacritic characters from received msgs on irc, 
# replacing them with their corresponding letters. Can be used against 
# ISO-8859-2 and Windows-1250 character sets.
#
# Settings:
#
#    nopl_replace: How to notify you that letters have been changed. Default 
#                  is "<pl>text</pl>", where "text" is replaced with the 
#                  message.
#
# Thanks to James <james@jamesoff.net> for his nocaps.pl script on which 
# I have based my nopl (I don't know perl :)).

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;

$VERSION = '1.00';
%IRSSI = (
	authors		=> 'Adam Wysocki',
	contact		=> 'gophi <at> efnet.pl',
	name		=> 'nopl',
	description	=> 'Replaces polish national characters with their corresponding letters',
	license		=> 'Public Domain',
	url		=> 'http://www.gophi.rotfl.pl/',
	changed		=> '10 May 2005 16.12.32',
);


sub have_polish_chars {
	my ($msg) = @_;

	# only pl-letters
	$msg =~ s/[^\xF3\xEA\xB6\xB1\xBF\xB3\xE6\xBC\xCA\xF1\xA1\xD3\xA3\xA6\xAC\xAF\xD1\xC6\x9C\xB9\x9F\xA5\x8C\x8F]+//g;

	# if it has pl-letters, return 1 else return 0
	return 1 if length($msg);

	return 0;
}

# main event handler
sub pl_message {
	my ($server, $data, $nick, $address) = @_;
	my ($target, $msg) = split(/ :/, $data, 2);

	return if (!have_polish_chars($msg));

	# bleh, a line contains pl-chars
	$msg =~ tr/\xF3\xEA\xB6\xB1\xBF\xB3\xE6\xBC\xCA\xF1\xA1\xD3\xA3\xA6\xAC\xAF\xD1\xC6\x9C\xB9\x9F\xA5\x8C\x8F/oesazlczEnAOLSZZNCsazASZ/;

	my $replacement = Irssi::settings_get_str('pl_replace');
	$replacement =~ s/text/$msg/;

	# display it
	Irssi::signal_emit('event privmsg', ($server, "$target :$replacement", $nick, $address));

	# and stop
	Irssi::signal_stop();
}

Irssi::signal_add('event privmsg', 'pl_message');
Irssi::settings_add_str('misc', 'pl_replace', "<pl>text</pl>");
