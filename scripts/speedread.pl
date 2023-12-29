use strict;
use warnings;
use Irssi;

our $VERSION = '1.1';
our %IRSSI = (
    authors     => 'Juha Kesti',
    contact     => 'nauski@nauski.com',
    name        => 'speedread.pl',
    description => 'Bolds the first (1-3) characters of each word.',
    license     => 'Public Domain',
);

sub bold_first_three {
    my $msg = shift;
    my @words = split(/\s+/, $msg);
    my @processed_words;

    for my $word (@words) {
        if (length($word) > 3) {
            $word = "\x02" . substr($word, 0, 3) . "\x02" . substr($word, 3);
        } else {
            $word = "\x02" . substr($word, 0, 1) . "\x02" . substr($word, 1);
        }
        push @processed_words, $word;
    }

    return join(' ', @processed_words);
}

sub message_handler {
    my ($server, $msg, $nick, $address, $target) = @_;
    my $new_msg = bold_first_three($msg);
    Irssi::signal_continue($server, $new_msg, $nick, $address, $target);
}

Irssi::signal_add_first('message public', 'message_handler');
Irssi::signal_add_first('message own_public', 'message_handler');

