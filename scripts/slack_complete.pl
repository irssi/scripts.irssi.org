#
# Copyright (C) 2015 by Morten Lied Johansen <mortenjo@ifi.uio.no>
#

use strict;

use Irssi;
use Irssi::Irc;

# ======[ Script Header ]===============================================

use vars qw{$VERSION %IRSSI};
($VERSION) = '$Revision: 1.0 $' =~ / (\d+\.\d+) /;
%IRSSI = (
          name        => 'slack_complete',
          authors     => 'Morten Lied Johansen',
          contact     => 'mortenjo@ifi.uio.no',
          license     => 'GPL',
          description => 'Convert to slack-mention when completing nicks',
         );

# ======[ Hooks ]=======================================================

# --------[ sig_complete_slack_nick ]-----------------------------------

sub sig_complete_slack_nick {
my ($complist, $window, $word, $linestart, $want_space) = @_;

	my $wi = Irssi::active_win()->{active};
	return unless ref $wi and $wi->{type} eq 'CHANNEL';
	return unless $wi->{server}->{chatnet} eq
		Irssi::settings_get_str('slack_network');

	if ($word =~ /^@/) {
		$word =~ s/^@//;
	}
	foreach my $nick ($wi->nicks()) {
		if ($nick->{nick} =~ /^\Q$word\E/i) {
		    if ($linestart) {
    			push(@$complist, "\@$nick->{nick}");
    	    } else {
				push(@$complist, "\@$nick->{nick}:");
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

# --------[ Register signals ]------------------------------------------

Irssi::signal_add('complete word', \&sig_complete_slack_nick);

# ======[ END ]=========================================================
