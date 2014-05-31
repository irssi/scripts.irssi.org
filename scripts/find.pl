# /FIND - display people who are in more than one channel with you
# (it's ugly code)

use Irssi;

use vars qw($VERSION %IRSSI);
$VERSION = "0.2";
%IRSSI = (
    authors     => "Erkki Seppälä",
    contact     => "flux\@inside.org",
    name        => "Find",
    description => "Finds a nick by real name, if he's on a channel with you.",
    license     => "Public Domain",
    url         => "http://xulfad.inside.org/~flux/software/irssi/",
    changed     => "Mon Mar  4 23:25:18 EET 2002"
);


sub cmd_find {
  my ($findName, $server, $channel) = @_;

  if ($findName eq "") {
    Irssi::print("usage: /find erkki");
    return 1;
  }

  my %channicks, $channel;
  my %found;

  foreach $channel (Irssi::active_server()->channels()) {
    foreach my $nick ($channel->nicks()) {
      $found{$nick->{nick}} = 1 if $nick->{realname} =~ /$findName/i;
    }
  }

  if (keys %found) {
    Irssi::print($findName . " could be found with these nicks: " . join(", ", keys %found));
  } else {
    Irssi::print("Sorry, " . $findName . " could not be found.");
  }
  return 1;
}

Irssi::command_bind('find', 'cmd_find');
