# Page script 0.2
#
# Thomas Graf <irssi@reeler.org>

use strict;
use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI);
$VERSION = "0.2";
%IRSSI = (
    authors     => 'Thomas Graf',
    contact     => 'irssi@reeler.org',
    name        => 'page',
    description => 'display and send CTCP PAGE',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.reeler.org/',
);

sub sig_ctcp_msg
{
    my ($server, $args, $sender, $addr, $target) = @_;

    if ( $args =~ /page/i ) {
        Irssi::active_win()->printformat(MSGLEVEL_CRAP, 'page', "$sender!$addr is paging you!");
        Irssi::signal_stop();
    }
}

sub sig_page
{
    my ($cmd_line, $server, $win_item) = @_;
    my @args = split(' ', $cmd_line);

    if (@args <= 0) {
        Irssi::active_win()->print("Usage: PAGE <nick>");
        return;
    }

    my $nick = lc(shift(@args));

    $server->command("CTCP $nick PAGE");
}

Irssi::signal_add_first('default ctcp msg', 'sig_ctcp_msg');
Irssi::command_bind('page', 'sig_page');

Irssi::theme_register(['page', '[%gPAGE%n]$0-']);
