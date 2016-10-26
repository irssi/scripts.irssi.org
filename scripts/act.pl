#!/usr/bin/perl -w
# resets window activity status
#  by c0ffee 
#    - http://www.penguin-breeder.org/irssi/

#<scriptinfo>
use strict;
use vars qw($VERSION %IRSSI);

use Irssi 20020120;
$VERSION = "0.14";
%IRSSI = (
    authors	=> "c0ffee",
    contact	=> "c0ffee\@penguin-breeder.org",
    name	=> "Reset window activity status",
    description	=> "Reset window activity status. defines command /act",
    license	=> "Public Domain",
    url		=> "http://www.penguin-breeder.org/irssi/",
    changed	=> "Thu Apr 16 15:55:05 BST 2015",
);
#</scriptinfo>

#
# /ACT [PUBLIC|ALL]
#
# /ACT without parameters marks windows as non-active where no
# public talk occured.
#
# /ACT PUBLIC also removes those where no nick hilight was triggered
#
# /ACT ALL sets all windows as non-active

Irssi::command_bind('act', sub { _act(1); });
Irssi::command_bind('act public', sub { _act(2); });
Irssi::command_bind('act all', sub { _act(3); });

sub _act {
  my($level) = @_;
  for (Irssi::windows()) {
    if ($_->{data_level} <= $level) {
      Irssi::signal_emit("window dehilight", $_);
    }
  }
}
