# prints "Query started with nick in window x" when query windows are
# created automatically. For irssi 0.7.98

# 21.08.2001 bd@bc-bd.org :: added automatic whois

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION="0.1.1";
%IRSSI = (
	authors=> 'unknown',
	contact=> 'bd@bc-bd.org',
	name=> 'noisyquery',
	description=> 'Prints an info about a newly started Query in your current window and runs a /whois on the nick.',
	license=> 'GPL v2',
	url=> 'http://bc-bd.org/software.php3#irssi',
);

sub sig_query() {
	my ($query, $auto) = @_;

	# don't say anything if we did /query,
	# or if query went to active window
	my $refnum = $query->window()->{refnum};
	my $window = Irssi::active_win();
	if ($auto && $refnum != $window->{refnum}) {
		$window->print("Query started with ".$query->{name}." in window $refnum");
		$query->{server}->command("whois ".$query->{name});
	}
}

Irssi::signal_add_last('query created', 'sig_query');
