#!/usr/bin/perl
#
# Do you feel tired of typing /wii ick nick?
# Just try idletime.pl :)
# By Stefan "tommie" Tomanek (stefan@kann-nix.org)

use strict;
use Irssi;

use vars qw($VERSION %IRSSI);

$VERSION = "20030208";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "idletime",
    description => "Retrieves the idletime of any nick",
    license     => "GPLv2",
    url         => "",
    changed     => "$VERSION",
    commands    => "idle"
);



my %nicks;

sub cmd_idle {
    my ($nicks, $server) = @_;
    foreach (split(/\s+/, $nicks)) {
	push @{$nicks{$server->{chatnet}}}, $_;
	$server->command("whois ".$_." ".$_);
    }
}

sub event_server_event {
    my ($server, $text, $nick, $user) = @_;
    my @items = split(/ /,$text);
    my $type = $items[0];
    
    if ( ($type eq 301) or ($type eq "311") or ($type eq "312") or ($type eq "317") or ($type eq "318") or ($type eq "319") ) {
	my $name = $items[2];
	my $i = 0;
	if ( has_item($name,@{$nicks{$server->{chatnet}}}) ) {
	    Irssi::signal_stop();
	    print_idletime($name, $server, $items[3]) if ($type eq "317");
	    splice(@{$nicks{$server->{chatnet}}},$i,1) if ($type eq "318");
	    $i++;
	}
    }
}

sub has_item {
    my ($item, @list) = @_;
    foreach (@list) {
	$item == $_ && return(1);
    }
    return(0)
}

sub print_idletime {
    my ($name, $ircnet, $time) = @_;
    my $hours = int($time / 3600);
    my $minutes = int(($time % 3600)/60);
    my $seconds = int(($time % 3600)%60);
    $ircnet->print(undef,$name." is idle for ".$hours." hours, ".$minutes." minutes and ".$seconds." seconds.", MSGLEVEL_CRAP);
}

Irssi::command_bind('idle', 'cmd_idle');
Irssi::signal_add('server event', 'event_server_event');
