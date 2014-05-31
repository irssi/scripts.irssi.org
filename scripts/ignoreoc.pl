#!/usr/bin/perl -w
use Irssi;
use vars qw($VERSION %IRSSI);
$VERSION = "0.6";
%IRSSI = (
    authors     => "Erkki Seppälä",
    contact     => "flux\@inside.org",
    name        => "Ignore-OC",
    description => "Ignore messages from people not on your channels." .
		   "Now people you msg are added to bypass-list.",
    license     => "Public Domain",
    url         => "http://www.inside.org/~flux/software/irssi/",
    changed     => "Mon Jun 16 08:10:45 EEST 2008"
);

my %bypass = ();

my $ignoredMessages = 0;

sub cmd_message_private {
  my ($server, $message, $nick, $address) = @_;
  my $channel;

=cut
  my ($addressNick) = $address =~ /^([^@]*)/;

  if ($addressNick ne $server->{nick}) {
    Irssi::print "Irssi bug? Received a message sent to $address";
    return 1;                                                     
  }
=cut
   
  if ($message =~ m/oc:/i ||
      exists $bypass{$nick}) {
    return 1;
  }

  foreach $channel ($server->channels()) {
    foreach my $other ($channel->nicks()) {
      if ($other->{nick} eq $nick) {
        return 1;
      }
    }
  }

  ++$ignoredMessages;
  $server->command("^NOTICE $nick You're not on any channel I'm on, thus, due to spambots, your message was ignored. Prefix your message with 'OC:' to bypass the ignore.");
  Irssi::signal_stop();
}

sub cmd_message_own_private {
  my ($server, $message, $nick, $address) = @_;
  $bypass{$nick} = 1;
}

sub cmd_ignoreoc {
  Irssi::print("You've ignored $ignoredMessages messages since startup.");
}

Irssi::signal_add_first("message private", "cmd_message_private");
Irssi::signal_add("message own_private", "cmd_message_own_private");
Irssi::command_bind("ignoreoc", "cmd_ignoreoc");

Irssi::print "IgnoreOC version $VERSION by flux with patches from Exstatica. Try /ignoreoc"
