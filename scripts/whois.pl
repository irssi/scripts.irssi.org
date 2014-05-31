# whois.pl/Irssi/fahren@bochnia.pl

use Irssi;
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "1.0";
%IRSSI = (
        authors         => "Maciek \'fahren\' Freudenheim",
        contact         => "fahren\@bochnia.pl",
        name            => "cwhois",
        description     => "Hilights \'@\' in whois channel reply",
        license         => "GNU GPLv2 or later",
        changed         => "Fri Mar 15 15:09:42 CET 2002"
);

Irssi::theme_register([
  'cwhois_channels', '{whois channels %|$1}'
]);
  
sub event_cwhois
{
	my ($server, $data) = @_;

	my ($nick, $chans) = $data =~ /([\S]+)\s:(.*)/;

	my $ret;
	foreach my $chan (split(/ /, $chans)) {
		$ret .= (($chan =~ s/^@//)? "\00316@\003" : "") . $chan . " ";
	}

 	chop $ret;
	$server->printformat($nick, MSGLEVEL_CRAP, 'cwhois_channels', $nick, $ret);
    
	Irssi::signal_stop();
}

Irssi::signal_add('event 319', 'event_cwhois');
