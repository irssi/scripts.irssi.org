use Irssi;
use Irssi::Irc;
use strict;

use vars qw($VERSION %IRSSI);

$VERSION="0.3";
%IRSSI = (
	authors=> 'BC-bd',
	contact=> 'bd@bc-bd.org',
	name=> 'ai',
	description=> 'Puts people on ignore if they do a public away. See source for options.',
	license=> 'GPL v2',
	url=> 'https://bc-bd.org/svn/repos/irssi/trunk/',
);

# $Id: ai.pl,v 1.4 2002/06/02 15:20:03 bd Exp $
# for irssi 0.8.4 by bd@bc-bd.org
#
#########
# USAGE
###
#
# Examples:
#
#	Ignore people saying "away"
#		/set ai_words away
#
#	Ignore people saying "gone for good" or "back"
#		/set ai_words gone for good,back
#
#	Ignore people for 500 seconds
#		/set ai_time 500
#
#	Ignore people forever
#		/set ai_time 0
#
#	Ignore people only on channels #foo,#bar
#		/set ai_ignore_only_in ON
#		/set ai_channels #foo,#bar
#
#	Ignore people on all channels BUT #foo,#bar
#		/set ai_ignore_only_in OFF
#		/set ai_channels #foo,#bar
# 
#	Ignore people on all channels
#		/set ai_ignore_only_in OFF
#		/set -clear ai_channels
#
#	Perform a command on ignore (e.g send them a message)
#		/set ai_command ^msg -$C $N no "$W" in $T please
#	
#	would become on #foo on chatnet bar from nick dude with "dude is away"
#		/msg -cbar dude no "away" in #foo please
#
#	look further down for details
#
#	Per channel command on #irssi:
#		/ai #irssi ^say foobar
#
#	delete channel command in #irssi:
#		/ai #irssi
#
#########
# OPTIONS
#########
#
# /set ai_words [expr[,]+]+
#		* expr  : comma seperated list of expressions that should trigger an ignore
#		  e.g.  : away,foo,bar baz bat,bam
#
# /set ai_command [command]
#		* command  : to be executed on a triggered ignore.
#		  /set -clear ai_command to disable. The following $'s are expanded
#		  ( see the default command for an example ):
#		    $C : Chatnet (e.g. IRCnet, DALNet, ...)
#		    $N : Nick (some dude)
#		    $W : Word (the word(s) that triggered the ignore
#		    $T : Target (e.g. the channel)
#
# /set ai_channels [#channel[ ]]+
#		* #channel  : space seperated list of channels, see ai_ignore_only_in
#
# /set ai_time <seconds>
#		* seconds  : number of seconds to wait before removing the ignore
#
# /set ai_ignore_only_in <ON|OFF>
#		* ON  : only trigger ignores in ai_channels
#		* OFF : trigger ignores in all channels EXCEPT ai_channels
#
# /set ai_display <ON|OFF>
#		* ON  : log whole sentence
#		* OFF : only log word that matched regex
#
###
################
###
#
# Changelog
#
# Version 0.4
# 	- added optional sentence output
#
# Version 0.3
#	- added per channel command support
#	- the command is now executed in the channel the event occured
#	- changed the expand char from % to $
#
# Version 0.2
#  - changed MSGLVL_ALL to MSGLVL_ACTIONS to avoid problems
#	  with channels with ignored Levels
#
# Version 0.1
#  - initial release
#
###
################

sub expand {
  my ($string, %format) = @_;
  my ($exp, $repl);
  $string =~ s/\$$exp/$repl/g while (($exp, $repl) = each(%format));
  return $string;
}

sub combineSettings {
	my ($setting,$string,$match) = @_;

	$match =  quotemeta($match);

	if ($setting) {
		if ($string !~ /$match\b/i) {
			return 1;
		}
	} else {
		if ($string =~ /$match\b/i) {
			return 1;
		}
	}

	return 0;
}

sub sig_action() {
	my ($server,$msg,$nick,$address,$target) = @_;
	
	my $command;

	if ($server->ignore_check($nick, $address, $target, $msg, MSGLEVEL_ACTIONS)) {
		return;
	}

	if (combineSettings(Irssi::settings_get_bool('ai_ignore_only_in'),
		Irssi::settings_get_str('ai_channels'),$target)) {
		return ;
	}

	my @words = split(',',Irssi::settings_get_str('ai_words'));

	foreach (@words) {
		if ($msg =~ /$_/i) {
			my $word = $_;

			my $sentence = $word;

			my $channel = $server->channel_find($target);
			my $n = $channel->nick_find($nick);

			my $type = Irssi::Irc::MASK_USER | Irssi::Irc::MASK_DOMAIN;
			my $mask = Irssi::Irc::get_mask($n->{nick}, $n->{host}, $type);
			
			my $time = Irssi::settings_get_int('ai_time');
			if ($time == 0) {
				$time = "";
			} else {
				$time = "-time ".$time;
			}
			Irssi::command("^ignore ".$time." $mask");

			if (Irssi::settings_get_bool('ai_display')) {
				$sentence = $msg
			}
			Irssi::print("Ignoring $nick$target\@$server->{chatnet} because of '$sentence'");

			my %commands = stringToHash('`',Irssi::settings_get_str('ai_commands'));
			if (defined $commands{$target}) {
				$command = $commands{$target};
			} else {
				$command = Irssi::settings_get_str('ai_command');
			}

			if ($command ne "") {
				$command = expand($command,"C",$server->{tag},"N",$nick,"T",$target,"W",$word);
				$server->window_item_find($target)->command($command);
				$server->window_item_find($target)->print($command);
			}

			return;
		}
	}
}

sub stringToHash {
	my ($delim,$str) = @_;

	return split($delim,$str);
}

sub hashToString {
	my ($delim,%hash) = @_;

	return join($delim,%hash);
}

sub colorCommand {
	my ($com) = @_;

	$com =~ s/\$(.)/%_\$$1%_/g;

	return $com;
}

sub cmd_ai {
	my ($data, $server, $channel) = @_;

	my $chan = $data;
	$chan =~ s/ .*//;
	$data =~ s/^\Q$chan\E *//;

	my %command = stringToHash('`',Irssi::settings_get_str('ai_commands'));

	if ($chan eq "") {
		foreach my $key (keys(%command)) {
			Irssi::print("AI: %_$key%_ = ".colorCommand($command{$key}));
		}
	
		Irssi::print("AI: placeholders: %_\$C%_)hatnet %_\$N%_)ick %_\$W%_)ord %_\$T%_)arget");
		Irssi::print("AI: not enough parameters: ai <channel> [command]");

		return;
	}

	if ($data eq "") {
		delete($command{$chan});
	} else {
		$command{$chan} = $data;
	}

	Irssi::settings_set_str('ai_commands',hashToString('`',%command));

	Irssi::print("AI: command on %_$chan%_ now: '".colorCommand($data)."'");
}

Irssi::command_bind('ai', 'cmd_ai');

# "message irc action", SERVER_REC, char *msg, char *nick, char *address, char *target
Irssi::signal_add_first('message irc action', 'sig_action');

Irssi::settings_add_str('misc', 'ai_commands', '');
Irssi::settings_add_str('misc', 'ai_words', 'away,gone,ist auf');
Irssi::settings_add_str('misc', 'ai_command', '^msg -$C $N no "$W" in $T please');
Irssi::settings_add_str('misc', 'ai_channels', '');
Irssi::settings_add_int('misc', 'ai_time', 500);
Irssi::settings_add_bool('misc', 'ai_ignore_only_in', 0);
Irssi::settings_add_bool('misc', 'ai_display', 0);
