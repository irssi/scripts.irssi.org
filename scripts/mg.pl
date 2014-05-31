# DCC MultiGet
# by Kaveh Moini
#
# Description:
#	* A small and rather resilient script for fetching a list of single packs 
# 	  and ranges of packs from an XDCC bot
#	* Can handle abrupt closing of DCC connection, check whether transfer 
#	  started, and restart incomplete transfers
#	* Avoids flooding bots and getting banned by using configurable delays 
#	  (with sane defaults)
#	* Configurable message prefix
#
# Requires:
#	* Written on IRSSI 0.8.13 (20090331), can't be guaranteed to work on 
#	  previous versions but testing won't hurt 
#	  (don't forget to change 'use Irssi [version];' line)
#	* dcc_autoget = on
#	* dcc_autoresume = on
#
# Note:
#	* For security reasons MultiGet does NOT automatically set dcc_autoget 
#	   and dcc_autoresume you have to do so manually
# 
# Usage:
# 	mg <bot name> <packs to transfer>
#	Fetches specified packs from specified bot
#	<packs to transfer> is a list of numbers, or ranges denoted by '-'
# 	Example: mg BotX 38 1 12-14 82 23-43
# 	Fetches, in order given, packs 38, 1, 12 to 14, 82, and 23 to 43
#	When a range m-n is specified m and n will be fetched too
#	----------------------------------------------------------------------
#	mg_cancel
#	Cancels mg fetching, will NOT close any running transfers
#	----------------------------------------------------------------------
#	mg_reset
#	Resets all mg configuration to defaults
#
# Configuration:
#	NOTE: all delays are in seconds
#	* mg_next_delay: how much to wait before requesting next pack after 
#	  successful transfer, default 5
#	* mg_no_transfer_delay: how much to wait before re-requesting same pack
#	  if transfer fails, default 60
#	* mg_dcc_closed_retry_delay: how much to wait before re-requesting same
#	  pack if DCC connection is closed for whatever reason, default 10
#	* mg_transfer_confirmation_delay: how much to wait before checking if 
#	  requested transfer started, will result in re-requesting the pack if no 
#	  offer is received from the bot after set time, default 30
#	* mg_message_prefix: what to tell the bot to request a pack, should 
#	  include everything before the pack number including the last 
#	  whitespace, default "xdcc send "

use strict;

use Irssi 20090331;

use vars qw($VERSION %IRSSI);

$VERSION = 20090813;
%IRSSI = (
	name => "mg", 
	description => "DCC MultiGet, for fetching from XDCC bots",
	license => "ccBSD, http://creativecommons.org/licenses/BSD/",
	changed => "$VERSION",
	authors => "Kaveh Moini",
	contact => "campanastra\@gmail.com",
);

my ($server, $botname, $pncounter, $pact);
my @totags = ();
my @packs = ();

my $nexdelay = 5; 
my $dcrdelay = 10; 
my $ntrdelay = 60;
my $trcdelay = 30; 
my $msgprefix = "xdcc send ";

sub mg 
{
	@packs = ();
	my @args = split(/ +/, @_[0]);
	if ($#args < 1)
	{
		Irssi::print "MG | too few arguments";
		Irssi::print "MG | usage: mg <bot name> <packs to transfer>";
		return;
	}
	$server = @_[1];
	my $witem = @_[2];
	$botname = shift(@args);
	my ($prh, $prl, $pn);
	foreach my $ps (@args)
	{
		if ($ps =~ /^\d+-\d+$/)
		{
			($prl, $prh) = ($ps =~ /(\d+)-(\d+)/);
			Irssi::print "MG | pack range: " . $prl . " through " . $prh;
			for ($pn = $prl; $pn <= $prh; $pn += 1)
			{
				push(@packs, $pn);
			}
		}
		elsif ($ps =~ /^\d+$/)
		{
			($pn) = ($ps =~ /(\d+)/);
			Irssi::print "MG | pack number: " . $pn;
			push(@packs, $pn);
		}
		else
		{
			Irssi::print "MG | invalid pack specification: " . $ps;
		}
	}
	if ($#packs < 0)
	{
		Irssi::print "MG | no valid packs specifications";
		return;
	}
	Irssi::print "MG | bot name: " . $botname;
	Irssi::print "MG | message prefix: " . "\"" . $msgprefix . "\"";
	$pncounter = 0;
	$pact = 0;
	Irssi::signal_add("dcc closed", "mghandler");
	Irssi::signal_add("dcc get receive", "dcchandler");
	Irssi::print "MG | beginning with: " . $packs[$pncounter];
	&reqpack;
}

sub mghandler
{
	my ($dcc) = @_;
	if ($dcc->{'nick'} eq $botname)
	{
		Irssi::print "MG | pack " . $packs[$pncounter] . " size was: " . $dcc->{'size'};
		Irssi::print "MG | transferred: " . $dcc->{'transfd'};
		Irssi::print "MG | skipped: " . $dcc->{'skipped'};
		$pact = 0;
		foreach my $to (@totags)
		{
			Irssi::timeout_remove($to);
		}
		@totags = ();
		if ($dcc->{'transfd'} == $dcc->{'size'})
		{
			Irssi::print "MG | transfer successful";
			if ($pncounter < $#packs)
			{
				Irssi::print "MG | waiting " . $nexdelay . " seconds";
				Irssi::timeout_add_once($nexdelay * 1000, sub { $pncounter += 1; Irssi::print "MG | getting next: " . $packs[$pncounter]; &reqpack; } , []);
			}
			else
			{
				Irssi::print "MG | ending at: " . $packs[$pncounter];
				Irssi::signal_remove("dcc closed", "mghandler");
				Irssi::signal_remove("dcc get receive", "dcchandler");
				@packs = ();
			}
		}
		else
		{
			Irssi::print "MG | transfer failed";
			Irssi::print "MG | waiting " . $dcrdelay . " seconds";
			Irssi::timeout_add_once($dcrdelay * 1000, sub { Irssi::print "MG | retrying: " . $packs[$pncounter]; &reqpack; } , []);
		}
	}
}

sub dcchandler
{
	my ($gdcc) = @_;
	if ($gdcc->{'nick'} eq $botname)
	{
		Irssi::print "MG | received connection for: " . $packs[$pncounter]; 
		$pact = 1;
	}
}

sub reqpack
{
	$server->command("msg $botname $msgprefix" . $packs[$pncounter]);
	push(@totags, Irssi::timeout_add_once($trcdelay * 1000, sub { if ($pact == 0) { Irssi::print "MG | transfer status not confirmed for: " . $packs[$pncounter]; Irssi::print "MG | waiting " . $ntrdelay . " seconds"; push(@totags, Irssi::timeout_add_once($ntrdelay * 1000, sub { if ($pact == 0) { Irssi::print "MG | retrying: " . $packs[$pncounter]; &reqpack; } } , [])); } }, []));
}

sub setuphandler
{
	($nexdelay, $ntrdelay, $dcrdelay, $trcdelay, $msgprefix) = (Irssi::settings_get_int("mg_next_delay"), Irssi::settings_get_int("mg_no_transfer_delay"), Irssi::settings_get_int("mg_dcc_closed_retry_delay"), Irssi::settings_get_int("mg_transfer_confirmation_delay"), Irssi::settings_get_str("mg_message_prefix"));
}

sub mgreset
{
	$nexdelay = 5; 
	$dcrdelay = 10; 
	$ntrdelay = 60;
	$trcdelay = 30; 
	$msgprefix = "xdcc send ";
	Irssi::settings_set_int("mg_next_delay", $nexdelay);
	Irssi::settings_set_int("mg_no_transfer_delay", $ntrdelay);
	Irssi::settings_set_int("mg_dcc_closed_retry_delay", $dcrdelay);
	Irssi::settings_set_int("mg_transfer_confirmation_delay", $trcdelay);
	Irssi::settings_set_str("mg_message_prefix", $msgprefix);
	Irssi::print "MG | all settings reset to default values";
}

sub mgcancel
{
	Irssi::signal_remove("dcc closed", "mghandler");
	Irssi::signal_remove("dcc get receive", "dcchandler");
	foreach my $to (@totags)
	{
		Irssi::timeout_remove($to);
	}
	@totags = ();
	Irssi::print "MG | cancelled";
	Irssi::print "MG | last requested pack was: " . $packs[$pncounter];
	Irssi::print "MG | remaining packs are: " . join(' ', splice(@packs, $pncounter));
	@packs = ();
}

Irssi::settings_add_int("mg", "mg_next_delay", $nexdelay);
Irssi::settings_add_int("mg", "mg_no_transfer_delay", $ntrdelay);
Irssi::settings_add_int("mg", "mg_dcc_closed_retry_delay", $dcrdelay);
Irssi::settings_add_int("mg", "mg_transfer_confirmation_delay", $trcdelay);
Irssi::settings_add_str("mg", "mg_message_prefix", $msgprefix);
Irssi::signal_add("setup changed", "setuphandler");
Irssi::command_bind("mg", "mg");
Irssi::command_bind("mg_reset", "mgreset");
Irssi::command_bind("mg_cancel", "mgcancel");
