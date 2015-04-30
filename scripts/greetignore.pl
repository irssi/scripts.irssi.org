# greetignore.pl
# Gets rid of annoying "greet messages".
#####
# >>> Nick!ident@hos.t has joined #channel
# <IdiotBot> [Nick] This is a shitty greet message.
# <nico> Sigh, I wish I just could ignore those...
#####
# With this script:
#####
# >>> Nick!ident@hos.t has joined #channel
# <nico> Way better.
#####
# It does this by remembering people who joined a channel for 1 second and
# ignoring any messages matching /^[$nick] / in this timeframe.
#####
# Settings:
# greetignore_networks (default: Rizon)
# - Set the network tags which this script should be looking at.

# Shamelessly edited David 'phyber' O'Rourke's quakequit.pl.
# Most credits to him :p

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
$VERSION = "1.1";
%IRSSI = (
	authors		=> "David O\'Rourke, Nico R. Wohlgemuth",
	contact		=> "nico\@lifeisabug.com",
	name			=> "greetignore",
	description	=> "Hide the stupid \"greet messages\" posted by some bots".
						" after someone joins a channel.",
	license		=> "GPLv2",
	changed		=> "20120914",
);

# Output a few extra messages to the status window to help with 
# any errors that might happen.
my $debug = 0;
# Array to store our temporary joins in.
my %joins;

# Return 1 if we should process the tag, otherwise 0.
sub process_tag {
	my ($tag) = @_;
	my $netlist = Irssi::settings_get_str('greetignore_networks');
	foreach my $network (split /[, ]/, $netlist) {
		if (lc $tag eq lc $network) {
			return 1;
		}
	}
	return 0;
}

# Remove entries from the joins hash.
sub purge_nick {
	my ($data) = @_;
	my @tagnick = split /:/, $data;
	delete $joins{$tagnick[0]}{$tagnick[1]};
	return 0;
}

# Ignore lines like "<SomeBot> [$nick] This is a shitty greet message."
sub ignore_greet {
	my ($server_rec, $msg, $nick, $addr, $target) = @_;
	my $tag = $server_rec->{tag};
	# Don't proceed if the hash is empty.
	# hash returns <elements>/<buckets> in scalar context and just 0 if it's empty.
	if (!$joins{$tag} || !(keys(%{$joins{$tag}}))) {
		return 0;
	}
	# Return if we don't care about this tag.
	if (process_tag($tag) == 0) {
		return 0;
	}
	# If the message matches a nick in our joins hash, don't show the greet message.
	if ($msg =~ /^\[(.+?)\] / && $joins{$tag}{lc($1)} && $nick ne $1) {
		Irssi::signal_stop();
		Irssi::print("Ignored: <$nick> $msg") if $debug;
		return 0;
	}
}

# Process the 'message join' signal. (/JOIN)
sub message_join {
	my ($server_rec, $channel, $nick, $addr) = @_;
	my $tag = $server_rec->{tag};
	# Return if we don't care about this tag.
	if (process_tag($tag) == 0) {
		return 0;
	}
	$joins{$tag}{lc($nick)}++;
	my $data = $tag.':'.lc($nick);
	Irssi::timeout_add_once(2500, 'purge_nick', $data);
	return 0;
}

## Settings
# greetignore_networks: set the networks that you'd like this script to watch
Irssi::settings_add_str('greetignore', 'greetignore_networks', 'Rizon');
# Signals to grab
Irssi::signal_add_first('message join', 'message_join');
Irssi::signal_add_last("message public", "ignore_greet");
