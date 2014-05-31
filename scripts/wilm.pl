# wilm.pl
# Lam 28.10.2001, 10.3.2002
# lam@lac.pl

use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "1.0.1";
%IRSSI = (
	authors => "Leszek Matok",
	contact => "lam\@lac.pl",
	name => "wilm",
	description => "Provides /wilm and /wiilm commands, which do a whois on a person who sent you last private message",
	license => "Public Domain",
	changed => "10.3.2002 14:00"
);

my $last_nick;
my $last_server;

sub wilm {
	my @all_servers = Irssi::servers();
	foreach my $one_server ( @all_servers ) {
		if ( $one_server = $last_server ) {
			$one_server->command( "whois $last_nick" );
			return;
		}
	}
	Irssi::print( "noone to whois" );
}

sub wiilm {
	my @all_servers = Irssi::servers();
	foreach my $one_server ( @all_servers ) {
		if ( $one_server = $last_server ) {
			$one_server->command( "whois $last_nick $last_nick" );
			return;
		}
	}
	Irssi::print( "noone to whois" );
}

sub privmsg {
	my ( $server, $data, $nick, $address ) = @_;
	my ( $target, $text ) = split( / :/, $data, 2 );

	if ( ( lc $target ) eq ( lc $server->{ nick } ) ) {
		$last_nick = $nick;
		$last_server = $server;
	}
}

Irssi::command_bind( "wilm", "wilm" );
Irssi::command_bind( "wiilm", "wiilm" );
Irssi::signal_add( "event privmsg", "privmsg" );
