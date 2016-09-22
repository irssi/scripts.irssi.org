#    Copyright (C) 2015  Dawid Lekawski
#      contact: xxrud0lf@gmail.com
#
#       --- INFORMATION ---
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#       --- END OF INFORMATION ---
#
#     Emote script - replace :emote_name: in your sent messages into predefined 
#   emotes (mostly but not limited to unicode). Result is visible both for you
#   and channel/query target users.
#
#     Feel free to modify or add your own ones!
#
#      (that's a lot of "emote" word, isn't it?)
#
#   commands:
#
#   - /emotes   - shows list of emotes in status window
#
#   notes:
#
#   - script doesn't work with /msg target text; must be typed in a channel
#     or query window
#
#   - Ctrl+O (ascii 15) at the beggining of your text turns off emote replacing 
#     for this text
#
#   - remeber to escape "\" characters in emotes (just type it twice -> "\\"),
#       take a look at 'shrug' emote for reference
#

use strict;
use warnings;
use utf8;

use Irssi qw(signal_add signal_continue command_bind);

our $VERSION = "1.00";
our %IRSSI = (
	authors		=> "Dawid 'rud0lf' Lekawski",
	contact		=> 'rud0lf/IRCnet; rud0lf/freenode; xxrud0lf@gmail.com',
	name		=> 'emotes script',
	description	=> 'Replaces :emote_name: text in your sent messages into pre-defined emotes (unicode mostly).',
	license		=> 'GPLv3'
);

my $pattern = '';
my %emotes = (
	'huh', '°-°',
	'lenny', '( ͡° ͜ʖ ͡°)',
	'shrug', '¯\\_(ツ)_/¯',
	'smile', '☺',
	'sad', '☹',
	'heart', '♥',
	'note', '♪',
	'victory', '✌',
	'coffee', '☕',
	'kiss', '💋',
	'inlove', '♥‿♥',
	'annoyed', '(¬_¬)',
	'bear', 'ʕ•ᴥ•ʔ',
	'animal', '(•ω•)',
	'happyanimal', '(ᵔᴥᵔ)',
	'strong', 'ᕙ(⇀‸↼‶)ᕗ',
	'happyeyeroll', '◔ ⌣ ◔',
	'tableflip', '(╯°□°）╯︵ ┻━┻',
	'tableback', '┬──┬ ノ( ゜-゜ノ)',
	'tm', '™',
	'birdflip', '╭∩╮(-_-)╭∩╮',
	'lolshrug', '¯\\(°_o)/¯',
	'shades', '(⌐■_■)',
	'smoke', '🚬',
	'poop', '💩',
	'drops', '💦',
	'yuno', 'щ（ﾟДﾟщ)',
	'dead', '✖_✖',
	'wtf', '☉_☉',
	'disapprove', '๏̯͡๏',
	'wave', '(•◡•)/',
    'shock', '⊙▃⊙',
    'wink', '◕‿↼',
	'gift', '(´・ω・)っ由',
    'success', '(•̀ᴗ•́)و',
	'whatever', '◔_◔'
);

sub init {
	$pattern = join('|', keys %emotes);
	if ($pattern eq '') {
		$pattern = '!?';
	}
}

sub process_emotes {
	my ($line) = @_;
	
	# don't process line starting with Ctrl+O (ascii 15)
	if ($line =~ /^\x0f/) {
		return $line;
	}

	$line =~ s/:($pattern):/$emotes{$1}/g;

	return $line;
}

sub sig_send_text {
	my ($line, $server, $witem) = @_;

	return unless ($witem);
	return unless ($witem->{type} eq "CHANNEL" or $witem->{type} eq "QUERY");

	my $newline = process_emotes($line);
	signal_continue($newline, $server, $witem);
}

sub pad {
	my ($txt, $cnt) = @_;

	if (length($txt) >= $cnt) {
		return $txt;
	}	
	
	$txt .= " " x ($cnt - length($txt));
	return $txt;
}

sub cmd_emotes {
	my ($data, $server, $witem) = @_;
	
	Irssi::print('List of emotes:', MSGLEVEL_CLIENTCRAP);
	foreach my $key (sort(keys %emotes)) {
		my $emote = $emotes{$key};
		Irssi::print('* '. pad($key, 15) . ' : ' . $emote, MSGLEVEL_CLIENTCRAP);
	}	
	Irssi::print('Total of '.scalar(keys %emotes).' emotes.', MSGLEVEL_CLIENTCRAP);
}

init();

signal_add("send text", "sig_send_text");
command_bind("emotes", "cmd_emotes");


