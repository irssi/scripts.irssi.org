# scripts/quakequit.pl
# Gets rid of some of the spam that you may see on quakenet if someone joins
# a channel before registering with nickserv.
# eg.
#####
# >>> Nick!ident@hos.t has joined #channel
# +++ Q sets +o Nick #channel
# <<< Nick!ident@hos.t has quit [Registered]
# >>> Nick!ident@hos.t has joined #channel
# +++ *.quakenet.org sets +o Nick #channel
#####
# Five lines for a single join, ridiculous.
# This script would make it so you just saw:
#####
# >>> Nick!ident@hos.t has joined #channel
# +++ Q sets +o Nick #channel
#####
# It does this by remembering people who quit with a message of "Registered"
# for 1 second after they quit.  Any joins or modes set within that one
# second are ignored.
#####
# Settings:
# quakequit_networks (default: quakenet)
# - Set the network tags which this script should be looking at.
# quakequit_servermask (default: *.quakenet.org)
# - Sets the quakenet mask so we can ignore the modes it sets.
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

# Output a few extra messages to the status window to help with
# any errors that might happen.
my $debug = 0;

# Debug line output.
sub dprint {
	my ($msg) = @_;
	if ($debug) {
		Irssi::print $msg;
	}
}

# Hash to store our temporary ignores in.
my %quits;

# Returns 1 if there are entrys in the quits hash, otherwise 0.
sub has_quitlist {
	if (%quits) {
		return 1;
	}
	return 0;
}

# Returns either 1 (from the entry in the hash) or undef.
sub in_quitlist {
	my ($tag, $nick) = @_;
	return $quits{$tag . ':' . $nick};
}

# Adds an entry to the quitlist.
sub quitlist_add {
	my ($tag, $nick) = @_;
	dprint("Adding $tag/$nick to the quitlist");
	$quits{$tag . ':' . $nick} = 1;
}

# Remove entries from the quits hash, this function takes only a single
# argument since it's called by Irssi::timeout_add_once. The argument is
# the concatinated $tag .':' $nick that the other functions use.
sub quitlist_del {
	my ($tagnick) = @_;
	dprint("Purging $tagnick from the quits list");
	delete $quits{$tagnick};
	return 0;
}

# Return 1 if we should process the tag, otherwise 0.
sub process_tag {
	my ($tag) = @_;
	my $netlist = Irssi::settings_get_str('quakequit_networks');
	foreach my $network (split / /, $netlist) {
		if (lc $tag eq lc $network) {
			return 1;
		}
	}
	return 0;
}

# Process the 'message join' signal. (/JOIN)
sub message_join {
	my ($server_rec, $channel, $nick, $addr) = @_;
	my $tag = $server_rec->{tag};

	# Don't proceed if the hash is empty.
	# hash returns <elements>/<buckets> in scalar context and just 0 if
	# it's empty.
	if (!has_quitlist()) {
		return 0;
	}

	# Return if we don't care about this tag.
	if (!process_tag($tag)) {
		return 0;
	}

	dprint("Processing JOIN $tag: $nick $addr");

	# Return if they're not in the quitlist.
	if (!in_quitlist($tag, $nick)) {
		return 0;
	}

	# Finally, stop the signal. They are in the quitlist.
	Irssi::signal_stop();
	return 0;
}

# Process the 'message quit' signal. (/QUIT)
sub message_quit {
	my ($server_rec, $nick, $addr, $reason) = @_;
	my $tag = $server_rec->{tag};

	# Return if we don't care about this tag.
	if (!process_tag($tag)) {
		return 0;
	}

	dprint("Processing QUIT $tag: $nick $addr $reason");

	if ($reason ne "Registered") {
		return 0;
	}

	# If the quit message is registered, add the person to our quit hash
	# and abort the signal.
	quitlist_add($tag, $nick);
	Irssi::signal_stop();

	# Setup a timeout to delete the entry in 1 second.
	Irssi::timeout_add_once(1000, 'quitlist_del', $tag.':'.$nick);
	return 0;
}

# Sometimes we have to hide server modes on quakenet too.
sub message_irc_mode {
	my ($server_rec, $channel, $nick, $addr, $mode) = @_;
	my $tag = $server_rec->{tag};

	# Don't proceed if the hash is empty
	if (!has_quitlist()) {
		return 0;
	}

	# Return if we don't care about this tag.
	if (!process_tag($tag)) {
		return 0;
	}

	dprint("Processing MIM $tag: $channel $nick $addr $mode");

	my $servermask = Irssi::settings_get_str('quakequit_servermask');
	# If the server is setting the mode, the $nick will be the server mask
	# and $addr will be empty.

	if ($nick ne $servermask) {
		return 0;
	}

	dprint("$nick == $servermask");

	# break the target nicks away from the modes set on them.
	my ($modes, @targets) = split / /, $mode, 2;

	# If the nick exists in the hash and the mode setter is
	# *.quakenet.org, signal_stop.
	foreach my $target (@targets) {
		dprint("Processing $target");

		# Proceed to next if target isn't in the quitlist.
		if (!in_quitlist($tag, $target)) {
			next;
		}

		dprint("Found $target in target list, stopping signal");
		Irssi::signal_stop();
		return 0;
	}
}

## Settings
# quakequit_networks: set the networks that you'd like this script to watch
# quakequit_servermask: the name of the server that's setting the modes on
#                       rejoin
Irssi::settings_add_str('quakequit', 'quakequit_networks', 'QuakeNet');
Irssi::settings_add_str('quakequit', 'quakequit_servermask', '*.quakenet.org');

# Signals to grab
Irssi::signal_add_first('message irc mode', 'message_irc_mode');
Irssi::signal_add_last('message join', 'message_join');
Irssi::signal_add_last('message quit', 'message_quit');
