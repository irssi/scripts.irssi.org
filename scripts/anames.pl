# anames.pl
# Irssi script that adds an /anames command, a clone of /names, with away nicks
# grayed out.
#
# Thanks to Dirm and Chris62vw for the Perl help and coekie for writing the
# evil code to sort the nicklist by the alphabet and rank in nicklist.pl
#
# 1.5   - Fixed halfop display bug (patch by epinephrine), 20100712
#
# 1.4   - Merged changes from VMiklos and readded /who redirection to prevent
#         spamming the status window. - ms, 20090122
#
# 1.3   - by VMiklos
#         Doing /dowho is very annoying and /alias foo /dowho;/anames won't
#         work either since anames will work from the old infos. So I've
#         modified /anames to just do a /dowho and the nicklist will be printed
#         when we'll get the answer from the server.
#
# 1.2   - It seems that redirected events will not pass through the internal
#         mechanisms that update user information (like away states). So, it
#         /dowho and the periodic execution of the command has been disabled.
#         /anames will still work, but new away information will need to be
#         obtained by executing a /who on a channel.
#         If you can make redirection (execute a /who without the information
#         spilling to the status window) work, let me know so I can fix the
#         script.
#
# 1.0.1 - Fixed row-determining and max-nick-length code, changed command_add
#         calls to refs instead of names.
#
# 1.0   - Added timer for periodic /who of all channels
#
# 0.9   - Initial test release

use strict;
use Irssi;
use POSIX;
#use Data::Dumper;

use vars qw($VERSION %IRSSI);

$VERSION = '1.5';
%IRSSI = (
  authors     => 'Matt "f0rked" Sparks, Miklos Vajna',
  contact     => 'ms+irssi@quadpoint.org',
  name        => 'anames',
  description => 'a /names display with away nicks colored',
  license     => 'GPLv2',
  url         => 'http://quadpoint.org',
  changed     => '2010-07-12',
);

# How often to do a /who of all channels (in seconds)
#my $who_timer = 300;

my $tmp_server;
my $tmp_chan;


sub cmd_anames
{
  my($args, $server, $item) = @_;
  my $channel = Irssi::active_win->{active};
  $tmp_server = $server;
  $tmp_chan = $channel->{"name"};

  if ($args ne "") {
    $server = $args;
    $server =~ s/-([^ ]*) .*/\1/;
    $tmp_server = Irssi::server_find_tag($server);
    $tmp_chan = $args;
    $tmp_chan =~ s/-[^ ]* (.*)/\1/;
  }

  # set up redirection
  $tmp_server->redirect_event("who", 1, $tmp_chan, 0, undef,
                              {
                                "event 352" => "redir who_reply",
                                "event 315" => "redir who_reply_end",
                              });

  $tmp_server->command("who $tmp_chan");
}


sub print_anames
{
  my $server = $tmp_server;
  my $chan = $tmp_chan;
  my $channel = Irssi::Server::channel_find($server, $chan);
  my $nick;

  if (!$channel) {
    # no nicklist
    Irssi::print("Not joined to any channel", MSGLEVEL_CLIENTERROR);
  } else {
    # Loop through each nick and display
    my @nicks;
    my($ops, $halfops, $voices, $normal, $away) = (0, 0, 0, 0, 0);

    # sorting from nicklist.pl
    foreach my $nick (sort {(($a->{'op'}?'1':$a->{'halfop'}?'2':$a->{'voice'}?'3':'4').lc($a->{'nick'}))
                      cmp (($b->{'op'}?'1':$b->{'halfop'}?'2':$b->{'voice'}?'3':'4').lc($b->{'nick'}))} $channel->nicks()) {
      my $realnick = $nick->{'nick'};
      my $gone = $nick->{'gone'};

      my $prefix;
      if ($nick->{'op'}) {
        $prefix = "@";
        $ops++;
      } elsif ($nick->{'halfop'}) {
        $prefix = "%%";
        $halfops++;
      } elsif ($nick->{'voice'}) {
        $prefix = "+";
        $voices++;
      } else {
        $prefix = " ";
        $normal++;
      }

      $prefix = "%W$prefix%n";
      if ($gone) {
        $realnick = "%K$realnick%n";
        $away++;
      }

      push @nicks, "$prefix" . $realnick;
    }

    my $total = @nicks;
    $channel->print("%K[%n%gUsers%n %G" . $chan . "%n%K]%n",
                    MSGLEVEL_CLIENTCRAP);
    columnize_nicks($channel,@nicks);
    $channel->print("%W$chan%n: Total of %W$total%n nicks %K[%W$ops%n ops, " .
                    "%W$halfops%n halfops, %W$voices%n voices, %W$normal%n " .
                    "normal, %W$away%n away%K]%n",
                    MSGLEVEL_CLIENTNOTICE);
  }
}


# create a /names style column, increasing alphabetically going down the
# columns.
sub columnize_nicks
{
  my($channel, @nicks) = @_;
  my $total = @nicks;

  # determine max columns
  # FIXME: this could be more intelligent (i.e., read window size)
  my $cols = Irssi::settings_get_int("names_max_columns");
  $cols = 6 if $cols == 0;

  # determine number of rows
  my $rows = round(ceil($total / $cols));

  # array of rows
  my @r;
  for (my $i = 0; $i < $cols; $i++) {
    # peek at next $rows items, determine max length
    my $max_length = find_max_length(@nicks[0 .. $rows - 1]);

    # fill rows
    for (my $j = 0; $j < $rows; $j++) {
      my $n = shift @nicks;  # single nick
      if ($n ne "") {
        $r[$j] .= "%K[%n$n" . fill_spaces($n,$max_length) . "%K]%n ";
      }
    }
  }

  for (my $m = 0; $m < $rows; $m++) {
    chomp $r[$m];
    $channel->print($r[$m], MSGLEVEL_CLIENTCRAP);
  }
}


sub fill_spaces
{
  my($text, $max_length) = @_;
  $text =~ s/%[a-zA-Z]//g;
  return " " x ($max_length - length($text));
}


sub find_max_length
{
  my $max_length = 0;
  for (my $i = 0; $i < @_; $i++) {
    my $nick = $_[$i];
    $nick =~ s/%[a-zA-Z]//g;
    if (length($nick) > $max_length) {
      $max_length = length($nick);
    }
  }
  return $max_length;
}


sub round
{
  my($number) = @_;
  return int($number + .5);
}


sub who_reply
{
  my($server, $data) = @_;
  my(undef, $c, $i, $h, $n, $s) = split / /, $data;
  if ($tmp_chan ne $c) {
    $tmp_chan = $c;
    #print "Got who info for $c";
  }
}


sub who_reply_end
{
  print_anames();
  $tmp_chan = "";
}


Irssi::Irc::Server::redirect_register("who", 0, 0,
                                      {"event 352" => 1},
                                      {"event 315" => 1},
                                      undef);
Irssi::signal_add("redir who_reply", \&who_reply);
Irssi::signal_add("redir who_reply_end", \&who_reply_end);
Irssi::command_bind("anames", \&cmd_anames);
