use strict;
use vars qw($VERSION %IRSSI);
use Irssi;

$VERSION = '1.0';

%IRSSI = (
	authors			=> "stryk",
	contact			=> '$IRSSI{authors} + <Shift-2> + protonmail + <rhymes-with-pot> + <2-char Country Code for Switzerland>',
	name			=> "ez_color",
	description		=> "Provides a single helper function to wrap mIRC-style color codes around strings",
	license			=> 'WTFPL/2 @ http://www.wtfpl.net/about/',
	changed			=> '2020-09-10',
	);

####################
#### You can call this helper function from other scripts,
#### ***AS LONG AS ez_color.pl IS LOADED IN IRSSI***
####################
# USAGE:
# Irssi::Script::ez_color::colorize(@args)
# ---------
# or, better yet, with a coderef: my $var = \&Irssi::Script::ez_color::colorize;
# and then call with: $var->(@args);
##################
# EXAMPLE:
# Irssi::active_win->command( "say ".Irssi::Script::ez_color::colorize('COLOR THIS TEXT', 'white', 'red') );
# ---------
# or, with the above coderef $var:
# Irssi::active_win->command( "say ".$var->('COLOR THIS TEXT', 'white', 'red') );
##################
# ARGUMENTS:           (all color names are case-INsensitive)
# [string-to-colorize], [foreground-color], [background-color(OPTIONAL)] 
# >>> arg #2 may, instead of a color-name, be one of: [normal, bold, underline, reverse, italic]
##################
# Be aware that most terminal emulators don't play well with ITALIC, results may not be what you expect.
# Feel free to change the colormap names, add more aliases, or whatever -- be wary of altering 'C' however.



sub colorize {
	my($str_in, $fgcol, $bgcol) = @_;
	my $ret_str;

	my %_C = (

		C			=> "\x{03}",

		NORMAL      => "\x{0f}",

		BOLD        => "\x{02}",
		UNDERLINE   => "\x{1f}",
		UL			=> "\x{1f}",
		REVERSE     => "\x{16}",
		REV			=> "\x{16}",
		ITALIC      => "\x{1d}",


		WHITE       => "00",
		BLACK       => "01",
		BLUE        => "02",
		GREEN       => "03",
		RED         => "04",
		BROWN       => "05",
		PURPLE      => "06",
		ORANGE      => "07",
		YELLOW      => "08",
		TEAL        => "10",
		PINK        => "13",
		GREY        => "14",
		GRAY        => "14",

		LIGHT_BLUE  => "12",
		CYAN        => "11",
		LIGHT_GREEN => "09",
		LIGHT_GRAY  => "15",
		LIGHT_GREY  => "15",
	);

	$fgcol = uc($fgcol || 'normal');

	if ($fgcol =~ m/(?:bold|underline|ul|rev(?:erse)?|italic|normal)/i) {
		$ret_str = join('', $_C{$fgcol}, $str_in, $_C{NORMAL});
		return $ret_str;
	};


	my $_colcode = $_C{$fgcol};

	unless (defined($_colcode)){
		Irssi::print("BAD COLOR NAME PASSED TO colorize FUNCTION", MSGLEVEL_CLIENTCRAP);
		return $str_in;
	};


	if (defined($bgcol)){
		$bgcol = uc($bgcol);
		$_colcode .= ",".$_C{$bgcol} if exists $_C{$bgcol};
	};


	$ret_str = join('', $_C{C}, $_colcode, $str_in, $_C{NORMAL});
	return $ret_str;
};
