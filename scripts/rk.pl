# rk.pl/Irssi/fahren@bochnia.pl

use Irssi 20020300;
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "0.9";
%IRSSI = (
        authors         => "Maciek \'fahren\' Freudenheim",
        contact         => "fahren\@bochnia.pl",
        name            => "Random kicker",
        description     => "/RK [-o | -l | -a] - kicks random nick from ops | lusers | all on channel",
        license         => "GNU GPLv2 or later",
        changed         => "Fri Mar 15 15:09:42 CET 2002"
);

sub cmd_rk {
	my ($args, $server, $chan) = @_;

	unless ($chan && $chan->{type} eq "CHANNEL" && $chan->{chanop}) {
		Irssi::print("%R>>%n You aren't opped / You don't have active channel :/");	
		return;
	}

	my @data = split(/ /, $args);
	my ($rk, @nicks);
	$rk = 0;

	while ($_ = shift(@data)) {
		/^-a$/ and $rk = 2, next;
		/^-o$/ and $rk = 1, next;
		/^-l$/ and $rk = 0, next;
	}

	my $channel = $chan->{name};
	
	for my $hash ($chan->nicks()) {
		unless ($rk) {
			next if $hash->{op};	
		} elsif ($rk eq 1 && !$hash->{op}) {next};

		next if ($hash->{nick} eq $server->{nick});

		push @nicks, $hash;	
	}

	my $nnum = scalar(@nicks);
	my $victim = $nicks[rand($nnum)]->{nick};
	
	$server->send_raw("KICK $channel $victim :\002Random Kick\002");
}

Irssi::command_bind('rk', 'cmd_rk');
