use Irssi 20020300;
use strict;

use vars qw($VERSION %IRSSI %HELP);
$HELP{getop} = "
GETOP [channel]

Gets op on current channel or 'channel' from random opped bot added by ADDGETOP.
";
$HELP{addgetop} = "
ADDGETOP [channel] <mask> <command>

Adds entry to 'channel' or current channel getop list.
The \$0 in command specifies nick of random found mask
in channel.
";
$HELP{delgetop} = "
DELGETOP [channel] <mask or index number from LISTGETOP>

Deletes entry from getoplist on current channel or 'channel'.
";
$HELP{listgetop} = "
LISTGETOP [channel]

Lists all entries in getop list or just 'channel's getop list.
";
$VERSION = "0.9b";
%IRSSI = (
	authors         => "Maciek \'fahren\' Freudenheim",
	contact         => "fahren\@bochnia.pl",
	name            => "GetOP",
	description     => "Automatically request op from random opped person with specifed command from list after joining channel",
	license         => "GNU GPLv2 or later",
	changed         => "Fri Jan 10 03:54:07 CET 2003"
);

Irssi::theme_register([
	'getop_listline', '[%W$[!-2]0%n]%| $[40]1%_: %_$2',
	'getop_add', 'Added \'%_$2%_\' to getop list on channel %_$1%_ /$0/',
	'getop_del', 'Deleted \'%_$2%_\' from getop list on channel %_$1%_ /$0/',
	'getop_changed', 'Changed command for mask \'%_$2%_\' on channel %_$1%_ /$0/',
	'getop_noone', '"%Y>>%n No one to get op from on $1 /$0/',
	'getop_get', '%Y>>%n Getting op from %_$2%_ on $1 /$0/'
]);

my %getop = ();
my @userhosts;
my $getopfile = Irssi::get_irssi_dir . "/getoplist";

sub sub_getop {
	my ($args, $server, $winit) = @_;

	my $chan;
	my ($channel) = $args =~ /^([^\s]+)/;

	if ($server->ischannel($channel)) {
		unless ($chan = $server->channel_find($channel)) {
			Irssi::print("%R>>%n You are not on $channel.");
			return;
		}
		$args =~ s/^[^\s]+\s?//;
	} else {
		unless ($winit && $winit->{type} eq "CHANNEL") {
			Irssi::print("%R>>%n You don't have active channel in that window.");
			return;
		}
		$channel = $winit->{name};
		$chan = $winit;
	}

	if ($chan->{chanop}) {
		Irssi::print("%R>>%n You are already opped on $channel.");
		return;
	}

	$channel = lc($channel);
	my $tag = lc($server->{tag});

	unless ($getop{$tag}{$channel}) {
		Irssi::print("%R>>%n Your getop list on channel $channel is empty. Use /ADDGETOP first.");
		return;
	};

	unless ($getop{$tag}{$channel}) {
		Irssi::print("%R>>%n Your getop list on channel $channel is empty.");
		return;
	}

	getop_proc($tag, $chan);
}

sub sub_addgetop {
	my ($args, $server, $winit) = @_;

	my ($channel) = $args =~ /^([^\s]+)/;

	if ($server->ischannel($channel)) {
		$args =~ s/^[^\s]+\s?//;
	} else {
		unless ($winit && $winit->{type} eq "CHANNEL") {
			Irssi::print("%R>>%n You don't have active channel in that window.");
			return;
		}
		$channel = $winit->{name};
	}

	my ($mask, $command) = split(/ +/, $args, 2);
	
	unless ($command) {
		Irssi::print("Usage: /ADDGETOP [channel] <mask or nickname> <command>. If you type '\$0' in command then it will be changed automatically into mask's nick.");
		return;
	}

	my $cmdchar = Irssi::settings_get_str('cmdchars');
	$command =~ s/^($cmdchar*)\^?/\1^/g;
	
	if (index($mask, "@") == -1) {
		my ($c, $n);
		if (($c = $server->channel_find($channel)) && ($n = $c->nick_find($mask))) {
			$mask = $n->{host};
			$mask =~ s/^[~+\-=^]/*/;
		} else {
			$server->redirect_event('userhost', 1, $mask, 0, undef, {
					'event 302' => 'redir getop userhost',
					'' => 'event empty' } );
			$server->send_raw("USERHOST $mask");
			my $uh = lc($mask) . " " . lc($channel) . " $command";
			push @userhosts,  $uh;
			return;
		}
	}
	
	$mask = "*!" . $mask if (index($mask, "!") == -1);
	my $tag = lc($server->{tag});
	my $channel = lc($channel);
	
	for my $entry (@{$getop{$tag}{$channel}}) {
		if ($entry->{mask} eq $mask) {
			$entry->{command} = $command;
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'getop_changed', $tag, $channel, $mask, $command);
			&savegetop;
			return;
		}
	}
	
	my $gh = {
		mask	=> $mask,
		command	=> $command
	};
	
	push @{$getop{$tag}{$channel}}, $gh;

	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'getop_add', $tag, $channel, $mask, $command);

	&savegetop;
}

sub sub_delgetop {
	my ($args, $server, $winit) = @_;

	my ($channel) = $args =~ /^([^\s]+)/;

	if ($server->ischannel($channel)) {
		$args =~ s/^[^\s]+\s?//;
	} else {
		unless ($winit && $winit->{type} eq "CHANNEL") {
			Irssi::print("%R>>%n You don't have active channel in that window.");
			return;
		}
		$channel = $winit->{name};
	}

	my $tag = lc($server->{tag});
	my $channel = lc($channel);

	unless ($getop{$tag}{$channel}) {
		Irssi::print("%R>>%n Your getop list on channel $channel is empty.");
		return;
	}

	unless ($args) {
		Irssi::print("%W>>%n Usage: /DELGETOP [channel] <mask | index from LISTGETOP>");
		return;
	}

	my $num;
	if ($args =~ /^[0-9]+$/) {
		if ($args > scalar(@{$getop{$tag}{$channel}})) {
			Irssi::print("%R>>%n No such entry in $channel getop list.");
			return;
		}
		$num = $args - 1;
	} else {
		my $i = 0;
		for my $entry (@{$getop{$tag}{$channel}}) {
			$args eq $entry->{mask} and $num = $i, last;
			$i++;
		}
	}

	if (my($gh) = splice(@{$getop{$tag}{$channel}}, $num, 1)) {
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'getop_del', $tag, $channel, $gh->{mask}, $gh->{command});
		unless (scalar(@{$getop{$tag}{$channel}})) {
			Irssi::print("%R>>%n No more entries in $channel getop list left.");
			delete $getop{$tag}{$channel};
		}
		unless (keys %{$getop{$tag}}) {
			Irssi::print("%R>>%n No more entries in getop list on $tag left.");	
			delete $getop{$tag};
		}
	}

	&savegetop;
}

sub sub_listgetop {
	my ($args, $server, $winit) = @_;

	my ($channel) = $args =~ /^([^\s]+)/;

	if ($server->ischannel($channel)) {
		my $tag = lc($server->{tag});
		$channel = lc($channel);
		unless ($getop{$tag}{$channel}) {
			Irssi::print("%R>>%n Your getop list on channel $channel is empty.");
			return;
		}
		my $i = 0;
		Irssi::print("Getop list on $channel /$tag/:");
		for my $entry (@{$getop{$tag}{$channel}}) {
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'getop_listline', $i++, $entry->{mask}, $entry->{command});
		}
	} else {
		unless (keys %getop) {
			Irssi::print("%R>>%n Your getop list is empty. /ADDGETOP first.");
			return;
		}
		for my $ircnet (keys %getop) {
			for my $chan (keys %{$getop{$ircnet}}) {
				Irssi::print("Channel: $chan /$ircnet/");
				my $i = 1;
				for my $entry (@{$getop{$ircnet}{$chan}}) {
					Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'getop_listline', $i++, $entry->{mask}, $entry->{command});
				}
			}
		}
	}
}

sub userhost_red {
	my ($server, $data) = @_;
	$data =~ s/^[^ ]* :?//;

	my $uh = shift @userhosts;
	my ($nick, $chan, $command) = split(/ /, $uh, 3);

	unless ($data && $data =~ /^([^=\*]*)\*?=.(.*)@(.*)/ && lc($1) eq $nick) {
		Irssi::print("%R>>%n No such nickname: $nick");
		return;
	}

	my ($user, $host) = ($2, $3);
	$user =~ s/^[~+\-=^]/*/;
	my $mask = "*!" . $user . "@" . $host;
	my $tag = lc($server->{tag});
	
	for my $entry (@{$getop{$tag}{$chan}}) {
		if ($entry->{mask} eq $mask) {
			$entry->{command} = $command;
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'getop_changed', $tag, $chan, $mask, $command);
			&savegetop;
			return;
		}
	}
	
	my $gh = {
		mask => $mask,
		command => $command
	};

	push @{$getop{$tag}{$chan}}, $gh;

	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'getop_add', $tag, $chan, $mask, $command);

	&savegetop;
}

sub getop_proc ($$) {
	my ($tag, $chan) = @_;

	my $channel = lc($chan->{name});
	return unless ($getop{$tag}{$channel});

	my (@list, $mask);
	for my $nick ($chan->nicks()) {
		next unless ($nick->{op});
		$mask = $nick->{nick} . "!" . $nick->{host};
		for my $entry (@{$getop{$tag}{$channel}}) {
			if (mask_match($mask, $entry->{mask})) {
				my $lh = {
					nick	=> $nick->{nick},
					command	=> $entry->{command}
				};
				push @list, $lh;
			}
		}
	}
	
	unless (@list) {
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'getop_noone', $tag, $channel);
	} else {
		my $get = $list[int(rand(@list))];
		$get->{command} =~ s/\$0/$get->{nick}/g;
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'getop_get', $tag, $channel, $get->{nick}, $get->{command});	
		$chan->command($get->{command});
	}
}

sub mask_match ($$) {
	my ($what, $match) = @_;

	$match =~ s/\\/\\\\/g;
	$match =~ s/\./\\\./g;
	$match =~ s/\*/\.\*/g;
	$match =~ s/\!/\\\!/g;
	$match =~ s/\?/\./g;
	$match =~ s/\+/\\\+/g;
	$match =~ s/\^/\\\^/g;

	return ($what =~ /^$match$/i);
}

sub got_notopped {
	my ($server, $data) = @_;
	my ($chan) = $data =~ /^[^\s]+\s([^\s]+)\s:/;
	getop_proc(lc($server->{tag}), $server->channel_find($chan));
}

sub channel_sync {
	my $chan = shift;
	getop_proc(lc($chan->{server}->{tag}), $chan) unless ($chan->{chanop});
}

sub savegetop {
	local *fp;
	open (fp, ">", $getopfile) or die "Couldn't open $getopfile for writing";

	for my $ircnet (keys %getop) {
		for my $chan (keys %{$getop{$ircnet}}) {
			for my $entry (@{$getop{$ircnet}{$chan}}) {
				print(fp "$ircnet $chan $entry->{mask} $entry->{command}\n");
			}
		}
	}

	close fp;
}

sub loadgetop {
	%getop = ();
	return unless (-e $getopfile);
	local *fp;

	open (fp, "<", $getopfile) or die "Couldn't open $getopfile for reading";
	local $/ = "\n";
	
	while (<fp>) {
		chop;
		my $gh = {};
		my ($tag, $chan);
		($tag, $chan, $gh->{mask}, $gh->{command}) = split(/ /, $_, 4);
		push @{$getop{$tag}{$chan}}, $gh;
	}
	
	close fp;
}

&loadgetop;

Irssi::command_bind( {
		'getop' => \&sub_getop,
		'addgetop' => \&sub_addgetop,
		'delgetop' => \&sub_delgetop,
		'listgetop' => \&sub_listgetop } );
Irssi::signal_add({ 'redir getop userhost' => \&userhost_red,
		    'event 482' => \&got_notopped,
	    	    'channel sync' => \&channel_sync});
