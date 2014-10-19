# $Id: pager.pl,v 1.23 2003/01/27 09:45:16 jylefort Exp $

use strict;
use Irssi 20020121.2020 ();
$VERSION = "1.1";
%IRSSI = (
	  authors     => 'Jean-Yves Lefort',
	  contact     => 'jylefort\@brutele.be',
	  name        => 'pager',
	  description => 'Notifies people if they send you a private message or a DCC chat offer while you are away; runs a shell command configurable via /set if they page you',
	  license     => 'BSD',
	  changed     => '$Date: 2003/01/27 09:45:16 $ ',
);

# note:
#
#	Irssi special variables (see IRSSI_DOC_DIR/special_vars.txt) will be
#	expanded in *_notice /set's, and will NOT be expanded in page_command
#	for obvious security reasons.
#
# /set's:
#
#	page_command	a shell command to run if someone sends you the
#			private message 'page' while you are away
#
#	away_notice	a notice to send to someone sending you a private
#			message while you are away
#
#	paged_notice	a notice to send to someone who has just paged you
#
#	dcc_notice	a notice to send to someone who has just sent you
#			a DCC chat offer (this automatically pages you)
#
# changes:
#
#	2003-01-27	release 1.1
#			* notices and commands are now optional
#
#	2002-07-04	release 1.01
#			* things are now printed in the right order
#			* signal_add's uses a reference instead of a string
#
#	2002-04-25	release 1.00
#			* increased version number
#
#	2002-02-06	release 0.20
#			* builtin expand deprecated;
#			  now uses Irssi's special variables
#
#	2002-01-27	release 0.11
#			* uses builtin expand
#
#	2002-01-23	initial release

use strict;
use Irssi::Irc;			# for DCC object

sub message
  {
    my ($server, $msg, $nick, $address) = @_;
  
    if ($server->{usermode_away})
      {
	if (lc($msg) eq "page")
	  {
	    my $page_command = Irssi::settings_get_str("page_command");
	    my $paged_notice = Irssi::settings_get_str("paged_notice");

	    if ($page_command)
	      {
		system($page_command);
	      }
	    if ($paged_notice)
	      {
		$server->command("EVAL NOTICE $nick $paged_notice");
	      }
	  }
	else
	  {
	    my $away_notice = Irssi::settings_get_str("away_notice");
	    
	    if ($away_notice)
	      {
		$server->command("EVAL NOTICE $nick $away_notice");
	      }
	  }
      }
  }

sub dcc_request
  {
    my ($dcc, $sendaddr) = @_;
    
    if ($dcc->{server}->{usermode_away} && $dcc->{type} eq "CHAT")
      {
	my $page_command = Irssi::settings_get_str("page_command");
	my $dcc_notice = Irssi::settings_get_str("dcc_notice");

	if ($page_command)
	  {
	    system($page_command);
	  }
	if ($dcc_notice)
	  {
	    $dcc->{server}->command("EVAL NOTICE $dcc->{nick} $dcc_notice");
	  }
      }
  }

Irssi::settings_add_str("misc",	"page_command",
			"esdplay ~/sound/events/page.wav &");
Irssi::settings_add_str("misc", "away_notice",
			'$N is away ($A). Type /MSG $N PAGE to page him.');
Irssi::settings_add_str("misc", "paged_notice",
			'$N has been paged.');
Irssi::settings_add_str("misc",	"dcc_notice",
			'$N is away ($A) and has been paged. Type /MSG $N PAGE to page him again.');

Irssi::signal_add_priority("message private", \&message,
			   Irssi::SIGNAL_PRIORITY_LOW + 1);
Irssi::signal_add_priority("dcc request", \&dcc_request,
			   Irssi::SIGNAL_PRIORITY_LOW + 1);
