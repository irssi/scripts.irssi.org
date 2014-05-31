use strict;
use Irssi 20021028;
use vars qw($VERSION %IRSSI);

# Usage:
# To add the host by a kick, for example, use:
#     /format kick {channick $0} {chanhost $host{$0}} was kicked from {channel $1} by {nick $2} {reason $3}
#
# Result:
#     19:23:42 -!- Nick [user@leet.hostname.org] was kicked from #channel by MyNick [leet reason]



$VERSION = "0.2";
%IRSSI = (
	authors         => "Michiel v Vaardegem",
	contact         => "michielv\@zeelandnet.nl",
	name            => "showhost",
	description     => "show host kicks",
	license         => "GPL",
	changed         => "Mon Dec  8 19:23:51 CET 2003"
);

my $lasthost;

sub setlast
{
	my ($server, $channelname, $nickname) = @_;
	my @channels;
	$lasthost = {};
	if (defined($channelname))
	{
		$channels[0] = $server->channel_find($channelname);
		if (!defined($channels[0]))
		{
			return;
		}
	}
	else
	{
		@channels = $server->channels();
	}

	foreach my $channel (@channels)
	{
		my $nick = $channel->nick_find($nickname);
		if (defined($nick))
		{
			$lasthost->{$channel->{'name'}} = $nick->{host};
		}
	}
}

sub expando_mode
{
	my ($server,$item,$mode2) = @_;
	if (!defined($item) || $item->{'type'} ne 'CHANNEL' )
	{
		return '';
	}
	return $lasthost->{$item->{'name'}};
}


Irssi::signal_add_first('message kick', sub {setlast($_[0],$_[1],$_[2]); });

Irssi::expando_create('host', sub {expando_mode($_[0],$_[1],0)},{ 'message part' => 'None'});

