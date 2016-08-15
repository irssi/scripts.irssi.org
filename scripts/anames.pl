# anames.pl
# Irssi script that adds an /anames command, a clone of /names, with away nicks
# grayed out.
#
# Thanks to Dirm and Chris62vw for the Perl help and coekie for writing the
# evil code to sort the nicklist by the alphabet and rank in nicklist.pl
#
# 1.6   - optional support for unicode nicknames, realnames script,
#         formattable summary line (default away colour changed!) (Nei)
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
use Irssi 20140918;
use POSIX;
use List::Util 'max';

use vars qw($VERSION %IRSSI);

$VERSION = '1.6'; # f200e871df81c77
%IRSSI = (
  authors     => 'Matt "f0rked" Sparks, Miklos Vajna',
  contact     => 'ms+irssi@quadpoint.org',
  name        => 'anames',
  description => 'a /names display with away nicks coloured',
  license     => 'GPLv2',
  url         => 'http://quadpoint.org',
  changed     => '2010-07-12',
);

# How often to do a /who of all channels (in seconds)
#my $who_timer = 300;

my $tmp_server;
my $tmp_chan;


Irssi::theme_register([
  'endofanames' => '{channel $0}: Total of {hilight $1} nicks {comment {hilight $2} ops, {hilight $3} halfops, {hilight $4} voices, {hilight $5} normal, {hilight $6} away}',
  'names_awaynick' => '{channick $0}',
]);


local $@;
eval { require Text::CharWidth; };
unless ($@) {
    *screen_length = sub { Text::CharWidth::mbswidth($_[0]) };
} else {
    *screen_length = sub { length($_[0]); }
}


sub object_printformat_module {
    my ($object, $level, $module, $format, @args) = @_;
    {
        local *CORE::GLOBAL::caller = sub { $module };
        $object->printformat($level, $format, @args);
    }
}


sub core_printformat_module {
    my ($level, $module, $format, @args) = @_;
    {
        local *CORE::GLOBAL::caller = sub { $module };
        Irssi::printformat($level, $format, @args);
    }
}


sub cmd_anames
{
  my($args, $server, $item) = @_;
  my $channel = $item;
  $tmp_server = $server->{"tag"};
  $tmp_chan = $channel->{"name"};

  if ($args ne "") {
    my @args = split ' ', $args;
    if ($args[0] =~ /-(.*)/) {
      $tmp_server = $1;
      $server = Irssi::server_find_tag($tmp_server);
      shift @args;
    }
    $tmp_chan = $args[0];
  }

  unless ($server) {
    core_printformat_module(MSGLEVEL_CLIENTERROR, 'fe-common/core', 'not_connected');
    return;
  }

  # set up redirection
  $server->redirect_event("who", 1, $tmp_chan, 0, undef,
                              {
                                "event 352" => "silent event who",
                                "event 315" => "redir who_reply_end",
                              });

  $server->command("who $tmp_chan");
}


sub print_anames
{
  my $server = Irssi::server_find_tag($tmp_server);
  my $chan = $tmp_chan;
  my $channel = $server ? $server->channel_find($chan) : undef;
  my $nick;

  if (!$channel) {
    # no nicklist
    core_printformat_module(MSGLEVEL_CLIENTERROR, 'fe-common/core', 'not_joined');
  } else {
    # Loop through each nick and display
    my @nicks;
    my($ops, $halfops, $voices, $normal, $away) = (0, 0, 0, 0, 0);

    my $prefer_real;
    if (exists $Irssi::Script::{'realnames::'}) {
        my $code = "Irssi::Script::realnames"->can('use_realnames');
        $prefer_real = $code && $code->($channel);
    }
    my $_real = sub {
        my $nick = shift;
        $prefer_real && length $nick->{'realname'} ? $nick->{'realname'} : $nick->{'nick'}
    };
    # sorting from nicklist.pl
    foreach my $nick (sort {($a->{'op'}?'1':$a->{'halfop'}?'2':$a->{'voice'}?'3':$a->{'other'}>32?'0':'4').lc($_real->($a))
        cmp ($b->{'op'}?'1':$b->{'halfop'}?'2':$b->{'voice'}?'3':$b->{'other'}>32?'0':'4').lc($_real->($b))} $channel->nicks()) {
      my $realnick = $_real->($nick);
      my $gone = $nick->{'gone'};

      my $prefix;
      if ($nick->{'other'}) {
        $prefix = chr $nick->{'other'};
      } elsif ($nick->{'op'}) {
        $prefix = "@";
      } elsif ($nick->{'halfop'}) {
        $prefix = "%";
      } elsif ($nick->{'voice'}) {
        $prefix = "+";
      } else {
        $prefix = " ";
      }

      my $format;
      if ($nick->{'op'}) {
        $ops++;
        $format = 'names_nick_op';
      } elsif ($nick->{'halfop'}) {
        $halfops++;
        $format = 'names_nick_halfop';
      } elsif ($nick->{'voice'}) {
        $voices++;
        $format = 'names_nick_voice';
      } else {
        $normal++;
        $format = 'names_nick';
      }

      if ($gone) {
        $realnick = $channel->window->format_get_text(__PACKAGE__, $server, $chan, 'names_awaynick', $realnick);
        $away++;
      }
      my $text = $channel->window->format_get_text('fe-common/core', $server, $chan, $format, $prefix, $realnick);
      my $bleak = Irssi::strip_codes($text);

      push @nicks, [ $prefix, $realnick, $format, screen_length($bleak) ];
    }

    my $total = @nicks;
    object_printformat_module($channel, MSGLEVEL_CLIENTCRAP, 'fe-common/core', 'names', $chan);
    columnize_nicks($channel,@nicks);
    $channel->printformat(MSGLEVEL_CLIENTNOTICE, 'endofanames', $chan, $total, $ops,
                          $halfops, $voices, $normal, $away);
  }
}


{ my %strip_table = (
    # fe-common::core::formats.c:format_expand_styles
    #      delete                format_backs  format_fores bold_fores   other stuff
    (map { $_ => '' } (split //, '04261537' .  'kbgcrmyw' . 'KBGCRMYW' . 'U9_8I:|FnN>#[' . 'pP')),
    #      escape
    (map { $_ => $_ } (split //, '{}%')),
   );
  sub ir_strip_codes { # strip %codes
      my $o = shift;
      $o =~ s/(%(%|Z.{6}|z.{6}|X..|x..|.))/exists $strip_table{$2} ? $strip_table{$2} :
	  $2 =~ m{x(?:0[a-f]|[1-6][0-9a-z]|7[a-x])|z[0-9a-f]{6}}i ? '' : $1/gex;
      $o
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
  if ($cols == 0) {
      my $width = $channel->window->{width};
      my $ts_format = Irssi::settings_get_str('timestamp_format');
      my $render_str = Irssi::current_theme->format_expand(
        Irssi::current_theme->get_format('fe-common/core', 'timestamp'));
      (my $ts_escaped = $ts_format) =~ s/([%\$])/$1$1/g;
      $render_str =~ s/(?|\$(.)(?!\w)|\$\{(\w+)\})/$1 eq 'Z' ? $ts_escaped : $1/ge;
      $render_str = ir_strip_codes($render_str);
      $width -= screen_length($render_str);
      $cols = max(1, int( $width / max(1, map { 1+ $_->[-1] } @nicks) ));
  }

  # determine number of rows
  my $rows = round(ceil($total / $cols));

  # array of rows
  my @r;
  for (my $i = 0; $i < $cols; $i++) {
    # peek at next $rows items, determine max length
    my $max_length = max map { $_->[-1] } @nicks[0 .. $rows - 1];

    # fill rows
    for (my $j = 0; $j < $rows; $j++) {
      my $n = shift @nicks;  # single nick
      if ($n->[-1]) {
        $r[$j] .= $channel->window->format_get_text('fe-common/core', $channel->{server}, $channel->{visible_name},
          $n->[2], $n->[0], $n->[1] . fill_spaces($n->[-1],$max_length) );
      }
    }
  }

  for (my $m = 0; $m < $rows; $m++) {
    chomp $r[$m];
    $r[$m] =~ s/%/%%/g;
    $channel->print($r[$m], MSGLEVEL_CLIENTCRAP);
  }
}


sub fill_spaces
{
  my($length, $max_length) = @_;
  return " " x max (0, $max_length - $length);
}


sub round
{
  my($number) = @_;
  return int($number + .5);
}


sub who_reply_end
{
  print_anames();
  Irssi::signal_emit('chanquery who end', @_);
  $tmp_chan = "";
}


Irssi::Irc::Server::redirect_register("who", 0, 0,
                                      {"event 352" => 1},
                                      {"event 315" => 1},
                                      undef);
Irssi::signal_register({'chanquery who end' => [qw[iobject string]]});
Irssi::signal_add("redir who_reply", 'who_reply');
Irssi::signal_add("redir who_reply_end", 'who_reply_end');
Irssi::command_bind("anames", 'cmd_anames');
