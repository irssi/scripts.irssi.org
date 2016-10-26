# IPupdate 1.2
# 
# automatically update your IP on server connections
# 
# original create by legion (a.lepore@email.it)
#
# thanks xergio for IP show php script :>

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
require LWP::UserAgent;
use HTTP::Request::Common;

$VERSION = '1.2';
%IRSSI = (
		authors         => 'xlony',
		contact         => 'anderfdez@yahoo.es',
		name            => 'IPupdate',
		description     => 'Auto "/set dcc_own_ip IP" on connect.',
		license         => 'GPL',
		changed         => 'Tue Jan  3 18:33:56 CET 2006',
);

sub ipset {
	my $user = LWP::UserAgent->new(timeout => 30);
	my $get = GET "http://stuff.xergio.net/ip.php";
	my $req = $user->request($get);
	my $out = $req->content();
	$out =~ s/.*IP real: ([0-9][0-9]?[0-9]?\.[0-9][0-9]?[0-9]?\.[0-9][0-9]?[0-9]?\.[0-9][0-9]?[0-9]?).*/$1/s;

	Irssi::print("%9IP update%_:", MSGLEVEL_CRAP);
	Irssi::command("set dcc_own_ip $out");
}

Irssi::signal_add('server connected', 'ipset');
Irssi::command_bind('ipupdate', 'ipset');
