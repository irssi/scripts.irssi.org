use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "1.1";
%IRSSI = (
    authors     =>  "Roeland 'Trancer' Nieuwenhuis",
    contact     =>  "irssi\@trancer.nl",
    name        =>  "nickban",
    description =>  "A simple nick banner. If it encounters a nick it bans its host",
    license     =>  "Public Domain"
);

use Irssi;

# The channels the nicks are banned on (on which this script is active)
my @channels = qw(#worldchat #chat-world #php);

# The banned nicks
my @nicks = qw(evildude evilgirl);

# Your kickreason
my $kickreason = "Not welcome here.";

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

Irssi::signal_add_last('message join', 'nick_banner');
