#
# For the full matterircd_complete experience, your matterircd.toml
# should have SuffixContext=true, ThreadContext="mattermost", and
# Unicode=true.
#
# Add it to ~/.irssi/scripts/autorun, or:
#
#   /script load ~/.irssi/scripts/matterircd_complete.pl
#   /set matterircd_complete_networks <...>
#
# NOTE: It is important to set which networks to enable plugin for per
# above ^.
#
# Bind message/thread ID completion to a key to make it easier to
# reply to threads:
#
#   /bind ^G /message_thread_id_search
#
# Also bind to insert nicknames:
#
#   /bind ^F /nicknames_search
#
# (Or pick your own shortcut keys to bind to).
#
# Then:
#
#   Ctrl+g - Insert latest message/thread ID.
#   Ctrl+c - Abort inserting message/thread ID. Also clears existing.
#
#   @@+TAB to tab auto-complete message/thread ID.
#   @ +TAB to tab auto-complete IRC nick. Active users appear first.
#
# By default, message/thread IDs are shortened from 26 characters to
# first few (default 5). It is also grayed out to try reduce noise and
# make it easier to read conversations. To disable this use:
#
#   /set matterircd_complete_shorten_message_thread_id 0
#
# Use the dump commands to show the contents of the cache:
#
#   /matterircd_complete_msgthreadid_cache_dump
#   /matterircd_complete_nick_cache_dump
#
# (You can bind these to keys).
#
# To increase or decrease the size of the cache, use:
#
#   /set matterircd_complete_message_thread_id_cache_size 50
#   /set matterircd_complete_nick_cache_size 20
#
# To ignore specific nicks in autocomplete:
#
#   /set matterircd_complete_nick_ignore somebot anotherbot

use strict;
use warnings;
use experimental 'smartmatch';

require Irssi::TextUI;
require Irssi;

# Enable for debugging purposes only.
# use Data::Dumper;

our $VERSION = '2.00';  # e2973ff
our %IRSSI = (
    name        => 'Matterircd Tab Auto Complete',
    description => 'Adds tab completion for Matterircd message threads',
    authors     => 'Haw Loeung',
    contact     => 'hloeung/Freenode',
    license     => 'GPL',
);

my $KEY_CTRL_C = 3;
my $KEY_CTRL_U = 21;
my $KEY_ESC    = 27;
my $KEY_RET    = 13;
my $KEY_SPC    = 32;
my $KEY_B      = 66;
my $KEY_O      = 79;

Irssi::settings_add_str('matterircd_complete', 'matterircd_complete_networks', '');
Irssi::settings_add_str('matterircd_complete', 'matterircd_complete_nick_ignore', '');
Irssi::settings_add_str('matterircd_complete', 'matterircd_complete_channel_dont_ignore', '');


sub _wi_print {
    my ($wi, $msg) = @_;

    if ($wi) {
        $wi->print($msg);
    } else {
        Irssi::print($msg);
    }
}

#==============================================================================
my %color_config;

# Taken from nickcolor_expando irssi script
# These are all the colors, sorted by main color class
# To display and select colors you want/want to avoid based on your background, use /cubes_text from cubes.pl
my @all_colors = (
    qw[20 30 40 50 04 66 0C 61 60 67 6L], # RED
    qw[37 3D 36 4C 46 5C 56 6C 6J 47 5D 6K 6D 57 6E 5E 4E 4K 4J 5J 4D 5K 6R], # ORANGE
    qw[3C 4I 5I 6O 6I 06 4O 5O 3U 0E 5U 6U 6V 6P 6Q 6W 5P 4P 4V 4W 5W 4Q 5Q 5R 6Y 6X], # YELLOW
    qw[26 2D 2C 3I 3O 4U 5V 2J 3V 3P 3J 5X], # YELLOW-GREEN
    qw[16 1C 2I 2U 2O 1I 1O 1V 1P 02 0A 1U 2V 4X], # GREEN
    qw[1D 1J 1Q 1W 1X 2Y 2S 2R 3Y 3Z 3S 3R 2K 3K 4S 5Z 5Y 4R 3Q 2Q 2X 2W 3X 3W 2P 4Y], # GREEN-TURQUOIS
    qw[17 1E 1L 1K 1R 1S 03 1M 1N 1T 0B 1Y 1Z 2Z 4Z], # TURQUOIS
    qw[28 2E 18 1F 19 1G 1A 1B 1H 2N 2H 09 3H 3N 2T 3T 2M 2G 2A 2F 2L 3L 3F 4M 3M 3G 29 4T 5T], # LIGHT-BLUE
    qw[22 33 44 0D 45 5B 6A 5A 5H 3B 4H 3A 4G 39 4F 6S 6T 5L 5N], # VIOLET
    qw[21 32 42 53 63 52 43 34 35 55 65 6B 4B 4A 48 5G 6H 5M 6M 6N], # PINK
    qw[38 31 05 64 54 41 51 62 69 68 59 5F 6F 58 49 6G], # ROSE
    qw[11 12 23 25 24 13 14 01 15 2B 4N], # DARK-BLUE
    qw[7A 00 10 7B 7C 7D 7E 7G 7F], # DARK-GRAY
    qw[7H 7I 27 7K 7J 08 7L 3E 7O 7Q 7N 7M 7P], # GRAY
    qw[7S 7T 7R 4L 7W 7U 7V 5S 07 7X 6Z 0F], # LIGHT-GRAY
);
# These are the colors unwanted with a dark theme
my @dark_theme_unwanted = (
    qw[11 12 23 25 24 13 14 01 15 2B 4N], # DARK-BLUE
    qw[7A 00 10 7B 7C 7D 7E 7G 7F], # DARK-GRAY
    qw[7H 7I 27 7K 7J 08 7L 3E 7O 7Q 7N 7M 7P], # GRAY
    qw[7S 7T 7R 4L 7W 7U 7V 5S 07 7X 6Z 0F], # LIGHT-GRAY
);
# These are the colors unwanted with a light theme
my @solarized_light_theme_unwanted = (
    qw[4U 4V 4W 4X 4Y 4Z 5U 5V 5W 5X 5Y 5Z 6U 6V 6W 6X 6Y 6Z 6O 6P 6Q 6R 6S 6T], # too light flashy colors
    qw[7T 7U 7V 7W 7X 07 7R 7S 7T 7U 7V 7W 7X 7B 7C 7D 7E 7F 7H 7I 7J 7K 7M 7N 7O 7P], # too light grayscales
    qw[5S 4L 7Q 5T 4T 4M 5M 6M 6N 1Z 2Z 1Y 2X 2W 3X 3W 1U 2V 1X 2Y 3V 3Z 3Y 2U], # hand picked too light + redundant
);

Irssi::settings_add_int('matterircd_complete', 'matterircd_complete_thread_id_color', -1);
# Default color theme to none, so we use all available colors.
Irssi::settings_add_str('matterircd_complete', 'matterircd_complete_thread_id_color_theme', '');
Irssi::settings_add_bool('matterircd_complete', 'matterircd_complete_thread_id_allow_bold', 0);
Irssi::settings_add_bool('matterircd_complete', 'matterircd_complete_thread_id_allow_italic', 0);
Irssi::settings_add_bool('matterircd_complete', 'matterircd_complete_thread_id_allow_underline', 0);
# Allowed colors will be applied first
# These can be a list of 20 30 40 50 5F colors, or without spaces 203040505F
Irssi::settings_add_str('matterircd_complete', 'matterircd_complete_thread_id_allowed_colors', '');
Irssi::settings_add_str('matterircd_complete', 'matterircd_complete_thread_id_unwanted_colors', '');
$color_config{'color_theme'} = '';
$color_config{'allowed_colors'} = '';
$color_config{'unwanted_colors'} = '';
# Initialize
my @thread_id_selected_colors = ();

# Rely on message/thread IDs stored in message cache so we can shorten
# to save on screen real-estate.
Irssi::settings_add_int('matterircd_complete',  'matterircd_complete_shorten_message_thread_id', 5);
Irssi::settings_add_bool('matterircd_complete', 'matterircd_complete_shorten_message_thread_id_hide_prefix', 1);
Irssi::settings_add_str('matterircd_complete', 'matterircd_complete_override_reply_prefix', '↪');

# Taken from nickcolor_expando irssi script and adapted for our use
sub xcolor_to_irssi {
    # Set to foreground xcolor
    my $c = "X".$_[0];
    my @ext_colour_off = (
    '.', '-', ',',
    '+', "'", '&',
    );
    if ($c =~ /^(X)(?:0([[:xdigit:]])|([1-6])(?:([0-9])|([a-z]))|7([a-x]))$/i) {
        my $bg = $1 eq 'x';
        my $col = defined $2 ? hex $2
            : defined $6 ? 232 + (ord lc $6) - (ord 'a')
            : 16 + 36 * ($3 - 1) + (defined $4 ? $4 : 10 + (ord lc $5) - (ord 'a'));
        if ($col < 0x10) {
            my $chr = chr $col + ord '0';
            return "\cD" . ($bg ? "/$chr" : "$chr/");
        }
        else {
            return "\cD" . $ext_colour_off[($col - 0x10) / 0x50 + $bg * 3] . chr (($col - 0x10) % 0x50 - 1 + ord '0');
        }
    } else {
        return $c;
    }
}

sub get_thread_format {
    my ($str) = @_;
    my @nums = (0..9,'a'..'z');
    my $chr=join('',@nums);
    my %nums = map { $nums[$_] => $_ } 0..$#nums;
    my $n = 0;
    $str = lc $str;
    foreach ($str =~ /[$chr]/g) {
        $n += $nums{$_} * 36;
    }
    my @colors = @thread_id_selected_colors;
    my $color_count = @colors;

    # We have normal, bold, italic, underline
    my $allow_bold = Irssi::settings_get_bool('matterircd_complete_thread_id_allow_bold');
    my $allow_italic = Irssi::settings_get_bool('matterircd_complete_thread_id_allow_italic');
    my $allow_underline = Irssi::settings_get_bool('matterircd_complete_thread_id_allow_underline');
    my @classes_prepend;
    push @classes_prepend, "\x02" if $allow_bold;
    push @classes_prepend, "\x1d" if $allow_italic;
    push @classes_prepend, "\x1f" if $allow_underline;
    my $classes = 1 + @classes_prepend;
    $n = $n % $color_count*$classes;
    my $random = $n;
    my $prepend = "";
    if ($classes == 4 and $n >= $color_count*3) {
        $n -= $color_count*3;
        $prepend = $classes_prepend[2];
    } elsif ($classes ge 3 and $n >= $color_count*2) {
        $n -= $color_count*2;
        $prepend = $classes_prepend[1];
    } elsif ($classes ge 2 and $n >= $color_count) {
        $n -= $color_count;
        $prepend = $classes_prepend[0];
    }
    $n = $colors[$n-1];
    return $n, $prepend;
}

sub thread_color {
    my ($str) = @_;
    my ($n, $prepend) = get_thread_format($str);
    # Pick the color in the allowed_color list.
    # n should be comprised between 1 and the array length.
    $n = xcolor_to_irssi($n);
    $n = "$prepend\x03$n";
    return $n;
}
sub cmd_matterircd_complete_thread_id_get_color {
    my ($data, $server, $wi) = @_;
    my ($color, $prepend) = get_thread_format($_[0]);
    my $n = xcolor_to_irssi($color);
    _wi_print($wi, "Thread color for $prepend\x03$n$_[0]\x0f is $color");
}
Irssi::command_bind('matterircd_complete_thread_id_get_color', 'cmd_matterircd_complete_thread_id_get_color');

sub update_msgthreadid {
    my($server, $msg, $nick, $address, $target) = @_;

    return unless Irssi::settings_get_int('matterircd_complete_shorten_message_thread_id');
    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    my $prefix = '';
    my $msgthreadid = '';
    my $msgpostid = '';
    my $reply_prefix = Irssi::settings_get_str('matterircd_complete_override_reply_prefix');

    if ($msg =~ s/\[(->|↪)?\@\@([0-9a-z]{26})(?:,\@\@([0-9a-z]{26}))?\]/\@\@PLACEHOLDER\@\@/) {
        $prefix = $reply_prefix ? $reply_prefix : $1 if $1;
        $msgthreadid = $2;
        $msgpostid = $3 ? $3 : '';
    }
    return unless $msgthreadid;

    my $thread_color = Irssi::settings_get_int('matterircd_complete_thread_id_color');
    if ($thread_color == -1) {
        $thread_color = thread_color($msgthreadid);
    } else {
        $thread_color = "\x03${thread_color}";
    }

    # Show that message is reply to a thread. (backwards compatibility
    # when matterircd doesn't show reply)
    if ((not $prefix) && ($msg =~ /\(re \@.*\)/)) {
        $prefix = $reply_prefix;
    }

    if (not Irssi::settings_get_bool('matterircd_complete_shorten_message_thread_id_hide_prefix')) {
        $prefix = "${prefix}\@\@";
    }

    my $len = Irssi::settings_get_int('matterircd_complete_shorten_message_thread_id');
    if ($len < 25) {
        # Shorten to length configured. We use unicode ellipsis (...)
        # here to both allow word selection to just select parts of
        # the message/thread ID when copying & pasting and save on
        # screen real estate.
        $msgthreadid = substr($msgthreadid, 0, $len) . '…';
        if ($msgpostid ne '') {
            $msgpostid = substr($msgpostid, 0, $len) . '…';
        }
    }
    if ($msgpostid eq '') {
        $msg =~ s/\@\@PLACEHOLDER\@\@/${thread_color}[${prefix}${msgthreadid}]\x0f/;
    } else {
        $msg =~ s/\@\@PLACEHOLDER\@\@/${thread_color}[${prefix}${msgthreadid},${msgpostid}]\x0f/;
    }

    Irssi::signal_continue($server, $msg, $nick, $address, $target);
}
Irssi::signal_add_last('message irc action', 'update_msgthreadid');
Irssi::signal_add_last('message irc notice', 'update_msgthreadid');
Irssi::signal_add_last('message private', 'update_msgthreadid');
Irssi::signal_add_last('message public', 'update_msgthreadid');

sub cache_store {
    my ($cache_ref, $item, $cache_size) = @_;

    return unless $item ne '';

    my $changed = 0;
    if ((@$cache_ref[0]) && (@$cache_ref[0] eq $item)) {
        return $changed;
    }
    $changed = 1;

    # We want to reduce duplicates by removing them currently in the
    # per-channel cache. But as a trade off in favor of
    # speed/performance, rather than traverse the entire per-channel
    # cache, we cap/limit it.
    my $limit = 16;
    my $max = ($#$cache_ref < $limit)? $#$cache_ref : $limit;
    for my $i (0 .. $max) {
        if ((@$cache_ref[$i]) && (@$cache_ref[$i] eq $item)) {
            splice(@$cache_ref, $i, 1);
        }
    }

    unshift(@$cache_ref, $item);
    if (($cache_size > 0) && (scalar(@$cache_ref) > $cache_size)) {
        pop(@$cache_ref);
    }

    return $changed;
}


#==============================================================================

# Adds tab-complete or keybinding insertion of messages/threads
# seen. This makes it easier for replying directly to threads in
# Mattermost or creating new threads.


my %MSGTHREADID_CACHE;
Irssi::settings_add_int('matterircd_complete', 'matterircd_complete_message_thread_id_cache_size', 50);
sub cmd_matterircd_complete_msgthreadid_cache_dump {
    my ($data, $server, $wi) = @_;

    if (not $data) {
        return unless ref $wi and ($wi->{type} eq 'CHANNEL' or $wi->{type} eq 'QUERY');
    }

    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    my $channel = $data ? $data : $wi->{name};
    # Remove leading and trailing whitespace.
    $channel =~ tr/ 	//d;

    _wi_print($wi, "${channel}: Message/Thread ID cache");

    if ((not exists($MSGTHREADID_CACHE{$channel})) || (scalar @{$MSGTHREADID_CACHE{$channel}} == 0)) {
        _wi_print($wi, "${channel}: Empty");
        return;
    }

    foreach my $msgthread_id (@{$MSGTHREADID_CACHE{$channel}}) {
        _wi_print($wi, "${channel}: ${msgthread_id}");
    }
    _wi_print($wi, "${channel}: Total: " . scalar @{$MSGTHREADID_CACHE{$channel}});
};
Irssi::command_bind('matterircd_complete_msgthreadid_cache_dump', 'cmd_matterircd_complete_msgthreadid_cache_dump');

my $MSGTHREADID_CACHE_SEARCH_ENABLED = 0;
my $MSGTHREADID_CACHE_INDEX = 0;
sub cmd_message_thread_id_search {
    my ($data, $server, $wi) = @_;

    return unless Irssi::settings_get_int('matterircd_complete_message_thread_id_cache_size');
    return unless ref $wi and ($wi->{type} eq 'CHANNEL' or $wi->{type} eq 'QUERY');
    return unless exists($MSGTHREADID_CACHE{$wi->{name}});

    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    $MSGTHREADID_CACHE_SEARCH_ENABLED = 1;
    my $msgthreadid = $MSGTHREADID_CACHE{$wi->{name}}[$MSGTHREADID_CACHE_INDEX];
    $MSGTHREADID_CACHE_INDEX += 1;
    if ($MSGTHREADID_CACHE_INDEX > $#{$MSGTHREADID_CACHE{$wi->{name}}}) {
        # Cycle back to the start.
        $MSGTHREADID_CACHE_INDEX = 0;
    }

    if ($msgthreadid) {
        # Save input text.
        my $input = Irssi::parse_special('$L');
        # Remove existing thread.
        $input =~ s/^@@(?:[0-9a-z]{26}|[0-9a-f]{3}) //;
        # Insert message/thread ID from cache.
        Irssi::gui_input_set_pos(0);
        Irssi::gui_input_set("\@\@${msgthreadid} ${input}");
    }
};
Irssi::command_bind('message_thread_id_search', 'cmd_message_thread_id_search');

my $ESC_PRESSED = 0;
my $O_PRESSED   = 0;
sub signal_gui_key_pressed_msgthreadid {
    my ($key) = @_;

    return unless $MSGTHREADID_CACHE_SEARCH_ENABLED;

    my $server = Irssi::active_server();
    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    if (($key == $KEY_RET) || ($key == $KEY_CTRL_U)) {
        $MSGTHREADID_CACHE_INDEX = 0;
        $MSGTHREADID_CACHE_SEARCH_ENABLED = 0;

        $ESC_PRESSED = 0;
        $O_PRESSED = 0;
    }

    # Cancel/abort, so remove thread stuff.
    elsif ($key == $KEY_CTRL_C) {
        my $input = Irssi::parse_special('$L');

        # Remove the Ctrl+C character.
        $input =~ tr///d;

        my $pos = 0;
        if ($input =~ s/^(@@(?:[0-9a-z]{26}|[0-9a-f]{3}) )//) {
            $pos = Irssi::gui_input_get_pos() - length($1);
        }

        # We also want to move the input position back one for Ctrl+C
        # char.
        $pos = $pos > 0 ? $pos - 1 : 0;

        # Replace the text in the input box with our modified version,
        # then move cursor positon to where it was without the
        # message/thread ID.
        Irssi::gui_input_set($input);
        Irssi::gui_input_set_pos($pos);

        $MSGTHREADID_CACHE_INDEX = 0;
        $MSGTHREADID_CACHE_SEARCH_ENABLED = 0;

        $ESC_PRESSED = 0;
        $O_PRESSED = 0;
    }

    # For 'down arrow', it's a sequence of ESC + O + B.
    elsif ($key == $KEY_ESC) {
        $ESC_PRESSED = 1;
    }
    elsif ($key == $KEY_O) {
        $O_PRESSED = 1;
    }
    elsif ($key == $KEY_B && $O_PRESSED && $ESC_PRESSED) {
        $MSGTHREADID_CACHE_INDEX = 0;
        $MSGTHREADID_CACHE_SEARCH_ENABLED = 0;

        $ESC_PRESSED = 0;
        $O_PRESSED = 0;
    }
    # Reset sequence on any other keys pressed.
    elsif ($O_PRESSED || $ESC_PRESSED) {
        $ESC_PRESSED = 0;
        $O_PRESSED = 0;
    }
};
Irssi::signal_add_last('gui key pressed', 'signal_gui_key_pressed_msgthreadid');

sub signal_complete_word_msgthread_id {
    my ($complist, $window, $word, $linestart, $want_space) = @_;

    # We only want to tab-complete message/thread if this is the first
    # word on the line.
    return if $linestart;
    return unless Irssi::settings_get_int('matterircd_complete_message_thread_id_cache_size');
    return if (substr($word, 0, 1) eq '@' and substr($word, 0, 2) ne '@@');
    return unless $window->{active} and ($window->{active}->{type} eq 'CHANNEL' || $window->{active}->{type} eq 'QUERY');
    return unless exists($MSGTHREADID_CACHE{$window->{active}->{name}});

    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$window->{active_server}->{chatnet}};

    if (substr($word, 0, 2) eq '@@') {
        $word = substr($word, 2);
    }

    foreach my $msgthread_id (@{$MSGTHREADID_CACHE{$window->{active}->{name}}}) {
        if ($msgthread_id =~ /^\Q$word\E/) {
            push(@$complist, "\@\@${msgthread_id}");
        }
    }
};
Irssi::signal_add_last('complete word', 'signal_complete_word_msgthread_id');

my $MSGTHREADID_CACHE_STATS = 0;
sub cache_msgthreadid {
    my($server, $msg, $nick, $address, $target) = @_;

    return unless Irssi::settings_get_int('matterircd_complete_message_thread_id_cache_size');
    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    my @msgids = ();

    my @ignore_nicks = split(/\s+/, Irssi::settings_get_str('matterircd_complete_nick_ignore'));
    # Ignore nicks configured to be ignored such as bots.
    if ($nick ~~ @ignore_nicks) {
        # But not if the channel is in matterircd_complete_channel_dont_ignore.
        my @channel_dont_ignore = split(/\s+/, Irssi::settings_get_str('matterircd_complete_channel_dont_ignore'));
        if ($target !~ @channel_dont_ignore) {
            return;
        }
    }

    # We also want to ignore reactions as we can't reply to those
    # directly if they're to a message in a thread.
    if ($msg =~ /(?:added|removed) reaction:/) {
        return;
    }

    # Mattermost message/thread IDs.
    if ($msg =~ /\[(?:->|↪)?\@\@([0-9a-z]{26})(?:,\@\@([0-9a-z]{26}))?\]/) {
        my $msgthreadid = $1;
        my $msgpostid = $2 ? $2 : '';

        if ($msgpostid ne '') {
            push(@msgids, $msgpostid);
        }
        push(@msgids, $msgthreadid);
    }
    # matterircd generated 3-letter hexadecimal.
    elsif ($msg =~ /(?:^\[([0-9a-f]{3})\])|(?:\[([0-9a-f]{3})\]\s*$)/) {
        push(@msgids, $1 ? $1 : $2);
    }
    # matterircd generated 3-letter hexadecimal replying to threads.
    elsif ($msg =~ /(?:^\[[0-9a-f]{3}->([0-9a-f]{3})\])|(?:\[[0-9a-f]{3}->([0-9a-f]{3})\]\s*$)/) {
        push(@msgids, $1 ? $1 : $2);
    }
    else {
        return;
    }

    my $key;
    if (substr($target, 0, 1) eq '#') {
        # It's a channel, so use $target
        $key = $target;
    } else {
        # It's a private query so use $nick
        $key = $nick
    }

    my $cache_size = Irssi::settings_get_int('matterircd_complete_message_thread_id_cache_size');
    for my $msgid (@msgids) {
        if (cache_store(\@{$MSGTHREADID_CACHE{$key}}, $msgid, $cache_size)) {
            $MSGTHREADID_CACHE_INDEX = 0;
            stats_increment(\$MSGTHREADID_CACHE_STATS);
        }
    }
}
Irssi::signal_add('message irc action', 'cache_msgthreadid');
Irssi::signal_add('message irc notice', 'cache_msgthreadid');
Irssi::signal_add('message private', 'cache_msgthreadid');
Irssi::signal_add('message public', 'cache_msgthreadid');

Irssi::settings_add_bool('matterircd_complete', 'matterircd_complete_reply_msg_thread_id_at_start', 1);

sub signal_message_own_public_msgthreadid {
    my($server, $msg, $target) = @_;

    return unless Irssi::settings_get_int('matterircd_complete_message_thread_id_cache_size');
    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    if ($msg !~ /^@@((?:[0-9a-z]{26})|(?:[0-9a-f]{3}))/) {
        return;
    }
    my $msgid = $1;

    my $cache_size = Irssi::settings_get_int('matterircd_complete_message_thread_id_cache_size');
    if (cache_store(\@{$MSGTHREADID_CACHE{$target}}, $msgid, $cache_size)) {
        $MSGTHREADID_CACHE_INDEX = 0;
        stats_increment(\$MSGTHREADID_CACHE_STATS);
    }

    my $msgthreadid = $1;

    my $thread_color = Irssi::settings_get_int('matterircd_complete_thread_id_color');
    if ($thread_color == -1) {
        $thread_color = thread_color($msgthreadid);
    } else {
        $thread_color = "\x03${thread_color}";
    }

    my $len = Irssi::settings_get_int('matterircd_complete_shorten_message_thread_id');
    if ($len < 25) {
        # Shorten to length configured. We use unicode ellipsis (...)
        # here to both allow word selection to just select parts of
        # the message/thread ID when copying & pasting and save on
        # screen real estate.
        $msgthreadid = substr($msgid, 0, $len) . "…";
    }

    my $reply_prefix = Irssi::settings_get_str('matterircd_complete_override_reply_prefix');
    if (Irssi::settings_get_bool('matterircd_complete_reply_msg_thread_id_at_start')) {
        $msg =~ s/^@@[0-9a-z]{26} /${thread_color}[${reply_prefix}${msgthreadid}]\x0f /;
    } else {
        $msg =~ s/^@@[0-9a-z]{26} //;
        $msg =~ s/$/ ${thread_color}[${reply_prefix}${msgthreadid}]\x0f/;
    }

    Irssi::signal_continue($server, $msg, $target);
};
Irssi::signal_add_last('message own_public', 'signal_message_own_public_msgthreadid');

sub signal_message_own_private {
    my($server, $msg, $target, $orig_target) = @_;

    return unless Irssi::settings_get_int('matterircd_complete_message_thread_id_cache_size');
    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    if ($msg !~ /^@@((?:[0-9a-z]{26})|(?:[0-9a-f]{3}))/) {
        return;
    }
    my $msgid = $1;

    my $cache_size = Irssi::settings_get_int('matterircd_complete_message_thread_id_cache_size');
    if (cache_store(\@{$MSGTHREADID_CACHE{$target}}, $msgid, $cache_size)) {
        $MSGTHREADID_CACHE_INDEX = 0;
        stats_increment(\$MSGTHREADID_CACHE_STATS);
    }

    my $msgthreadid = $1;

    my $thread_color = Irssi::settings_get_int('matterircd_complete_thread_id_color');
    if ($thread_color == -1) {
        $thread_color = thread_color($msgthreadid);
    } else {
        $thread_color = "\x03${thread_color}";
    }

    my $len = Irssi::settings_get_int('matterircd_complete_shorten_message_thread_id');
    if ($len < 25) {
        # Shorten to length configured. We use unicode ellipsis (...)
        # here to both allow word selection to just select parts of
        # the message/thread ID when copying & pasting and save on
        # screen real estate.
        $msgthreadid = substr($msgid, 0, $len) . "…";
    }

    my $reply_prefix = Irssi::settings_get_str('matterircd_complete_override_reply_prefix');
    if (Irssi::settings_get_bool('matterircd_complete_reply_msg_thread_id_at_start')) {
        $msg =~ s/^@@[0-9a-z]{26} /${thread_color}[${reply_prefix}${msgthreadid}]\x0f /;
    } else {
        $msg =~ s/^@@[0-9a-z]{26} //;
        $msg =~ s/$/ ${thread_color}[${reply_prefix}${msgthreadid}]\x0f/;
    }

    Irssi::signal_continue($server, $msg, $target, $orig_target);
};
Irssi::signal_add_last('message own_private', 'signal_message_own_private');


#==============================================================================

# Adds tab-complete or keybinding insertion of nicknames for users in
# the current channel. Similar to irssi's builtin, recently active
# users/nicks will be first in the completion list.


my %NICKNAMES_CACHE;
Irssi::settings_add_int('matterircd_complete', 'matterircd_complete_nick_cache_size', 20);
sub cmd_matterircd_complete_nick_cache_dump {
    my ($data, $server, $wi) = @_;

    if (not $data) {
        return unless ref $wi and ($wi->{type} eq 'CHANNEL' or $wi->{type} eq 'QUERY');
    }

    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    my $channel = $data ? $data : $wi->{name};
    # Remove leading and trailing whitespace.
    $channel =~ tr/ 	//d;

    _wi_print($wi, "${channel}: Nicknames cache");

    if ((not exists($NICKNAMES_CACHE{$channel})) || (scalar @{$NICKNAMES_CACHE{$channel}} == 0)) {
        _wi_print($wi,"${channel}: Empty");
        return;
    }

    foreach my $nick (@{$NICKNAMES_CACHE{$channel}}) {
        _wi_print($wi, "${channel}: ${nick}");
    }
    _wi_print($wi, "${channel}: Total: " . scalar @{$NICKNAMES_CACHE{$channel}});
};
Irssi::command_bind('matterircd_complete_nick_cache_dump', 'cmd_matterircd_complete_nick_cache_dump');

sub signal_complete_word_nicks {
    my ($complist, $window, $word, $linestart, $want_space) = @_;

    return if substr($word, 0, 2) eq '@@';
    return unless $window->{active} and $window->{active}->{type} eq 'CHANNEL';

    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$window->{active_server}->{chatnet}};

    if (substr($word, 0, 1) eq '@') {
        $word = substr($word, 1);
    }
    my $compl_char = Irssi::settings_get_str('completion_char');
    my $own_nick = $window->{active}->{ownnick}->{nick};
    my @ignore_nicks = split(/\s+/, Irssi::settings_get_str('matterircd_complete_nick_ignore'));

    # We need to store the results in a temporary array so we can
    # sort.
    my @tmp;
    foreach my $cur ($window->{active}->nicks()) {
        my $nick = $cur->{nick};
        # Ignore our own nick.
        if ($nick eq $own_nick) {
            next;
        }
        # Ignore nicks configured to be ignored such as bots.
        elsif ($nick ~~ @ignore_nicks) {
            next;
        }
        # Only those matching partial word.
        elsif ($nick =~ /^\Q$word\E/i) {
            push(@tmp, $nick);
        }
    }
    @tmp = sort @tmp;
    foreach my $nick (@tmp) {
        # Only add completion character on line start.
        if (not $linestart) {
            push(@$complist, "\@${nick}${compl_char}");
        } else {
            push(@$complist, "\@${nick}");
        }
    }

    return unless exists($NICKNAMES_CACHE{$window->{active}->{name}});

    # We use the populated cache so frequent and active users in
    # channel come before those idling there. e.g. In a channel where
    # @barryp talks more often, it will come before @barry-m. We also
    # want to make sure users are still in channel for those still in
    # the cache.
    foreach my $nick (reverse @{$NICKNAMES_CACHE{$window->{active}->{name}}}) {
        my $nick_compl;
        # Only add completion character on line start.
        if (not $linestart) {
            $nick_compl = "\@${nick}${compl_char}";
        } else {
            $nick_compl = "\@${nick}";
        }
        # Skip over if nick is already first in completion list.
        if ((scalar(@{$complist}) > 0) and ($nick_compl eq @{$complist}[0])) {
            next;
        }
        # Only add to completion list if user/nick is online and in channel.
        elsif (${nick} ~~ @tmp) {
            # Only add completion character on line start.
            if (not $linestart) {
                unshift(@$complist, "\@${nick}${compl_char}");
            } else {
                unshift(@$complist, "\@${nick}");
            }
        }
    }
};
Irssi::signal_add('complete word', 'signal_complete_word_nicks');

my $NICKNAMES_CACHE_STATS = 0;
sub cache_ircnick {
    my($server, $msg, $nick, $address, $target) = @_;

    return unless Irssi::settings_get_int('matterircd_complete_nick_cache_size');
    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    my $cache_size = Irssi::settings_get_int('matterircd_complete_nick_cache_size');
    my @ignore_nicks = split(/\s+/, Irssi::settings_get_str('matterircd_complete_nick_ignore'));
    # Ignore nicks configured to be ignored such as bots.
    if ($nick !~ @ignore_nicks) {
        if (cache_store(\@{$NICKNAMES_CACHE{$target}}, $nick, $cache_size)) {
            stats_increment(\$NICKNAMES_CACHE_STATS);
        }
    }
}
Irssi::signal_add('message irc action', 'cache_ircnick');
Irssi::signal_add('message irc notice', 'cache_ircnick');
Irssi::signal_add('message public', 'cache_ircnick');

sub signal_message_own_public_nicks {
    my($server, $msg, $target) = @_;

    return unless Irssi::settings_get_int('matterircd_complete_nick_cache_size');
    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    if ($msg !~ /^@([^@ \t:,\)]+)/) {
        return;
    }
    my $nick = $1;

    my $cache_size = Irssi::settings_get_int('matterircd_complete_nick_cache_size');
    # We want to make sure that the nick or user is still online and
    # in the channel.
    my $wi = $server->window_item_find($target);
    if (not defined $wi) {
        return;
    }
    foreach my $cur ($wi->nicks()) {
        if ($nick eq $cur->{nick}) {
            if (cache_store(\@{$NICKNAMES_CACHE{$target}}, $nick, $cache_size, 1)) {
                stats_increment(\$NICKNAMES_CACHE_STATS);
            }
            last;
        }
    }
};
Irssi::signal_add_last('message own_public', 'signal_message_own_public_nicks');

my @NICKNAMES_CACHE_SEARCH;
my $NICKNAMES_CACHE_SEARCH_ENABLED = 0;
my $NICKNAMES_CACHE_INDEX = 0;
sub cmd_nicknames_search {
    my ($data, $server, $wi) = @_;

    return unless ref $wi and $wi->{type} eq 'CHANNEL';

    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    my $own_nick = $wi->{ownnick}->{nick};
    my @ignore_nicks = split(/\s+/, Irssi::settings_get_str('matterircd_complete_nick_ignore'));

    @NICKNAMES_CACHE_SEARCH = ();
    foreach my $cur ($wi->nicks()) {
        my $nick = $cur->{nick};
        # Ignore our own nick.
        if ($nick eq $own_nick) {
            next;
        }
        # Ignore nicks configured to be ignored such as bots.
        elsif ($nick ~~ @ignore_nicks) {
            next;
        }
        push(@NICKNAMES_CACHE_SEARCH, $nick);
    }
    @NICKNAMES_CACHE_SEARCH = sort @NICKNAMES_CACHE_SEARCH;

    if (exists($NICKNAMES_CACHE{$wi->{name}})) {
        # We use the populated cache so frequent and active users in
        # channel come before those idling there. e.g. In a channel
        # where @barryp talks more often, it will come before
        # @barry-m.  We also want to make sure users are still in
        # channel for those still in the cache.
        foreach my $nick (reverse @{$NICKNAMES_CACHE{$wi->{name}}}) {
            # Skip over if nick is already first in completion list.
            if ((scalar(@NICKNAMES_CACHE_SEARCH) > 0) and ($nick eq $NICKNAMES_CACHE_SEARCH[0])) {
                next;
            }
            # Only add to completion list if user/nick is online and
            # in channel.
            elsif ($nick ~~ @NICKNAMES_CACHE_SEARCH) {
                unshift(@NICKNAMES_CACHE_SEARCH, $nick);
            }
        }
    }

    $NICKNAMES_CACHE_SEARCH_ENABLED = 1;
    my $nickname = $NICKNAMES_CACHE_SEARCH[$NICKNAMES_CACHE_INDEX];
    $NICKNAMES_CACHE_INDEX += 1;
    if ($NICKNAMES_CACHE_INDEX > $#NICKNAMES_CACHE_SEARCH) {
        # Cycle back to the start.
        $NICKNAMES_CACHE_INDEX = 0;
    }

    if ($nickname) {
        # Save input text.
        my $input = Irssi::parse_special('$L');
        my $compl_char = Irssi::settings_get_str('completion_char');
        # Remove any existing nickname and insert one from the cache.
        my $msgid = "";
        if ($input =~ s/^(\@\@(?:[0-9a-z]{26}|[0-9a-f]{3}) )//) {
            $msgid = $1;
        }
        $input =~ s/^\@[^${compl_char}]+$compl_char //;
        Irssi::gui_input_set_pos(0);
        Irssi::gui_input_set("${msgid}\@${nickname}${compl_char} ${input}");
    }
};
Irssi::command_bind('nicknames_search', 'cmd_nicknames_search');

sub signal_gui_key_pressed_nicks {
    my ($key) = @_;

    return unless $NICKNAMES_CACHE_SEARCH_ENABLED;

    my $server = Irssi::active_server();
    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    if (($key == $KEY_RET) || ($key == $KEY_CTRL_U)) {
        $NICKNAMES_CACHE_INDEX = 0;
        $NICKNAMES_CACHE_SEARCH_ENABLED = 0;
        @NICKNAMES_CACHE_SEARCH = ();
    }

    # Cancel/abort, so remove current nickname.
    elsif ($key == $KEY_CTRL_C) {
        my $input = Irssi::parse_special('$L');

        # Remove the Ctrl+C character.
        $input =~ tr///d;

        my $compl_char = Irssi::settings_get_str('completion_char');
        my $pos = 0;
        if ($input =~ s/^(\@[^${compl_char}]+$compl_char )//) {
            $pos = Irssi::gui_input_get_pos() - length($1);
        }

        # We also want to move the input position back one for Ctrl+C
        # char.
        $pos = $pos > 0 ? $pos - 1 : 0;

        # Replace the text in the input box with our modified version,
        # then move cursor positon to where it was without the
        # current nickname.
        Irssi::gui_input_set($input);
        Irssi::gui_input_set_pos($pos);

        $NICKNAMES_CACHE_INDEX = 0;
        $NICKNAMES_CACHE_SEARCH_ENABLED = 0;
        @NICKNAMES_CACHE_SEARCH = ();
    }
};
Irssi::signal_add_last('gui key pressed', 'signal_gui_key_pressed_nicks');


#==============================================================================

# The replied cache keeps an index of messages/thread IDs that we've
# replied to then when others reply to those, it will insert our nick
# so that any further replies to these threads will be hilighted.


my %REPLIED_CACHE;
Irssi::settings_add_int('matterircd_complete', 'matterircd_complete_replied_cache_size', 50);
sub cmd_matterircd_complete_replied_cache_dump {
    my ($data, $server, $wi) = @_;

    if (not $data) {
        return unless ref $wi and ($wi->{type} eq 'CHANNEL' or $wi->{type} eq 'QUERY');
    }

    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    my $channel = $data ? $data : $wi->{name};
    # Remove leading and trailing whitespace.
    $channel =~ tr/ 	//d;

    _wi_print($wi, "${channel}: Replied cache");

    if ((not exists($REPLIED_CACHE{$channel})) || (scalar @{$REPLIED_CACHE{$channel}} == 0)) {
        _wi_print($wi, "${channel}: Empty");
        return;
    }

    foreach my $threadid (@{$REPLIED_CACHE{$channel}}) {
        _wi_print($wi, "${channel}: ${threadid}");
    }
    _wi_print($wi, "${channel}: Total: " . scalar @{$REPLIED_CACHE{$channel}});
};
Irssi::command_bind('matterircd_complete_replied_cache_dump', 'cmd_matterircd_complete_replied_cache_dump');

my $REPLIED_CACHE_STATS = 0;
sub cmd_matterircd_complete_replied_cache_clear {
    my ($data, $server, $wi) = @_;

    my $channel;
    my @msgids = ();
    my @args = ();
    if ($data) {
        @args = split(/\s+/, $data);
    }

    if (scalar(@args) == 0 || $args[0] eq '*') {
        stats_increment(\$REPLIED_CACHE_STATS);
        _wi_print($wi, "matterircd_complete replied cache cleared");
        return;
    }

    if (exists($REPLIED_CACHE{$args[0]}) || exists($REPLIED_CACHE{"#${args[0]}"})) {
        $channel = shift(@args);
        if (rindex($channel, "#", 0) == -1) {
            $channel = "#${channel}";
        }
    } elsif ($wi->{name}) {
        $channel = $wi->{name};
    } else {
        return;
    }
    @msgids = @args;

    if (scalar(@msgids) > 0) {
        foreach my $id (@msgids) {
            my $i = 0;
            if (rindex($id, "@@", 0) == 0) {
                $id = substr($id, 2);
            }
            foreach my $msgid (@{$REPLIED_CACHE{$channel}}) {
                if ($id eq $msgid) {
                    splice(@{$REPLIED_CACHE{$channel}}, $i, 1);
                    stats_increment(\$REPLIED_CACHE_STATS);
                    _wi_print($wi, "matterircd_complete replied cache removed ${id} from ${channel} cache");
                    last;
                }
                $i += 1;
            }
        }
    } else {
        @{$REPLIED_CACHE{$channel}} = ();
        stats_increment(\$REPLIED_CACHE_STATS);
        _wi_print($wi, "matterircd_complete replied cache cleared for channel ${channel}");
    }
};
Irssi::command_bind('matterircd_complete_replied_cache_clear', 'cmd_matterircd_complete_replied_cache_clear');

my $REPLIED_CACHE_CLEARED = 0;
Irssi::settings_add_bool('matterircd_complete', 'matterircd_complete_clear_replied_cache_on_away', 0);
sub signal_away_mode_changed {
    my ($server) = @_;

    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    # When you visit the web UI when marked away, it retriggers this
    # event. Let's avoid that.
    if (! $server->{usermode_away}) {
        $REPLIED_CACHE_CLEARED = 0;
    }

    if (Irssi::settings_get_bool('matterircd_complete_clear_replied_cache_on_away') && $server->{usermode_away} && (! $REPLIED_CACHE_CLEARED)) {
        %REPLIED_CACHE = ();
        $REPLIED_CACHE_CLEARED = 1;
        Irssi::print("matterircd_complete replied cache cleared");
    }
};
Irssi::signal_add('away mode changed', 'signal_away_mode_changed');

sub signal_message_own_public_replied {
    my($server, $msg, $target) = @_;

    return unless Irssi::settings_get_int('matterircd_complete_replied_cache_size');
    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    if ($msg !~ /^@@((?:[0-9a-z]{26})|(?:[0-9a-f]{3}))/) {
        return;
    }
    my $msgid = $1;

    my $cache_size = Irssi::settings_get_int('matterircd_complete_replied_cache_size');
    if (cache_store(\@{$REPLIED_CACHE{$target}}, $msgid, $cache_size)) {
        stats_increment(\$REPLIED_CACHE_STATS);
    }
};
Irssi::signal_add('message own_public', 'signal_message_own_public_replied');

sub signal_message_public {
    my($server, $msg, $nick, $address, $target) = @_;

    return unless Irssi::settings_get_int('matterircd_complete_replied_cache_size');
    my %chatnets = map { $_ => 1 } split(/\s+/, Irssi::settings_get_str('matterircd_complete_networks'));
    return unless exists $chatnets{'*'} || exists $chatnets{$server->{chatnet}};

    # For '/me' actions, it has trailing space so we need to use
    # \s* here.
    $msg =~ /\[(?:->|↪)?\@\@([0-9a-z]{26})[\],]/;
    my $msgthreadid = $1;
    return unless $msgthreadid;

    if ($msgthreadid ~~ @{$REPLIED_CACHE{$target}}) {
        # Add user's (or our own) nick for hilighting if not in
        # message and message not from us.
        if (($nick ne $server->{nick}) && ($msg !~ /\@$server->{nick}/)) {
            $msg =~ s/\(re (\@\S+): /(re \@$server->{nick}, $1: /;
        }
    }

    Irssi::signal_continue($server, $msg, $nick, $address, $target);
};
Irssi::signal_add('message public', 'signal_message_public');

# Remove an array's elements per their values
sub array_splice_values {
    my ($ar_ref, $uw_ref) = @_;
    my @array = @{$ar_ref};
    my @unwanted = @{$uw_ref};
    my %removals = map { $_ => 1 } @unwanted;
    my @keys = keys %removals;
    my @indices = grep { exists($removals{$array[$_]}) } 0..$#array;
    # Each time we remove index from @arr, the next correct index to delete will be reduced of $o
    my $o = 0;
    for (@indices) {
        splice(@array, $_-$o, 1);
        $o++;
    }
    return @array;
}

sub setup_colors {
    # Skip colors setup if we're using a fixed color
    my $fixed_color = Irssi::settings_get_int('matterircd_complete_thread_id_color');
    return if $fixed_color ne -1;

    my $allowed_colors = Irssi::settings_get_str('matterircd_complete_thread_id_allowed_colors');
    $allowed_colors = uc $allowed_colors;
    my $unwanted_colors = Irssi::settings_get_str('matterircd_complete_thread_id_unwanted_colors');
    $unwanted_colors = uc $unwanted_colors;
    my $color_theme = Irssi::settings_get_str('matterircd_complete_thread_id_color_theme');
    $color_theme = lc $color_theme;
    my @colors;

    if ($allowed_colors =~ /^[0-9A-Z]{2}( [0-9A-Z]{2})*$/) {
        @colors = split(' ', $allowed_colors);
        Irssi::print("[matterircd_complete] Setting allowed colors: @colors");
    } elsif ($allowed_colors =~ /^[0-9A-Z]{2}([0-9A-Z]{2})*$/ and length($allowed_colors) % 2 == 0) {
        @colors = ( $allowed_colors =~ m/../g );
        Irssi::print("[matterircd_complete] Setting allowed colors: @colors");
    } elsif (length($allowed_colors) != 0) {
        Irssi::print("[matterircd_complete] Ignoring matterircd_complete_thread_id_allowed_colors: invalid format ($allowed_colors)");
    } else {
        Irssi::print("[matterircd_complete] Setting allowed colors to all colors");
        @colors = @all_colors;
    }

    if (length($color_theme) != 0) {
        if ($color_theme eq "dark") {
            Irssi::print("[matterircd_complete] Removing colors incompatible with dark theme");
            @colors = array_splice_values(\@colors, \@dark_theme_unwanted);
        } elsif ($color_theme eq 'solarized-light') {
            Irssi::print("[matterircd_complete] Removing colors incompatible with solarized-light theme");
            @colors = array_splice_values(\@colors, \@solarized_light_theme_unwanted);
        } else {
            Irssi::print("[matterircd_complete] Ignoring unknown color theme $color_theme");
            Irssi::print("[matterircd_complete] Valid themes are dark, solarized-light");
        }
    }

    if ($unwanted_colors =~ /^[0-9A-Z]{2}( [0-9A-Z]{2})*$/) {
        my @unwanted = split(' ', $unwanted_colors);
        Irssi::print("[matterircd_complete] Removing unwanted colors");
        @colors = array_splice_values(\@colors, \@unwanted);
    } elsif ($unwanted_colors =~ /^[0-9A-Z]{2}([0-9A-Z]{2})*$/ and length($unwanted_colors) % 2 == 0) {
        my @unwanted = ($unwanted_colors =~ m/../g);
        Irssi::print("[matterircd_complete] Removing unwanted colors");
        @colors = array_splice_values(\@colors, \@unwanted);
    } elsif (length($unwanted_colors)) {
        Irssi::print("[matterircd_complete] Ignoring matterircd_complete_thread_id_unwanted_colors: invalid format ($unwanted_colors)");
    }

    if (@thread_id_selected_colors) {
        Irssi::print("[matterircd_complete] Config changed, existing threads might change colors!")
            if $allowed_colors ne $color_config{"allowed_colors"}
                    or $unwanted_colors ne $color_config{"unwanted_colors"}
                    or $color_theme ne $color_config{"color_theme"};
        $color_config{"allowed_colors"} = $allowed_colors;
        $color_config{"unwanted_colors"} = $unwanted_colors;
        $color_config{"color_theme"} = $color_theme;
    } else {
        Irssi::print("[matterircd_complete] Thread colors have been set per your config");
    }
    Irssi::print("[matterircd_complete] You can check colors in use with /matterircd_complete_thread_id_get_colors");
    @thread_id_selected_colors = @colors;
}
Irssi::signal_add('setup changed', 'setup_colors');
Irssi::signal_add('setup reread', 'setup_colors');

sub cmd_matterircd_complete_thread_id_get_colors {
    my ($data, $server, $wi) = @_;

    # Display a warning if we're using a fixed color
    my $fixed_color = Irssi::settings_get_int('matterircd_complete_thread_id_color');
    if ($fixed_color ne -1) {
        _wi_print($wi, "Thread_id_color is not set to -1");
        _wi_print($wi, "Threads will always take \x03${fixed_color}this color\x0f");
        return;
    }

    my $colors_text = "Selected colors: ";
    foreach (@thread_id_selected_colors) {
        my $n = xcolor_to_irssi($_);
        $colors_text .= "\x03$n$_";
    }
    $colors_text .= "\x0f";
    _wi_print($wi, $colors_text);
}
Irssi::command_bind('matterircd_complete_thread_id_get_colors', 'cmd_matterircd_complete_thread_id_get_colors');

Irssi::settings_add_bool('matterircd_complete', 'matterircd_complete_stats_output', 0);
sub stats_increment {
    my ($stats_ref) = @_;

    $$stats_ref += 1;

    # autosave.
    if (($$stats_ref % 100) == 0) {
        my $output = Irssi::settings_get_bool('matterircd_complete_stats_output');
        save_cache($output);
    }
}

my $STARTUP_DATE = localtime();
sub stats_show {
    Irssi::print("[matterircd_complete] Started / loaded since ${STARTUP_DATE}");

    my $total = 0;
    my $entries;
    my $channels;

    my %cache = (
        'MSGTHREADID' => \%MSGTHREADID_CACHE,
        'NICKNAMES' => \%NICKNAMES_CACHE,
        'REPLIED' => \%REPLIED_CACHE,
        );

    my %stats = (
        'MSGTHREADID' => 0,
        'NICKNAMES' => 0,
        'REPLIED' => 0,
        );
    foreach my $key (sort keys %cache) {
        foreach my $channel (sort keys %{$cache{$key}}) {
            my $d = $cache{$key}->{$channel};
            if (scalar(@{$d}) == 0) {
                next;
            }
            $stats{$key} += scalar(@{$d});
        }
        $total += $stats{$key};
    }

    $entries = $stats{'MSGTHREADID'};
    $channels = keys %{$cache{'MSGTHREADID'}};
    Irssi::print("[matterircd_complete] ${entries} entries across ${channels} channels for msg/thread IDs cache (${MSGTHREADID_CACHE_STATS} updates)");

    $entries = $stats{'NICKNAMES'};
    $channels = keys %{$cache{'NICKNAMES'}};
    Irssi::print("[matterircd_complete] ${entries} entries across ${channels} channels for nicknames cache (${NICKNAMES_CACHE_STATS} updates)");

    $entries = $stats{'REPLIED'};
    $channels = keys %{$cache{'REPLIED'}};
    Irssi::print("[matterircd_complete] ${entries} entries across ${channels} channels for threads replied to cache (${REPLIED_CACHE_STATS} updates)");

    my $total_updates = $MSGTHREADID_CACHE_STATS + $NICKNAMES_CACHE_STATS + $REPLIED_CACHE_STATS;
    Irssi::print("[matterircd_complete] \x03%GSaved total of ${total} entries in the cache (${total_updates} total updates)…");
}
Irssi::command_bind('matterircd_complete_stats', 'stats_show');

my $CACHE_FILE = Irssi::get_irssi_dir() . '/matterircd_complete.cache';
my $exited;
sub save_cache {
    my ($output_stats) = @_;

    open(FH, '>', $CACHE_FILE) or do {
        Irssi::print("[matterircd_complete] \x03%RError saving matterircd_complete cache: $!")
            unless $exited;
        return;
    };

    my %cache = (
        'MSGTHREADID' => \%MSGTHREADID_CACHE,
        'NICKNAMES' => \%NICKNAMES_CACHE,
        'REPLIED' => \%REPLIED_CACHE,
        );

    foreach my $key (sort keys %cache) {
        foreach my $channel (sort keys %{$cache{$key}}) {
            my $d = $cache{$key}->{$channel};
            my $entries = join(',', @{$d});
            if (scalar(@{$d}) == 0) {
                next;
            }
            print(FH "${key} ${channel} ${entries}\n");
        }
    }
    close(FH);

    if ($output_stats == 0) {
        return;
    }

    stats_show();
}
Irssi::command_bind('matterircd_complete_cache_save', 'save_cache');

sub load_cache {
    open(FH, '<', $CACHE_FILE) or return;

    my %cache = (
        'MSGTHREADID' => \%MSGTHREADID_CACHE,
        'NICKNAMES' => \%NICKNAMES_CACHE,
        'REPLIED' => \%REPLIED_CACHE,
        );

    my $total = 0;
    while(<FH>) {
        chomp;
        my ($key, $channel, $entries) = split;
        my @d = split(',', $entries);
        $cache{$key}->{$channel} = \@d;
        $total += scalar(@d);
    }
    close(FH);

    Irssi::print("[matterircd_complete] \x03%GLoaded total of ${total} entries from disk cache…");
}

sub UNLOAD {
    return if $exited;
    exit_save();
}

sub exit_save {
    $exited = 1;
    save_cache(1)
}
Irssi::signal_add('gui exit', 'exit_save');

# Set up on load!
setup_colors();
load_cache();
