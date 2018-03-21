# Settings:
# window_hidden_levels - levels to hide/show with below commands
# Included commands:
# /window togglelevel  - hide/show levels in active window
# /show_levels_all     - show levels in all windows
# /hide_levels_all     - hide levels in all windows

use strict;
use warnings;
use Irssi v1.1;
use Irssi::TextUI;
use Data::Dumper;
use vars qw($VERSION %IRSSI);

$VERSION = "0.3.1";
%IRSSI = (
          authors       => 'Jari Matilainen',
          contact       => 'vague!#irssi@freenode on irc',
          name          => 'toggle_winlevels',
          description   => 'Toggle hidden levels on per window basis',
          licence       => "GPLv2",
          changed       => "17.01.2018 01:00pm CET"
);

my $windows;
my $processing = 0;

sub set_mode_all {
  my ($mode) = @_;
  for my $win (Irssi::windows) {
    set_mode($win, $mode);
  }
}

sub set_mode {
  my ($win, $mode) = @_;
  my $lvlbits = ($win->view->{hidden_level} - Irssi::level2bits('HIDDEN')) || ($windows->{$win->{refnum}}{levels} ? $windows->{$win->{refnum}}{levels} - Irssi::level2bits('HIDDEN') : 0);
  my $levels = Irssi::bits2level($lvlbits);
  my $val;

  unless($levels && length $levels) {
    $val = '-ALL +HIDDEN';
    $windows->{$win->{refnum}}{mode} = 0;
  }
  else {
    $mode = ($windows->{$win->{refnum}}{mode} // 0) ^ 1 unless defined $mode;
    $val = $levels =~ s/(\w+)/sprintf("%s%s", $mode ? '+' : '-', $1)/gre;
    $windows->{$win->{refnum}}{mode} = $mode;
  }

  if($val) {
    $processing += 1;
    $win->command("^window hidelevel $val");
  }
}

Irssi::signal_add('message join' => sub {
  my ($server, $target, $nick) = @_;
  return unless $server->{nick} eq $nick;

  my $win = $server->window_find_item($target);
  my $levels = $win->view->{hidden_level};
  $windows->{$win->{refnum}}{levels} = $levels - Irssi::level2bits('HIDDEN') ? $levels : Irssi::settings_get_level('window_default_hidden_level');
  $windows->{$win->{refnum}}{mode}   = $levels - Irssi::level2bits('HIDDEN') ? 1 : 0;
  set_mode($win, 1) unless $levels - Irssi::level2bits('HIDDEN');
});

Irssi::signal_add('window destroyed' => sub {
  my ($win) = @_;
  delete $windows->{$win->{refnum}};
});

Irssi::signal_add('window refnum changed' => sub {
  my ($win, $old_refnum) = @_;
  $windows->{$win->{refnum}} = $windows->{$old_refnum};
  delete $windows->{$old_refnum};
});

Irssi::command_bind('hide_levels_all' => sub {
  set_mode_all(1);
});

Irssi::command_bind('show_levels_all' => sub {
  set_mode_all(0);
});

Irssi::command_bind('window togglelevel' => sub {
  my ($args, $server, $witem) = @_;
  return unless $witem;
  set_mode($witem->window, undef);
});

Irssi::command_bind_last('window hidelevel' => sub {
  my ($args, $server, $witem) = @_;

  if($processing) {
    $processing -= 1;
    return;
  }

  return unless $witem;

  if($args) {
    my $levels = $witem->window->view->{hidden_level};
    $windows->{$witem->window->{refnum}}{levels} = $levels;
    $windows->{$witem->window->{refnum}}{mode}   = $levels - Irssi::level2bits('HIDDEN') ? 1 : 0;
  }
});

Irssi::command_bind('dump_window_hash' => sub {
  for my $key (keys %$windows) {
    warn Dumper($key, Irssi::bits2level($windows->{$key}{levels}), $windows->{$key}{mode});
  }
});

Irssi::settings_add_level('lookandfeel', 'window_default_hidden_level', 'HIDDEN');

for my $win (Irssi::windows) {
  my $view = $win->view();
  my $levels = ($view->{hidden_level} ? $view->{hidden_level} - Irssi::level2bits('HIDDEN') : 0) || ($windows->{$win->{refnum}}{levels} ? $windows->{$win->{refnum}}{levels} - Irssi::level2bits('HIDDEN') : 0);
  $windows->{$win->{refnum}}{levels} = $levels // Irssi::settings_get_level('window_default_hidden_level');
  $windows->{$win->{refnum}}{mode}   = $levels ? 1 : 0;
}
