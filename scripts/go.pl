use strict;
use vars qw($VERSION %IRSSI);
use Irssi;
use Irssi::Irc;

# Usage:
# /script load go.pl
# If you are in #irssi you can type /go #irssi or /go irssi or even /go ir ...
# also try /go ir<tab> and /go  <tab> (that's two spaces)

$VERSION = '1.00';

%IRSSI = (
    authors     => 'nohar',
    contact     => 'nohar@freenode',
    name        => 'go to window',
    description => 'Implements /go command that activates a window given a name/partial name. It features a nice completion.',
    license     => 'GPLv2 or later',
    changed     => '08-17-04'
);

sub signal_complete_go {
	my ($complist, $window, $word, $linestart, $want_space) = @_;
	my $channel = $window->get_active_name();
	my $k = Irssi::parse_special('$k');

        return unless ($linestart =~ /^\Q${k}\Ego/i);

	@$complist = ();
	foreach my $w (Irssi::windows) {
		my $name = $w->get_active_name();
		if ($word ne "") {
			if ($name =~ /\Q${word}\E/i) {
				push(@$complist, $name)
			}
		} else {
			push(@$complist, $name);
		}
	}
	Irssi::signal_stop();
};

sub cmd_go
{
	my($chan,$server,$witem) = @_;

	$chan =~ s/ *//g;
	foreach my $w (Irssi::windows) {
		my $name = $w->get_active_name();
		if ($name =~ /^#?\Q${chan}\E/) {
			$w->set_active();
			return;
		}
	}
}

Irssi::command_bind("go", "cmd_go");
Irssi::signal_add_first('complete word', 'signal_complete_go');

