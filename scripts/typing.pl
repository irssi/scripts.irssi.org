use v5.28;
use vars qw($VERSION %IRSSI);

our $VERSION = '0.10';
our %IRSSI = (
	authors     => 'Juerd',
	contact     => 'juerd@juerd.nl',
	name        => 'IRCv3 typing notifications',
	description => 'Display and send typing notifications for servers that support it. Use "/statusbar additem typing window" and "/save" after loading this script.',
	license     => 'Public Domain',
	url         => 'http://codeberg.org/Juerd/irssi-typing',
	changed     => '2026-03-01T02:27:00+0100',
	changes     => '',
);

use Irssi 20220612 qw(
	active_win
	command
	parse_special
	servers
	settings_get_str
	signal_add
	signal_stop
	timeout_add
	timeout_add_once
	timeout_remove
);
use Irssi::TextUI;

# NOTE Throughout this script, $tag is a server tag, not a message tag.


## PART 1: request IRCv3 'message-tags' capability

signal_add 'server connected' => sub {
	my ($server) = @_;
	$server->irc_server_cap_toggle('message-tags', 1);
};

# Existing connections
$_->irc_server_cap_toggle('message-tags', 1) for servers;


## PART 2: Incoming +typing tags

my %typing;
my %timeout;

sub redraw {
	Irssi::statusbar_items_redraw 'typing';
}

sub done {
	my ($server, $target, $nick) = @_;
	my $tag = ref($server) ? $server->{tag} : $server;
	timeout_remove delete $timeout{$tag}{$target}{$nick};
	delete $typing{$tag}{$target}{$nick};
	redraw;
}

sub timeout {
	my ($tag, $target, $nick) = @{+shift};
	done $tag, $target, $nick;
}

sub disconnected {
	my ($server) = @_;
	my $tag = $server->{tag};
	delete $typing{$tag};
}

sub status {
	my ($item, $get_size_only) = @_;
	my $window = active_win;
	my $tag = $window->{active}{server}{tag} // "";
	my $name = $window->get_active_name;

	my $hash = $typing{$tag}{$name} || {};
	my $text = join " ", map {
		$hash->{$_}{state} eq 'paused' ? "($_)" : "$_";
	} sort {
		$hash->{$a}{time} <=> $hash->{$b}{time}
	} keys %$hash;
	my $format = length($text) ? '{sb $0-}' : '';  # hide item if nobody types
	$item->default_handler($get_size_only, $format, $text, 1);
}

sub tags {
	my ($server, $line, $nick, $address, $message_tags) = @_;
	$line =~ s/^TAGMSG // or return;
	my ($state) = $message_tags =~ /\+typing=(\w+)/ or return;

	if ($state eq 'done') {
		done $server, $line, $nick;
		return;
	}

	my $tag = $server->{tag};

	timeout_remove delete $timeout{$tag}{$line}{$nick};

	my $typing = $typing{$tag}{$line}{$nick} ||= {};
	my $prev_state = $typing->{state} // "";
	$typing->{time} = time if $state ne $prev_state;
	$typing->{state} = $state;

	my $timeout = $state eq 'paused' ? 30_000 : 6_000;
	$timeout{$tag}{$line}{$nick} = timeout_add_once $timeout, \&timeout, [$tag, $line, $nick];

	redraw;
}

sub message {
	my ($server, $data, $nick, $address, $target) = @_;
	done $server, $target || $nick, $nick;
}

sub part {
	my ($server, $channel, $nick) = @_;
	done $server, $channel, $nick;
}

sub cmd_part {
	my ($channel, $server, $witem) = @_;
	my $tag = $server->{tag};
	delete $typing{$tag}{$channel};
	redraw;
}

sub quit {
	my ($server, $nick, $address, $reason) = @_;
	my $tag = $server->{tag};
	delete $typing{$tag};
	redraw;
}

signal_add 'event tagmsg'        => sub { };  # hide TAGMSG in status window
signal_add 'server disconnected' => \&disconnected;
signal_add 'server event tags'   => \&tags;
signal_add 'message public'      => \&message;
signal_add 'message private'     => \&message;
signal_add 'message irc notice'  => \&message;
signal_add 'message part'        => \&part;
signal_add 'message kick'        => \&part;
signal_add 'message quit'        => \&quit;
signal_add 'command part'        => \&cmd_part;

Irssi::statusbar_item_register 'typing', undef, 'status';


## PART 3: Outgoing +typing tags

# XXX When the user switches to a different target (channel/query), the
# notifications in the old target will expire. Maybe send expicit 'done' to old
# target too when (implicitly) going to that state?

my $state = '';  # empty string = implicit 'done'
my $sent_state;
my $timer;
my $paused_timer;
my $server;  # Server/target at time of input_change could differ from active
my $target;

sub paused {
	$state = 'paused';
	# Can't send immediately, because +typing notification MUST be throttled to
	# >= 3 seconds and less time will have passed. The next time the timer
	# triggers, the state will be sent. In the meantime, the state can change
	# too.
}

sub stop_timers {
	timeout_remove $timer if $timer;
	$timer = undef;
	timeout_remove $paused_timer if $paused_timer;
	$paused_timer = undef;
}

sub send_typing {
	$state =~ /^(?:active|paused|done)$/ or return;

	exists $server->{cap_supported}{'message-tags'} or return;

	my $raw = "\@+typing=$state TAGMSG $target";
	#active_win->print($raw);
	$server->send_raw($raw);

	stop_timers if $state ne 'active';
}

sub input_changed {
	my ($input) = @_;
	my $command_chars = settings_get_str 'cmdchars';
	my $have_input =
		length($input) > 4
		&&
		$input !~ /^[\Q$command_chars\E](?!\s[\Q$command_chars\E])/;

	# Don't re-send done state
	return if !$have_input and $state eq 'done' || !$state;

	my $window = active_win;
	$server = $window->{active}{server} or return;
	$target = $window->get_active_name;

	$state = $have_input ? 'active' : 'done';

	timeout_remove $paused_timer if $paused_timer;
	$paused_timer = timeout_add_once 10_000, \&paused, undef if $state eq 'active';

	if ($timer) {
		# Wait for timer, which will send the state. This ensures the
		# mandatory minimum of 3 seconds between notifications.
	} else {
		send_typing;

		if ($state eq 'active') {
			# IRCv3 specification specifies a minimum of 3 seconds;
			# and recipients should timeout after 6 seconds. Using
			# the minimum gives a 3 second margin for latency jitter.
			$timer = timeout_add 3000, \&send_typing, undef;
		}
	}
}

sub after_key {
	state $prev_input = '';
	my $input = parse_special '$L';
	$input ne $prev_input or return;
	$prev_input = $input;

	input_changed $input;
}

sub key {
	my ($key) = @_;
	# At this point, the new key is not yet processed, and the
	# input line is unchanged.
	timeout_add_once 50, \&after_key, undef;
}

sub sent {
	my ($server, $message, $target) = @_;
	stop_timers;
	$state = '';
}

signal_add 'gui key pressed'     => \&key;
signal_add 'message own_public'  => \&sent;
signal_add 'message own_private' => \&sent;
