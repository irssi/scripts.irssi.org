# Map - Generates simple tree of IRC network based on the output of the LINKS
# command.
#
# $Id: map.pl,v 1.2 2002/02/01 22:21:20 pasky Exp pasky $


use strict;

use vars qw ($VERSION %IRSSI $rcsid);

$rcsid = '$Id: map.pl,v 1.2 2002/02/01 22:21:20 pasky Exp pasky $';
($VERSION) = '$Revision: 1.2 $' =~ / (\d+\.\d+) /;
%IRSSI = (
          name        => 'map',
          authors     => 'Petr Baudis',
          contact     => 'pasky@ji.cz',
          url         => 'http://pasky.ji.cz/~pasky/dev/irssi/',
          license     => 'GPLv2, not later',
          description => 'Generates simple tree of IRC network based on the output of the LINKS command.'
         );


my $root;  # The root lc(server)
my %tree;  # Key is lc(server), value is lc(array of downlinks)
my %rcase; # Key is lc(server), value is server
my %sname; # Key is lc(server), value is server's name
my @branches; # Index is level, value is (should_print_'|')


use Irssi 20011112;
use Irssi::Irc;


sub cmd_map {
  my ($data, $server, $channel) = @_;

  # ugly, but no easy way how to distinguish between two mixes links output :/
  $server->redirect_event('command map', 0, '',
      (split(/\s+/, $data) > 1), undef,
      {
	"event 364", "redir links_line",
	"event 365", "redir links_done",
      } );

  $server->send_raw("LINKS $data");

  Irssi::signal_stop();
}


sub event_links_line {
  my ($server, $data, $nick, $address) = @_;
  my ($target, $to, $from, $hops, $name) = $data =~ /^(\S*)\s+(\S*)\s+(\S*)\s+:(\d+)\s+(.*)$/;
  
  $rcase{lc($from)} = $from;
  $rcase{lc($to)} = $to;
  $sname{lc($to)} = $name;

  if ($hops == 0) {
    $root = lc($from);
  } else {
    push(@{$tree{lc($from)}}, lc($to));
  }

  Irssi::signal_stop();
}

sub event_links_done {
  my ($server, $data, $nick, $address) = @_;
  
  @branches = (' ');

  print_server($root, 0) if ($root);

  $root = undef;
}

sub print_server {
  my ($parent, $level, $last) = @_;
  my ($i, $str);

  for ($i = 0; $i < $level; $i++) {
    $str .= "   " . $branches[$i];
  }

  $str .= ($level ? "-" : " ") . " ";
  $str .= $rcase{$parent};
  $str = sprintf('%-50s %s', $str, $sname{$parent})
    if Irssi::settings_get_bool("show_server_names");

  Irssi::print $str;

  return unless ($tree{$parent});

  $branches[$level - 1] = ' '
    if ($level and $branches[$level - 1] eq '`');

  $branches[$level] = '|';

  while (@{$tree{$parent}}) {
    my ($server) = shift @{$tree{$parent}};
    
    $last = not scalar @{$tree{$parent}}; # sounds funny, eh? :^)
    $branches[$level] = '`' if ($last);
    
    print_server($server, $level + 1, $last);
  } 
}


Irssi::command_bind("map", "cmd_map");
Irssi::signal_add("redir links_line", "event_links_line");
Irssi::signal_add("redir links_done", "event_links_done");
Irssi::settings_add_bool("lookandfeel", "show_server_names", 1);

Irssi::Irc::Server::redirect_register("command map", 0, 0,
    {
      "event 364" => 1, # link line (wait...)
    },
    {
      "event 402" => 1,  # not found
      "event 263" => 1,  # try again
      "event 365" => 1,  # end of links
    },
    undef,
    );


Irssi::print("Map $VERSION loaded...");
