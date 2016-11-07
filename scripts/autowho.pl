use strict;
use warnings;

our $VERSION = '0.1'; # 486977756197d40
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'autowho',
    description => 'Periodically sends /who on configured channels to update away state.',
    license     => 'ISC',
   );

# Options
# =======
# /set autowho_time <time>
# * time interval for periodic /who
#
# /set autowho_channel net1/#chan1 net2/
# * space separated list of network/channel entries (network/ for the
#   whole network)
#

use Irssi;

my $timer;
my $single_timer;
my $time = 0;
my $max_sync;
my %netchans;
my %who_done;

sub _want_chan {
    my ($server, $c) = @_;
    return unless $server;
    return unless $c;
    my $tag = lc $server->{tag};
    my $chan = lc $c->{visible_name};
    my $netchan = "$tag/$chan";
    return unless exists $netchans{"$tag/"} || exists $netchans{$netchan} || exists $netchans{"/$chan"};
    return 1;
}

sub run_who_single {
    $single_timer = undef;
    for my $server (Irssi::servers) {
	next unless $server->isa('Irssi::Irc::Server');
	for my $channel ($server->channels) {
	    next if $who_done{ $channel->{_irssi} };
	    if (_want_chan($server, $channel) && @{[ $channel->nicks ]} <= $max_sync) {
		$server->redirect_event("who", 1, $channel->{name}, -1, '', {
		    "event 352" => "silent event who",
		    # TODO: make end of who trigger the next run instead of timer below
		    "" => "event empty"
		   });
		$server->send_raw('WHO '.$channel->{name});
	    }
	    $who_done{ $channel->{_irssi} } = 1;
	    $single_timer = Irssi::timeout_add_once(3_000 + rand 1_000, 'run_who_single', '');
	    return;
	}
    }
}

sub run_who {
    unless ($single_timer) { # still running
	%who_done = ();
	run_who_single();
    }
    $timer = Irssi::timeout_add_once($time + rand 10_000, 'run_who', '');
}

sub sig_setup_changed {
    $max_sync = Irssi::settings_get_int('channel_max_who_sync');
    my @channels = split ' ', lc Irssi::settings_get_str('autowho_channel');
    %netchans = map { ($_ => 1) } @channels;
    my $new_time = Irssi::settings_get_time('autowho_time');
    if ($new_time != $time) {
	$time = $new_time;
	if ($timer) {
	    Irssi::timeout_remove($timer);
	    $timer = undef;
	}
	if ($time > 0) {
	    $time = 60_000 if $time < 60_000; # minimum of 1 minute
	    $timer = Irssi::timeout_add_once($time + rand 10_000, 'run_who', '');
	}
    }
}

sub init {
    sig_setup_changed();
}

Irssi::settings_add_time('autowho', 'autowho_time', '5min');
Irssi::settings_add_str('autowho', 'autowho_channel', '');

Irssi::signal_add('setup changed' => 'sig_setup_changed');

init();

