use Irssi;
use strict;
use vars qw($VERSION %IRSSI);
$VERSION = '0.69';

%IRSSI = (
	authors		=> 'Jonne Piittinen',
	contact		=> 'jip@loota.org',
	name		=> 'Smiley',
	description	=> 'Very useful smiley-flooder',
	license		=> 'Public Domain',
);

print "<--------[------------------------------]-------->";
print "<--------[    smiley-script v. $VERSION.    ]-------->";
print "<--------[ /smiley to generate a smiley ]-------->";
print "<--------[------------------------------]-------->";

sub gen_smiley {

	my ($data, $server, $witem) = @_;
	my @smilies;
	my $string;
	my $i;

	@smilies = (':)',':D',';D',':P',':>','=D','=)',':E',':]');

	for ($i = 0; $i < 100; $i++) {
		if (rand(4) > 2 && $i > 0 && $string !~ / $/) {
			$string .= " ";
		} else {
			$string .= @smilies[rand($#smilies-1)];
		}
	}
	
	if ($witem) {
		$witem->command("MSG ".$witem->{name}." ".$string);
	} else {
		Irssi::print("No active channel or query in this window.");
	}
}

Irssi::command_bind('smiley', 'gen_smiley');
