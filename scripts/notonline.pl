# Answers "$nick: No." if you're away and someone asks are you online on a channel.

use strict;
use Irssi;
use locale;

use vars qw($VERSION %IRSSI %answers $floodlimit %floodi);

$VERSION = '0.9';
%IRSSI = (
    authors     => 'Johan "Ion" Kiviniemi',
    contact     => 'ion at hassers.org',
    name        => 'NotOnline',
    description =>
'Answers "$nick: No." if you\'re away and someone asks are you online on a channel',
    license => 'Public Domain',
    url     => 'http://ion.amigafin.org/irssi/',
    changed => 'Tue Mar 12 22:20 EET 2002',
);

%answers = (
    'online'    => 'Offline.',
    'there'     => 'Not here.',
    'idle'      => 'Of course.',
    'paikalla'  => 'En, vaan paikassa.',
    'siellä'    => 'Ei kun tuolla.',
    'siellÃ¤'   => 'Ei kun tuolla.',
    'hereillä'  => 'Nukkumassa.',
    'hereillÃ¤' => 'Nukkumassa.',
);

$floodlimit = 600;    # notice the same channel only once in N seconds
%floodi     = ();

Irssi::signal_add_last(
    'message public' => sub {
        my ($server, $msg, $nick, $address, $target) = @_;

        # Am i away?
        return unless $server->{usermode_away};

        # Am i asked about something?
        my $own_nick = $server->{nick};
        $own_nick =~ s/\W//g;
        return
          unless $msg =~ /^(\Q$server->{nick}\E|\Q$own_nick\E)\s*[,:].+\?/i;

        # Is it me who's talking?
        return if $nick eq $server->{nick};

        # Are you asking the right question?
        my $answer;
        foreach (keys %answers) {
            $answer = $answers{$_} if $msg =~ /\b\Q$_\E\b/i;
        }
        return unless $answer;

        # You aren't flooding, are you?
        if (defined $floodi{$target}) {
            if (time - $floodi{$target} < $floodlimit) {
                return;
            } else {
                undef $floodi{$target};
            }
        }

        $nick =~ s/\W//g;
        $nick = lc $nick
          if Irssi::settings_get_bool('completion_nicks_lowercase');
        $nick .= Irssi::settings_get_str('completion_char') || ":";

        $floodi{$target} = time;
        $server->command("msg $target $nick $answer");
        # Irssi::print("msg $target $nick $answer");
    }
);
