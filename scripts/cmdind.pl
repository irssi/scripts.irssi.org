use strict;
use warnings;

our $VERSION = '1.0'; # cd71e7f6cb97775
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'cmdind',
    description => 'Indicator for input prompt if you are inputting a command or text',
    license     => 'GNU GPLv2 or later',
   );

# Usage
# =====
# This script requires the
#
#  uberprompt
#
# script to work. If you don't have it yet, /script install uberprompt

# Options
# =======
# /set cmdind_text <string>
# * string : Text to show in prompt when typing a command
#
# /set cmdind_warn_text <string>
# * string : Text to show in prompt when typing a command with spaces in front

use Irssi;

my $cmd_state = 0;
my ($cmdind_text, $cmdind_warn_text);
my $cmdchars;

sub check_input {
    my $inputline = Irssi::parse_special('$L');
    my $c1 = length $inputline > 0 ? substr $inputline, 0, 1 : '';
    my $c2 = length $inputline > 1 ? substr $inputline, 1, 1 : '';
    my $old_state = $cmd_state;
    my $x_state = length $c1 && (-1 != index $cmdchars, $c1) && $c2 ne ' ';
    my $warn_state = !$x_state &&
	$inputline =~ /^\s+(\S)/ && (-1 != index $cmdchars, $1);
    $cmd_state = $x_state ? 1 : $warn_state ? 2 : 3;
    if ($cmd_state ne $old_state) {
	Irssi::signal_emit('change prompt',
			   $x_state ? $cmdind_text : $warn_state ? $cmdind_warn_text : '', 'UP_POST');
    }
}
sub setup_changed {
    $cmdchars = Irssi::settings_get_str('cmdchars');
    $cmdind_text = Irssi::settings_get_str('cmdind_text');
    $cmdind_warn_text = Irssi::settings_get_str('cmdind_warn_text');
}
Irssi::settings_add_str('cmdind', 'cmdind_text', '%gCmd:');
Irssi::settings_add_str('cmdind', 'cmdind_warn_text', '%RMsg?');
setup_changed();
Irssi::signal_add_last('gui key pressed', 'check_input');
Irssi::signal_add('setup changed', 'setup_changed');
