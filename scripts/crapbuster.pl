
# By Stefan 'tommie' Tomanek
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "2003020801";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "CRAPbuster",
    description => "Removes CRAP or CLIENTCRAP messages from your buffer",
    license     => "GPLv2",
    changed     => "$VERSION",
    commands	=> "crapbuster"
);

use Irssi;
use Irssi::TextUI;

sub cmd_crapbuster ($$$) {
    my ($args, $server, $witem) = @_;
    my $limit = $args =~ /^\d+$/ ? $args : -1;
    my $win = ref $witem ? $witem->window() : Irssi::active_win();
    my $view = $win->view;
    my $line = $view->get_lines;
    $line = $line->next while defined $line->next;
    while (defined $line->prev){
	last if $limit == 0;
	my $level = $line->{info}{level};
	my $copy = $line;
	$line = $line->prev;
	foreach (split / /, Irssi::settings_get_str('crapbuster_levels')) {
	    next unless ($level == Irssi::level2bits($_));
	    $view->remove_line($copy);
	    last;
	}
	$limit-- if $limit;
    }
    $view->redraw();
}

Irssi::command_bind('crapbuster', \&cmd_crapbuster);
Irssi::settings_add_str($IRSSI{name}, 'crapbuster_levels', 'CLIENTCRAP CRAP');
