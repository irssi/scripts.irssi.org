#!/usr/bin/perl
# vim: ts=2 sw=2 expandtab

# Ack: Jump to the next active window, with tiebreakers.

use warnings;
use strict;

use Irssi;

### Script header.

our $VERSION = '1.000';

use vars qw(%IRSSI);
%IRSSI = (
  name        => 'ack',
  authors     => 'Rocco Caputo',
  contact     => 'rcaputo@cpan.org',
  url         => 'http://github.com/rcaputo/irssi-ack',
  license     => 'Perl',
  description => 'Jump to the next active window, with tiebreakers.',
);

# Jump to an active channel.

sub cmd_ack {
  my ($cmd, $server, $window) = @_;

  # We sort the data_level in reverse order because higher numbers
  # mean "more important".  If the data_level is equal between two
  # windows, then we jump to the window that has been upbated least
  # recently.
  #
  # Currently that's the window with the earliest (oldest) last line
  # of text.

  my @windows = sort {
    ($b->{data_level} <=> $a->{data_level}) ||
    ($a->{last_line}  <=> $b->{last_line} )
  }
  grep { $_->{data_level} }  # Must have some activity.
  Irssi::windows();

  # Jump to the first window.  How hard can it be?
  $windows[0]->set_active() if @windows;
}

# Usage: /ack ... probably bind it to Meta-A or something.
Irssi::command_bind("ack", "cmd_ack");
