# by Uwe 'duden' Dudenhoeffer
#
# chansync.pl


use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '0.1';
%IRSSI = (
    authors     => 'Uwe \'duden\' Dudenhoeffer',
    contact     => 'script@duden.eu.org',
    name        => 'chanfull',
    description => 'Notify if Channellimit is reached',
    license     => 'GPLv2',
    url         => '',
    changed     => 'Sat Feb  8 18:08:54 CET 2003',
);

# Changelog
#
# 0.1
#   - first working version

use Irssi;

sub event_message_join ($$$$) {
	my ($server, $channel, $nick, $address) = @_;
	my $c=Irssi::channel_find($channel);
	my $users=scalar @{[$c->nicks]};
	return if($c->{limit} == 0);
	my $left = $c->{limit} - $users;
	if($left < 3) {
		if($left<=0) {
			Irssi::printformat(MSGLEVEL_CRAP, 'chanfull_full', $channel);
		} else {
			Irssi::printformat(MSGLEVEL_CRAP, 'chanfull_left', $left, $channel);
		}
	}
}

Irssi::signal_add('message join', 'event_message_join');

Irssi::theme_register([
	'chanfull_left' => 'Only $0 client(s) left in {channel $1} till limit is reached',
	'chanfull_full' => '{channel $0} is full'
]);
