#!/usr/bin/perl -w
#
# This script may not work with irssi older than 0.8.5!
#
# Historical author of this script is Erkki Seppala <flux@inside.org>
# Now it's maintained by me, so i'm listed as an author.
# 
# $Id: friends.pl,v 1.3 2003/11/09 21:11:45 shasta Exp $ 

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "2.4.9";
%IRSSI = (
    authors	=> 'Jakub Jankowski',
    contact	=> 'shasta@toxcorp.com',
    name	=> 'Friends',
    description	=> 'Maintains list of people you know.',
    license	=> 'GNU GPLv2 or later',
    url		=> 'http://toxcorp.com/irc/irssi/friends/',
    changed	=> 'Sun Oct 9 22:12:43 2003'
);

use Irssi 20011201.0100 ();
use Irssi::Irc;

# friends.pl
my $friends_version = $VERSION . " (20031109)";

# release note, if any
my $release_note = "Please read http://toxcorp.com/irc/irssi/friends/current/README\n";

##############################################
# These variables are adjustable with /set
# but here are some 'safe' defaults:

# do you want to process CTCP queries?
my $default_friends_use_ctcp = 1;

# space-separated list of allowed (implemented ;) CTCP commands
my $default_friends_ctcp_commands = "OP VOICE LIMIT KEY INVITE PASS IDENT UNBAN";

# do you want to learn new users?
my $default_friends_learn = 1;

# do you want to autovoice already opped nicks?
my $default_friends_voice_opped = 0;

# do you want to show additional info with /whois?
my $default_friends_show_whois_extra = 1;

# which flags do you want to add automatically with /addfriend? (case *sensitive*)
my $default_friends_default_flags = "";

# default path to friendlist
my $default_friends_file = Irssi::get_irssi_dir() . "/friends";

# do you want to save friendlist every time irssi's setup is saved
my $default_friends_autosave = 0;

# do you want to backup your friendlist upon a save
my $default_friends_backup_friendlist = 1;

# backup suffix to use (unixtime if empty)
my $default_friends_backup_suffix = ".backup";

# do you want to show friend's flags while he joins a channel?
my $default_friends_show_flags_on_join = 1;

# do you want to revenge?
my $default_friends_revenge = 1;

# revenge mode:
# 0 Deop the user.
# 1 Deop the user and give them the +D flag for the channel.
# 2 Deop the user, give them the +D flag for the channel, and kick them.
# 3 Deop the user, give them the +D flag for the channel, kick, and ban them.
my $default_friends_revenge_mode = 0;

# do you want /findfriends to print info in separate windows for separate chans?
my $default_friends_findfriends_to_windows = 0;

# maximum size of operationQueue
my $default_friends_max_queue_size = 20;

# min delaytime
my $default_delay_min = 10;

# max delaytime
my $default_delay_max = 60;

###############################################################

# registering themes
Irssi::theme_register([
	'friends_empty',		'Your friendlist is empty. Add items with /ADDFRIEND',
	'friends_notenoughargs',	'Not enough arguments. Usage: $0',
	'friends_badargs',		'Bad arguments. Usage: $0',
	'friends_nosuch',		'No such friend %R$0%n',
	'friends_notonchan',		'Not on channel {hilight $0}',
	'friends_endof',		'End of $0 $1',
	'friends_badhandle',		'Wrong handle: %R$0%n. $1',
	'friends_notuniqhandle',	'Handle %R$0%n already exists, choose another one',
	'friends_version',		'friends.pl\'s version: {hilight $0} [$1]',
	'friends_file_written',		'friendlist written on: {hilight $0}',
	'friends_file_version',		'friendlist written with: {hilight $0} [$1]',
	'friends_filetooold',		'Friendfile too old, loading aborted',
	'friends_loaded',		'Loaded {hilight $0} friends from $1',
	'friends_saved',		'Saved {hilight $0} friends to $1',
	'friends_duplicate',		'Skipping %R$0%n [duplicate?]',
	'friends_checking',		'Checking {hilight $0} took {hilight $1} secs [on $2]',
	'friends_line_head',		'[$[!-3]0] Handle: %R$1%n, flags: %C$2%n [password: $3]',
	'friends_line_hosts',		'$[-6]9 Hosts: $0',
	'friends_line_chan',		'$[-6]9 Channel {hilight $0}: Flags: %c$1%n, Delay: $2',
	'friends_line_comment',		'$[-6]9 Comment: $0',
	'friends_line_currentnick',	'$[-6]9 [$1] Current nick: {nick $0}',
	'friends_line_channelson',	'$[-6]9 [$1] Currently sharing with you: $0',
	'friends_joined',		'{nick $0} is a friend, handle: %R$1%n, global flags: %C$2%n, flags for {hilight $3}: %C$4%n',
	'friends_whois',		'{whois friend handle: {hilight $0}, global flags: $1}',
	'friends_queue_empty',		'Operation queue is empty',
	'friends_queue_line1',		'[$[!-2]0] Operation: %R$1%n secs left before {hilight $2}',
	'friends_queue_line2',		'     (Server: {hilight $0}, Channel: {hilight $1}, Nicklist: $2)',
	'friends_queue_nosuch',		'No such entry in operation queue ($0)',
	'friends_queue_removed',	'$0 queues: {hilight $1} [$2]',
	'friends_friendlist',		'{hilight Friendlist} [$0]:',
	'friends_friendlist_count',	'Listed {hilight $0} friend$1',
	'friends_findfriends',		'Looking for %R$2%n on channel {hilight $0} [on $1]:',
	'friends_already_added',	'Nick {hilight $0} matches one of %R$1%n\'s hosts',
	'friends_added',		'Added %R$0%n to friendlist',
	'friends_removed',		'Removed %R$0%n from friendlist',
	'friends_comment_added',	'Added comment line to %R$0%n ($1)',
	'friends_comment_removed',	'Removed comment line from %R$0%n',
	'friends_host_added',		'Added {hilight $1} to %R$0%n',
	'friends_host_removed',		'Removed {hilight $1} from %R$0%n',
	'friends_host_exists',		'Hostmask {hilight $1} overlaps with one of the already added to %R$0%n',
	'friends_host_notexists',	'%R$0%n does not have {hilight $1} in hostlist',
	'friends_chanrec_removed',	'Removed {hilight $1} record from %R$0%n',
	'friends_chanrec_notexists',	'%R$0%n does not have {hilight $1} record',
	'friends_changed_handle',	'Changed {hilight $0} to %R$1%n',
	'friends_changed_delay',	'Changed %R$0%n\'s delay value on {hilight $1} to %c$2%n',
	'friends_chflagexec',		'Executing %c$0%n for %R$1%n ($2)',
	'friends_currentflags',		'Current {channel $2} flags for %R$1%n are: %c$0%n',
	'friends_chpassexec',		'Altered password for %R$0%n',
	'friends_ctcprequest',		'%R$0%n asks for {hilight $1} on {hilight $2}',
	'friends_ctcppass',		'Password for %R$0%n altered by $1',
	'friends_ctcpident',		'CTCP IDENT for %R$0%n from {hilight $1} succeeded',
	'friends_ctcpfail',		'Failed CTCP {hilight $0} from %R$1%n. $2',
	'friends_optree_header',	'Opping tree:',
	'friends_optree_line1',		'%R$0%n has opped these:',
	'friends_optree_line2',		'{hilight $[!-4]0} times: $1',
	'friends_general',		'$0',
	'friends_notice',		'[%RN%n] $0'
]);

my @friends = ();
my $all_regexp_hosts = {};
my $all_hosts = {};
my $all_handles = {};
my @operationQueue = ();
my $timerHandle = undef;
my $friends_file_version;
my $friends_file_written;

my $friends_PLAIN_HOSTS = 0;
my $friends_REGEXP_HOSTS = 1;

# Idea of moving userhost to a regexp and
# the subroutine userhost_to_regexp were adapted from people.pl,
# an userlist script made by Marcin 'Qrczak' Kowalczyk.
# You can get that script from http://qrnik.knm.org.pl/~qrczak/irssi/people.pl
# or from http://scripts.irssi.org/

# HostToRegexp
my %htr = ();
# fill the hash
foreach my $i (0..255) {
	my $ch = chr($i);
	$htr{$ch} = "\Q$ch\E";
}
# wildcards to regexp
$htr{'?'} = '.';
$htr{'*'} = '.*';

# str userhost_to_regexp($userhost)
# translates userhost to a regexp
# lowercases host-part
sub userhost_to_regexp($) {
	my ($mask) = @_;
	$mask = lowercase_hostpart($mask);
	$mask =~ s/(.)/$htr{$1}/g;
	return $mask;
}

# str lowercase_hostpart($userhost)
# returns userhost with host-part loweracased
sub lowercase_hostpart($) {
	my ($host) = @_;
	$host =~ s/(.+)\@(.+)/sprintf("%s@%s", $1, lc($2));/eg;
	return $host;
}

# void print_version($what)
# print's version of script/userlist
sub print_version($) {
	my ($what) = @_;
	$what = lc($what);

	if ($what eq "filever") {
		if ($friends_file_version) {
			my ($verbal, $numeric) = $friends_file_version =~ /^(.+)\ \(([0-9]+)\)$/;
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_file_version', $verbal, $numeric);
		} else {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_empty');
		}
	} elsif ($what eq "filewritten" && $friends_file_written) {
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($friends_file_written);
		my $written = sprintf("%4d%02d%02d %02d:%02d:%02d", ($year+1900), ($mon+1), $mday, $hour, $min, $sec);
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_file_written', $written);
	} else {
		my ($verbal, $numerical) = $friends_version =~ /^(.+)\ \(([0-9]+)\)$/;
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_version', $verbal, $numerical);
	}
}

# void print_releasenote()
# suprisingly, prints a release note ;^)
sub print_releasenote {
	foreach my $line (split(/\n/, $release_note)) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notice', $line);
	}
}

# str friends_crypt($plain)
# returns crypt()ed $plain, using random salt;
# or "" if $plain is empty
sub friends_crypt {
	return if ($_[0] eq "");
	return crypt("$_[0]", (join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64]));
}

# bool friend_passwdok($idx, $pwd)
# returns 1 if password is ok, 0 if isn't
sub friends_passwdok {
	my ($idx, $pwd) = @_;
	return 1 if (crypt("$pwd", $friends[$idx]->{password}) eq $friends[$idx]->{password});
	return 0;
}

# arr get_friends_channels($idx)
# returns list of $friends[$idx] channels
sub get_friends_channels {
	return keys(%{$friends[$_[0]]->{channels}});
}

# arr get_friends_hosts($idx, $type)
# returns list of $friends[$idx] regexp-hostmask if $type=$friends_REGEXP_HOSTS
# returns list of plain-hostmasks if $type=$friends_PLAIN_HOSTS
sub get_friends_hosts($$) {
	if ($_[1] == $friends_REGEXP_HOSTS) {
		return keys(%{$friends[$_[0]]->{regexp_hosts}});
	} elsif ($_[1] == $friends_PLAIN_HOSTS) {
		return keys(%{$friends[$_[0]]->{hosts}});
	}
	return undef;
}

# str get_friends_flags($idx[, $chan])
# returns list of $chan flags for $idx
# $chan can be also 'global' or undef
# case insensitive about the $chan
sub get_friends_flags {
	my ($idx, $chan) = @_;
	$chan = lc($chan);
	if ($chan eq "" || $chan eq "global") {
		return $friends[$idx]->{globflags};
	} else {
		foreach my $friendschan (get_friends_channels($idx)) {
			if ($chan eq lc($friendschan)) {
				return $friends[$idx]->{channels}->{$friendschan}->{flags};
			}
		}
	}
	return;
}

# str get_friends_delay($idx[, $chan])
# returns $chan delay for $idx
# returns "" if $chan is 'global' or undef
# case insensitive about the $chan
sub get_friends_delay {
	my ($idx, $chan) = @_;
	$chan = lc($chan);
	if ($chan && $chan ne "global") {
		foreach my $friendschan (get_friends_channels($idx)) {
			if ($chan eq lc($friendschan)) {
				return undef if ($friends[$idx]->{channels}->{$friendschan}->{delay} eq '');
				return $friends[$idx]->{channels}->{$friendschan}->{delay};
			}
		}
	}
	return;
}

# struct friend new_friend($handle, $hoststr, $globflags, $chanflagstr, $password, $comment)
# hoststr is: *!foo@host1 *!bar@host2 *!?baz@host3
# chanstr is: #chan1,flags,delay #chan2,flags,delay
sub new_friend {
	my $friend = {};
	my $idx = scalar(@friends);
	$friend->{handle} = $_[0];
	$all_handles->{lc($_[0])} = $idx;
	$friend->{globflags} = $_[2];
	$friend->{password} = $_[4];
	$friend->{comment} = $_[5];
	$friend->{friends} = [];

	foreach my $host (split(/ +/, $_[1])) {
		my $regexp_host = userhost_to_regexp($host);
		my ($firstalpha) = $host =~ /\@(.)/;
		$firstalpha = lc($firstalpha);

		$friend->{hosts}->{$host} = $regexp_host;
		$friend->{regexp_hosts}->{$regexp_host} = $host;
		$all_regexp_hosts->{allhosts}->{$regexp_host} = lc($_[0]);
		$all_regexp_hosts->{$firstalpha}->{$regexp_host} = lc($_[0]);
		$all_hosts->{$host} = lc($_[0]);
	}

	foreach my $cfd (split(/ +/, $_[3])) {
		# $cfd format: #foobar,oikl,15 (channelname,flags,delay)
		my ($channel, $flags, $delay) = split(",", $cfd, 3);
		$friend->{channels}->{$channel}->{exist} = 1;
		$friend->{channels}->{$channel}->{flags} = $flags;
		$friend->{channels}->{$channel}->{delay} = $delay;
	}

	return $friend;
}

# get_regexp_hosts_by_letter($letter)
# returns those regexp masks whose host part begins with $letter, '?' or '*'
sub get_regexp_hosts_by_letter($) {
	my $l = lc(substr($_[0], 0, 1));
	my @tmphosts = ();
	push(@tmphosts, keys(%{$all_regexp_hosts->{$l}}));
	push(@tmphosts, keys(%{$all_regexp_hosts->{'?'}}));
	push(@tmphosts, keys(%{$all_regexp_hosts->{'*'}}));
	return @tmphosts;
}

# bool is_allowed_flag($flag)
# will be obsolete, soon.
sub is_allowed_flag { return 1; }

# bool is_ctcp_command($command)
# check if $command is one of the implemented ctcp commands
sub is_ctcp_command {
	my ($command) = @_;
	$command = uc($command);
	foreach my $allowed (split(/[,\ \|]+/, uc(Irssi::settings_get_str('friends_ctcp_commands')))) {
		return 1 if ($command eq $allowed);
	}
	return 0;
}

# int get_idx($nick, $userhost)
# returns idx of the friend or -1 if not a friend
# The New Approach (TM) :)
sub get_idx($$) {
	my ($nick, $userhost) = @_;
	$userhost = lowercase_hostpart($nick.'!'.$userhost);
	my ($letter) = $userhost =~ /\@(.)/;
	my $idx = -1;

	foreach my $regexp_host (get_regexp_hosts_by_letter($letter)) {
		if ($userhost =~ /^$regexp_host$/) {
			return get_idxbyhand($all_regexp_hosts->{allhosts}->{$regexp_host});
		}
	}

	return -1;
}

# int get_idxbyhand($handle)
# returns $idx of friend with $handle or -1 if no such handle
# case insensitive
sub get_idxbyhand($) {
	my $handle = lc($_[0]);
	if (exists $all_handles->{$handle}) {
		return $all_handles->{$handle};
	}
	return -1;
}

# int get_handbyidx($idx)
# returns $handle of friend with $idx or undef if no such $idx
# case sensitive
sub get_handbyidx($) {
	my ($idx) = @_;
	return undef unless ($idx > -1 && $idx < scalar(@friends));
	return $friends[$idx]->{handle};
}

# bool friend_has_host($idx, $host)
# checks wheter $host matches any of $friend[$idx]'s hostmasks
# The New Approach (TM)
sub friend_has_host($$) {
	my ($idx, $host) = @_;
	$host = lowercase_hostpart($host);
	foreach my $regexp_host (keys (%{$friends[$idx]->{regexp_hosts}})) {
		return 1 if ($host =~ /^$regexp_host$/);
	}
	return 0;
}

# void add_host($idx, $host)
# adds $host wherever it's needed
# $friends[$idx]->{handle} is A MUST for add_host() to work properly.
sub add_host($$) {
	my ($idx, $host) = @_;
	my $regexp_host = userhost_to_regexp($host);
	my ($firstalpha) = $host =~ /\@(.)/;
	$firstalpha = lc($firstalpha);

	$friends[$idx]->{hosts}->{$host} = $regexp_host;
	$friends[$idx]->{regexp_hosts}->{$regexp_host} = $host;
	$all_regexp_hosts->{allhosts}->{$regexp_host} = lc($friends[$idx]->{handle});
	$all_regexp_hosts->{$firstalpha}->{$regexp_host} = lc($friends[$idx]->{handle});
	$all_hosts->{$host} = lc($friends[$idx]->{handle});
}

# int del_host($idx, $host)
# deletes $host from wherever it is
# if given $host arg is '*', removes all hosts of this friend
sub del_host($$) {
	my ($idx, $host) = @_;
	my $deleted = 0;

	foreach my $regexp_host (keys (%{$friends[$idx]->{regexp_hosts}})) {
		if ($host eq '*' || $host =~ /^$regexp_host$/) {
			my $plain_host = $friends[$idx]->{regexp_hosts}->{$regexp_host};
			my ($l) = $plain_host =~ /\@(.)/;

			delete $friends[$idx]->{hosts}->{$plain_host};
			delete $friends[$idx]->{regexp_hosts}->{$regexp_host};
			delete $all_regexp_hosts->{allhosts}->{$regexp_host};
			delete $all_regexp_hosts->{$l}->{$regexp_host};
			delete $all_hosts->{$plain_host};
			$deleted++;
		}
	}
	return $deleted;
}

# bool friend_has_chanrec($idx, $chan)
# checks wheter $friend[$idx] has a $chan record
# case insensitive
sub friend_has_chanrec {
	my ($idx, $chan) = @_;
	$chan = lc($chan);
	foreach my $friendschan (get_friends_channels($idx)) {
		return 1 if ($chan eq lc($friendschan));
	}
	return 0;
}

# bool add_chanrec($idx, $chan)
# adds an empty $chan record to $friends[$idx]
# case sensitive
sub add_chanrec {
	my ($idx, $chan) = @_;
	return 0 unless ($idx > -1 && $idx < scalar(@friends));
	$friends[$idx]->{channels}->{$chan}->{exist} = 1;
	return 1;
}

# bool del_chanrec($idx, $chan)
# deletes $chan record from $friends[$idx]
# case *in*sensitive
sub del_chanrec {
	my ($idx, $chan) = @_;
	my $deleted = 0;
	foreach my $friendschan (get_friends_channels($idx)) {
		if (lc($chan) eq lc($friendschan)) {
			delete $friends[$idx]->{channels}->{$friendschan};
			$deleted = 1;
		}
	}
	return $deleted;
}

# arr del_friend($idxs)
# removes friends
# removes all hosts corresponding to this friend
# returns array of removed friends
sub del_friend($) {
	my ($idxlist) = @_;
	my @idxs = split(/ /, $idxlist);
	return -1 unless (scalar(@idxs) > 0);
	my @tmp = ();
	my @result = ();
	my @todelete = ();

	foreach my $idx (@idxs) {
		my $handle = get_handbyidx($idx);
		if (!(!defined $handle || grep(/^\Q$handle\E$/i, @todelete))) {
			push(@todelete, $handle);
			del_host($idx, '*');
		}
	}
	for (my $idx = 0; $idx < @friends; $idx++) {
		if (grep(/^\Q$friends[$idx]->{handle}\E$/i, @todelete)) {
			push(@result, $friends[$idx]);
		} else {
			push(@tmp, $friends[$idx]);
		}
	}
	@friends = @tmp;
	update_allhandles();
	return @result;
}

# void update_all_handles()
# updates $all_handles
sub update_allhandles {
	$all_handles = {};
	for (my $idx = 0; $idx < @friends; $idx++) {
		$all_handles->{lc($friends[$idx]->{handle})} = $idx
	}
}

# bool is_unique_handle($handle)
# checks if the $handle is unique for the whole friendlist
# returns 1 if there's no such $handle
# returns 0 if there is one.
sub is_unique_handle($) {
	return !exists $all_handles->{lc($_[0])};
}

# str choose_handle($proposed)
# tries to choose a handle, closest to the $proposed one
sub choose_handle {
	my ($proposed) = @_;
	my $counter = 0;
	my $handle = $proposed;

	# do this until we have an unique handle
	while (!is_unique_handle($handle)) {
		if (($handle !~ /([0-9]+)$/) && !$counter) {
			# first, if handle doesn't end with a digit, append '2'
			# (but only in first step)
			$handle .= "2";
		} elsif ($counter < 85) {
			# later, increase the trailing number by one
			# do that 84 times
			my ($number) = $handle =~ /([0-9]+)$/;
			++$number;
			$handle =~ s/([0-9]+)$/$number/;
		} elsif ($counter == 85) {
			# then, if it didn't helped, make $handle = $proposed."_"
			$handle = $proposed . "_";
		} elsif ($counter < 90) {
			# if still unsuccessful, append "_" to the handle
			# do that 4 times
			$handle .= "_";
		} else {
			# if THAT didn't help -- make some silly handle
			# and exit the loop
			$handle = $proposed.'_'.(join '', (0..9, 'a'..'z')[rand 36, rand 36, rand 36, rand 36]);
			last;
		}
		++$counter;
	}

	# return our glorious handle ;-)
	return $handle;
}

# bool friend_has_flag($idx, $flag[, $chan])
# returns true if $friends[$idx] has $flag for $chan
# (checks global flags, if $chan is 'global' or undef)
# returns false if hasn't
# case sensitive about the FLAG
# case insensitive about the chan.
sub friend_has_flag {
	my ($idx, $flag, $chan) = @_;
	$chan = "global" unless ($chan ne '');

	return 1 if (get_friends_flags($idx, $chan) =~ /\Q$flag\E/);
	return 0;
}

# bool friend_is_wrapper($idx, $chan, $goodflag, $badflag)
# something to replace friend_is_* subs
# true on: ($channel +$goodflag OR global +$goodflag) AND ($badflag == "" OR NOT $channel +$badflag))
sub friend_is_wrapper($$$$) {
	my ($idx, $chan, $goodflag, $badflag) = @_;
	return 0 unless ($idx > -1);
	if ((friend_has_flag($idx, $goodflag, $chan) ||
		 friend_has_flag($idx, $goodflag, undef)) && 
		($badflag eq "" || !friend_has_flag($idx, $badflag, $chan))) {
		return 1;
	}
	return 0;
}

# bool add_flag($idx, $flag[, $chan])
# adds $flag to $idx's $chan flags
# $chan can be 'global' or undef
# case insensitive about the $chan -- chooses the proper case.
# returns 1 on success
sub add_flag {
	my ($idx, $flag, $chan) = @_;
	$chan = lc($chan);
	if ($chan eq "" || $chan eq "global") {
		$friends[$idx]->{globflags} .= $flag;
		return 1;
	} else {
		foreach my $friendschan (get_friends_channels($idx)) {
			if ($chan eq lc($friendschan)) {
				$friends[$idx]->{channels}->{$friendschan}->{flags} .= $flag;
				return 1;
			}
		}
	}
	return 0;
}

# bool del_flag($idx, $flag[, $chan])
# removes $flag from $idx's $chan flags
# $chan can be 'global' or undef
# case insensitive about the $chan -- chooses the proper case.
sub del_flag {
	my ($idx, $flag, $chan) = @_;
	$chan = lc($chan);
	if ($chan eq "" || $chan eq "global") {
		$friends[$idx]->{globflags} =~ s/\Q$flag\E//g;
		return 1;
	} else {
		foreach my $friendschan (get_friends_channels($idx)) {
			if ($chan eq lc($friendschan)) {
				$friends[$idx]->{channels}->{$friendschan}->{flags} =~ s/\Q$flag\E//i;
				return 1;
			}
		}
	}
	return 0;
}

# bool change_delay($idx, $delay, $chan)
# alters $idx's delay time for $chan
# fails if $chan is 'global' or undef
sub change_delay {
	my ($idx, $delay, $chan) = @_;
	$chan = lc($chan);
	if ($chan && $chan ne "global") {
		foreach my $friendschan (get_friends_channels($idx)) {
			if ($chan eq lc($friendschan)) {
				$friends[$idx]->{channels}->{$friendschan}->{delay} = $delay;
				return 1;
			}
		}
	}
	return 0;
}

# void list_friend($window, $who, @data)
# prints an info line about certain friend.
# $who may be handle or idx
# if you want to improve the look of the script, you should
# change /format friends_*, probably.
sub list_friend {
	my ($win, $who, @data) = @_;
	my $idx = $who;

	$idx = get_idxbyhand($who) unless ($who =~ /^[0-9]+$/);

	return unless ($idx > -1 && $idx < scalar(@friends));

	my $globflags = get_friends_flags($idx, undef);

	$win = Irssi::active_win() unless ($win);

	$win->printformat(MSGLEVEL_CRAP, 'friends_line_head',
		$idx,
		get_handbyidx($idx),
		(($globflags) ? "$globflags" : "[none]"),
		(($friends[$idx]->{password}) ? "yes" : "no"));

	$win->printformat(MSGLEVEL_CRAP, 'friends_line_hosts',
		join(", ", get_friends_hosts($idx, $friends_PLAIN_HOSTS)) );

	foreach my $chan (get_friends_channels($idx)) {
		my $flags = get_friends_flags($idx, $chan);
		my $delay = get_friends_delay($idx, $chan);
		$win->printformat(MSGLEVEL_CRAP, 'friends_line_chan', 
			$chan,
			(($flags) ? "$flags" : "[none]"),
			(defined($delay) ? "$delay" : "random"));
	}

	if ($friends[$idx]->{comment}) {
		$win->printformat(MSGLEVEL_CRAP, 'friends_line_comment', $friends[$idx]->{comment});
	}

	for my $item (@data) {
		my ($ircnet, $nick, $chanstr) = split(" ", $item);
		next unless (defined $ircnet);
		$win->printformat(MSGLEVEL_CRAP, 'friends_line_currentnick', $nick, $ircnet) if ($nick ne '');;
		$win->printformat(MSGLEVEL_CRAP, 'friends_line_channelson', join(", ", split(/,/, $chanstr)), $ircnet) if ($chanstr ne '');
	}
}

# void add_operation($server, "#channel", "op|voice|deop|devoice|kick|kickban", timeout, "nick1", "nick2", ...)
# adds a delayed (or not) operation
sub add_operation {
	my ($server, $channel, $operation, $timeout, @nicks) = @_;

	# my dear queue, don't grow too big, mmkay? ;^)
	my $maxsize = Irssi::settings_get_int('friends_max_queue_size');
	$maxsize = $default_friends_max_queue_size unless ($maxsize > 0);
	return if (@operationQueue >= $maxsize);

	push(@operationQueue,
	{
		server=>$server,		# server object
		left=>$timeout,			# seconds left
		nicks=>[ @nicks ],		# array of nicks
		channel=>$channel,		# channel name
		operation=>$operation	# operation ("op", "voice" and so on)
	});

	$timerHandle = Irssi::timeout_add(1000, 'timer_handler', 0) unless (defined $timerHandle);
}

# void timer_handler()
# handles delay timer
sub timer_handler {
	my @ops = ();

	# splice out expired timeouts. if they are expired, move them to
	# local ops-queue. this allows creating new operations to the queue
	# in the operation. (we're not (yet) doing that)

	for (my $c = 0; $c < @operationQueue;) {
		if ($operationQueue[$c]->{left} <= 0) {
			push(@ops, splice(@operationQueue, $c, 1));
		} else {
			++$c;
		}
	}

	for (my $c = 0; $c < @ops; ++$c) {
		my $op = $ops[$c];
		my $channel = $op->{server}->channel_find($op->{channel});

		# check if $channel is still active (you might've parted)
		if ($channel) {
			my @operationNicks = ();
			foreach my $nickStr (@{$op->{nicks}}) {
				my $nick = $channel->nick_find($nickStr);
				# check if there's still such nick (it might've quit/parted)
				if ($nick) {
					if ($op->{operation} eq "op" && !$nick->{op}) {
						push(@operationNicks, $nick->{nick});
					}
					if ($op->{operation} eq "voice" && !$nick->{voice} &&
						(!$nick->{op} || Irssi::settings_get_bool('friends_voice_opped'))) {
						push(@operationNicks, $nick->{nick});
					}
					if ($op->{operation} eq "deop" && $nick->{op}) {
						push(@operationNicks, $nick->{nick});
					}
					if ($op->{operation} eq "devoice" && $nick->{voice}) {
						push(@operationNicks, $nick->{nick});
					}
					if ($op->{operation} eq "kick") {
						push(@operationNicks, $nick->{nick});
					}
					if ($op->{operation} eq "kickban") {
						push(@operationNicks, $nick->{nick});
					}
				}
			}
			# final stage: issue desired command if we're a chanop
			$channel->command($op->{operation}." ".join(" ", @operationNicks)) if ($channel->{chanop});
		}
	}

	# decrement timeouts.
	for (my $c = 0; $c < @operationQueue; ++$c) {
		--$operationQueue[$c]->{left};
	}

	# if operation queue is empty, remove timer.
	if (!@operationQueue && $timerHandle) {
		Irssi::timeout_remove($timerHandle);
		$timerHandle = undef;
	}
}

# str replace_home($string)
# replaces '~' with current $ENV{HOME}
sub replace_home($) {
	my ($string) = @_;
	my $home = $ENV{HOME};
	return undef unless ($string);
	$string =~ s/^\~/$home/;
	return $string;
}

# void load_friends($inputfile)
# loads friends from file. uses $inputfile if supplied.
# if not, uses friends_file setting. if this setting is empty,
# uses default -- $friends_file
sub load_friends {
	my ($inputfile) = @_;
	my $friendfile = undef;

	if (defined($inputfile)) {
		$friendfile = replace_home($inputfile);
	} else {
		$friendfile = replace_home(Irssi::settings_get_str('friends_file'));
	}

	$friendfile = $default_friends_file unless (defined $friendfile);

	if (-e $friendfile && -r $friendfile) {
		@friends = ();
		$all_hosts = {};
		$all_regexp_hosts = {};
		$all_handles = {};

		local *F;
		open(F, "<", $friendfile) or return -1;
		local $/ = "\n";
		while (<F>) {
			my ($handle, $hosts, $globflags, $chanstr, $password, $comment);
			chop;

			# dealing with empty lines
			next if (/^[\w]*$/);

			# dealing with comments
			if (/^\#/) {
				# script version
				if (/^\# version = (.+)/) { $friends_file_version = $1; }
				# timestamp
				if (/^\# written = ([0-9]+)/) { $friends_file_written = $1; }
				next;
			}

			# split by '%'
			my @fields = split("%", $_);
			foreach my $field (@fields) {
				if ($field =~ /^handle=(.*)$/) { $handle = $1; }
				elsif ($field =~ /^hosts=(.*)$/) { $hosts = $1; }
				elsif ($field =~ /^globflags=(.*)$/) { $globflags = $1; }
				elsif ($field =~ /^chanflags=(.*)$/) { $chanstr = $1; }
				elsif ($field =~ /^password=(.*)$/) { $password = $1; }
				elsif ($field =~ /^comment=(.*)$/) { $comment = $1; }
			}

			# handle cannot start with a digit
			# skip friend if it does
			next if ($handle =~ /^[0-9]/);

			# if all fields were processed, and $handle is unique,
			# make a friend and add it to $friends
			if (is_unique_handle($handle)) {
				push(@friends, new_friend($handle, $hosts, $globflags, $chanstr, $password, $comment));
			} else {
				Irssi::printformat(MSGLEVEL_CRAP, 'friends_duplicate', $handle);
			}
		}

		close(F);

		# if everything's ok -- print a message
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_loaded', scalar(@friends), $friendfile);
	} else {
		# whoops, bail out, but do not clear the friendlist.
		Irssi::print("Cannot load $friendfile");
	}
}

# void cmd_loadfriends($data, $server, $channel)
# handles /loadfriends [file]
sub cmd_loadfriends {
	my ($file) = split(/ +/, $_[0]);
	load_friends($file);
}

# void save_friends($auto)
# saving friends to file
sub save_friends {
	my ($auto, $inputfile) = @_;
	local *F;
	my $friendfile = undef;
	my $backup_suffix = Irssi::settings_get_str('friends_backup_suffix');
	$backup_suffix = "." . time if ($backup_suffix eq '');

	if (defined $inputfile) {
		$friendfile = replace_home($inputfile);
	} else {
		$friendfile = replace_home(Irssi::settings_get_str('friends_file'));
	}
	$friendfile = $default_friends_file unless (defined $friendfile);

	my $backupfile = $friendfile . $backup_suffix;
	my $tmpfile = $friendfile . ".tmp" . time;

	# be sane
	my $old_umask = umask(077);

	if (!defined open(F, ">", $tmpfile)) {
		Irssi::print("Couldn't open $tmpfile for writing");
		return 0;
	}

	# write script's version and update corresponding variable
	$friends_file_version = $friends_version;
	print(F "# version = $friends_file_version\n");
	# write current unixtime and update corresponding variable
	$friends_file_written = time;
	print(F "# written = $friends_file_written\n");

	# go through all entries
	for (my $idx = 0; $idx < @friends; ++$idx) {
		# get friend's channels, corresponding flags and delay values
		# then put them as c,f,d fields into @chanstr
		my @chanstr = ();
		foreach my $chan (get_friends_channels($idx)) {
			$chan =~ s/\%//g;
			push(@chanstr, $chan.",".(get_friends_flags($idx, $chan)).",".
				(get_friends_delay($idx, $chan)));
		}

		# write the actual line
		print(F join("%",
			"handle=".get_handbyidx($idx),
			"hosts=".(join(" ", get_friends_hosts($idx, $friends_PLAIN_HOSTS))),
			"globflags=".(get_friends_flags($idx, undef)),
			"chanflags=".(join(" ", @chanstr)),
			"password=".$friends[$idx]->{password},
			"comment=".$friends[$idx]->{comment},
			"\n"));
	}
	# done.

	close(F);

	rename($friendfile, $backupfile) if (Irssi::settings_get_bool('friends_backup_friendlist'));
	rename($tmpfile, $friendfile);

	Irssi::printformat(MSGLEVEL_CRAP, 'friends_saved', scalar(@friends), $friendfile) unless ($auto);

	# restore umask
	umask($old_umask);
}

# void cmd_savefriends($data, $server, $channel)
# handles /savefriends [filename]
sub cmd_savefriends {
	my ($file) = split(/ +/, $_[0]);
	eval {
		save_friends(0, $file);
	};
	Irssi::print("Saving friendlist failed: $?") if ($?);
}

# void event_setup_saved($config, $auto)
# calls save_friends to save friendslist while saving irssi's setup
# (if friends_autosave is turned on)
sub event_setup_saved {
	my ($config, $auto) = @_;
	return unless (Irssi::settings_get_bool('friends_autosave'));
	eval {
		save_friends($auto);
	};
	Irssi::print("Saving friendlist failed: $?") if ($?);
}

# void event_setup_reread($config)
# calls load_friends() while setup is re-readed
# (if friends_autosave is turned on)
sub event_setup_reread {
	load_friends() if (Irssi::settings_get_bool('friends_autosave'));
}

# int calculate_delay($idx, $chan)
# calculates delay
sub calculate_delay {
	my ($idx, $chan) = @_;
	my $delay = get_friends_delay($idx, $chan);
	my $min = Irssi::settings_get_int('friends_delay_min');
	my $max = Irssi::settings_get_int('friends_delay_max');

	# lazy man's sanity checks :-P
	$min = $default_delay_min if $min < 0;
	$max = $default_delay_max if $min > $max;
	$max = $max + $min if $min > $max;

	# make a random delay unless we've got a fixed delay time already
	$delay = int(rand ($max - $min)) + $min unless ($delay =~ /^[0-9]+$/);

	return $delay;
}

# void check_friends($server, $channelstr, $options, @nickstocheck)
# checks the given nicklist, channelname and server against the friendlist
sub check_friends {
	my ($server, $channelName, $options, @nicks) = @_;
	my $channel = $server->channel_find($channelName);
	my $delay = 30;
	my %opList = ();
	my %voiceList = ();

	# server and channel -- a must.
	return unless ($server && $channelName);

	# proper !channels support, hopefully
	my $noPrefix = $channelName;
	$noPrefix = '!' . substr($channelName, 6) if ($channelName =~ /^\!/);

	# get settings
	my $voice_opped = Irssi::settings_get_bool('friends_voice_opped');

	# for each nick from the given list
	foreach my $nick (@nicks) {
		# check if $nick is a friend
		if ((my $idx = get_idx($nick->{nick}, $nick->{host})) > -1) {

			# notify about the join if "showjoins" is set
			if ($options =~ /showjoins/) {
				my $globflags = get_friends_flags($idx, undef);
				my $chanflags = get_friends_flags($idx, $noPrefix);

				my $win = $server->window_item_find($channelName);
				$win = Irssi::active_win() unless ($win);
				$win->printformat(MSGLEVEL_CRAP, 'friends_joined',
					$nick->{nick},
					get_handbyidx($idx),
					($globflags) ? $globflags : "[none]",
					$noPrefix,
					($chanflags) ? $chanflags : "[none]");
			}

			# notice1: password doesn't matter in this loop
			# notice2: channel flags take precedence over the global ones

			# handle auto-(op|voice)
			if (friend_is_wrapper($idx, $noPrefix, "a", undef)) {
				# add $nick to opList{delay} if he is a valid op
				# and isn't opped already
				# 'valid op' means: (chanflag +o OR globflag +o) AND NOT chanflag +d
				if (friend_is_wrapper($idx, $noPrefix, "o", "d") && !$nick->{op}) {
					# calculate delay, add to $opList{$delay}
					$delay = calculate_delay($idx, $noPrefix);
					$opList{$delay}->{$nick->{nick}} = 1;
				}
				# add $nick to voiceList{delay} if he is a valid voice
				# and isn't voiced already
				if (friend_is_wrapper($idx, $noPrefix, "v", undef) && !$nick->{voice} &&
					(!$nick->{op} || $voice_opped)) {
					# calculate delay, add to $voiceList{$delay}
					$delay = calculate_delay($idx, $noPrefix);
					$voiceList{$delay}->{$nick->{nick}} = 1;
				}
			}
		}
	}

	# opping
	foreach my $delay (keys %opList) {
		add_operation($server, $channelName, "op", $delay, keys %{$opList{$delay}});
	}
	# voicing
	foreach my $delay (keys %voiceList) {
		add_operation($server, $channelName, "voice", $delay, keys %{$voiceList{$delay}});
	}

	timer_handler();
}

# void event_kick($server, $data, $nick)
# handles kicks (for revenging)
sub event_kick {
	my ($server, $data, $kicker) = @_;
	my ($channel, $kicked, $reason) = $data =~ /^([^ ]+) ([^ ]+) :(.*)$/;
	my $channelInfo = $server->channel_find($channel);
	my $myNick = $server->{nick};
	my $victimInfo = undef;
	my $kickerInfo = undef;
	my $victimIdx = -1;
	my $kickerIdx = -1;
	my $noPrefix = $channel;
	$noPrefix = '!' . substr($channel, 6) if ($channel =~ /^\!/);

	return unless ($channelInfo);

	# don't bother checking our own kicks, or self-kicks
	return if ($kicker eq $myNick || $kicker eq $kicked);

	$victimInfo = $channelInfo->nick_find($kicked);
	$kickerInfo = $channelInfo->nick_find($kicker);
	# we'll need both
	return unless ($victimInfo && $kickerInfo);

	$victimIdx = get_idx($victimInfo->{nick}, $victimInfo->{host});
	$kickerIdx = get_idx($kickerInfo->{nick}, $kickerInfo->{host});

	# check if we know the victim, and it wasn't a master who deopped
	if ($victimIdx > -1 && !friend_is_wrapper($kickerIdx, $noPrefix, "m", undef)) {
		# RRRRREVENGE!
		my $revengemode = Irssi::settings_get_int('friends_revenge_mode');
		if (Irssi::settings_get_bool('friends_revenge') && ($revengemode > -1 && $revengemode < 4) &&
		    friend_is_wrapper($victimIdx, $noPrefix, "p", undef)) {
			# 0 Deop the user.
			add_operation($server, $channel, "deop", 1, $kicker);
			if ($revengemode > 0) {
				# 1 Deop the user and give them the +D flag for the channel.
				if ($kickerIdx < 0) {
					push(@friends, new_friend(
						choose_handle("bad1"),		# handle
						"*!".$kickerInfo->{host}, 	# hostmask
						undef,				# globflags
						$noPrefix.",D,",		# channel,chanflags,chandelay
						undef,				# password
						"Kicked ".get_handbyidx($victimIdx)." off $noPrefix on $server->{tag}"));
				} else {
					friends_chflags($kickerIdx, "+D", $noPrefix);
				}
				if ($revengemode > 1 && $channelInfo->{chanop}) {
					# 2 Deop the user, give them the +D flag for the channel, and kick them.
					$channelInfo->command("KICK ". $channel . " ".$kicker. " Don't mess with my friends[.pl]");
					if ($revengemode > 2) {
						# 3 Deop the user, give them the +D flag for the channel, kick, and ban them.
						$channelInfo->command("MODE ". $channel ." +b *!".$kickerInfo->{host});
					}
				}
			}
		}
	}
}

# void event_modechange($server, $data, $nick)
# handles modechanges and learning
sub event_modechange {
	my ($server, $data, $nick) = @_;
	my ($channel, $modeStr, $nickStr) = $data =~ /^([^ ]+) ([^ ]+) (.*)$/;
	my @modeargs = split(" ", $nickStr);
	my $ptr = 0;
	my $mode = undef;
	my $gotOpped = 0;
	my $learnFriends = Irssi::settings_get_bool('friends_learn');
	my $opperInfo = undef;
	my $opperIdx = -1;
	my $learnFromOpper = 0;
	my $channelInfo = $server->channel_find($channel);
	my $myNick = $server->{nick};
	# !channels support :)
	my $noPrefix = $channel;
	$noPrefix = '!' . substr($channel, 6) if ($channel =~ /^\!/);

	# don't bother checking our own modes
	return if ($nick eq $myNick);

	# we need $channelInfo to do almost every other things;
	return unless (defined $channelInfo);

	$opperInfo = $channelInfo->nick_find($nick);
	$opperIdx = get_idx($opperInfo->{nick}, $opperInfo->{host}) if ($opperInfo);

	# learn if learning is enabled, 
	# we know the opper, and we're allowed to learn from him
	if ($learnFriends && $opperIdx > -1 &&
	    (friend_is_wrapper($opperIdx, $noPrefix, "F", undef))) {
		$learnFromOpper = 1;
	}

	# process the mode string
	foreach my $char (split(//, $modeStr)) {

		if ($char eq "+") { $mode = "+";
		} elsif ($char eq "-") { $mode = "-";

		# op/deop, it wasn't a self-op/deop
		} elsif (lc($char) eq "o" && ($nick ne $modeargs[$ptr])) {
			my $victim = $channelInfo->nick_find($modeargs[$ptr]);
			my $victimIdx = -1;
			$victimIdx = get_idx($victim->{nick}, $victim->{host}) if ($victim);

			# someone +o foobar
			if ($mode eq "+") {
				# hooray, i got opped!
				if ($modeargs[$ptr] eq $myNick) {
					$gotOpped = 1;
				# should learn?
				} elsif ($learnFromOpper && $victim) {
					# handle the learning stuff.
					my $friend;

					if ($victimIdx == -1) {
						# we got someone not known before
						# choose a handle for him and add him to our friendlist with +L $noPrefix
						$friend = new_friend(
							choose_handle($modeargs[$ptr]),		# handle
							"*!".$victim->{host}, 			# hostmask
							undef,					# globflags
							$noPrefix.",L,",			# channel,chanflags,chandelay
							undef,					# password
							"Learnt (opped by $friends[$opperIdx]->{handle} on $noPrefix\@$server->{tag})"	# comment
						);
						push(@friends, $friend);
					} else {
						# we know him already
						$friend = $friends[$victimIdx];
					}

					if ($victimIdx == -1 || get_friends_flags($victimIdx, $noPrefix) eq "L") {
						# add him to the opper's friendlist
						# ($opperIdx != -1, we've checked that with $learnFromOpper earlier)
						push(@{$friends[$opperIdx]->{friends}}, $friend);
					}

				} elsif (friend_is_wrapper($victimIdx, $noPrefix, "D", undef) && !friend_is_wrapper($opperIdx, $noPrefix, "m", undef)) {
					add_operation($server, $channel, "deop", 1, $modeargs[$ptr]);
				}

			# deop
			} elsif ($mode eq "-") {
				if ($victim) {
					# check if we know the victim, and it wasn't a master who deopped
					if ($victimIdx > -1 && !friend_is_wrapper($opperIdx, $noPrefix, "m", undef)) {
						# RRRRREVENGE!
						my $revengemode = Irssi::settings_get_int('friends_revenge_mode');
						if (Irssi::settings_get_bool('friends_revenge') && ($revengemode > -1 && $revengemode < 4) &&
						    friend_is_wrapper($victimIdx, $noPrefix, "p", undef)) {
							# 0 Deop the user.
							add_operation($server, $channel, "deop", 1, $nick);
							if ($revengemode > 0 && $opperInfo) {
								# 1 Deop the user and give them the +D flag for the channel.
								if ($opperIdx < 0) {
									push(@friends, new_friend(
										choose_handle("bad1"),		# handle
										"*!".$opperInfo->{host}, 	# hostmask
										undef,				# globflags
										$noPrefix.",D,",		# channel,chanflags,chandelay
										undef,				# password
										"Deopped ".get_handbyidx($victimIdx)." on $noPrefix\@$server->{tag}"));
								} else {
									friends_chflags($opperIdx, "+D", $noPrefix);
								}

								if ($revengemode > 1 && $channelInfo->{chanop}) {
									# 2 Deop the user, give them the +D flag for the channel, and kick them.
									$channelInfo->command("KICK ". $channel . " ".$opperInfo->{nick}. " Don't mess with my friends[.pl]");
									if ($revengemode > 2) {
										# 3 Deop the user, give them the +D flag for the channel, kick, and ban them.
										$channelInfo->command("MODE ". $channel ." +b *!".$opperInfo->{host});
									}
								}
							}
						}
						# if a +r'ed person was deopped, perform a reop
						if (friend_is_wrapper($victimIdx, $noPrefix, "r", "d")) {
							add_operation($server, $channel, "op", calculate_delay($victimIdx, $channel), $modeargs[$ptr])
						}
					}
				}
			}
			# increase pointer, 'o' mode has argument, *always*
			$ptr++;
		} elsif ($char =~ /[beIqdhvk]/ || ($char eq "l" && $mode eq "+")) {
			# increase pointer, these modes have arguments as well
			$ptr++;
		}
	}

	if ($gotOpped) {
		# calling check_friends with !BLARHchannel, since removing BLARH is done there
		check_friends($server, $channel, undef, $channelInfo->nicks());
	}
}

# void event_massjoin($channel, $nicklist)
# handles join event
sub event_massjoin {
	my ($channel, $nicksList) = @_;
	my @nicks = @{$nicksList};
	my $server = $channel->{'server'};
	my $channelName = $channel->{name};
	my $options;
	$options = "showjoins|" if Irssi::settings_get_bool("friends_show_flags_on_join");

	my $begin = time;

	check_friends($server, $channelName, $options, @nicks);

	if ((my $duration = time - $begin) >= 1) {
		# if checking took more than 1 second -- print a message about it
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_checking', $channelName, $duration, $server->{address});
	}
}

# void event_nicklist_changed($channel, $nick, $oldnick)
# some kind of nick-tracking
# alters operationQueue if someone from there has changed nick
sub event_nicklist_changed {
	my ($channel, $nick, $oldnick) = @_;

	# nicknames are case insensitive
	return if (lc($oldnick) eq lc($nick->{nick}));

	# cycle through all operation queues
	for (my $c = 0; $c < @operationQueue; ++$c) {
		# temporary array
		my @nickarr = ();
		# is there any nick in this queue that needs altering?
		my $found = 0;

		# skip if tags don't match
		next unless ($operationQueue[$c]->{server}->{tag} eq $channel->{server}->{tag});

		# cycle through all nicks in single operation queue
		foreach my $opnick (@{$operationQueue[$c]->{nicks}}) {
			# if $oldnick was in the queue
			if (lc($oldnick) eq lc($opnick)) {
				# ... replace it with the new one
				push(@nickarr, $nick->{nick});
				$found = 1;
			} else {
				# ... else -- keep the old one
				push(@nickarr, $opnick);
			}
		}

		# replace $opQ[$c]->{nicks} with our new nicklist if any nick needed updating
		$operationQueue[$c]->{nicks} = [ @nickarr ] if ($found);
	}
}

# void event_server_disconnected($server, $anything)
# removes all queues related to $server from @operationQueue
sub event_server_disconnected {
	my ($server, $anything) = @_;
	my @removed = ();

	# cycle through all operation queues
	for (my $c = 0; $c < @operationQueue;) {
		if ($operationQueue[$c]->{server}->{tag} eq $server->{tag}) {
			push(@removed, splice(@operationQueue, $c, 1));
		} else {
			++$c;
		}
	}

	# if operation queue is empty, remove the timer.
	if (scalar(@removed) && !@operationQueue && $timerHandle) {
		Irssi::timeout_remove($timerHandle);
		$timerHandle = undef;
	}
}

# void cmd_opfriends($data, $server, $channel)
# handles /opfriends #channel
sub cmd_opfriends {
	my ($data, $server, $channel) = @_;
	my ($chan) = split(/ +/, $data);
	my $usage = "/OPFRIENDS [channel]";
	my @chanstocheck = ();

	if (!$server) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_general', "No server item in current window");
		return;
	}

	# no argument given
	if ($chan eq "") {
		if (!$channel) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_general', "No usable channel item in current window");
			return;
		} elsif ($channel->{type} ne "CHANNEL") {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_general', "Current window item is not a channel");
			return;
		} else {
			push(@chanstocheck, $channel->{name});
		}
	# all channels on current server
	} elsif ($chan eq "*") {
		foreach my $c ($server->channels()) {
			push(@chanstocheck, $c->{name});
		}
	# specified channel on current server
	} else {
		push(@chanstocheck, $chan);
	}

	foreach my $channelName (@chanstocheck) {
		my $chanInfo = $server->channel_find($channelName);
		if (!$chanInfo) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_notonchan', $channelName);
			next;
		}

		# !channels support
		my $noPrefix = $chanInfo->{name};
		$noPrefix = '!' . substr($chanInfo->{name}, 6) if ($chanInfo->{name} =~ /^\!/);

		my @opnicks = ();
		foreach my $nick ($chanInfo->nicks()) {
			# skip already opped nicks
			next if ($nick->{op});
			# check for friends
			my $idx = get_idx($nick->{nick}, $nick->{host});
			# skip not-friends
			next unless ($idx > -1);
			# add $nick's nick to oplist if enough flags for this channel
			push(@opnicks, $nick->{nick}) if (friend_is_wrapper($idx, $noPrefix, "o", "d"));
		}

		# add stuff to the operation queue
		add_operation($server, $noPrefix, "op", "0", @opnicks);
	}

	timer_handler();
}

# void cmd_queue($data, $server, $channel)
# expands to queue show|purge|flush
sub cmd_queue($$$) {
	my ($data, $server, $channel) = @_;
	Irssi::command_runsub("queue", $data, $server, $channel);
}

# bool queue_flush_expand(%what)
# "... and few lines of The Magic Code. Now. Your poison is ready."
sub queue_flush_expand {
	my ($flush) = @_;
	my $result = 0;

	foreach my $s (keys(%{$flush})) {
		# is this server active?
		my $server = Irssi::server_find_tag($s);
		next unless (defined $server);

		foreach my $c (keys(%{$flush->{$s}})) {
			# is this channel active?
			my $channel = $server->channel_find($c);
			next unless (defined $channel);

			# for each pending operation
			foreach my $o (sort keys(%{$flush->{$s}->{$c}})) {
				my @nicklist = ();
				foreach my $nickStr (sort keys(%{$flush->{$s}->{$c}->{$o}})) {
					# is this nick still here?
					if (my $nick = $channel->nick_find($nickStr)) {
						push(@nicklist, $nick->{nick});
					}
				}

				if (my $nickstr = join(" ", @nicklist)) {
					$channel->command($o." ".$nickstr);
					$result = 1;
				}
			}
		}
	}
	return $result;
}

# void queue_show($data, $server, $channel)
# handles /QUEUE SHOW
# prints @operationQueue's contents
sub cmd_queue_show {
	if (!@operationQueue) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_queue_empty');
		return;
	}

	# cycle through all operation queues
	for (my $c = 0; $c < @operationQueue; ++$c) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_queue_line1', 
			$c,
			$operationQueue[$c]->{left},
			$operationQueue[$c]->{operation}
		);
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_queue_line2', 
			$operationQueue[$c]->{server}->{address},
			$operationQueue[$c]->{channel},
			join(", ", @{$operationQueue[$c]->{nicks}})
		);
	}
}

# void cmd_queue_flush($data, $server, $channel)
# handles /QUEUE FLUSH <number|all>
# flushes given/all queue(s)
sub cmd_queue_flush {
	my ($data) = split(/ +/, $_[0]);
	my $usage = "/QUEUE FLUSH <number|all>";
	my @flushqueue = ();
	my $flushdata = {};
	my @removed = ();

	if (!@operationQueue) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_queue_empty');
		return;
	}

	if ($data eq "") {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notenoughargs', $usage);
		return;
	}

	if ($data =~ /^all/i) {
		@flushqueue = @operationQueue;
		@operationQueue = ();
		push(@removed, $data);
	} elsif ($data =~ /^[0-9,]+$/) {
		my $numstr = join(" ", split(/,/, $data));
		for (my $num = 0; $num < @operationQueue;) {
			if ($numstr =~ /\b$num\b/) {
				push(@flushqueue, splice(@operationQueue, $num, 1));
				push(@removed, $num);
			} else {
				$num++
			}
		}
	} else {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_badargs', $usage);
		return;
	}

	if (@flushqueue) {
		# don't ask... ;^)
		foreach my $q (@flushqueue) {
			my $s = $q->{server}->{tag};
			my $c = $q->{channel};
			my $o = $q->{operation};
			foreach my $n (@{$q->{nicks}}) {
				$flushdata->{$s}->{$c}->{$o}->{$n} = 1 unless ($o eq "voice" && 
					exists $flushdata->{$s}->{$c}->{op}->{$n} && 
					!Irssi::settings_get_bool('friends_voice_opped'));
			}
		}
		my $result = ((queue_flush_expand($flushdata)) ? "seems ok" : "looks like nothing done");
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_queue_removed', "Flushed", join(", ", @removed), $result);
	}

	if (!@operationQueue && $timerHandle) {
		Irssi::timeout_remove($timerHandle);
		$timerHandle = undef;
	}
}

# void cmd_queue_purge($data, $server, $channel)
# handles /QUEUE PURGE <number|all>
# removes given/all queue(s)
sub cmd_queue_purge {
	my ($data) = split(/ +/, $_[0]);
	my $usage = "/QUEUE PURGE <number|all>";
	my $result;
	my @removed;

	if (!@operationQueue) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_queue_empty');
		return;
	}

	if ($data eq "") {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notenoughargs', $usage);
		return;
	}

	if ($data =~ /^all/i) {
		@operationQueue = ();
		$result = "OK";
		push(@removed, $data);
	} elsif ($data =~ /^[0-9,]+$/) {
		my $numstr = join(" ", split(/,/, $data));
		for (my $num = 0; $num < @operationQueue;) {
			if ($numstr =~ /\b$num\b/) {
				splice(@operationQueue, $num, 1);
				push(@removed, $num);
				$result = "OK";
			} else {
				$num++
			}
		}
	} else {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_badargs', $usage);
		return;
	}

	Irssi::printformat(MSGLEVEL_CRAP, 'friends_queue_removed', "Purged", join(", ", @removed), $result) if (defined $result);

	if (!@operationQueue && $timerHandle) {
		Irssi::timeout_remove($timerHandle);
		$timerHandle = undef;
	}
}

# void friends_chflags($idx, $string[, $chan])
# parses the $string and calls add_flag() or del_flag()
sub friends_chflags {
	my ($idx, $string, $chan) = @_;
	my $mode = undef;
	my $char;

	$chan = "global" if ($chan eq "" || lc($chan) eq "global");

	foreach my $char (split(//, $string)) {
		if ($char eq "+") { $mode = "+";
		} elsif ($char eq "-") { $mode = "-";
		} elsif ($mode) {
			if ($mode eq "+") {
				# ADDING flags
				# add chan record, if needed
				add_chanrec($idx, $chan) if ($chan ne "global" && !friend_has_chanrec($idx, $chan));
				if (!friend_has_flag($idx, $char, $chan)) {
					# add this flag if he doesn't have it yet
					add_flag($idx, $char, $chan);
				}
			} elsif ($mode eq "-") {
				# REMOVING flags
				if ($chan eq "global" || friend_has_chanrec($idx, $chan)) {
					del_flag($idx, $char, $chan);
				}
			}
		}
	}
}

# void cmd_chflags($data, $server, $channel)
# handles /chflags <handle> <+-flags> [#channel]
sub cmd_chflags {
	my ($handle, $flags, @chans) = split(/ +/, $_[0]);
	my $usage = "/CHFLAGS <handle> <+/-flags> [#channel1] [#channel2] ...";

	# strip %'s
	$handle =~ s/\%//g;

	# not enough args
	if ($handle eq "" || $flags eq "") {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notenoughargs', $usage);
		return;
	}

	# bad args
	# if the 'flags' part doesn't start with + or -
	if ($flags !~ /^[\+\-]/) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_badargs', $usage);
		return;
	}

	# get idx, yell and return if it isn't valid
	my $idx = get_idxbyhand($handle);
	if ($idx == -1) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_nosuch', $handle);
		return;
	}

	# if #channel wasn't specified -- we'll deal with global flags
	push(@chans, "global") unless (@chans);

	# go through all channels specified
	foreach my $chan (@chans) {
		# strip %'s
		$chan =~ s/\%//g;

		# 'executing +foo-bar for someone (where)'
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_chflagexec', $flags, get_handbyidx($idx), $chan);
		# make changes
		friends_chflags($idx, $flags, $chan);

		my $flagstr = get_friends_flags($idx, $chan);
		# 'current $chan flags for someone are: +blah/[none]'
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_currentflags', (($flagstr) ? $flagstr : "[none]"), get_handbyidx($idx), $chan);
	}
}

# void cmd_chhandle($data, $server, $channel)
# handles /chhandle <oldhandle> <newhandle>
sub cmd_chhandle {
	my ($oldhandle, $newhandle) = split(/ +/, $_[0]);
	my $usage = "/CHHANDLE <oldhandle> <newhandle>";

	# strip %'s
	$newhandle =~ s/\%//g;

	# not enough args
	if ($oldhandle eq "" || $newhandle eq "") {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notenoughargs', $usage);
		return;
	}

	# get idx, yell and return if it's not valid
	my $idx = get_idxbyhand($oldhandle);
	if ($idx == -1) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_nosuch', $oldhandle);
		return;
	}

	# proper case for later printformat
	$oldhandle = get_handbyidx($idx);

	# handle cannot start with a digit
	if ($newhandle =~ /^[0-9]/) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_badhandle', $newhandle, 
			"Handle may not start with a digit");
		return;
	}

	if (lc($newhandle) eq lc($oldhandle)) {
		# funny case, only changes case of letters, omit the whole change_handle()
		$friends[$idx]->{handle} = $newhandle;
	} else {
		# check if $newhandle is unique
		# if not, print appropriate message and return
		if (!is_unique_handle($newhandle)) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_notuniqhandle', $newhandle);
			return;
		}
		# ok, everything seems fine now, let's change the handle.
		change_handle($oldhandle, $newhandle);
	}

	# ... and print a message
	Irssi::printformat(MSGLEVEL_CRAP, 'friends_changed_handle', $oldhandle, $newhandle);
}

# void change_handle($oldhandle, $newhandle)
# changes handle in appropriate structures
sub change_handle($$) {
	my ($old, $new) = @_;
	my $idx = get_idxbyhand($old);
	my $lc_new = lc($new);
	foreach my $host (get_friends_hosts($idx, $friends_PLAIN_HOSTS)) {
		my ($l) = $host =~ /\@(.)/;
		my $regexp_host = userhost_to_regexp($host);
		$all_regexp_hosts->{allhosts}->{$regexp_host} = $lc_new;
		$all_regexp_hosts->{lc($l)}->{$regexp_host} = $lc_new;
		$all_hosts->{$host} = $lc_new;
		delete $all_handles->{lc($old)};
		$all_handles->{$lc_new} = $idx;
		$friends[$idx]->{handle} = $new;
	}
}

# void cmd_chpass($data, $server, $channel)
# handles /chpass <handle> [pass]
# if pass is empty, removes password
# otherwise, crypts it and sets as current one
sub cmd_chpass {
	my ($handle, $pass) = split(/ +/, $_[0]);
	my $usage = "/CHPASS <handle> [newpassword]";

	# not enough args
	if ($handle eq "") {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notenoughargs', $usage);
		return;
	}

	# get idx, yell and return if it's not valid
	my $idx = get_idxbyhand($handle);
	if ($idx == -1) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_nosuch', $handle);
		return;
	}

	# crypt and set password. then print a message
	$friends[$idx]->{password} = friends_crypt("$pass");
	Irssi::printformat(MSGLEVEL_CRAP, 'friends_chpassexec', get_handbyidx($idx));
}

# void cmd_chdelay($data, $server, $channel)
# handles /chdelay <handle> <delay> <#channel>
# use delay=0 to get instant opping
# use delay>0 to get fixed opping delay
# use delay='random' or delay='none' or delay = 'remove'
#  to remove fixed delay (make it random)
sub cmd_chdelay {
	my ($handle, $delay, $chan) = split(/ +/, $_[0]);
	my $usage = "/CHDELAY <handle> <delay> <#channel>";
	my $value = undef;

	# strip %'s
	$chan =~ s/\%//g;

	# not enough args
	if ($handle eq "" || $delay eq "" || $chan eq "") {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notenoughargs', $usage);
		return;
	}

	# if $chan doesn't start with one of the [!&#+]
	if ($chan !~ /^[\!\&\#\+]/) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_badargs', $usage);
		return;
	}

	# check validness of $delay
	if ($delay =~ /^[0-9]+$/) {
		# numeric value
		$value = $delay;
	} elsif ($delay =~ /^(remove|random|none)$/i) {
		# 'remove', 'random' or 'none'
		$value = undef;
	} else {
		# badargs, return
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_badargs', $usage);
		return;
	}

	# get idx, yell and return if it's not valid
	my $idx = get_idxbyhand($handle);
	if ($idx == -1) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_nosuch', $handle);
		return;
	}

	# check if $idx has got $chan record.
	# add one if needed
	add_chanrec($idx, $chan) unless (friend_has_chanrec($idx, $chan));

	# finally, set it, and print a message
	change_delay($idx, $value, $chan);
	Irssi::printformat(MSGLEVEL_CRAP, 'friends_changed_delay', get_handbyidx($idx),
		$chan, (defined($value) ? $value : "[random]"));
}

# void cmd_comment($data, $server, $channel)
# handles /comment <handle> [comment]
# if comment is empty, removes it
# otherwise, sets it as the current one
sub cmd_comment {
	my ($handle, $comment) = split(" ", $_[0], 2);
	my $usage = "/COMMENT <handle> [comment]";

	# not enough args
	if ($handle eq "") {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notenoughargs', $usage);
		return;
	}

	# get idx, yell and return if it's not valid
	my $idx = get_idxbyhand($handle);
	if ($idx == -1) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_nosuch', $handle);
		return;
	}

	# remove %'s and trailing spaces (just-in-case ;)
	$comment =~ s/\%//g;
	$comment =~ s/[\ ]+$//;

	# finally, set it, and print a message
	$friends[$idx]->{comment} = $comment;

	if ($comment ne '') {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_comment_added', get_handbyidx($idx), $comment);
	} else {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_comment_removed', get_handbyidx($idx));
	}
}

# void cmd_listfriend($data, $server, $chanel)
# handles /listfriends [what]
# 'what' can be either handle, channel name, 1,2,5,15-style, host mask or empty.
sub cmd_listfriends {
	if (@friends == 0) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_empty');
	} else {
		my ($data) = @_;
		my $counter = 0;
		# remove whitespaces
		$data =~ s/[\t\ ]+//g;
		my $win = Irssi::active_win();

		if ($data =~ /^[\!\&\#\+]/) {
			# deal with channel
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_friendlist', "channel " . $data);
			for (my $idx = 0; $idx < @friends; ++$idx) {
				if (friend_has_chanrec($idx, $data)) {
					list_friend($win, $idx, undef);
					$counter++;
				}
			}
		} elsif ($data =~ /^[0-9,]+$/) {
			# deal with 1,2,5,15 style
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_friendlist', $data);
			foreach my $idx (split(/,/, $data)) {
				if ($idx < @friends) {
					list_friend($win, $idx, undef);
					$counter++;
				}
			}
		} elsif ($data =~ /^.*\!.*\@.*$/) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_friendlist', "matching " . $data);
			# /* FIXME */
			my $regexp_data = userhost_to_regexp($data);
			for (my $idx = 0; $idx < @friends; ++$idx) {
				foreach my $regexp_host (get_friends_hosts($idx, $friends_REGEXP_HOSTS)) {
					if ($data =~ /^$regexp_host$/ || $friends[$idx]->{regexp_hosts}->{$regexp_host} =~ /^$regexp_data$/) {
						list_friend($win, $idx, undef);
						$counter++;
						last;
					}
				}
			}
		} elsif ($data ne "") {
			if ((my $idx = get_idxbyhand($data)) > -1) {
				# deal with handle
				Irssi::printformat(MSGLEVEL_CRAP, 'friends_friendlist', $data);
				list_friend($win, $idx, undef);
				$counter++;
			} else {
				Irssi::printformat(MSGLEVEL_CRAP, 'friends_nosuch', $data);
			}
		} else {
			# deal with every entry
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_friendlist', "all");
			for (my $idx = 0; $idx < @friends; ++$idx) {
				list_friend($win, $idx, undef);
				$counter++;
			}
		}
		if ($counter) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_friendlist_count', $counter, (($counter > 1) ? "s" : ""));
		}
	}
}

# void cmd_addfriend($data, $server, $channel)
# handles /addfriend <handle> <hostmask> [flags]
# if 'flags' is empty, uses friends_default_flags instead
sub cmd_addfriend {
	my ($handle, $host, $flags) = split(/ +/, $_[0]);
	my $server = $_[1];
	my $usage = "/ADDFRIEND <handle|nick> [<hostmask> [flags]]";

	# strip %'s
	$handle =~ s/\%//g;
	$host =~ s/\%//g;

	# not enough args
	if ($handle eq "") {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notenoughargs', $usage);
		return;
	}

	# handle cannot start with a digit
	if ($handle =~ /^[0-9]/) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_badhandle', $handle, "Handle may not start with a digit");
		return;
	}

	# assume we want /addfriend somenick
	if ($host eq "") {
		# no server item in current window
		if (!$server) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_general', "No server item in current window");
			return;
		}

		# redirect userhost reply to event_isfriend_userhost()
		# caution: This works only with Irssi 0.7.98.CVS (20011117) and newer
		$server->redirect_event("userhost", 1, $handle, 0, undef, {
					"event 302" => "redir userhost_addfriend"});
		# send our query
		$server->send_raw("USERHOST :$handle");
		return;
	}

	# check must be unique
	if (!is_unique_handle($handle)) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notuniqhandle', $handle);
		return;
	}

	# add friend.
	push(@friends, new_friend($handle, $host, undef, undef, undef, undef));
	Irssi::printformat(MSGLEVEL_CRAP, 'friends_added', $handle);

	# check 'flags' parameter, add default flags if empty.
	$flags = Irssi::settings_get_str('friends_default_flags') unless ($flags);

	# add flags and print them if needed
	if ($flags) {
		# check if $flags start with a '+'. if not, prepend one.
		$flags = "+".$flags unless ($flags =~ /^\+/);

		# our new friend should have $idx=(scalar(@friends)-1) now, so we'll use it.
		my $idx = scalar(@friends) - 1;

		friends_chflags($idx, $flags, "global");
		$flags = get_friends_flags($idx, undef);
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_currentflags', $flags, $handle, "global") if ($flags);
	}
}

# void event_addfriend_userhost($server, $reply, $servername)
# handles redirected USERHOST replies
# (part of /addfriend)
sub event_addfriend_userhost {
	my ($mynick, $reply) = split(/ +/, $_[1]);
	my $server = $_[0];
	my ($nick, $user, $host) = $reply =~ /^:?([^\*=]*)\*?=.(.*)@(.*)/;
	my $string = $nick . '!' . $user . '@' . $host;
	my $friend_matched = 0;

	# try matching ONLY if the response is positive
	if (defined $nick && defined $user && defined $host) {
		if ((my $idx = get_idx($nick, $user.'@'.$host)) > -1) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_already_added', $nick, get_handbyidx($idx));
			return;
		}
		# handle
		my $handle = choose_handle($nick);
		# *~^=-ident
		$user =~ s/^[\~\+\-\^\=]+/\*/;

		# add friend.
		push(@friends, new_friend($handle, '*!'.$user.'@'.$host, undef, undef, undef, undef));
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_added', $handle);
		return;
	}

	# failed
	Irssi::printformat(MSGLEVEL_CRAP, 'friends_general', "No such nick");
}

# void cmd_delfriend($data, $server, $channel)
# handles /delfriend <handle|number>
# supports /delfriend 2-5,foohand,1,4,10,11-22
sub cmd_delfriend {
	my ($who) = split(/ +/, $_[0]);
	my $usage = "/DELFRIEND <handle|number>";

	# strip %'s
	$who =~ s/\%//g;

	# not enough args
	if ($who eq "") {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notenoughargs', $usage);
		return;
	}

	my @todelete = ();
	foreach my $what (split(/[\ ,]/, $who)) {
		if ($what =~ /^[0-9]+$/) {
			# /delfriend 15
			next unless ($what > -1 && $what < scalar(@friends));
			push(@todelete, $what) unless (grep(/^$what$/, @todelete));
		} elsif ($what =~ /^([0-9]+)\-([0-9]+)$/) {
			# /delfriend 2-10
			my ($start, $end) = $what =~ /([0-9]+)\-([0-9]+)/;
			next if ($start > $end);
			for my $i ($start .. $end) {
				next unless ($i > -1 && $i < scalar(@friends));
				push(@todelete, $i) unless (grep(/^$i$/, @todelete));
			}
		} else {
			# /delfriend foobar
			my $delidx = get_idxbyhand($what);
			push(@todelete, $delidx) unless ($delidx < 0 || grep(/^$delidx$/, @todelete));
		}
	}
	@todelete = sort {$a <=> $b} @todelete;

	return unless (@todelete);

	my @result = del_friend(join(" ", @todelete));
	foreach my $deleted (@result) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_removed', $deleted->{handle});
	}
}

# void cmd_addhost($data, $server, $channel)
# handles /addhost <handle> <hostmask1> [hostmask2] ...
# hostmask may not overlap with any of the current ones
sub cmd_addhost {
	my ($handle, @hosts) = split(/ +/, $_[0]);
	my $usage = "/ADDHOST <handle> <hostmask1> [hostmask2] [hostmask3] ...";

	# not enough args
	if ($handle eq "" || !@hosts) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notenoughargs', $usage);
		return;
	}

	# get idx, yell and return if it's not valid
	my $idx = get_idxbyhand($handle);
	if ($idx == -1) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_nosuch', $handle);
		return;
	}

	for (my $i = 0; $i < scalar(@hosts); $i++) {
		my $data = $hosts[$i];
		$data =~ s/\%//g;
		my $regexp_data = userhost_to_regexp($data);
		my $found = 0;
		my $who = "";

		# /* FIXME */
		foreach my $plain_host (keys %{$all_hosts}) {
			if (!$found && $plain_host =~ /^$regexp_data$/) {
				$found = 1;
				$who = get_handbyidx(get_idxbyhand($all_hosts->{$plain_host}));
				last;
			}
		}

		# /* FIXME again */
		foreach my $regexp_host (get_friends_hosts($idx, $friends_REGEXP_HOSTS)) {
			last if ($found);
			if ($data =~ /^$regexp_host$/ || $friends[$idx]->{regexp_hosts}->{$regexp_host} =~ /^$regexp_data$/) {
				$found = 1;
				$who = get_handbyidx($idx);
				last;
			}
		}

		if (!$found) {
			add_host($idx, $data);
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_host_added', get_handbyidx($idx), $data);
		} else {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_host_exists', $who, $data);
		}
	}
}

# void cmd_delhost($data, $server, $channel)
# handles /delhost <handle> <hostmask>
# hostmask should be EXACTLY the same as one in $friends[$idx]->{hosts}
sub cmd_delhost {
	my ($handle, $host) = split(/ +/, $_[0]);
	my $usage = "/DELHOST <handle> <hostmask>";

	# strip %'s
	$host =~ s/\%//g;

	# not enough args
	if ($handle eq "" || $host eq "") {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notenoughargs', $usage);
		return;
	}

	# get idx, yell and return if it's not valid
	my $idx = get_idxbyhand($handle);
	if ($idx == -1) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_nosuch', $handle);
		return;
	}

	# delete host, print appropriate message
	if (del_host($idx, $host)) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_host_removed', get_handbyidx($idx), $host);
	} else {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_host_notexists', get_handbyidx($idx), $host);
	}
}

# void cmd_delchanrec($data, $server, $channel)
# handles /delchanrec <handle> <#channel>
sub cmd_delchanrec {
	my ($handle, $chan) = split(/ +/, $_[0]);
	my $usage = "/DELCHANREC <handle> <#channel>";

	# strip %'s
	$chan =~ s/\%//g;

	# not enough args
	if ($handle eq "" || $chan eq "") {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notenoughargs', $usage);
		return;
	}

	# get idx, yell and return if it's not valid
	my $idx = get_idxbyhand($handle);
	if ($idx == -1) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_nosuch', $handle);
		return;
	}

	# delete chanrec, print appropriate message
	if (del_chanrec($idx, $chan)) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_chanrec_removed', get_handbyidx($idx), $chan);
	} else {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_chanrec_notexists', get_handbyidx($idx), $chan);
	}
}

# void cmd_findfriends($data, $server, $channel)
# handles /findfriends [handle]
# prints online friends
sub cmd_findfriends {
	my ($data) = split(/ +/, $_[0]);
	my $f2w = Irssi::settings_get_str('friends_findfriends_to_windows');
	my $win = undef;
	my $lc_data = lc($data);
	$win = Irssi::active_win() unless ($f2w || $data eq '');

	# gathering info
	my $by_hand = {};
	foreach my $channel (Irssi::channels()) {
		my $myNick = $channel->{server}->{nick};
		my $tag = lc($channel->{server}->{tag});
		foreach my $nick ($channel->nicks()) {
			# don't count myself
			next if ($nick->{nick} eq $myNick);
			if ((my $idx = get_idx($nick->{nick}, $nick->{host})) > -1) {
				$by_hand->{lc($friends[$idx]->{handle})}->{$tag}->{$channel->{name}} = $nick->{nick};
			}
		}
	}

	# looking for a specified handle
	if ($data ne '') {
		my $handle = undef;
		foreach my $h (keys %{$by_hand}) {
			next if ($lc_data ne $h);
			$handle = $h;
			last;
		}
		return unless (defined $handle);

		# tricky part.
		my @data = ();
		foreach my $ircnet (keys %{$by_hand->{$handle}}) {
			my ($nick, $chan);
			foreach $chan (keys %{$by_hand->{$handle}->{$ircnet}}) {
				$nick = $by_hand->{$handle}->{$ircnet}->{$chan};
				last;
			}
			my $chanstr = join(",", sort keys %{$by_hand->{$handle}->{$ircnet}});
			push(@data, join(" ", $ircnet, $nick, $chanstr));
		}
		# list them.
		list_friend(Irssi::active_win(), $handle, @data);

	# looking for anyone
	} else {
		foreach my $handle (keys %{$by_hand}) {
			foreach my $ircnet (keys %{$by_hand->{$handle}}) {
				my $server = Irssi::server_find_tag($ircnet);
				next unless (defined $server);
				foreach my $chan (sort keys %{$by_hand->{$handle}->{$ircnet}}) {
					my @data = ();
					my $nick = $by_hand->{$handle}->{$ircnet}->{$chan};
					$win = $server->window_item_find($chan);
					$win = Irssi::active_win() unless (defined $win && $f2w);
					my $chanstr = join(",", sort keys %{$by_hand->{$handle}->{$ircnet}});
					push(@data, join(" ", $ircnet, $nick, $chanstr));
					list_friend($win, $handle, @data);
				}
			}
		}
	}
}

# void cmd_isfriend($data, $server, $channel)
# handles /isfriend <nick>
sub cmd_isfriend {
	my ($data, $server, $channel) = @_;
	my $usage = "/ISFRIEND <nick>";

	# remove trailing spaces
	$data =~ s/[\t\ ]+$//;

	# not enough args
	if ($data eq "") {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_notenoughargs', $usage);
		return;
	}

	# no server item in current window
	if (!$server) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_general', "No server item in current window");
		return;
	}

	# redirect userhost reply to event_isfriend_userhost()
	# caution: This works only with Irssi 0.7.98.CVS (20011117) and newer
	$server->redirect_event("userhost", 1, $data, 0, undef, {
				"event 302" => "redir userhost_friends"});
	# send our query
	$server->send_raw("USERHOST :$data");
}

# void event_isfriend_userhost($server, $reply, $servername)
# handles redirected USERHOST replies
# (part of /isfriend)
sub event_isfriend_userhost {
	my ($mynick, $reply) = split(/ +/, $_[1]);
	my $server = $_[0];
	my ($nick, $user, $host) = $reply =~ /^:?([^\*=]*)\*?=.(.*)@(.*)/;
	my $string = $nick . '!' . $user . '@' . $host;
	my $friend_matched = 0;

	# try matching ONLY if the response is positive
	if (defined $nick && defined $user && defined $host) {
		if ((my $idx = get_idx($nick, $user.'@'.$host)) > -1) {
			my @chans = ();
			foreach my $channel ($server->channels()) {
				push(@chans, $channel->{name}) if ($channel->nick_find($nick));
			}
			my $chanstr = join(",", @chans);
			list_friend(Irssi::active_win(), $idx, join(" ", $server->{tag}, $nick, $chanstr));
			$friend_matched++;
		}
	}

	# print message
	if ($friend_matched) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_endof', "/isfriend", $nick);
	} else {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_nosuch', $nick);
	}
}

# void event_whois($server, $text, $servername)
# handles additional whois data
sub event_whois {
	my ($server, $text, $servername) = @_;
	return unless (Irssi::settings_get_bool('friends_show_whois_extra'));

	my ($on, $nick, $user, $host, $as, $rn) = split(/[\ ]:?/, $text, 6);
	my $idx = get_idx($nick, $user.'@'.$host);
	return unless ($idx > -1);

	$server->printformat($nick, MSGLEVEL_CRAP, 'friends_whois', get_handbyidx($idx), ($friends[$idx]->{globflags} ? $friends[$idx]->{globflags} : "none"));
}

# void cmd_flushlearnt($data, $server, $channel)
# cycles through all users and removes every chanrec with flag L
# then, if no other stuff left (specific delay, other chanrecs,
# global flags, password maybe) -- deletes user.
# clears the opping tree too
sub cmd_flushlearnt {
	my @todelete = ();
	# cycle through the whole friendlist
	for (my $idx = 0; $idx < @friends; ++$idx) {
		my $was_learnt = 0;

		# foreach friend, clear his opping tree
		$friends[$idx]->{friends} = [];

		# now go through all friend's channel entries
		foreach my $chan (get_friends_channels($idx)) {
			# if 'L' is the only flag for this chan
			if (get_friends_flags($idx, $chan) eq "L") {
				# remove channel record and print a message
				$was_learnt = del_chanrec($idx, $chan);
				Irssi::printformat(MSGLEVEL_CRAP, 'friends_chanrec_removed', get_handbyidx($idx), $chan);
			}
		}

		# delete friend, if he has exactly 1 host, no global flags,
		# neither password, nor chanrecs, and he was learnt.
		if ($was_learnt && scalar(get_friends_hosts($idx, $friends_REGEXP_HOSTS)) == 1  && !get_friends_flags($idx, undef) &&
			!get_friends_channels($idx) && !$friends[$idx]->{password}) {
			push(@todelete, $idx) unless (grep(/^$idx$/, @todelete));
		}
	}
	return unless @todelete;

	@todelete = sort {$a <=> $b} @todelete;
	my @result = del_friend(join(" ", @todelete));
	foreach my $deleted (@result) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_removed', $deleted->{handle});
	}
}

# void cmd_opping_tree($data, $server, $channel)
# prints the Opping Tree
sub cmd_oppingtree {
	my $found = 0;
	# cycle through the whole friendlist
	for (my $idx = 0; $idx < @friends; ++$idx) {
		# get friend's friends
		my @friendFriends = @{$friends[$idx]->{friends}};
		if (@friendFriends) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_general', "Opping tree:") unless ($found);
			$found = 1;
			# print info about our friend
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_optree_line1', get_handbyidx($idx));
			my %masks;
			# get all masks opped by him
			foreach my $friend (@friendFriends) {
				foreach my $host (keys(%{$friend->{hosts}})) {
					$masks{$host}++;
					last;
				}
			}
			# print them, along with the opcount
			foreach my $friend (sort keys %masks) {
				Irssi::printformat(MSGLEVEL_CRAP, 'friends_optree_line2', $masks{$friend}, $friend);
			}
		}
	}
	Irssi::printformat(MSGLEVEL_CRAP, 'friends_general', "Opping tree is empty.") unless ($found);
}

# void event_ctcpmsg($server, $args, $sender, $senderhsot, $target)
# handles ctcp requests
sub event_ctcpmsg {
	my ($server, $args, $sender, $userhost, $target) = @_;

	# return, if ctcp is not for us
	my $myNick = $server->{nick};
	return if (lc($target) ne lc($myNick));

	# return, if we don't process ctcp requests
	return unless (Irssi::settings_get_bool('friends_use_ctcp'));

	# return in case of strange things
	return unless (defined $sender && defined $userhost);

	my @cmdargs = split(/ +/, $args);

	# prepare arguments:
	# get 1st arg, uppercase it
	my $command = uc($cmdargs[0]);
	# get 2nd arg
	my $channelName = $cmdargs[1];
	# get 3rd arg
	my $password = $cmdargs[2];

	# check if $command is one of friends_ctcp_commands. return if it isn't
	return unless (is_ctcp_command($command));

	# this is supposed to be processed BEFORE any other ctcp commands
	# /ctcp nick IDENT handle password
	if ($command eq "IDENT") {
		my $idxguess = get_idxbyhand($channelName);
		# looks like a valid friend, password already set, provided password looks fine
		if ($idxguess > -1 && $friends[$idxguess]->{password} ne "" && friends_passwdok($idxguess, $password)) {
			# do the IDENT stuff here.
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpident', $channelName, $sender.'!'.$userhost);
			add_host($idxguess, "*!$userhost");
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_host_added', $channelName, '*!'.$userhost);
			$server->command("/^NOTICE $sender Identified as " . get_handbyidx($idxguess));
		} else {
			my $reason = "No reason ;)";
			if ($idxguess < 0) {
				$reason = "No such handle: $channelName";
			} elsif ($friends[$idxguess]->{password} eq "") {
				$reason = "Can't IDENT $channelName without password set";
			} elsif (!friends_passwdok($idxguess, $password)) {
				$reason = "Bad password for $channelName";
			}
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $sender.'!'.$userhost, $reason);
		}
		goto SIGSTOP;
	}

	my $idx = get_idx($sender, $userhost);

	# if get_idx* failed, return.
	if ($idx == -1) {
		my $reason = "Not a friend" . (($command ne "PASS") ? " for $channelName" : "");
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $sender.'!'.$userhost, $reason);
		goto SIGSTOP;
	}

	# we'll use handle instead of $sender!$userhost in messages
	my $handle = get_handbyidx($idx);

	# check if $channelName was supplied.
	# (first argument, should be always given)
	if ($channelName eq "") {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Not enough arguments");
		goto SIGSTOP;
	}

	# /ctcp nick PASS pass [newpass]
	if ($command eq "PASS") {
		# if someone has password already set - we can only *change* it
		if ($friends[$idx]->{password}) {
			# if cmdargs[1] ($channelName, that is) is a valid password (current)
			if (!friends_passwdok($idx, $channelName)) {
				Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Bad password");
				goto SIGSTOP;
			}
			# and $cmdargs[2] ($password, that is) contains something ...
			if (defined $password) {
				# ... process allowed password change.
				# in this case, old password is in $channelName
				# and new password is in $password
				$friends[$idx]->{password} = friends_crypt("$password");
				Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcppass', $handle, $sender."!".$userhost);
				# send a quiet notice to sender
				$server->command("/^NOTICE $sender Password changed to: $password");
			} else {
				# in this case, notify sender about his current password quietly
				$server->command("/^NOTICE $sender You already have a password set");
			}
		# if $idx doesn't have a password, we will *set* it
		} else {
			# in this case, new password is in $channelName
			# and $password is unused
			$friends[$idx]->{password} = friends_crypt("$channelName");
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcppass', $handle, $sender.'!'.$userhost);
			# send a quiet notice to sender
			$server->command("/^NOTICE $sender Password set to: $channelName");
		}
		goto SIGSTOP;
	}

	# get channel object. if not found -- yell, stop the signal, and return
	my $channel = $server->channel_find($channelName);
	if (!$channel) {
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Not on channel $channelName");
		goto SIGSTOP;
	}

	my $sender_rec = $channel->nick_find($sender);

	# /ctcp nick OP #channel password
	if ($command eq "OP") {
		if (!friend_is_wrapper($idx, $channelName, "o", "d")) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Not enough flags");
			goto SIGSTOP;
		}
		if (!friends_passwdok($idx, $password)) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Bad password");
			goto SIGSTOP;
		}

		# process allowed opping
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcprequest', $handle, $command, $channelName);
		$channel->command("op $sender") if ($sender_rec && !$sender_rec->{op});
		goto SIGSTOP;

	# /ctcp nick VOICE #channel password
	} elsif ($command eq "VOICE") {
		if (!friend_is_wrapper($idx, $channelName, "v", undef)) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Not enough flags");
			goto SIGSTOP;
		}
		if (!friends_passwdok($idx, $password)) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Bad password");
			goto SIGSTOP;
		}

		# process allowed voicing
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcprequest', $handle, $command, $channelName);
		$channel->command("voice $sender") if ($sender_rec && !$sender_rec->{voice});
		goto SIGSTOP;

	# /ctcp nick INVITE #channel password
	} elsif ($command eq "INVITE") {
		if (!friend_is_wrapper($idx, $channelName, "i", undef)) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Not enough flags");
			goto SIGSTOP;
		}
		if (!friends_passwdok($idx, $password)) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Bad password");
			goto SIGSTOP;
		}

		Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcprequest', $handle, $command, $channelName);
		if (!$channel->{chanop} && !$sender_rec) {
			# friend is outside channel, but we're not opped
			$server->command("/^NOTICE $sender I'm not opped on $channelName");
		} elsif (!$sender_rec) {
			# process allowed invite
			$channel->command("invite $sender");
		}
		goto SIGSTOP;

	# /ctcp nick KEY #channel password
	} elsif ($command eq "KEY") {
		if (!friend_is_wrapper($idx, $channelName, "k", undef)) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Not enough flags");
			goto SIGSTOP;
		}
		if (!friends_passwdok($idx, $password)) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Bad password");
			goto SIGSTOP;
		}

		# process allowed key giving
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcprequest', $handle, $command, $channelName);
		if ($channel->{key} && !$sender_rec) {
			# give a key if channel is +k'ed and $sender is not on $channelName
			$server->command("/^NOTICE $sender Key for $channelName is: $channel->{key}");
		}
		goto SIGSTOP;

	# /ctcp nick UNBAN #channel password
	} elsif ($command eq "UNBAN") {
		if (!friend_is_wrapper($idx, $channelName, "u", undef)) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Not enough flags");
			goto SIGSTOP;
		}
		if (!friends_passwdok($idx, $password)) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Bad password");
			goto SIGSTOP;
		}

		Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcprequest', $handle, $command, $channelName);
		if (!$channel->{chanop}) {
			# notify him that we're not opped, unless he's here and he can see that ;^)
			$server->command("/^NOTICE $sender I'm not opped on $channelName") if (!$sender_rec);
		} else {
			# process allowed unban
			foreach my $ban ($channel->bans()) {
				if ($server->mask_match_address($ban->{ban}, $sender, $userhost)) {
					$server->command("MODE $channelName -b $ban->{ban}");
				}
			}
		}
		goto SIGSTOP;

	# /ctcp nick LIMIT #channel password
	} elsif ($command eq "LIMIT") {
		if (!friend_is_wrapper($idx, $channelName, "l", undef)) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Not enough flags");
			goto SIGSTOP;
		}
		if (!friends_passwdok($idx, $password)) {
			Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcpfail', $command, $handle, "Bad password");
			goto SIGSTOP;
		}

		# process allowed limit raising
		Irssi::printformat(MSGLEVEL_CRAP, 'friends_ctcprequest', $handle, $command, $channelName);
		if (!$channel->{chanop}) {
			# notify him that we're not opped, unless he's here and he can see that ;^)
			$server->command("/^NOTICE $sender I'm not opped on $channelName") if (!$sender_rec);
		} else {
			my @nicks = $channel->nicks();
			if ($channel->{limit} && $channel->{limit} <= scalar(@nicks)) {
				# raise the limit if it's needed
				$server->command("MODE $channelName +l " . (scalar(@nicks) + 1));
			}
		}
		goto SIGSTOP;
	}

	# stop the signal if we processed the request
SIGSTOP:
	Irssi::signal_stop();
}

# void cmd_friendsversion($data, $server, $channel)
# handles /friendsversion
# prints script's and friendlist's version
sub cmd_friendsversion() {
	print_version("script");
	print_version("filever");
	print_version("filewritten");
}

# settings
Irssi::settings_add_int('misc', 'friends_delay_min', $default_delay_min);
Irssi::settings_add_int('misc', 'friends_delay_max', $default_delay_max);
Irssi::settings_add_int('misc', 'friends_max_queue_size', $default_friends_max_queue_size);
Irssi::settings_add_int('misc', 'friends_revenge_mode', $default_friends_revenge_mode);
Irssi::settings_add_bool('misc', 'friends_revenge', $default_friends_revenge);
Irssi::settings_add_bool('misc', 'friends_learn', $default_friends_learn);
Irssi::settings_add_bool('misc', 'friends_voice_opped', $default_friends_voice_opped);
Irssi::settings_add_bool('misc', 'friends_use_ctcp', $default_friends_use_ctcp);
Irssi::settings_add_bool('misc', 'friends_autosave', $default_friends_autosave);
Irssi::settings_add_bool('misc', 'friends_backup_friendlist', $default_friends_backup_friendlist);
Irssi::settings_add_bool('misc', 'friends_show_flags_on_join', $default_friends_show_flags_on_join);
Irssi::settings_add_bool('misc', 'friends_findfriends_to_windows', $default_friends_findfriends_to_windows);
Irssi::settings_add_bool('misc', 'friends_show_whois_extra', $default_friends_show_whois_extra);
Irssi::settings_add_str('misc', 'friends_ctcp_commands', $default_friends_ctcp_commands);
Irssi::settings_add_str('misc', 'friends_default_flags', $default_friends_default_flags);
Irssi::settings_add_str('misc', 'friends_file', $default_friends_file);
Irssi::settings_add_str('misc', 'friends_backup_suffix', $default_friends_backup_suffix);

# commands
Irssi::command_bind('addfriend', 'cmd_addfriend');
Irssi::command_bind('delfriend', 'cmd_delfriend');
Irssi::command_bind('addhost', 'cmd_addhost');
Irssi::command_bind('delhost', 'cmd_delhost');
Irssi::command_bind('delchanrec', 'cmd_delchanrec');
Irssi::command_bind('chhandle', 'cmd_chhandle');
Irssi::command_bind('chdelay', 'cmd_chdelay');
Irssi::command_bind('loadfriends', 'cmd_loadfriends');
Irssi::command_bind('savefriends', 'cmd_savefriends');
Irssi::command_bind('listfriends', 'cmd_listfriends');
Irssi::command_bind('findfriends', 'cmd_findfriends');
Irssi::command_bind('isfriend', 'cmd_isfriend');
Irssi::command_bind('chflags', 'cmd_chflags');
Irssi::command_bind('chpass', 'cmd_chpass');
Irssi::command_bind('comment', 'cmd_comment');
Irssi::command_bind('oppingtree', 'cmd_oppingtree');
Irssi::command_bind('opfriends', 'cmd_opfriends');
Irssi::command_bind('queue', 'cmd_queue');
Irssi::command_bind('queue show', 'cmd_queue_show');
Irssi::command_bind('queue flush', 'cmd_queue_flush');
Irssi::command_bind('queue purge', 'cmd_queue_purge');
Irssi::command_bind('flushlearnt', 'cmd_flushlearnt');
Irssi::command_bind('friendsversion', 'cmd_friendsversion');

# events
Irssi::signal_add_last('massjoin', 'event_massjoin');
Irssi::signal_add_last('event mode', 'event_modechange');
Irssi::signal_add_last('event 311', 'event_whois');
Irssi::signal_add('default ctcp msg', 'event_ctcpmsg');
Irssi::signal_add('redir userhost_friends', 'event_isfriend_userhost');
Irssi::signal_add('redir userhost_addfriend', 'event_addfriend_userhost');
Irssi::signal_add('setup saved', 'event_setup_saved');
Irssi::signal_add('setup reread', 'event_setup_reread');
Irssi::signal_add('nicklist changed', 'event_nicklist_changed');
Irssi::signal_add('server disconnected', 'event_server_disconnected');
Irssi::signal_add('server connect failed', 'event_server_disconnected');
Irssi::signal_add_first('event kick', 'event_kick');

print_releasenote() if (defined($release_note));
load_friends();
