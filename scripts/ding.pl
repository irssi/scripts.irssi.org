# Put me in ~/.irssi/scripts, and then execute the following in irssi:
#       /script load ding
#
# Or put me in ~/.irssi/scripts/autorun
#
# Don't forget to set the sound files!

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.1";
%IRSSI = (
    authors     => 'Andrew Slice',
    contact     => 'edward.andrew.slice@gmail.com',
    name        => 'ding.pl',
    description => 'Play a given sound when messages come in.',
    license     => 'MIT',
    url         => 'https://bitbucket.org/easlice/irssi-ding',
);

Irssi::settings_add_bool('ding', 'ding', 1);
Irssi::settings_add_str('ding', 'ding_sound', '');
Irssi::settings_add_str('ding', 'ding_sound_hilight', '');
Irssi::settings_add_str('ding', 'ding_sound_private_msg', '');

sub print_text_ding {
    my ($dest, $text, $stripped) = @_;
    my $server = $dest->{server};

    return if not Irssi::settings_get_bool("ding");

    # Ignore:
    #     Anything that is not a 'public message'
    #     Anything that came from our own nick.
    #
    # Getting the sender from $stripped shamelessly stolen from irssi-libnotify
    # (Seriously, why does $dest->{nick} not work?)
    my $sender = $stripped;
    $sender =~ s/^\<.([^\>]+)\>.+/\1/ ;
    return if (!($dest->{level} & MSGLEVEL_PUBLIC) || ($sender eq $server->{nick}));

    if ($dest->{level} & MSGLEVEL_HILIGHT) {
        ding(Irssi::settings_get_str("ding_sound_hilight"));
    } else {
        ding(Irssi::settings_get_str("ding_sound"));
    }
}

sub message_private_ding {
    my ($server, $msg, $nick, $address) = @_;

    return if not Irssi::settings_get_bool("ding");

    ding(Irssi::settings_get_str("ding_sound_private_msg"));
}

sub ding {
    my ($sound) = @_;

    return if !$sound;

    if (substr($sound, -3) =~ /mp3/i) {
        system("mpg123 -q $sound &");
    } elsif (substr($sound, -3) =~ /wav/i) {
        system("aplay -q $sound &");
    }
}

Irssi::signal_add('print text', 'print_text_ding');
Irssi::signal_add('message private', 'message_private_ding');
