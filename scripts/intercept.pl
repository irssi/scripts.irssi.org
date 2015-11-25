# Some elements borrowed from ideas developed by shabble@freenode(https://github.com/shabble/irssi-docs/wiki )
#
# You can change what intercept.pl considers a linestart by setting
# /set intercept_linestart to a regular expression that fits your needs.
# For most, a simple whitespace or . pattern will stop most accidental
# inputs.
#
# You can also tell which patterns should be ignored, for example
# /set intercept_exceptions s/\w+/[\w\s\d]+/ wouldn't consider
# s/word a mistyped command if it is followed by a slash, string of
# valid characters and a final slash.
# You can enter several patterns separated by a space.

use strict;
use warnings;
use Data::Dumper;
use Carp qw( croak );
use Irssi;

use vars qw($VERSION %IRSSI);

$VERSION = "0.2";
%IRSSI = (
              authors     => "Jari Matilainen",
              contact     => 'vague!#irssi@freenode on irc',
              name        => "intercept",
              description => "Intercept misprinted commands and offer to remove the first character before sending it on",
              license     => "Public Domain",
              url         => "http://gplus.to/vague",
              changed     => "24 Nov 16:00:00 CET 2015",
             );

my $active = 0;
my $permit_pending = 0;
my $pending_input = {};
my $verbose = 0;

sub script_is_loaded {
  return exists($Irssi::Script::{$_[0] . '::'});
}

if (script_is_loaded('uberprompt')) {
  app_init();
}
else {
  print "This script requires 'uberprompt.pl' in order to work. "
      . "Attempting to load it now...";

  Irssi::signal_add('script error', 'load_uberprompt_failed');
  Irssi::command("script load uberprompt.pl");

  unless(script_is_loaded('uberprompt')) {
    load_uberprompt_failed("File does not exist");
  }
  app_init();
}

sub load_uberprompt_failed {
  Irssi::signal_remove('script error', 'load_uberprompt_failed');

  print "Script could not be loaded. Script cannot continue. "
      . "Check you have uberprompt.pl installed in your scripts directory and "
      . "try again.  Otherwise, it can be fetched from: ";
  print "https://github.com/shabble/irssi-scripts/raw/master/"
      . "prompt_info/uberprompt.pl";

  croak "Script Load Failed: " . join(" ", @_);
}

sub sig_send_text {
  my ($data, $server, $witem) = @_;

  if($permit_pending == 1) {
    $pending_input = {};
    $permit_pending = 0;
    Irssi::signal_continue(@_);
  }
  elsif($permit_pending == 2) {
    my $regexp = Irssi::settings_get_str('intercept_linestart');
    $pending_input = {};
    $permit_pending = 0;
    Irssi::signal_stop();
    $data =~ s/^$regexp//;

    if(ref $witem && $witem->{type} eq 'CHANNEL') {
      $witem->command($data);
    }
    else {
      $server->command($data);
    }
  }
  else {
    (my $cmdchars = Irssi::settings_get_str('cmdchars')) =~ s/(.)(.)/$1|$2/;
    my @exceptions = split / /, Irssi::settings_get_str('intercept_exceptions');

    foreach(@exceptions) {
      return if($data =~ m{$_}i);
    }

    my $regexp = Irssi::settings_get_str('intercept_linestart');
    $regexp =~ s/(^[\^])|([\$]$)//g;
    if($data =~ /^($regexp)($cmdchars)/i) {
      my $text = "You have " . ($1 eq ' '?'a space':$1) . " infront of your cmdchar '$2', is this what you wanted? [y/F/c]";
      $pending_input = {
                         text     => $data,
                         server   => $server,
                         win_item => $witem,
                       };

      Irssi::signal_stop();
      require_confirmation($text);
    }
  }
}

sub sig_gui_keypress {
  my ($key) = @_;

  return if not $active;

  my $char = chr($key);

  # we support f, F, enter for Fix.
  if($char =~ m/^f?$/i) {
    $permit_pending = 2;
    Irssi::signal_stop();
    Irssi::signal_emit('send text',
                        $pending_input->{text},
                        $pending_input->{server},
                        $pending_input->{win_item});
    $active = 0;
    set_prompt('');
  }
  elsif($char =~ m/^y$/i) {
    # y or Y for send as is
    $permit_pending = 1;
    Irssi::signal_stop();
    Irssi::signal_emit('send text',
                        $pending_input->{text},
                        $pending_input->{server},
                        $pending_input->{win_item});
    $active = 0;
    set_prompt('');
  }
  elsif ($char =~ m/^c$/i or $key == 3 or $key == 7) {
    # we support c, C, Ctrl-C, and Ctrl-G for don't send
    Irssi::signal_stop();
    set_prompt('');
    $permit_pending = 0;
    $active         = 0;
    $pending_input  = {};
  }
  else {
    Irssi::signal_stop();
    return;
  }
}

sub app_init {
  Irssi::signal_add_first("send text"       => \&sig_send_text);
  Irssi::signal_add_first('gui key pressed' => \&sig_gui_keypress);
  Irssi::settings_add_str('Intercept', 'intercept_exceptions', 's/\w+/[\w\s\d]+/');
  Irssi::settings_add_str('Intercept', 'intercept_linestart', '\s');
}

sub require_confirmation {
  $active = 1;
  set_prompt(shift);
}

sub set_prompt {
  my ($msg) = @_;
  $msg = ': ' . $msg if length $msg;
  Irssi::signal_emit('change prompt', $msg, 'UP_INNER');
}

sub _debug {
  return unless $verbose;

  my ($msg, @params) = @_;
  my $str = sprintf($msg, @params);
  print $str;
}
