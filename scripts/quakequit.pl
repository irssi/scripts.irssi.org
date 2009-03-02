use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
$VERSION = "1.0";
%IRSSI = (
	authors		=> "David O\'Rourke",
	contact		=> "phyber [at] #irssi",
	name		=> "quakequit",
	description	=> "Hide the stupid quit/join on QuakeNet when a user registers with nickserv.",
	licence		=> "GPLv2",
	changed		=> "02/03/2009",
);

# Hash to store our temporary ignores in.
my %quits;

sub message_join {
	my ($server_rec, $nick, $addr) = @_;
	my $tag = $server_rec->{tag};
	# If the joining nick is in our quit hash, don't show the join.
	if (($tag eq "QuakeNet") and (defined $quits{$nick})) {
		delete $quits{$nick};
		Irssi::signal_stop();
		return 0;
	}
}

sub message_quit {
	my ($server_rec, $nick, $addr, $reason) = @_;
	my $tag = $server_rec->{tag};
	# If the quit message is registered, add the person to our quit hash and abort the signal.
	if (($tag eq "QuakeNet") and ($reason eq "Registered")) {
		$quits{$nick} = 1;
		Irssi::signal_stop();
		return 0;
	}
}

# Signals to grab
Irssi::signal_add('message join', 'message_join');
Irssi::signal_add('message quit', 'message_quit');
