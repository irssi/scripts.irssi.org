#!/usr/bin/env perl

use strict;
use vars qw($VERSION %IRSSI);
use Irssi;

$VERSION = "20151026";
%IRSSI = (
    authors     => "Philip Paeps",
    contact     => "philip\@trouble.is",
    name        => "suppress_yubikey_otp",
    description => "This script stops accidental YubiKey output on IRC",
    license     => "BSD",
    changed     => "$VERSION",
);

sub event_send_text {
    my ($line, $server_rec, $wi_item_rec) = @_;
    Irssi::signal_stop() if $line =~ /^cccccc/;
}
Irssi::signal_add_first('send text', \&event_send_text);
