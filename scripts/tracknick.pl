# created for irssi 0.7.98, Copyright (c) 2000 Timo Sirainen

# Are you ever tired of those people who keep changing their nicks?
# Or maybe you just don't like someone's nick?
# This script lets you see them with the real nick all the time no matter
# what nick they're currently using.

# Features:
#  - when you first join to channel the nick is detected from real name
#  - when the nick join to channel, it's detected from host mask
#  - keeps track of parts/quits/nick changes
#  - /find[realnick] command for seeing the current "fake nick"
#  - all public messages coming from the nick are displayed as coming from
#    the real nick.
#  - all other people's replies to the fake nick are changed to show the
#    real nick instead ("fakenick: hello" -> "realnick: hello")
#  - if you reply to the real nick, it's automatically changed to the 
#    fake nick

# TODO:
#  - ability to detect always from either address or real name (send whois
#    requests after join)
#  - don't force the trackchannel
#  - nick completion should complete to the real nick too (needs changes
#    to irssi code, perl module doesn't recognize "completion word" signal)
#  - support for runtime configuration + multiple nicks
#  - support for /whois and some other commands? private messages?

use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI); 
$VERSION = "0.01";
%IRSSI = (
    authors     => "Timo Sirainen",
    contact	=> "tss\@iki.fi", 
    name        => "track nick",
    description => "Are you ever tired of those people who keep changing their nicks? Or maybe you just don't like someone's nick? This script lets you see them with the real nick all the time no matter what nick they're currently using.",
    license	=> "Public Domain",
    url		=> "http://irssi.org/",
    changed	=> "2002-03-04T22:47+0100"
);

# change these to the values you want them to be
# change these to the values you want them to be
my $trackchannel = '#channel';
my $realnick = 'nick';
my $address_regexp = 'user@address.fi$';
my $realname_regexp = 'first.*lastname';

my $fakenick = '';

sub event_nick {
	my ($newnick, $server, $nick, $address) = @_;
	$newnick = substr($newnick, 1) if ($newnick =~ /^:/);

	$fakenick = $newnick if ($nick eq $fakenick)
}

sub event_join {
	my ($data, $server, $nick, $address) = @_;

	if (!$fakenick && $data eq $trackchannel && 
	    $address =~ /$address_regexp/) {
		$fakenick = $nick;
	}
}

sub event_part {
	my ($data, $server, $nick, $address) = @_;
        my ($channel, $reason) = $data =~ /^(\S*)\s:(.*)/;

	$fakenick = '' if ($fakenick eq $nick && $channel eq $trackchannel);
}

sub event_quit {
	my ($data, $server, $nick, $address) = @_;

	$fakenick = '' if ($fakenick eq $nick);
}

sub event_wholist {
	my ($channel) = @_;

	find_realnick($channel) if ($channel->{name} eq $trackchannel);
}

sub find_realnick {
	my ($channel) = @_;

	my @nicks = $channel->nicks();
	$fakenick = '';
	foreach $nick (@nicks) {
		my $realname = $nick->{realname};
		if ($realname =~ /$realname_regexp/i) {
			$fakenick = $nick->{nick};
			break;
		}
	}
}

sub sig_public {
	my ($server, $msg, $nick, $address, $target) = @_;

	return if ($target ne $trackchannel || !$fakenick ||
		   $fakenick eq $realnick);

	if ($nick eq $fakenick) {
		# text sent by fake nick - change it to real nick
		send_real_public($server, $msg, $nick, $address, $target);
		return;
	}

	if ($msg =~ /^$fakenick([:',].*)/) {
		# someone's message starts with the fake nick,
		# automatically change it to real nick
		$msg = $realnick.$1;
		Irssi::signal_emit("message public", $server, $msg,
				   $nick, $address, $target);
		Irssi::signal_stop();
	}
}

sub send_real_public
{
	my ($server, $msg, $nick, $address, $target) = @_;

	my $channel = $server->channel_find($target);
	return if (!$channel);

	my $nickrec = $channel->nick_find($nick);
	return if (!$nickrec);

	# create temporarily the nick to the nick list so that
	# nick mode can be displayed correctly
	my $newnick = $channel->nick_insert($realnick,
		$nickrec->{op}, 
		$nickrec->{voice}, 0);

	Irssi::signal_emit("message public", $server, $msg,
			   $realnick, $address, $target);
	$channel->nick_remove($newnick);
	Irssi::signal_stop();
}

sub sig_send_text {
	my ($data, $server, $item) = @_;

	return if (!$fakenick || !$item || 
		   $item->{name} ne $trackchannel);

	if ($fakenick ne $realnick && $data =~ /^$realnick([:',].*)/) {
		# sending message to realnick, change it to fakenick
		$data = $fakenick.$1;
		Irssi::signal_emit("send text", $data, $server, $item);
		Irssi::signal_stop();
	}
}

sub cmd_realnick {
	if ($fakenick) {
		Irssi::print("$realnick is currently with nick: $fakenick");
	} else {
		Irssi::print("I can't find $realnick currently.");
	}
}

my $channel = Irssi::channel_find($trackchannel);
find_realnick($channel) if ($channel);

Irssi::signal_add('event nick', 'event_nick');
Irssi::signal_add('event join', 'event_join');
Irssi::signal_add('event part', 'event_part');
Irssi::signal_add('event quit', 'event_quit');
Irssi::signal_add('message public', 'sig_public');
Irssi::signal_add('send text', 'sig_send_text');
Irssi::signal_add('channel wholist', 'event_wholist');

Irssi::command_bind("find$realnick", 'cmd_realnick');
