use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "2004021901";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "morse",
    description => "turns your messages into morse or spelling code",
    license     => "GPLv2",
    changed     => "$VERSION",
    commands	=> "morse spell"
);

use Irssi 20020324;

use vars qw(%codes %spell);

%codes = (
	A=>".-",
	B=>"-...",
	C=>"-.-.",
	D=>"-..",
	E=>".",
	F=>"..-.",
	G=>"--.",
	H=>"....",
	I=>"..",
	J=>".---",
	K=>"-.-",
	L=>".-..",
	M=>"--",
	N=>"-.",
	O=>"---",
	P=>".--.",
	Q=>"--.-",
	R=>".-.",
	S=>"...",
	T=>"-",
	U=>"..-",
	V=>"...-",
	W=>".--",
	X=>"-..-",
	Y=>"-.--",
	Z=>"--..",
	0=>"-----",
	1=>".----",
	2=>"..---",
	3=>"...--",
	4=>"....-",
	5=>".....",
	6=>"-....",
	7=>"--...",
	8=>"---..",
	9=>"----.",
	' '=>" ",
	'.'=>".-.-.-",
	','=>"--..--",
	'?'=>"..--..",
	':'=>"---...",
	';'=>"-.-.-.",
	'-'=>"-....-",
	'_'=>"..--.-",
	'"'=>".-..-.",
	"'"=>".----.",
	'/'=>"-..-.",
        '('=>"-.--.",
        ')'=>"-.--.-",
	'='=>"-...-",
	'Ä'=>'.-.-',
	'Ö'=>'---.',
	'Ü'=>'..--',
	'@'=>'.--.-.'
);
my %spell = (
	'intern.' => {
    			'A' => 'Amsterdam',
    			'B' => 'Baltimore',
                        'C' => 'Casablanca',
                        'D' => 'Danemark',
                        'E' => 'Edison',
                        'F' => 'Florida',
                        'G' => 'Gallipoli',
                        'H' => 'Havana',
                        'I' => 'Italia',
                        'J' => 'Jérusalem',
                        'K' => 'Kilogramme',
                        'L' => 'Liverpool',
                        'M' => 'Madagaskar',
                        'N' => 'New York',
                        'O' => 'Oslo',
                        'P' => 'Paris',
                        'Q' => 'Québec',
                        'R' => 'Roma',
                        'S' => 'Santiago',
                        'T' => 'Tripoli',
                        'U' => 'Upsala',
                        'V' => 'Valencia',
                        'W' => 'Washington',
                        'X' => 'Xanthippe',
                        'Y' => 'Yokohama',
                        'Z' => 'Zürich'
                      },
	    'GB' => {
			'A' => 'Andrew',
	    		'B' => 'Benjamin',
			'C' => 'Charlie',
		    	'D' => 'David',
			'E' => 'Edward',
			'F' => 'Frederick',
			'G' => 'George',
			'H' => 'Harry',
			'I' => 'Isaac',
			'J' => 'Jack',
			'K' => 'King',
			'L' => 'Lucy',
			'M' => 'Mary',
			'N' => 'Nellie',
			'O' => 'Oliver',
			'P' => 'Peter',
			'Q' => 'Queenie',
			'R' => 'Robert',
			'S' => 'Sugar',
			'T' => 'Tommy',
			'U' => 'Uncle',
			'V' => 'Victor',
			'W' => 'William',
			'X' => 'Xmas',
			'Y' => 'Yellow',
			'Z' => 'Zebra'
		    },
	    'USA' => {
			'A' => 'Abel',
			'B' => 'Baker',
			'C' => 'Charlie',
			'D' => 'Dog',
			'E' => 'Easy',
			'F' => 'Fox',
			'G' => 'George',
			'H' => 'How',
			'I' => 'Item',
			'J' => 'Jig',
			'K' => 'King',
			'L' => 'Love',
			'M' => 'Mike',
			'N' => 'Nan',
			'O' => 'Oboe',
			'P' => 'Peter',
			'Q' => 'Queen',
			'R' => 'Roger',
			'S' => 'Sugar',
			'T' => 'Tare',
			'U' => 'Uncle',
			'V' => 'Victor',
			'W' => 'William',
			'X' => 'X',
			'Y' => 'Yoke',
			'Z' => 'Zebra'
			},
	    'ICAO' => {
			'A' => 'Alfa',
			'B' => 'Bravo',
			'C' => 'Charlie',
			'D' => 'Delta',
			'E' => 'Echo',
			'F' => 'Foxtrot',
			'G' => 'Golf',
			'H' => 'Hotel',
			'I' => 'India',
			'J' => 'Juliett',
			'K' => 'Kilo',
			'L' => 'Lima',
			'M' => 'Mike',
			'N' => 'November',
			'O' => 'Oscar',
			'P' => 'Papa',
			'Q' => 'Quebec',
			'R' => 'Romeo',
			'S' => 'Sierra',
			'T' => 'Tango',
			'U' => 'Uniform',
			'V' => 'Victor',
			'W' => 'Whiskey',
			'X' => 'X-Ray',
			'Y' => 'Yankee',
			'Z' => 'Zulu'
			},
	    'D' => {
     			'A' => 'Anton',
	  		'B' => 'Berta',
	       		'C' => 'Cäsar',
		    	'D' => 'Dora',
			'E' => 'Emil',
			'F' => 'Friedrich',
			'G' => 'Gustav',
			'H' => 'Heinrich',
			'I' => 'Ida',
			'J' => 'Julius',
			'K' => 'Kaufmann',
			'L' => 'Ludwig',
			'M' => 'Martha',
			'N' => 'Nordpol',
			'O' => 'Otto',
			'P' => 'Paula',
			'Q' => 'Quelle',
			'R' => 'Richard',
			'S' => 'Samuel',
			'T' => 'Theodor',
			'U' => 'Ulrich',
			'V' => 'Viktor',
			'W' => 'Wilhelm',
			'X' => 'Xanthippe',
			'Y' => 'Ypsilon',
			'Z' => 'Zacharias'
		    }
);

sub text2morse ($) {
    my ($text) = @_;
    my $result;
    my %deumlaut = ('ä' => 'Ä',
		    'ö' => 'Ö',
		    'ü' => 'Ü',
		    'ß' => 'ss'
		   );
    $text =~ s/$_/$deumlaut{$_}/ foreach keys %deumlaut;
    foreach (split(//, $text)) {
	if (defined $codes{uc $_}) {
	    $result .= $codes{uc $_}." ";
	} elsif (Irssi::settings_get_bool('morse_kill_unknown_characters')) {
	    $result .= " ";
	} else {
	    $result .= $_." ";
	}
    }
    return $result;
}

sub morse2text ($) {
    my ($morse) = @_;
    my (%table, $result);
    $table{$codes{$_}} = $_ foreach keys %codes;
    foreach (split(/ /, $morse)) {
	if (defined $table{$_}) {
	    $result .= $table{$_};
	} else {
	    $result .= $_." ";
	}
    }
    $result =~ s/ +/ /g;
    return $result;
}

sub morse_decode ($$$) {
    my ($server, $target, $text) = @_;
    return unless ($text =~ /(^|.*? )([\.\-]+ [\.\- ]+)($| .*)/g);
    my $witem = $server->window_item_find($target);

    return unless ($witem);
    $witem->print("%B[morse]>>%n ".$1."%U".morse2text($2)."%U ".$3, MSGLEVEL_CLIENTCRAP);
}

sub spell_decode ($$$) {
    my ($server, $target, $text) = @_;
    my $codes;
    foreach my $type (keys %spell) {
        $codes .= $spell{$type}{$_}.'|' foreach keys %{ $spell{$type} };
    }
    $codes =~ s/\|$//;
    return unless ($text =~ /^($codes| |[\:\,\.\-\?\!\(\)])+$/);
    return unless ($text =~ /($codes)/);
    my $witem = $server->window_item_find($target);
    return unless ($witem);
    $witem->print("%B[spell]>>%n ".despell($text), MSGLEVEL_CLIENTCRAP);
}

sub despell ($) {
    my ($input) = @_;
    my %data;
    foreach my $type (keys %spell) {
	$data{ $spell{$type}{$_} } = $_ foreach keys %{ $spell{$type} };
    }
    my $output;
    foreach (split / /, $input) {
	if (defined $data{$_}) {
	    $output .= $data{$_};
	} else {
	    $output .= $_." ";
	}
    }
    return $output;
}

sub cmd_morse ($$$) {
    my ($arg, $server, $witem) = @_;
    if ($witem && ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY')) {
	$witem->command('MSG '.$witem->{name}.' '.text2morse($arg));
    } else {
	print CLIENTCRAP "%B>>%n ".text2morse($arg);
    }
}

sub cmd_spell ($$$) {
    my ($args, $server, $witem) = @_;
    my $type = Irssi::settings_get_str('morse_spelling_alphabet');
    return unless defined $spell{$type};
    my $encode;
    foreach (split(//, $args)) {
	if (defined $spell{$type}{uc $_}) {
	    $encode .= $spell{$type}{uc $_}." ";
	} else {
	    $encode .= $_;
	}
    }
    if ($witem && ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY')) {
        $witem->command('MSG '.$witem->{name}.' '.$encode);
    } else {
        print CLIENTCRAP "%B>>%n ".$encode;
    }

}

sub cmd_despell ($$$) {
    my ($args, $server, $witem) = @_;
    print CLIENTCRAP "%B>>%n ".despell($args);
}

sub cmd_demorse ($$$) {
    my ($arg, $server, $witem) = @_;
    print CLIENTCRAP "%B>>%n ".morse2text($arg);
}

Irssi::command_bind('morse', \&cmd_morse);
Irssi::command_bind('spell', \&cmd_spell);
Irssi::command_bind('despell', \&cmd_despell);
Irssi::command_bind('demorse', \&cmd_demorse);

Irssi::settings_add_bool($IRSSI{name}, 'morse_kill_unknown_characters', 0);
Irssi::settings_add_str($IRSSI{name}, 'morse_spelling_alphabet', "ICAO");

Irssi::signal_add('message public', sub { morse_decode($_[0], $_[4], $_[1]); });
Irssi::signal_add('message own_public', sub { morse_decode($_[0], $_[2], $_[1]); });

Irssi::signal_add('message public', sub { spell_decode($_[0], $_[4], $_[1]); });
Irssi::signal_add('message own_public', sub { spell_decode($_[0], $_[2], $_[1]); });
print "%B>>%n ".$IRSSI{name}." ".$VERSION." loaded";

