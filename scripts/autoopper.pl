use Irssi;
use POSIX;
use strict;
use Socket;
use vars qw($VERSION %IRSSI);

$VERSION = "3.7";
%IRSSI = (
	authors     => 'Toni Salomäki',
	name        => 'autoopper',
	contact     => 'Toni@IRCNet',
	description => 'Auto-op script with dynamic address support and random delay',
	license     => 'GNU GPLv2 or later',
	url         => 'http://vinku.dyndns.org/irssi_scripts/'
);

# This is a script to auto-op people on a certain channel (all or, represented with *).
# Users are auto-opped on join with random delay.
# There is a possibility to use dns aliases (for example dyndns.org) for getting the correct address.
# The auto-op list is stored into ~/.irssi/autoop
#
# To get the dynamic addresses to be refreshed automatically, set value to autoop_dynamic_refresh (in hours)
# The value will be used next time the script is loaded (at startup or manual load)
#
# NOTICE: the datafile is in completely different format than in 1.0 and this version cannot read it. Sorry.
#

# COMMANDS:
#
# autoop_show - Displays list of auto-opped hostmasks & channels
#               The current address of dynamic host is displayed in parenthesis
#
# autoop_add - Add new auto-op. Parameters hostmask, channel (or *) and dynamic flag
#
#    Dynamic flag has 3 different values:
#      0: treat host as a static ip
#      1: treat host as an alias for dynamic ip
#      2: treat host as an alias for dynamic ip, but do not resolve the ip (not normally needed)
#
# autoop_del - Remove auto-op
#
# autoop_save - Save auto-ops to file (done normally automatically)
#
# autoop_load - Load auto-ops from file (use this if you have edited the autoop -file manually)
#
# autoop_check - Check all channels and op people needed
#
# autoop_dynamic - Refresh dynamic addresses (automatically if parameter set)
#
# Data is stored in ~/.irssi/autoop
# format: host	channels	flag
# channels separated with comma
# one host per line

my (%oplist);
my (@opitems);
srand();

#resolve dynamic host
sub resolve_host {
	my ($host, $dyntype) = @_;

	if (my $iaddr = inet_aton($host)) {
		if ($dyntype ne "2") {
			if (my $newhost = gethostbyaddr($iaddr, AF_INET)) {
				return $newhost;
			} else {
				return inet_ntoa($iaddr);
			}
		} else {
			return inet_ntoa($iaddr);
		}
	}
	return "error";
}

# return list of dynamic hosts with real addresses
sub fetch_dynamic_hosts {
	my %hostcache;
	my $resultext;
	foreach my $item (@opitems) {
		next if ($item->{dynamic} ne "1" && $item->{dynamic} ne "2");

		my (undef, $host) = split(/\@/, $item->{mask}, 2);

		# fetch the host's real address (if not cached)
		unless ($hostcache{$host}) {
			$hostcache{$host} = resolve_host($host, $item->{dynamic});
			$resultext .= $host . "\t" . $hostcache{$host} . "\n";
		}
	}
	chomp $resultext;
	return $resultext;
}

# fetch real addresses for dynamic hosts
sub cmd_change_dynamic_hosts {
	pipe READ, WRITE;
	my $pid = fork();

	unless (defined($pid)) {
		Irssi::print("Can't fork - aborting");
		return;
	}

	if ($pid > 0) {
		# the original process, just add a listener for pipe
		close (WRITE);
		Irssi::pidwait_add($pid);
		my $target = {fh => \*READ, tag => undef};
		$target->{tag} = Irssi::input_add(fileno(READ), INPUT_READ, \&read_dynamic_hosts, $target);
	} else {
		# the new process, fetch addresses and write to the pipe
		print WRITE fetch_dynamic_hosts;
		close (READ);
		close (WRITE);
		POSIX::_exit(1);
	}
}

# get dynamic hosts from pipe and change them to users
sub read_dynamic_hosts {
 	my $target = shift;
	my $rh = $target->{fh};
	my %hostcache;

	while (<$rh>) {
		chomp;
		my ($dynhost, $realhost, undef) = split (/\t/, $_, 3);
		$hostcache{$dynhost} = $realhost;
	}

	close($target->{fh});
	Irssi::input_remove($target->{tag});

	my $mask;
	my $count = 0;
	undef %oplist if (%oplist);

	foreach my $item (@opitems) {
		if ($item->{dynamic} eq "1" || $item->{dynamic} eq "2") {
			my ($user, $host) = split(/\@/, $item->{mask}, 2);

			$count++ if ($item->{dynmask} ne $hostcache{$host});
			$item->{dynmask} = $hostcache{$host};
			$mask = $user . "\@" . $hostcache{$host};
		} else {
			$mask = $item->{mask};
		}

		foreach my $channel (split (/,/,$item->{chan})) {
			$oplist{$channel} .= "$mask ";
		}
	}
	chop %oplist;
	Irssi::print("$count dynamic hosts changed") if ($count > 0);
}

# Save data to file
sub cmd_save_autoop {
	my $file = Irssi::get_irssi_dir."/autoop";
	open FILE, "> $file" or return;

	foreach my $item (@opitems) {
		printf FILE ("%s\t%s\t%s\n", $item->{mask}, $item->{chan}, $item->{dynamic});
	}

	close FILE;
	Irssi::print("Auto-op list saved to $file");
}

# Load data from file
sub cmd_load_autoop {
	my $file = Irssi::get_irssi_dir."/autoop";
	open FILE, "< $file" or return;
	undef @opitems if (@opitems);

	while (<FILE>) {
		chomp;
		my ($mask, $chan, $dynamic, undef) = split (/\t/, $_, 4);
		my $item = {mask=>$mask, chan=>$chan, dynamic=>$dynamic, dynmask=>undef};
		push (@opitems, $item);
	}

	close FILE;
	Irssi::print("Auto-op list reloaded from $file");
	cmd_change_dynamic_hosts;
}

# Show who's being auto-opped
sub cmd_show_autoop {
	my %list;
	foreach my $item (@opitems) {
		foreach my $channel (split (/,/,$item->{chan})) {
			$list{$channel} .= "\n" . $item->{mask};
			$list{$channel} .= " (" . $item->{dynmask} . ")" if ($item->{dynmask});
		}
	}

	Irssi::print("All channels:" . $list{"*"}) if (exists $list{"*"});
	delete $list{"*"}; #this is already printed, so remove it
	foreach my $channel (sort (keys %list)) {
		Irssi::print("$channel:" . $list{$channel});
	}
}

# Add new auto-op
sub cmd_add_autoop {
	my ($data) = @_;
	my ($mask, $chan, $dynamic, undef) = split(" ", $data, 4);
	my $found = 0;

	if ($chan eq "" || $mask eq "" || !($mask =~ /.+!.+@.+/)) {
		Irssi::print("Invalid hostmask. It must contain both ! and @.") if (!($mask =~ /.+!.+@.+/));
		Irssi::print("Usage: /autoop_add <hostmask> <*|#channel> [dynflag]");
		Irssi::print("Dynflag: 0 normal, 1 dynamic, 2 dynamic without resolving");
		return;
	}

	foreach my $item (@opitems) {
		next unless ($item->{mask} eq $mask);
		$found = 1;
		$item->{chan} .= ",$chan";
		last;
	}

	if ($found == 0) {
		$dynamic = "0" unless ($dynamic eq "1" || $dynamic eq "2");
		my $item = {mask=>$mask, chan=>$chan, dynamic=>$dynamic, dynmask=>undef};
		push (@opitems, $item);
	}

	$oplist{$chan} .= " $mask";

	Irssi::print("Added auto-op: $chan: $mask");
}

# Remove autoop
sub cmd_del_autoop {
	my ($data) = @_;
	my ($mask, $channel, undef) = split(" ", $data, 3);

	if ($channel eq "" || $mask eq "") {
		Irssi::print("Usage: /autoop_del <hostmask> <*|#channel>");
		return;
	}

	my $i=0;
	foreach my $item (@opitems) {
		if ($item->{mask} eq $mask) {
			if ($channel eq "*" || $item->{chan} eq $channel) {
				splice @opitems, $i, 1;
				Irssi::print("Removed: $mask");
			} else {
				my $newchan;
				foreach my $currchan (split (/,/,$item->{chan})) {
					if ($channel eq $currchan) {
						Irssi::print("Removed: $channel from $mask");
					} else {
						$newchan .= $currchan . ",";
					}
				}
				chop $newchan;
				Irssi::print("Couldn't remove $channel from $mask") if ($item->{chan} eq $newchan);
				$item->{chan} = $newchan;
			}
			last;
		}
		$i++;
	}
}

# Do the actual opping
sub do_autoop {
	my $target = shift;

	Irssi::timeout_remove($target->{tag});

	# nick has to be fetched again, because $target->{nick}->{op} is not updated
	my $nick = $target->{chan}->nick_find($target->{nick}->{nick});

	# if nick is changed during delay, it will probably be lost here...
	if ($nick->{nick} ne "") {
		if ($nick->{host} eq $target->{nick}->{host}) {
			$target->{chan}->command("op " . $nick->{nick}) unless ($nick->{op});
		} else {
			Irssi::print("Host changed for nick during delay: " . $nick->{nick});
		}
	}
	undef $target;
}

# Someone joined, might be multiple person. Check if opping is needed
sub event_massjoin {
	my ($channel, $nicklist) = @_;
	my @nicks = @{$nicklist};

	return if (!$channel->{chanop});

	my $masks = $oplist{"*"} . " " . $oplist{$channel->{name}};

	foreach my $nick (@nicks) {
		my $host = $nick->{host};
		$host=~ s/^~//g; # remove this if you don't want to strip ~ from username (no ident)
		next unless ($channel->{server}->masks_match($masks, $nick->{nick}, $host));

		my $min_delay = Irssi::settings_get_int("autoop_min_delay");
		my $max_delay = Irssi::settings_get_int("autoop_max_delay") - $min_delay;
		my $delay = int(rand($max_delay)) + $min_delay;

		my $target = {nick => $nick, chan => $channel, tag => undef};

		$target->{tag} = Irssi::timeout_add($delay, 'do_autoop', $target);
	}

}

# Check channel op status
sub do_channel_check {
	my $target = shift;

	Irssi::timeout_remove($target->{tag});

	my $channel = $target->{chan};
	my $server = $channel->{server};
	my $masks = $oplist{"*"} . " " . $oplist{$channel->{name}};
	my $nicks = "";

	foreach my $nick ($channel->nicks()) {
		next if ($nick->{op});

		my $host = $nick->{host};
		$host=~ s/^~//g; # remove this if you don't want to strip ~ from username (no ident)

		if ($server->masks_match($masks, $nick->{nick}, $host)) {
			$nicks = $nicks . " " . $nick->{nick};
		}
	}
	$channel->command("op" . $nicks) unless ($nicks eq "");

	undef $target;
}

#check people needing opping after getting ops
sub event_nickmodechange {
	my ($channel, $nick, $setby, $mode, $type) = @_;

	return unless (($mode eq '@') && ($type eq '+'));

	my $server = $channel->{server};

	return unless ($server->{nick} eq $nick->{nick});

	my $min_delay = Irssi::settings_get_int("autoop_min_delay");
	my $max_delay = Irssi::settings_get_int("autoop_max_delay") - $min_delay;
	my $delay = int(rand($max_delay)) + $min_delay;

	my $target = {chan => $channel, tag => undef};

	$target->{tag} = Irssi::timeout_add($delay, 'do_channel_check', $target);
}

#Check all channels / all users if someone needs to be opped
sub cmd_autoop_check {
	my ($data, $server, $witem) = @_;

	foreach my $channel ($server->channels()) {
		Irssi::print("Checking: " . $channel->{name});
		next if (!$channel->{chanop});

		my $masks = $oplist{"*"} . " " . $oplist{$channel->{name}};

		foreach my $nick ($channel->nicks()) {
			next if ($nick->{op});

			my $host = $nick->{host};
			$host=~ s/^~//g; # remove this if you don't want to strip ~ from username (no ident)

			if ($server->masks_match($masks, $nick->{nick}, $host)) {
				$channel->command("op " . $nick->{nick}) if (!$nick->{op});
			}
		}
	}
}

#Set dynamic refresh period.
sub set_dynamic_refresh {
	my $refresh = Irssi::settings_get_int("autoop_dynamic_refresh");
	return if ($refresh == 0);

	Irssi::print("Dynamic host refresh set for $refresh hours");
	Irssi::timeout_add($refresh*3600000, 'cmd_change_dynamic_hosts', undef);
}

Irssi::command_bind('autoop_show', 'cmd_show_autoop');
Irssi::command_bind('autoop_add', 'cmd_add_autoop');
Irssi::command_bind('autoop_del', 'cmd_del_autoop');
Irssi::command_bind('autoop_save', 'cmd_save_autoop');
Irssi::command_bind('autoop_load', 'cmd_load_autoop');
Irssi::command_bind('autoop_check', 'cmd_autoop_check');
Irssi::command_bind('autoop_dynamic', 'cmd_change_dynamic_hosts');
Irssi::signal_add_last('massjoin', 'event_massjoin');
Irssi::signal_add_last('setup saved', 'cmd_save_autoop');
Irssi::signal_add_last('setup reread', 'cmd_load_autoop');
Irssi::signal_add_last("nick mode changed", "event_nickmodechange");
Irssi::settings_add_int('autoop', 'autoop_max_delay', 15000);
Irssi::settings_add_int('autoop', 'autoop_min_delay', 1000);
Irssi::settings_add_int('autoop', 'autoop_dynamic_refresh', 0);


cmd_load_autoop;
set_dynamic_refresh;
