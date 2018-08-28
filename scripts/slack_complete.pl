#
# Copyright (C) 2015 by Morten Lied Johansen <mortenjo@ifi.uio.no>
#

# Version history:
#  2.0: - Added support for common mentions (here, channel, everyone)
#       - Completion uses completion_char setting instead of hard coded colon
#       - Option to choose if completion_char is added in beginning of line
#  1.1: - Added support for multiple networks: /set slack_network slack flowdock gitter
#         or all networks: /set slack_network *

use strict;

use Irssi;
use Irssi::Irc;

# ======[ Script Header ]===============================================

use vars qw{$VERSION %IRSSI};
($VERSION) = '$Revision: 2.0 $' =~ / (\d+\.\d+) /;
%IRSSI = (
          name        => 'slack_complete',
          authors     => 'Morten Lied Johansen, Jonas Berlin, Ossi Hakkarainen',
          contact     => 'mortenjo@ifi.uio.no',
          license     => 'GPL',
          description => 'Prefix nicks with @ when completing nicks to match conventions on networks like Slack, Flowdock, Gitter etc',
         );

# ======[ Hooks ]=======================================================

# --------[ sig_complete_slack_nick ]-----------------------------------

sub sig_complete_slack_nick {
my ($complist, $window, $word, $linestart, $want_space) = @_;

	my $wi = Irssi::active_win()->{active};
	return unless ref $wi and $wi->{type} eq 'CHANNEL';
	my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('slack_network'));
	return unless exists $chatnets{'*'} || exists $chatnets{$wi->{server}->{chatnet}};

	if ($word =~ /^@/) {
		$word =~ s/^@//;
	}
	foreach my $nick ($wi->nicks()) {
		if ($nick->{nick} =~ /^\Q$word\E/i) {
			my $ignore_completion_char = Irssi::settings_get_bool('slack_ignore_completion_char');
			if ($linestart || $ignore_completion_char) {
				push(@$complist, "\@$nick->{nick}");
			} else {
				my $compchar = Irssi::settings_get_str('completion_char');
				push(@$complist, "\@$nick->{nick}$compchar");
			}
		}
	}
	if (Irssi::settings_get_bool('slack_complete_commons')) {
		my @common_mentions = ("here", "channel", "everyone");
		foreach my $mention (@common_mentions) {
			if ($mention =~ /^\Q$word\E/i) {
				push(@$complist, "\@$mention");
			}
		}
	}

	@$complist = sort {
		return $a =~ /^\@\Q$word\E(.*)$/i ? 0 : 1;
	} @$complist;
}

# ======[ Setup ]=======================================================

# --------[ Register settings ]-----------------------------------------

Irssi::settings_add_str('slack_complete', 'slack_network', 'Slack');
Irssi::settings_add_bool('slack_complete', 'slack_ignore_completion_char', 0);
Irssi::settings_add_bool('slack_complete', 'slack_complete_commons', 0);

# --------[ Register signals ]------------------------------------------

Irssi::signal_add('complete word', \&sig_complete_slack_nick);

# ======[ END ]=========================================================
