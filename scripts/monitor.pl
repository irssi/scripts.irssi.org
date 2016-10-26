#!/usr/bin/perl
# Copyright (c) 2006 Jilles Tjoelker
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";

%IRSSI = (
    authors    => "Jilles Tjoelker",
    contact    => "jilles\@stack.nl",
    name       => "monitor",
    description=> "Interface to ratbox 2.1+ /monitor command",
    license    => "BSD (revised)",
);

# Track the nicks in our monitor list
my %monitorlist;
# Server::connect_time we added monitor items
my %readded;
# Nicks waiting on /accept
my %acceptqueue;

Irssi::theme_register([monitoron => 'Now online: {nick $0} {nickhost $1}',
	monitoroff => 'Now offline: {nick $0} {nickhost $1} {comment $2}',
	monitorlist => 'Monitored: $0',
	monitordel => 'No longer monitoring: $0',
	monitoralready => 'Already monitoring: $0']);

sub event_motdgot {
	my ($server, $args, $nick, $address) = @_;

	if ($readded{$server->{tag}} != $server->{connect_time}) {
		Irssi::print("Readding monitor items");
		cmd_monitor_readd('', $server, undef);
	}
}

sub doaccept {
	my $server = shift;

	if (defined $server->isupport("CALLERID")) {
		$server->print('','Accepting '.$acceptqueue{$server->{tag}});
		$server->command("QUOTE ACCEPT ".$acceptqueue{$server->{tag}});
	} else {
		$server->print('','Not accepting '.$acceptqueue{$server->{tag}}.', server does not support callerid');
	}
	$acceptqueue{$server->{tag}} = '';
}

sub nowonline {
	my ($server, $nuh) = @_;
	my ($n, $uh) = split /!/, $nuh, 2;
	my $ln = lc $n;

	$server->printformat('', MSGLEVEL_CLIENTCRAP, 'monitoron', $n, $uh);
	$monitorlist{$server->{tag}}{$ln}{lastseen} = time();
	if ($monitorlist{$server->{tag}}{$ln}{action} eq 'accept') {
		if ($acceptqueue{$server->{tag}} eq '') {
			Irssi::timeout_add_once(3000, 'doaccept', $server);
			$acceptqueue{$server->{tag}} = $n;
		} else {
			$acceptqueue{$server->{tag}} .= ','.$n;
		}
	}
}

sub event_mononline {
	my ($server, $args, $nick, $address) = @_;
	my @a = split(/ +/, $args);
	my ($nuh, $n, $addr, $ln);
# :jaguar.test 730 jilles :n!u@h,n2!u@h
	$a[1] =~ s/^://;
	foreach $nuh (split /,/, $a[1]) {
		($n, $addr) = split /!/, $nuh;
		$ln = lc $n;
		$monitorlist{$server->{tag}}{$ln}{address} = $addr;
		$monitorlist{$server->{tag}}{$ln}{nick_online} = 1;
		$monitorlist{$server->{tag}}{$ln}{mask_online} = $server->masks_match($monitorlist{$server->{tag}}{$ln}{masks}, $n, $addr);
		if ($monitorlist{$server->{tag}}{$ln}{mask_online}) {
			nowonline($server, $nuh);
		} elsif ($monitorlist{$server->{tag}}{$ln}{new}) {
			$server->printformat('', MSGLEVEL_CLIENTCRAP, 'monitoroff', $n, '');
		}
		$monitorlist{$server->{tag}}{$ln}{new} = 0;
	}
	Irssi::signal_stop();
}

sub event_monoffline {
	my ($server, $args, $nick, $address) = @_;
	my @a = split(/ +/, $args);
	my ($n, $ln);
# :jaguar.test 731 jilles :n,n2
	$a[1] =~ s/^://;
	foreach $n (split /,/, $a[1]) {
		$ln = lc $n;
		if ($monitorlist{$server->{tag}}{$ln}{mask_online} || $monitorlist{$server->{tag}}{$ln}{new}) {
			if ($monitorlist{$server->{tag}}{$ln}{nick_online}) {
				$server->printformat('', MSGLEVEL_CLIENTCRAP, 'monitoroff', $n, $monitorlist{$server->{tag}}{$ln}{address});
			} else {
				$server->printformat('', MSGLEVEL_CLIENTCRAP, 'monitoroff', $n, '');
			}
			$monitorlist{$server->{tag}}{$ln}{lastseen} = time() if $monitorlist{$server->{tag}}{$ln}{mask_online};
			$monitorlist{$server->{tag}}{$ln}{mask_online} = 0;
			$monitorlist{$server->{tag}}{$ln}{new} = 0;
		}
		$monitorlist{$server->{tag}}{$ln}{nick_online} = 0;
	}
	Irssi::signal_stop();
}

sub event_monlist {
	my @a = split(/ +/, $_[1]);
# :jaguar.test 732 jilles :n,n2
	$a[1] =~ s/^://;
	$a[1] =~ s/,/ /g;
	$_[0]->printformat('', MSGLEVEL_CLIENTCRAP, 'monitorlist', $a[1]);
	Irssi::signal_stop();
}

sub cmd_monitor {
	my ($data, $server, $item) = @_;

	if ($data ne '') {
		Irssi::command_runsub ('monitor', $data, $server, $item);
	} else {
		cmd_monitor_show(@_);
	}
}

sub cmd_monitor_add {
	my ($data, $server, $item) = @_;
	my @nicks;
	my $data2;
	my $nuh;
	my ($n, $ln);
	my ($doaction, $action) = (0, '');

	if (!defined $server->isupport("MONITOR")) {
		$server->print('', "No monitor support");
		return;
	}

	if ($data =~ /-([^ ]*) (.*)/) {
		$doaction = 1;
		$action = $1;
		$data = $2;
	}
	$data =~ s/ /,/g;
	@nicks = split /,/, $data;
	$data2 = '';
	foreach $nuh (@nicks) {
		$n = $nuh;
		$n =~ s/!.*//;
		next if $n eq '';
		if ($n eq $nuh) {
			$nuh .= '!*@*';
		}
		$ln = lc $n;
		if (defined($monitorlist{$server->{tag}}{$ln})) {
			if ($doaction) {
				$monitorlist{$server->{tag}}{$ln}{action} = $action;
			}
			my $m = ' '.$monitorlist{$server->{tag}}{$ln}{masks}.' ';
			if ($m =~ / \Q$nuh\E /) {
				$server->printformat('', MSGLEVEL_CLIENTCRAP, 'monitoralready', $nuh);
				next;
			}
			$monitorlist{$server->{tag}}{$ln}{masks} .= ' '.$nuh;
			if ($monitorlist{$server->{tag}}{$ln}{nick_online} &&
				!$monitorlist{$server->{tag}}{$ln}{mask_online})
			{
				if ($server->mask_match_address($nuh, $n, $monitorlist{$server->{tag}}{$ln}{address}))
				{
					$monitorlist{$server->{tag}}{$ln}{mask_online} = 1;
					nowonline($server, $n.'!'.$monitorlist{$server->{tag}}{$ln}{address});
				}
			}
		} else {
			$data2 .= ','.$n;
			$monitorlist{$server->{tag}}{$ln}{masks} = $nuh;
			$monitorlist{$server->{tag}}{$ln}{nick_online} = 0;
			$monitorlist{$server->{tag}}{$ln}{mask_online} = 0;
			$monitorlist{$server->{tag}}{$ln}{action} = $action;
			$monitorlist{$server->{tag}}{$ln}{lastseen} = 0;
			$monitorlist{$server->{tag}}{$ln}{new} = 1;
		}
	}
	$data2 =~ s/^,//;
	return if ($data2 eq '');
	$server->command("QUOTE MONITOR + $data2");
}

sub cmd_monitor_readd {
	my ($data, $server, $item) = @_;
	my ($n, $data2);
	
	$readded{$server->{tag}} = $server->{connect_time};
	$data2 = '';
	foreach $n (keys %{$monitorlist{$server->{tag}}}) {
		$data2 .= ','.$n;
	}
	$data2 =~ s/^,//;
	return if ($data2 eq '');
	if (!defined $server->isupport("MONITOR")) {
		$server->print('', "No monitor support");
		return;
	}
	$server->command("QUOTE MONITOR + $data2");
}

sub cmd_monitor_clear {
	my ($data, $server, $item) = @_;
	$monitorlist{$server->{tag}} = ();
	$server->printformat('', MSGLEVEL_CLIENTCRAP, 'monitordel', '*');
	if (defined $server->isupport("MONITOR")) {
		$server->command("QUOTE MONITOR C");
	}
}

sub cmd_monitor_delete {
	my ($data, $server, $item) = @_;
	my @nicks;
	my $data2;
	my $data3;
	my $nuh;
	my ($n, $ln);

	$data =~ s/ /,/g;
	@nicks = split /,/, $data;
	$data2 = '';
	$data3 = '';
	foreach $nuh (@nicks) {
		$n = $nuh;
		$n =~ s/!.*//;
		next if $n eq '';
		$ln = lc $n;
		next unless (defined($monitorlist{$server->{tag}}{$ln}));
		if ($n ne $nuh) {
			my $m = ' '.$monitorlist{$server->{tag}}{$ln}{masks}.' ';
			next unless ($m =~ s/ \Q$nuh\E / /);
			$m =~ s/^ //;
			$m =~ s/ $//;
			$monitorlist{$server->{tag}}{$ln}{masks} = $m;
			if ($m ne '') {
				if ($monitorlist{$server->{tag}}{$ln}{mask_online}) {
					$monitorlist{$server->{tag}}{$ln}{mask_online} = $server->masks_match($monitorlist{$server->{tag}}{$ln}{masks}, $n, $monitorlist{$server->{tag}}{$ln}{address});
					if (!$monitorlist{$server->{tag}}{$ln}{mask_online}) {
						$server->printformat('', MSGLEVEL_CLIENTCRAP, 'monitoroff', $n, '');
					}
				}
				$data3 .= $nuh.' ';
				next;
			}
		}
		$data3 .= $n.' ';
		delete $monitorlist{$server->{tag}}{$ln};
		$data2 .= ','.$n;
	}
	$data2 =~ s/^,//;
	$server->printformat('', MSGLEVEL_CLIENTCRAP, 'monitordel', $data3);
	return if ($data2 eq '');
	#$server->printformat('', MSGLEVEL_CLIENTCRAP, 'monitordel', $data2);
	if (defined $server->isupport("MONITOR")) {
		$server->command("QUOTE MONITOR - $data2");
	}
}

sub cmd_monitor_list {
	my ($data, $server, $item) = @_;
	my ($n, $ln);
	my $count = 0;
	my $misc;
	my $lastseen;

	foreach $n (keys %{$monitorlist{$server->{tag}}}) {
		$ln = lc $n;
		$misc = 'masks: '.$monitorlist{$server->{tag}}{$ln}->{masks};
		if ($monitorlist{$server->{tag}}{$ln}->{action}) {
			$misc .= ', action: '.$monitorlist{$server->{tag}}{$ln}->{action};
		}
		if ($monitorlist{$server->{tag}}{$ln}{mask_online}) {
			$server->printformat('', MSGLEVEL_CLIENTCRAP, 'monitorlist', $n.' ('.$monitorlist{$server->{tag}}{$ln}->{address}.'), '.$misc);
		} else {
			if ($monitorlist{$server->{tag}}{$ln}{lastseen}) {
				$lastseen = localtime($monitorlist{$server->{tag}}{$ln}{lastseen});
			} else {
				$lastseen = "never";
			}
			$server->printformat('', MSGLEVEL_CLIENTCRAP, 'monitorlist', $n.', '.$misc.', lastseen: '.$lastseen.', lastaddr: '.$monitorlist{$server->{tag}}{$ln}->{address});
		}
		$count++;
	}
	if ($count == 0) {
		Irssi::print("Monitor list for ".$server->{tag}." is empty");
	}
	#$server->command("QUOTE MONITOR L");
}

sub cmd_monitor_show {
	my ($data, $server, $item) = @_;
	my ($n, $ln);
	my $count = 0;
	my $lastseen;

	foreach $n (keys %{$monitorlist{$server->{tag}}}) {
		$ln = lc $n;
		if ($monitorlist{$server->{tag}}{$ln}{mask_online}) {
			$server->printformat('', MSGLEVEL_CLIENTCRAP, 'monitoron', $n, $monitorlist{$server->{tag}}{$n}->{address});
		} else {
			if ($monitorlist{$server->{tag}}{$n}{lastseen}) {
				$lastseen = localtime($monitorlist{$server->{tag}}{$n}{lastseen});
			} else {
				$lastseen = "never";
			}
			$server->printformat('', MSGLEVEL_CLIENTCRAP, 'monitoroff', $n, '', 'last seen: '.$lastseen);
		}
		$count++;
	}
	if ($count == 0) {
		Irssi::print("Monitor list for ".$server->{tag}." is empty");
	}
	#$server->command("QUOTE MONITOR S");
}

sub cmd_monitor_save {
	#my ($data, $server, $item) = @_;
	my $file = Irssi::get_irssi_dir."/monitor";
	my ($net, $n, $k);
	open FILE, ">", $file or return;
	foreach $net (keys %monitorlist) {
		foreach $n (keys %{$monitorlist{$net}}) {
			$monitorlist{$net}{$n}{lastseen} = time() if $monitorlist{$net}{$n}{mask_online};
			foreach $k (keys %{$monitorlist{$net}{$n}}) {
				next if ($k eq 'mask_online' || $k eq 'nick_online' || $k eq 'new');
				printf FILE ("%s %s %s %s\n", $net, $n, $k, $monitorlist{$net}{$n}{$k});
			}
		}
	}
	close FILE;
	Irssi::print("Monitor list saved to $file");
}

sub cmd_monitor_load {
	#my ($data, $server, $item) = @_;
	my $file = Irssi::get_irssi_dir."/monitor";

	open FILE, "<", $file or return;
	%monitorlist = ();
	while (<FILE>) {
		chomp;
		my ($net, $n, $k, $value) = split (/ /, $_, 4);
		$monitorlist{$net}{lc $n}{$k} = $value;
	}
	close FILE;
	Irssi::print("Monitor list loaded from $file");
}

sub cmd_monitor_help {
	#my ($data, $server, $item) = @_;

	Irssi::print(
"%CNotify list using MONITOR extension%n\n".
"This script provides a notify list using the MONITOR extension found ".
"in ratbox 2.1 and newer and charybdis (MONITOR keyword in 005 numeric).\n".
"Each server tag has its own list.\n\n".
"COMMANDS:\n\n".
"%_/MONITOR ADD [-|-accept] nick[!user\@host]...%_\n".
"  - Adds nicks/hostmasks or changes their accept setting, for this server. ".
"The nick cannot contain wildcards but the user\@host can. ".
"If the user\@host part is omitted, *@* is used. ".
"A - disables accept for the given nicks, a -accept enables it.\n".
"%_/MONITOR DEL nick[!user\@host]...%_\n".
"  - Deletes nicks/hostmasks for this server. If a user\@host is given, that ".
"user\@host is deleted and the whole nick if it was the last, otherwise the ".
"whole nick.\n".
"%_/MONITOR CLEAR%_\n".
"  - Clears the monitor list for this server.\n".
"%_/MONITOR [SHOW]%_\n".
"  - Shows the monitor list for this server in a brief format.\n".
"%_/MONITOR LIST%_\n".
"  - Shows the monitor list for this server in a long format.\n".
"%_/MONITOR LOAD%_\n".
"  - Reloads the monitor list for all servers from ~/.irssi/monitor. ".
"The lists on the servers are not updated.\n".
"%_/MONITOR SAVE%_\n".
"  - Saves the monitor list for all servers to ~/.irssi/monitor.\n".
"%_/MONITOR READD%_\n".
"  - Adds the known entries to the server-side list, for this server. ".
"This is normally done automatically when the MOTD is received.\n".
"\nAfter a reload of the script it may be necessary to do /foreach server /quote monitor s.".
"", MSGLEVEL_CLIENTCRAP);
}

Irssi::signal_add('event 376', 'event_motdgot');
Irssi::signal_add('event 422', 'event_motdgot');
Irssi::signal_add('event 730', 'event_mononline');
Irssi::signal_add('event 731', 'event_monoffline');
Irssi::signal_add('event 732', 'event_monlist');
#Irssi::signal_add('event 733', 'event_endofmonlist');
#Irssi::signal_add('event 734', 'event_monlistfull');

Irssi::signal_add_last('setup saved', 'cmd_monitor_save');
Irssi::signal_add_last('setup reread', 'cmd_monitor_load');

Irssi::command_bind('monitor', 'cmd_monitor');
Irssi::command_bind('monitor add', 'cmd_monitor_add');
Irssi::command_bind('monitor readd', 'cmd_monitor_readd');
Irssi::command_bind('monitor clear', 'cmd_monitor_clear');
Irssi::command_bind('monitor delete', 'cmd_monitor_delete');
Irssi::command_bind('monitor list', 'cmd_monitor_list');
Irssi::command_bind('monitor show', 'cmd_monitor_show');
Irssi::command_bind('monitor save', 'cmd_monitor_save');
Irssi::command_bind('monitor load', 'cmd_monitor_load');
Irssi::command_bind('monitor help', 'cmd_monitor_help');

cmd_monitor_load();
