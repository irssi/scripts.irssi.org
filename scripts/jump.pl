use strict;
use warnings;
use Irssi;

our $VERSION = '1.1'; # 48b3e25efb559bd
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'jump',
    description => 'Adds a command to navigate to the previously active windows and an optional shortcut to go back when you try to switch to the current window. Think /window last²',
    license     => 'ISC',
   );


# Usage
# =====
# The best way in my opinion is to make some key bindings for cycling
# through your windows in recently used order:
#
# /bind meta-> command window nexth
# /bind meta-< command window prevh
#
#
# If you want to to go to the last window when you try to switch to
# the current window with some Alt+# key, turn this setting on:
#
# /set change_window_jump ON/OFF
#

our ($i, $j, $v, $w) = (-1, -1, 'w', 'v');

sub num_list {
    join ',', map { $_->{refnum} } @_
}

sub window_last_history {
    my ($index, $last) = @_;
    my @windows = Irssi::windows;
    my $current = num_list(@windows);
    $$index = 0 unless $current eq $$last;
    $windows[++$$index % @windows]->set_active;
    $$last = num_list(Irssi::windows);
}

sub sig_key_change_window {
    if (Irssi::settings_get_bool('change_window_jump')
	&& $_[0] eq Irssi::active_win->{refnum}) {
	Irssi::signal_stop;
	Irssi::command("window prevh");
    }
}

sub cmd_window_nexth { window_last_history(\$j, \$v); }
sub cmd_window_prevh { window_last_history(\$i, \$w); }

Irssi::settings_add_bool('jump', 'change_window_jump', 0);

Irssi::command_bind( "window nexth" => "cmd_window_nexth" );
Irssi::command_bind( "window prevh" => "cmd_window_prevh" );

Irssi::signal_register({ "key " => [qw[string ulongptr Irssi::UI::Keyinfo]] });
Irssi::signal_add_first( "key change_window" => "sig_key_change_window" );
