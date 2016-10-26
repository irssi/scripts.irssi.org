#
# for all who dont like perl:
#   inputlength = "{sb length: $@L}";
#
#  with leading spaces: (3 spaces in example)
#    inputlength = "{sb $[-!3]@L}"; 
#
#  with leading char "-"
#
#    inputlength = "{sb $[-!3-]@L}"; 
#
#   you cant use numbers here. if you want to use the numbers use the 
#   perl script
#
#
# thanks to: Wouter Coekaerts <wouter@coekaerts.be> aka coekie
#
# add one of these 2 lines to your config in statusbar items section
# 
# the perl scripts  reacts on every keypress and updates the counter. 
# if you dont need/want this the settings are maybe enough for you.
# with the settings the item is update with a small delay.
#

use strict;
use Irssi 20021105; 
use Irssi::TextUI;

use vars qw($VERSION %IRSSI);
$VERSION = '0.0.5';
%IRSSI = (
    authors     => 'Marcus Rueckert',
    contact     => 'darix@irssi.org',
    name        => 'inputlength',
    description => 'adds a statusbar item which show length of the inputline',
    license     => 'BSD License or something more liberal',
    url         => 'http://www.irssi.de./',
    changed     => '2003-01-13T13:17:44Z'
);

sub beancounter {
    my ( $sbItem, $get_size_only ) = @_;

    my ( $width, $padChar, $padNum, $length ); 

	#
	# getting settings
	#
    $width = Irssi::settings_get_int ( 'inputlength_width' );
	$padChar = Irssi::settings_get_str ( 'inputlength_padding_char' );

	#
	# only one char allowed
	#
    $padChar =~ s/^(.).*?$/$1/;

	#
	# do we have to deal wit numbers for padding?
    #  
    if ( $padChar =~ m/\d/ ) {
		$padNum = $padChar;
		$padChar = '-';
	};

	#
	# getting formatted lengh
	#
	$length = Irssi::parse_special ( "\$[-!$width$padChar]\@L" );

	#
	# did we have a number?
	#
    $length =~ s/$padChar/$padNum/g if ( $padNum ne '' );

    $sbItem->default_handler ( $get_size_only, "{sb $length}", undef, 1 );
}

Irssi::statusbar_item_register ( 'inputlength', 0, 'beancounter' );
#
# ToDo:
#  - statusbar item register doesnt support function references. 
#    so we have to stuck to the string and wait for cras.
#

Irssi::signal_add_last 'gui key pressed' => sub {
    Irssi::statusbar_items_redraw ( 'inputlength' );
};

Irssi::settings_add_int ( 'inputlength', 'inputlength_width', 0 );
#
# setting:
# 
# 0 means it resizes automatically
# greater means it has at least a size of n chars.
# it will grow if the space is to space is too small
#
 
Irssi::settings_add_str ( 'inputlength', 'inputlength_padding_char', " " );
#
# char to pad with
#
#  you can use any char you like here. :) even numbers should work
#

