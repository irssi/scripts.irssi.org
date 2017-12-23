#
# 2017-09-09 bcattaneo:
#  - initial release
#
# 2017-12-23 bcattaneo:
#  - Added filters
#

use IPC::Open3;
use strict;
use vars qw($VERSION %IRSSI);
use Irssi qw(command_bind active_win);

#
# Usage:
#	/toilet [message]
#
# Settings:
#	/set toilet_filters [Filters (separated with ":")]
#	/set toilet_font [Font name]
#
# Example:
# /set toilet_filters border:metal
# /set toilet_font small
# /toilet Hello!
#

our $VERSION = '1.1.0';
our %IRSSI = (
  authors     => 'bcattaneo',
  contact     => 'c@ttaneo.uy',
  name        => 'toilet',
  url         => 'http://github.com/bcattaneo',
  description => 'Simple toilet implementation for Irssi',
  license     => 'Public Domain',
  changed     => "2017-12-23",

  # safe implementation borrowed from figlet.pl:
  # Author: https://juerd.nl/site.plp/irssi
  # https://github.com/irssi/scripts.irssi.org/blob/master/scripts/figlet.pl

);

Irssi::settings_add_str('toilet', 'toilet_filters' => '');
Irssi::settings_add_str('toilet', 'toilet_font' => '');

command_bind (
  toilet => sub {
    my ($msg) = @_;
    my @toilet;
    my $i = 0;
    my @parm;
    push(@parm,'toilet');
    push(@parm,'--irc');
    my $filters = Irssi::settings_get_str('toilet_filters');
    my $font = Irssi::settings_get_str('toilet_font');
    if ($filters ne '') {
      push(@parm,'-F'.$filters);
    }
    if ($font ne '') {
      push(@parm,'-f'.$font);
    }
    my $pid = open3(undef, *TOILET, *TOILET, @parm, $msg);
    while (<TOILET>) {
      chomp;
      $toilet[$i++] .= $_;
    }
    close TOILET;
    waitpid $pid, 0;
    for (@toilet) {
      (my $copy = $_) =~ s/\cC\d*(?:,\d*)?|[\cB\cO\c_]//g;
      next unless $copy =~ /\S/;
      active_win->command("say $_");
    }
  }
);
