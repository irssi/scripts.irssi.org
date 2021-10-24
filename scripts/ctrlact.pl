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
# the ability to define, per-item and per-window, what level of activity should
# trigger a change in the statusbar, possibily depending on how long ago
# you yourself were active on the channel, then ctrlact might be for you.
#
# For instance, you might never want to be disturbed by activity in any
# channel, unless someone highlights you, or if you've said something yourself
# in the channel in the past hour. You also want all activity
# in queries (except on efnet), as well as an indication about any chatter in
# your company channels. The following ctrlact map would do this for you:
#
#	channel		*	/^#myco-/	messages
#	channel		*	*		messages	3600
#	channel		*	*		hilights
#	query		efnet	*		messages
#	query		*	*		all
#
# These five lines would be interpreted/read as:
#  "only messages or higher in a channel matching /^#myco-/ should trigger act"
#  "in all other channels where I've been active in the last 3600 seconds,
#   trigger on all messages"
#  "in all other channels, only hilights (or higher) should trigger act"
#  "queries on efnet should only trigger act for messages and higher"
#  "privmsgs of all levels should trigger act in queries elsewhere"
#
# The activity level in the fourth column is thus to be interpreted as
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
# character. You may also use the asterisk by itself to match everything, or
# as part of a word, e.g. #debian-*. No other wildcards are supported.
#
# If you change the file, make sure to use /ctrlact reload or else it may get
# overwritten.
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
### Changelog:
#
#  2021-09-20 : v1.5
#  * Introduce snoop and sleep. Snooping means ctrlact will apply rules as if
#    you had just been active on the channel, and sleeping means that ctrlact
#    applies rules as if you hadn't been active recently.
#  * Also display the time remaining when an attention-span rule matches
#  * Sanity checks on the fallback settings
#  * Implement /ctrlact help
#  * Fix /ctrlact show with an empty ruleset
#
#  2021-09-11 : v1.4
#  * Let rules be defined and removed with /ctrlact add/remove
#  * Implement saving of map file
#  * Introduce the concept of attention span
#  * Wildcard matching on substrings
#  * Several code refactorings and improvements
#
#  2021-09-06 : v1.3
#  * Maintenance release, minor fixups
#
#  2017-02-24 : v1.2
#  * Fix invocation of '/ctrlact query' without a -tag (#354)
#
#  2017-02-15 : v1.1
#  * Configurable inhibition of beeps
#  * Re-read configuration properly
#  * Provide for matching on chatnet/server tag
#
#  2017-02-12 : v1.0
#  * Initial public release
#
### To-do:
#
# - figure out interplay with activity_hide_level
# - use Irssi formats
#
use strict;
use warnings;
use utf8;
use Carp qw( croak );
use Irssi;
use Text::ParseWords;
use version;

our %IRSSI = (
    authors     => 'martin f. krafft',
    contact     => 'madduck@madduck.net',
    name        => 'ctrlact',
    description => 'allows per-channel control over activity indication',
    license     => 'MIT',
    url         => 'https://github.com/irssi/scripts.irssi.org/blob/master/scripts/ctrlact.pl',
    version     => '1.5',
    changed     => '2021-09-20'
);

our $VERSION = $IRSSI{version};
my $_VERSION = version->parse($VERSION);

### DEFAULTS AND SETTINGS ######################################################

my @DATALEVEL_KEYWORDS = ('all', 'messages', 'hilights', 'none');

my $debug = 0;
my $map_file = Irssi::get_irssi_dir()."/ctrlact";
my $fallback_channel_threshold = 1;
my $fallback_query_threshold = 1;
my $fallback_window_threshold = 1;
my $inhibit_beep = 1;
my $autosave = 1;

Irssi::settings_add_str('ctrlact', 'ctrlact_map_file', $map_file);
Irssi::settings_add_bool('ctrlact', 'ctrlact_debug', $debug);
Irssi::settings_add_str('ctrlact', 'ctrlact_fallback_channel_threshold', $fallback_channel_threshold);
Irssi::settings_add_str('ctrlact', 'ctrlact_fallback_query_threshold', $fallback_query_threshold);
Irssi::settings_add_str('ctrlact', 'ctrlact_fallback_window_threshold', $fallback_window_threshold);
Irssi::settings_add_bool('ctrlact', 'ctrlact_inhibit_beep', $inhibit_beep);
Irssi::settings_add_bool('ctrlact', 'ctrlact_autosave', $autosave);

sub init_threshold_setting {
	my ($type, $ref) = @_;
	my $setting = 'ctrlact_fallback_'.$type.'_threshold';
	my $th = Irssi::settings_get_str($setting);
	my $dl = get_data_level($th);
	if ($dl) {
		${$ref} = $dl;
	}
	else {
		Irssi::settings_set_str($setting, ${$ref});
	}
}

sub sig_setup_changed {
	$debug = Irssi::settings_get_bool('ctrlact_debug');
	$map_file = Irssi::settings_get_str('ctrlact_map_file');

	init_threshold_setting('channel', \$fallback_channel_threshold);
	init_threshold_setting('query', \$fallback_query_threshold);
	init_threshold_setting('window', \$fallback_window_threshold);

	$inhibit_beep = Irssi::settings_get_bool('ctrlact_inhibit_beep');
	$autosave = Irssi::settings_get_bool('ctrlact_autosave');
}
Irssi::signal_add('setup changed', \&sig_setup_changed);
Irssi::signal_add('setup reread', \&sig_setup_changed);
sig_setup_changed();

my $changed_since_last_save = 0;

my @window_thresholds;
my @channel_thresholds;
my @query_thresholds;
my %THRESHOLDARRAYS = ('window'  => \@window_thresholds,
		 'channel' => \@channel_thresholds,
		 'query'   => \@query_thresholds
		);

my %OWN_ACTIVITY = ();

### HELPERS ####################################################################

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
	say("DEBUG: ".$msg, MSGLEVEL_CRAP + MSGLEVEL_NO_ACT, $inwin);
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

sub match {
	my ($pat, $text) = @_;
	if ($pat =~ m/^(\W)(.+)\1$/) {
		return ($pat, $text) if $text =~ /$2/i;
	}
	elsif ($pat =~ m/\*/) {
		my $rpat = $pat =~ s/\*/.*/gr;
		return ($pat, $text) if $text =~ /$rpat/
	}
	else {
		return ($pat, $text) if lc($text) eq lc($pat);
	}
	return ();
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

sub is_data_level {
	my ($dl) = @_;
	return $dl =~ /^[1-4]$/;
}

sub from_data_level {
	my ($dl) = @_;
	if (is_data_level($dl)) {
		return $DATALEVEL_KEYWORDS[$dl-1];
	}
}

sub get_data_level {
	my ($data) = @_;
	if (is_data_level($data)) {
		return $data;
	}
	elsif((my $dl = to_data_level($data)) > 0) {
		return $dl;
	}
	else {
		error("Invalid data level: $data");
	}
}

sub walk_match_array {
	my ($name, $net, $type, $arr) = @_;
	foreach my $rule (@{$arr}) {
		my ($netpat, $net) = match($rule->[0], $net);
		my ($namepat, $name) = match($rule->[1], $name);
		next unless $netpat and $namepat;

		my $own = $OWN_ACTIVITY{($net, $name)} // 0;
		my $time = time();
		my $span = ($rule->[3] eq '∞') ? 0 : $rule->[3];
		my $remaining = $own + $span - $time;

		if ($span > 0 and $remaining <= 0) {
			delete $OWN_ACTIVITY{($net, $name)};
			next;
		}

		my $result = to_data_level($rule->[2]);
		my $tresult = from_data_level($result);
		$name = '(unnamed)' unless length $name;
		my $match = sprintf('%s = net:%s name:%s span:%s',
			$rule->[4], $netpat, $namepat,
			($remaining < 0) ? $rule->[3] : $remaining.'s remain');
		return ($result, $tresult, $match);
	}
	return -1;
}

sub get_mappings_table {
	my ($arr, $fallback) = @_;
	my @ret = ();
	while (my ($i, $elem) = each @{$arr}) {
		push @ret, sprintf("%7d: %-16s %-32s %-9s %-5s (%s)",
			$i, @{$elem});
	}
	push @ret, sprintf("%7s: %-16s %-32s %-9s %-5s (%s)",
		'last', '*', '*', from_data_level($fallback), '∞', 'default');
	return join("\n", @ret);
}

sub get_specific_threshold {
	my ($type, $name, $net) = @_;
	$type = lc($type);
	if (exists $THRESHOLDARRAYS{$type}) {
		return walk_match_array($name, $net, $type, $THRESHOLDARRAYS{$type});
	}
	else {
		croak "ctrlact: can't look up threshold for type: $type";
	}
}

sub get_item_threshold {
	my ($type, $name, $net) = @_;
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

sub set_threshold {
	my ($arr, $chatnet, $name, $level, $pos, $span) = @_;

	if ($level =~ /^[1-4]$/) {
		$level = from_data_level($level);
	}
	elsif (!to_data_level($level)) {
		error("Not a valid activity level: $level", 1);
		return -1;
	}

	my $found = 0;
	my $index = 0;
	for (; $index < scalar @{$arr}; ++$index) {
		my $item = $arr->[$index];
		if ($item->[0] eq $chatnet and $item->[1] eq $name) {
			$found = 1;
			last;
		}
	}

	if ($found) {
		splice @{$arr}, $index, 1;
		$pos = $index unless defined $pos;
	}

	splice @{$arr}, $pos // 0, 0, [$chatnet, $name, $level, $span, 'manual'];
	$changed_since_last_save = 1;
	return $found;
}

sub unset_threshold {
	my ($arr, $chatnet, $name, $pos) = @_;
	my $found = 0;
	if (defined $pos) {
		if ($pos > $#{$arr}) {
			warning("There exists no rule \@$pos");
		}
		else {
			splice @{$arr}, $pos, 1;
			$found = 1;
		}
	}
	else {
		for (my $i = scalar @{$arr} - 1; $i >= 0; --$i) {
			my $item = $arr->[$i];
			if ($item->[0] eq $chatnet and $item->[1] eq $name) {
				splice @{$arr}, $i, 1;
				$found = 1;
			}
		}
		if (!$found) {
			warning("No matching rule found for deletion");
		}
	}
	$changed_since_last_save = $found;
	return $found;
}

sub print_levels_for_all {
	my ($type, @arr) = @_;
	info(uc("$type mappings:"));
	for my $i (@arr) {
		my $name = $i->{'name'};
		my $net = $i->{'server'}->{'tag'} // '';
		my ($c, $t, $tt, $match);
		if ($type eq 'window') {
			($t, $tt, $match) = get_win_threshold($name, $net);
			$c = $i->{'refnum'};
		}
		else {
			($t, $tt, $match) = get_item_threshold($type, $name, $net);
			$c = $i->window()->{'refnum'};
		}
		info(sprintf("%4d: %-40.40s → %d (%-8s)  match %s", $c, $name, $t, $tt, $match));
	}
}

sub parse_args {
	# type: -window -channel -query
	# tag: -*
	# span: +\d
	# position: @\d
	# anything else: item
	my ($data) = @_;
	my @args = shellwords($data);
	my ($type, $tag, $pos, $span);
	my @rest = ();
	my $max = 0;

	foreach my $arg (@args) {
		if ($arg =~ m/^-(windows?|channels?|quer(?:ys?|ies))/) {
			if ($type) {
				error("Can't specify $arg after -$type", 1);
				return 1;
			}
			my $m = $1;
			$type = 'window' if $m =~ m/^w/;
			$type = 'channel' if $m =~ m/^c/;
			$type = 'query' if $m =~ m/^q/;
		}
		elsif ($arg =~ m/^-(\S+)/) {
			if ($tag) {
				error("Tag -$tag already specified, cannot accept $arg", 1);
				return 1;
			}
			$tag = $1;
		}
		elsif ($arg =~ m/^@([0-9]+)/) {
			if ($pos) {
				error("Position $pos already given, cannot accept $arg", 1);
				return 1;
			}
			$pos = $1;
		}
		elsif ($arg =~ m/^\+([0-9]+)/) {
			if ($span) {
				error("Span $span already given, cannot accept $arg", 1);
				return 1;
			}
			$span = $1;
		}
		else {
			push @rest, $arg;
			$max = length $arg if length $arg > $max;
		}
	}

	my %args = (
		type => $type,
		tag => $tag,
		pos => $pos,
		span => $span,
		rest => \@rest,
		max => $max
	);
	return \%args;
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
	my $witype = $witem->{'type'};
	my $winame = $witem->{'name'};
	my $witag = $witem->{'server'}->{'tag'} // '';
	my ($th, $tth, $match) = get_item_threshold($witype, $winame, $witag);
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
	if ($_inhibit_window && $win->{'refnum'} == $_inhibit_window->{'refnum'}) {
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

###

sub record_own_message {
	my ($server, $msg, $target) = @_;
	$OWN_ACTIVITY{($server->{chatnet}, $target)} = time();
}
for my $i ('public', 'private') {
	Irssi::signal_add("message own_$i", \&record_own_message);
}

### SAVING AND LOADING #########################################################

sub get_mappings_fh {
	my ($filename) = @_;
	my $fh;
	if (! -e $filename) {
		save_mappings($filename);
		info("Created new/empty mappings file: $filename");
	}
	open($fh, '<', $filename) || croak "Cannot open mappings file: $!";
	return $fh;
}

sub load_mappings {
	my ($filename) = @_;
	@window_thresholds = @channel_thresholds = @query_thresholds = ();
	my $fh = get_mappings_fh($filename);
	my $firstline = <$fh> || croak "Cannot read from $filename.";;
	my $version;
	if ($firstline =~ m/^#+\s+ctrlact mappings file \(version: *([\d.]+)\)/) {
		$version = version->parse($1);
	}
	else {
		croak "First line of $filename is not a ctrlact header.";
	}

	my $nrcols = 5;
	if ($version <= version->parse('1.0')) {
		$nrcols = 3;
	}
	elsif ($version <= version->parse('1.3')) {
		$nrcols = 4;
	}
	my $l = 1;
	my $cnt = 0;
	while (<$fh>) {
		$l++;
		next if m/^\s*(?:#|$)/;
		my ($type, @matchers) = split;
		if (scalar @matchers >= $nrcols) {
			error("Cannot parse $filename:$l: $_");
			return;
		}
		@matchers = ['*', @matchers] if $version <= version->parse('1.0');

		if (scalar @matchers == $nrcols - 2) {
			push @matchers, '∞';
		}

		push @matchers, sprintf('line %2d', $l);

		if (exists $THRESHOLDARRAYS{$type}) {
			push @{$THRESHOLDARRAYS{$type}}, [@matchers];
			$cnt += 1;
		}
	}
	close($fh) || croak "Cannot close mappings file: $!";
	return $cnt;
}

sub save_mappings {
	my ($filename) = @_;
	open(FH, '+>', $filename) || croak "Cannot create mappings file: $!";

	my $ftw = from_data_level($fallback_window_threshold);
	my $ftc = from_data_level($fallback_channel_threshold);
	my $ftq = from_data_level($fallback_query_threshold);
	print FH <<"EOF";
# ctrlact mappings file (version: $_VERSION)
#
# WARNING: this file will be overwritten on /save,
# use "/set ctrlact_autosave off" to avoid.
#
# type: window, channel, query
# server: the server tag (chatnet)
# name: full name to match, /regexp/, or * (for all)
# min.level: none, messages, hilights, all, or 1,2,3,4
# span: "attention span", how many seconds after your own
#       last message should this rule apply
#
# type	server	name	min.level	span

EOF
	foreach my $type (sort keys %THRESHOLDARRAYS) {
		foreach my $arr (@{$THRESHOLDARRAYS{$type}}) {
			print FH "$type\t";
			print FH join "\t", @{$arr}[0..2];
			print FH "\t" . @{$arr}[3] if @{$arr}[3] ne '∞';
			print FH "\n";
		}
	}
	print FH <<"EOF";

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
### display messages in channels in which we were recently (3600s) active:
# channel	*	*	messages	3600
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
	close FH;
}

sub cmd_load {
	my $cnt = load_mappings($map_file);
	if (!$cnt) {
		@window_thresholds = @channel_thresholds = @query_thresholds = ();
	}
	else {
		info("Loaded $cnt mappings from $map_file");
		$changed_since_last_save = 0;
	}
}

sub cmd_save {
	my ($args) = @_;
	if (!$changed_since_last_save and $args ne '-force') {
		info("Not saving unchanged mappings without -force");
		return;
	}
	autosave(1);
}

### OTHER COMMANDS #############################################################

sub cmd_add {
	my ($data, $server, $witem) = @_;
	my $args = parse_args($data);
	my $type = $args->{type} // 'channel';
	my $tag = $args->{tag} // '*';
	my $pos = $args->{pos};
	my $span = $args->{span} // '∞';
	my ($name, $level);

	for my $item (@{$args->{rest}}) {
		if (!$name) {
			$name = $item;
		}
		elsif (!$level) {
			$level = $item;
		}
		else {
			error("Unexpected argument: $item");
			return;
		}
	}

	if (!$name) {
		error("Must specify at least a level");
		return;
	}
	elsif (!length $level) {
		if ($witem) {
			$level = $name;
			$name = $witem->{name};
			$tag = $server->{chatnet} unless $tag;
		}
		else {
			error("No name specified, and no active window item");
			return;
		}
	}

	my $res = set_threshold($THRESHOLDARRAYS{$type}, $tag, $name, $level, $pos, $span);
	if ($res > 0) {
		info("Existing rule replaced.");
	}
	elsif ($res == 0) {
		info("Rule added.");
	}
}

sub cmd_remove {
	my ($data, $server, $witem) = @_;
	my $args = parse_args($data);
	my $type = $args->{type} // 'channel';
	my $tag = $args->{tag} // '*';
	my $pos = $args->{pos};
	my $name;

	for my $item (@{$args->{rest}}) {
		if (!$name) {
			$name = $item;
		}
		else {
			error("Unexpected argument: $item");
			return;
		}
	}
	if (!defined $pos) {
		if (!$name) {
			if ($witem) {
				$name = $witem->{name};
				$tag = $server->{chatnet} unless $tag;
			}
			else {
				error("No name specified, and no active window item");
				return;
			}
		}
	}

	if (unset_threshold($THRESHOLDARRAYS{$type}, $tag, $name, $pos)) {
		info("Rule removed.");
	}
}

sub cmd_snoop {
	my ($data, $server, $witem) = @_;
	my $args = parse_args($data);
	my $type = $args->{type} // 'channel';
	my $tag = $args->{tag};
	my $name;

	for my $item (@{$args->{rest}}) {
		if (!$name) {
			$name = $item;
		}
		else {
			error("Unexpected argument: $item");
			return;
		}
	}

	if (!$name) {
		if ($witem) {
			$name = $witem->{name};
			$tag = $server->{chatnet} unless $tag;
		}
		else {
			error("No name specified, and no active window item");
			return;
		}
	}

	$OWN_ACTIVITY{($tag, $name)} = time();
	info("Snooping in on $tag/$name", 1);
}

sub cmd_sleep {
	my ($data, $server, $witem) = @_;
	my $args = parse_args($data);
	my $type = $args->{type} // 'channel';
	my $tag = $args->{tag};
	my $name;

	for my $item (@{$args->{rest}}) {
		if (!$name) {
			$name = $item;
		}
		else {
			error("Unexpected argument: $item");
			return;
		}
	}

	if (!$name) {
		if ($witem) {
			$name = $witem->{name};
			$tag = $server->{chatnet} unless $tag;
		}
		else {
			error("No name specified, and no active window item");
			return;
		}
	}

	my $was = $OWN_ACTIVITY{($tag, $name)};
	delete $OWN_ACTIVITY{($tag, $name)};
	if ($was) {
		$was = time() - $was;
		info("Back to sleep on $tag/$name (after $was seconds)", 1);
	}
}

sub cmd_list {
	info("WINDOW MAPPINGS\n" . get_mappings_table(\@window_thresholds, $fallback_window_threshold));
	info("CHANNEL MAPPINGS\n" . get_mappings_table(\@channel_thresholds, $fallback_channel_threshold));
	info("QUERY MAPPINGS\n" . get_mappings_table(\@query_thresholds, $fallback_query_threshold));
}

sub cmd_query {
	my ($data, $server, $witem) = @_;
	my $args = parse_args($data);
	my $type = $args->{type} // 'channel';
	my $tag = $args->{tag} // '*';
	my $max = $args->{max};
	my @words = @{$args->{rest}};

	if (!@words) {
		if ($witem) {
			push @words, $witem->{name};
			$tag = $server->{chatnet} unless $tag ne '*';
		}
		else {
			error("No name specified, and no active window item");
			return;
		}
	}

	foreach my $name (@words) {
		my ($t, $tt, $match) = get_specific_threshold($type, $name, $tag);
		info(sprintf("%7s: %7s %-22s → %-8s  match: %s", $type, $tag, $name, $tt, $match), 1);
	}
}

sub cmd_show {
	my ($data, $server, $item) = @_;
	my $args = parse_args($data);
	my $type = $args->{type} // 'all';

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
	my ($force) = @_;
	return unless $force or $changed_since_last_save;
	if (!$autosave) {
		info("Not saving mappings due to ctrlact_autosave setting");
		return;
	}
	info("Saving mappings to $map_file");
	save_mappings($map_file);
	$changed_since_last_save = 0;
}

sub UNLOAD {
	autosave();
}

sub cmd_help {
	my ($data, $server, $item) = @_;
	Irssi::print (<<"SCRIPTHELP_EOF", MSGLEVEL_CLIENTCRAP);
%_ctrlact $_VERSION - fine-grained control of activity indication%_

%U%_Synopsis%_%U

%_CTRLACT ADD%_ [<%Umatchspec%U>] [@<%Uposition%U>] [+<%Uspan%U>] <%Ulevel%U>
%_CTRLACT REMOVE%_ [<%Umatchspec%U>] [@<%Uposition%U>]
%_CTRLACT QUERY%_ [<%Umatchspec%U>]
%_CTRLACT SNOOP%_ [<%Umatchspec%U>]
%_CTRLACT SLEEP%_ [<%Umatchspec%U>]
%_CTRLACT LIST%_
%_CTRLACT SHOW%_ [<%Utype%U>]
%_CTRLACT SAVE%_ [-force]
%_CTRLACT [RE]LOAD%_
%_CTRLACT HELP%_

<%Umatchspec%U> %| [-<%Utype%U>] [-<%Utag%U>] <%Uname%U>
%U%U            %|   (defaults to current window item, if available)
<%Utype%U>      %| "window"|"channel"|"query"
%U%U            %|   (default: "channel")
<%Utag%U>       %| The chat network's tag, e.g. oftc
<%Uname%U>      %| Name of the channel, query, or window
%U%U            %|   May include '*', or be a regular expression: /.../
<%Ulevel%U>     %| Minimum activity level to match:
%U%U            %|   1, all, 2, messages, 3, highlights, 4, none
<%Uposition%U>  %| Integer index where to insert new rule, or of rule to remove
<%Uspan%U>      %| Time in seconds during which this rule applies following own engagement

%U%_Settings%_%U

/set %_ctrlact_map_file%_ [$map_file]
  %| Controls where the activity control map will be read from (and saved to)

/set %_ctrlact_fallback_channel_threshold%_ [$fallback_channel_threshold]
/set %_ctrlact_fallback_query_threshold%_ [$fallback_query_threshold]
/set %_ctrlact_fallback_window_threshold%_ [$fallback_window_threshold]
  %| Controls the lowest data level that will trigger activity for channels,
  %| queries, and windows respectively, if no applicable mapping could be
  %| found. Valid values are 1, all, 2, messages, 3, highlights, 4, none.

/set %_ctrlact_inhibit_beep%_ [$inhibit_beep]
  %| If an activity wouldn't be indicated, also inhibit the beep/bell. Turn
  %| this off if you want the bell anyway.

/set %_ctrlact_autosave%_ [$autosave]
  %| Unless this is disabled, the rules will be written out to the map file
  %| (and overwriting it) on /save and /ctrlact save.

/set %_ctrlact_debug%_ [$debug]
  %| Turns on debug output. Not that this may itself be buggy, so please don't
  %| use it unless you really need it.

%U%_Examples%_%U

Set channel default level to hilights only:
  %|%#/SET %_ctrlact_fallback_channel_threshold%_ hilights

Show activity for messages in the #irssi channel on LiberaChat:
  %|%#/%_CTRLACT ADD%_ -LiberaChat #irssi messages

Show all activity for messages on my company's channels:
  %|%#/%_CTRLACT ADD%_ -channel #myco-* all

Create a rule for the current window item:
  %|%#/%_CTRLACT ADD%_ all

Insert a rule at position 3 (default is to insert at the top):
  %|%#/%_CTRLACT ADD%_ @3 #mutt messages

List all mappings:
  %|%#/%_CTRLACT LIST%_

Remove mapping at position 3:
  %|%#/%_CTRLACT REMOVE%_ @3

Remove mapping for current window item:
  %|%#/%_CTRLACT REMOVE%_

Remove mapping for #irssi channel (see above)
  %|%#/%_CTRLACT REMOVE%_ -LiberaChat #irssi

Save mappings to file ($map_file), using -force to write even if nothing has changed:
  %|%#/%_CTRLACT SAVE%_ -force

Load mappings from file ($map_file):
  %|%#/%_CTRLACT LOAD%_

Create a rule to show activity on any channel in which we've engaged in the last hour:
  %|%#/%_CTRLACT ADD%_ +3600 -* * messages

Pretend that we interacted with the #perl channel, so as to get activity as per the last rule:
  %|%#/%_CTRLACT SNOOP%_ #perl

Stop activity indication for the current channel after we engaged with it:
  %|%#/%_CTRLACT SLEEP%_

Query which rule would apply to the current channel:
  %|%#/%_CTRLACT QUERY%_

Show the matching rule for every query:
  %|%#/%_CTRLACT SHOW%_ -query
SCRIPTHELP_EOF
}

Irssi::signal_add('setup saved', \&autosave);
Irssi::signal_add('setup reread', \&cmd_load);

Irssi::command_bind('ctrlact help',\&cmd_help);
Irssi::command_bind('ctrlact reload',\&cmd_load);
Irssi::command_bind('ctrlact load',\&cmd_load);
Irssi::command_bind('ctrlact save',\&cmd_save);
Irssi::command_bind('ctrlact add',\&cmd_add);
Irssi::command_bind('ctrlact remove',\&cmd_remove);
Irssi::command_bind('ctrlact snoop',\&cmd_snoop);
Irssi::command_bind('ctrlact sleep',\&cmd_sleep);
Irssi::command_bind('ctrlact list',\&cmd_list);
Irssi::command_bind('ctrlact query',\&cmd_query);
Irssi::command_bind('ctrlact show',\&cmd_show);

Irssi::command_bind('ctrlact' => sub {
		my ($data, $server, $item) = @_;
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
		my ($data, $server, $item) = @_;
		my @words = split /\s+/, $data;
		return unless shift @words eq 'ctrlact';
		cmd_help();
		Irssi::signal_stop();
	}
);

cmd_load();
