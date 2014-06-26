use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.1";

%IRSSI = (
    authors     => 'Christian Brassat',
    contact     => 'crshd@mail.com',
    name        => 'smartfilter.pl',
    description => 'This script hides join/part messages.',
    license     => 'BSD',
    url         => 'http://crshd.github.io',
    changed     => '2012-10-02',
);

our $lastmsg = {};

sub smartfilter {
    my ($channel, $nick, $address, $reason) = @_;
    if ($lastmsg->{$nick} <= time() - Irssi::settings_get_int('smartfilter_delay')) {
        Irssi::signal_stop();
    }
};

sub log {
    my ($server, $msg, $nick, $address, $target) = @_;
    $lastmsg->{$nick} = time();
}

Irssi::signal_add('message public', 'log');
Irssi::signal_add('message join', 'smartfilter');
Irssi::signal_add('message part', 'smartfilter');
Irssi::signal_add('message quit', 'smartfilter');

Irssi::settings_add_int('smartfilter', 'smartfilter_delay', 300);
