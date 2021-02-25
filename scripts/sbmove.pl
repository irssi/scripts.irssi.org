use strict;
use warnings;
use Irssi;
use Irssi::TextUI;

our $VERSION = '0.1'; # de90d37dafaf9ed
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'sbmove alpha',
    description => 'move matching lines from scrollback',
    license     => 'GPLv2 or later',
);

sub cmd_help {
    my ($args) = @_;
    if ($args =~ /^scrollback *$/i) {
	print CLIENTCRAP <<HELP

SCROLLBACK MOVE [-window <refnum>] [-level <level>] [-regexp] [-case] [-word] [<pattern>]

    MOVE: Move the scrollback of matching text.

    -regexp:    The given text pattern is a regular expression.
    -case:      Performs a case-sensitive matching.
    -word:      The text must match full words.
HELP

    }
}


sub cmd_sb_move {
    my ($args, $server, $witem) = @_;
    my ($options, $pattern) = Irssi::command_parse_options('scrollback move', $args);

    if (!defined $options->{window}) {
	print CLIENTERROR "No source window";
	return;
    }

    my $win = Irssi::window_find_refnum($options->{window});
    if (!$win) {
	print CLIENTERROR "Window not found";
	return;
    }

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

    my $ow = Irssi::active_win;

    my $view = $win->view;
    my $line = $view->get_lines;
    my $need_redraw;
    my $bottom = $view->{bottom};

    $ow->command('^window scroll off');
    my $oline = $ow->view->get_lines;
    my $obottom = $ow->view->{bottom};

    while ($line) {
	my $line_level = $line->{info}{level};
	my $time = $line->{info}{time};
	my $next = $line->next;
	if ($line_level & $level && $line->get_text(0) =~ $regex) {
	    my $text = $line->get_text(1);
	    $view->remove_line($line);
	    $need_redraw = 1;
	    my $onext = $oline && $oline->{info}{time} < $time ? $oline->next : undef;
	    while ($onext && $onext->{info}{time} < $time) {
		$oline = $onext;
		$onext = $oline->next;
	    }
	    $ow->gui_printtext_after($oline, $line_level, "$text\n", $time);
	    $oline = $ow->last_line_insert;
	}
	$line = $next;
    }

    if ($need_redraw) {
	$win->command('^scrollback end') if $bottom && !$win->view->{bottom};
	$ow->command('^scrollback end') if $obottom && !$ow->view->{bottom};
	$ow->view->redraw;
	$view->redraw;
    }
    $ow->command('^window scroll default');
}

Irssi::command_bind        'scrollback move' => 'cmd_sb_move';
Irssi::command_set_options 'scrollback move' => '-window -level regexp case word';
Irssi::command_bind_last 'help' => 'cmd_help';
