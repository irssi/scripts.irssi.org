use strict;
use vars qw($VERSION %IRSSI);
use Irssi;
use Irssi::Irc;

# Usage:
# /script load go.pl
# If you are in #irssi you can type /go #irssi or /go irssi or even /go ir ...
# also try /go ir<tab> and /go  <tab> (that's two spaces)
#
# The following settings exist:
#
#   /SET go_match_case_sensitive [ON|OFF]
#     Match window/item names sensitively (the default). Turning this off
#     means e.g. "/go foo" would jump to a window named "Foobar", too.
#
#   /SET go_match_anchored [ON|OFF]
#     Match window/names only at the start of the word (the default). Turning
#     this off will mean that strings can match anywhere in the window/names.
#     The leading '#' of channel names is optional either way.
#
#   /SET go_complete_case_sensitive [ON|OFF]
#     When using tab-completion, match case-insensitively (the default).
#     Turning this on means that "/go foo<tab>" will *not* suggest "Foobar".
#
#   /SET go_complete_anchored [ON|OFF]
#     Match window/names only at the start of the word. The default is 'off',
#     which causes completion to match anywhere in the window/names during
#     completion. The leading '#' of channel names is optional either way.
#

$VERSION = '1.1';

%IRSSI = (
    authors     => 'nohar',
    contact     => 'nohar@freenode',
    name        => 'go to window',
    description => 'Implements /go command that activates a window given a name/partial name. It features a nice completion.',
    license     => 'GPLv2 or later',
    changed     => '2017-02-02'
);

sub _make_regexp {
	my ($name, $ci, $aw) = @_;
	my $re = "\Q${name}\E";
	$re = "(?i:$re)" unless $ci;
	$re = "^#?$re" if $aw;
	return $re;
}

sub signal_complete_go {
	my ($complist, $window, $word, $linestart, $want_space) = @_;
	my $channel = $window->get_active_name();
	my $k = Irssi::parse_special('$k');

        return unless ($linestart =~ /^\Q${k}\Ego\b/i);

	my $re = _make_regexp($word,
		Irssi::settings_get_bool('go_complete_case_sensitive'),
		Irssi::settings_get_bool('go_complete_anchored'));
	@$complist = ();
	foreach my $w (Irssi::windows) {
		my $name = $w->get_active_name();
		if ($word ne "") {
			if ($name =~ $re) {
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
	my $re = _make_regexp($chan,
		Irssi::settings_get_bool('go_match_case_sensitive'),
		Irssi::settings_get_bool('go_match_anchored'));

	foreach my $w (Irssi::windows) {
		my $name = $w->get_active_name();
		if ($name =~ $re) {
			$w->set_active();
			return;
		}
	}
}

Irssi::command_bind("go", "cmd_go");
Irssi::signal_add_first('complete word', 'signal_complete_go');
Irssi::settings_add_bool('go', 'go_match_case_sensitive', 1);
Irssi::settings_add_bool('go', 'go_complete_case_sensitive', 0);
Irssi::settings_add_bool('go', 'go_match_anchored', 1);
Irssi::settings_add_bool('go', 'go_complete_anchored', 0);

# Changelog
#
# 2017-02-02  1.1  martin f. krafft <madduck@madduck.net>
#   - made case-sensitivity of match configurable
#   - made anchoring of search strings configurable
#
