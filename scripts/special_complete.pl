use strict;
use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '1.1';
%IRSSI = (
	authors  	=> 'Wouter Coekaerts',
	contact  	=> 'wouter@coekaerts.be, coekie@#irssi',
	name    	=> 'special_complete',
	description 	=> '(tab)complete irssi special variables (words that start with $) by evaluating them',
	license 	=> 'GPLv2',
	url     	=> 'http://wouter.coekaerts.be/irssi/',
	changed  	=> '28/07/03',
);

Irssi::signal_add_last 'complete word', sub {
	my ($complist, $window, $word, $linestart, $want_space) = @_;
	if ($word =~ /^\$/){
		my $evaluated;
		if (Irssi::active_win->{'active'}) {
			$evaluated = Irssi::active_win->{'active'}->parse_special($word);
		} elsif (Irssi::active_win->{'active_server'}) {
			$evaluated = Irssi::active_win->{'active_server'}->parse_special($word);
		} else {
			$evaluated = Irssi::parse_special($word);
		}
		if ($evaluated ne '') {
			push @$complist, $evaluated;
		}
	}
};
