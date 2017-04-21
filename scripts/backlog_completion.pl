#!/usr/bin/perl

use strict;
use warnings;
use Irssi;

# backlog completion:
#
# enter a word prefix and press TAB - and the prefix will be
# expanded from all the words on the current channel on everything
# that was said by yourself or by others  - provided that its
# length is at least $backlog_complete_min_length and at most
# $backlog_complete_max_length long, and consists only of letters
# in $backlog_complete_word_chars.  word case does not matter.

# 2014-10-20: by Matthias Kopfermann and Sven Guckes:
# Extended regexp for "word_chars", adding umlauts (äöü)
# and s-sharp (ß) for those weird German words,
# as well as punctuation to allow for URLs:
#   word_chars => [ 'str', '-_.:=#+/?&~%0-9a-zA-ZäÄöÖüÜß' ],
# example URL:
# http://www.guckes.net:80/~sven/irssi/script.html#Heizölrückstoßabdämpfung?answer=42%23

our $VERSION = '0.02';
our %IRSSI   = (
        authors     => 'Florian Ragwitz',
        contact     => 'rafl@debian.org',
        name        => 'backlog completion',
        description => 'backlog based tab completion',
        license     => 'GPL2',
        url         => 'http://perldition.org/',
        changed     => 'Mon Nov 06 23:42:05 CET 2006',
);

our $channel_history;

sub sig_message {
    my ($server, $message) = @_;
    my $target = pop;

    my $min_length = Irssi::settings_get_int( 'backlog_complete_min_length' );
    my $max_length = Irssi::settings_get_int( 'backlog_complete_max_length' );
    my $max_words  = Irssi::settings_get_int( 'backlog_complete_max_words'  );
    my $word_chars = Irssi::settings_get_str( 'backlog_complete_word_chars' );

    my $server_id  = $server->{address} .q{:}. $server->{port};
    $channel_history->{ $server_id }->{ $target } ||= {};
    my $queue = $channel_history->{ $server_id }->{ $target };

    for my $word (split /[^$word_chars]/, $message) {
        next if length $word < $min_length;
        next if length $word > $max_length;

        if (!exists $queue->{ $word }) {
            $queue->{ $word } = { time => time(), count => 1 };
        }
        else {
            $queue->{ $word }->{ count }++;
            $queue->{ $word }->{ time  } = time();
        }
    }

    if (scalar keys %{ $queue } > $max_words) {
        my $num_delete = $max_words - scalar keys %{ $queue };

        if ($num_delete > 0) {
            my @candidates = sort { $queue->{ $b }->{time} <=> $queue->{ $a }->{time} } keys %{ $queue };

            delete $queue->{ pop @candidates } for 0 .. $num_delete;
        }
    }
}

sub sig_complete {
    my ($complist, $window, $word, $linestart, $want_space) = @_;

    my $order_by = Irssi::settings_get_str( 'backlog_complete_order_by' );
    $order_by = 'count' if $order_by ne 'count' && $order_by ne 'time';

    my $server  = $window->{ active_server  };
    my $channel = $window->{ active         };

    return unless defined $server && defined $channel;

    my $server_id = $server->{address} .q{:}. $server->{port};
    my $queue     = $channel_history->{ $server_id }->{ $channel->{name} };

    return unless $queue;

    my $word_re = quotemeta ($word);
       $word_re = qr/^$word_re/;

    push @{ $complist },
        sort { $queue->{ $b }->{ $order_by } <=> $queue->{ $a }->{ $order_by } }
        grep { $_ =~ $word_re }
        keys %{ $queue };
}

my %option_defaults = (
        max_words  => [ 'int',   1000 ],
        min_length => [ 'int',      4 ],
        max_length => [ 'int',    100 ],
#       word_chars => [ 'str',   '\w' ],
        word_chars => [ 'str', '-_.:=#+/?&~%0-9a-zA-ZäÄöÖüÜß' ],
        order_by   => [ 'str', 'time' ]
);

while (my ($option, $default_value) = each %option_defaults) {
    my $func = 'Irssi::settings_add_'. $default_value->[0];
    {
        no strict 'refs';
        $func->( 'backlog_complete', "backlog_complete_${option}", $default_value->[1] );
    }
}

for my $signal ('message public',     'message private',
                'message own_public', 'message own_private',
                'message topic') {
    Irssi::signal_add( $signal => \&sig_message );
}

Irssi::signal_add_last( 'complete word' => \&sig_complete );
