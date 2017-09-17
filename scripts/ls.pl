use strict;
use vars qw($VERSION %IRSSI);
use Irssi 20020120;
$VERSION = "0.02";
%IRSSI = (
    authors	=> "c0ffee",
    contact	=> "c0ffee\@penguin-breeder.org",
    name	=> "List nicks in channel",
    description	=> "Use /ls <regex> to show all nicks (including ident\@host) matching regex in the current channel",
    license	=> "Public Domain",
    url		=> "http://www.penguin-breeder.org/irssi/",
    changed	=> "Fri Sep 06 15:36 CEST 2002",
);


sub cmd_ls {
	my ($data, $server, $channel) = @_;

	if ($channel->{type} ne "CHANNEL") {
		Irssi::print("You are not on a channel");

		return;
	}

	my @nicks = $channel->nicks();

	my $re = eval { qr/$data/i };
	if (not $re) {
		chomp $@;
		$channel->print("Invalid regex pattern:\n$@");
		return;
	}

	foreach my $nick (@nicks) {
		my $n = $nick->{nick} . "!" . $nick->{host};

		$channel->print("$n") if $n =~ $re;
	}
}

Irssi::command_bind('ls','cmd_ls');
