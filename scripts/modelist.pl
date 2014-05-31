# modelist.pl v 0.7.2 by Marcin Rozycki (derwan@irssi.pl) changed at Sat Jun  5 22:38:59 CEST 2004
#
# Usage:
#   /se
#   /si
#   /unexcept [index]	( ex. /unexcept 1 5 17)
#   /uninvite [index]	( ex. /uninvite 3 8)
#

use strict;
use Irssi 20020600 ();
use Irssi::Irc;

use vars qw($VERSION %IRSSI);

$VERSION = "0.7.2";
%IRSSI = (
	authors		=> 'Marcin Rozycki',
	contact		=> 'derwan@irssi.pl',
	name		=> 'modelist',
	description	=> 'Cache of invites and ban exceptions in channel. Usage: /si, /se, '.
			   '/unexcept [indexes], /uninvite [indexes]',
	license		=> 'GNU GPL v2',
	url		=> 'http://derwan.irssi.pl',
	changed		=> 'Sat Jun  5 22:38:59 CEST 2004'
);

Irssi::theme_register([
	'modelist',		'$0 - {hilight $1}: $2 %c$3%n $4'
]);

my %modelist = ();

sub channel_create
{
	my ($server, $channel) = (@_[0], lc($_[1]));
	delete $modelist{lc($server->{tag})}{$channel};

	$server->redirect_event("mode I", 1, "$channel", 0, undef, {
		'event 346'	=> 'redir modelist invite',
		''		=> 'event empty' });
	$server->send_raw("MODE $channel I");

	$server->redirect_event("mode e", 1, "$channel", 0, undef, {
		'event 348'	=> 'redir modelist except',
		''		=> 'event empty' });
	$server->send_raw("MODE $channel e");
}

sub sig_channel_created
{
	channel_create($_[0]->{server}, $_[0]->{name}) unless ($_[0]->{no_modes});
}


sub sig_redir_modelist_invite
{
	my ($nick, $chan, $mode) = split(/ +/, $_[1], 3);
	message_irc_mode($_[0], $chan, undef, undef, "+I $mode");
}

sub sig_redir_modelist_except
{
	my ($nick, $chan, $mode) = split(/ +/, $_[1], 3);
	message_irc_mode($_[0], $chan, undef, undef, "+e $mode");
}

sub message_irc_mode
{
	my ($mode, @args) = split(/ +/, $_[4]);
	return unless $_[0]->ischannel($_[1]);
	my ($tag, $chan, $mod) = (lc($_[0]->{tag}), lc($_[0]->channel_find($_[1])->{name}), "+");
	foreach ( split //, $mode )
	{
		/([+-])/ and $mod = $_, next;
		my $arg = ( $mod eq '+' && $_ =~ m/[beIkloRvh]/ or $mod eq '-' && $_ =~ m/[beIkoRvh]/ ) ? shift(@args) : undef;
		next unless ( $_ =~ m/[eI]/ );
		( $mod eq '+' ) and push(@{$modelist{$tag}{$chan}{$_}}, [$arg, $_[2], time]), next;
		for (my $idx = 0; $idx <= $#{$modelist{$tag}{$chan}{$_}}; $idx++) {
			splice(@{$modelist{$tag}{$chan}{$_}}, $idx, 1) if ($modelist{$tag}{$chan}{$_}[$idx][0] eq $arg);
		}
	}
}

sub proc_modelist_show
{
	my ($arg, $server, $channel, $list, $mode) = @_;

	Irssi::print("You\'re not connected to server"), return unless ($server and $server->{connected});
	
	$arg =~ s/\s.*//;
	if ($arg) {
		Irssi::print("Bad channel name: $arg"), return unless ($server->ischannel($arg));
		unless ($channel = $server->channel_find($arg)) {
			Irssi::print("You\'re not in channel $arg --> sending request to server");
			$server->send_raw("MODE $arg $list");
			return;
		}
	}

	Irssi::print("Not joined to any channel"), return unless ($channel and $channel->{type} eq "CHANNEL");
	Irssi::print("Channel not fully synchronized yet, try again after a while"), return unless ($channel->{synced});
	Irssi::print("Channel doesn\'t support modes"), return if ($channel->{no_modes});

	my ($tag, $name) = (lc($server->{tag}), $channel->{name});
	my $chan = lc($name);
	my $items = $#{$modelist{$tag}{$chan}{$list}};

	Irssi::print("No $mode\s in channel %_$name%_"), return if ($items < 0);

	for (my $idx = 0; $idx <= $items; $idx++)
	{
		my ($mask, $who) = ($modelist{$tag}{$chan}{$list}[$idx]->[0], $modelist{$tag}{$chan}{$list}[$idx]->[1]);
		$mask =~ tr/\240\002\003\037\026/\206\202\203\237\226/;
		my $setby = ($who) ? "\00314[\003by \002$who\002, ".(time - $modelist{$tag}{$chan}{$list}[$idx]->[2])." secs ago\00314]\003" : undef;
		$channel->printformat(MSGLEVEL_CRAP, 'modelist', ($idx+1), $name, $mode, $mask, $setby);
	}
}

sub cmd_si { proc_modelist_show @_, "I", "invite"; }
sub cmd_se { proc_modelist_show @_, "e", "ban exception"; }

sub cmd_modelist {
	my ( $type, $data, $server, $witem) = @_;
	Irssi::print("You\'re not connected to server"), return unless ($server and $server->{connected});
	Irssi::print("Not joined to any channel"), return unless ( $witem and $witem->{type} eq "CHANNEL" );
	my ($tag, $chan, @masks) = (lc($server->{tag}), lc($server->channel_find($witem->{name})->{name})); 
	while ( $data =~ m/(\d+)/g ) {
		my $idx = $1 - 1;
		next unless ( exists $modelist{$tag}{$chan}{$type}[$idx] );
		push(@masks, $modelist{$tag}{$chan}{$type}[$idx]->[0]);
	}
	return unless ( $#masks >= 0 );
	$witem->command(sprintf("MODE %s -%s %s", $chan, $type x scalar(@masks), join(" ", @masks)));
}

Irssi::signal_add("channel created", "sig_channel_created");
Irssi::signal_add("redir modelist invite", "sig_redir_modelist_invite");
Irssi::signal_add("redir modelist except", "sig_redir_modelist_except");
Irssi::signal_add("message irc mode", "message_irc_mode");

Irssi::command_bind("si", "cmd_si");
Irssi::command_bind("se", "cmd_se");
Irssi::command_bind("uninvite" => sub { cmd_modelist("I", @_); });
Irssi::command_bind("unexcept" => sub { cmd_modelist("e", @_); });

foreach my $server (Irssi::servers)
{
	foreach my $channel ($server->channels())
	{
		channel_create($server, $channel->{name}) unless ($channel->{no_modes});
	}
}
