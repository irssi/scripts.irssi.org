use strict;
use warnings;

our $VERSION = '0.1'; # fca02729ae64034
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'beforespace',
    description => 'Rebind certain keys so that they are inserted before the space',
    license     => 'ISC',
   );

# Usage
# =====
# after loading the script, rebind the desired keys like so:
#
#   /bind , /key_insert_before_space ,
#   /bind : /key_insert_before_space :
#
# don't forget to put the script in autorun otherwise next time you
# cannot type those keys anymore ;-)

use Irssi::TextUI;
use Irssi;

Irssi::command_bind(
    key_insert_before_space => sub {
	my ($data) = @_;
	my $input = Irssi::parse_special('$L');
	my $pos = Irssi::gui_input_get_pos;
	my ($p1, $p2) = ((substr $input, 0, $pos), (substr $input, $pos));
	$p1 =~ s/(\s*)$/$data$1/;
	Irssi::gui_input_set("$p1$p2");
	Irssi::gui_input_set_pos(length $p1);
    });
