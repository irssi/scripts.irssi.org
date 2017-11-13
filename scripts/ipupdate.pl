# IPupdate 1.2
# 
# automatically update your IP on server connections
# 
# original create by legion (a.lepore@email.it)
#
# thanks xergio for IP show php script :>
#
# Fixed by Axel Gembe <derago@gmail.com> to use ifconfig.co/ip
# because the original server did not work anymore.

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
require LWP::UserAgent;
use HTTP::Request::Common;

$VERSION = '1.3';
%IRSSI = (
		authors         => 'xlony, Axel Gembe',
		contact         => 'anderfdez@yahoo.es',
		name            => 'IPupdate',
		description     => 'Auto "/set dcc_own_ip IP" on connect.',
		license         => 'GPL',
		changed         => '2017-11-08',
);

sub ipset {
	my $user = LWP::UserAgent->new(timeout => 30);
	my $get = GET "http://ifconfig.co/ip";
	my $req = $user->request($get);
	my $out = $req->content();

	Irssi::print("%9IP update%_:", MSGLEVEL_CRAP);
	Irssi::command("set dcc_own_ip $out");
}

Irssi::signal_add('server connected', 'ipset');
Irssi::command_bind('ipupdate', 'ipset');
