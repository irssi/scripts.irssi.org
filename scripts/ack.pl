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
 
# Sort by last_spoke if enabled
my %last_spoke;
sub recentlySpoke
{
	my ($window) = @_;
	my $refnum = $window->{'refnum'};
	return 0 unless (Irssi::settings_get_bool('ack_use_last_spoke'));
	return 0 unless ($last_spoke{$refnum});
	# Prioritize this refnum if you spoke in it in the last X seconds
	return 1 if ($last_spoke{$refnum} + Irssi::settings_get_int('ack_last_spoke_timeout') > time);
	return 0;
}

 
# Sort by priority if enabled
sub highPriority
{
	my ($window, @list) = @_;
	return 0 unless(Irssi::settings_get_bool('ack_use_priority'));
	return 1 if (grep {$window->{refnum} == $_} @list);
	return 0;
}

# Jump to an active channel.
sub cmd_ack {
  my ($cmd, $server, $window) = @_;
	my @list = split(/,/, lc(Irssi::settings_get_str('ack_high_priority')));
 
  # We sort the data_level in reverse order because higher numbers
  # mean "more important".  If the data_level is equal between two
  # windows, then we jump to the window that has been upbated least
  # recently.
  #
  # Currently that's the window with the earliest (oldest) last line
  # of text.
 
  my @windows = sort {
    ($b->{data_level}        <=> $a->{data_level})               ||
	(highPriority($b, @list) <=> highPriority($a, @list))        ||
	(recentlySpoke($b)       <=> recentlySpoke($a))              ||
    ($a->{refnum}            <=> $b->{refnum} )                  ||
    ($a->{last_line}         <=> $b->{last_line} ) 
  }
  grep { $_->{data_level} }  # Must have some activity.
  Irssi::windows();
 
  # Jump to the first window.  How hard can it be?
  $windows[0]->set_active() if @windows;
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


# Usage: /ack ... probably bind it to Meta-A or something.
Irssi::command_bind("ack", "cmd_ack"); 

# Commands to manipulate the ack_high_priority string
Irssi::command_bind("ack_del", "cmd_ack_del"); 
Irssi::command_bind("ack_add", "cmd_ack_add"); 

# Command to add a window to the last_spoke hash for temporary priority increase
Irssi::command_bind("ack_spoke", "cmd_ack_spoke"); 

# Hook to track when you last_spoke in a channel
Irssi::signal_add("message own_public", "cmd_own_public"); 
Irssi::signal_add("message irc own_action", "cmd_own_public"); 

# List of channels with elevated sort priority
Irssi::settings_add_str('misc', 'ack_high_priority', '');

# Toggle is various sort-methods should be used
Irssi::settings_add_bool('misc', 'ack_use_priority', 0);
Irssi::settings_add_bool('misc', 'ack_use_last_spoke', 0);

# How long a last_spoke is valid for before "forgotten"
Irssi::settings_add_int('misc', 'ack_last_spoke_timeout', 300);
