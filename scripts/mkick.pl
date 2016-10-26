#
# Usage: /MKICK [options] [mode] [mask] [reason]
# Options:
#	-n	normal kick
#	-6	'2+4' kickmethod
# Mode:
#	-a	all on channel
#	-o	chops
#	-v	chvoices
#	-d	users without op
#	-l	users without op and voice
# Settings.
#	/SET masskick_default_reason [reason]
#	/SET masskick_default_use_6method [On/Off]
#

use strict;
use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI);

$VERSION = "0.9";
%IRSSI = (
	authors		=> 'Marcin Rozycki',
	contact		=> 'derwan@irssi.pl',
	name		=> 'mkick',
	description	=> 'Masskick, usage: /mkick [-aovdln6 (hostmask)] <[:]reason>',
	license		=> 'GNU GPL v2',
	url		=> 'http://derwan.irssi.pl',
	changed		=> 'Wed Oct  6 20:58:38 CEST 2004'
);

Irssi::theme_register([
	'mkick_not_connected',	'Mkick: Not connected to server',
	'mkick_not_chanwin',	'Mkick: Not joined to any channel',
	'mkick_not_chanop',	'Mkick: You\'re not channel operator on {hilight $0}',
	'mkick_syntax',		'Mkick: $0, use: /MKICK [-a|-o|-v|-d|-l] [-n|-6] (mask) [reason]',
	'mkick_no_users',	'%_Mkick:%_ No users matching given criteria',
	'mkick_kicklist',	'%_Mkick:%_ Send masskick for $1 users on $0: $2-'
]);

sub cmd_mkick
{
	my ($args, $server, $witem) = @_;

	Irssi::printformat(MSGLEVEL_CRAP, "mkick_not_connected"), return if (!$server or !$server->{connected});
	Irssi::printformat(MSGLEVEL_CRAP, "mkick_not_chanwin"), return if (!$witem or $witem->{type} !~ /^channel$/i);
	Irssi::printformat(MSGLEVEL_CRAP, "mkick_not_chanop", $witem->{name}), return if (!$witem->{chanop});

	my $reason = Irssi::settings_get_str("masskick_default_reason");
	my $method = Irssi::settings_get_bool("masskick_default_use_6method");
	my $servernick = $server->{nick};
	my $channel = $witem->{name};
	my $mode = undef;
	my $mask = "*!*\@*";

	my @kicklist = ();
	my @nicklist = ();
	my @args = split(/ +/, $args);

	while ($_ = shift(@args))
	{
		/^..*!..*@..*$/ and $mask = "$&", next;
		/^-(a|o|v|d|l)$/ and s/-//, $mode = $_, next;
		/^-(n|6)$/ and $method = $_ =~ s/6//, next;
		/^-/ and Irssi::printformat(MSGLEVEL_CRAP, "mkick_syntax", "Unknown argument: $_"), return;
		/^:/ and s/^://;
		$reason = ($#args >= 0) ? $_." ".join(" ", @args) : $_;
		last;
	};

	unless ($mode) {
		Irssi::printformat(MSGLEVEL_CRAP, "mkick_syntax", "Missing argument"), return if ($mask eq '*!*@*');
		$mode = "a";
	};

	foreach my $hash ($witem->nicks())
	{
		my $nick = $hash->{nick};
		next if ($nick eq $servernick or !$server->mask_match_address($mask, $nick, $hash->{host}));

		my $isop = $hash->{op};
		my $isvoice = $hash->{voice};

		if ($mode eq "a" or
		    $mode eq "o" && $isop or
		    $mode eq "v" && $isvoice && !$isop or
		    $mode eq "d" && !$isop or
		    $mode eq "l" && !$isop && !$isvoice) {
			push(@kicklist, $nick);
			my $mod = ($isop == 1) ? "\@" : ($isvoice == 1) ? "+" : undef;
			push(@nicklist, $mod.$nick);
		};
	};

	Irssi::printformat(MSGLEVEL_CRAP, "mkick_no_users", $mask, $mode), return if ($#kicklist < 0);
	Irssi::printformat(MSGLEVEL_CRAP, "mkick_kicklist", $channel, scalar(@nicklist), @nicklist);

	if ($method > 0) {
		$reason = substr($reason, 0, 15) if (length($reason) > 15);
		while (@kicklist) {
			$server->send_raw("KICK $channel ".join(",", @kicklist[0 .. $method])." :$reason");
			@kicklist = @kicklist[($method + 1)..$#kicklist];
			$method = ($method == 3 && $#kicklist > 3) ? 1 : 3;
		};
	} else {
		$server->send_raw_split("KICK $channel ".join(",", @kicklist)." :$reason", 2, $server->{max_kicks_in_cmd});
	};
};

Irssi::settings_add_str("misc", "masskick_default_reason", "Irssi BaBy!");
Irssi::settings_add_bool("misc", "masskick_default_use_6method", 0);

Irssi::command_bind("mkick", "cmd_mkick");
