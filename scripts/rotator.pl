use Irssi;
use Irssi::TextUI;
use strict;

use vars qw($VERSION %IRSSI);

$VERSION="0.2.1";
%IRSSI = (
	authors=> 'BC-bd',
	contact=> 'bd@bc-bd.org',
	name=> 'rotator',
	description=> 'Displaye a small, changeing statusbar item to show irssi is still running',
	license=> 'GPL v2',
	url=> 'https://bc-bd.org/svn/repos/irssi/trunk/',
);

# rotator Displaye a small, changeing statusbar item to show irssi is still running
# for irssi 0.8.4 by bd@bc-bd.org
#
#########
# USAGE
###
# 
# To use this script type f.e.:
#
#		/statusbar window add -after more -alignment right rotator
#
# For more info on statusbars read the docs for /statusbar
#
#########
# OPTIONS
#########
#
# /set rotator_seperator <char>
# 	The character that is used to split the string in elements.
#
# /set rotator_chars <string>
# 	The string to display. Examples are:
#
# 		/set rotator_chars . o 0 O
# 		/set rotator_chars _ ­ ¯
# 		/set rotator_chars %r­ %Y- %g-
#
# /set rotator_speed <int>
# 	The number of milliseconds to display every char.
# 	1 second = 1000 milliseconds.
#
# /set rotator_bounce <ON|OFF>
#		* ON  : reverse direction at the end of rotator_chars
#		* OFF : start from the beginning
#
###
################
###
# Changelog
#
# Version 0.2.1
#  - checking rotator_speed to be > 10
#
# Version 0.2
#  - added rotator_bounce
#  - added rotator_seperator
#  - added support for elements longer than one char
#  - fixed displaying of special chars (thx to peder for pointing this one out)
#
# Version 0.1
#  - initial release
#
###
################

my ($pos,$char,$timeout,$boundary,$direction);

$char = '';

sub rotatorTimeout {
	my @rot = split(Irssi::settings_get_str('rotator_seperator'), Irssi::settings_get_str('rotator_chars'));
	my $len = scalar @rot;

	$char = quotemeta($rot[$pos]);

	if ($pos == $boundary) {
		if (Irssi::settings_get_bool('rotator_bounce')) {
			if ($direction < 0) {
				$boundary = $len -1;
			} else {
				$boundary = 0;
			}
			$direction *= -1;
		} else {
			$pos = -1;
		}
	}

	$pos += $direction;

	Irssi::statusbar_items_redraw('rotator');
}

sub rotatorStatusbar() {
	my ($item, $get_size_only) = @_;

	$item->default_handler($get_size_only, "{sb ".$char."}", undef, 1);
}

sub rotatorSetup() {
	my $time = Irssi::settings_get_int('rotator_speed');

	Irssi::timeout_remove($timeout);

	$boundary = scalar split(Irssi::settings_get_str('rotator_seperator'), Irssi::settings_get_str('rotator_chars')) -1;
	$direction = +1;
	$pos = 0;

	if ($time < 10) {
		Irssi::print("rotator: rotator_speed must be > 10");
	} else {
		$timeout = Irssi::timeout_add($time, 'rotatorTimeout' , undef);
	}
}

Irssi::signal_add('setup changed', 'rotatorSetup');

Irssi::statusbar_item_register('rotator', '$0', 'rotatorStatusbar');

Irssi::settings_add_str('misc', 'rotator_chars', '. o 0 O 0 o');
Irssi::settings_add_str('misc', 'rotator_seperator', ' ');
Irssi::settings_add_int('misc', 'rotator_speed', 2000);
Irssi::settings_add_bool('misc', 'rotator_bounce', 1);

if (Irssi::settings_get_int('rotator_speed') < 10) {
	Irssi::print("rotator: rotator_speed must be > 10");
} else {
	$timeout = Irssi::timeout_add(Irssi::settings_get_int('rotator_speed'), 'rotatorTimeout' , undef);
}

rotatorSetup();
