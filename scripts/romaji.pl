#!/usr/bin/perl -w
#
# Copyright (c) 2002 Victor Ivanov <v0rbiz@yahoo.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '1.0b3';
%IRSSI = (
    authors	=> 'Victor Ivanov',
    contact	=> 'v0rbiz@yahoo.com',
    name	=> 'romaji',
    description => 'translates romaji to hiragana or katakana in text enclosed in ^R',
    license	=> 'BSD 2-clause',
    url		=> 'http://irssi.org/scripts/'
);


my(%hira) = (
    "a"   => "あ", "i"   => "い", "u"   => "う", "e"   => "え", "o"   => "お",
    "ka"  => "か", "ki"  => "き", "ku"  => "く", "ke"  => "け", "ko"  => "こ",
    "sa"  => "さ", "shi" => "し", "su"  => "す", "se"  => "せ", "so"  => "そ",
    "ta"  => "た", "chi" => "ち", "tsu" => "つ", "te"  => "て", "to"  => "と",
    "na"  => "な", "ni"  => "に", "nu"  => "ぬ", "ne"  => "ね", "no"  => "の",
    "ha"  => "は", "hi"  => "ひ", "hu"  => "ふ", "he"  => "へ", "ho"  => "ほ", "fu"  => "ふ",
    "ma"  => "ま", "mi"  => "み", "mu"  => "む", "me"  => "め", "mo"  => "も",
    "ya"  => "や", "yu"  => "ゆ", "yo"  => "よ",
    "ra"  => "ら", "ri"  => "り", "ru"  => "る", "re"  => "れ", "ro"  => "ろ",
    "wa"  => "わ", "wi"  => "ゐ", "we"  => "ゑ", "wo"  => "を",
    "n"   => "ん",
    "m"   => "ん",

    "ga"  => "が", "gi"  => "ぎ", "gu"  => "ぐ", "ge"  => "げ", "go"  => "ご",
    "za"  => "ざ", "ji"  => "じ", "zu"  => "ず", "ze"  => "ぜ", "zo"  => "ぞ",
    "da"  => "だ", "dzi" => "ぢ", "dzu" => "づ", "de"  => "で", "do"  => "ど",
    "ba"  => "ば", "bi"  => "び", "bu"  => "ぶ", "be"  => "べ", "bo"  => "ぼ",
    "pa"  => "ぱ", "pi"  => "ぴ", "pu"  => "ぷ", "pe"  => "ぺ", "po"  => "ぽ",

    "fa"  => "ふぁ", "fi"  => "ふぃ", "fe"  => "ふぇ", "fo"  => "ふぉ",
    "di"  => "でぃ",

    "kya" => "きゃ", "kyu" => "きゅ", "kyo" => "きょ",
    "sha" => "しゃ", "shu" => "しゅ", "sho" => "しょ",
    "cha" => "ちゃ", "chu" => "ちゅ", "cho" => "ちょ",
    "nya" => "にゃ", "nyu" => "にゅ", "nyo" => "にょ",
    "hya" => "ひゃ", "hyu" => "ひゅ", "hyo" => "ひょ",
    "mya" => "みゃ", "myu" => "みゅ", "myo" => "みょ",
    "rya" => "りゃ", "ryu" => "りゅ", "ryo" => "りょ",
    "gya" => "ぎゃ", "gyu" => "ぎゅ", "gyo" => "ぎょ",
    "ja"  => "じゃ", "ju"  => "じゅ", "jo"  => "じょ",
    "jya" => "じゃ", "jyu" => "じゅ", "jyo" => "じょ",
    "dza" => "ぢゃ", "dju" => "ぢゅ", "dzo" => "ぢょ",
    "dja" => "ぢゃ",                  "djo" => "ぢょ",
    "bya" => "びゃ", "byu" => "びゅ", "byo" => "びょ",
    "pya" => "ぴゃ", "pyu" => "ぴゅ", "pyo" => "ぴょ",

    "TSU" => "っ"
);

my(%kata) = (
    "a"   => "ア", "i"   => "イ", "u"   => "ウ", "e"   => "エ", "o"   => "オ",
    "ka"  => "カ", "ki"  => "キ", "ku"  => "ク", "ke"  => "ケ", "ko"  => "コ",
    "sa"  => "サ", "shi" => "シ", "su"  => "ス", "se"  => "セ", "so"  => "ソ",
    "ta"  => "タ", "chi" => "チ", "tsu" => "ツ", "te"  => "テ", "to"  => "ト",
    "na"  => "ナ", "ni"  => "ニ", "nu"  => "ヌ", "ne"  => "ネ", "no"  => "ノ",
    "ha"  => "ハ", "hi"  => "ヒ", "hu"  => "フ", "he"  => "ヘ", "ho"  => "ホ", "fu"  => "フ",
    "ma"  => "マ", "mi"  => "ミ", "mu"  => "ム", "me"  => "メ", "mo"  => "モ",
    "ya"  => "ヤ", "yu"  => "ユ", "yo"  => "ヨ", "ye"  => "エ",
    "ra"  => "ラ", "ri"  => "リ", "ru"  => "ル", "re"  => "レ", "ro"  => "ロ",
    "wa"  => "ワ", "wi"  => "ヰ", "we"  => "ヱ", "wo"  => "ヲ",
    "n"   => "ン",
    "m"   => "ン",

    "ga"  => "ガ", "gi"  => "ギ", "gu"  => "グ", "ge"  => "ゲ", "go"  => "ゴ",
    "za"  => "ザ", "ji"  => "ジ", "zu"  => "ズ", "ze"  => "ゼ", "zo"  => "ゾ",
    "da"  => "ダ", "dzi" => "ヂ", "dzu" => "ヅ", "de"  => "デ", "do"  => "ド",
    "ba"  => "バ", "bi"  => "ビ", "bu"  => "ブ", "be"  => "ベ", "bo"  => "ボ",
    "pa"  => "パ", "pi"  => "ピ", "pu"  => "プ", "pe"  => "ペ", "po"  => "ポ",

    "va"  => "ヴァ", "vi"  => "ヴィ", "vu"  => "ヴ",   "ve"  => "ヴェ", "vo"  => "ヴォ",
    "fa"  => "ファ", "fi"  => "フィ", "fe"  => "フェ", "fo"  => "フォ",
    "di"  => "ディ",

    "dje" => "ヂェ", "dze" => "ヂェ",

    "kya" => "キャ", "kyu" => "キュ", "kyo" => "キョ",
    "sha" => "シャ", "shu" => "シュ", "sho" => "ショ",
    "cha" => "チャ", "chu" => "チュ", "cho" => "チョ",
    "nya" => "ニャ", "nyu" => "ニュ", "nyo" => "ニョ",
    "hya" => "ヒャ", "hyu" => "ヒュ", "hyo" => "ヒョ",
    "mya" => "ミャ", "myu" => "ミュ", "myo" => "ミョ",
    "rya" => "リャ", "ryu" => "リュ", "ryo" => "リョ",
    "gya" => "ギャ", "gyu" => "ギュ", "gyo" => "ギョ",
    "ja"  => "ジャ", "ju"  => "ジュ", "jo"  => "ジョ",
    "jya" => "ジャ", "jyu" => "ジュ", "jyo" => "ジョ",
    "dza" => "ヂャ", "dju" => "ヂュ", "dzo" => "ヂョ",
    "dja" => "ヂャ",                  "djo" => "ヂョ",
    "bya" => "ビャ", "byu" => "ビュ", "byo" => "ビョ",
    "pya" => "ピャ", "pyu" => "ピュ", "pyo" => "ピョ",

    "TSU" => "ッ"
);

my(%comn) = (
    "-"   => "ー",
    "."   => "。",
    ","   => "、",
    "!"   => "！",
    "?"   => "？",
    "~"   => "〜",
    "  "  => "　",
    "["   => "〔", "]"   => "〕",
    "{"   => "【", "}"   => "】",
    "("   => "（", ")"   => "）",
    "0"   => "０", "1"   => "１", "2"   => "２", "3"   => "３", "4"   => "４",
    "5"   => "５", "6"   => "６", "7"   => "７", "8"   => "８", "9"   => "９",
    "*"   => "★", # ☆ is uglier :P
    # where to put ♪ ?
);

my(@squot) = ( "「", "」" );
my($squoti) = 0;
my(@dquot) = ( "『", "』" );
my($dquoti) = 0;

sub r2hk ($$) {
    my($str) = "";
    my($pos) = 0;
    my($inlen) = length($_[0]);
    my($last) = "";
    my($href) = $_[1];
    my($inp) = lc($_[0]);

    while ($pos < $inlen) {
	my($len);
	my($p) = substr($inp, $pos, 3);
	my($h) = ${$href}{$p};

	# this could be done with another cycle, but this way's faster i guess
	if ($h) {
	    $len = 3;
	} else {
	    $p = substr($inp, $pos, 2);
	    $h = ${$href}{$p};
	    if ($h) {
		$len = 2;
	    } else {
		$p = substr($inp, $pos, 1);
		$h = ${$href}{$p};
		if (!$h) {
		    if ($p eq "'") {
			$h = $squot[$squoti];
			$squoti = 1 - $squoti;
		    } elsif ($p eq "\"") {
			$h = $dquot[$dquoti];
			$dquoti = 1 - $dquoti;
		    } else {
			$h = $p;
		    }
		}
		$len = 1;
	    }
	}

	if ($h ne $p) {
	    if ($last) {
		if ($last eq substr($p, 0, 1)) {
		    $str .= ${$href}{"TSU"};
		} else {
		    $str .= $last;
		}
		$last = "";
	    }
	} else {
	    $str .= $last;
	    $last = $p;
	    $h = "";
	}

	$str .= $h;
	
	$pos += $len;
    }

    $str .= $last;

    return $str;
}

my($lock_ev) = 0;

sub event1 {
    my ($line, $server, $witem) = @_;

    return unless ref $witem;
    if ($lock_ev) { return };
    $squoti = 0;
    $dquoti = 0;

    my ($str) = "";
    my (@p) = split(//, $line);
    my ($i);
    my ($inside) = 0;
    my ($empty) = 0;

    for ($i = 0; $i <= $#p; $i++) {
	if ($inside) {
	    if (!$p[$i]) {
		$empty++;
	    } else {
		if ($empty == 0) {
		    $str .= r2hk($p[$i], \%hira);
		} else {
		    $str .= r2hk($p[$i], \%kata);
		}
		$empty = 0;
		$inside = 0;
	    }
	} else {
	    $str .= $p[$i];
	    $inside = 1;
	}
    }

    $lock_ev = 1;
    Irssi::signal_emit('send command', $str, $server, $witem);
    Irssi::signal_stop();
    $lock_ev = 0;
}

sub cmd_romaji {
    Irssi::print('%BRomaji (with ひらがな and カタカナ support) version '.$VERSION);
    Irssi::print('(this is amateur product and comes with %Wno warranty%n, see the source)');
    Irssi::print('Text enclosed in Ctrl-Rs (like this) will be converted to hiragana.');
    Irssi::print('If the opening ^R is doubled, it will be converted to katakana.');
    Irssi::print('Example: genki -> げんき and genki -> ゲンキ');
}

Irssi::signal_add('send command', "event1");
Irssi::command_bind('romaji', \&cmd_romaji);

Irssi::print('%B'.$IRSSI{name}.' '.$VERSION.'%n loaded; type /romaji for more info');

# Add the common hash to hiragana and kitakana hashes
my($k, $v);

while (($k, $v) = each %comn) {
    $hira{$k} = $v;
    $kata{$k} = $v;
}
