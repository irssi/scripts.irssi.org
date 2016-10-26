#!/usr/bin/perl

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "2003011700";
%IRSSI = (
    authors     => "Joern 'Wulf' Heissler",
    contact     => "wulf\@wulf.eu.org",
    name        => "chanfull",
    description => "Notifies the user when some channel limit is reached",
    license     => "GPLv2",
    url         => "",
    changed     => "$VERSION"
);

use Irssi;

# draws a nice box, author is Stefan 'tommie' Tomanek
sub draw_box ($$$) {
    my ($title, $text, $footer) = @_;
    my $box = ''; 
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {
        $box .= '%R|%n '.$_."\n";
    }
    $box .= '%R`--<%n'.$footer.'%R>->%n';
    return $box; 
}

sub event_message_join ($$$$) {
	my ($server, $channel, $nick, $address) = @_;
	my $c=Irssi::channel_find($channel);
	my $users=scalar @{[$c->nicks]};
	return if($c->{limit} == 0);
	my $left = $c->{limit} - $users;
	if($left < 4) {
		if($left<=0) {
			$c->print(draw_box('warning', 'Channel is full!!', 'chanfull'), MSGLEVEL_CLIENTCRAP);
		} else {
			$c->print(draw_box('warning', 'Channel is nearly full! ('.$left.' client'.(($left==1)?'':'s').' left)', 'chanfull'), MSGLEVEL_CLIENTCRAP);
		}
	}
}

Irssi::signal_add('message join', 'event_message_join');

Irssi::print '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded.', MSGLEVEL_CLIENTCRAP;
