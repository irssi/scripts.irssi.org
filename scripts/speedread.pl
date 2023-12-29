use strict;
use warnings;
use Irssi;

our $VERSION = '1.0';
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
sub outgoing_msg_handler {
    my ($msg, $server, $witem) = @_;
    if (defined $witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {
        my $new_msg = bold_first_three($msg);
        $witem->command("msg -channel " . $witem->{name} . " $new_msg");
        Irssi::signal_stop();
    }
}

sub incoming_msg_handler {
    my ($server, $msg, $nick, $address, $target) = @_;
    my $new_msg = bold_first_three($msg);
    Irssi::signal_continue($server, $new_msg, $nick, $address, $target);
}

Irssi::signal_add('send text', 'outgoing_msg_handler');
Irssi::signal_add('message public', 'incoming_msg_handler');

