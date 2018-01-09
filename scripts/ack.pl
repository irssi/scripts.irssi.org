#! /usr/bin/perl
# $Id$
 
# Ack: Jump to the next active window, with tiebreakers.
 
use warnings;
use strict;
 
use Irssi;
 
### Script header.
 
use vars qw($VERSION);
$VERSION = do {my@r=(q$Revision: 0.0$=~/\d+/g);sprintf"%d."."%04d"x$#r,@r};
 
use vars qw(%IRSSI);
%IRSSI = (
  name        => 'ack',
  authors     => 'Rocco Caputo',
  contact     => 'rcaputo@cpan.org',
  url         => '(none yet)',
  license     => 'Perl',
  description => 'Jump to the next active window, with tiebreakers.',
);

my %sort_methods = (
	refnum    => [ \&sort_refnum,    "Sort by window refnum - returns one item" ],
	level     => [ \&sort_level,     "Sort by data priority: hilight, PRIVMSG, NICK/JOIN/QUICK - returns a group" ],
	whitelist => [ \&sort_whitelist, "Only show whitelisted windows - by refnum" ],
	lastspoke => [ \&sort_lastspoke, "Give priority to channels you recently spoke in" ],
	priority  => [ \&sort_priority,  "Manually prioritize given windows" ],
	timestamp => [ \&sort_timestamp, "Channel most recently with activity" ],
	network   => [ \&sort_network,   "Ordered list of network tags" ],
);


# Sort by window refnum - returns one item
sub sort_refnum
{
	my ($reverse, @windows) = @_;
	# Sort by window reference, ascending
	@windows = sort { $a->{refnum} <=> $b->{refnum} } @windows;
	# Return the first/last window
	return $windows[$reverse ? -1 : 0];              
}

# Sort by data priority: hilight, PRIVMSG, NICK/JOIN/QUICK - returns a group
sub sort_level 
{
	my ($reverse, @windows) = @_;
	# Search for windows with the highest/lowest data_level
	my @levels = qw/1 2 3/;
	@levels = reverse(@levels) unless ($reverse);

	for my $level (@levels)
	{
		my @list = grep {$_->{'data_level'} == $level} @windows;
		return @list if (@list);
	}
}

sub sort_network
{
	my ($reverse, @windows) = @_;
	return @windows unless (Irssi::settings_get_str('ack_networks'));
	my @networks = split (/,/, lc(Irssi::settings_get_str('ack_networks')));
	my @list;
	for my $tag (@networks)
	{
		for my $item (@windows)
		{
			push @list, $item if ( lc($item->{active_server}->{tag}) eq $tag );
		}
		return @list if( @list );
	}
	return @windows;
}


# Only show whitelisted windows - by refnum 
# Set reversed to blacklist
sub sort_whitelist
{
	my ($reverse, @windows) = @_;
	my @list;

	# Do nothing unless a whitelist is set
	return @windows unless (Irssi::settings_get_str('ack_channel_whitelist'));

	# Select the items from the window list that appear on the whitelist
	my @whitelist = split (/,/, Irssi::settings_get_str('ack_channel_whitelist'));
	for my $item (@windows)
	{
		# Push the item to the return list if it is (not) on the whitelist list
		push @list, $item if (not $reverse and grep {$item->{'refnum'} == $_} @whitelist);
		push @list, $item if ($reverse and not grep {$item->{'refnum'} == $_} @whitelist);
	}
	return @list;
}

# Give priority to channels you recently spoke in
# Reversing is ignored
my %last_spoke;
sub sort_lastspoke
{
	my ($reverse, @windows) = @_;
	# You must have spoke after this time to get priority
	my $cutoff = time - Irssi::settings_get_int('ack_last_spoke_timeout');
	# Windows you spoke in after the cutoff
	my @list = grep {$last_spoke{$_->{'refnum'}} and $last_spoke{$_->{'refnum'}} > $cutoff} @windows;
	# If something was found, use it. Otherwise fallback to all the windows
	return @list if (@list);
	return @windows;
}

# Manually prioritize given windows
sub sort_priority
{
	my ($reverse, @windows) = @_;
	my @priorities = split(/,/, lc(Irssi::settings_get_str('ack_high_priority')));
	my @list;
	for my $item (@windows)
	{
		# Push the item to the return list if it is (not) on the priority list
		push @list, $item if (not $reverse and grep {$item->{'refnum'} == $_} @priorities);
		push @list, $item if ($reverse and not grep {$item->{'refnum'} == $_} @priorities);
	}
	# If something was found, use it. Otherwise fallback to all the windows
	return @list if (@list);
	return @windows;
}

# Channel most recently with activity first (or oldest first with reverse)
sub sort_timestamp
{
	my ($reverse, @windows) = @_;
	# Sort by activity timestamp, descending
	@windows = sort { $b->{refnum} <=> $a->{refnum} } @windows;
	# Return the first/last window
	return $windows[$reverse ? -1 : 0];              
}


# Jump to an active channel.
sub cmd_ack
{
	my ($cmd, $server, $window) = @_;

	# There's various methods of sorting activity
	# The best is to magically see what the user would want to see next
	# Various sort functions approximate that. The user can select which functions to use and in what order.
	# The sorts can also be reversed with a - flag or normal with a + flag
	# Each sort function takes a list of windows and returns another list of equal or smaller size

	my @windows = grep { $_->{data_level} } Irssi::windows(); # Get windows with activity
	return unless @windows; # Prevent a bunch of function calls when there's no active windows

	# The sort functions to use
	my $ack_sorts = Irssi::settings_get_str('ack_sorts');
	$ack_sorts =~ s/\s//g;
	for my $sort (split(/,/, $ack_sorts))
	{
		my $reverse = ($sort =~ /^-/) ? 1 : 0; # Reverse sort or not
		$sort = substr($sort, 1) if ($sort =~ /^[+-]/); # ltrim a leading + or -
		my $func = $sort_methods{$sort}->[0];
		unless (defined $func)
		{
			Irssi::print("No such ack sort method as $sort");
			next;
		}

		# Call the sorting method
		@windows = &$func($reverse, @windows);

		last if(scalar(@windows) < 2); # Nothing left to sort between
	}

	# Jump to the first window.  How hard can it be?
	$windows[0]->set_active() if (defined $windows[0]);
}
 
# Add a refnum to the high priority list
sub cmd_ack_add
{
	my ($input, $server, $window) = @_;
	my @list = split(/,/, lc(Irssi::settings_get_str('ack_high_priority')));
	my $num = Irssi::active_win()->{refnum};
	return if grep {$_ == $num} @list;
	Irssi::settings_set_str('ack_high_priority', join(',', @list, $num));
}

# Remove a refnum from the high priority list
sub cmd_ack_del
{
	my ($input, $server, $window) = @_;
	my @list = split(/,/, lc(Irssi::settings_get_str('ack_high_priority')));
	my $num = Irssi::active_win()->{refnum};
	@list = grep {$_ != $num} @list;
	Irssi::settings_set_str('ack_high_priority', join(',', @list));
}

# Track the window number you last_spoke in
sub cmd_own_public
{
	my ($server, $msg, $target) = @_;
	my $window = $server->window_find_item($target);
	my $refnum = $window->{'refnum'};
	$last_spoke{$refnum} = time;
}
sub cmd_ack_spoke
{
	my ($data, $server, $witem) = @_;
	unless ($witem and $witem->window())
	{
		Irssi::print("No window here to operate on :(");
		return;
	}
	my $refnum = $witem->window()->{'refnum'};
	$last_spoke{$refnum} = time;
}

sub cmd_ack_sorts_help
{
	Irssi::print("Sort methods:");
	for my $k (keys %sort_methods)
	{
		Irssi::print(sprintf("%-12s: %s", $k, $sort_methods{$k}->[1]));
	}
	Irssi::print("You're ack_sorts setting: " . Irssi::settings_get_str('ack_sorts'));
}

# Usage: /ack ... probably bind it to Meta-A or something.
Irssi::command_bind("ack", "cmd_ack"); 

# Commands to manipulate the ack_high_priority string
Irssi::command_bind("ack_del", "cmd_ack_del"); 
Irssi::command_bind("ack_add", "cmd_ack_add"); 

# Command to add a window to the last_spoke hash for temporary priority increase
Irssi::command_bind("ack_spoke", "cmd_ack_spoke"); 

# Display the sort methods available along with a brief description
Irssi::command_bind("ack_sorts", "cmd_ack_sorts_help"); 

# Hook to track when you last_spoke in a channel
Irssi::signal_add("message own_public", "cmd_own_public"); 
Irssi::signal_add("message irc own_action", "cmd_own_public"); 

# List of channels with elevated sort priority
Irssi::settings_add_str('misc', 'ack_high_priority', '');
Irssi::settings_add_str('misc', 'ack_channel_whitelist', '');

# A list of sort methods to apply
# See the sort_method hash
Irssi::settings_add_str('misc', 'ack_sorts', '+level,+refnum');

# Network priority list, eg a,b,c will prioritize a then b then c then the rest
Irssi::settings_add_str('misc', 'ack_networks', 'FreeNode,EFNet');

# How long a last_spoke is valid for before "forgotten"
Irssi::settings_add_int('misc', 'ack_last_spoke_timeout', 300);
