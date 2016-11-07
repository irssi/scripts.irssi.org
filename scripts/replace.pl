# replace.pl - replaces a regexp with a string
#
# Commands:
# REPLACE ADD <regexp> - <string>
# REPLACE DEL <regexp>
# REPLACE LIST
# REPLACE HELP
#
# Example usage:
# REPLACE ADD \S*dQw4w9WgXcQ\S* - Rick Roll
# <@anon> Hey check out this cool video https://www.youtube.com/watch?v=dQw4w9WgXcQ
# shows as:
# <@anon> Hey check out this cool video Rick Roll
#
# Changelog:
#
# 2016-03-22 (version 1.0)
# Release

use strict;
use vars qw($VERSION %IRSSI);
use Irssi;

$VERSION = '1.0';
%IRSSI = (
    authors     => 'Jere Toivonen',
    contact     => 'jere@flamero.fi',
    name        => 'replace',
    description => 'Replaces regexps with predefined strings',
    license     => 'MIT',
    url         => 'http://flamero.fi',
    changed     => '22 March 2016',
);

my %replaces;

sub help_replace {
    my $help_str = 
    "REPLACE ADD <regexp> - <replace>
REPLACE DEL <regexp>
REPLACE LIST";

    Irssi::print($help_str, MSGLEVEL_CLIENTCRAP);
}

sub add_replace {
    my ($data, $server, $witem) = @_;
    my ($new_key, $new_replace) = split(/ - /, $data,2);

    $replaces{$new_key} = $new_replace;

    Irssi::print("Added replace: $new_key - $new_replace", MSGLEVEL_CLIENTCRAP);
}

sub list_replace {
    my ($data, $server, $witem) = @_;

    Irssi::print("List of replaces:", MSGLEVEL_CLIENTCRAP);
    foreach my $key (keys %replaces) {
        Irssi::print("$key - $replaces{$key}", MSGLEVEL_CLIENTCRAP);
    }
}

sub del_replace {
    my ($data, $server, $witem) = @_;

    if (!%replaces) {
        Irssi::print("No replaces to delete", MSGLEVEL_CLIENTCRAP);
        return;
    }

    foreach my $key (keys %replaces) {
        if ($data eq $key) {
            Irssi::print("Deleted replace $key - $replaces{$key}", MSGLEVEL_CLIENTCRAP);
            delete $replaces{$key};
        } else {
            Irssi::print("No such replace, see /REPLACE LIST", MSGLEVEL_CLIENTCRAP);
        }
    }
}

sub run_replace {
    my ($server, $data, $nick, $address) = @_;
    my ($target, $msg) = split(/ :/, $data,2);

    foreach my $key (keys %replaces) {
        if ($msg =~ /$key/) {
            $msg =~ s/$key/$replaces{$key}/;

            Irssi::signal_emit('event privmsg', ($server, "$target :$msg", $nick, $address));
            Irssi::signal_stop();
        }
    }
}

Irssi::signal_add('event privmsg', 'run_replace');

Irssi::command_bind('replace help',\&help_replace);
Irssi::command_bind('replace add',\&add_replace);
Irssi::command_bind('replace delete',\&del_replace);
Irssi::command_bind('replace list',\&list_replace);
Irssi::command_bind 'replace' => sub {
    my ($data, $server, $witem) = @_;
    $data =~ s/\s+$//g;
    Irssi::command_runsub('replace', $data, $server, $witem);
}
