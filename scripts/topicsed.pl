#
# Topicsed edits channel topics by perl regexps via the command /topicsed.
#
# Thanks to Mikael Magnusson for the idea and patch to implement a
# preview functionality. ;]
#

use Irssi;

use vars %IRSSI;
%IRSSI = (
	authors		=> "Gabor Nyeki",
	contact		=> "bigmac\@vim.hu",
	name		=> "topicsed",
	description	=> "editing channel topics by regexps",
	license		=> "public domain",
	changed		=> "Fri Aug 13 19:27:38 CEST 2004"
);


sub topicsed {
	my ($regexp, $server, $winit) = @_;

	my $preview = 0;
	if ($regexp =~ m/^-p(review|) ?/) {
		$preview = 1;
		$regexp =~ s/^-p\w* ?//;
	}

	unless ($regexp) {
		Irssi::print("Usage: /topicsed [-p[review]] <regexp>");
		return;
	}
	return if (!$server || !$server->{connected} ||
		!$winit || $winit->{type} != 'CHANNEL');

	my $topic = $winit->{topic};
	my $x = $topic;

	unless (eval "\$x =~ $regexp") {
		Irssi::print("topicsed:error: An error occured with your regexp.");
		return;
	}

	if ($x eq $topic) {
		Irssi::print("topicsed:error: The topic wouldn't be changed.");
		return;
	} elsif ($x eq "") {
		Irssi::print("topicsed:error: Edited topic is empty;  try '/topic -delete' instead.");
		return;
	}

	if ($preview) {
		Irssi::print("topicsed: Edited topic for $winit->{name}: $x");
	} else {
		$server->send_raw("TOPIC $winit->{name} :$x");
	}
}

Irssi::command_bind('topicsed', 'topicsed');
