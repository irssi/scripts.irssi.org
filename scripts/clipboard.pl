use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Irssi::Irc;
use Tk;

$VERSION = '1.2';
%IRSSI = (
authors     => 'Dominic Battre',
contact     => 'dominic@battre.de',
name        => 'Quoting from X clipboard',
description => 'Better quoting of content from clipboard (without leading spaces) -- requires Perl/Tk',
license     => 'Public Domain',
url         => 'http://www.battre.de',
changed     => 'Fri Dec  6 23:23:31 CET 2002',
);

# if you quote long lines by selecting the text and inserting via middle
# mousebutton you get something like this:
# 23:12 <@DominicB> 23:11 <@DominicB> This is a very long line. This is a very
#                   long line. This is a
# 23:12 <@DominicB>                   very long line. This is a very long line.
#                   This is a very long
# 23:12 <@DominicB>                   line.
#
# this script queries the clipboard of X11, strips leading blanks and
# joins lines if needed so the result would be
# 23:16 <@DominicB> 23:11 <@DominicB> This is a very long line. This is a very
#                   long line. This is a very long line. This is a very long
#                   line. This is a very long line.
#
# just execute by /qc ("quote clipboard")
# for print only use /qc -p 


# Known problem
# if you
# 1) connect via `ssh -X user@localhost`
# 2) start `screen irssi`
# 3) use /qc,
# 4) disconnect ssh
# 5) reconnect via `ssh -X user@localhost`
# 6) `screen -R -D`
# 7) use /qc again
# => screen and along with it irssi terminate
# the problem persists if you try
# perl -e 'use Tk;print MainWindow->new->SelectionGet("-selection","CLIPBOARD")'
# in a ssh -X/screen environment. Thus it seems to be a problem of
# X forwarding - not of Perl/Tk

# credits to 
#
# Hugo Haas          for s/CLIPBOARD/PRIMARY/ (using PRIMARY instead of
#                    CLIPBOARD in order to use highlighted text instead of the
#                    X clipboard (identical to middle clicking)
#
# Clemens Heidinger  using Irssi::print() now if /qc is executed outside a channel/query
#                    -p for printing only

Irssi::command_bind('qc','cmd_quoteclipboard');

sub cmd_quoteclipboard {
    my ($arguments, $server, $witem) = @_;

    my $main = MainWindow->new;
    my $text = $main->SelectionGet('-selection','PRIMARY');
    $main->destroy();

    my $sendMsg = ( $arguments !~ /-p/ &&  # no parameter -p
                     defined($witem) && $witem &&
                    ($witem->{'type'} eq 'CHANNEL' || $witem->{'type'} eq 'QUERY') )
                  ? sub { $server->command("msg $witem->{'name'} @_[0]"); }
                  : sub { Irssi::print(@_[0], MSGLEVEL_CRAP); };

    my $prev = "";

    while ( $text =~ /^( *)(.*)$/gm ) {
        if ( $1 eq "" and $prev ne "") {
            $sendMsg->($prev);
            $prev = "$2 ";
        } else {
            $prev .= "$2 ";
        }
    }

    if ( $prev ne "" ) {
        $sendMsg->($prev);
    }
}
