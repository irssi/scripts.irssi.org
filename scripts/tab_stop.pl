# Created by Stefan "tommie" Tomanek [stefan@kann-nix.org]
# to free the world from  the evil inverted I
#
# 23.02.2002
# *First release
#
# 01.03.200?
# *Changed to GPL
#
# 24.05.2011
# * Buggered about with by shabble.
#
# 19.01.2022
# * Added tabstop_interval support

use strict;
use warnings;

use Irssi;

our $VERSION = "2022011900";
our %IRSSI = (
    authors     => "Stefan 'tommie' Tomanek, shabble",
    contact     => "stefan\@pico.ruhr.de, shabble@#irssi/Freenode",
    name        => "tab_stop",
    description => 'Replaces \t TAB characters to line up with tab stops '
                 . '(default 8) or to contents of /set tabstop_replacement '
                 . 'if tabstop_interval is set to 0',
    license     => "GPLv2",
    changed     => "$VERSION",
    );

my $not_tab;
my $interval;

sub sig_gui_print_text {
    return unless $_[4] =~ /\t/;
    if ($interval) {
        while ($_[4] =~ s{^(.*?)\t}{ sprintf("%s%s", $1, " " x ($interval - length($1) % $interval)) }e) {
        }
    } else {
        $_[4] =~ s/\t/$not_tab/g;
    }
    Irssi::signal_continue(@_);
}

# create an expando $TAB which produces real tabs
Irssi::expando_create('TAB', sub { "\t" }, { 'gui exit' => 'never' });

# then rewrite them just before they're printed.
Irssi::signal_add_first('gui print text', \&sig_gui_print_text);
Irssi::signal_add('setup changed', \&sig_setup_changed);
Irssi::settings_add_str('misc', 'tabstop_replacement', "    ");
Irssi::settings_add_int('misc', 'tabstop_interval', 8);

sub sig_setup_changed {
    $not_tab = Irssi::settings_get_str('tabstop_replacement');
    $interval = Irssi::settings_get_int('tabstop_interval');
}

sig_setup_changed();
