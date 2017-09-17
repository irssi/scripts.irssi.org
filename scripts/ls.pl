use strict;
use vars qw($VERSION %IRSSI);
use Irssi 20020120;
$VERSION = "0.03";
%IRSSI = (
    authors	=> "c0ffee",
    contact	=> "c0ffee\@penguin-breeder.org",
    name	=> "List nicks in channel",
    description	=> "Use /ls <regex> to show all nicks (including ident\@host) matching regex in the current channel",
    license	=> "Public Domain",
    url		=> "http://www.penguin-breeder.org/irssi/",
    changed	=> "Sun Sep 17 06:31 CEST 2017",
);


sub cmd_ls {
	my ($data, $server, $channel) = @_;

	if ($channel->{type} ne "CHANNEL") {
		Irssi::print("You are not on a channel");

		return;
	}

	$channel->print("--- Search results:");

	my @nicks = $channel->nicks();

	my $re = eval { qr/$data/i };
	if (not $re) {
		chomp $@;
		$channel->print("Invalid regex pattern:\n$@");
		return;
	}

	my $found;
	foreach my $nick (@nicks) {
		my $n = $nick->{nick} . "!" . $nick->{host};

		if ($n =~ $re) {
			$channel->print($n);
			$found = 1;
		}
	}

	if (not $found) {
		$channel->print("No matches");
	}
}

Irssi::command_bind('ls','cmd_ls');
