# /sana command, translates english-finnish-english.

# BUGS: Doesn't handle UTF-8.

use warnings;
use strict;
use HTML::Entities ();
use Irssi ();
use LWP::Simple ();

use vars qw($VERSION %IRSSI);

$VERSION = "0.1";
%IRSSI = (
    authors     => 'Johan "Ion" Kiviniemi, idea taken from Riku Voipio\'s sana.pl',
    contact     => 'ion at hassers.org',
    name        => 'sana-cmd',
    description => '/sana command, translates english-finnish-english.',
    license     => 'Public Domain',
    url         => 'http://ion.amigafin.org/irssi/',
    changed     => 'Sat Mar 16 06:20 EET 2002',
);

Irssi::command_bind(
    'sana' => sub {
        my @params = split /\s+/, shift;
        unless (@params) {
            Irssi::print("Sana: Usage: "
                . (substr(Irssi::settings_get_str('cmdchars'), 0, 1) || "/")
                . "sana word");
            return;
        }

        my $word = $params[0];
        $word =~ s/ /+/g;
        $word =~ s/(\W)/'%' . unpack "H*", $1/eg;

        if (my $content =
            LWP::Simple::get(
                'http://www.tracetech.net:8081/?word=' . $word))
        {
            $content = HTML::Entities::decode($content);
            $content =~ s/\015?\012/ /g;
            $content =~ s/<[^>]+>/ /g;     # Ugly, but it does the trick here.

            my @words = $content =~ /(\S+)\s+(\(\S+?\))/g;

            if (@words) {
                Irssi::print("Sana: $word: @words");
            } else {
                Irssi::print("Sana: $word: No translations.");
            }
        } else {
            Irssi::print("Sana failed.");
        }
    }
);
