#!/usr/bin/perl -w
# joins channel with non-utf8 non-ascii names
#   by c0ffee
#     - http://penguin-breeder.org/irssi/

#<scriptinfo>
use strict;
use vars qw($VERSION %IRSSI);

use Irssi 20020120;
$VERSION="0.2";
%IRSSI = (
     authors	=> "c0ffee",
     contact	=> "c0ffee\@penguin-breeder.org",
     name	=> "i18n /join",
     description=> "Joins channels with non-utf8 non-ascii names.",
     license	=> "Public Domain",
     url	=> "http://www.penguin-breeder.org/irssi/",
     changed	=> "Sun Sep 21 12:22:24 CEST 2008",
);
#</scriptinfo>


use Text::Iconv;

sub cmd_join18n {
	my ($data, $server, $channel) = @_;

	if (!$server || !$server->{connected}) {
		Irssi::print("Not connected to a server");
		return;
	}

	if (!$data) {
		Irssi::print("No channel given");
		return;
	}

	my $enc = Irssi::settings_get_str("join18n_encoding");

	$enc = $1 if $data =~ /^\s*-enc\s+(\S+)/;
	$data =~ s/^\s*-enc\s+(\S+)//;

	my $converter = Text::Iconv->new("UTF-8", $enc);
	
	if (!$converter) {
		Irssi::print("Invalid encoding specified: $enc");
		return;
	}

	$server->send_raw("JOIN " . $converter->convert($data));
}

sub cmd_msg18n {
	my ($data, $server, $channel) = @_;

	if (!$server || !$server->{connected}) {
		Irssi::print("Not connected to a server");
		return;
	}

	if (!$channel) {
		Irssi::print("Not in a channel");
		return;
	}

	my $name = $channel->{name};

	my $enc = Irssi::settings_get_str("join18n_encoding");

	$enc = $1 if $data =~ /^\s*-enc\s+(\S+)/;
	$data =~ s/^\s*-enc\s+(\S+)//;

	my $converter = Text::Iconv->new("UTF-8", $enc);
	
	if (!$converter) {
		Irssi::print("Invalid encoding specified: $enc");
		return;
	}

	Irssi::signal_emit("message own_public", $server, $data, $name);
	$server->send_raw("PRIVMSG " . $converter->convert($name) . " :" . $converter->convert($data));
}

sub cmd_part18n {
	my ($data, $server, $channel) = @_;

	if (!$server || !$server->{connected}) {
		Irssi::print("Not connected to a server");
		return;
	}

	if (!$channel) {
		Irssi::print("Not in a channel");
		return;
	}

	my $name = $channel->{name};

	my $enc = Irssi::settings_get_str("join18n_encoding");

	$enc = $1 if $data =~ /^\s*-enc\s+(\S+)/;
	$data =~ s/^\s*-enc\s+(\S+)//;

	my $converter = Text::Iconv->new("UTF-8", $enc);
	
	if (!$converter) {
		Irssi::print("Invalid encoding specified: $enc");
		return;
	}

	$server->send_raw("PART " . $converter->convert($name) . ($data ? " :" . $converter->convert($data) : ""));
}

Irssi::settings_add_str("misc", "join18n_encoding", "latin1");
Irssi::command_bind("join18n", "cmd_join18n");
Irssi::command_bind("msg18n", "cmd_msg18n");
Irssi::command_bind("part18n", "cmd_part18n");

