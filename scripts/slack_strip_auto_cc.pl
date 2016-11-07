use strict;
use warnings;
use Irssi;

our $VERSION = '1.0';
our %IRSSI = (
    authors     => 'Ævar Arnfjörð Bjarmason',
    contact     => 'avarab@gmail.com',
    name        => 'slack_strip_auto_cc.pl',
    description => 'Strips the annoying mentions of your nickname on Slack via [cc: <you>]',
    license     => 'Public Domain',
    url         => 'http://scripts.irssi.org & https://github.com/avar/dotfiles/blob/master/.irssi/scripts/slack_strip_auto_cc.pl',
);

# HOWTO:
#
#   /load slack_strip_auto_cc.pl
#
# This should just automatically work, it'll detect if you're using
# the slack IRC gateway and auto-detect the nick it should be
# stripping as well.

sub privmsg_slack_strip_auto_cc {
    my ($server, $data, $nick, $nick_and_address) = @_;
    my ($target, $message) = split /:/, $data, 2;

    return unless $server->{address} =~ /irc\.slack\.com$/s;
    my $wanted_nick = $server->{wanted_nick};
    return unless $message =~ s/ \[cc: \Q$wanted_nick\E\]$//s;

    my $new_data = "$target:$message";
    Irssi::signal_continue($server, $new_data, $nick, $nick_and_address);
}

Irssi::signal_add('event privmsg', 'privmsg_slack_strip_auto_cc');
