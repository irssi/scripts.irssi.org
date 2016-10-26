# Copyright 2001 by Maciek Freudenheim <fahren@bochnia.pl>
#  /thanks to elluin & lemur/
# Copyright 2002 by Marco d'Itri <md@linux.it>
#
# You can use this software under the terms of the GNU General Public License.

# ppl.pl for Irssi (port of asmodean's /ppl command from skuld3)
#
# Usage: /ppl [-o -v -i | -l] [-g | -h] [-p <n!u@h>] [-m <*ircserver*>]
#             [-N | -H | -M | -D]
#  To list ops | voices | normal | ircops
#  To list away / unaway people, and
#  To list people matching n!u@h or using server matching *ircserver*
#  Multiple options can be combined

use Irssi;
use POSIX qw(strftime);
use strict;

use vars qw($VERSION %IRSSI);

$VERSION = '20020128';
%IRSSI = (
	authors		=> 'Maciek Freudenheim, Marco d\'Itri',
	contact		=> 'fahren@bochnia.pl, md@linux.it',
	name		=> 'ppl',
	description	=> 'port of asmodean\'s /ppl command from skuld3',
	license		=> 'GPL v2',
	url			=> 'http://www.linux.it/~md/irssi/',
);

my $ServerRewrite = '\.openprojects\.net$';
my $At_Pos = 30;

Irssi::theme_register([
#	0 mode, 1 nick, 2 filler1, 3 user, 4 host, 5 filler2, 6 server, 7 hops
	'ppl_line'	=> '%W$0%n$1%K$2%n$3%B@%n$4%K$5%n$6%C$7%n',
	'ppl_end'	=> '%y>>%n $0 - matched %_$1%_ users '
				.  '(*=%_$2%_ -o=%_$3%_ +v=%_$4%_ +o=%_$5%_)'
]);

Irssi::command_bind('ppl' => 'cmd_ppl');
Irssi::signal_add('redir ppl_line'	=> 'red_ppl_line');
Irssi::signal_add('redir ppl_end'	=> 'red_ppl_end');

my @users;
my %ppl;

sub cmd_ppl {
	my ($pars, $server, $winit) = @_;

	if (not $winit or $winit->{type} ne 'CHANNEL') {
		Irssi::print('%R>>>%n You have to join channel first :\\',
			MSGLEVEL_CRAP);
		return;
	}

	$ppl{o} = $ppl{v} = $ppl{l} = $ppl{m} = $ppl{i} = 0;

	my $ppl = '';
	my @data = split(/ /, $pars);
	while ($_ = shift(@data)) {
		/^-N$/	and	$ppl{SORT} = 'nick', next;
		/^-H$/	and	$ppl{SORT} = 'host', next;
		/^-M$/	and	$ppl{SORT} = 'mode', next;
		/^-D$/	and	$ppl{SORT} = 'distance', next;
		/^-o$/	and $ppl{show_o} = 1, next;
		/^-i$/	and $ppl{show_i} = 1, next;
		/^-v$/	and $ppl{show_v} = 1, next;
		/^-l$/	and $ppl{show_l} = 1, next;
		/^-g$/	and $ppl{only_G} = 1, next;
		/^-h$/	and $ppl{only_H} = 1, next;
		/^-s$/	and $ppl{s} = shift(@data), next;
		/^-p$/	and $ppl{h} = shift(@data), next;
		Irssi::print("Unknown option: $_");
		return;
	}

	$ppl{show_o} = $ppl{show_i} = $ppl{show_v} = $ppl{show_l} = 1
		unless exists $ppl{show_o} or exists $ppl{show_i}
			or exists $ppl{show_v} or exists $ppl{show_l};

	$ppl{w} = Irssi::active_win()->{width};
	$ppl{c} = $winit->{name};

	if (Irssi::settings_get_bool('timestamps')) {
		my $ts_for = Irssi::settings_get_str('timestamp_format');
		$ppl{w} -= (length(strftime($ts_for, localtime)) + 1);
	}

	$server->redirect_event('who', 1, $ppl{c}, 0, undef, {
		'event 315' => 'redir ppl_end',
		'event 352' => 'redir ppl_line',
	});
	$server->send_raw("WHO :$ppl{c}");
}

sub red_ppl_line {
	my ($s, $data) = @_;

	my (undef, undef, $user, $host, $server, $nick, $mode, $hops)
		= split(/ /, $data);

	return if $mode =~ /^G/ and $ppl{only_H};
	return if $mode =~ /^H/ and $ppl{only_G};

	if ($ppl{h}) {
		return unless $s->mask_match($ppl{h}, $nick, $user, $host);
	}
	if ($ppl{s}) {
		return unless $server =~ /$ppl{s}/;
	}

	if ($mode =~ /\*/) {
		return unless $ppl{show_i};
		$ppl{i}++;
	}
	if ($mode =~ /@/) {
		return unless $ppl{show_o};
		$ppl{o}++;
	} elsif ($mode =~ /\+/) {
		return unless $ppl{show_v};
		$ppl{v}++;
	} else {
		return unless $ppl{show_l};
		$ppl{l}++;
	}
	$ppl{m}++;

	$mode = sprintf('%-2.2s', $mode);
	if (length($nick) + length($user) > $At_Pos - 4) {
		$user = substr($user, 0, 11);
		$nick = substr($nick, 0, $At_Pos - 4 - length $user);
	}
	$server =~ s/$ServerRewrite//o if $ServerRewrite;
	if (length($host) + length($server) > $ppl{w} - $At_Pos - 2) {
		$host = substr($host, 0, $ppl{w} - $At_Pos - 2);
		my $len = $ppl{w} - $At_Pos - 3 - length($host);
		$server = substr($server, 0, $len > 0 ? $len : 0);
	}
	my $filler1 = '.' x ($At_Pos - 3 - length($nick) - length($user));
	my $filler2 = '.' x ($ppl{w} - $At_Pos - 2
		- length($host) - length($server));
	$hops =~ s/^://;

	if ($ppl{SORT}) {
		push(@users,
			[$mode, $nick, $filler1, $user, $host, $filler2, $server, $hops]);
	} else {
		$s->printformat($ppl{c}, MSGLEVEL_CLIENTCRAP, 'ppl_line',
			$mode, $nick, $filler1, $user, $host, $filler2, $server, $hops);
	}
}

sub red_ppl_end {
	my ($server, $data) = @_;

	if ($ppl{SORT}) {
		if ($ppl{SORT} eq 'host') {
			@users = sort sort_domain @users;
		} elsif ($ppl{SORT} eq 'mode') {
			@users = sort sort_mode @users;
		} elsif ($ppl{SORT} eq 'nick') {
			@users = sort { lc $a->[1] cmp lc $b->[1] } @users;
		} elsif ($ppl{SORT} eq 'distance') {
			@users = sort { lc $a->[7] cmp lc $b->[7] } @users;
		}

		foreach (@users) {
			$server->printformat($ppl{c}, MSGLEVEL_CLIENTCRAP, 'ppl_line', @$_);
		}
		undef @users;
	}
	$server->printformat($ppl{c}, MSGLEVEL_CLIENTCRAP, 'ppl_end',
		$ppl{c}, $ppl{m}, $ppl{i}, $ppl{l}, $ppl{v}, $ppl{o});
	undef %ppl;
}

sub sort_domain {
	my @doma = split(/\./, lc $a->[4]);
	my @domb = split(/\./, lc $b->[4]);

	# sort IP addresses
	if ($doma[$#doma] =~ /^\d+$/ and $domb[$#domb] =~ /^\d+$/) {
		return $doma[0] <=> $domb[0] || $doma[1] <=> $domb[1]
			|| $doma[2] <=> $domb[2] || $doma[3] <=> $domb[3];
	}

		$doma[$#doma] cmp $domb[$#domb]
					||
	$doma[$#doma - 1] cmp $domb[$#domb - 1]
					||
	$doma[$#doma - 2] cmp $domb[$#domb - 2]
}

sub sort_mode {
	return; # FIXME unfinished
	my ($sa, $ma) = split(//, $a->[0]);
	my ($sb, $mb) = split(//, $b->[0]);

#	Irssi::print("=== <$sa> <$ma>");

#	if ($sa eq $sb) {
#		return ?
#	}
	return -1 if $sa eq 'G';
	return 1 if $sb eq 'G';
}

# vim: set tabstop=4
