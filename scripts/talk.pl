# -*- CPerl -*-
#       $Id$
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
$VERSION = '1.02';
%IRSSI = (
    authors     => 'Alexander Mieland',
    contact     => 'dma147\@mieland-programming.de',
    name        => 'Talk',
    description => 'This script talks to you *g*. It reads the chat-msgs for you.',
    license     => 'GPL2',
);

##########################################################################
#	view settings with /set Talk
#
#	your preferred language
my $language = "en";	# (en|de)
#
#	should I say all of the joins, parts and quits?
my $sayjpq = 0;		# (1|0)
#
#	should I say all of the nickchanges?
my $saynickchg = 0;	# (1|0)
#
##########################################################################


Irssi::theme_register(
[
 'talk_loaded', 
 '{line_start}{hilight Talk:} $0',
]);

Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'talk_loaded', "Version $VERSION loaded. Type /talk_help, if you have any questions or problems.");

sub cmd_talk_help
	{
	my $help = "
[talk.pl]

This script is a text2speech engine for your irssi. It reads the msgs from 
your irssi client and speaks them through your soundcard.

It is highly recommended, that you\'ve set up your txt2speech in linux with 
a tutorial, which provides a little bash-script, called \'say\', which must 
be able to be useed in a pipe.

Because this irssi-script makes use of the bash-script /usr/(local/)bin/say 
and it uses it in a pipe. 
Otherwise this irssi-script will *not* work.

For german people, I would prefer:
http://www.linux-magazin.de/Artikel/ausgabe/2000/05/Sprachsynthese/sprachsynthese.html

==========================================================================

Commands:

/talk [message]   :  Speaks the given message through your soundcard
/talk_about      :  Licence and Information about this script
/talk_help       :  This helptext
";
	Irssi::print($help, MSGLEVEL_CLIENTCRAP);
	}

sub cmd_talk_about
	{
	my $about = "
[talk.pl]

This script is a text2speech engine for your irssi. It reads the msgs from 
your irssi client and speaks them through your soundcard.

For information how to use, type /talk_help

This script is written and copyrighted 2004 by Alexander Mieland
Contact: dma147 in #gentoo.de @ irc.freenode.net
This script is licenced under the terms of GNU - General Public Licence 
Version 2.
";
	Irssi::print($about, MSGLEVEL_CLIENTCRAP);
	}

sub RepCrap
	{
	my $string = lc(shift) || return;
	$string =~ s/['#\`]//g;
	$string =~ s/ä/ae/g;
	$string =~ s/ö/oe/g;
	$string =~ s/ü/ue/g;
	$string =~ s/ß/ss/g;
	if ($language eq "de")
		{
		$string =~ s/([ ]+[0-9]*)mbit/\1megabit/g;
		$string =~ s/([ ]+[0-9,\.]*)[ ]*kbit/\1kilobit/g;
		$string =~ s/([ ]+[0-9,\.]*)[ ]*bit/\1bit/g;
		$string =~ s/([ ]+[0-9,\.]*)[ ]*mbyte/\1megabeit/g;
		$string =~ s/([ ]+[0-9,\.]*)[ ]*kbyte/\1megabeit/g;
		$string =~ s/([ ]+[0-9,\.]*)[ ]*byte/\1beit/g;
		$string =~ s/([ ]+[0-9,\.]*)[ ]*mb/\1megabeit/g;
		$string =~ s/([ ]+[0-9,\.]*)[ ]*kb/\1kilobeit/g;
		$string =~ s/\"/anfuehrungszeichen/g;
		$string =~ s/_/unterstrich/g;
		$string =~ s/;\)/zwinkernder smeili/g;
		$string =~ s/;-\)/zwinkernder smeili/g;
		$string =~ s/:\)/smeili/g;
		$string =~ s/:-\)/smeili/g;
		$string =~ s/:\(/trauriger smeili/g;
		$string =~ s/:-\(/trauriger smeili/g;
		$string =~ s/\*g\*/grins/g;
		$string =~ s/\*gg\*/grins grins/g;
		$string =~ s/\*fg\*/freches grinsen/g;
		$string =~ s/\*ffg\*/sehr freches grinsen/g;
		$string =~ s/afaik/so weit ich weiss/g;
		$string =~ s/imho/meiner meinung nach/g;
		$string =~ s/([^ ]+)\.([^ ]+)/\1punkt\2/g;
		}
	else
		{
		$string =~ s/([ ]+[0-9,\.]*)[ ]*mbit/\1megabit/g;
		$string =~ s/([ ]+[0-9,\.]*)[ ]*kbit/\1kilobit/g;
		$string =~ s/([ ]+[0-9,\.]*)[ ]*mbyte/\1megabyte/g;
		$string =~ s/([ ]+[0-9,\.]*)[ ]*kbyte/\1megabyte/g;
		$string =~ s/([ ]+[0-9,\.]*)[ ]*mb/\1megabyte/g;
		$string =~ s/([ ]+[0-9,\.]*)[ ]*kb/\1kilobyte/g;
		$string =~ s/\"/quote/g;
		$string =~ s/_/underscore/g;
		$string =~ s/;\)/winking smilie/g;
		$string =~ s/;-\)/winking smilie/g;
		$string =~ s/:\)/smilie/g;
		$string =~ s/:-\)/smilie/g;
		$string =~ s/:\(/sad smilie/g;
		$string =~ s/:-\(/sad smilie/g;
		$string =~ s/\*g\*/grin/g;
		$string =~ s/\*gg\*/grin grin/g;
		$string =~ s/\*fg\*/sassy grin/g;
		$string =~ s/\*ffg\*/very sassy grin/g;
		$string =~ s/afaik/as far as i know/g;
		$string =~ s/imho/in my humble opinion/g;
		$string =~ s/([^ ]+)\.([^ ]+)/\1point\2/g;
		}
	$string =~ s/;/semicolon/g;
	$string =~ s/-/minus/g;
	$string =~ s/\+/plus/g;
	return($string);
	}

sub Say
	{
	my $text = lc(shift) || return;
	$text = " ".$text." ";
	$text = RepCrap($text);
	system("bash -c \"echo \\\"$text\\\" | say\" &");
	}

sub on_privmsg
	{
	my ($server, $data, $nick, $hostmask) = @_;
	my ($channel, $text) = split(/ :/, $data, 2);
	if ($language eq "de")
		{ Say("$nick sagt: $text"); }
	else
		{ Say("$nick says: $text"); }
	return 0;
	}

sub on_join
	{
	my ($server, $channel, $nick, $hostmask) = @_;
	if ($language eq "de")
		{ Say("$nick hat den Channel $channel betreten."); }
	else
		{ Say("$nick has entered the channel $channel."); }
	return 0;
	}

sub on_quit
	{
	my ($server, $data, $nick, $hostmask) = @_;
	my ($channel, $text) = split(/ :/, $data, 2);
	if ($language eq "de")
		{ Say("$nick hat den Server verlassen."); }
	else
		{ Say("$nick has left the server."); }
	return 0;
	}

sub on_part
	{
	my ($server, $data, $nick, $hostmask) = @_;
	my ($channel, $text) = split(/ :/, $data, 2);
	if ($language eq "de")
		{ Say("$nick hat den Channel $channel verlassen."); }
	else
		{ Say("$nick has left the channel $channel."); }
	return 0;
	}

sub on_nick
	{
	my ($server, $newnick, $nick, $hostmask) = @_;
	if ($language eq "de")
		{ Say("$nick heisst nun $newnick"); }
	else
		{ Say("$nick is now known as $newnick"); }
	return 0;
	}

sub cmd_say
	{
	Say(@_);
	return 0;
	}

sub sig_setup_changed {
	my $l=Irssi::settings_get_str($IRSSI{name}.'_language');
	if (!($l eq 'en' || $l eq 'de')) {
		$l= 'en';
		Irssi::settings_set_str($IRSSI{name}.'_language', $l);
	}
	$language=$l;
	my $j=Irssi::settings_get_bool($IRSSI{name}.'_sayjpq');
	if ($sayjpq != $j) {
		if ($j) {
			Irssi::signal_add("event join", 'on_join');
			Irssi::signal_add("event quit", 'on_quit');
			Irssi::signal_add("event part", 'on_part');
		} else {
			Irssi::signal_remove("event join", 'on_join');
			Irssi::signal_remove("event quit", 'on_quit');
			Irssi::signal_remove("event part", 'on_part');
		}
		$sayjpq = $j;
	}
	my $n=Irssi::settings_get_bool($IRSSI{name}.'_saynickchg');
	if ($saynickchg != $n) {
		if ($n) {
			Irssi::signal_add("event nick", 'on_nick');
		} else {
			Irssi::signal_remove("event nick", 'on_nick');
		}
		$saynickchg= $n;
	}
}

sub cmd_help {
	my ($args, $server, $witem)=@_;
	$args =~ s/\s+//g;
	if ($args eq 'talk' || $args eq 'talk_help') {
		cmd_talk_help();
		Irssi::signal_stop;
	}
	if ($args eq 'talk_about') {
		cmd_talk_about();
		Irssi::signal_stop;
	}
}

Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_language', 'en');
Irssi::settings_add_bool($IRSSI{name}, $IRSSI{name}.'_sayjpq', 0);
Irssi::settings_add_bool($IRSSI{name}, $IRSSI{name}.'_saynickchg', 0);

Irssi::command_bind('talk', 'cmd_say', 'talk.pl');
Irssi::command_bind('talk_about', 'cmd_talk_about', 'talk.pl');
Irssi::command_bind('talk_help', 'cmd_talk_help', 'talk.pl');
Irssi::command_bind('help', 'cmd_help');

Irssi::signal_add("event privmsg", 'on_privmsg');
Irssi::signal_add('setup changed',\&sig_setup_changed);

sig_setup_changed();
#end
