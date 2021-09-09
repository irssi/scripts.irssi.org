# ctrlact.pl — Irssi script for fine-grained control of activity indication
#
# © 2017–2021 martin f. krafft <madduck@madduck.net>
# Released under the MIT licence.
#
### Usage:
#
# /script load ctrlact
#
# If you like a busy activity statusbar, this script is not for you.
#
# If, on the other hand, you don't care about most activity, but you do want
# the ability to define per-item and per-window, what level of activity should
# trigger a change in the statusbar, then ctrlact might be for you.
#
# For instance, you might never want to be disturbed by activity in any
# channel, unless someone highlights you. However, you do want all activity
# in queries (except on efnet), as well as an indication about any chatter in
# your company channels. The following ctrlact map would do this for you:
#
#	channel		*	/^#myco-/	messages
#	channel		*	*		hilights
#	query		efnet	*		messages
#	query		*	*		all
#
# These four lines would be interpreted/read as:
#  "only messages or higher in a channel matching /^#myco-/ should trigger act"
#  "in all other channels, only hilights (or higher) should trigger act"
#  "queries on efnet should only trigger act for messages and higher"
#  "privmsgs of all levels should trigger act in queries elsewhere"
#
# The activity level in the third column is thus to be interpreted as
#  "the minimum level of activity that will trigger an indication"
#
# Loading this script per-se should not change anything, except it will create
# ~/.irssi/ctrlact with some informational content, including the defaults and
# some examples.
#
# The four activity levels are, and you can use either the words, or the
# integers in the map.
#
#	all		(data_level: 1)
#	messages	(data_level: 2)
#	hilights	(data_level: 3)
#	none		(data_level: 4)
#
# Note that the name is either matched in full and verbatim, or treated like
# a regular expression, if it starts and ends with the same punctuation
# character. The asterisk ('*') is special and simply gets translated to /.*/
# internally. No other wildcards are supported.
#
# Once you defined your mappings, please don't forget to /ctrlact reload them.
# You can then use the following commands from Irssi to check out the result:
#
#	# list all mappings
#	/ctrlact list
#
#	# query the applicable activity levels, possibly limited to
#	# windows/channels/queries
#	/ctrlact query name [name, …] [-window|-channel|-query]
#
#	# display the applicable level for each window/channel/query
#	/ctrlact show [-window|-channel|-query]
#
# There's an interplay between window items and windows here, and you can
# specify mininum activity levels for each. Here are the rules:
#
# 1. if the minimum activity level of a window item (channel or query) is not
#    reached, then the window is prevented from indicating activity.
# 2. if traffic in a window item does reach minimum activity level, then the
#    minimum activity level of the window is considered, and activity is only
#    indicated if the window's minimum activity level is lower.
#
# In general, this means you'd have windows defaulting to 'all', but it might
# come in handy to move window items to windows with min.levels of 'hilights'
# or even 'none' in certain cases, to further limit activity indication for
# them.
#
# You can use the Irssi settings activity_msg_level and activity_hilight_level
# to specify which IRC levels will be considered messages and hilights. Note
# that if an activity indication is inhibited, then there also won't be
# a beep (cf. beep_msg_level), unless you toggle ctrlmap_inhibit_beep.
#
### Settings:
#
# /set ctrlact_map_file [~/.irssi/ctrlact]
#   Controls where the activity control map will be read from (and saved to)
#
# /set ctrlact_fallback_(channel|query|window)_threshold [1]
#   Controls the lowest data level that will trigger activity for channels,
#   queries, and windows respectively, if no applicable mapping could be
#   found.
#
# /set ctrlact_inhibit_beep [on]
#   If an activity wouldn't be indicated, also inhibit the beep/bell. Turn
#   this off if you want the bell anyway.
#
# /set ctrlact_debug [off]
#   Turns on debug output. Not that this may itself be buggy, so please don't
#   use it unless you really need it.
#
### To-do:
#
# - figure out interplay with activity_hide_level
# - /ctrlact add/delete/move and /ctrlact save, maybe
# - completion for commands
#
use strict;
use warnings;
use Carp qw( croak );
use Irssi;
use Text::ParseWords;

our $VERSION = '1.3';

our %IRSSI = (
    authors     => 'martin f. krafft',
    contact     => 'madduck@madduck.net',
    name        => 'ctrlact',
    description => 'allows per-channel control over activity indication',
    license     => 'MIT',
    url         => 'https://github.com/irssi/scripts.irssi.org/blob/master/scripts/ctrlact.pl',
    changed     => '2021-09-06'
);

### DEFAULTS AND SETTINGS ######################################################

my $debug = 0;
my $map_file = Irssi::get_irssi_dir()."/ctrlact";
my $fallback_channel_threshold = 1;
my $fallback_query_threshold = 1;
my $fallback_window_threshold = 1;
my $inhibit_beep = 1;

Irssi::settings_add_str('ctrlact', 'ctrlact_map_file', $map_file);
Irssi::settings_add_bool('ctrlact', 'ctrlact_debug', $debug);
Irssi::settings_add_int('ctrlact', 'ctrlact_fallback_channel_threshold', $fallback_channel_threshold);
Irssi::settings_add_int('ctrlact', 'ctrlact_fallback_query_threshold', $fallback_query_threshold);
Irssi::settings_add_int('ctrlact', 'ctrlact_fallback_window_threshold', $fallback_window_threshold);
Irssi::settings_add_bool('ctrlact', 'ctrlact_inhibit_beep', $inhibit_beep);

sub sig_setup_changed {
	$debug = Irssi::settings_get_bool('ctrlact_debug');
	$map_file = Irssi::settings_get_str('ctrlact_map_file');
	$fallback_channel_threshold = Irssi::settings_get_int('ctrlact_fallback_channel_threshold');
	$fallback_query_threshold = Irssi::settings_get_int('ctrlact_fallback_query_threshold');
	$fallback_window_threshold = Irssi::settings_get_int('ctrlact_fallback_window_threshold');
	$inhibit_beep = Irssi::settings_get_bool('ctrlact_inhibit_beep');
}
Irssi::signal_add('setup changed', \&sig_setup_changed);
Irssi::signal_add('setup reread', \&sig_setup_changed);
sig_setup_changed();

my $changed_since_last_save = 0;

my @DATALEVEL_KEYWORDS = ('all', 'messages', 'hilights', 'none');

### HELPERS ####################################################################

my $_inhibit_debug_activity = 0;
use constant DEBUGEVENTFORMAT => "%7s %7.7s %-22.22s  %d %s %d → %-7s  (%-8s ← %s)";
sub say {
	my ($msg, $level, $inwin) = @_;
	$level = $level // MSGLEVEL_CLIENTCRAP;
	if ($inwin) {
		Irssi::active_win->print("ctrlact: $msg", $level);
	}
	else {
		Irssi::print("ctrlact: $msg", $level);
	}
}

sub debug {
	return unless $debug;
	my ($msg, $inwin) = @_;
	$msg = $msg // "";
	$_inhibit_debug_activity = 1;
	say("DEBUG: ".$msg, MSGLEVEL_CRAP, $inwin);
	$_inhibit_debug_activity = 0;
}

use Data::Dumper;
sub dumper {
	debug(scalar Dumper(@_), 1);
}

sub info {
	my ($msg, $inwin) = @_;
	say($msg, MSGLEVEL_CLIENTCRAP, $inwin);
}

sub warning {
	my ($msg, $inwin) = @_;
	$msg = $msg // "";
	say("WARNING: ".$msg, MSGLEVEL_CLIENTERROR, $inwin);
}

sub error {
	my ($msg, $inwin) = @_;
	$msg = $msg // "";
	say("ERROR: ".$msg, MSGLEVEL_CLIENTERROR, $inwin);
}

my @window_thresholds;
my @channel_thresholds;
my @query_thresholds;

sub match {
	my ($pat, $text) = @_;
	my $npat = ($pat eq '*') ? '/.*/' : $pat;
	if ($npat =~ m/^(\W)(.+)\1$/) {
		my $re = qr/$2/;
		$pat = $2 unless $pat eq '*';
		return $pat if $text =~ /$re/i;
	}
	else {
		return $pat if lc($text) eq lc($npat);
	}
	return 0;
}

sub to_data_level {
	my ($kw) = @_;
	my $ret = 0;
	for my $i (0 .. $#DATALEVEL_KEYWORDS) {
		if ($kw eq $DATALEVEL_KEYWORDS[$i]) {
			$ret = $i + 1;
		}
	}
	return $ret
}

sub from_data_level {
	my ($dl) = @_;
	if ($dl =~ /^[1-4]$/) {
		return $DATALEVEL_KEYWORDS[$dl-1];
	}
}

sub walk_match_array {
	my ($name, $net, $type, $arr) = @_;
	foreach my $quadruplet (@{$arr}) {
		my $netmatch = $net eq '*' ? '(ignored)'
					: match($quadruplet->[0], $net);
		my $match = match($quadruplet->[1], $name);
		next unless $netmatch and $match;

		my $result = to_data_level($quadruplet->[2]);
		my $tresult = from_data_level($result);
		$name = '(unnamed)' unless length $name;
		$match = sprintf('line %3d = net:%s name:%s',
			$quadruplet->[3], $netmatch, $match);
		return ($result, $tresult, $match)
	}
	return -1;
}

sub get_mappings_table {
	my ($arr) = @_;
	my @ret = ();
	while (my ($i, $elem) = each @{$arr}) {
		push @ret, sprintf("%7d: %-16s %-32s %-10s (%s)",
			$i, $elem->[0], $elem->[1], $elem->[2], $elem->[3]);
	}
	return join("\n", @ret);
}

sub get_specific_threshold {
	my ($type, $name, $net) = @_;
	$type = lc($type);
	if ($type eq 'window') {
		return walk_match_array($name, $net, $type, \@window_thresholds);
	}
	elsif ($type eq 'channel') {
		return walk_match_array($name, $net, $type, \@channel_thresholds);
	}
	elsif ($type eq 'query') {
		return walk_match_array($name, $net, $type, \@query_thresholds);
	}
	else {
		croak "ctrlact: can't look up threshold for type: $type";
	}
}

sub get_item_threshold {
	my ($chattype, $type, $name, $net) = @_;
	my ($ret, $tret, $match) = get_specific_threshold($type, $name, $net);
	return ($ret, $tret, $match) if $ret > 0;
	if ($type eq 'CHANNEL') {
		return ($fallback_channel_threshold, from_data_level($fallback_channel_threshold), '[default]');
	}
	else {
		return ($fallback_query_threshold, from_data_level($fallback_query_threshold), '[default]');
	}
}

sub get_win_threshold {
	my ($name, $net) = @_;
	my ($ret, $tret, $match) = get_specific_threshold('window', $name, $net);
	if ($ret > 0) {
		return ($ret, $tret, $match);
	}
	else {
		return ($fallback_window_threshold, from_data_level($fallback_window_threshold), '[default]');
	}
}

sub print_levels_for_all {
	my ($type, @arr) = @_;
	info(uc("$type mappings:"));
	for my $i (@arr) {
		my $name = $i->{'name'};
		my $net = $i->{'server'}->{'tag'} // '';
		my ($t, $tt, $match) = get_specific_threshold($type, $name, $net);
		my $c = ($type eq 'window') ? $i->{'refnum'} : $i->window()->{'refnum'};
		info(sprintf("%4d: %-40.40s → %d (%-8s)  match %s", $c, $name, $t, $tt, $match));
	}
}

### HILIGHT SIGNAL HANDLERS ####################################################

my $_inhibit_beep = 0;
my $_inhibit_window = 0;

sub maybe_inhibit_witem_hilight {
	my ($witem, $oldlevel) = @_;
	return unless $witem;
	$oldlevel = 0 unless $oldlevel;
	my $newlevel = $witem->{'data_level'};
	return if ($newlevel <= $oldlevel);

	$_inhibit_window = 0;
	$_inhibit_beep = 0;
	my $wichattype = $witem->{'chat_type'};
	my $witype = $witem->{'type'};
	my $winame = $witem->{'name'};
	my $witag = $witem->{'server'}->{'tag'} // '';
	my ($th, $tth, $match) = get_item_threshold($wichattype, $witype, $winame, $witag);
	my $inhibit = $newlevel > 0 && $newlevel < $th;
	debug(sprintf(DEBUGEVENTFORMAT, lc($witype), $witag, $winame, $newlevel,
			$inhibit ? ('<',$th,'inhibit'):('≥',$th,'pass'),
			$tth, $match));
	if ($inhibit) {
		Irssi::signal_stop();
		# the rhval comes from config, so if the user doesn't want the
		# bell inhibited, this is effectively a noop.
		$_inhibit_beep = $inhibit_beep;
		$_inhibit_window = $witem->window();
	}
}
Irssi::signal_add_first('window item hilight', \&maybe_inhibit_witem_hilight);

sub inhibit_win_hilight {
	my ($win) = @_;
	Irssi::signal_stop();
	Irssi::signal_emit('window dehilight', $win);
}

sub maybe_inhibit_win_hilight {
	my ($win, $oldlevel) = @_;
	return unless $win;
	if ($_inhibit_debug_activity) {
		inhibit_win_hilight($win);
	}
	elsif ($_inhibit_window && $win->{'refnum'} == $_inhibit_window->{'refnum'}) {
		inhibit_win_hilight($win);
	}
	else {
		$oldlevel = 0 unless $oldlevel;
		my $newlevel = $win->{'data_level'};
		return if ($newlevel <= $oldlevel);

		my $wname = $win->{'name'};
		my $wtag = $win->{'server'}->{'tag'} // '';
		my ($th, $tth, $match) = get_win_threshold($wname, $wtag);
		my $inhibit = $newlevel > 0 && $newlevel < $th;
		debug(sprintf(DEBUGEVENTFORMAT, 'window', $wtag,
				$wname?$wname:"$win->{'refnum'}(unnamed)", $newlevel,
				$inhibit ? ('<',$th,'inhibit'):('≥',$th,'pass'),
				$tth, $match));
		inhibit_win_hilight($win) if $inhibit;
	}
}
Irssi::signal_add_first('window hilight', \&maybe_inhibit_win_hilight);

sub maybe_inhibit_beep {
	Irssi::signal_stop() if $_inhibit_beep;
}
Irssi::signal_add_first('beep', \&maybe_inhibit_beep);

### SAVING AND LOADING #########################################################

sub get_mappings_fh {
	my ($filename) = @_;
	my $fh;
	if (-e $filename) {
		open($fh, '<', $filename) || croak "Cannot open mappings file: $!";
	}
	else {
		open($fh, '+>', $filename) || croak "Cannot create mappings file: $!";

		my $ftw = from_data_level($fallback_window_threshold);
		my $ftc = from_data_level($fallback_channel_threshold);
		my $ftq = from_data_level($fallback_query_threshold);
		print $fh <<"EOF";
# ctrlact mappings file (version: $VERSION)
#
# type: window, channel, query
# server: the server tag (chatnet)
# name: full name to match, /regexp/, or * (for all)
# min.level: none, messages, hilights, all, or 1,2,3,4
#
# type	server	name	min.level


# EXAMPLES
#
### only indicate activity in the status window if messages were displayed:
# window	*	(status)	messages
#
### never ever indicate activity for any item bound to this window:
# window	*	oubliette	none
#
### indicate activity on all messages in debian-related channels on OFTC:
# channel	oftc	/^#debian/	messages
#
### display any text (incl. joins etc.) for the '#madduck' channel:
# channel	*	#madduck	all
#
### otherwise ignore everything in channels, unless a hilight is triggered:
# channel	*	*	hilights
#
### make somebot only get your attention if they hilight you:
# query	efnet	somebot	hilights
#
### otherwise we want to see everything in queries:
# query	*	*	all

# DEFAULTS:
# window	*	*	$ftw
# channel	*	*	$ftc
# query	*	*	$ftq

# vim:noet:tw=0:ts=16
EOF
		info("Created new/empty mappings file: $filename");
		seek($fh, 0, 0) || croak "Cannot rewind $filename.";
	}
	return $fh;
}

sub load_mappings {
	my ($filename) = @_;
	@window_thresholds = @channel_thresholds = @query_thresholds = ();
	my $fh = get_mappings_fh($filename);
	my $firstline = <$fh> || croak "Cannot read from $filename.";;
	my $version;
	if ($firstline =~ m/^#+\s+ctrlact mappings file \(version: *([\d.]+)\)/) {
		$version = $1;
	}
	else {
		croak "First line of $filename is not a ctrlact header.";
	}

	my $nrcols = 4;
	if ($version eq $VERSION) {
		# current version, i.e. no special handling is required. If
		# previous versions require special handling, then massage the
		# data or do whatever is required in the following
		# elsif-clauses:
	}
	elsif ($version eq "1.0") {
		$nrcols = 3;
	}
	my $linesplitter = '^\s*'.join('\s+', ('(\S+)') x $nrcols).'\s*$';
	my $l = 1;
	my $cnt = 0;
	while (<$fh>) {
		$l++;
		next if m/^\s*(?:#|$)/;
		my ($type, @matchers) = m/$linesplitter/;
		@matchers = ['*', @matchers] if ($version eq "1.0");
		push @matchers, $l;
		push @window_thresholds, [@matchers] if match($type, 'window');
		push @channel_thresholds, [@matchers] if match($type, 'channel');
		push @query_thresholds, [@matchers] if match($type, 'query');
		$cnt += 1;
	}
	close($fh) || croak "Cannot close mappings file: $!";
	return $cnt;
}

sub cmd_load {
	my $cnt = load_mappings($map_file);
	info("Loaded $cnt mappings from $map_file");
	$changed_since_last_save = 0;
}

sub cmd_save {
	error("saving not yet implemented", 1);
	return 1;
}

sub cmd_list {
	info("WINDOW MAPPINGS\n" . get_mappings_table(\@window_thresholds));
	info("CHANNEL MAPPINGS\n" . get_mappings_table(\@channel_thresholds));
	info("QUERY MAPPINGS\n" . get_mappings_table(\@query_thresholds));
}

sub parse_args {
	my (@args) = @_;
	my @words = ();
	my $typewasset = 0;
	my $tag;
	my $max = 0;
	my $type = undef;
	foreach my $arg (@args) {
		if ($arg =~ m/^-(windows?|channels?|quer(?:ys?|ies))/) {
			if ($typewasset) {
				error("can't specify -$1 after -$type", 1);
				return 1;
			}
			$type = 'window' if $1 =~ m/^w/;
			$type = 'channel' if $1 =~ m/^c/;
			$type = 'query' if $1 =~ m/^q/;
			$typewasset = 1
		}
		elsif ($arg =~ m/-(\S+)/) {
			$tag = $1;
		}
		else {
			push @words, $arg;
			$max = length $arg if length $arg > $max;
		}
	}
	return ($type, $tag, $max, @words);
}

sub cmd_query {
	my ($data, $server, $item) = @_;
	my @args = shellwords($data);
	my ($type, $tag, $max, @words) = parse_args(@args);
	$type = $type // 'channel';
	$tag = $tag // '*';
	foreach my $word (@words) {
		my ($t, $tt, $match) = get_specific_threshold($type, $word, $tag);
		printf CLIENTCRAP "ctrlact $type map: %s %*s → %d (%s, match:%s)", $tag, $max, $word, $t, $tt, $match;
	}
}

sub cmd_show {
	my ($data, $server, $item) = @_;
	my @args = shellwords($data);
	my ($type, $max, @words) = parse_args(@args);
	$type = $type // 'all';

	if ($type eq 'channel' or $type eq 'all') {
		print_levels_for_all('channel', Irssi::channels());
	}
	if ($type eq 'query' or $type eq 'all') {
		print_levels_for_all('query', Irssi::queries());
	}
	if ($type eq 'window' or $type eq 'all') {
		print_levels_for_all('window', Irssi::windows());
	}
}

sub autosave {
	cmd_save() if ($changed_since_last_save);
}

sub UNLOAD {
	autosave();
}

Irssi::signal_add('setup saved', \&autosave);
Irssi::signal_add('setup reread', \&cmd_load);

Irssi::command_bind('ctrlact help',\&cmd_help);
Irssi::command_bind('ctrlact reload',\&cmd_load);
Irssi::command_bind('ctrlact load',\&cmd_load);
Irssi::command_bind('ctrlact save',\&cmd_save);
Irssi::command_bind('ctrlact list',\&cmd_list);
Irssi::command_bind('ctrlact query',\&cmd_query);
Irssi::command_bind('ctrlact show',\&cmd_show);

Irssi::command_bind('ctrlact' => sub {
		my ( $data, $server, $item ) = @_;
		$data =~ s/\s+$//g;
		if ($data) {
			Irssi::command_runsub('ctrlact', $data, $server, $item);
		}
		else {
			cmd_help();
		}
	}
);
Irssi::command_bind('help', sub {
		$_[0] =~ s/\s+$//g;
		return unless $_[0] eq 'ctrlact';
		cmd_help();
		Irssi::signal_stop();
	}
);

cmd_load();
