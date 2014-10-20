## Usage: /RELM [-l || index] [target]
## to list last 15 messages:
## /RELM -l
## to redirect msg #4, 7, 8, 9, 10, 13 to current channel/query:
## /RELM 4,7-10,13
## to redirect last message to current channel/query:
## /RELM

use strict;
use Irssi;

use vars qw($VERSION %IRSSI);
$VERSION = "1.0";
%IRSSI = (
        authors         => "Maciek \'fahren\' Freudenheim",
        contact         => "fahren\@bochnia.pl",
        name            => "REdirect Last Message",
        description     => "Keeps last 15 messages in cache",
        license         => "GNU GPLv2 or later",
        changed         => "Fri Mar 15 15:09:42 CET 2002"
);

my %relm;

sub cmd_relm {
	my ($args, $server, $winit) = @_;
	my $ircnet = lc($server->{tag});
	my ($which, $where) = split(/ +/, $args, 2);
	
	$where = $which unless $which =~ /[0-9]/;

	$which = scalar(@{$relm{lc($ircnet)}}) unless ($which);

	unless ($relm{$ircnet}) {
		Irssi::print("%R>>%n Nothing in relm buffer on $ircnet.", MSGLEVEL_CRAP);
		return;
	}

	if ($where eq "-l") {
		my $numspace;
		Irssi::print(">> ---- Context ------------------------", MSGLEVEL_CRAP);
		for (my $i = 0; $i < scalar(@{$relm{$ircnet}}); $i++) {
			$numspace = sprintf("%.2d", $i+1);
			Irssi::print("[%W$numspace%n] $relm{$ircnet}[$i]", MSGLEVEL_CRAP);
		}
		return;
	}

	unless ($where) {
		unless ($winit && ($winit->{type} eq "CHANNEL" || $winit->{type} eq "QUERY")) {
			Irssi::print("%R>>%n You have to join channel first", MSGLEVEL_CRAP);
			return;
		}
		$where = $winit->{name};
	}
	
	$which =~ s/,/ /g;
	my @nums;
	for my $num (split(/ /, $which)) {
		if ($num =~ /-/) {
			my ($start, $end) = $num =~ /([0-9]+)-([0-9]*)/;
			for (;$start <= $end; $start++) {
				push(@nums, $start - 1);
			}
		} else {
			push(@nums, $num - 1);
		}
	}
	
	for my $num (@nums) {
		unless ($relm{$ircnet}[$num]) {
			Irssi::print("%R>>%n No such message in relm buffer /" . ($num + 1). "/", MSGLEVEL_CRAP);
		} else {
			Irssi::active_server()->command("msg $where $relm{$ircnet}[$num]");
		}
	}
}

sub event_privmsg {
	my ($server, $data, $nick, $address) = @_;
	my ($target, $text) = split(/ :/, $data, 2);
	my $ircnet = lc($server->{tag});

	return if ($server->{nick} ne $target);
	my $relm = "\00312[ \00310$nick!$address \00312]\003 $text";
	shift(@{$relm{$ircnet}}) if scalar(@{$relm{$ircnet}}) > 14;
	push(@{$relm{$ircnet}}, $relm);
}

Irssi::command_bind("relm", "cmd_relm");
Irssi::signal_add("event privmsg", "event_privmsg");
