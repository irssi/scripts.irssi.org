use strict;
use warnings;
use Irssi;

our $VERSION = '1.2';
our %IRSSI = (
    authors     => 'Idiomdrottning',
    contact     => 'sandra.snan@idiomdrottning.org',
    name        => 'discord_unbridge.pl',
    description => 'In channels with a discord birdge, turns "<bridge> <Sender> Message" into "<Sender> Message", and hides spoilers.',
    license     => 'Public Domain',
    url         => 'https://idiomdrottning.org/discord_unbridge.pl',
);

# HOWTO:
#
# optionally, but for better security, change
#    if ($text) {
# to
#    if ($text && "Your Bridge's name goes here" eq $nick) {
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

sub msg_bot_clean {
    my ($server, $data, $nick, $nick_and_address) = @_;
    my ($target, $message) = split /:/, $data, 2;
    my ($name, $text) = $message =~ /< *([^>]*)> (.*)/s;
    if ($text) {
        $nick = $name;
        $message = $text;
    }
    $message =~ s/\|\|([^|][^|]*)\|\|/1,1$1/;
    my $data = "$target:$message";
    Irssi::signal_continue($server, $data, $nick, $nick_and_address);
}

Irssi::signal_add('event privmsg', 'msg_bot_clean');
