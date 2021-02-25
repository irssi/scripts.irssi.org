use strict;
use warnings;
use experimental 'signatures';

our $VERSION = '0.3'; # 90d307aaaf70a32
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'partial',
    description => 'partial tab completion for Irssi',
    license     => 'ISC',
   );

# Usage
# =====
# Complete only as many characters as uniquely possible while using
# tab completion.
#

# If you disable completion_default_partial, you can bind another key
# to invoke partial completion:
#
#   /bind meta-/ /script exec Irssi::Script::partial::partial_word_completion
#
# If you want to have another key to do regular completion, while
# completion_default_partial is enabled:
#
#   /bind meta-/ /script exec Irssi::Script::partial::word_completion
#
# Note: you cannot change completion mode in the middle of an ongoing
# completion! Your completion key will continue to operate in the way
# that it was initiated with.

# Options
# =======
# /set completion_default_partial <ON|OFF>
# * If the default tab completion should use partial
#
# /set completion_suggest_partial <ON|OFF>
# * If partial completions should be suggested when you continue to
#   press the completion key
#
# /set completion_partial_display <ON|OFF>
# * If partial completions should be printed to the window
#
# /set completion_partial_display_max <num>
# * Maximum number of partial completions allowed inside one display
#   item

# For another implementation of the same idea, check
# https://github.com/aquanight/codejunk/blob/master/perl/irssi/bash_tab.pl

use Tree::Trie;
use List::Util qw(min pairvalues);

use Irssi;

my $completing = 0;
my $suggest_partial;
my $partial_display;
my $partial_threshold;

our $partial_complete;

sub complete_to ($trie, $word) {
    my @next = map {
	if ($partial_threshold < 0 || $trie->lookup("$word$_") < $partial_threshold) {
	    [ $_, 1 ]
	} else {
	    my $x = $_;
	    map { [ "$x$_", 2 ] } $trie->lookup("$word$_", 1)
	}
    } $trie->lookup($word, 1);

    for my $n (@next) {
	my @nn = $trie->lookup("$word$n->[0]", 1);
	if (@nn == 1 && length $nn[0]) {
	    $n->[0] .= $nn[0];
	    redo;
	}
    }
    sort { (min pairvalues $trie->lookup_data("$word$a->[0]") ) <=> (min pairvalues $trie->lookup_data("$word$b->[0]") ) }
    @next
}

sub clear_partial_sug ($win, $view) {
    my $line = $view->get_bookmark('partial');
    if (defined $line) {
        my $bottom = $view->{bottom};
        $view->remove_line($line);
        $win->command('^scrollback end') if $bottom && !$win->view->{bottom};
        $view->redraw;
    }
}

sub _show ($trie, $pre, $post) {
    return $pre unless length $post->[0];

    my $w1 = "$pre\cB" . (substr $post->[0], 0, $post->[1]) . "\cB" . substr $post->[0], $post->[1];
    my $c = $trie->lookup("$pre$post->[0]");
    if ($c > 1) {
	$w1 .= "…($c)";
    }
    $w1
}

sub print_next ($trie, $word, @next) {
    my $win = Irssi::active_win;
    my $view = $win->view;

    unless (@next) {
	clear_partial_sug($win, $view);
	return;
    }

    my $sug = join ' ', map { _show($trie, $word, $_) }
	@next;
    $win->print($sug);
    clear_partial_sug($win, $view);
    $view->set_bookmark_bottom('partial');
}

sub key_partial_clear {
    my $win = Irssi::active_win;
    clear_partial_sug($win, $win->view);
    $completing = 0;
}

sub key_partial_complete_stop {
    $completing = 0;
}

sub key_clear_completions {
    return if $completing;
    local our $clear_completions = 1;
    Irssi::signal_emit('key word_completion', '', $_[1], $_[2])
}

sub partial_complete ($list, $window, $word, $linestart, $want_space) {
    $completing = 1;

    if (our $clear_completions) {
	@$list = ();
	Irssi::signal_stop;
	return;
    }

    if (!our $partial_complete) {
	return;
    }

    &Irssi::signal_continue;

    if (@$list > 1) {
	my $trie = Tree::Trie->new;
	$trie->deepsearch('count');
	my $idx = 1;
	$trie->add_data(map { ( $_, $idx++ ) } @$list);
	my @next = complete_to($trie, $word);
	if (@next == 1) {
	    $word = "$word$next[0][0]";
	    @$list = $word;
	    @next = complete_to($trie, $word);
	    $$want_space = 0
		if @next;
	}
	else {
	    if ($suggest_partial) {
		@$list = ($word, map { "$word$_->[0]" } @next);
		$$want_space = 0;
	    }
	    else {
		@$list = ();
	    }
	}
	print_next($trie, $word, @next)
	    if $partial_display;
    }
}

sub partial_word_completion {
    local our $partial_complete = 1;
    Irssi::signal_emit('key word_completion', '', 0, undef);
}

sub partial_word_completion_backward {
    local our $partial_complete = 1;
    Irssi::signal_emit('key word_completion_backward', '', 0, undef);
}

sub word_completion {
    local our $partial_complete = 0;
    Irssi::signal_emit('key word_completion', '', 0, undef);
}

sub word_completion_backward {
    local our $partial_complete = 0;
    Irssi::signal_emit('key word_completion_backward', '', 0, undef);
}

sub init_partial {
    $partial_complete = Irssi::settings_get_bool('completion_default_partial');
    $suggest_partial = Irssi::settings_get_bool('completion_suggest_partial');
    $partial_display = Irssi::settings_get_bool('completion_partial_display');
    $partial_threshold = Irssi::settings_get_int('completion_partial_display_max');
}

Irssi::settings_add_bool('completion', 'completion_suggest_partial', 1);
Irssi::settings_add_bool('completion', 'completion_default_partial', 1);
Irssi::settings_add_bool('completion', 'completion_partial_display', 1);
Irssi::settings_add_int('completion', 'completion_partial_display_max', 40);

Irssi::signal_register({ "key " => [qw[string ulongptr Irssi::UI::Keyinfo]] });

Irssi::signal_add_first('complete word', 'partial_complete');
Irssi::signal_add_first('key backspace', 'key_clear_completions');
Irssi::signal_add('key check_replaces', 'key_partial_complete_stop');
Irssi::signal_add('key send_line', 'key_partial_clear');
Irssi::signal_add('setup changed', 'init_partial');

init_partial();
