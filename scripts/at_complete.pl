#
# Copyright (C) 2015 by Kevin Pulo <kev@pulo.com.au>
#
# This adds a "@" in front of all nick tab completion, and appends ","
# if at the start of the line.
#
# Currently happens in all channels on all networks, which works for me
# with Flowdock's IRC interface (for which I use a dedicated irssi
# session).  Some sort of channel/network configurability would be nice,
# but since I don't need that, I haven't looked into it.
#
# Based on slack_complete.pl: Copyright (C) 2015 by Morten Lied Johansen
# <mortenjo@ifi.uio.no>
#

use strict;

use Irssi;
use Irssi::Irc;

# ======[ Script Header ]===============================================

use vars qw{$VERSION %IRSSI};
($VERSION) = '$Revision: 1.0 $' =~ / (\d+\.\d+) /;
%IRSSI = (
          name        => 'at_complete',
          authors     => 'Morten Lied Johansen, Kevin Pulo',
          contact     => 'mortenjo@ifi.uio.no, kev@pulo.com.au',
          license     => 'GPL',
          description => 'Convert to @mention when completing nicks',
         );

# ======[ Hooks ]=======================================================

# --------[ sig_complete_at_nick ]-----------------------------------

sub sig_complete_at_nick {
my ($complist, $window, $word, $linestart, $want_space) = @_;

	my $wi = Irssi::active_win()->{active};
	return unless ref $wi and $wi->{type} eq 'CHANNEL';

	if ($word =~ /^@/) {
		$word =~ s/^@//;
	}
	foreach my $nick ($wi->nicks()) {
		if ($nick->{nick} =~ /^\Q$word\E/i) {
			if ($linestart) {
				push(@$complist, "\@$nick->{nick}");
			} else {
				push(@$complist, "\@$nick->{nick},");
			}
		}
	}

	@$complist = sort {
		return $a =~ /^\@\Q$word\E(.*)$/i ? 0 : 1;
	} @$complist;
}

# ======[ Setup ]=======================================================

# --------[ Register signals ]------------------------------------------

Irssi::signal_add('complete word', \&sig_complete_at_nick);

# ======[ END ]=========================================================
