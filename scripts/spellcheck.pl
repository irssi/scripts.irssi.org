# Copyright © 2008 Jakub Jankowski <shasta@toxcorp.com>
# Copyright © 2012-2019 Jakub Wilk <jwilk@jwilk.net>
# Copyright © 2012 Gabriel Pettier <gabriel.pettier@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 dated June, 1991.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.

use strict;
use warnings;

use vars qw($VERSION %IRSSI);
use Irssi 20070804;
use Irssi::TextUI;
use Encode;
use Text::Aspell;

$VERSION = '0.9';
%IRSSI = (
    authors     => 'Jakub Wilk, Jakub Jankowski, Gabriel Pettier, Nei',
    name        => 'spellcheck',
    description => 'checks for spelling errors using Aspell',
    license     => 'GPLv2',
    url         => 'http://jwilk.net/software/irssi-spellcheck',
);

my %speller;

sub spellcheck_setup
{
    my ($lang) = @_;
    my $speller = $speller{$lang};
    return $speller if defined $speller;
    $speller = Text::Aspell->new or return;
    $speller->set_option('lang', $lang) or return;
    $speller->set_option('sug-mode', 'fast') or return;
    $speller{$lang} = $speller;
    return $speller;
}

# add_rest means "add (whatever you chopped from the word before
# spell-checking it) to the suggestions returned"
sub spellcheck_check_word
{
    my ($langs, $word, $add_rest) = @_;
    my $win = Irssi::active_win();
    my $prefix = '';
    my $suffix = '';

    my @langs = split(/[+]/, $langs);
    for my $lang (@langs) {
        my $speller = spellcheck_setup($lang);
        if (not defined $speller) {
            $win->print('%R' . "Error while setting up spell-checker for $lang" . '%N', MSGLEVEL_CLIENTERROR);
            return;
        }
    }

    return if $word =~ m{^/}; # looks like a path
    $word =~ s/^([[:punct:]]*)//; # strip leading punctuation characters
    $prefix = $1 if $add_rest;
    $word =~ s/([[:punct:]]*)$//; # ...and trailing ones, too
    $suffix = $1 if $add_rest;
    return if $word =~ m{^\w+://}; # looks like a URL
    return if $word =~ m{^[^@]+@[^@]+$}; # looks like an e-mail
    return if $word =~ m{^[[:digit:][:punct:]]+$}; # looks like a number

    my @result;
    for my $lang (@langs) {
        my $ok = $speller{$lang}->check($word);
        if (not defined $ok) {
            $win->print('%R' . "Error while spell-checking for $lang" . '%N', MSGLEVEL_CLIENTERROR);
            return;
        }
        if ($ok) {
            return;
        } else {
            push @result, map { "$prefix$_$suffix" } $speller{$lang}->suggest($word);
        }
    }
    return \@result;
}

sub _spellcheck_find_language
{
    my ($network, $target) = @_;
    return Irssi::settings_get_str('spellcheck_default_language') unless (defined $network && defined $target);

    # support !channels correctly
    $target = '!' . substr($target, 6) if ($target =~ /^\!/);

    # lowercase net/chan
    $network = lc($network);
    $target  = lc($target);

    # possible settings: network/channel/lang  or  channel/lang
    my @languages = split(/[ ,]+/, Irssi::settings_get_str('spellcheck_languages'));
    for my $langstr (@languages) {
        my ($t, $c, $l) = $langstr =~ m{^(?:([^/]+)/)?([^/]+)/([^/]+)/*$};
        $t //= $network;
        if (lc($c) eq $target and lc($t) eq $network) {
            return $l;
        }
    }

    # no match, use defaults
    return Irssi::settings_get_str('spellcheck_default_language');
}

sub spellcheck_find_language
{
    my ($win) = @_;
    return _spellcheck_find_language(
        $win->{active_server}->{tag},
        $win->{active}->{name}
    );
}

sub spellcheck_key_pressed
{
    my ($key) = @_;
    my $win = Irssi::active_win();

    my $correction_window;
    my $window_height;

    my $window_name = Irssi::settings_get_str('spellcheck_window_name');
    if ($window_name ne '') {
        $correction_window = Irssi::window_find_name($window_name);
        $window_height = Irssi::settings_get_str('spellcheck_window_height');
    }

    return unless Irssi::settings_get_bool('spellcheck_enabled');

    # hide correction window when message is sent
    if (chr($key) =~ /\A[\r\n]\z/ && $correction_window) {
        $correction_window->command("^window hide $window_name");
        if (Irssi->can('gui_input_clear_extents')) {
            Irssi::gui_input_clear_extents(0, 9999);
        }
    }

    # get current inputline
    my $inputline = Irssi::parse_special('$L');
    my $utf8 = lc Irssi::settings_get_str('term_charset') eq 'utf-8';
    if ($utf8) {
        Encode::_utf8_on($inputline);
    }

    # ensure that newly added characters are not colored
    # when correcting a colored word
    # FIXME: this works at EOL, but not elsewhere
    if (Irssi->can('gui_input_set_extent')) {
        Irssi::gui_input_set_extent(length $inputline, '%n');
    }

    # don't bother unless pressed key is space
    # or a terminal punctuation mark
    return unless grep { chr $key eq $_ } (' ', qw(. ? !));

    $inputline = substr $inputline, 0, Irssi::gui_input_get_pos();

    # check if inputline starts with any of cmdchars
    # we shouldn't spell-check commands
    my $cmdchars = Irssi::settings_get_str('cmdchars');
    my $re = qr/^[\Q$cmdchars\E]/;
    return if ($inputline =~ $re);

    # get last bit from the inputline
    my ($word) = $inputline =~ /\s*(\S+)\s*$/;
    defined $word or return;

    # remove color from the last word
    # (we will add it back later if needed)
    my $start = $-[1];
    if (Irssi->can('gui_input_clear_extents')) {
        Irssi::gui_input_clear_extents($start, length $word);
    }

    my $lang = spellcheck_find_language($win);

    return if $lang eq 'und';

    my $suggestions = spellcheck_check_word($lang, $word, 0);

    return unless defined $suggestions;

    # strip leading and trailing punctuation
    $word =~ s/^([[:punct:]]+)// and $start += length $1;
    $word =~ s/[[:punct:]]+$//;

    # add color to the misspelled word
    my $color = Irssi::settings_get_str('spellcheck_word_input_color');
    if ($color && Irssi->can('gui_input_set_extents')) {
        Irssi::gui_input_set_extents($start, length $word, $color, '%n');
    }

    return unless Irssi::settings_get_bool('spellcheck_print_suggestions');

    # show corrections window if hidden
    if ($correction_window) {
        $win->command("^window show $window_name");
        $correction_window->command('^window stick off');
        $win->set_active;
        $correction_window->command("window size $window_height");
    } else {
        $correction_window = $win;
    }

    # we found a mistake, print suggestions

    $word =~ s/%/%%/g;
    $color = Irssi::settings_get_str('spellcheck_word_color');
    if (scalar @$suggestions > 0) {
        if ($utf8) {
            Encode::_utf8_on($_) for @$suggestions;
        }
        $correction_window->print("Suggestions for $color$word%N - " . join(', ', @$suggestions));
    } else {
        $correction_window->print("No suggestions for $color$word%N");
    }

    return;
}

sub spellcheck_complete_word
{
    my ($complist, $win, $word, $lstart, $wantspace) = @_;

    return unless Irssi::settings_get_bool('spellcheck_enabled');

    my $lang = spellcheck_find_language($win);

    return if $lang eq 'und';

    # add suggestions to the completion list
    my $suggestions = spellcheck_check_word($lang, $word, 1);
    push(@$complist, @$suggestions) if defined $suggestions;

    return;
}

sub spellcheck_add_word
{
    my ($cmd_line, $server, $win_item) = @_;
    my $win = Irssi::active_win();
    my @args = split(' ', $cmd_line);

    if (@args <= 0) {
        $win->print('SPELLCHECK_ADD <word>...    add word(s) to personal dictionary');
        return;
    }

    my $lang = spellcheck_find_language($win);

    my $speller = spellcheck_setup($lang);
    if (not defined $speller) {
        $win->print('%R' . "Error while setting up spell-checker for $lang" . '%N', MSGLEVEL_CLIENTERROR);
        return;
    }

    $win->print("Adding to $lang dictionary: @args");
    for my $word (@args) {
        $speller{$lang}->add_to_personal($word);
    }
    my $ok = $speller{$lang}->save_all_word_lists();
    if (not $ok) {
        $win->print('%R' . "Error while saving $lang dictionary" . '%N', MSGLEVEL_CLIENTERROR);
    }

    return;
}

Irssi::command_bind('spellcheck_add', 'spellcheck_add_word');

Irssi::settings_add_bool('spellcheck', 'spellcheck_enabled', 1);
Irssi::settings_add_bool('spellcheck', 'spellcheck_print_suggestions', 1);
Irssi::settings_add_str( 'spellcheck', 'spellcheck_default_language', 'en_US');
Irssi::settings_add_str( 'spellcheck', 'spellcheck_languages', '');
Irssi::settings_add_str( 'spellcheck', 'spellcheck_word_color', '%R');
Irssi::settings_add_str( 'spellcheck', 'spellcheck_word_input_color', '%U');
Irssi::settings_add_str( 'spellcheck', 'spellcheck_window_name', '');
Irssi::settings_add_str( 'spellcheck', 'spellcheck_window_height', 10);

Irssi::signal_add_last('key word_completion', sub{spellcheck_key_pressed(ord '.')});
Irssi::signal_add_last('key word_completion_backward', sub{spellcheck_key_pressed(ord '.')});
Irssi::signal_add_last('gui key pressed', 'spellcheck_key_pressed');
Irssi::signal_add_last('complete word', 'spellcheck_complete_word');

1;

# vim:ts=4 sts=4 sw=4 et
