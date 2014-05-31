# Answers to /msg's using Chatbot::Eliza when you're away.

# Put definition files to ~/.irssi/eliza/*.txt
# Uses the default definitions if there aren't any definition files.
# http://misterhouse.net:81/mh/data/eliza/

use strict;
use 5.6.0;
use Irssi;
use Chatbot::Eliza;

use vars qw($VERSION %IRSSI $eliza_dir @cmd_queue
  $min_reply_time $max_reply_time
  %conversations $conversation_expire);

$VERSION = '1.0';
%IRSSI = (
    authors     => 'Johan "Ion" Kiviniemi',
    contact     => 'ion at hassers.org',
    name        => 'Eliza',
    description => 'Answers to /msg\'s using Chatbot::Eliza when you\'re away.',
    license     => 'Public Domain',
    url         => 'http://ion.amigafin.org/scripts/',
    changed     => 'Thu Mar 14 05:29 EET 2002',
);

$eliza_dir = Irssi::get_irssi_dir . "/eliza";
undef $eliza_dir unless -d $eliza_dir;

$min_reply_time      = 5;      # seconds
$max_reply_time      = 15;     # seconds as well
$conversation_expire = 600;    # seconds again

Irssi::timeout_add(
    1000 * $conversation_expire, sub {
        foreach (keys %conversations) {
            if ($conversations{$_}{lastmsg} < time - $conversation_expire) {
                # The Chatbot::Eliza object will be destroyed automagically.
                delete $conversations{$_};
            }
        }
    },
    undef
);

sub new_eliza {
    my ($name, $eliza_o, @files) = shift;
    if ($eliza_dir) { @files = <$eliza_dir/*.txt> }
    if (@files) {
        $eliza_o = Chatbot::Eliza->new(scriptfile => $files[ rand @files ])
          || return;
    } else {
        $eliza_o = Chatbot::Eliza->new() || return;
    }
    $eliza_o->name($name);
    return $eliza_o;
}

Irssi::signal_add(
    'message private' => sub {
        # Someone just msg'ed me.
        my ($server, $message, $nick, $address) = @_;
        return if $nick eq $server->{nick};

        # Ignore it if I'm not away.
        return unless $server->{usermode_away};

        if (not $conversations{$address}
            and $conversations{$address}{lastmsg} < time - $conversation_expire)
        {
            # A new conversation.
            $conversations{$address} = { lastmsg => time };
            unless ($conversations{$address}{eliza} =
                new_eliza($server->{nick}))
            {
                Irssi::print("Chatbot::Eliza->new() failed!",
                    MSGLEVEL_CLIENTERROR);
                delete $conversations{$address};
                return;
            }
        } else {
            # Continuing an old conversation.
            $conversations{$address}{lastmsg} = time;
        }
        push_queue($server, "msg $nick "
            . $conversations{$address}{eliza}->transform($message));
    }
);

sub push_queue {
    my ($server, $command) = @_;
    return if @cmd_queue > 3;
    my $reply_time =
      int(time + $min_reply_time + rand($max_reply_time - $min_reply_time));
    push @cmd_queue, [ $reply_time, $server, $command ];
    @cmd_queue = sort { $a->[0] <=> $b->[0] } @cmd_queue;
}

Irssi::timeout_add(
    1000, sub {
        while (@cmd_queue and $cmd_queue[0][0] <= time) {
            my $cmd = shift @cmd_queue;
            $cmd->[1]->command($cmd->[2]);
        }
    },
    undef
);
