# rot13.pl
# Mariusz "Craig" Cie¶la <craig at fish.mac.edu.pl>
# ROT13-encodes and decodes messages on the channel :)

use strict;

use vars qw($VERSION %IRSSI);

$VERSION = "2003121202";

%IRSSI = (
	authors		=>	"Mariusz 'Craig' Ciesla",
	contact		=>	"craig\@fish.mac.edu.pl",
	name		=>	"rot13",
	description	=>	"ROT13 encoding and reverse :)",
	license		=>	"GPLv2",
	changed		=>	"$VERSION",
	commands	=>	"rot13 unrot13"
);

use Irssi 20020324;

sub text2rot ($)
{
	my ($text) = @_;

	$text =~ y/N-ZA-Mn-za-m/A-Za-z/;

	return $text."  ";
}

sub rot2text ($)
{
	my ($text) = @_;

	$text =~ y/A-Za-z/N-ZA-Mn-za-m/;

	return $text;
}

sub rot13_decode ($$$)
{
	my ($server, $target, $text) = @_;
	
	return unless ($text =~ /(^|.*?)  /g);
	my $witem = $server->window_item_find($target);

	return unless ($witem);
	$witem->print("%B[ROT13]>>%n ".rot2text($1), MSGLEVEL_CLIENTCRAP);
}

sub cmd_rot13 ($$$)
{
	my ($arg, $server, $witem) = @_;

	if ($witem && ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY'))
	{
		$witem->command('MSG '.$witem->{name}.' '.text2rot($arg));
	} else {
		print CLIENTCRAP "%B>>%n ".text2rot($arg);
	}
}

sub cmd_unrot13 ($$$)
{
	my ($arg, $server, $witem) = @_;
	
	print CLIENTCRAP "%B>>%n ".rot2text($arg);
}

Irssi::command_bind('rot13',\&cmd_rot13);
Irssi::command_bind('unrot13',\&cmd_unrot13);

Irssi::signal_add('message public',sub {rot13_decode($_[0], $_[4], $_[1]);} );
Irssi::signal_add('message own_public',sub {rot13_decode($_[0], $_[2], $_[1]);});

print "%B>>%n ".$IRSSI{name}." ".$VERSION." loaded";
