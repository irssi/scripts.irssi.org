# dice_concise / Based on Marcel Kossin's 'dice' RP Dice Simulator
#
# What is this?
#
# -- Marcel Kossin's notes: --
#
# I (mkossin) often Dungeon Master on our Neverwinternights Servers called 'Bund der
# alten Reiche' (eng. 'Alliance of the old realms') at bundderaltenreiche.de
# (German Site) Often idling in our Channel I thought it might be Fun to have
# a script to dice. Since I found nothing for irssi I wrote this little piece
# of script. The script assumes, that if a 'd' for english dice is given it
# should print the output in English. On the other hand if a 'w' for German
# 'Würfel' is given it prints the output in German.
#
# Usage.
#
# Anyone on the Channel kann ask '!roll' to toss the dice for him. He just has
# to say what dice he want to use. The notation should be well known from
# RP :-) Thus
#
# Write: !roll <quantity of dice>d[or w for german users]<sides on dice>
#
# Here are some examples
#
# !roll 2d20
# !roll 3d6
#
# OK, I think you got it already :-)
#
# Write: !roll version
# For Version Information
#
# Write: !roll help
# For Information about how to use it
#
# -- Makaze's notes: --
#
# [Changes in dice_concise:]
#
# Features added:
#
# [ ] Can add bonuses to the roll. e.g. "!roll 3d6+10"
# [ ] Output changed to one line only. e.g. "Makaze rolls the 3d6 and gets: 9 [4,
#     4, 1]"
# [ ] Corrected English grammar.
# [ ] Removed insults.
# [ ] Cleaner code with fewer nested if statements and true case switches.
# [ ] Errors call before the loop, saving clock cycles.
#
# Bugs fixed:
#
# [ ] Rolls within the correct range.*
#
# Edge cases added:
#
# [ ] Catch if rolling less than 1 dice.
# [ ] Catch if dice or sides are above 100 instead of 99.
#
# -----------------------------------------
#
# * [The original dice.pl rolled a number between 1 and (<number of sides> - 1)]
#   [instead of using the full range. e.g. "!roll 1d6" would output 1 through  ]
#   [5, but never 6.                                                           ]
#
# -----------------------------------------
#
# Original script 'dice.pl' by mkossin.
#
# Updated script 'dice_concise.pl' by Makaze.

use strict;
use vars qw($VERSION %IRSSI);
use feature qw(switch);
use Scalar::Util qw(looks_like_number);

use Irssi qw(command_bind signal_add);

$VERSION = '0.1.5';
%IRSSI = (
	authors			=> 'Marcel Kossin, Makaze',
	contact			=> 'izaya.orihara@gmail',
	name			=> 'dice_concise',
	description		=> 'A concise dice simulator for channels.',
	license			=> 'GNU GPL v2 or later'
);

sub own_question {
	my ($server, $msg, $nick, $address, $target) = @_;
	question($server, $msg, $nick, $target);
}

sub public_question {
	my ($server, $msg, $nick, $address, $target) = @_;
	question($server, $msg, $nick, $target);
}

sub question($server, $msg, $nick, $target) {
	my ($server, $msg, $nick, $target) = @_;
	$_ = $msg;

	my $msgCompare = lc;

	if (substr($msgCompare, 0, 5) ne '!roll') {
		return 0;
	}

	unless (length $target) {
		$target = $nick;
		$nick = $server->{nick};
	}

	if (/\d[dw]\d/i) {
		my $rnd;
		my $forloop;
		my $lang;
		my @roll = split(/\s/, $_, 2);
		my ($dice, $sides) = (@roll[1] =~ /(\d+)[dw](\d+)/i);
		my @modifiers = ($roll[1] =~ /([\+\-\*\/]\d+)/gi);
		my $modifyType;
		my $modifyVal;
		my @modifyErrors = ($roll[1] =~ /([\+\-\*\/][^\d\+\-\*\/]+)/);
		my $value;
		# Plus support added
		my @rolls;

		if (/\d[w]\d/i) {
			$lang = 'DE';
		} else {
			$lang = 'EN';
		}

		if ($dice < 1) {
			given ($lang) {
				when ('DE') {
					$server->command('msg ' . $target . ' ' . $nick  . ' macht nichts... Würfeln funktioniert am besten mit Würfeln.');
				}
				when ('EN') {
					$server->command('msg ' . $target . ' ' . $nick  . ' does nothing... Rolling dice works best with dice.');
				}
			}
			return 0;
		} elsif ($dice > 100) {
			given ($lang) {
				when ('DE') {
					$server->command('msg ' . $target . ' ' . $nick  . ' scheitert den ' . $roll[1] . ' zu werfen... Versuch es mit weniger Würfeln.');
				}
				when ('EN') {
					$server->command('msg ' . $target . ' ' . $nick  . ' fails to roll the ' . $roll[1] . '... Try fewer dice.');
				}
			}
			return 0;
		} elsif ($sides <= 1) {
			if ($sides == 0) {
				given ($lang) {
					when ('DE') {
						$server->command('msg ' . $target . ' ' . $nick  . ' verursacht ein Paradox... Oder hat jemand schon mal einen Würfel ohne Seiten gesehen?');
					}
					when ('EN') {
						$server->command('msg ' . $target . ' ' . $nick  . ' causes a paradox... Or has anybody ever seen a die without sides?');
					}
				}
				return 0;
			} elsif ($sides == 1) {
				given ($lang) {
					when ('DE') {
						$server->command('msg ' . $target . ' ' . $nick  . ' verursacht ein Paradox... Oder hat jemand schon mal einen Würfel mit nur einer Seite gesehen?');
					}
					when ('EN') {
						$server->command('msg ' . $target . ' ' . $nick  . ' causes a paradox... Or has anybody ever seen a die with only one side?');
					}
				}
				return 0;
			}
		} elsif ($sides > 100) {
			given ($lang) {
				when ('DE') {
					$server->command('msg ' . $target . ' ' . $nick  . ' scheitert den ' . $roll[1] . ' zu werfen... Versuch es mit weniger Augen.');
				}
				when ('EN') {
					$server->command('msg ' . $target . ' ' . $nick  . ' fails to roll the ' . $roll[1] . '... Try fewer sides.');
				}
			}
			return 0;
		}
		for ($forloop = 0; $forloop < $dice; $forloop++) {
			$rnd = int(rand($sides));
			if ($rnd == 0) {
				$rnd = $sides;
			}
			$value += $rnd;
			$rolls[$forloop] = $rnd;
		}
		foreach (@modifiers) {
			($modifyType) = ($_ =~ /([\+\-\*\/])/);
			($modifyVal) = ($_ =~ /(\d+)/);
			given ($modifyType) {
				when ('*') {
					$value = $value * $modifyVal;
				}
				when ('/') {
					$value = $value / $modifyVal;
				}
				when ('+') {
					$value = $value + $modifyVal;
				}
				when ('-') {
					$value = $value - $modifyVal;
				}
			}
		}
		given ($lang) {
			when ('DE') {
				$server->command('msg ' . $target . ' '. $nick . ' würfelt mit dem ' . $roll[1] . ' und erhält: ' . $value . ' [' . join(', ', @rolls) . ']');
			}
			when ('EN') {
				$server->command('msg ' . $target . ' '. $nick . ' rolls the ' . $roll[1] . ' and gets: ' . $value . ' [' . join(', ', @rolls) . ']');
			}
		}
		if (@modifyErrors) {
			given ($lang) {
				when ('DE') {
					$server->command('msg ' . $target . ' ' . $nick  . ' scheitert ihr Ergebnis zu ändern. Versuch es mit Zahlen. [' . join(', ', @modifyErrors) . ']');
				}
				when ('EN') {
					$server->command('msg ' . $target . ' ' . $nick  . ' fails to modify their result. Try using numbers. [' . join(', ', @modifyErrors) . ']');
				}
			}
		}
		return 1;
	} elsif (substr($msgCompare, 0, 13) eq '!roll version') {
		$server->command('msg ' . $target . " \x039" . $IRSSI{'name'} . ": Version " . $VERSION . " by Makaze & mkossin");
		return 0;
	} elsif (substr($msgCompare, 0, 10) eq '!roll help') {
		$server->command('msg ' . $target . ' Syntax: "!roll <quantity of dice>d<sides on dice>[<+-*/>modifier]" - e.g. "!roll 2d20", "!roll 2d20*2+10"');
		return 0;
	} elsif (substr($msgCompare, 0, 11) eq '!roll hilfe') {
		$server->command('msg ' . $target . ' Syntax: "!roll <Anzahl der Würfel>w<Augen des Würfels>[<+-*/>Modifikator]" - z.B. "!roll 2w20", "!roll 2w20*2+10"');
		return 0;
	} else {
		$server->command('msg ' . $target .' "!roll help"  - gives the English help');
		$server->command('msg ' . $target . ' "!roll hilfe" - zeigt die deutsche Hilfe an');
		return 0;
	}
}

signal_add('message public', 'public_question');
signal_add('message own_public', 'own_question');