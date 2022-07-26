##
## Put me in ~/.irssi/scripts, and then execute the following in irssi:
##
##       /load perl
##       /script load notify
##

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.01";
%IRSSI = (
    authors     => 'Luke Macken, Paul W. Frields',
    contact     => 'lewk@csh.rit.edu, stickster@gmail.com',
    name        => 'notify.pl',
    description => 'Use libnotify to alert user to hilighted messages',
    license     => 'GNU General Public License',
    url         => 'http://lewk.org/log/code/irssi-notify',
);


sub notify {
    my ($server, $summary, $message) = @_;

    # Make the message entity-safe
    $message =~ s/&/&amp;/g; # That could have been done better.
    $message =~ s/</&lt;/g;
    $message =~ s/>/&gt;/g;
    $message =~ s/'/&apos;/g;

    my $cmd = "EXEC - dunstify --action='replyAction,reply'" .
	" '" . $summary . "'" .
	" '" . $message . "' &>/dev/null";

    $server->command($cmd);
}
 
sub print_text_notify {
    my ($dest, $text, $stripped) = @_;
    my $server = $dest->{server};

    return if (!$server || !($dest->{level} & (MSGLEVEL_HILIGHT | MSGLEVEL_NOTICES)));
    notify($server, $dest->{target}, $stripped);
}

sub private_msg_notify {
    my ($server, $msg, $nick, $address) = @_;

    return if (!$server);
    notify($server, "Private message from ".$nick, $msg);
}

Irssi::signal_add('print text', 'print_text_notify');
Irssi::signal_add('message private', 'private_msg_notify');
