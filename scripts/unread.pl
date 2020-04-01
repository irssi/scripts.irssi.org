#!/usr/bin/perl
# reset window to unread status

use strict;
use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.1';
%IRSSI = (
    authors => 'Gregory Colpart',
    contact => 'reg on #evolix@freenode',
    name => 'unread',
    description => 'reset window to unread status',
    license => 'GPLv2 or later',
    changed => '2020-04-01'
);

# copy unread.pl to ~/.irssi/scripts/
# /load unread.pl
# /unread <window number>

Irssi::command_bind 'unread' => sub {
    my ( $data, $server, $item ) = @_;
    $data =~ s/\s+$//g;
    Irssi::window_find_refnum($data)->activity(3);
};

