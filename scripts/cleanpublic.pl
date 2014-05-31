# Simple script for removing colours in public channels :)

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

# Dev. info ^_^
$VERSION = "0.3";
%IRSSI = (
	authors     => "Jørgen Tjernø",
	contact     => "darkthorne\@samsen.com",
	name        => "CleanPublic",
	description => "Simple script that removes colors and other formatting (bold, etc) from public channels",
	license     => "GPL",
	url         => "http://mental.mine.nu",
	changed     => "Wed Sep 24 13:17:15 CEST 2003"
);

# All the works
sub strip_formatting {
	my ($server, $data, $nick, $mask, $target) = @_;
	# Channel *allowed* to be colorful?
	foreach my $chan (split(' ', Irssi::settings_get_str('colored_channels'))) {
		if ($target eq $chan) { return }
	}
	
	# Ruthlessly_ripped_from_Garion {
	my $twin = Irssi::window_find_name($target);
	# Beam it to window 1 if we cant find any other suitable target.
	if (!defined($twin)) { $twin = Irssi::window_find_refnum(1); }
	# }
	
	# Remove formatting
	$data =~ s/\x03\d?\d?(,\d?\d?)?|\x02|\x1f|\x16|\x06|\x07//g;
	# Let it flow
	Irssi::signal_continue($server, $data, $nick, $mask, $target);
}

# Hook me up
Irssi::signal_add('message public', 'strip_formatting');
Irssi::settings_add_str('lookandfeel', 'colored_channels', '');
