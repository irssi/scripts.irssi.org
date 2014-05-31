# Swap between green and white format for public messages. I think this
# helps readability. Assumes you haven't changed message formats.
# for irssi 0.7.98 by Timo Sirainen

use Irssi;
use strict;
use vars qw($VERSION %IRSSI); 
$VERSION = "0.1";
%IRSSI = (
    authors	=> "Timo \'cras\' Sirainen",
    contact	=> "tss\@iki.fi",
    name	=> "colorswap",
    description	=> "Swap between green and white format for public messages. I think this helps readability. Assumes you haven't changed message formats.",
    license	=> "Public Domain",
    url		=> "http://irssi.org/",
    changed	=> "2002-03-04T22:47+0100"
);

my %setnext = {};

sub change_formats {
	my $target = lc shift;

	if ($setnext{$target}) {
		Irssi::command('^format own_msg {ownmsgnick %G$2 {ownnick %G$0}}%g$1');
		Irssi::command('^format pubmsg {pubmsgnick %g$2 {pubnick %g$0}}%g$1');
	} else {
		Irssi::command('^format -reset own_msg');
		Irssi::command('^format -reset pubmsg');
	}
	$setnext{$target} = !$setnext{$target};
}

sub sig_public {
	my ($server, $msg, $nick, $address, $target) = @_;

	change_formats($server->{tag}."/".$target);
}

sub sig_own_public {
	my ($server, $msg, $target) = @_;

	change_formats($server->{tag}."/".$target);
}

Irssi::signal_add('message public', 'sig_public');
Irssi::signal_add('message own_public', 'sig_own_public');
