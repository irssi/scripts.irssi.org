use strict;
use Irssi;
use Irssi::Irc;

use vars qw($VERSION %IRSSI);
$VERSION = "0.2";
%IRSSI = (
    authors     => 'Valentin Batz',
    contact     => 'senneth@irssi.org',
    name        => 'banaffects',
    description => 'shows affected nicks by a ban on a new ban',
    url		=> 'http://www.oberkommando.org/~senneth/irssi/scripts/',
    licence	=> 'GPLv2',
    revision    => '$LastChangedRevision: 369 $',
    changed     => '$LastChangedDate: 2006-01-31 22:35:03 +0100 (Di, 31 Jan 2006) $',
    version	=> $VERSION,
);

Irssi::theme_register([ 'ban_affects', '         %K-%r-%R-%n Ban {hilight $0} affects: {hilight $1-}']);

sub ban_new() {
	#print "@_";
	my ($chan, $ban) = @_;
	return unless $chan;
	my $server = $chan->{server};
	my $banmask = $ban->{ban};
	my $window = $server->window_find_item($chan->{name});
	my @matches;
	foreach my $nick ( sort ( $chan->nicks() ) ) {
		if (Irssi::mask_match_address( $banmask, $nick->{nick}, $nick->{host} )) {
			push (@matches, $nick->{nick});
		}
	}
	my $nicks = join(", ", @matches);
	$window->printformat(MSGLEVEL_CRAP, 'ban_affects', $banmask, $nicks) if ($nicks ne '');
}

Irssi::signal_add('ban new', \&ban_new);

sub test_ban() {
	my ($arg, $server, $witem) = @_;
	return unless (defined $witem && $witem->{type} eq 'CHANNEL');
	my $chan = $server->channel_find($witem->{name});
	my @matches;
	foreach my $nick ( sort ( $chan->nicks() ) ) {
		if (Irssi::mask_match_address( $arg, $nick->{nick}, $nick->{host} )) {
			push (@matches, $nick->{nick});
		}
	}
	my $nicks = join(", ", @matches);
	$witem->printformat(MSGLEVEL_CRAP, 'ban_affects', $arg, $nicks) if ($nicks ne '');
}


Irssi::command_bind('banaffects', \&test_ban);
