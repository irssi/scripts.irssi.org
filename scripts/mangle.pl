#!/usr/bin/perl
#
# by Szymon Sokol <szymon@hell.pl>
# ideas taken from BabelIRC by Stefan Tomanek
#

use strict;
use locale;
use utf8;
use Irssi 20020324;
use Irssi::TextUI;
use POSIX;
use Data::Dumper;

use vars qw($VERSION %IRSSI %HELP %channels %translations);
$VERSION = '2019071201';
%IRSSI = (
    authors     => 'Szymon Sokol',
    contact     => 'szymon@hell.pl',
    name        => 'mangle',
    description => 'translates your messages into Morse code, rot13 and other sillinesses.',
    sbitems     => 'mangle_sb',
    license     => 'GPLv2',
    url         => 'http://irssi.org/scripts/',
    changed     => $VERSION,
    modules     => 'Data::Dumper'
);  

# To work, this help requires scripthelp.pl by Maciek 'fahren' Freudenheim
$HELP{"mangle add"} = "/mangle add <translation> [<channel>]
Add a new translation entry for <channel> (default is current channel)";
$HELP{"mangle del"} = "/mangle del [<channel>]
Removes the translation for <channel> (default is current channel)";
$HELP{"mangle say"} = "/mangle say <translation> <message>
Says something to the current channel using given translation";
$HELP{"mangle load"} = "/mangle load 
Loads translations from file";
$HELP{"mangle save"} = "/mangle save 
Saves active translations to file";
$HELP{"mangle show"} = "/mangle show 
Shows active translations";
$HELP{"mangle list"} = "/mangle list 
Lists available translations";

# the endless possibilities for extensions here
%translations = (
  # CChheecckk  yyoouurr  dduupplleexx  sswwiittcchh
  "duplex" => sub { 
    my ($text) = @_;
    $text =~ s/./$&$&/g;
    return $text;
  },
  # TaLk LiKe ThIs - EvErY OtHeR LeTtEr Is UpPeRcAse
  "funky" => sub {
    my ($text) = @_;
    $text =~ s/(\w.)/\u$1/g;
    return $text;
  },
  # TalkLikeThis-NoSpaces,WordBeginsWithUppercase
  "gnome" => sub {
    my ($text) = @_;
    $text =~ s/\b(\w)/\u$1/g;
    $text =~ s/\s+//g;
    return $text;
  },

  # ds mangle by blap - double strike mathematical symbols
  "ds" => sub { 
    my %ds = (
    "A" => "𝔸",
    "B" => "𝔹",
    "C" => "ℂ",
    "D" => "𝔻",
    "E" => "𝔼",
    "F" => "𝔽",
    "G" => "𝔾",
    "H" => "ℍ",
    "I" => "𝕀",
    "J" => "𝕁",
    "K" => "𝕂",
    "L" => "𝕃",
    "M" => "𝕄",
    "N" => "ℕ",
    "O" => "𝕆",
    "P" => "ℙ",
    "Q" => "ℚ",
    "R" => "ℝ",
    "S" => "𝕊",
    "T" => "𝕋",
    "U" => "𝕌",
    "V" => "𝕍",
    "W" => "𝕎",
    "X" => "𝕏",
    "Y" => "𝕐",
    "Z" => "ℤ",
    "a" => "𝕒",
    "b" => "𝕓",
    "c" => "𝕔",
    "d" => "𝕕",
    "e" => "𝕖",
    "f" => "𝕗",
    "g" => "𝕘",
    "h" => "𝕙",
    "i" => "𝕚",
    "j" => "𝕛",
    "k" => "𝕜",
    "l" => "𝕝",
    "m" => "𝕞",
    "n" => "𝕟",
    "o" => "𝕠",
    "p" => "𝕡",
    "q" => "𝕢",
    "r" => "𝕣",
    "s" => "𝕤",
    "t" => "𝕥",
    "u" => "𝕦",
    "v" => "𝕧",
    "w" => "𝕨",
    "x" => "𝕩",
    "y" => "𝕪",
    "z" => "𝕫",
    "0" => "𝟘",
    "1" => "𝟙",
    "2" => "𝟚",
    "3" => "𝟛",
    "4" => "𝟜",
    "5" => "𝟝",
    "6" => "𝟞",
    "7" => "𝟟",
    "8" => "𝟠",
    "9" => "𝟡"
    );
    my ($text) = @_;
    $text =~ s/./defined $ds{$&} ? $ds{$&} : "$&"/eg;
    return $text;
  },

  # curs cursive by blap - cursive (bold) script
  "curs" => sub { 
    my %curs = (
    "A" => "𝓐",
    "B" => "𝓑",
    "C" => "𝓒",
    "D" => "𝓓",
    "E" => "𝓔",
    "F" => "𝓕",
    "G" => "𝓖",
    "H" => "𝓗",
    "I" => "𝓘",
    "J" => "𝓙",
    "K" => "𝓚",
    "L" => "𝓛",
    "M" => "𝓜",
    "N" => "𝓝",
    "O" => "𝓞",
    "P" => "𝓟",
    "Q" => "𝓠",
    "R" => "𝓡",
    "S" => "𝓢",
    "T" => "𝓣",
    "U" => "𝓤",
    "V" => "𝓥",
    "W" => "𝓦",
    "X" => "𝓧",
    "Y" => "𝓨",
    "Z" => "𝓩",
    "a" => "𝓪",
    "b" => "𝓫",
    "c" => "𝓬",
    "d" => "𝓭",
    "e" => "𝓮",
    "f" => "𝓯",
    "g" => "𝓰",
    "h" => "𝓱",
    "i" => "𝓲",
    "j" => "𝓳",
    "k" => "𝓴",
    "l" => "𝓵",
    "m" => "𝓶",
    "n" => "𝓷",
    "o" => "𝓸",
    "p" => "𝓹",
    "q" => "𝓺",
    "r" => "𝓻",
    "s" => "𝓼",
    "t" => "𝓽",
    "u" => "𝓾",
    "v" => "𝓿",
    "w" => "𝔀",
    "x" => "𝔁",
    "y" => "𝔂",
    "z" => "𝔃"
    );
    my ($text) = @_;
    $text =~ s/./defined $curs{$&} ? $curs{$&} : "$&"/eg;
    return $text;
  },

  # vapor double-width by blap - 'vaporwave' script
  "vapor" => sub { 
    my %vapor = (
    " " => "  ",
    "A" => "Ａ",
    "B" => "Ｂ",
    "C" => "Ｃ",
    "D" => "Ｄ",
    "E" => "Ｅ",
    "F" => "Ｆ",
    "G" => "Ｇ",
    "H" => "Ｈ",
    "I" => "Ｉ",
    "J" => "Ｊ",
    "K" => "Ｋ",
    "L" => "Ｌ",
    "M" => "Ｍ",
    "N" => "Ｎ",
    "O" => "Ｏ",
    "P" => "Ｐ",
    "Q" => "Ｑ",
    "R" => "Ｒ",
    "S" => "Ｓ",
    "T" => "Ｔ",
    "U" => "Ｕ",
    "V" => "Ｖ",
    "W" => "Ｗ",
    "X" => "Ｘ",
    "Y" => "Ｙ",
    "Z" => "Ｚ",
    "a" => "ａ",
    "b" => "ｂ",
    "c" => "ｃ",
    "d" => "ｄ",
    "e" => "ｅ",
    "f" => "ｆ",
    "g" => "ｇ",
    "h" => "ｈ",
    "i" => "ｉ",
    "j" => "ｊ",
    "k" => "ｋ",
    "l" => "ｌ",
    "m" => "ｍ",
    "n" => "ｎ",
    "o" => "ｏ",
    "p" => "ｐ",
    "q" => "ｑ",
    "r" => "ｒ",
    "s" => "ｓ",
    "t" => "ｔ",
    "u" => "ｕ",
    "v" => "ｖ",
    "w" => "ｗ",
    "x" => "ｘ",
    "y" => "ｙ",
    "z" => "ｚ",
    "0" => "０",
    "1" => "１",
    "2" => "２",
    "3" => "３",
    "4" => "４",
    "5" => "５",
    "6" => "６",
    "7" => "７",
    "8" => "８",
    "9" => "９",
    '[' => '［',
    ']' => '］',
    '{' => '｛',
    '}' => '｝',
    '(' => '（',
    ')' => '）',
    '.' => '．',
    ',' => '，',
    '?' => '？',
    '!' => '！',
	'"' => chr(65282),
    '\'' => '＇',
    '#' => '＃',
    '$' => '＄',
    '%' => '％',
    '^' => '＾',
    '&' => '＆',
    '=' => '＝',
    '\\' => '＼',
    '/' => '／',
    '`' => '｀'
    );
    my ($text) = @_;
    $text =~ s/./defined $vapor{$&} ? $vapor{$&} : "$&"/eg;
    return $text;
  },

  # blox cypher by blap
  "blox" => sub { 
    my %blox = (
    "a" => "▞",
    "b" => "▍",
    "c" => "▎",
    "d" => "▅",
    "e" => "▃",
    "f" => "▚",
    "g" => "◼",
    "h" => "▇",
    "i" => "▘",
    "j" => "▛",
    "k" => "┫",
    "l" => "▋",
    "m" => "▆",
    "n" => "▝",
    "o" => "▜",
    "p" => "█",
    "q" => "▁",
    "r" => "▄",
    "s" => "▜",
    "t" => "▀",
    "u" => "▌",
    "v" => "▖",
    "w" => "▙",
    "x" => "▂",
    "y" => "▗",
    "z" => "▟",
    "0" => "▊",
    "1" => "▐",
    "2" => "▔",
    "3" => "▒",
    "4" => "▏",
    "5" => "░",
    "6" => "▲",
    "7" => "┣",
    "8" => "▓",
    "9" => "▼"
    );
    my ($text) = @_;
    $text = lc($text);
    $text =~ s/./defined $blox{$&} ? $blox{$&} : "$&"/eg;
    return "╳".$text;
  },

  "morse" => sub { 
    my %morse = (
    " " => "",
    "a" => ".-",
    "b" => "-...",
    "c" => "-.-.",
    "d" => "-..",
    "e" => ".",
    "f" => "..-.",
    "g" => "--.",
    "h" => "....",
    "i" => "..",
    "j" => ".---",
    "k" => "-.-",
    "l" => ".-..",
    "m" => "--",
    "n" => "-.",
    "o" => "---",
    "p" => ".--.",
    "q" => "--.-",
    "r" => ".-.",
    "s" => "...",
    "t" => "-",
    "u" => "..-",
    "v" => "...-",
    "w" => ".--",
    "x" => "-..-",
    "y" => "-.--",
    "z" => "--..",
    # notice: Polish and German diacritical characters have their own 
    # Morse codes; the same probably stands true for other languages
    # using ISO-8859-2 - if you happen to know them, please send me e-mail
    "±" => ".-.-",
    "æ" => "-.-..",
    "ê" => "..-..",
    "³" => ".-..-",
    "ñ" => "--.-",
    "ó" => "---.".
    "¶" => "...-...",
    "¼" => "--..",
    "¿" => "--..-",
    'ä'=>'.-.-',
    'ö'=>'---.',
    'ü'=>'..--',
    "0" => "-----",
    "1" => ".----",
    "2" => "..---",
    "3" => "...--",
    "4" => "....-",
    "5" => ".....",
    "6" => "-....",
    "7" => "--...",
    "8" => "---..",
    "9" => "----.",
    "'" => ".----.",
    '"' => ".-..-.",
    '.' => ".-.-.-",
    ',' => "--..--",
    '?' => "..--..",
    ':' => "---...",
    ';' => "-.-.-.",
    '-' => "-....-",
    '_' => "..--.-",
    '/' => "-..-.",
    '(' => "-.--.",
    ')' => "-.--.-",
    '@' => ".--.-.", #  byFlorian Ernst <florian@uni-hd.de>
    '=' => "-...-"
    );
    my ($text) = @_;
    $text = lc($text);
    $text =~ s/./defined $morse{$&} ? $morse{$&}." " : ""/eg;
    return $text.'[morse]';
  },

  # Fraktur font by blap
  "frakt" => sub { 
    my %HoA = (
    'a' => ["𝖆"],
    'b' => ["𝖇"],
    'c' => ["𝖈"],
    'd' => ["𝖉"],
    'e' => ["𝖊"],
    'f' => ["𝖋"],
    'g' => ["𝖌"],
    'h' => ["𝖍"],
    'i' => ["𝖎"],
    'j' => ["𝖏"],
    'k' => ["𝖐"],
    'l' => ["𝖑"],
    'm' => ["𝖒"],
    'n' => ["𝖓"],
    'o' => ["𝖔"],
    'p' => ["𝖕"],
    'q' => ["𝖖"],
    'r' => ["𝖗"],
    's' => ["𝖘"],
    't' => ["𝖙"],
    'u' => ["𝖚"],
    'v' => ["𝖛"],
    'w' => ["𝖜"],
    'x' => ["𝖝"],
    'y' => ["𝖞"],
    'z' => ["𝖟"],
    'A' => ["𝕬"],
    'B' => ["𝕭"],
    'C' => ["𝕮"],
    'D' => ["𝕯"],
    'E' => ["𝕰"],
    'F' => ["𝕱"],
    'G' => ["𝕲"],
    'H' => ["𝕳"],
    'I' => ["𝕴"],
    'J' => ["𝕵"],
    'K' => ["𝕶"],
    'L' => ["𝕷"],
    'M' => ["𝕸"],
    'N' => ["𝕹"],
    'O' => ["𝕺"],
    'P' => ["𝕻"],
    'Q' => ["𝕼"],
    'R' => ["𝕽"],
    'S' => ["𝕾"],
    'T' => ["𝕿"],
    'U' => ["𝖀"],
    'V' => ["𝖁"],
    'W' => ["𝖂"],
    'X' => ["𝖃"],
    'Y' => ["𝖄"],
    'Z' => ["𝖅"]
    );
    my ($text) = @_;
    $text =~ s/./defined $HoA{$&} ? $HoA{$&}[rand(@{$HoA{$&}})] : "$&"/eg;
    return $text;
  },

  # Unicode Obfusticator by blap
  "obfus" => sub { 
    my %HoA = (
    '0' => ["Ө","Ὀ","Ồ","Ổ","Θ","Ǒ","Ȏ","ϴ","Ò","Õ","Ô","Ǿ"],
    '1' => ["Ĭ","Ἰ","Ī","Ӏ","Ί","Ι","І","Ї","Ῐ","Ῑ","Ὶ"],
    '2' => ["ƻ","ƨ"],
    '3' => ["Ʒ","Ӡ","Ҙ","ҙ","Ӟ","з","Յ","З","ɝ"],
    '4' => ["Ч"],
    '5' => ["Ƽ"],
    '6' => ["ǝ","ə"],
    '7' => ["7"],
    '8' => ["Ց"],
    '9' => ["9"],
    'a' => ["ἅ","ἁ","ẚ","ӓ","ά","ᾷ","ᾶ","ᾱ","ǎ","ǟ","ά","ɑ"],
    'b' => ["ƃ","ƅ","þ","ḃ","ḅ","ḇ","ϸ","ɓ"],
    'c' => ["ċ","ć","ƈ","ⅽ","ϛ","ç","ς","ϲ"],
    'd' => ["ƌ","ḑ","ⅾ","ḋ","ḍ","ḏ","ժ","ɗ","ɖ"],
    'e' => ["ё","ė","ệ","ѳ","ḕ","ḝ","è","ê","ϱ","ȩ","ε"],
    'f' => ["ғ","ƒ","ſ","ẛ","ϝ","ḟ"],
    'g' => ["ğ","ģ","ɡ","ǥ","ǧ","ց","գ","ǵ","ḡ","ɕ"],
    'h' => ["ĥ","һ","ẖ","ɧ","ɦ","ի","ḩ","ḫ","հ"],
    'i' => ["ĩ","ī","ἲ","ɩ","¡","í","ì","ΐ","ί","ι","ḭ"],
    'j' => ["ј","ĵ","ʝ","ȷ","ǰ","յ"],
    'k' => ["ҝ","ƙ","ĸ","ķ","к","ḱ","ḳ","κ"],
    'l' => ["ł","ŀ","ƚ","ľ","ĺ","ɫ","ǀ","ɭ","ɬ","ḻ","ḽ"],
    'm' => ["₥","ṃ","ṁ","ɱ","ḿ"],
    'n' => ["ƞ","ἤ","ṅ","ή","ñ","ɴ","ᾗ","ᾕ","ᾔ","ῇ","ռ","ղ"],
    'o' => ["ớ","ở","ὁ","ŏ","ō","ơ","ὸ","ό","ó","ò","ʘ","ȫ"],
    'p' => ["р","ҏ","ṗ","ṕ","ῤ","ῥ","þ","թ"],
    'q' => ["ԛ","ʠ","զ","գ"],
    'r' => ["ŗ","ŕ","ѓ","ӷ","г","ȑ","ɽ","ɼ"],
    's' => ["ş","ś","ṧ","ṣ","ԑ","š","ʂ"],
    't' => ["†","ṫ","ť","ț","Ւ","ȶ","ʈ"],
    'u' => ["ư","ṻ","ṳ","ů","ū","ụ","ủ","ù","µ","ǜ","ǚ"],
    'v' => ["ṿ","ὐ","ὗ","ὔ","ύ","ѵ","ү","ῠ","ῢ","ⅴ","ΰ"],
    'w' => ["ԝ","ẉ","ẃ","ẁ","ŵ","ẇ","ẅ"],
    'x' => ["ẋ","ҳ","ẍ","ϰ"],
    'y' => ["у","ƴ","ӯ","ў","ỹ","ỵ","ỷ","ẙ","ÿ"],
    'z' => ["ƶ","ž","ż","ź","ẓ","ẑ","ʑ"],
    'A' => ["Ẩ","Ậ","Ą","Ἆ","Ӑ","Ά","Ᾱ","Α","Ⱥ","Ã","ᾉ","ᾈ"],
    'B' => ["Ɓ","Ḃ","Ḅ","Β","В"],
    'C' => ["Č","Ĉ","Ć","₵","Ҫ","Ͼ","Ç"],
    'D' => ["Đ","Ɗ","Ɖ","Ḓ","Ḋ","Ḍ","Ḏ","Ð"],
    'E' => ["Ẹ","Ę","Ẽ","Ĕ","Ệ","Ɛ","Ԑ","Ḗ","Ḝ","Ὲ","Ȩ"],
    'F' => ["Ғ","Ƒ","₣","ϝ","Ϝ"],
    'G' => ["Ĝ","Ğ","Ġ","Ģ","Ǥ","Ḡ","Ǵ"],
    'H' => ["Ĥ","Ӈ","Ҥ","Ң","Ȟ","Н","Ḥ","Ḫ"],
    'I' => ["Ỉ","Ἱ","Ī","İ","Ȉ","Ȋ","Ι","Í","Ḭ","Ὶ","Ḯ"],
    'J' => ["Ĵ","ʆ","Ј"],
    'K' => ["₭","Ƙ","Ķ","Κ","Ḱ","Ḳ","Ḵ","К","Ќ"],
    'L' => ["Ł","Ľ","Ⅼ","Ḷ","Ḹ","Ḻ","ℒ"],
    'M' => ["Ӎ","Ṃ","Ṁ","Μ","М","Ḿ"],
    'N' => ["Ň","Ņ","Ń","₦","Ṋ","Ṉ","Ñ","Ǹ"],
    'O' => ["Ӫ","Ờ","Ổ","Ọ","Θ","Ø","Ò","Õ","Ȭ","Ȯ"],
    'P' => ["Ƥ","Ҏ","Ṗ","Ṕ","₱","Ῥ","Ρ"],
    'Q' => ["Ԛ"],
    'R' => ["Ř","Ŗ","Ŕ","Ṟ","Ṙ","Ȑ"],
    'S' => ["ϟ","Ş","Ŝ","Ṡ","Š","Ș","Տ"],
    'T' => ["Ṱ","Ṯ","Ṫ","Ʈ","Ŧ","Ţ","Т","Τ","Ί"],
    'U' => ["Ự","Ų","Ứ","Ử","Ũ","Ȕ","Ȗ","Ǖ","Ǘ","Ǜ","Û","Ú"],
    'V' => ["Ṿ","Ṽ","Ѷ","⋁","Ⅴ"],
    'W' => ["Ԝ","Ẉ","Ẃ","Ẁ","Ŵ","Ẇ","Ẅ"],
    'X' => ["Ẋ","Ҳ","Ẍ","Х","Χ"],
    'Y' => ["Ỹ","Ẏ","Ұ","Ÿ","Ỳ","Ỵ","¥","ϓ","Ȳ","Υ"],
    'Z' => ["Ž","Ż","Ź","Ẓ","Ζ","Ȥ"],
    );
    my ($text) = @_;
    $text =~ s/./defined $HoA{$&} ? $HoA{$&}[rand(@{$HoA{$&}})] : "$&"/eg;
    return $text;
  },

  # convert text in Polish from ISO-8859-2 to 7-bit approximation
  # if you know how to do it for other languages using 8859-2, 
  # please let me know
  "polskawe" => sub {
    my ($text) = @_;
    $text =~ y/¡ÆÊ£ÑÓ¦¯¬±æê³ñó¶¿¼/ACELNOSZZacelnoszz/;
    return $text;
  },
  # Ouch, my eyes!
  "rainbow" => sub {
    my ($text) = @_;
    # colors list
    #  0 == white
    #  4 == light red
    #  8 == yellow
    #  9 == light green
    # 11 == light cyan
    # 12 == light blue
    # 13 == light magenta
    my @colors = ('00','04','08','09','11','12','13');
    my $color;
    $text = join '', map { push @colors, $color = shift @colors;
"\003" . $color . ($_ eq "," ? ",," : $_) } split(//,$text);
    return $text;
  },
  # .drawkcab klaT
  "reverse" => sub {
    my ($text) = @_;
    $text = scalar reverse $text;
    return $text;
  },
  # Gnyx va ebg13 rapbqvat.
  "rot13" => sub {
    my ($text) = @_;
    $text =~ y/N-ZA-Mn-za-m/A-Za-z/;
    return $text.' [rot13]';
  },
  # T-T-Talk l-l-like y-y-you h-h-have a s-s-stutter.
  "stutter" => sub {
    my ($text) = @_;
    $text =~ s/(\w)(\w+)/$1-$1-$1$2/g;
    return $text;
  },
  # rmv vwls
  "vowels" => sub {
    my ($text) = @_;
    $text =~ y/aeiouy±ê//d;
    return $text;
  }
);

sub add_channel ($$) {
    my ($channel,$code) = @_;
    $channels{$channel} = $code;
}

sub save_channels {
    my $filename = Irssi::settings_get_str('mangle_filename');
	my $fo;
    open $fo, '>',$filename;
    my $data = Dumper(\%channels);
    print $fo $data;
    close $fo;
    print CLIENTCRAP "%R>>%n Mangle channels saved";
}

sub load_channels {
    my $filename = Irssi::settings_get_str('mangle_filename');
    return unless (-e $filename);
    my $fi;
    open $fi, '<',$filename;
    my $text;
    $text .= $_ foreach <$fi>;
    #no strict "vars";
    my $VAR1;
    eval "$text";
    %channels = %$VAR1;
}

sub mangle_show ($$) {
    my ($item, $get_size_only) = @_;
    my $win = !Irssi::active_win() ? undef : Irssi::active_win()->{active};
    if (ref $win && ($win->{type} eq "CHANNEL" || $win->{type} eq "QUERY") && $channels{$win->{name}}) {
        my $code = $channels{$win->{name}};
	$item->{min_size} = $item->{max_size} = length($code);
	$code = '%U%g'.$code.'%U%n';
	my $format = "{sb ".$code."}";
	$item->default_handler($get_size_only, $format, 0, 1);
    } else {
	$item->{min_size} = $item->{max_size} = 0;
    }
}
sub cmd_mangle ($$$) {
    my ($args, $server, $witem) = @_;
    my @arg = split(/ +/, $args);
    if ($arg[0] eq 'add' && defined $arg[1]) {
      my $code = $arg[1];
      if(exists $translations{$code}) {
        if (defined $arg[2]) { 
    	  add_channel($arg[2], $code);
        }
        elsif($witem) {
	  add_channel($witem->{name}, $code);
	}
      } else {
        Irssi::print("There is no such translation as $code !");
      }
    } elsif ($arg[0] eq 'del') {
        if(defined $arg[1]) {
	  delete $channels{$arg[1]} if defined $channels{$arg[1]};
	} elsif($witem) {
	  delete $channels{$witem->{name}} if defined $channels{$witem->{name}};
	}
    } elsif ($arg[0] eq 'say' && defined $arg[1]) {
      my $code = $arg[1];
      if(exists $translations{$code}) {
        if($witem) {
	  say($code, join(' ',@arg[2..$#arg]), $server, $witem);
	}
      } else {
        Irssi::print("There is no such translation as $code !");
      }
    } elsif ($arg[0] eq 'save') {
	save_channels();
    } elsif ($arg[0] eq 'load') {
	load_channels();
    } elsif ($arg[0] eq 'list') {
	Irssi::print("mangle: available translations are: ".
	join(" ", sort keys %translations));
    } elsif ($arg[0] eq 'show') {
        for (sort keys %channels) {
	  Irssi::print("mangle: ".$_." set to ".$channels{$_});
	}
    } else {
      Irssi::print("mangle v. $VERSION; use /help mangle for help (ensure you have scripthelp.pl loaded!)");
    }
    Irssi::statusbar_items_redraw('mangle_sb');
}

sub say ($$$$) {
    my ($code, $line, $server, $witem) = @_;
    my $target = "";
    if ($line =~ s/^(\w+?: )//) {
      $target = $1;
    }
    $line = $translations{$code}->($line);
    $server->command('MSG '.$witem->{name}.' '.$target.$line);
}

sub event_send_text ($$$) {
    my ($line, $server, $witem) = @_;
    return unless ($witem && 
                  ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY") && 
                  $channels{$witem->{name}});
    say($channels{$witem->{name}}, $line, $server, $witem);
    Irssi::signal_stop();
    Irssi::statusbar_items_redraw('mangle_sb');
}

# main

Irssi::command_bind('mangle', \&cmd_mangle);
foreach my $cmd ('add', 'del', 'save', 'load', 'say', 'list', 'show') {
    Irssi::command_bind('mangle '.$cmd => sub {
		    cmd_mangle($cmd." ".$_[0], $_[1], $_[2]); });
}

Irssi::statusbar_item_register('mangle_sb', 0, "mangle_show");
Irssi::signal_add('setup saved', 'save_channels');
Irssi::signal_add('send text', \&event_send_text);
Irssi::signal_add('window changed', sub {Irssi::statusbar_items_redraw('mangle_sb');});

Irssi::settings_add_str($IRSSI{name}, 'mangle_filename', Irssi::get_irssi_dir()."/mangle_channels");
load_channels();
print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /help mangle for help';

# ;-)
