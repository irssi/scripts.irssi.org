use strict;
use warnings;
use Irssi;
use Irssi::TextUI;

our $VERSION = '0.2'; # 6c39400282189a0
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'sbclearmatch',
    description => 'clear matching lines in scrollback',
    license     => 'GPLv2 or later',
);

sub cmd_help {
    my ($args) = @_;
    if ($args =~ /^scrollback *$/i) {
	print CLIENTCRAP <<HELP

SCROLLBACK CLEARMATCH [-level <level>] [-regexp] [-case] [-word] [-all] [<pattern>]

    CLEARMATCH: Clears the screen and the buffer of matching text.

    -regexp:    The given text pattern is a regular expression.
    -case:      Performs a case-sensitive matching.
    -word:      The text must match full words.
HELP

    }
}


sub cmd_sb_clearmatch {
    my ($args, $server, $witem) = @_;
    my ($options, $pattern) = Irssi::command_parse_options('scrollback clearmatch', $args);

    my $level;
    if (defined $options->{level}) {
	$level = $options->{level};
	$level =~ y/,/ /;
	$level = Irssi::combine_level(0, $level);
    }
    else {
	return unless length $pattern;
	$level = MSGLEVEL_ALL;
    }

    my $regex;
    if (length $pattern) {
	my $flags = defined $options->{case} ? '' : '(?i)';
	my $b = defined $options->{word} ? '\b' : '';
	if (defined $options->{regexp}) {
	    local $@;
	    eval { $regex = qr/$flags$b$pattern$b/; 1 }
		or do {
		    print CLIENTERROR "Pattern did not compile: " . do { $@ =~ /(.*) at / && $1 };
		    return;
		};
	}
	else {
	    $regex = qr/$flags$b\Q$pattern\E$b/;
	}
    }

    my $current_win = ref $witem ? $witem->window : Irssi::active_win;

    for my $win (defined $options->{all} ? Irssi::windows : $current_win) {
	my $view = $win->view;
	my $line = $view->get_lines;
	my $need_redraw;
	my $bottom = $view->{bottom};

	while ($line) {
	    my $line_level = $line->{info}{level};
	    my $next = $line->next;
	    if ($line_level & $level && $line->get_text(0) =~ $regex) {
		$view->remove_line($line);
		$need_redraw = 1;
	    }
	    $line = $next;
	}

	if ($need_redraw) {
	    $win->command('^scrollback end') if $bottom && !$win->view->{bottom};
	    $view->redraw;
	}
    }
}

Irssi::command_bind        'scrollback clearmatch' => 'cmd_sb_clearmatch';
Irssi::command_set_options 'scrollback clearmatch' => '-level regexp case word all';
Irssi::command_bind_last 'help' => 'cmd_help';
