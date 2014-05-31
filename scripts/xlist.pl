#!/usr/bin/perl

# (c) Matthäus 'JonnyBG' Wander <jbg@swznet.de>

# Usage: Simply use /list as you always do

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '1.00';
%IRSSI = (
    authors => 'Matthäus \'JonnyBG\' Wander',
    contact => 'jbg@swznet.de',
    name => 'xlist',
    description => 'Better readable listing of channel names',
    license => 'GPLv2',
    url => 'http://jbg.swznet.de/xlist/',
);

use Irssi;

my %xlist = ();

sub collect {
    my ($server, $data) = @_;
    
    my (undef, $channel, $users, $topic) = split(/\s/, $data, 4);
    $topic = substr($topic, 1);
    
    $xlist{$channel} = [ $users, $topic ];
}

sub list {
    my ($data, $server) = @_;
    %xlist = ();
    
    print "%K[%n".$server->{'tag'}."%K]%n %B<-->%n xlist";
}

sub show {
    my ($server) = @_;
    my ($printstring, $channel);

    for $channel ( sort { ${ $xlist{$b} }[0] <=> ${ $xlist{$a} }[0] } keys %xlist ) {
	$printstring =	"%K[%n" . $server->{'tag'} . "%K]%n " .
			sprintf("%4d", ${ $xlist{$channel} }[0]) .
			" " . $channel;

	if (length ${ $xlist{$channel} }[1] > 0 ) {
	    $printstring .= " %B->%n ". ${ $xlist{$channel} }[1];
	}

	print $printstring;
    }
    
    %xlist = ();
    
    print "%K[%n".$server->{'tag'}."%K]%n %B<-->%n End of xlist";
}

Irssi::command_bind('list', \&list);
Irssi::signal_add('event 322', \&collect);
Irssi::signal_add('event 323', \&show);

print "%B<-->%n xlist v$VERSION: Simply use /list as you always do";
