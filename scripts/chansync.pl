# by Uwe 'duden' Dudenhoeffer
#
# chansync.pl


use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '0.22';
%IRSSI = (
    authors     => 'Uwe \'duden\' Dudenhoeffer',
    contact     => 'script@duden.eu.org',
    name        => 'chansync',
    description => '/who a channel and optionaly executes a command',
    license     => 'GPLv2',
    url         => '',
    changed     => 'Sun Feb  9 18:27:51 CET 2003',
    commands	=> 'chansync',
);

# Changelog
#
# 0.22
#   - added "commands => chansync"
#
# 0.21
#   - some design issues
#
# 0.2
#   - used "silent event who" instead of stopping "print text"
#
# 0.1
#   - first working version

use Irssi 20020324;
use POSIX;

my(%arguments,%items);

# Usage: /chansync [command]
sub cmd_chansync {
  my($args, $server, $item) = @_;
  return if not ($item && $item->{type} eq "CHANNEL");
  my($chan) = $item->{name};
  $server->redirect_event('who', 1, $chan, -1, undef,
                         {
                          "event 315" => "redir chansync endwho",
                          "event 352" => "redir chansync who",
                          "" => "event empty",
                         });
  $server->send_raw("WHO $chan");
  $arguments{lc $chan} = $args;
  $items{lc $chan} = $item;
}

sub sig_event_block {
  Irssi::signal_stop();
}

sub sig_redir_chansync_who {
  Irssi::signal_emit('silent event who', @_);
}

sub sig_redir_chansync_endwho {
  my($server) = shift;
  my(@text) = split " ", shift;
  my($cmd) = $arguments{lc @text[1]};
  $items{lc @text[1]}->command("$cmd");
  delete $arguments{lc @text[1]};
  delete $items{lc @text[1]};
}

Irssi::command_bind("chansync", "cmd_chansync");
Irssi::signal_add('redir chansync who', 'sig_redir_chansync_who');
Irssi::signal_add('redir chansync endwho', 'sig_redir_chansync_endwho');
