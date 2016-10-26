use Irssi 20020300;
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "1.0";
%IRSSI = (
        authors         => "Maciek \'fahren\' Freudenheim",
        contact         => "fahren\@bochnia.pl",
        name            => "opnotify",
        description     => "Hilights window refnumber in statusbar if someone ops/deops you on channel",
        license         => "GNU GPLv2 or later",
        changed         => "Fri Mar 15 15:09:42 CET 2002"
);

sub event_modechange {
	my ($server, $data, $nick) = @_;                                                                                                      
	my ($channel, $mode, $rest) = split(/ /, $data, 3);
	my $win = Irssi::active_win();
	my $winchan = $server->window_find_item($channel);

	return if $win->{refnum} == $winchan->{refnum};

	my @rest = split(/ +/, $rest);

	# l4m3 but speeds-up
	return unless grep {/^$server->{nick}$/} @rest;

	my $par = undef;
	my $ind = 0;
	my $op = $winchan->{active}->{chanop};
	my $gotop = $op;
	
	for my $c (split(//, $mode)) {
		if ($c =~ /[+-]/) {
			$par = $c;
		} elsif ($c eq "o") {
			$gotop = ($par eq "+"? 1 : 0) if $rest[$ind++] eq $server->{nick};
		} elsif ($c =~ /[vbkeIqhdO]/ || ($c eq "l" && $par eq "+")) {
			$ind++;
		}
	}	

	$winchan->activity(4) unless $gotop == $op;
#	Irssi::print("%R>>%n $nick " . (($gotop)? "opped" : "deopped") . " You on %_$channel%_ /" . $server->{tag} . "/") unless $gotop == $op;
}

Irssi::signal_add("event mode", "event_modechange");                                                                                     
