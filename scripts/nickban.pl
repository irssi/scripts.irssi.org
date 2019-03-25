use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "1.2";
%IRSSI = (
    authors     =>  "Roeland 'Trancer' Nieuwenhuis",
    contact     =>  "irssi\@trancer.nl",
    name        =>  "nickban",
    description =>  "A simple nick banner. If it encounters a nick it bans its host",
    license     =>  "Public Domain"
);

use Irssi;

# The channels the nicks are banned on (on which this script is active)
my @channels;

# The banned nicks
my @nicks;

# Your kickreason
my $kickreason;

sub nick_banner {

    my($server, $channel, $nick, $address) = @_;

    # Are we opped?
    return unless $server->channel_find($channel)->{chanop};
    
    # If the nick is a server, stop it.
    return if $nick eq $server->{nick};
    
    # Is the user a banned nick?
    my $nono = 0;
    foreach (@nicks) { $nono = 1 if lc($nick) eq lc($_) }
    return unless $nono;
       
    # Is the user on one of the banned channels?
    my $react = 0;
    foreach (@channels) { $react = 1 if lc($channel) eq lc($_) }
    return unless $react;
    
    # User voiced or op'd?
    # Pretty useless, but ok
    return if $server->channel_find($channel)->nick_find($nick)->{op} || $server->channel_find($channel)->nick_find($nick)->{voice};

    $server->command("kickban $channel $nick $kickreason");
    Irssi::print("Nick banning $nick on $channel. Banned.");
}

sub sig_setup_changed {
    @channels = split(/\s+/,Irssi::settings_get_str($IRSSI{name}.'_channels'));
    @nicks = split(/\s+/,Irssi::settings_get_str($IRSSI{name}.'_nicks'));
    $kickreason = Irssi::settings_get_str($IRSSI{name}.'_reason');
}

Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_channels', '#worldchat #chat-world #php');
Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_nicks', 'evildude evilgirl');
Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_reason', "Not welcome here.");

Irssi::signal_add_last('message join', 'nick_banner');
Irssi::signal_add('setup changed', 'sig_setup_changed');

sig_setup_changed();

# vim:set ts=4 sw=4 expandtab:
