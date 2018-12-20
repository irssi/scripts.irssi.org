use strict;
use warnings;

our $VERSION = '1.1'; # 67ffc4766319fe4
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
my $cmdchars;
my @text;

sub check_input {
    my $inputline = Irssi::parse_special('$L');
    my $c1 = length $inputline > 0 ? substr $inputline, 0, 1 : '';
    my $c2 = length $inputline > 1 ? substr $inputline, 1, 1 : '';
    my $old_state = $cmd_state;
    my $x_state = length $c2 && (-1 != index $cmdchars, $c1) && $c2 ne ' ';
    my $warn_state =
	($inputline =~ /^\s+(\S)/ && (-1 != index $cmdchars, $1))
	|| ($x_state && $inputline =~ /^(.)\1?+\S*[\Q$cmdchars\E]/);
    $cmd_state = $warn_state ? 2 : $x_state ? 1 : 3;
    if ($cmd_state ne $old_state) {
	Irssi::signal_emit('change prompt', $text[ $cmd_state ], 'UP_POST');
    }
}
sub setup_changed {
    $cmdchars = Irssi::settings_get_str('cmdchars');
    @text = ('',
	     Irssi::settings_get_str('cmdind_text'),
	     Irssi::settings_get_str('cmdind_warn_text'),
	     '');
}
Irssi::settings_add_str('cmdind', 'cmdind_text', '%gCmd:');
Irssi::settings_add_str('cmdind', 'cmdind_warn_text', '%RMsg?');
setup_changed();
Irssi::signal_add_last('gui key pressed', 'check_input');
Irssi::signal_add('setup changed', 'setup_changed');
