use strict;
use warnings;

our $VERSION = "1.0";
our %IRSSI = (
  authors     => 'David Leadbeater',
  contact     => 'dgl@dgl.cx',
  name        => 'oopsie',
  description => 'Stops those silly mistakes being sent (spaces at start of ' .
                 'line, /1/1 for window changes, etc).',
  license     => 'WTFPL <http://dgl.cx/licence>',
  url         => 'http://dgl.cx/irssi',
);

# /SET oopsie_chars_regexp [0-9]
# This can have nearly anything in it, but you may block some commands if
# you're not careful. \w may be useful (e.g. blocks "/ m foo bar") but \w+ is
# problematic (it would block /exec /some/file among other useful things,
# although if you're a bad typist maybe that is a reasonable trade-off).
Irssi::settings_add_str("misc", "oopsie_chars_regexp", "[0-9]");

my @words = qw(stopped prevented avoided inhibited forestalled averted deflected
  repelled);

Irssi::signal_add("send command" => sub {
  my ($command, $server, $rec) = @_;

  my $chars = Irssi::settings_get_str("cmdchars");
  my $cmdchars_re = qr/[$chars]/;
  my $oopsie_re = Irssi::settings_get_str("oopsie_chars_regexp");

  if ($command =~ /^\s+$cmdchars_re/ ||
      $command =~ /^$cmdchars_re(?:\s+$oopsie_re|$oopsie_re\s*$cmdchars_re)/) {
    Irssi::signal_stop();
    $rec->print("oopsie " . $words[rand @words] . ": $command", MSGLEVEL_CRAP);
  }
});

Irssi::signal_add("setup changed" => sub {
  if (" " =~ Irssi::settings_get_str("oopsie_chars_regexp")) {
    Irssi::active_win->print(
      "Your oopsie_chars_regexp matches a space. This is a very bad idea.");
  }
});
