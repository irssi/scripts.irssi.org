#
#   fortune
#
#   Edited by:
#   Ivo Marino <eim@cpan.org> 1.3 2004/12/17
#   bw1 <bw1@aol.at>          1.4 2019/05/30
#
#   Required (Debian) packages:
#
#       . fortune-mod       The fortune core binaries
#       . fortunes-min      Basic english fortune cookies
#
#   Optional (Debian) packages:
#
#       . fortunes-de       German fortune cookies
#       . fortunes-it       Italian fortune cookies
#
#   Usage:
#
#       Inside Irssi write: /fortune [nick] [-h] [-o options]
#       The optional [options] parameter can be:
#
#           . en            English
#           . de            German
#           . it            Italian
#           or anything else what the fortune command provide
#
#       If not defined the fortune script defaults to en.
#
#   Settings:
#
#       fortune_command
#       fortune_default_args
#
#   TODO:
#
#       . Check if specified user exists.
#       . Handle direct user messaging.
#

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Getopt::Long qw/GetOptionsFromString/;
$VERSION = '1.4';
%IRSSI = (
    authors     => 'Ivo Marino',
    contact     => 'eim@cpan.rg',
    name        => 'fortune',
    description => 'Send a random fortune cookie to an user in channel.',
    license     => 'Public Domain',
);

my ($nargs, $help);
my %opts = (
    'h' => \$help,
    'o=s' => \$nargs,
);

sub fortune {

    my ($param, $server, $witem) = @_;
    my $return = 0;
    my $cookie = '';
    my $cmd = Irssi::settings_get_str($IRSSI{name}.'_command');
    my $args = Irssi::settings_get_str($IRSSI{name}.'_default_args');
    my ($ret, $arg)= GetOptionsFromString($param, %opts) or $help=1;
    my $nick = $arg->[0];

    if (!defined $help) {

        if ($server || $server->{connected}) {

            #Irssi::print ("Nick: " . $nick . ", Lang: \"" . $lang . "\"");

            $args = $nargs if (defined $nargs);
            $cookie = `$cmd $args`;

            $cookie =~ s/\s*\n\s*/ /g;

            if ($cookie) {

                if ($witem && ($witem->{type} eq "CHANNEL")) {
                    if (defined $nick) {
                        $witem->command('MSG ' . $witem->{name} . ' ' . $nick . ': ' . $cookie);
                    } else {
                        $witem->command('MSG ' . $witem->{name} .' '. $cookie);
                    }
                } else {
                    Irssi::print ($cookie);
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

        Irssi::print ("Usage: /fortune [nick] [-h] [-o options]");
        $return = 1;
    }

    $nick = undef;
    $nargs= undef;
    $help = undef;

    return $return;
}

Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_command', 'fortune');
Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_default_args', '');

Irssi::command_bind ('fortune', \&fortune);

# vim:set expandtab sw=4 ts=4:
