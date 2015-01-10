# $Id: userhost.pl,v 1.18 2002/07/04 13:18:02 jylefort Exp $
use strict;
use Irssi 20020121.2020 ();
use vars qw($VERSION %IRSSI);
$VERSION = "0.23";
%IRSSI = (
	  authors     => 'Jean-Yves Lefort',
	  contact     => 'jylefort\@brutele.be, decadix on IRCNet',
	  name        => 'userhost',
	  description => 'Adds a -cmd option to the /USERHOST builtin command',
	  license     => 'BSD',
	  url         => 'http://void.adminz.be/irssi.shtml',
	  changed     => '$Date: 2002/07/04 13:18:02 $ ',
);

# usage:
#
#	/USERHOST <nicks> [-cmd <command>]
#
#	-cmd		evaluate the specified Irssi command
#
# percent substitutions in command:
#
#	%n		nick
#	%u		user
#	%h		host
#	%%		a single percent sign
#
# examples:
#
#	/userhost albert -cmd echo %n is %u at %h
#	/userhost john james -cmd exec xterm -e ping %h
#
# changes:
#
#	2002-07-04	release 0.23
#			* signal_add's uses a reference instead of a string
#
#	2002-02-08	release 0.22
#			* safer percent substitutions
#
#	2002-01-27	release 0.21
#			* uses builtin expand
#
#	2002-01-24	release 0.20
#			* now replaces builtin /USERHOST
#
#	2002-01-23	initial release

# -verbatim- import expand
sub expand {
  my ($string, %format) = @_;
  my ($len, $attn, $repl) = (length $string, 0);
  
  $format{'%'} = '%';

  for (my $i = 0; $i < $len; $i++) {
    my $char = substr $string, $i, 1;
    if ($attn) {
      $attn = undef;
      if (exists($format{$char})) {
	$repl .= $format{$char};
      } else {
	$repl .= '%' . $char;
      }
    } elsif ($char eq '%') {
      $attn = 1;
    } else {
      $repl .= $char;
    }
  }
  
  return $repl;
}
# -verbatim- end

my $queuedcmd;

sub userhost_reply {
  if ($queuedcmd) {
    my ($server, $args, $sender, $sender_address) = @_;
    if ($args =~ / :(.*)$/) {
      foreach (split(/ /, $1)) {
	$server->command(expand($queuedcmd, "n", $1, "u", $2, "h", $3))
	  if (/(.*)\*?=[-+][-+~]?(.*)@(.*)/);
      }
    }
    $queuedcmd = undef;
    Irssi::signal_stop();
  }
}

sub userhost {
  my ($args, $server, $item) = @_;
  my ($nicks, $command) = split(/ -cmd /, $args);
  if ($queuedcmd = $command) {
    $server->send_raw("USERHOST :$nicks");
    Irssi::signal_stop();
  }
}

Irssi::signal_add("event 302", \&userhost_reply);
Irssi::command_bind("userhost", \&userhost);
