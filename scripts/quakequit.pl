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
	# Return if we don't care about this tag.
	if (process_tag($tag) == 0) {
		return 0;
	}
	#Irssi::print "Processing JOIN $tag: $nick $addr";
	# If the joining nick is in our quit hash, don't show the join.
	if ($quits{$nick} == 1) {
		delete $quits{$nick};
		Irssi::signal_stop();
		return 0;
	}
}

# Process the 'message quit' signal. (/QUIT)
sub message_quit {
	my ($server_rec, $nick, $addr, $reason) = @_;
	my $tag = $server_rec->{tag};
	# Return if we don't care about this tag.
	if (process_tag($tag) == 0) {
		return 0;
	}
	#Irssi::print "Processing QUIT $tag: $nick $addr $reason";
	# If the quit message is registered, add the person to our quit hash and abort the signal.
	if ($reason eq "Registered") {
		$quits{$nick} = 1;
		Irssi::signal_stop();
		return 0;
	}
}

# Add a networks setting
Irssi::settings_add_str('quakequit', 'quakequit_networks', 'QuakeNet');
# Signals to grab
Irssi::signal_add('message join', 'message_join');
Irssi::signal_add('message quit', 'message_quit');
