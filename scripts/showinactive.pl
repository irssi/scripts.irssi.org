
# This script replaces the following three scripts:
#
# hilightwin, noisyquery, showhilight
#
# It makes the following changes/improvements
# - The text which is shown in your active irssi window is cleaned up after a window change
# - The hilightwin now has the window number so you can see which window had the original info
# - Also privates are shown in current window.
#
# Don't forget to create a window named hilight for the hilightwin functionality!
#
use strict;
use Irssi;
use Irssi::TextUI;

use vars qw($VERSION %IRSSI); 

$VERSION = "1.0";

%IRSSI = (
	authors         => "Peter 'kinlo' Leurs",
	contact         => "peter\@pfoe.be",
	name            => "showinactive",
	description     => "Show whatever needs your attention in active window, and cleans your windows afterwards.  Also provides a hilight window.  This is a combination of the hilightwin, noisyquery and showhilight scripts",
	license         => "GNU GPLv2",
	changed         => "Tue 12 Jul 2016 22:40:40  CEST"
);


# First create a function to write self-erasing/hilightwin text + a cleanup function that is hooked to window changes
my $bookmark_id=0;
sub print_inactive {
	my ($text, $window_from) = @_;
#        $text =~ s/%/%%/g;


	my $window_active = Irssi::active_win();
	my $window_hilight = Irssi::window_find_name('hilight');

	my $showinactive = 1;
	my $showinhilight = 0;

	if ($window_hilight) {
		$showinhilight = 1;
		if ($window_hilight->{refnum} == $window_active->{refnum}) {
			$showinactive = 0;
		}
	}

	# anti flood this window protection
	if ($bookmark_id > 100) {
		$showinactive = 0;
	}

	if ($window_from->{refnum} == $window_active->{refnum}) {
		$showinactive = 0;
	}

	if ($showinactive) {
		$window_active->print("%Y>>>%w ".$text, MSGLEVEL_CLIENTCRAP);
		$window_active->view()->set_bookmark_bottom("showinactive_$bookmark_id");
		$bookmark_id++;
	}

	if ($showinhilight) {
		$window_hilight->print($text, MSGLEVEL_CLIENTCRAP);
	}
}

sub sig_window_changed {
	my (undef, $oldwindow) = @_;
	if ($oldwindow) {
		for(my $i=0; $i<$bookmark_id; $i++) {
			my $line = $oldwindow->view()->get_bookmark("showinactive_$i");
			$oldwindow->view()->remove_line($line) if defined $line;
		}
		$bookmark_id=0;
	}
}
Irssi::signal_add('window changed', 'sig_window_changed');

# Now that we have self-erasing functionality:
# implement noisyquery:

sub sig_query_created() {
	my ($query, $auto) = @_;

	my $refnum = $query->window()->{refnum};
	if ($auto) {
		print_inactive("Query started with ".$query->{name}." in window $refnum", $query->window());
		$query->{server}->command("whois ".$query->{name});
	}
}

Irssi::signal_add_last('query created', 'sig_query_created');

# and implement hilightwin/showhilight
sub sig_printtext {
	my ($dest, $text, $stripped) = @_;

	# Sanitize input
	$text =~ s/%/%%/g;
	if (($dest->{level} & (MSGLEVEL_HILIGHT|MSGLEVEL_MSGS))  && (($dest->{level} & MSGLEVEL_NOHILIGHT) == 0)) {
		$text = $dest->{target}.":%K[%w".$dest->{window}->{refnum}."%K]:".$text;
		print_inactive($text, $dest->{window});
	}
}

Irssi::signal_add('print text', 'sig_printtext');



