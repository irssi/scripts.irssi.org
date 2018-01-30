use strict;
use warnings;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.4";

%IRSSI = (
	authors     => 'Christian Brassat, Niall Bunting, Walter Hop and Frantisek Sumsal',
	contact     => 'irssi-smartfilter@spam.lifeforms.nl',
	name        => 'smartfilter.pl',
	description => 'Improved smart filter for join, part, quit, nick messages',
	license     => 'BSD',
	url         => 'https://github.com/lifeforms/irssi-smartfilter',
	changed     => '2015-12-28',
);

# Associative array of nick => last active unixtime
our $lastmsg = {};
our $garbagetime = 1;
our @ignored_chans;

# Do checks after receving a channel event.
# - If the originating nick is not active, ignore the signal.
# - If nick is active, propagate the signal and display the event message.
#   Keep the nick marked as active, so we will not miss a re-join after a PART
#   or QUIT, a second nick change, etc.
sub checkactive {
	my ($nick, $altnick, $channel) = @_;

	# if channel is not defined do nothing, quits and parts always have
	# a channel so I wonder if this is needed
	if (not defined($channel)) {
		return;
	}

	# Skip filtering if current channel is in 'smartfilter_ignored_chans'
	# If the channel and nick values match event happened in a query so skip filtering
	if (grep {$_ eq $channel} @ignored_chans or $channel eq $nick) {
		return;
	}

	if (!exists $lastmsg->{$nick} || $lastmsg->{$nick} <= time() - Irssi::settings_get_int('smartfilter_delay')) {
		delete $lastmsg->{$nick};
		Irssi::signal_stop();
	}

	if(exists $lastmsg->{$nick} && $altnick) {
		$lastmsg->{$altnick} = $lastmsg->{$nick};
		delete $lastmsg->{$nick};
	}

	# Run the garbage collection every interval.
	if ($garbagetime <= time() - (Irssi::settings_get_int('smartfilter_delay') * Irssi::settings_get_int('smartfilter_garbage_multiplier') )) {
		garbagecollect();
		$garbagetime = time();
	}
}

# Implements garbage collection.
sub garbagecollect{
	foreach my $key (keys %$lastmsg) {
		if ($lastmsg->{$key} <= time() - Irssi::settings_get_int('smartfilter_delay')) {
			delete $lastmsg->{$key}
		}
	}
}

# JOIN or PART received.
sub smartfilter_chan {
	my ($server, $channel, $nick, $address) = @_;
	&checkactive($nick, undef, $channel);
};

sub smartfilter_text {
	my ($dest, $text, $stripped) = @_;

	# Message we attempt to print is nick change or quit notice
	if($dest->{'level'} & MSGLEVEL_NICKS) {
		if($stripped =~ m/([^ ]+) is now known as ([^ ]+)/) {
			&checkactive($1, $2, $dest->{'target'});
		}
	} elsif($dest->{'level'} & MSGLEVEL_QUITS) {
		if($stripped =~ m/-!- ([^ ]+) .+? has quit/) {
			&checkactive($1, undef, $dest->{'target'});
		}
	}
}

sub smartfilter_settings {
	undef @ignored_chans if @ignored_chans;
	my $ign_chans = Irssi::settings_get_str('smartfilter_ignored_chans');
	@ignored_chans = split /\s+/, $ign_chans;
}

# Channel message received. Mark the nick as active.
sub log {
	my ($server, $msg, $nick, $address, $target) = @_;
	$lastmsg->{$nick} = time();
}

Irssi::signal_add('message public', 'log');
Irssi::signal_add('message join', 'smartfilter_chan');
Irssi::signal_add('message part', 'smartfilter_chan');
Irssi::signal_add('print text', 'smartfilter_text');
Irssi::signal_add('setup changed', 'smartfilter_settings');

Irssi::settings_add_int('smartfilter', 'smartfilter_garbage_multiplier', 4);
Irssi::settings_add_int('smartfilter', 'smartfilter_delay', 1200);
Irssi::settings_add_str('smartfilter', 'smartfilter_ignored_chans', '');

smartfilter_settings();
