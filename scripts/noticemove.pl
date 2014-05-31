# Prints private notices from people in the channel where they are joined
# with you. Useful when you get lots of private notices from some bots.
# for irssi 0.7.99 by Timo Sirainen

# v1.01 - history:
#   - fixed infinite loop when you weren't connected to server :)

use Irssi;
use vars qw($VERSION %IRSSI); 
$VERSION = "1.01";
%IRSSI = (
    authors     => "Timo Sirainen",
    contact	=> "tss\@iki.fi", 
    name        => "notice move",
    description => "Prints private notices from people in the channel where they are joined with you. Useful when you get lots of private notices from some bots.",
    license	=> "Public Domain",
    url		=> "http://irssi.org/",
    changed	=> "2002-03-04T22:47+0100",
    changes	=> "v1.01 - fixed infinite loop when you weren't connected to server :)"
);

my $insig = 0;

sub sig_print_text {
  my ($dest, $text, $stripped) = @_;
  my $server = $dest->{server};

  # ignore non-notices and notices in channels
  return if (!$server || 
	     !($dest->{level} & MSGLEVEL_NOTICES) ||
	     $server->ischannel($dest->{target}));

  return if ($insig);
  $insig = 1;

  # print the notice in the first channel the sender is joined
  foreach my $channel ($server->channels()) {
    if ($channel->nick_find($dest->{target})) {
      $channel->print($text, MSGLEVEL_NOTICES);
      Irssi::signal_stop();
      last;
    }
  }

  $insig = 0;
}

Irssi::signal_add('print text', 'sig_print_text');
