use strict;
use Irssi;
use Irssi::Irc;

use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
	"authors"       => "Mantis",
	"contact"       => "mantis\@inta-link.com",
	"name"          => "highlite",
	"description"   => "shows events happening in all channels you are in that may concern you",
	"url"           => "http://www.inta-link.com/",
	"license"       => "GNU GPL v2",
	"changed"       => "2003-01-03"
);

sub msg_join
{
  my ($server, $channame, $nick, $host) = @_;
  $channame =~ s/^://;

  my $windowname = Irssi::window_find_name('highlite');
  $windowname->print("%B%0JOIN : " . $nick . " : " . $channame . " : " . $host, MSGLEVEL_CLIENTCRAP) if ($windowname);
}

sub msg_part
{
  my ($server, $channame, $nick, $host) = @_;
  $channame =~ s/^://;

  my $windowname = Irssi::window_find_name('highlite');
  $windowname->print("%b%0PART : " . $nick . " : " . $channame . " : " . $host, MSGLEVEL_CLIENTCRAP) if ($windowname);
}

sub msg_quit
{
  my ($server, $nick, $host, $quitmsg) = @_;

  if (substr($quitmsg, 0, 14) eq "Read error to ")
  {
    $quitmsg = "[ General Read Error ]";
  }
  if (substr($quitmsg, 0, 17) eq "Ping timeout for ")
  {
    $quitmsg = "[ General Ping Timeout Error ]";
  }

  my $windowname = Irssi::window_find_name('highlite');
  $windowname->print("%R%0QUIT : " . $nick . " : " . $host . " : " . $quitmsg, MSGLEVEL_CLIENTCRAP) if ($windowname);

  $quitmsg = "";
}

sub msg_topic
{
  my ($server, $channame, $topicmsg, $nick, $host) = @_;
  $channame =~ s/^://;

  my $windowname = Irssi::window_find_name('highlite');
  $windowname->print("%G%0TOPIC : " . $nick . " : " . $channame . " : " . $topicmsg, MSGLEVEL_CLIENTCRAP) if ($windowname);
}

sub msg_nick
{
  my ($server, $nick, $old_nick, $host) = @_;

  my $windowname = Irssi::window_find_name('highlite');
  $windowname->print("%m%0NICK : " . $old_nick . " : " . $nick . " : " . $host, MSGLEVEL_CLIENTCRAP) if ($windowname);
}

sub msg_kick
{
  my ($server, $channame, $kicked, $nick, $host, $reason) = @_;
  $channame =~ s/^://;

  my $windowname = Irssi::window_find_name('highlite');
  $windowname->print("%Y%0KICK : " . $kicked . " : " . $channame . " : " . $nick . " : " . $reason, MSGLEVEL_CLIENTCRAP) if ($windowname);
}

sub sig_printtext {
  my ($dest, $text, $stripped) = @_;

  if (($dest->{level} & (MSGLEVEL_HILIGHT|MSGLEVEL_MSGS)) && ($dest->{level} & MSGLEVEL_NOHILIGHT) == 0)
  {
    if ($dest->{level} & MSGLEVEL_PUBLIC)
    {
      my $windowname = Irssi::window_find_name('highlite');

      $windowname->print("%W%0HIGHLITE : " . $dest->{target} . " : " . $text, MSGLEVEL_CLIENTCRAP) if ($windowname);
    }
  }
}

my $windowname = Irssi::window_find_name('highlite');
if (!$windowname)
{
  Irssi::command("window new hidden");
  Irssi::command("window name highlite");
}

Irssi::signal_add(
{
  'message join' => \&msg_join,
  'message part' => \&msg_part,
  'message quit' => \&msg_quit,
  'message topic' => \&msg_topic,
  'print text', 'sig_printtext',
  'message nick' => \&msg_nick,
  'message kick' => \&msg_kick
}
);

