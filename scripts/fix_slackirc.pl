use strict;
use warnings;

our $VERSION = '0.3'; # e43de0fd9100921
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'fix_slackirc',
    description => 'Some workarounds to improve irssi experience on the Slack IRC gateway',
    license     => 'ISC',
   );

# Usage
# =====
# Load and enjoy

use Irssi;

my $SLACK_ADDRESS = 'irc.tinyspeck.com';

# Work-around for 2 bugs in the Slack IRC bridge
# * Format of 315 is broken - the nick is missing
# * No Reply to the MODE b command
# * Empty real names are given as string "null" instead
# these issues will stop channel sync from working properly

my %timer;
my %chanlist;

Irssi::signal_register({
    'chanquery who end' => [qw[iobject string]],
});

# Accessor for the Rawlog
sub _s2r {
    my $ref = shift;
    if ($ref =~ /=SCALAR/) {
	bless +{ _irssi => $$ref } => ref $ref
    } else {
	$ref
    }
}

sub queue_ban_end {
    my ($server, $raw) = @_;
    return unless $server && $server->{real_address} eq $SLACK_ADDRESS;
    my (@p) = split ' :', $raw, 2;
    unshift @p, (split / /, shift @p);
    my $tag = $server->{tag};
    push @{ $chanlist{$tag} }, split /,/, $p[1];
    if (my $t = delete $timer{$tag}) {
	Irssi::timeout_remove($t);
    }
    # Gross hack due to Irssi missing a signal. We expect that irssi will ask for bans "soon" and in order
    $timer{$tag} = Irssi::timeout_add_once(5_000, 'send_end_of_bans', $tag);
}

sub send_end_of_bans {
    my ($tag) = @_;
    delete $timer{$tag};
    return unless $chanlist{$tag} && @{$chanlist{$tag}};
    my $chan = shift @{ $chanlist{$tag} // [] } || return;
    if (my $server = Irssi::server_find_tag($tag)) {
	my $raw = ':'.$server->{real_address}.' 368 '.$server->{nick}.' '.$chan.' :Slack has no Ban List';
	_s2r($server->{rawlog})->input("[FAKED] $raw") if $server->{rawlog};
	Irssi::signal_emit('server incoming', $server, $raw);
	if (@{$chanlist{$tag}}) {
	    # We expect that irssi will ask for the "next" ban soon
	    $timer{$tag} = Irssi::timeout_add_once(2_000, 'send_end_of_bans', $tag);
	}
	else {
	    delete $chanlist{$tag};
	}
    }
}

sub fix_incoming {
    my ($server, $raw) = @_;
    my $nick = $server->{nick};
    my $continue;
    # fix end of wholist
    if ($raw =~ s/:$SLACK_ADDRESS 315 \K /$nick /) {
	$continue = 1;
    }
    # fix "null" realnames
    elsif ($raw =~ s/:$SLACK_ADDRESS 352 .* :\d+ \Knull$//) {
	$continue = 1;
    }
    # support self msgs
    elsif ($raw =~ s/^:(?:(\S+)!\S+(\@$SLACK_ADDRESS)) PRIVMSG ([^#\s]\S*) :\[\3\] /:$3!$3$2 PRIVMSG $1 :/) {
	$continue = 1;
    }
    if ($continue) {
	_s2r($server->{rawlog})->input("[FIXED] $raw") if $server->{rawlog};
	Irssi::signal_continue($server, $raw);
    }
}

Irssi::signal_add_last('chanquery who end' => 'queue_ban_end');
Irssi::signal_add_first('server incoming' => 'fix_incoming');
