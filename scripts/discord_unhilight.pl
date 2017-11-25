use strict;
use warnings;
use Irssi;

our $VERSION = '0.1b';
our %IRSSI = (
    authors     => 'Christoffer Holmberg',
    contact     => 'skug+irssiscripts@skug.fi',
    name        => 'discord_unhilight.pl',
    description => 'Strips the annoying mentions of your nickname via <yournick> on irc<->discord bridge, will work for any bridge using botnick: <yournick>',
    license     => 'Public Domain',
    url         => 'http://scripts.irssi.org & https://github.com/mskug/scrips.irssi.org/blob/master/scripts/discord_unhilight.pl',
);

# HOWTO:
#
#   /load discord_unhilight.pl
#
# This should just automatically work
#
# NOTE:
#
# Based on slack_strip_auto_cc.pl by Ævar Arnfjörð Bjarmason.

sub msg_strip_nick_from_discord_bridge {
    my ($server, $data, $nick, $nick_and_address) = @_;
    my ($target, $message) = split /:/, $data, 2;

    my $wanted_nick = $server->{wanted_nick};
    return unless $message =~ s/^<\Q$wanted_nick\E>/-You-:/;

    my $new_data = "$target:$message";
    Irssi::signal_continue($server, $new_data, $nick, $nick_and_address);
}

Irssi::signal_add('event privmsg', 'msg_strip_nick_from_discord_bridge');
