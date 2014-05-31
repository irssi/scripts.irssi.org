#!/usr/bin/perl
#
# Created by Stefan "tommie" Tomanek [stefan@kann-nix.org]
# to free the world from  the evil inverted I
#
# 23.02.2002
# *First release
#
# 01.03.200
# *Changed to GPL

use strict;
use vars qw($VERSION %IRSSI);
use Irssi;

$VERSION = "2002123102";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "tab_stop",
    description => "This script replaces the evil inverted 'I' with a configurable number of whitespaces ",
    license     => "GPLv2",
    changed     => "$VERSION",
);

sub event_server_incoming {
    my ($server, $data) = @_;
    my $newdata;
    if (has_tab($data)) {
	$newdata = replace_tabs($data);
	Irssi::signal_continue($server, $newdata);
    }
}

# FIXME Experimental!
sub sig_gui_print_text {
    my ($win, $fg, $bg, $flags, $text, $dest) = @_;
    return unless $text =~ /\t/;
    my $newtext = replace_tabs($text);
    Irssi::signal_continue($win, $fg, $bg, $flags, $newtext, $dest);
}

sub has_tab {
    my ($text) = @_;
    return $text =~ /\t/;
}

sub replace_tabs {
    my ($text) = @_;
    my $replacement = Irssi::settings_get_str('tabstop_replacement');
    $text =~ s/\t/$replacement/g;
    return($text);
}

#Irssi::signal_add('gui print text', \&sig_gui_print_text);
Irssi::signal_add_first('server incoming', \&event_server_incoming);

Irssi::settings_add_str('misc', 'tabstop_replacement', "    ");

