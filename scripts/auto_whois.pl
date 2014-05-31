# /WHOIS all the users who send you a private message.
# v0.9 for irssi by Andreas 'ads' Scherbaum
# idea and some code taken from autowhois.pl from Timo Sirainen
use Irssi;
use vars qw($VERSION %IRSSI); 

$VERSION = "0.9";
%IRSSI = (
    authors	=> "Andreas \'ads\' Scherbaum",
    contact	=> "ads\@ufp.de",
    name	=> "auto_whois",
    description	=> "/WHOIS all the users who send you a private message.",
    license	=> "GPL",
    url		=> "http://irssi.org/",
    changed	=> "2004-02-10",
    changes	=> "v0.9: don't /WHOIS if query exists for the nick already"
);

# History:
#  v0.9: don't /WHOIS if query exists for the nick already
#        now we store all nicks we have seen in the last 10 minutes

my @seen = ();

sub msg_private_first {
  my ($server, $msg, $nick, $address) = @_;

  # go through every stored connection and remove, if timed out
  my $time = time();
  my ($connection);
  my @new = ();
  foreach $connection (@seen) {
    if ($connection->{lasttime} >= $time - 600) {
      # is ok, use it
      push(@new, $connection);
      # all timed out connections will be dropped
    } 
  }
  @seen = @new;
}

sub msg_private {
  my ($server, $msg, $nick, $address) = @_;

  # look, if we already know this connection
  my ($connection, $a);
  my $known_to_us = 0;
  for ($a = 0; $a <= $#seen; $a++) {
    $connection = $seen[$a];
    # the lc() works not exact, because irc uses another charset
    if ($connection->{server} eq $server->{address} and $connection->{port} eq $server->{port} and lc($connection->{nick}) eq lc($nick)) {
      $known_to_us = 1;
      # mark as refreshed
      $seen[$a]->{lasttime} = time();
      last;
    }
  }

  if ($known_to_us == 1) {
    # all ok, return
    return;
  }

  # now store the new connection
  $connection = {};
  # store our own server data here
  $connection->{server} = $server->{address};
  $connection->{port} = $server->{port};
  # and the nick who queried us
  $connection->{nick} = $nick;
  $connection->{lasttime} = time();
  $connection->{starttime} = time();
  push(@seen, $connection);

  $server->command("whois $nick");
}

Irssi::signal_add_first('message private', 'msg_private_first');
Irssi::signal_add('message private', 'msg_private');
