#!/usr/bin/perl -w
#
# Michael Kowalchuk <michael_kowalchuk@umanitoba.ca> presents:
#
# A spell checker for irssi
# Requires Lingua::Ispell and ispell
#
# Usage:
#  Load the script
#  Type /bind meta-s /_spellcheck
#  Hit meta+s (alt+s) to check your spelling
#
# This script also implements /spell <line> which shows more spelling suggestions than
# the hotkey (99).
#
# Options:
#   spell_max_guesses (def: 1)
#   spell_error_effect (def: %U = underline, others are %8 = reverse, %9 = bold)
#                                            see http://irssi.org/documentation/formats
#                                      
#
# History
#   First version: inline spellchecking, terrible, unreleased [Tue Aug  2 00:32:27 CDT 2005]
#   New version: Spellcheck on request [Mon Jan  2 17:02:12 CST 2006]
#
# Todo
#   Is there a way for a script to clear its mess like '/lastlog -clear' does?
#

use strict;
use Irssi;
use List::Util qw( min );
use Irssi::TextUI;
use Lingua::Ispell;

use vars qw($VERSION %IRSSI);
$VERSION = '1.0';
%IRSSI = (
    authors     => 'Michael Kowalchuk',
    contact     => 'michael_kowalchuk@umanitoba.ca',
    name        => 'spell',
    description => 'A spell checker for irssi.  Hit alt+s and your line will echoed to the active window with mistakes underlined and suggestions noted.  /spell is also provided.  Requires Lingua::Ispell and Ispell.',
    license     => 'MIT',
    url         => 'http://home.cc.umanitoba.ca/~umkowa17/',
    changed     => 'Mon Jan  2 17:02:12 CST 2006'
);

sub check_line {
	my ($inputline, $guesses) = @_;

	my $error_start = Irssi::settings_get_str($IRSSI{'name'}.'_error_effect');
	my $error_end = "%n"; # previous colour

	# ISpell has a limit of 99 characters in a word
	if ( $inputline =~ /\w{99}/ ) {
		return "unable to spellcheck";
	}

	# Reads in a list of hashes for each error with the keys term, type, and offset
	my @errs = Lingua::Ispell::spellcheck( $inputline );
	
	if( @errs > 0 ) {
		# Reconstruct the line with suggestions built in
		my $outputline;
		my $last_end = 0;
		foreach(@errs) {
			my $off=$_->{'offset'}-1; # ispell counts from 1
			my $before = substr($inputline, $last_end, $off - $last_end);
			
			$last_end = $off + length($_->{'term'});

			# Give speling [spelling, spelunking?] suggestions
			my $extra_info = "";
			if( $guesses > 0 ) {
				if( $_->{'type'} eq 'miss' ) {
					# Show near-misses, there will be 1..n of them
					my @misses = @{$_->{'misses'}};

					my $miss_len = @misses;
					my $shown_guesses = min( $miss_len, $guesses);

					my @shown = @misses[0..$shown_guesses - 1];

					$extra_info = " (" . join(", ", @shown ) . "?)";
				}
				elsif( $_->{'type'} eq 'root' ) {
					# Show root suggestions, there will be exactly 1
					$extra_info = " (" . $_->{'root'} . "?)";
				}
			}
			
 			$outputline .= $before . $error_start . $_->{'term'} . $error_end . $extra_info;
		}
		$outputline .= substr($inputline, $last_end);
	
		return $outputline;
	}
	else {
		return "no errors";
	}
}

# Read from the input line
sub cmd_spellcheck {
	my $inputline = Irssi::parse_special("\$L");
	my $guesses = Irssi::settings_get_int($IRSSI{'name'}.'_max_guesses');	

	Irssi::active_win()->print("spell: " . check_line($inputline, $guesses), MSGLEVEL_CRAP );
}

# Read from the argument list
sub cmd_spell {
	my ($inputline) = @_;
	my $guesses = 99;

	Irssi::active_win()->print("spell: " . check_line($inputline, $guesses), MSGLEVEL_CRAP );
}


Irssi::settings_add_str('misc', $IRSSI{'name'} . '_error_effect', "%U");
Irssi::settings_add_int('misc', $IRSSI{'name'} . '_max_guesses', 1);

Irssi::command_bind('_spellcheck', 'cmd_spellcheck');
Irssi::command_bind('spell', 'cmd_spell');

