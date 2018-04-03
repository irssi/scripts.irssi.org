# Simple script to highlight urls
# To configure the color, the setting 'url_color' can be set. The format
# is like the bash colors. So for instance, if you want to have the links to be
# colored in red, set the color to 31.
# See this page for more information about colors:
# https://misc.flogisoft.com/bash/tip_colors_and_formatting

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

# Dev. info ^_^
$VERSION = "0.2";
%IRSSI = (
	authors     => "Stefan Heinemann",
	contact     => "stefan.heinemann\@codedump.ch",
	name        => "HiliteUrl",
	description => "Simple script that highlights links",
	license     => "GPL",
	url         => "http://senseless.codedump.ch",
);

# All the works
sub hilite_url {
	my ($server, $data, $nick, $mask, $target) = @_;

	my $color = Irssi::settings_get_int('url_color');

	$color = sprintf("\e[%sm", $color);

	# Add Colours
    $data =~ s/(https?:\/\/[^\s]+)/$color\1\e[00m/g;

	# Let it flow
	Irssi::signal_continue($server, $data, $nick, $mask, $target);
}

# Hook me up
Irssi::signal_add('message public', 'hilite_url');

Irssi::settings_add_int(
	'hilite_url', 'url_color', "4;34"
)
