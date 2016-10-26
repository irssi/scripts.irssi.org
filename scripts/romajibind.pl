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
$VERSION = "1.0b";
%IRSSI = (
    authors	=> 'Victor Ivanov',
    contact	=> 'v0rbiz@yahoo.com',
    name	=> 'romajibind',
    description	=> 'Dynamic romaji binds',
    license	=> 'BSD 2-clause',
    url		=> 'http://irssi.org/scripts/'
);

# Some help...
# First, this is UTF-8 script.
# Press ctrl-R to switch between Hiragana, Katakana and English input
#
# When the script is loading, it will install the huge amount of
# second-level binds. This takes some time.
#
# When you press ctrl-R it will install some binds, but not the whole
# bunch. Still, it takes noticeable amount of time. If you want
# something faster, try the simple romaji.pl :)
#
# The system is mostly Hepburn, but it could have some kunrei mappings also.
#
# Because of the irssi bind limits, the small tsu is not automatic as in
# the romaji.pl. You need to type it explicitly, using 'tt'.
# Same goes for ん and ン, which are typed with nn or mm.
#
# There is a statusbar item which shows a glyph for the current mapping.
# [英]語 -> [平]仮名 -> [片]仮名
#
# If you want it, type
# /statusbar window add ro1_sb
# (just once, it will remember it)

use Irssi;
use Irssi::TextUI;

# Meow
# These are almost the same as in romaji.pl

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
    "nn"  => "ん",
    "mm"  => "ん",

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

    "tt"  => "っ"
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
    "nn"  => "ン",
    "mm"  => "ン",

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

    "tt"  => "ッ"
);

my(%comm) = (
    "-"   => "ー",
    "."   => "。",
    ","   => "、",
    "!"   => "！",
    "?"   => "？",
    "~"   => "〜",
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

my(%hirab); # Contains DIRECT insert_texts and first-level metas for Hiragana
my(%katab); # Contains DIRECT insert_texts and first-level metas for Katakana
my(%commb); # Common binds
my(%persb); # Persistent binds (don't collide and are all second-level or more)

my($currs) = "英"; # Current state eigo -> hiragana -> katakana

# Builds irssi binds from a hash containing romaji -> utf-8 pairs
# Arguments: sh, dh, pr
#   sh:  Source Hash (%hira, %kata, %comm)
#   dh:  Destination Hash (%hirab or %katab)
#   pr:  Prefix for meta keys (hira or kata)
# The function uses %persb for all non-direct binds
sub build_binds ($$$) {
    my($sh) = $_[0]; # Source hash, %hira or %kata
    my($dh) = $_[1]; # Destination hash, %hirab or %katab
    my($pr) = $_[2]; # The prefix
    my($k, $v);      # for each from the source hash

    while (($k, $v) = each %{$sh}) {
	my($ll) = length($k); # get the length of the KEY
	my($tk, $tv);         # used to take apart the KEY into chars

	if ($ll == 1) { # one-char KEYs are easy
	    ${$dh}{$k} = "insert_text $v";
	} elsif ($ll >= 2) {
	    # take the first and the second chars
	    $tk = substr($k, 0, 1);
	    $tv = substr($k, 1, 1);
	    # if the meta-key is not defined yet, define it now
	    if (!${$dh}{$tk}) {
		${$dh}{$tk} = "key $pr$tk";
	    }
	    # if the KEY is 2-char, define it now
	    if ($ll == 2) {
		$persb{"$pr$tk-$tv"} = "insert_text $v";
	    } else {
		# otherwise register a new meta key, if not yet registered
		if (!$persb{"$pr$tk-$tv"}) {
		    $persb{"$pr$tk-$tv"} = "key $pr$tk$tv";
		}
		# and now register the key...
		$tk .= $tv;
		$tv = substr($k, 2, 1);
		$persb{"$pr$tk-$tv"} = "insert_text $v";
	    }
	}
    }
}

# Applies all binds in a given hash
sub do_binds ($) {
    my($h) = $_[0];
    my($k, $v);

    while (($k, $v) = each %{$h}) {
	Irssi::command("^bind $k $v");
    }
}

# Deletes all binds existing in the given hash
sub del_binds ($) {
    my($h) = $_[0];
    my($k, $v);

    while (($k, $v) = each %{$h}) {
	Irssi::command("^bind -delete $k");
    }
}

# Bindings for hiragana, next Ctrl-R will bind Katakana
sub cmd_rohira {
    Irssi::command("^bind ^R /rokata");
    do_binds \%hirab;
    do_binds \%commb;
    $currs = "平";
    Irssi::statusbar_items_redraw('ro1_sb');
}

# Bindings for Katakana, next Ctrl-R will restore
sub cmd_rokata {
    Irssi::command("^bind ^R /rorest");
    del_binds \%hirab;
    do_binds \%katab;
    # no need to rebind commons from %commb
    $currs = "片";
    Irssi::statusbar_items_redraw('ro1_sb');
}

# Delete bindings (first-level), next Ctrl-R will bind Hiragana
sub cmd_rorest {
    Irssi::command("^bind ^R /rohira");
    del_binds \%katab;
    del_binds \%commb;
    $currs = "英";
    Irssi::statusbar_items_redraw('ro1_sb');
}

# Display the statusbar item
sub ro1_sb_show ($$) {
    my ($item, $get_size_only) = @_;

    $item->{min_size} = $item->{max_size} = 2;
    $item->default_handler($get_size_only, "{sb " . $currs . "}", 0, 1);
}

# Register the /commands
Irssi::command_bind('rohira', 'cmd_rohira');
Irssi::command_bind('rokata', 'cmd_rokata');
Irssi::command_bind('rorest', 'cmd_rorest');

# Register the statusbar item
Irssi::statusbar_item_register('ro1_sb', 0, "ro1_sb_show");
Irssi::statusbar_items_redraw('ro1_sb');

# Bind Ctrl-R to Hiragana (initial position)
Irssi::command("^bind ^R /rohira");

# Build the bind hashes
build_binds \%hira, \%hirab, "hira";
build_binds \%kata, \%katab, "kata";
build_binds \%comm, \%commb, "comm";

# Register persistent binds... SLOWwwwwww :(((
do_binds \%persb;
