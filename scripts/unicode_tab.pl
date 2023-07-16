use strict;
use warnings FATAL => qw(all);

use Irssi;

our $VERSION = 1;

our %IRSSI = (
	authors => qw(aquanight),
	name => 'unicode_tab',
	description =>
		q/Provides the ability to type in unicode characters via their codepoint, by typing U+XXX and pressing tab./,
	license => 'public domain',
);

sub sig_complete_word
{
	my ($result, $window, $word, $linestart, $want_space) = @_;

	# Irssi's unicode is UTF-8
	my $realword = $word;
	utf8::decode($realword);

	# Capture the code point, less any leading 0
	if ($realword =~ m/[uU]\+0*([[:xdigit:]]{1,8})$/)
	{
		my $cp = hex($1);
		if ($cp > Irssi::settings_get_int('max_codepoint'))
		{
			# Not a valid code-point.
			$window->print(sprintf("Code point out of range: %04X", $cp));
			return;
		}
		# Do not encode surrogate pair, byte-order mark, or illegal unicode character (FFFE and FFFF)
		if (($cp & 0xF800) == 0xD800 || $cp == 0xFEFF || $cp == 0xFFFE || $cp == 0xFFFF)
		{
			$window->print(sprintf("Illegal code point: %04X", $cp));
			return;
		}
		my $chr = chr($cp);
		utf8::encode($chr);
		push @$result, (substr($word, 0, $-[0]) . $chr);
		$$want_space = 0;
	}
}

Irssi::signal_add("complete word", \&sig_complete_word);
Irssi::settings_add_int('unicode_tab', 'max_codepoint', 0x10FFFF);
