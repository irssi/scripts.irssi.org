#!/usr/bin/perl
#
# by Stefan 'tommie' Tomanek

use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "2003020801";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "BeStoiber",
    description => "stoibers your messages",
    license     => "GPLv2",
    url         => "",
    modules     => "",
    changed     => "$VERSION",
    commands	=> "bestoiber"
);


use Irssi 20020324;

sub stoibern ($) {
    my ($text) = @_;
    my $result;
    my $buffer;
    foreach (split / /, $text) {
	if (int(rand(4)) == 1) {
	    $result .= ' eehh, ';
	} else {
	    $result .= ' ';
	}
	if (substr($_, 0,1) =~ /[A-Z]+/ && int(rand(2)) == 1) {
	    my @buzzwords = split(/,/, Irssi::settings_get_str('bestoiber_buzzwords'));
	    $result .= $buzzwords[rand(scalar(@buzzwords))].", ";
	}
	if (int(rand(6)) == 1) {
	    $result =~ s/,?\ $//;
	    $result .= ", ".$buffer." " if $buffer;
	}

	$result .= $_;
	$buffer = $_;
    }
    $result =~ s/^ //;
    return $result;
}

sub cmd_bestoiber ($$$) {
    my ($arg, $server, $witem) = @_;
    if ($witem && ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY')) {
	$witem->command('MSG '.$witem->{name}.' '.stoibern($arg));
    } else {
	print CLIENTCRAP "%B>>%n ".stoibern($arg);
    }
}

Irssi::settings_add_str($IRSSI{name}, 'bestoiber_buzzwords', 'Arbeitslose,Fr. Merkel,Schröder');

Irssi::command_bind('bestoiber', \&cmd_bestoiber);
