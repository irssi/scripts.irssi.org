# /ziew ile
# Grzegorz Jaskiewicz aka giejot 2004
# credits to Smiechu for help

use strict;
use Irssi;
use Irssi qw(command_bind command signal_add_last signal_stop settings_get_bool settings_add_bool);

use vars qw($VERSION %IRSSI);

%IRSSI = (
        authors     => "Grzegorz Jaskiewicz",
        contact     => "gj\@pointblue.com.pl",
        name        => "ziew",
        description => "yawners toy",
        license     => "GPLv2",
        url         => "http://gj.pointblue.com.pl/projects/ziew",
    );

$VERSION = "0.56";
my $iscolor=0;

#rozne wersje jezykowe ziewow

my %ziew = (
	"pl" => [ "zi", "e", "w" ],
	"en" => [ "y", "a", "wn" ],
	"jp" => [ "ak", "u", "bi" ],
	"de" => [ "gä", "h", "nen" ],
	"fr" => [ "bâil", "l", "er" ],
);

## stolen from rainbow.pl

# colors list
#  0 == white
#  4 == light red
#  8 == yellow
#  9 == light green
# 11 == light cyan
# 12 == light blue
# 13 == light magenta
my @colors = ('0', '4', '8', '9', '11', '12', '13');

# str make_colors($string)
# returns random-coloured string
sub make_colors {
	my ($string) = @_;
	my $newstr = "";
	my $last = 255;
	my $color = 0;

	for (my $c = 0; $c < length($string); $c++) {
		my $char = substr($string, $c, 1);
		if ($char eq ' ') {
			$newstr .= $char;
			next;
		}
		while (($color = int(rand(scalar(@colors)))) == $last) {};
		$color = int(rand(scalar(@colors)));
		$last = $color;
		$newstr .= "\003";
		$newstr .= sprintf("%02d", $colors[$color]);
		$newstr .= (($char eq ",") ? ",," : $char);
	}

	return $newstr;
}

sub ziewaj($$) {
    my( $ilosc, $lang ) = @_;
    
    if (!$ziew{ $lang }->[0]) {
	$lang="pl";	
    }

    return $ziew{$lang}->[0].($ziew{$lang}->[1]x$ilosc).$ziew{$lang}->[2]; 

}

sub cmd_yawn {
	my $out;
	my $i;
	my $l;
	my @args = split(/ +/, $_[0]);
	( $i, $l ) = @args;
	
	if ( $i <=0 ) {
	    Irssi::print("ziew.pl: parametrem musi byc dodatnia liczba", MSGLEVEL_CRAP);
	    return;
	}
		
	$out = ziewaj( $i, $l );

	if ( $iscolor) {
	    $out = make_colors( $out );
	}
			
	my $window = Irssi::active_win();
	$window->command( "/say ".$out );
}

sub cmd_ryawn {
	$iscolor=1;
	cmd_yawn(@_);
	$iscolor=0;
}

Irssi::command_bind('yawn', 'cmd_yawn');
Irssi::command_bind('ryawn', 'cmd_ryawn');

Irssi::print("--------------------------------------");
Irssi::print("/yawn En [en|pl|jp|de|fr]");
Irssi::print("En - ilosc  'e' w ziew");
Irssi::print("");
Irssi::print("/ryawn En [en|pl|jp|de|fr]");
Irssi::print("En - ilosc  'e' w ziew, w kolorkach!");
Irssi::print("");
Irssi::print("drugi parametr to jezyk, narazie obsluguje en,jp,de,fr,pl");
Irssi::print("pl jest domyslne");
Irssi::print("");
Irssi::print("wiecej opcji na gwiazdke w przyszlym roku ;)");
Irssi::print("--------------------------------------");
