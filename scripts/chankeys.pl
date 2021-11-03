# chankeys.pl — Irssi script for associating key shortcuts with channels
#
# © 2021 martin f. krafft <madduck@madduck.net>
# Released under the MIT licence.
#
### Usage:
#
# /script load chankeys
#
# This plugin serves to simplify the assignment of keyboard shortcuts that
# take you to channels or queries (so-called "window items").
#
# Let's assume you're in the #irssi channel, then you could issue the command
#
#   /chankeys add meta-s-meta-i
#
# and thenceforth, hitting that key combination will take you to the channel.
# It's smart enough to check whether a mapping is already in use by chankey,
# or whether a key combination won't work, for instance because meta-s was
# already assigned elsewhere in the above.
#
# You can also explicitly specify the name (and chatnet) if you'd like to
# set up a mapping for another item:
#
#   /chankeys add F12 &bitlbee
#
# Key bindings are removed when you leave a channel or a query is closed, and
# reinstated when the channel or query is reinstated. They are saved to
# ~/.irssi/chankeys on /save, and loaded from there on startup and /reload.
#
### To-do:
#
# * Mappings for {01..99} and associated hook to renumber windows with named
#   mappings
# * Handle queries better, i.e. they should be created if not found, probably
#   just use /query instead of /window goto
# * When adding a keymap from /chankey add, if the keymap is already assigned
#   to another channel, we need to handle this better
# * check_for_existing_bind really hurts and causes a bit of lag in Irssi that
#   it doesn't recover from for a few seconds after load. Better to read /bind
#   output once into a hash and use that.
#
use strict;
use warnings;
use Irssi;
use version;

our %IRSSI = (
    authors     => 'martin f. krafft',
    contact     => 'madduck@madduck.net',
    name        => 'chankeys',
    description => 'manage channel keyboard shortcuts',
    license     => 'MIT',
    version     => '0.4',
    changed     => '2021-11-03'
);

our $VERSION = $IRSSI{version};
my $_VERSION = version->parse($VERSION);

### DEFAULTS AND SETTINGS ######################################################

my $map_file = Irssi::get_irssi_dir()."/chankeys";
my $go_command = 'window goto $C';
my $autosave = 1;
my $overwrite_binds = 0;
my $clear_composites = 0;
my $debug = 0;

Irssi::settings_add_str('chankeys', 'chankeys_go_command', $go_command);
Irssi::settings_add_bool('chankeys', 'chankeys_autosave', $autosave);
Irssi::settings_add_bool('chankeys', 'chankeys_overwrite_binds', $overwrite_binds);
Irssi::settings_add_bool('chankeys', 'chankeys_clear_composites', $clear_composites);
Irssi::settings_add_bool('chankeys', 'chankeys_debug', $debug);

sub sig_setup_changed {
	$debug = Irssi::settings_get_bool('chankeys_debug');
	$clear_composites = Irssi::settings_get_bool('chankeys_clear_composites');
	$overwrite_binds = Irssi::settings_get_bool('chankeys_overwrite_binds');
	$autosave = Irssi::settings_get_bool('chankeys_autosave');
	$go_command = Irssi::settings_get_str('chankeys_go_command');
}
Irssi::signal_add('setup changed', \&sig_setup_changed);
Irssi::signal_add('setup reread', \&sig_setup_changed);
sig_setup_changed();

my $changed_since_last_save = 0;

my %itemmap;
my %leadkeys;

### HELPERS ####################################################################

sub say {
	my ($msg, $level, $inwin) = @_;
	$level = $level // MSGLEVEL_CLIENTCRAP;
	if ($inwin) {
		Irssi::active_win->print("chankeys: $msg", $level);
	}
	else {
		Irssi::print("chankeys: $msg", $level);
	}
}

sub debug {
	return unless $debug;
	my ($msg, $inwin) = @_;
	$msg = $msg // "";
	say("DEBUG: ".$msg, MSGLEVEL_CRAP + MSGLEVEL_NO_ACT, $inwin);
}

sub info {
	my ($msg, $inwin) = @_;
	say($msg, MSGLEVEL_CLIENTCRAP, $inwin);
}

use Data::Dumper;
sub dumper {
	debug(scalar Dumper(@_), 1);
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

sub channet_pair_to_string {
	my ($name, $chatnet) = @_;
	my $ret = $chatnet ? "$chatnet/" : '';
	return $ret . $name;
}

sub string_to_channet_pair {
	my ($str) = @_;
	return reverse(split(/\//, $str));
}

sub get_keymap_for_channet_pair {
	my ($name, $chatnet) = @_;
	foreach my $cn ($chatnet, undef) {
		# if not found with $chatnet, fallback to no chatnet
		my $item = channet_pair_to_string($name, $cn);
		my $keys = $itemmap{$item};
		return ($keys, $name, $cn) if $keys;
	}
	return ();
}

sub get_go_command {
	my ($name, $chatnet) = @_;
	my $cmd = $go_command;
	$cmd =~ s/\$C/$name/;
	$cmd =~ s/\$chatnet/$chatnet/;
	$cmd =~ s/\s+$//;
	return $cmd;
}

my $keybind_to_check;
my $existing_binding;
sub check_existing_binds {
	my ($rec, undef, $text) = @_;
	if ($rec->{level} == 524288 and $rec->{target} eq '' and !defined $rec->{server}) {
		if ($text =~ /^\Q${keybind_to_check}\E\s+(.+?)\s*$/) {
			$existing_binding = $1;
		}
		Irssi::signal_stop();
	}
}

sub check_for_existing_bind {
	my ($keys) = @_;
	$keybind_to_check = $keys;
	$existing_binding = undef;
	Irssi::signal_add_first('print text' => \&check_existing_binds);
	Irssi::command("bind $keybind_to_check");
	Irssi::signal_remove('print text' => \&check_existing_binds);
	return $existing_binding;
}

## KEYMAP HANDLERS #############################################################

sub create_keymapping {
	my ($keys, $name, $chatnet) = @_;
	my $cmd = 'command ' . get_go_command($name, $chatnet);
	if ($keys =~ /(meta-.)-.+/ and !exists($leadkeys{$1})) {
		if (my $bind = check_for_existing_bind($1)) {
			if ($clear_composites) {
				warning("Removing bind from $1 to '$bind' as instructed");
				Irssi::command("^bind -delete $1");
				$leadkeys{$1} = $bind;
			}
			else {
				error("$1 is bound to '$bind' and cannot be used in composite keybinding", 1);
				return 0;
			}
		}
	}
	Irssi::command("^bind $keys $cmd");
	return 1;
}

sub check_create_keymapping {
	my ($keys, $name, $chatnet) = @_;
	my $cmd = 'command ' . get_go_command($name, $chatnet);
	my $bind = check_for_existing_bind($keys);
	if ($bind and $bind ne $cmd) {
		if ($overwrite_binds) {
			warning("Overwriting bind from $keys to '$bind' as instructed");
		}
		else {
			error("Key $keys already bound to '$bind', please remove first.", 1);
			return 0;
		}
	}
	return create_keymapping($keys, $name, $chatnet);
}

sub add_keymapping {
	my ($keys, $name, $chatnet) = @_;
	if (check_create_keymapping($keys, $name, $chatnet)) {
		$name = channet_pair_to_string($name, $chatnet);
		debug("Key binding created: $keys → $name", 1);
		return 1;
	}
	return 0;
}

sub remove_keymapping {
	my ($keys) = @_;
	my $bind = check_for_existing_bind($keys);
	if (!$bind) {
		error("No chankey mapping for $keys");
		return;
	}
	my $item = lookup_item_by_keys($keys);
	if ($item) {
		Irssi::command("^bind -delete $keys");
		return $bind;
	}
	else {
		error("The key binding for '$keys' is not a chankeys binding: $bind");
		return;
	}
}

sub lookup_item_by_keys {
	my ($data) = @_;
	my $ret;
	while (my ($item, $keys) = each %itemmap) {
		$ret = $item if ($keys eq $data);
		# do not call last or the iterator won't be reset
	}
	return $ret;
}

sub remove_existing_binds {
	while (my ($item, $keys) = each %itemmap) {
		Irssi::command("^bind -delete $keys");
	}
	%leadkeys = ();
}

### SAVING AND LOADING #########################################################

sub get_mappings_fh {
	my ($filename) = @_;
	my $fh;
	if (! -e $filename) {
		save_mappings($filename);
		info("Created new/empty mappings file: $filename");
	}
	open($fh, '<', $filename) || error("Cannot open mappings file: $!");
	return $fh;
}

sub load_mappings {
	my ($filename) = @_;
	%itemmap = ();
	my $fh = get_mappings_fh($filename);
	my $firstline = <$fh> || error("Cannot read from $filename.");;
	my $version;
	if ($firstline =~ m/^;+\s+chankeys keymap file \(version: *([\d.]+)\)/) {
		$version = $1;
	}
	else {
		error("First line of $filename is not a chankey header.");
	}

	my $l = 1;
	while (<$fh>) {
		$l++;
		next if m/^\s*(?:;|$)/;
		my ($item, $keys, $rest) = split;
		if ($rest) {
			error("Cannot parse $filename:$l: $_");
			return;
		}
		$itemmap{$item} = $keys;
	}
	close($fh) || error("Cannot close mappings file: $!");
}

sub save_mappings {
	my ($filename) = @_;
	open(FH, '+>', $filename) || error("Cannot create mappings file: $!");
	print FH <<"EOF";
; chankeys keymap file (version: $_VERSION)
;
; WARNING: this file will be overwritten on /save,
; use "/set chankey_autosave off" to avoid.
;
; item: channel name (optionally chatnet/#channel) or query partner
; keys: key combination
;
; item	keys

EOF
	while (my ($name, $keys) = each %itemmap) {
		print FH "$name\t$keys\n";
	}
	print FH <<"EOF";

; EXAMPLES
;
;;; associate meta-s-meta-i with the #irssi channel
; libera/#irssi	meta-s-meta-i
;
;;; associate F12 with the bitlbee control window
; &bitlbee	F12
;
;;; associate meta-\ with a query
; bitlbee/sgs7e	meta-\\

; vim:noet:tw=0:ts=48:com=b\\:;
EOF
	close(FH);
}

## COMMAND HANDLERS ############################################################

sub chankey_add {
	my ($data, $server, $witem) = @_;
	my ($keys, $name, $chatnet) = split /\s+/, $data;
	if ($name) {
		($name, $chatnet) = string_to_channet_pair($name) unless $chatnet;
	}
	else {
		if (!$witem) {
			error("No active window item to add a channel key for", 1);
			return;
		}
		$name = $witem->{name};
		$chatnet = $server->{chatnet};
	}
	if (add_keymapping($keys, $name, $chatnet)) {
		$itemmap{channet_pair_to_string($name, $chatnet)} = $keys;
		$changed_since_last_save = 1;
	}
}

sub chankey_remove {
	my ($data) = @_;
	return unless $data;
	my $bind = remove_keymapping($data);
	if ($bind) {
		debug("Key binding removed: $data (was: $bind)");
		my $item = lookup_item_by_keys($data);
		delete($itemmap{$item});
		$changed_since_last_save = 1;
	}
}

sub chankey_list {
	return unless %itemmap;
	info("Key bindings I know about:", 1);
	foreach my $item (sort keys %itemmap) {
		my $keys = $itemmap{$item};
		my $active;
		if (my $bind = check_for_existing_bind($keys)) {
			my ($name, $chatnet) = string_to_channet_pair($item);
			$active = $bind eq ('command ' . get_go_command($name, $chatnet));
		}
		my $out = sprintf("%13s %1s %s", $keys, $active ? '→' : '', $item);
		info($out, 1);
	}
}

sub chankey_load {
	remove_existing_binds();
	load_mappings($map_file);
	my $cnt = scalar(keys %itemmap);
	foreach my $channel (Irssi::channels, Irssi::queries) {
		my $name = $channel->{name};
		my $chatnet = $channel->{server}->{chatnet};
		if (my @keymap = get_keymap_for_channet_pair($name, $chatnet)) {
			create_keymapping(@keymap);
		}
	}
	$changed_since_last_save = 0;
	info("Loaded $cnt mappings from $map_file");
}

sub chankey_save {
	my ($args) = @_;
	if (!$changed_since_last_save and $args ne '-force') {
		info("Not saving unchanged mappings without -force");
		return;
	}
	autosave(1);
}

sub chankey_goto {
	my ($args) = @_;
	my ($name, $chatnet) = split /\s+/, $args;
	my $cmd = get_go_command($name, $chatnet);
	Irssi::command("^$cmd");
}

Irssi::command_bind('chankeys add', \&chankey_add);
Irssi::command_bind('chankeys remove', \&chankey_remove);
Irssi::command_bind('chankeys list', \&chankey_list);
Irssi::command_bind('chankeys reload', \&chankey_load);
Irssi::command_bind('chankeys save', \&chankey_save);
Irssi::command_bind('chankeys goto', \&chankey_goto);
Irssi::command_bind('chankeys help', \&chankey_help);
Irssi::command_bind('chankeys', sub {
		my ( $data, $server, $item ) = @_;
		$data =~ s/\s+$//g;
		if ($data) {
			Irssi::command_runsub('chankeys', $data, $server, $item);
		}
		else {
			chankey_help();
		}
	}
);
Irssi::command_bind('help', sub {
		$_[0] =~ s/\s+$//g;
		return unless $_[0] eq 'chankeys';
		chankey_help();
		Irssi::signal_stop();
	}
);

sub chankey_help {
	my ($data, $server, $item) = @_;
	Irssi::print (<<"SCRIPTHELP_EOF", MSGLEVEL_CLIENTCRAP);
%_chankeys $_VERSION - associate key shortcuts with channels

%U%_Synopsis%_%U

%_CHANKEYS ADD%_ <%Ukeybinding%U> [<%Uchannel%U>] [<%Uchatnet%U>]
%_CHANKEYS REMOVE%_ <%Ukeybinding%U>
%_CHANKEYS LIST%_
%_CHANKEYS [RE]LOAD%_
%_CHANKEYS SAVE%_ [-force]
%_CHANKEYS GOTO%_ <%Uchannel%U> [<%Uchatnet%U>]
%_CHANKEYS HELP%_

<%Ukeybinding%U> %| Key(s) to bind. Refer to %_/HELP BIND%_ for format
<%Uchannel%U>    %| Channel name to associate. Can include %_/chatnet%.
<%Uchatnet%U>    %| The chatnet of the channel. Not generally supported.

%U%_Settings%_%U

/set %_chankeys_go_command%_ [$go_command]
  %| The command to use to switch to a matching window item. The only reason
  %| you might need to set this is if you have channels with the same name
  %| across different chatnets. In this case, you need to load the go2.pl
  %| module, and set this to "go \$C \$chatnet", because "window goto" cannot
  %| incorporate the chatnet (yet). Beware that this will prevent
  %| adv_windowlist.pl from reading out the keybinding to use for the
  %| statusbar.

/set %_chankeys_overwrite_binds%_ [$overwrite_binds]
  %| When chankey encounters an existing key mapping, it refuses to overwrite
  %| it unless this is switched on.

/set %_chankeys_clear_composites%_ [$clear_composites]
  %| A mapping like meta-s-meta-i will not work if meta-s is bound to something
  %| already, and chankey will check and fail in such a case. Setting this
  %| to on will make chankeys remove the existing mapping, such that the
  %| composite mapping works.

/set %_chankeys_autosave%_ [$autosave]
  %| Skip saving/overwriting the chankeys setup to file if you prefer to
  %| maintain the mappings outside of irssi.

/set %_chankeys_debug%_ [$debug]
  %| Turns on debug output. Not that this may itself be buggy, so please don't
  %| use it unless you really need it.

%U%_Examples%_%U

Associate %_meta-d-meta-d%_ with the current channel
  %|%#/%_CHANKEYS ADD%_ meta-d-meta-d

Associate F12 with the &bitlbee window
  %|%#/%_BIND%_ ^[[24~ key F12
  %|%#/%_CHANKEYS ADD%_ F12 &bitlbee

Associate %_meta-m-meta-m%_ with the #matrix channel on LiberaChat
  %|%#/%_CHANKEYS ADD%_ meta-m-meta-m #matrix LiberaChat

Alternative form to specify chatnet
  %|%#/%_CHANKEYS ADD%_ meta-m-meta-m #matrix/LiberaChat

Save mappings to file ($map_file), using -force to write even if nothing has changed:
  %|%#/%_CHANKEYS SAVE%_ -force

Load mappings from file ($map_file):
  %|%#/%_CHANKEYS LOAD%_

List all known key associations
  %|%#/%_CHANKEYS LIST%_
SCRIPTHELP_EOF
}

## SIGNAL HANDLERS #############################################################

sub on_channel_created {
	my ($chanrec, $auto) = @_;
	my $name = $chanrec->{name};
	my $chatnet = $chanrec->{server}->{chatnet};
	my @keymap = get_keymap_for_channet_pair($name, $chatnet);
	add_keymapping(@keymap) if @keymap;
}
Irssi::signal_add('channel created' => \&on_channel_created);
Irssi::signal_add('query created' => \&on_channel_created);

sub on_channel_destroyed {
	my ($chanrec) = @_;
	my $name = $chanrec->{name};
	my $chatnet = $chanrec->{server}->{chatnet};
	my ($keys, undef, undef) = get_keymap_for_channet_pair($name, $chatnet);
	remove_keymapping($keys) if $keys;
}
Irssi::signal_add('channel destroyed' => \&on_channel_destroyed);
Irssi::signal_add('query destroyed' => \&on_channel_destroyed);

sub autosave {
	my ($force) = @_;
	return unless $changed_since_last_save or $force;
	if (!$autosave) {
		info("Not saving mappings due to chankeys_autosave setting");
		return;
	}
	info("Saving mappings to $map_file");
	save_mappings($map_file);
	$changed_since_last_save = 0;
}

sub UNLOAD {
	autosave();
}

Irssi::signal_add('setup saved', \&autosave);
Irssi::signal_add('setup reread', \&chankey_load);

## INIT ########################################################################

chankey_load();
