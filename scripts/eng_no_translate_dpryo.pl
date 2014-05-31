# A simple script for all Norwegians who like to get
# all incoming english text translated to Norwegian :D
# Written by dpryo <hnesland@samsen.com>
#
# WARNING:
# Dunno what freetranslation.com thinks about it ;D
# ..so remember, this scripts sends ALL incoming public messages
# as a webrequest to their server. That is, one request pr.
# message you get. In other words, if somebody pubfloods 100 lines, you will 
# visit freetranslation.com 100 times ;)
###### 
#
# There is at least one bug in it .. It doesn't check wether the
# incoming text is english or not before it sends the request.
#
# Somebody could perhaps fix that?, since i'm a lazy asshole.
#
# Another thing, it doesn't handles channels or anything, so
# I could call this a "Technology Preview" as all the big
# guys are calling their software when it's in a buggy and
# not-so-very-usefull stage of development :P
# 
use Irssi;
use LWP::Simple;
use vars qw($VERSION %IRSSI);
$translate =0;

$VERSION = "0.2";
%IRSSI = (
	authors     => "Harald Nesland",
	contact     => "hnesland\@samsen.com",
	name        => "EngNoTranslate",
	description => "Very simple script that sends incoming text to freetranslation.com for english->norwegian translation. May be modified to translate other languages.",
	license     => "Public Domain",
	url         => "http://www.satyra.net",
	changed     => "Thu Apr 11 14:15:25 CEST 2002"
);

sub income {
my ($server, $data, $nick, $mask, $target) = @_;
		$eng = $data;
	if($translate=1) {
		$eng =~ s/ /+/ig;
		chop($eng);
		Irssi::command("/echo [$nick] $eng");
		$result = get("http://ets.freetranslation.com:5081/?Sequence=core&Mode=txt&template=TextResults2.htm&Language=English/Norwegian&SrcText=$eng");
		Irssi::command("/echo [$nick] $result");
	}
}

sub trans {

	if($translate =0) { $translate=1; } else { $translate =0; }
}

Irssi::signal_add("message public", "income");
Irssi::command_bind("translate","trans");			  
