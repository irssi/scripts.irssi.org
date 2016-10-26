use Irssi 20020300;
use 5.6.0;
use strict;
use Socket;
use POSIX;

use vars qw($VERSION %IRSSI %HELP);
$HELP{ban} = "
BAN [channel] [-normal|-host|-user|-domain|-crap|-ip|-class -before \"command\"|-after \"command\" nicks|masks] ...

Bans the specified nicks or userhost masks.

If nick is given as parameter, the ban type is used to generate the ban mask.
/SET banpl_type specified the default ban type. Ban type is one of the following:

    normal - *!fahren\@*.ds14.agh.edu.pl
    host   - *!*\@plus.ds14.agh.edu.pl
    user   - *!fahren@*
    domain - *!*\@*.agh.edu.pl
    crap   - *?fah???\@?l??.?s??.??h.???.?l
    ip     - *!fahren\@149.156.124.*
    class  - *!*\@149.156.124.*

Only one flag can be specified for a given nick.
Script removes any conflicting bans before banning.

You can specify command that will be executed before or after
banning nick/mask using -before or -after.

Examples:
      /BAN fahren       - Bans the nick 'fahren'
      /BAN -ip fahren   - Bans the ip of nick 'fahren'
      /BAN fahren -ip fantazja -crap nerhaf -normal ff
                        - Bans 'fahren' (using banpl_type set), ip of 'fantazja',
                          host with crap mask of 'nerhaf' and 'ff' with normal bantype.
      /BAN *!*fahren@*  - Bans '*!*fahren@*'
      /BAN #chan -after \"KICK #chan fahren :reason\" fahren
                        - Bans and kicks 'fahren' from channel '#chan' with reason 'reason'.

      /ALIAS ipkb ban \$C -after \"KICK \$C \$0 \$1-\" -ip \$0
                        - Adds command /ipkb <nick> [reason] which kicks 'nick' and bans it's ip address.
";
$VERSION = "1.4d";
%IRSSI = (
	authors         => "Maciek \'fahren\' Freudenheim",
	contact         => "fahren\@bochnia.pl",
	name            => "ban",
	description     => "/BAN [channel] [-normal|-host|-user|-domain|-crap|-ip|-class -before|-after \"cmd\" nick|mask] ... - bans several nicks/masks on channel, removes any conflicting bans before banning",
	license         => "GNU GPLv2 or later",
	changed         => "Tue Nov 19 18:11:09 CET 2002"
);

# Changelog:
# 1.4d
# - getting user@host of someone who isn't on channel was broken
# 1.4c
# - fixed banning of unresolved hosts
# - fixed problem with /ban unexisting_nick other_nick
# 1.4b
# - doesn't require op to see banlist :)
# 1.4
# - few fixes
# - using banpl_type instead of irssi's builtin ban_type
# - changed -normal behaviour
# 1.3
# - :( fixed crap banning (yes, i'm to stupid to code it)
# 1.2
# - queuing MODES for nicks that aren't on channel
# 1.11
# - fixed .. surprise! crap banning
# - added use 5.6.0
# 1.1
# - fixed banning 10-char long idents
# - fixed crap banning (once more)
# - added -before and -after [command] for executing command before/after setting ban
# 1.0
# - -o+b if banning opped nick
# - fixed -crap banning
# - always banning with *!*ident@ (instead of *!ident@)
# - can take channel as first argument now
# - displays error if it couldn't resolve host for -ip / -class ban
# - groups all modes and sends them at once, ie. -bbo\n+b-o+b 
# - gets user@host via USERHOST if requested ban of someone who is not on channel
# - added help

my (%ftag, $parent, %modes, %modes_args, %b, @userhosts);

sub cmd_ban {
        my ($args, $server, $winit) = @_;

	my $chan;
	my ($channel) = $args =~ /^([^\s]+)/;
	
	if (($server->ischannel($channel))) {
		$args =~ s/^[^\s]+\s?//;
		return unless ($args);
		unless (($chan = $server->channel_find($channel)) && $chan->{chanop}) {
			Irssi::print("%R>>%n You are not on $channel or you are not opped.");
			Irssi::signal_stop();
			return;
		}
	} else {
		return unless ($args);
		unless ($winit && $winit->{type} eq "CHANNEL" && $winit->{chanop}) {
			Irssi::print("%R>>%n You don't have active channel in that window or you are not opped.");
			Irssi::signal_stop();
			return;
		}
		$chan = $winit;
		$channel = $chan->{name};
	}

	Irssi::signal_stop();

	my $bantype = Irssi::settings_get_str("banpl_type");
	my $max = $server->{max_modes_in_cmd};
	my ($cmdwhat, $cmdwhen) = (0, 0);
	$b{$channel} = 0;

	# counts nicks/masks to ban, lame :|
	for my $cmd (split("\"", $args)) {
		($cmdwhen) and $cmdwhen = 0, next;
		for (split(/ +/, $cmd)) {
			next unless $_;
			/^-(normal|host|user|domain|crap|ip|class)$/ and next;
			/^-(before|after)$/ and $cmdwhen = 1, next;
			$b{$channel}++;
		}
	}

	for my $cmd (split("\"", $args)) {
		($cmdwhen && !$cmdwhat) and $cmdwhat = $cmd, next;
	for my $arg (split(/ +/, $cmd)) {
		next unless $arg;	
		$arg =~ /^-(normal|host|user|domain|crap|ip|class)$/ and $bantype = $1, next;
		$arg eq "-before" and $cmdwhen = 1, next;
		$arg eq "-after" and $cmdwhen = 2, next;
	
		if (index($arg, "@") == -1) {
			my $n;
			if ($n = $chan->nick_find($arg)) {
				# nick is on channel

				my ($user, $host) = split("@", $n->{host});
				
				if ($bantype eq "ip" || $bantype eq "class") {
					# requested ip ban, forking
					my $pid = &ban_fork;
					unless (defined $pid) {	# error
						$cmdwhen = $cmdwhat = 0;	
						$b{$channel}--;
						next;
					} elsif ($pid) {	# parent
						$cmdwhen = $cmdwhat = 0;	
						next;
					}
					my $ia = gethostbyname($host);
					unless ($ia) {
						print($parent "error $channel %R>>%n Couldn't resolve $host.\n");
					} else {
						print($parent "execute $server->{tag} $channel " . (($n->{op})? $arg : 0) . " " . make_ban($user, inet_ntoa($ia), $bantype) . " $cmdwhen $cmdwhat\n"); 
					}
					close $parent; POSIX::_exit(1);
				}
				ban_execute($chan, (($n->{op})? $arg : 0), make_ban($user, $host, $bantype), $max, $cmdwhen, $cmdwhat);
			} else {
				# nick is not on channel, trying to get addres via /userhost
				$server->redirect_event('userhost', 1, $arg, 0, undef, {
						'event 302' => 'redir ban userhost',
						'' => 'event empty' } );
				$server->send_raw("USERHOST :$arg");
				my $uh = {
					tag 	=> $server->{tag},
					nick 	=> lc($arg),
					channel => $channel,
					chanhash => $chan,
					bantype	=> $bantype,
					cmdwhen	=> $cmdwhen,
					cmdwhat	=> $cmdwhat
				};
				push @userhosts, $uh;
			}
		} else {
			# specified mask
			my $ban;
			$ban = "*!" if (index($arg, "!") == -1);
			$ban .= $arg;
			ban_execute($chan, 0, $ban, $max, $cmdwhen, $cmdwhat);
		}

		$cmdwhen = $cmdwhat = 0;	
	}
	}
}

sub push_mode ($$$$) {
	my ($chan, $mode, $arg, $max) = @_;

	my $channel = $chan->{name};
	$modes{$channel} .= $mode;
	$modes_args{$channel} .= "$arg ";

	flush_mode($chan) if (length($modes{$channel}) >= ($max * 2));
}

sub flush_mode ($) {
	my $chan = shift;

	my $channel = $chan->{name};
	return unless (defined $modes{$channel});
#	Irssi::print("MODE $channel $modes{$channel} $modes_args{$channel}");
	$chan->command("MODE $channel $modes{$channel} $modes_args{$channel}");
	undef $modes{$channel}; undef $modes_args{$channel};
}

sub userhost_red {
	my ($server, $data) = @_;
	$data =~ s/^[^ ]* :?//;

	my $uh = shift @userhosts;
	
	unless ($data && $data =~ /^([^=\*]*)\*?=.(.*)@(.*)/ && lc($1) eq $uh->{nick}) {
		Irssi::print("%R>>%n No such nickname: $uh->{nick}");
		$b{$uh->{channel}}--;
		flush_mode($uh->{chanhash}) unless ($b{$uh->{channel}});
		return;
	}
	
	my ($user, $host) = (lc($2), lc($3));
	
	if ($uh->{bantype} eq "ip" || $uh->{bantype} eq "class") {
		# requested ip ;/
		my $pid = &ban_fork;
		unless (defined $pid) {	# error
			$b{$uh->{channel}}--;
			return;
		} elsif ($pid) {	# parent
			return;
		}
		my $ia = gethostbyname($host);
		unless ($ia) {
			print($parent "error " . $uh->{channel} . " %R>>%n Couldn't resolve $host.\n");
		} else {
			print($parent "execute " . $uh->{tag} . " " . $uh->{channel} . " 0 " . make_ban($user, inet_ntoa($ia), $uh->{bantype}) . " " . $uh->{cmdwhen} . " " . $uh->{cmdwhat} . "\n"); 
		}
		close $parent; POSIX::_exit(1);
	}
	
	my $serv = Irssi::server_find_tag($uh->{tag});
	ban_execute($uh->{chanhash}, 0, make_ban($user, $host, $uh->{bantype}), $serv->{max_modes_in_cmd}, $uh->{cmdwhen}, $uh->{cmdwhat});
}

sub ban_execute ($$$$$$) {
	my ($chan, $nick, $ban, $max, $cmdwhen, $cmdwhat) = @_;

	my $no = 0;
	my $channel = $chan->{name};
	
	for my $hash ($chan->bans()) {
		if (mask_match($ban, $hash->{ban})) {
			# should display also who set the ban (if available)
			Irssi::print("%Y>>%n $channel: ban $hash->{ban}");
			$no = 1;
			last;
		} elsif (mask_match($hash->{ban}, $ban)) {
			push_mode($chan, "-b", $hash->{ban}, $max);
		}
	}	

	unless ($no) {
		my ($cmdmode, $cmdarg);
		# is requested command a MODE so we can put it to queue?
	 	($cmdmode, $cmdarg) = $cmdwhat =~ /^MODE\s+[^\s]+\s+([^\s]+)\s+([^\s]+)/i if $cmdwhen;
		if ($cmdwhen == 1) { # command requested *before* banning
			unless ($cmdmode) { # command isn't mode, ie: KICK
				flush_mode($chan); # flush all -b conflicting bans
				$chan->command($cmdwhat); # execute
			} else { # command is MODE, we can add it to queue
				push_mode($chan, $cmdmode, $cmdarg, $max);	
			}
		}
		push_mode($chan, "-o", $nick, $max) if ($nick);
		push_mode($chan, "+b", $ban, $max);
		if ($cmdwhen == 2) { # command requested *after* banning
			unless ($cmdmode) {
				flush_mode($chan); # flush all modes
				$chan->command($cmdwhat);
			} else {
				push_mode($chan, $cmdmode, $cmdarg, $max);
			}
		}
	}

	$b{$channel}--;
	flush_mode($chan) unless ($b{$channel});
}

sub ban_fork {
	my ($rh, $wh);
	pipe($rh, $wh);
	my $pid = fork();
	unless (defined $pid) {
		Irssi::print("%R>>%n Failed to fork() :/ -  $!");
		close $rh; close $wh;
		return undef;
	} elsif ($pid) {	# parent
		close $wh;
		$ftag{$rh} = Irssi::input_add(fileno($rh), INPUT_READ, \&ifork, $rh);
		Irssi::pidwait_add($pid);
	} else {		# child
		close $rh;
		$parent = $wh;
	}
	return $pid;
}

sub ifork {
	my $rh = shift;
	while (<$rh>) {
		/^error\s([^\s]+)\s(.+)/ and $b{$1}--, Irssi::print("$2"), last;
		if (/^execute\s([^\s]+)\s([^\s]+)\s([^\s]+)\s([^\s]+)\s([^\s]+)\s(.+)/) {
			my $serv = Irssi::server_find_tag($1);
			ban_execute($serv->channel_find($2), $3, $4, $serv->{max_modes_in_cmd}, $5, $6);
			last;
		}
	}
	Irssi::input_remove($ftag{$rh});
	delete $ftag{$rh};
	close $rh;
}
						
sub make_ban ($$$) {
	my ($user, $host, $bantype) = @_;
					
	$user =~ s/^[~+\-=^]/*/;
	if ($bantype eq "ip") {
		$host =~ s/\.[0-9]+$/.*/;
	} elsif ($bantype eq "class") {
		$user = "*";	
		$host =~ s/\.[0-9]+$/.*/;
	} elsif ($bantype eq "user") {
		$host = "*";
	} elsif ($bantype eq "domain") {
		# i know -- lame
		if ($host =~ /^.*\..*\..*\..*$/) {
			$host =~ s/.*(\..+\..+\..+)$/*\1/;
		} elsif ($host =~ /^.*\..*\..*$/) {
			$host =~ s/.*(\..+\..+)$/*\1/;
		}
		$user = "*";
	} elsif ($bantype eq "host") {
		$user = "*";
	} elsif ($bantype eq "normal") {
#		$host =~ s/^[A-Za-z\-]*[0-9]+\./*./;
		if ($host =~ /\d$/) {
			$host =~ s/\.[0-9]+$/.*/;
		} else {
			$host =~ s/^[^.]+\./*./ if $host =~ /^.*\..*\..*$/;
		}
	} elsif ($bantype eq "crap") {
		my $crap;
		for my $c (split(//, $user)) {
			$crap .= ((int(rand(2)))? "?" : $c);
		}
		$user = $crap;
		$crap = "";
		for my $c (split(//, $host)) {
			$crap .= ((int(rand(2)))? "?" : $c);
		}
		$host = $crap;
	}

	return ("*!" . $user . "@" . $host);
}

sub mask_match ($$) {
	my ($what, $match) = @_;

	# stolen from shasta's friend.pl
	$match =~ s/\\/\\\\/g;
	$match =~ s/\./\\\./g;
	$match =~ s/\*/\.\*/g;
	$match =~ s/\!/\\\!/g;
	$match =~ s/\?/\./g;
	$match =~ s/\+/\\\+/g;
	$match =~ s/\^/\\\^/g;
	$match =~ s/\[/\\\[/g;

	return ($what =~ /^$match$/i);
}

Irssi::command_bind 'ban' => \&cmd_ban;
Irssi::settings_add_str 'misc', 'banpl_type', 'normal';
Irssi::signal_add 'redir ban userhost' => \&userhost_red;
