#!/usr/bin/perl -w
#
# LastSpoke.pl
#
# irssi script
# 
# This script, when loaded into irssi, will monitor and remember everyones
# last action on one or more channels specified in the lastspoke_channels
# setting
#
# [settings]
# lastspoke_channels
#     - Should contain a list of channels that lastspoke should monitor
#       this list can be in any format as long as theres full channelnames
#       in it. For example:
#          "#foo,#bar,#baz" is correct
#          "#foo#bar#baz" is correct
#          "#foo #bar #baz" is correct
#
# Triggers on !lastspoke <nick>, !seen <nick> and !lastseen <nick>
# 
use strict;
use utf8;
use Encode qw/decode encode/;
use Irssi;
use Irssi::Irc;
use CPAN::Meta::YAML;
use vars qw($VERSION %IRSSI);

$VERSION = "0.4";
%IRSSI = (
    authors     => 'Sander Smeenk',
    contact     => 'irssi@freshdot.net',
    name        => 'lastspoke',
	description => 'Remembers what people said last on what channels',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.freshdot.net/',
	modules		=> 'CPAN::Meta::YAML',
);

# Storage for the data.
my %lasthash;

my $filename=Irssi::get_irssi_dir().'/lastspoke.yaml';

# Calculates the difference between two unix times and returns
# a string like '15d 23h 42m 15s ago.'
sub calcDiff {
	my ($when) = @_;

	my $diff = (time() - $when);
	my $day = int($diff / 86400); $diff -= ($day * 86400);
	my $hrs = int($diff / 3600); $diff -= ($hrs * 3600);
	my $min = int($diff / 60); $diff -= ($min * 60);
	my $sec = $diff;

	return "${day}d ${hrs}h ${min}m ${sec}s ago.";
}

# Hook for nick changes
sub on_nick {
	my ($server, $new, $old, $address) = @_;

	my $allowedChans = lc(Irssi::settings_get_str("lastspoke_channels")) || "(null)";
	my @cl=split(/,/,$server->get_channels());
	my $ok=0;
	foreach (@cl) {
		$ok += index($allowedChans, $_) >= 0;
	}
	if ( $ok >= 0) {
	    $lasthash{lc($old)}{'last'} = time();
	    $lasthash{lc($old)}{'words'} = "$old changed nick to $new";
	    $lasthash{lc($new)}{'last'} = time();
	    $lasthash{lc($new)}{'words'} = "$new changed nick from $old";
	}
}

# Hook for people quitting
sub on_quit {
	my ($server, $nick, $address, $reason) = @_;

	my $allowedChans = lc(Irssi::settings_get_str("lastspoke_channels")) || "(null)";
	my @cl=split(/,/,$server->get_channels());
	my $ok=0;
	foreach (@cl) {
		$ok += index($allowedChans, $_) >= 0;
	}
	if ( $ok >= 0) {
		$lasthash{lc($nick)}{'last'} = time();
		if (! $reason) {
			$lasthash{lc($nick)}{'words'} = "$nick quit IRC with no reason";
		} else {
			$lasthash{lc($nick)}{'words'} = "$nick quit IRC stating '$reason'";
		}
	}
}

# Hook for people joining
sub on_join {
	my ($server, $channel, $nick, $address) = @_;
	
	my $allowedChans = lc(Irssi::settings_get_str("lastspoke_channels")) || "(null)";
	if (index($allowedChans, $channel) >= 0) {
    	$lasthash{lc($nick)}{'last'} = time();
		$lasthash{lc($nick)}{'words'} = "$nick joined $channel";	
	}
}

# Hook for people parting
sub on_part {
	my ($server, $channel, $nick, $address, $reason) = @_;

	my $allowedChans = lc(Irssi::settings_get_str("lastspoke_channels")) || "(null)";
	if (index($allowedChans, $channel) >= 0) {
		$lasthash{lc($nick)}{'last'} = time();
		if (! $reason) {
			$lasthash{lc($nick)}{'words'} = "$nick left from $channel with no reason";
		} else {
			$lasthash{lc($nick)}{'words'} = "$nick left from $channel stating '$reason'";
		}
	}
}

# Hook for public messages.
# Only act on channels we are supposed to act on (settings_get_str)
sub on_public {
	my ($server, $msg, $nick, $addr, $target) = @_;
	utf8::decode($msg);

	$target = $nick if ( ! $target );
	$nick = $server->{'nick'} if ($nick =~ /^#/);
	$target = lc($target);

	my $allowedChans = lc(Irssi::settings_get_str("lastspoke_channels")) || "(null)";

	# Debug
	# Irssi::active_win()->print("Server: $server");
	# Irssi::active_win()->print("Msg   : $msg");
	# Irssi::active_win()->print("Nick  : $nick");
	# Irssi::active_win()->print("Addr  : $addr");
	# Irssi::active_win()->print("Target: $target");
	# /Debug

	if (index($allowedChans, $target) >= 0) {
		if ( ($msg =~ /^!lastspoke /) || ($msg =~ /^!seen /) || ($msg =~ /^!lastseen /)) {
			my @parts = split(/ /,$msg);

			$lasthash{lc($nick)}{'last'} = time();
			$lasthash{lc($nick)}{'words'} = "$nick last queried information about " . $parts[1] . " on $target";
	
			if (exists $lasthash{lc($parts[1])}) {
				$server->command("MSG $target " . 
					to_term_enc($lasthash{lc($parts[1])}{'words'}) . 
						" " . calcDiff($lasthash{lc($parts[1])}{'last'}));
			} else {
				$server->command("MSG $target I don't know anything about " . $parts[1]);
			}
		} else {
			$lasthash{lc($nick)}{'last'} = time();
			$lasthash{lc($nick)}{'words'} = "$nick last said '$msg' on $target";
		}
	}
}

# encode the words to term_charset
sub to_term_enc {
	my ($words)= @_;
	my $charset= Irssi::settings_get_str('term_charset');
	return encode($charset, $words);
}

# write the memory to disk
sub save {
	my $fa;
	open($fa, '>:utf8', $filename);
	my $yml = CPAN::Meta::YAML->new( \%lasthash );
	print $fa $yml->write_string();
	close($fa);
}

# read form the disk to memory
sub load {
	my $fi;
	if (-e $filename) {
		local $/;
		open($fi, '<:utf8', $filename);
		my $s= <$fi>;
		my $yml= CPAN::Meta::YAML->read_string($s);
		%lasthash = %{ $yml->[0] };
		close($fi);
	}
}

# hook for unload, /quit
sub UNLOAD {
	save();
}

# Put hooks on events
Irssi::signal_add_last("message public", "on_public");
Irssi::signal_add_last("message own_public", "on_public");
Irssi::signal_add_last("message part", "on_part");
Irssi::signal_add_last("message join", "on_join");
Irssi::signal_add_last("message quit", "on_quit");
Irssi::signal_add_last("message nick", "on_nick");

# Add setting
Irssi::settings_add_str("lastspoke", "lastspoke_channels", '%s');

load();
