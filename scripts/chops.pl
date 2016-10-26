#!/usr/bin/perl -w

# chops.pl: Simulates BitchX's /chops and /nops commands
# prints list with nickname and userhost
#
# Written by Jakub Jankowski <shasta@atn.pl>
# for irssi 0.7.98.CVS
#
# todo:
#  - enhance the look of the script
#
# sample /chops output:
# [11:36:33] -!- Irssi: Information about chanops on #irssi
# [11:36:33] -!- Irssi: [nick]    [hostmask]
# [11:36:33] -!- Irssi: shasta    shasta@quasimodo.olsztyn.tpsa.pl
# [11:36:34] -!- Irssi: cras      cras@xmunkki.org
# [11:36:34] -!- Irssi: fuchs     fox@wh8043.stw.uni-rostock.de
# [11:36:34] -!- Irssi: End of listing
#
# sample /nops output:
# [11:40:34] -!- Irssi: Information about non-ops on #irssi
# [11:40:34] -!- Irssi: [nick]    [hostmask]
# [11:40:34] -!- Irssi: globe_    ~globe@ui20i21hel.dial.kolumbus.fi
# [11:40:34] -!- Irssi: shastaBX  shasta@thorn.kanal.olsztyn.pl
# [11:40:34] -!- Irssi: End of listing

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "20020223";
%IRSSI = (
    authors     => 'Jakub Jankowski',
    contact     => 'shasta@atn.pl',
    name        => 'chops',
    description => 'Simulates BitchX\'s /CHOPS and /NOPS commands.',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.atn.pl/',
);

use Irssi;
use Irssi::Irc;

Irssi::theme_register([
	'chops_nochan', 'You are not on a channel',
	'chops_notsynced', 'Channel $0 is not fully synchronized yet',
	'chops_noone', 'There are no $0 to list',
	'chops_start', 'Information about $0 on $1',
	'chops_end', 'End of listing',
	'chops_header', '[nick]    [hostmask]',
	'chops_line', '$[!9]0 $[!50]1'
]);

sub cmd_chops {
	my ($data, $server, $channel) = @_;
	my @chanops = ();

	# if we're not on a channel, print appropriate message and return
	if (!$channel) {
		Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_nochan');
		return;
	}

	# if channel is not fully synced yet, print appropriate message and return
	if (!$channel->{synced}) {
		Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_notsynced', $channel->{name});
		return;
	}

	# gather all opped people into an array
	foreach my $nick ($channel->nicks()) {
		push(@chanops, $nick) if ($nick->{op});
	}

	# if there are no chanops, print appropriate message and return
	if (scalar(@chanops) < 1) {
		Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_noone', "chanops");
		return;
	}

	# print a starting message
	Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_start', "chanops", $channel->{name});

	# print listing header
	Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_header');

	# print every chanop's nick, status (gone/here), userhost and hopcount
	foreach my $nick (@chanops) {
		my $userhost = $nick->{host};
		# if user's host is longer than 50 characters, cut it to 47 to fit in column
		$userhost = substr($userhost, 0, 47) if (length($userhost) > 50);
		Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_line', $nick->{nick}, $userhost);
	}

	# print listing footer
	Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_end');
}

sub cmd_nops {
	my ($data, $server, $channel) = @_;
	my @nonops = ();

	# if we're not on a channel, print appropriate message and return
	if (!$channel) {
		Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_nochan');
		return;
	}

	# if channel is not fully synced yet, print appropriate message and return
	if (!$channel->{synced}) {
		Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_notsynced', $channel->{name});
		return;
	}

	# gather all not opped people into an array
	foreach my $nick ($channel->nicks()) {
		push(@nonops, $nick) if (!$nick->{op});
	}

	# if there are only chanops, print appropriate message and return
	if (scalar(@nonops) < 1) {
		Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_noone', "non-ops");
		return;
	}

	# print a starting message
	Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_start', "non-ops", $channel->{name});

	# print listing header
	Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_header');

	# print every chanop's nick, status (gone/here), userhost and hopcount
	foreach my $nick (@nonops) {
		my $userhost = $nick->{host};
		# if user's host is longer than 50 characters, cut it to 47 to fit in column
		$userhost = substr($userhost, 0, 47) if (length($userhost) > 50);
		Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_line', $nick->{nick}, $userhost);
	}

	# print listing footer
	Irssi::printformat(MSGLEVEL_CLIENTNOTICE, 'chops_end');
}

Irssi::command_bind("chops", "cmd_chops");
Irssi::command_bind("nops", "cmd_nops");
