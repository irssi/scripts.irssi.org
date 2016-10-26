use strict;
use vars qw($VERSION %IRSSI);

use Irssi 20020120;
$VERSION = "0.02";
%IRSSI = (
    authors	=> "c0ffee",
    contact	=> "c0ffee\@penguin-breeder.org",
    name	=> "mIRC pager",
    description	=> "Adds the /PAGE command to page a nick (use /page nick <text>)... to ignore pages /set pager_mode off",
    license	=> "Public Domain",
    url		=> "http://www.penguin-breeder.org/?page=irssi",
    changed	=> "Sun Feb 16 11:32 CET 2003",
);

use Irssi::Irc;

Irssi::theme_register(['page_received','-({channick_hilight $0})- $1',
	'page_sending','Paging {nick $0}...',
	'page_pageroff','Page request ignored: {nick $0}\'s pager is {hilight OFF}',
	'page_pagersilent','Page request to {nick $0} dispatched silently',
	'page_pageron','Page request to {nick $0} dispatched']);

sub signal_ctcpmsg_reply {
	my ($server, $data, $nick, $addr, $target) = @_;

	if ($data eq "0") {

		Irssi::printformat(MSGLEVEL_CRAP,'page_pageroff',$nick);

	} elsif ($data eq "1") {
		
		Irssi::printformat(MSGLEVEL_CRAP,'page_pagersilent',$nick);

	} elsif ($data eq "2") {
		
		Irssi::printformat(MSGLEVEL_CRAP,'page_pageron',$nick);
		
	} 
	
	Irssi::signal_stop();
}

sub signal_ctcpmsg {
	my ($server, $data, $nick, $addr, $target) = @_;
	my $pm = Irssi::settings_get_bool('pager_mode');
	my $cmd = Irssi::settings_get_str('pager_cmd');
	my $answer = 0, $pid;
	my $rnd = int(rand(65535));

	if ($pm) {
		$data = "requesting your attention" if ($data eq "");
		Irssi::printformat(MSGLEVEL_CTCPS, 'page_received',$nick,$data);
		$answer = 1;

		$nick =~ s/\\/\\\\/g;
		$nick =~ s/\$/\\\$/g;
		$nick =~ s/;/\\;/g;
		
		$data =~ s/\\/\\\\/g;
		$data =~ s/\$/\\\$/g;
		$data =~ s/;/\\;/g;

		if ($cmd ne "") {

			$answer = 2;
			$cmd =~ s/\$r/$rnd/g;
			$cmd =~ s/\$n/$nick/g;
			$cmd =~ s/\$i/$server->{chatnet}/g;
			$cmd =~ s/\$s/$server->{address}/g;
			$cmd =~ s/\$t/scalar localtime/eg;
			$cmd =~ s/\$m/$data/g;

			Irssi::command("$cmd");

		}
	}

	$server->send_raw("NOTICE $nick :\001PAGE $answer\001");
	
	Irssi::signal_stop();
}

sub cmd_page {
	my ($data, $server, $channel) = @_;
	my ($nick, $what);

	$nick = $data;
	$nick =~ s/\s(.+)//;
	$what = $1;
	$what = " $what" if ($what ne "");
	
	$server->send_raw("PRIVMSG $nick :\001PAGE$what\001");
	Irssi::printformat(MSGLEVEL_CRAP,'page_sending', $nick);

}

Irssi::signal_add('ctcp msg page', 'signal_ctcpmsg');
Irssi::signal_add('ctcp reply page', 'signal_ctcpmsg_reply');
Irssi::command_bind('page','cmd_page');
Irssi::settings_add_bool('misc','pager_mode',true);
Irssi::settings_add_str('misc', 'pager_cmd', "");
# ok, here for the pager_cmd syntax:
# "command [parameters]+"
# where the following things will be replaced:
#  $n	the nick who paged you
#  $m	the message
#  $t	timestamp (format depends on locale)
#  $i	ircnet
#  $s	server
#  $r   a random number
#
# for example:
#   /set pager_cmd exec - play /usr/share/sounds/generic.wav
#   /set pager_cmd beep
#   /set pager_cmd eval exec -nosh -name wish$r wish - ; exec -in wish$r wm withdraw . ; exec -in wish$r tk_messageBox -message "$m" -icon info -type ok -title "$n paging..." ; exec -in wish$r destroy .
