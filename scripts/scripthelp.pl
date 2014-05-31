use Irssi;

use vars qw($VERSION %IRSSI %HELP);
$VERSION = "0.9";
%IRSSI = (
	authors         => "Maciek \'fahren\' Freudenheim",
	contact         => "fahren\@bochnia.pl",
	name            => "Scripts help",
	description     => "Provides access to script\'s help",
	license         => "GNU GPLv2 or later",
	changed         => "Sat Apr 13 02:23:37 CEST 2002"
);
$HELP{scripthelp} = "
Provides help for irssi's perl scripts.

All what you have to do is to add
\$HELP{commandname} = \"
    your help goes here
\";
to your script.
";

sub cmd_help {
	my ($args, $server, $win) = @_;

	# from scriptinfo.pl
	for (sort grep s/::$//, keys %Irssi::Script::) {
		my $help = ${ "Irssi::Script::${_}::HELP" }{$args};
		if ($help) {
			Irssi::signal_stop();
			Irssi::print("$help");
			return;
		}
	}		
}

Irssi::command_bind("help", "cmd_help");
