use strict;
use warnings;
use Irssi;

our $VERSION = '1.3';
our %IRSSI = (
    authors     => 'Idiomdrottning',
    contact     => 'sandra.snan@idiomdrottning.org',
    name        => 'discord_unbridge.pl',
    description => 'In channels with a discord bridge, turns "<bridge> <Sender> Message" into "<Sender> Message", and hides spoilers.',
    license     => 'Public Domain',
    url         => 'https://idiomdrottning.org/discord_unbridge.pl',
);

# HOWTO:
#
# set $bridgename to your bot's name, default is Yoda50.
#
# Regardless, to use the script just
#   /load discord_unbridge.pl
#
# NOTE:
#
# git clone https://idiomdrottning.org/discord_unbridge.pl
# for version history and to send patches.
#
# Based on discord_unhilight by Christoffer Holmberg, in turn
# based on slack_strip_auto_cc.pl by Ævar Arnfjörð Bjarmason.

my $bridgename = "Yoda50";

sub bot_nick_change {
    my($server, $message) = @_;
    $message =~ s/:$bridgename!~[^ ]* PRIVMSG ([&#][^ ]+) :<([^>]+)> (.*)/:$2!~Yoda50\@ToscheStation PRIVMSG $1 :$3/;
    $message =~ s/\|\|([^|][^|]*)\|\|/1,1$1/;
    Irssi::signal_continue($server, $message);
}

Irssi::signal_add('server incoming', 'bot_nick_change');
