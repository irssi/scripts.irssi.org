use strict;
use Irssi 20020217; # Irssi 0.8.0
use vars qw($VERSION %IRSSI);
$VERSION = "1.2";
%IRSSI = (
    authors     =>  "Matti 'qvr' Hiljanen",
    contact     =>  "matti\@hiljanen.com",
    name        =>  "wkb",
    description =>  "A simple word kickbanner",
    license     =>  "Public Domain",
    url         =>  "http://matin.maapallo.org/softa/irssi",
);

use Irssi;

my @channels;

my @words;

my @gods;

sub sig_public {
    my ($server, $msg, $nick, $address, $target) = @_;

    return if $nick eq $server->{nick};

    $msg =~ s/[\000-\037]//g;
    my $rmsg = $msg;
    $msg = lc($msg);

    # bad word
    my $nono = 0;
    foreach (@words) { $nono = 1 if $msg =~ /$_/ }
    return unless $nono;
       
    # channel? 
    my $react = 0;
    foreach (@channels) { $react = 1 if lc($target) eq lc($_) }
    return unless $react;

    # god-like person?
    my $jumala = 0;
    foreach (@gods) { $jumala = 1 if lc($nick) =~ /$_/ }
    return if $jumala;
    
    # voiced or op'd?
    return if $server->channel_find($target)->nick_find($nick)->{op} || $server->channel_find($target)->nick_find($nick)->{voice};

    $server->command("kickban $target $nick WKB initiated");
    Irssi::print("Word kick: Kicking $nick from $target. (He said $rmsg)");
}

sub sig_setup_changed {
    @channels= split(/\s+/, Irssi::settings_get_str($IRSSI{name}.'_channels'));
    @words= split(/\s+/, Irssi::settings_get_str($IRSSI{name}.'_words'));
    @gods= split(/\s+/, Irssi::settings_get_str($IRSSI{name}.'_gods'));
}

Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_channels', '#foo #foo2');
Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_words', 'bad_word bad_word2');
Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_gods', 'qvr other_gods');

Irssi::signal_add_last('message public', 'sig_public');
Irssi::signal_add('setup changed', 'sig_setup_changed');

sig_setup_changed();

# vim:set ts=4 sw=4 expandtab:
