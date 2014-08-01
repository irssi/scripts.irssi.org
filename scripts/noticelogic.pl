# notice logic - irssi plugin
use strict;

use Irssi;
use vars qw($VERSION %IRSSI); 
$VERSION = "2.0";
%IRSSI = (
    authors     => "Ben Klein, based on noticemove by Timo Sirainen",
    contact     => "shacklein\@gmail.com", 
    name        => "notice logic",
    description => "Print private notices in query/channel where you're talking to them. Prefers active window if they're there with you.",
    license     => "Public Domain",
    url         => "http://irssi.org/",
    changed     => "2014-07-10T09:20+1000",
    changes     => "v2.0 - Rewrite noticemove to prefer active window"
);

my $insig = 0;

sub sig_print_text {
  my ($dest, $text, $stripped) = @_;
  my $server = $dest->{server};
  my $active = Irssi::active_win()->{active};
  my $hit = 0;

  # ignore non-notices and notices in channels
  return if (!$server || ($dest->{level} & MSGLEVEL_NOHILIGHT) ||
	     !($dest->{level} & MSGLEVEL_NOTICES) ||
	     $server->ischannel($dest->{target}));

  return if ($insig);
  $insig = 1;

  # Check active query/channel for sender
  if (ref $active && (
        ($active->{name} eq $dest->{target} && $active->{server}->{tag} eq $dest->{server}->{tag}) ||
	($active->isa("Irssi::Channel") && $active->nick_find($dest->{target}))
     )) {
    Irssi::active_win()->print($text, $dest->{level});
    Irssi::signal_stop();
    $hit = 1;
  } else {
    # print the notice in a query with the sender if there is one
    foreach my $query ($server->queries()) {
      if ($query->{name} eq $dest->{target}) {
        $query->print($text, $dest->{level});
        Irssi::signal_stop();
        $hit = 1;
        last;
      }
    }
    if (!$hit) {
      # print the notice in the first channel the sender is joined
      foreach my $channel ($server->channels()) {
        if ($channel->nick_find($dest->{target})) {
          $channel->print($text, $dest->{level});
          Irssi::signal_stop();
          $hit = 1;
          last;
        }
      }
    }
  }
  $insig = 0;
}

Irssi::signal_add('print text', 'sig_print_text');
