#!/usr/bin/perl -w
# resets window activity status
#  by c0ffee 
#    - http://www.penguin-breeder.org/irssi/

#<scriptinfo>
use vars qw($VERSION %IRSSI);

use Irssi 20020120;
$VERSION = "0.13";
%IRSSI = (
    authors	=> "c0ffee",
    contact	=> "c0ffee\@penguin-breeder.org",
    name	=> "Reset window activity status",
    description	=> "Reset window activity status. defines command /act",
    license	=> "Public Domain",
    url		=> "http://www.penguin-breeder.org/irssi/",
    changed	=> "Wed Jun 23 08:34:53 CEST 2004",
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
sub cmd_act {
    my ($data, $server, $channel) = @_;

    if ($data eq "") {
      $level = 1;
    } elsif ($data =~ /^public$/i) {
      $level = 2;
    } elsif ($data =~ /^all$/i) {
      $level = 3;
    } else {
      Irssi::signal_emit("error command", -3, $data);
      return;
    }

    foreach (Irssi::windows()) {

      if ($_->{data_level} <= $level) {

        Irssi::signal_emit("window dehilight", $_);

      }

    }
}

my @arguments = ('public', 'all');
sub sig_complete ($$$$$) {
    my ($list, $window, $word, $linestart, $want_space) = @_;
    return unless $linestart =~ /^.act/;
    foreach my $arg (@arguments) {
      if ($arg =~ /^$word/i) {
        $$want_space = 0;
        push @$list, $arg;
      }
    }
    Irssi::signal_stop();
}


Irssi::command_bind("act", "cmd_act");
Irssi::signal_add_first('complete word', \&sig_complete);
