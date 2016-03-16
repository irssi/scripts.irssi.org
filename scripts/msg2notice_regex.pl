use strict;
use warnings;
use Irssi;

our $VERSION = '1.0';
our %IRSSI = (
    authors     => 'Fernando Vezzosi & Ævar Arnfjörð Bjarmason',
    contact     => 'irssi@repnz.net & avarab@gmail.com',
    name        => 'msg2notice_regex.pl',
    description => 'For a configured list of nicks or nicks matching a regex, convert all their messages to a notices',
    license     => 'Public Domain',
    url         => 'http://scripts.irssi.org & https://github.com/avar/dotfiles/blob/master/.irssi/scripts/msg2notice_regex.pl & https://github.com/bucciarati/irssi-script-msg_to_notice',
);

# HOWTO:
#
#   /load msg2notice_regex.pl
#   /set noticeable_nicks ~\[bot\]$,~mon-[0-9]+$,~^mon-.*-[0-9]+$,root,deploy,log,jenkins,nagmetoo
#
# The nicks that match will be turned into notices, useful for marking
# bots as such. Note that if the nicks start with ~ the rest is taken
# to be a regex. Due to limitations of our dummy parser you can't use
# {x,y} character classes or other regex constructs that require a
# comma, but usually that's something you can work around.

sub privmsg_msg2notice_regex {
    use Data::Dumper;
    my ($server, $data, $nick, $nick_and_address) = @_;
    my ($target, $message) = split /:/, $data, 2;

    # Irssi::print("server<$server> data<$data>[$target:$message] nick<$nick> mask<$nick_and_address>");
    my $is_noticeable = 0;
    for my $noticeable_nick ( split /[\s,]+/, Irssi::settings_get_str('noticeable_nicks') ) {
        $noticeable_nick =~ s/\A \s+//x;
        $noticeable_nick =~ s/\s+ \z//x;
        my $is_regexp; $is_regexp = 1 if $noticeable_nick =~ s/^~//;

        # Irssi::print("Checking <$nick> to <$noticeable_nick> via <" . ($is_regexp ? "rx" : "eq") . ">");
        if ( $is_regexp and $nick =~ $noticeable_nick ) {
            # Irssi::print("Matched <$nick> to <$noticeable_nick> via <rx>");
            $is_noticeable = 1;
            last;
        } elsif ( not $is_regexp and lc $noticeable_nick eq lc $nick ){
            # Irssi::print("Matched <$nick> to <$noticeable_nick> via <eq>");
            $is_noticeable = 1;
            last;
        }
    }
    return unless $is_noticeable;

    Irssi::signal_emit('event notice', $server, $data, $nick, $nick_and_address);
    Irssi::signal_stop();
}

Irssi::settings_add_str('msg_to_notice', 'noticeable_nicks', '~\[bot\]$,root,deploy');
Irssi::signal_add('event privmsg', 'privmsg_msg2notice_regex');
