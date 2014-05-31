#
#   fortune
#
#   Edited by: Ivo Marino <eim@cpan.org>
#   $Id: fortune.pl,v 1.3 2004/12/17 19:39:19 eim Exp $
#
#   Required (Debian) packages:
#
#       . fortune-mod       The fortune core binaries
#       . fortunes-min      Basic english fortune cookies
#       . fortunes-de       German fortune cookies
#       . fortunes-it       Italian fortune cookies
#
#   Usage:
#
#       Inside a channel write: /fortune <nick> [lang]
#       The optional [lang] parameter can be:
#
#           . en            English
#           . de            German
#           . it            Italian
#
#       If not defined the fortune script defaults to en.
#
#   TODO:
#
#       . Check if specified user exists.
#       . Handle direct user messaging.
#

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '$Id: fortune.pl,v 1.3 2004/12/17 19:39:19 eim Exp $';
%IRSSI = (
    authors     => 'Ivo Marino',
    contact     => 'eim@cpan.rg',
    name        => 'fortune',
    description => 'Send a random fortune cookie to an user in channel.',
    license     => 'Public Domain',
);

sub fortune {

    my ($param, $server, $witem) = @_;
    my $return = 0;
    my $cookie = '';

    if ($param) {

        if ($server || $server->{connected}) {

            (my $nick, my $lang) = split (' ', $param);

            $lang = 'en' unless ($lang eq 'de'|| $lang eq 'it' || $lang eq 'en');

            Irssi::print ("Nick: " . $nick . ", Lang: \"" . $lang . "\"");

            if ($lang eq 'de') {

                $cookie = `fortune -x`;

            } elsif ($lang eq 'it') {

                $cookie = `fortune -a italia`;

            } else {

                $cookie = `fortune.en -a fortunes literature riddles`;
            }

            $cookie =~ s/\s*\n\s*/ /g;

            if ($cookie) {

                if ($witem && ($witem->{type} eq "CHANNEL")) {

                        $witem->command('MSG ' . $witem->{name} . ' ' . $nick . ': ' . $cookie);
                }

            } else {

                Irssi::print ("No cookie.");
                $return = 1;
            }

        } else {

            Irssi::print ("Not connected to server");
            $return = 1;
        }

    } else {

        Irssi::print ("Usage: /fortune <nick> [language]");
        $return = 1;
    }

    return $return;
}

Irssi::command_bind ('fortune', \&fortune);
