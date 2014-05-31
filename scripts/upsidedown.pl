#!/usr/bin/perl
# 
# Irssi plugin to place text upside down
# V0.1 - Initial script - Ivo Schooneman, 08-11-2012
# V0.2 - usay/ume - Ivo Schooneman, 08-11-2012
#
use strict;
use Text::UpsideDown;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.2";
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
