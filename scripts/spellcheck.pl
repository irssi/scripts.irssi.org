# Copyright © 2008 Jakub Jankowski <shasta@toxcorp.com>
# Copyright © 2012, 2013 Jakub Wilk <jwilk@jwilk.net>
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
use Text::Aspell;

$VERSION = '0.6';
%IRSSI = (
    authors     => 'Jakub Wilk, Jakub Jankowski, Gabriel Pettier',
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
    $speller->set_option('lang', $_[0]) or return;
    $speller->set_option('sug-mode', 'fast') or return;
    $speller{$lang} = $speller;
    return $speller;
}

# add_rest means "add (whatever you chopped from the word before
# spell-checking it) to the suggestions returned"
sub spellcheck_check_word
{
    my ($lang, $word, $add_rest) = @_;
    my $win = Irssi::active_win();
    my $prefix = '';
    my $suffix = '';

    my $speller = spellcheck_setup($lang);
    if (not defined $speller) {
        $win->print('%R' . "Error while setting up spell-checker for $lang" . '%N', MSGLEVEL_CLIENTERROR);
        return;
    }

    return if $word =~ m{^/}; # looks like a path
    $word =~ s/^([[:punct:]]*)//; # strip leading punctuation characters
    $prefix = $1 if $add_rest;
    $word =~ s/([[:punct:]]*)$//; # ...and trailing ones, too
    $suffix = $1 if $add_rest;
    return if $word =~ m{^\w+://}; # looks like an URL
    return if $word =~ m{^[^@]+@[^@]+$}; # looks like an e-mail
    return if $word =~ m{^[[:digit:][:punct:]]+$}; # looks like a number

    my $ok = $speller{$lang}->check($word);
    if (not defined $ok) {
        $win->print('%R' . "Error while spell-checking for $lang" . '%N', MSGLEVEL_CLIENTERROR);
        return;
    }
    unless ($ok) {
        my @result =  map { "$prefix$_$suffix" } $speller{$lang}->suggest($word);
        return \@result;
    }
    return;
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
    my @languages = split(/[ ,]/, Irssi::settings_get_str('spellcheck_languages'));
    for my $langstr (@languages) {
        # strip trailing slashes
        $langstr =~ s=/+$==;
        my ($s1, $s2, $s3) = split(/\//, $langstr, 3);
        my ($t, $c, $l);
        if (defined $s3 && $s3 ne '') {
            # network/channel/lang
            $t = lc($s1); $c = lc($s2); $l = $s3;
        } else {
            # channel/lang
            $c = lc($s1); $l = $s2;
        }

        if ($c eq $target && (!defined $t || $t eq $network)) {
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

    # I know no way to *mark* misspelled words in the input line,
    # that's why there's no spellcheck_print_suggestions -
    # because printing suggestions is our only choice.
    return unless Irssi::settings_get_bool('spellcheck_enabled');

    # hide correction window when message is sent
    if ($key eq 10 && $correction_window) {
        $correction_window->command("window hide $window_name");
    }

    # don't bother unless pressed key is space or dot
    return unless (chr $key eq ' ' or chr $key eq '.');

    # get current inputline
    my $inputline = Irssi::parse_special('$L');

    # check if inputline starts with any of cmdchars
    # we shouldn't spell-check commands
    my $cmdchars = Irssi::settings_get_str('cmdchars');
    my $re = qr/^[$cmdchars]/;
    return if ($inputline =~ $re);

    # get last bit from the inputline
    my ($word) = $inputline =~ /\s*([^\s]+)$/;
    defined $word or return;

    my $lang = spellcheck_find_language($win);

    my $suggestions = spellcheck_check_word($lang, $word, 0);

    return unless defined $suggestions;

    # show corrections window if hidden
    if ($correction_window) {
        $win->command("window show $window_name");
        $correction_window->command('window stick off');
        $correction_window->command("window size $window_height");
    } else {
        $correction_window = $win;
    }

    # we found a mistake, print suggestions

    $word =~ s/%/%%/g;
    my $color = Irssi::settings_get_str('spellcheck_word_color');
    if (scalar @$suggestions > 0) {
        $correction_window->print("Suggestions for $color$word%N - " . join(", ", @$suggestions));
    } else {
        $correction_window->print("No suggestions for $color$word%N");
    }
}

sub spellcheck_complete_word
{
    my ($complist, $win, $word, $lstart, $wantspace) = @_;

    return unless Irssi::settings_get_bool('spellcheck_enabled');

    my $lang = spellcheck_find_language($win);

    # add suggestions to the completion list
    my $suggestions = spellcheck_check_word($lang, $word, 1);
    push(@$complist, @$suggestions) if defined $suggestions;
}

sub spellcheck_add_word
{
    my $win = Irssi::active_win();
    my ($cmd_line, $server, $win_item) = @_;
    my @args = split(' ', $cmd_line);

    if (@args <= 0) {
        $win->print("SPELLCHECK_ADD <word>...    add word(s) to personal dictionary");
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
}

Irssi::command_bind('spellcheck_add', 'spellcheck_add_word');

Irssi::settings_add_bool('spellcheck', 'spellcheck_enabled', 1);
Irssi::settings_add_str( 'spellcheck', 'spellcheck_default_language', 'en_US');
Irssi::settings_add_str( 'spellcheck', 'spellcheck_languages', '');
Irssi::settings_add_str( 'spellcheck', 'spellcheck_word_color', '%R');
Irssi::settings_add_str( 'spellcheck', 'spellcheck_window_name', '');
Irssi::settings_add_str( 'spellcheck', 'spellcheck_window_height', 10);

Irssi::signal_add_first('gui key pressed', 'spellcheck_key_pressed');
Irssi::signal_add_last('complete word', 'spellcheck_complete_word');

# vim:ts=4 sw=4 et
