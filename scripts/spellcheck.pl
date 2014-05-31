#!/usr/bin/perl -w

# ** This script is a 10-minutes-hack, so it's EXPERIMENTAL. **
#
# Requires:
#  - Irssi 0.8.12 or newer (http://irssi.org/).
#  - GNU Aspell with appropriate dictionaries (http://aspell.net/).
#  - Perl module Text::Aspell (available from CPAN).
#
#
# Description:
#  Works as you type, printing suggestions when Aspell thinks
#  your last word was misspelled. 
#  It also adds suggestions to the list of tabcompletions,
#  so once you know last word is wrong, you can go back 
#  and tabcomplete through what Aspell suggests.
#
#
# Settings:
#
#  spellcheck_languages  -- a list of space and/or comma
#    separated languages to use on certain networks/channels.
#    Example: 
#    /set spellcheck_languages netA/#chan1/en_US, #chan2/fi_FI, netB/!chan3/pl_PL
#    will use en_US for #chan1 on network netA, fi_FI for #chan2
#    on every network, and pl_PL for !chan3 on network netB.
#    By default this setting is empty.
#
#  spellcheck_default_language  -- language to use in empty
#    windows, or when nothing from spellcheck_languages matches.
#    Defaults to 'en_US'.
#
#  spellcheck_enabled [ON/OFF]  -- self explaining. Sometimes
#    (like when pasting foreign-language text) you don't want
#    the script to spit out lots of suggestions, and turning it
#    off for a while is the easiest way. By default it's ON.
#
#
# BUGS:
#  - won't catch all mistakes
#  - picking actual words from what you type is very kludgy,
#    you may occasionally see some leftovers like digits or punctuation
#  - works every time you press space or a dot (so won't work for
#    the last word before pressing enter, unless you're using dot
#    to finish your sentences)
#  - when you press space and realize that the word is wrong,
#    you can't tabcomplete to the suggestions right away - you need
#    to use backspace and then tabcomplete. With dot you get an extra
#    space after tabcompletion.
#  - all words will be marked and no suggestions given if 
#    dictionary is missing (ie. wrong spellcheck_default_language)
#  - probably more, please report to $IRSSI{'contact'}
#
#
# $Id: spellcheck.pl 5 2008-05-28 22:31:06Z shasta $
#

use strict;
use vars qw($VERSION %IRSSI);
use Irssi 20070804;
use Text::Aspell;

$VERSION = '0.3';
%IRSSI = (
    authors     => 'Jakub Jankowski',
    contact     => 'shasta@toxcorp.com',
    name        => 'Spellcheck',
    description => 'Checks for spelling errors using Aspell.',
    license     => 'GPLv2',
    url         => 'http://toxcorp.com/irc/irssi/spellcheck/',
);

my %speller;

sub spellcheck_setup
{
    return if (exists $speller{$_[0]} && defined $speller{$_[0]});
    $speller{$_[0]} = Text::Aspell->new or return undef;
    $speller{$_[0]}->set_option('lang', $_[0]) or return undef;
    $speller{$_[0]}->set_option('sug-mode', 'fast') or return undef;
    return 1;
}

# add_rest means "add (whatever you chopped from the word before
# spellchecking it) to the suggestions returned"
sub spellcheck_check_word
{
    my ($lang, $word, $add_rest) = @_;
    my $win = Irssi::active_win();
    my @suggestions = ();

    # setup Text::Aspell for that lang if needed
    if (!exists $speller{$lang} || !defined $speller{$lang})
    {
	if (!spellcheck_setup($lang))
	{
	    $win->print("Error while setting up spellchecker for $lang");
	    # don't change the message
	    return @suggestions;
	}
    }

    # do the spellchecking
    my ($stripped, $rest) = $word =~ /([^[:punct:][:digit:]]{2,})(.*)/; # HAX
    # Irssi::print("Debug: stripped $word is '$stripped', rest is '$rest'");
    if (defined $stripped && !$speller{$lang}->check($stripped))
    {
	push(@suggestions, $add_rest ? $_ . $rest : $_) for ($speller{$lang}->suggest($stripped));
    }
    return @suggestions;
}

sub spellcheck_find_language
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
    for my $langstr (@languages)
    {
	# strip trailing slashes
	$langstr =~ s=/+$==;
	# Irssi::print("Debug: checking network $network target $target against langstr $langstr");
	my ($s1, $s2, $s3) = split(/\//, $langstr, 3);
	my ($t, $c, $l);
	if (defined $s3 && $s3 ne '')
	{
	    # network/channel/lang
	    $t = lc($s1); $c = lc($s2); $l = $s3;
	}
	else
	{
	    # channel/lang
	    $c = lc($s1); $l = $s2;
	}

	if ($c eq $target && (!defined $t || $t eq $network))
	{
	    # Irssi::print("Debug: language found: $l");
	    return $l;
	}
    }

    # Irssi::print("Debug: language not found, using default");
    # no match, use defaults
    return Irssi::settings_get_str('spellcheck_default_language');
}

sub spellcheck_key_pressed
{
    my ($key) = @_;
    my $win = Irssi::active_win();

    # I know no way to *mark* misspelled words in the input line,
    # that's why there's no spellcheck_print_suggestions -
    # because printing suggestions is our only choice.
    return unless Irssi::settings_get_bool('spellcheck_enabled');

    # don't bother unless pressed key is space or dot
    return unless (chr $key eq ' ' or chr $key eq '.');

    # get current inputline
    my $inputline = Irssi::parse_special('$L');

    # check if inputline starts with any of cmdchars
    # we shouldn't spellcheck commands
    my $cmdchars = Irssi::settings_get_str('cmdchars');
    my $re = qr/^[$cmdchars]/;
    return if ($inputline =~ $re);

    # get last bit from the inputline
    my ($word) = $inputline =~ /\s*([^\s]+)$/;

    # find appropriate language for current window item
    my $lang = spellcheck_find_language($win->{active_server}->{tag}, $win->{active}->{name});

    my @suggestions = spellcheck_check_word($lang, $word, 0);
    # Irssi::print("Debug: spellcheck_check_word($word) returned array of " . scalar @suggestions);
    return if (scalar @suggestions == 0);

    # we found a mistake, print suggestions
    $win->print("Suggestions for $word - " . join(", ", @suggestions));
}


sub spellcheck_complete_word
{
    my ($complist, $win, $word, $lstart, $wantspace) = @_;

    return unless Irssi::settings_get_bool('spellcheck_enabled');

    # find appropriate language for the current window item
    my $lang = spellcheck_find_language($win->{active_server}->{tag}, $win->{active}->{name});

    # add suggestions to the completion list
    push(@$complist, spellcheck_check_word($lang, $word, 1));
}


Irssi::settings_add_bool('spellcheck', 'spellcheck_enabled', 1);
Irssi::settings_add_str( 'spellcheck', 'spellcheck_default_language', 'en_US');
Irssi::settings_add_str( 'spellcheck', 'spellcheck_languages', '');

Irssi::signal_add_first('gui key pressed', 'spellcheck_key_pressed');
Irssi::signal_add_last('complete word', 'spellcheck_complete_word');
