#!/usr/bin/perl
#
# by Szymon Sokol <szymon@hell.pl>
# ideas taken from BabelIRC by Stefan Tomanek
#

use strict;
use locale;
use Irssi 20020324;
use POSIX;
use Data::Dumper;

use vars qw($VERSION %IRSSI %HELP %channels %translations);
$VERSION = '2004031701';
%IRSSI = (
    authors     => 'Szymon Sokol',
    contact     => 'szymon@hell.pl',
    name        => 'mangle',
    description => 'translates your messages into Morse code, rot13 and other sillinesses.',
    license     => 'GPLv2',
    url         => 'http://irssi.org/scripts/',                                     changed     => $VERSION,
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
  # -- --- .-. ... .  -.-. --- -.. .
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
    local *F;
    open F, '>'.$filename;
    my $data = Dumper(\%channels);
    print F $data;
    close F;
    print CLIENTCRAP "%R>>%n Mangle channels saved";
}

sub load_channels {
    my $filename = Irssi::settings_get_str('mangle_filename');
    return unless (-e $filename);
    local *F;
    open F, '<'.$filename;
    my $text;
    $text .= $_ foreach <F>;
    no strict "vars";
    %channels = %{ eval "$text" };
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
