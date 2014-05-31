use Irssi 20020300;
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "1.1";
%IRSSI = (
        authors         => "Maciek \'fahren\' Freudenheim",
        contact         => "fahren\@bochnia.pl",
        name            => "Topic Lock",
        description     => "/TLOCK [-d] [channel] [topic] - locks current or specified topic on [channel]",
        license         => "GNU GPLv2 or later",
        changed         => "Fri Mar 15 15:09:42 CET 2002"
);

my %tlock = ();

sub cmd_tlock {
	my ($args, $server, $win) = @_;

	my $tag = $server->{tag};
	my $delete = ($args =~ s/^-d\s//)? 1 : 0;
	my ($chan) = $args =~ /^([^\s]+)/;

	unless ($chan) {
		my $i = 0;
		for my $ch (keys %{$tlock{$tag}}) {
			if ($tlock{$tag}{$ch}) {
				$i = 1;
				Irssi::print("Lock on $tag%W/%n$ch%W:%n $tlock{$tag}{$ch}");
			}
		}
		Irssi::print("%R>>%n You dont have any active topic locks at this moment.") unless $i;
		return;
	}

	$chan = lc($chan);
	if ($delete) {
		Irssi::print("%W>>%n topic lock on $chan removed") if $tlock{$tag}{$chan};
		undef $tlock{$tag}{$chan};
		return;
	} 

	my $channel = $server->channel_find($chan);
	unless ($channel && $channel->{chanop}) {
		Irssi::print("%R>>%n You are not channel operator/not on channel on $chan.");
		return;
	}

	$args =~ s/^$chan\s?//;
	my $topic = ($args)? $args : $channel->{topic};

	if ($tlock{$tag}{$chan}) {
		Irssi::print("Changed tlock on $chan to%W:%n $topic");
	} else {
		Irssi::print("Set tlock on $chan to%W:%n $topic");
	}

	$server->send_raw("TOPIC $chan :$topic") if $channel->{topic} ne $topic;

	$tlock{$tag}{$chan} = $topic;	
	
}

sub sub_tlock {
	# "event "<cmd>, SERVER_REC, char *args, char *sender_nick, char *sender_address
	my ($server, $args, $nick, $uh) = @_;

	return if $server->{nick} eq $nick;
	my ($chan, $topic) = split(/ :/, $args);
	return unless $server->channel_find($chan)->{chanop};
	$chan = lc($chan);
	my $tag = $server->{tag};
	
	if ($tlock{$tag}{$chan} && $topic ne $tlock{$tag}{$chan}) {
		Irssi::print("%W>>%n tlock: changing topic back on $chan");
		$server->send_raw("TOPIC $chan :$tlock{$tag}{$chan}");
	}
}

Irssi::signal_add('event topic', 'sub_tlock');
Irssi::command_bind('tlock', 'cmd_tlock');
