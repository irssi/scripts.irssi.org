use Irssi;
use strict;

use vars qw($VERSION %IRSSI);

$VERSION = "0.1";
%IRSSI = (
    authors     => 'BC-bd',
    contact     => 'bd@bc-bd.org',
    name        => 'ircops',
    description => '/IRCOPS - Display IrcOps in current channel',
    license     => 'GPL v2',
    url         => 'https://bc-bd.org/svn/repos/irssi/trunk/',
);

sub cmd_ircops {
	my ($data, $server, $channel) = @_;

	my (@list,$text,$num);

	if (!$channel || $channel->{type} ne 'CHANNEL') {
		Irssi::print('No active channel in window');
		return;
	}

	foreach my $nick ($channel->nicks()) {
		if ($nick->{serverop}) {
			push(@list,$nick->{nick});
		}
	}

	$num = scalar @list;

	if ($num == 0) {
		$text = "no IrcOps on this channel";
	} else {
		$text = "IrcOps (".$num."): ".join(" ",@list);
	}

	$channel->print($text);
}

Irssi::command_bind('ircops', 'cmd_ircops');

