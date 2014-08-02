# tmux.pl - set away when tmux session is detached
#
# Copyright (c) 2014 Martin Natano <natano@natano.net>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use strict;
use warnings;
use Irssi;
use vars qw/$VERSION %IRSSI/;

$VERSION = '1.0';
%IRSSI = (
    authors     => 'Martin Natano',
    contact     => 'natano@natano.net',
    name        => 'tmux',
    description => 'set away when tmux session is detached',
    license     => 'ISC',
);

return if (!defined($ENV{TMUX}));

my $attached = list_clients();

sub list_clients {
    my $session_name = `tmux display -p '#{session_name}'`;
    my $clients = `tmux list-clients -t $session_name`;
    return $clients =~ tr/\n//;
}

sub check_status {
    my $clients = list_clients();

    if ($clients && !$attached) {
        Irssi::command('foreach server /away -one')
    } elsif (!$clients && $attached) {
        Irssi::command('foreach server /away -one afk')
    }
    $attached = $clients;
}

Irssi::timeout_add(1000, 'check_status', undef);
