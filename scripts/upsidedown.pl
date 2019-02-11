#!/usr/bin/perl
# 
# Irssi plugin to place text upside down
# V0.1 - Initial script - Ivo Schooneman, 08-11-2012
# V0.2 - usay/ume - Ivo Schooneman, 08-11-2012
# V0.3 - decode args 30-01-2019
#
use strict;
use utf8;
use Text::UpsideDown;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.3";
%IRSSI = (
    authors     => "Ivo Schooneman",
    contact     => "ivo\@schooneman.net",
    name        => "upsidedown",
    description => "Plugin to place text upsidedown",
    license     => "GNU GPLv2",
    url         => "https://github.com/Ivo-tje/Irssi-plugin-upsidedown",
);

sub ume {
    my ($text, $server, $dest) = @_;

    utf8::decode($text);

    # Check if connected to server
    if (!$server || !$server->{connected}) {
  	Irssi::print("Not connected to server");
   	return;
    }

    return unless $dest;

    if ($dest->{type} eq "CHANNEL" || $dest->{type} eq "QUERY") {
        $dest->command("me " . upside_down($text));
    }
}

sub usay {
    my ($text, $server, $dest) = @_;

    utf8::decode($text);

    # Check if connected to server
    if (!$server || !$server->{connected}) {
  	Irssi::print("Not connected to server");
   	return;
    }

    return unless $dest;

    if ($dest->{type} eq "CHANNEL" || $dest->{type} eq "QUERY") {
        $dest->command("msg " . $dest->{name} . " " . upside_down($text));
    }
}

Irssi::command_bind('usay', 'usay');
Irssi::command_bind('ume', 'ume');

if (Irssi::settings_get_str("term_charset") !~ m/utf/i ) {
    Irssi::print("%RWarning%n %9$IRSSI{name}:%n no utf8 Terminal (".
	Irssi::settings_get_str("term_charset").")",MSGLEVEL_CLIENTCRAP);
}

# vim:set sw=4 ts=8: 
