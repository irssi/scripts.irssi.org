use Irssi;
use strict;
use warnings;
use Text::ParseWords;
use vars qw($VERSION %IRSSI); 
$VERSION = "2.1";
%IRSSI = (
  authors     => "Liam Hopkins",
  contact     => "we.hopkins\@gmail.com",
  name        => "betterlist",
  description => "/list <perl-regexp>",
  license     => "GPL",
);


my $running = 0; # flag to prevent overlapping requests.
my $match;

sub call_list_cmd {
  my ($server, $args) = @_;

  # set a one-time redirect for handling responses of a given command
  $server->redirect_event('list', 1, '', -1, 'redir my_timeout',
    {
      'event 321' => 'redir my_liststart',
      'event 322' => 'redir my_list',
      'event 323' => 'redir my_listend',
      ''          => 'event empty',
    });

  # execute the command
  $server->send_raw("LIST");
}

sub event_list {
    my ($server, $data) = @_;
    my $channel = ( split / +/, $data)[1];

    Irssi::active_win->print("Matched $channel", MSGLEVEL_CLIENTCRAP) if ($channel =~ /$match/)
 }

sub event_liststart {
  Irssi::active_win->print("Looking for $match", MSGLEVEL_CLIENTCRAP);
}

sub event_listend {
  Irssi::active_win->print("End of /LIST", MSGLEVEL_CLIENTCRAP);
  $running = 0;
}

sub event_timeout {
  my ($server, $data) = @_;
  Irssi::print("timeout", MSGLEVEL_CLIENTCRAP);
  $running = 0;
}

sub betterlist {
  my ($data, $server, $witem) = @_;

  if ($running) {
    Irssi::active_win->print("please try again shortly.", MSGLEVEL_CLIENTCRAP);
    return;
  } 
  $running = 1;
  my (@args)  = &quotewords(' ', 1, $data);
  ($match) = &quotewords(' ', 0, shift(@args));
  call_list_cmd($server);
  Irssi::signal_stop();
}

Irssi::signal_add_first ({
    'redir my_liststart'       => 'event_liststart',
    'redir my_list'            => 'event_list',
    'redir my_listend'         => 'event_listend',
});

Irssi::command_bind("betterlist", \&betterlist);
