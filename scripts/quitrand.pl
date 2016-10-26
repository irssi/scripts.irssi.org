# If quit message isn't given, quit with a random message
# read from ~/.irssi/irssi.quit

use Irssi;
use Irssi::Irc;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "1.00";
%IRSSI = (
    authors     => 'Fernando J. Pereda',
    contact	=> 'ferdy@ferdyx.org',
    name        => 'quitrand',
    description => 'Random quit messages - based on quitmsg (Timo Sirainen)',
    license     => 'GPLv2',
);

my $quitfile = glob "~/.irssi/irssi.quit";

sub cmd_quit {
	my ($data, $server, $channel) = @_;
	
	open(f,"<",$quitfile);
	my @contenido = <f>;
	close(f);

	my $numlines = 0;
	
	foreach my $nada (@contenido) {
		$numlines++;
	}

	my $line = int(rand($numlines))+1;

	my $quitmsg = "[IRSSI] ".$contenido[$line];

	chop($quitmsg);

	print($quitmsg);

	foreach my $sv (Irssi::servers()) {
		foreach my $item ($sv->channels()) {
			$item->command("PART ".$item->{name}." $quitmsg");
		}
	}
	
	foreach my $svr (Irssi::servers()) {
		$svr->command("DISCONNECT ".$svr->{tag}." $quitmsg");
	}
}

Irssi::command_bind('quit', 'cmd_quit');
