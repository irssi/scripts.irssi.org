#!/usr/bin/env perl
#
# Irssi script for easy usage of unicode emoticons.
#
# Package `unifont` should have to be installed so that 
# some of these display correctly. Depending on the font, some
# of them may not really work anyway. 
#
# Feel free to add your own.
#
# Enjoy! (⌐■_■)ノ♪♬

use strict;
use utf8;
use vars qw($VERSION %IRSSI %EMOTICONS);

$VERSION = "0.0.1";

%IRSSI = (
    authors      =>     "Ilkka Pale",
    contact      =>     "ilkka.pale\@gmail.com",
    name         =>     "emo",
    description  =>     "Outputs various unicode emoticons",
    commands     =>     "emo",
    license      =>     "Public Domain"
);

use Irssi;
use Irssi::Irc;

%EMOTICONS = (
    happy         => 'ʘ‿ʘ',
    smile         => '◔ ⌣ ◔',
    flex          => 'ᕙ(⇀‸↼‶)ᕗ',
    shrug         => '¯\_(ツ)_/¯',
    wave          => '(•◡•)/',
    bear          => 'ʕ•ᴥ•ʔ',
    love          => '♥‿♥',
    shock         => '⊙▃⊙',
    wink          => '◕‿↼',
    what          => '☉_☉',
    worried       => '⊙﹏⊙',
    fingers       => '╭∩╮(-_-)╭∩╮',
    tableflip     => '(╯°□°）╯︵ ┻━┻',
    tableback     => '┬──┬ ノ(゜-゜ノ)',
    heart         => '❤',
    lenny         => '(͡° ͜ʖ ͡°)',
    gift          => '(´・ω・)っ由',
    disapprove    => 'ಠ_ಠ',
    tired         => 'ب_ب',
    handsup       => '╚(•⌂•)╝',
    dance         => '(⌐■_■)ノ♪♬',
    sad           => '⊙︿⊙',
    ohplease      => 'ヘ(￣ω￣ヘ)',
    kiss          => '(っ˘з(˘⌣˘ )',
    owl           => '◎▼◎',
    hrm           => '눈_눈',
    success       => '(•̀ᴗ•́)و',
    whatever      => '◔_◔',
    amazed        => '＼(◎o◎)／',
    suave         => '〜(￣△￣〜)',
    eyes          => 'Ծ_Ծ',
    ghost         => '༼✷ɷ✷༽',
    stoned        => '{◕ ◡ ◕}',
    angry         => '►_◄',
);

sub emolist {
    foreach my $key (sort keys %EMOTICONS) {
        Irssi::print($key . " = " . $EMOTICONS{$key});
    } 
}

sub emo {
    my ($key, $server, $dest) = @_;
    
    if (!$server || !$server->{connected}) {
        Irssi::print("Not connected to server.");
        return;
    }
    return unless $dest;

    if (!exists $EMOTICONS{$key}) {
        return;
    }

    $dest->command("msg " . $dest->{name} . " " . $EMOTICONS{$key});
}

Irssi::command_bind('emo', 'emo');
Irssi::command_bind('emolist', 'emolist');
