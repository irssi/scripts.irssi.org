use strict;
use warnings;

our $VERSION = '0.4.4';
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'hideshow',
    description => 'Removes and re-adds lines to the Irssi buffer view.',
    license     => 'GNU GPLv2 or later',
   );

# Usage
# =====
# Use this script to hide and re-add lines into your Irssi view. You
# can grab a custom-modified recentdepart.pl to hide smart-filtered
# messages instead of ignore, if you do
#
#  /set recdep_use_hideshow ON
#
# You can use trigger.pl with:
#
#  /trigger add ... -command 'script exec $$Irssi::scripts::hideshow::hide_next = 1'
#
# instead of -stop

# Options
# =======
# /set hideshow_level <levels>
# * list of levels that should be hidden from view
#
# /set hideshow_hide <ON|OFF>
# * if hiding is currently enabled or not. make a key binding to
#   conveniently toggle this setting (see below)

# Commands
# ========
# you can use this key binding:
#
# /bind meta-= command ^toggle hideshow_hide
#
# /scrollback status hidden
# * like /scrollback status, but for the hidden part (some statistics)

no warnings 'redefine';
use constant IN_IRSSI => __PACKAGE__ ne 'main' || $ENV{IRSSI_MOCK};
use Irssi;
use Irssi::TextUI;
use Encode;



sub setc () {
    $IRSSI{name}
}

sub set ($) {
    setc . '_' . $_[0]
}

my (%hidden);

my $dest;

my $HIDE;
my $hide_level;
my $ext_hidden_level = MSGLEVEL_LASTLOG << 1;


sub show_win_lines {
    my $win = shift;
    my $view = $win->view;
    my $vid = $view->{_irssi};
    my $hl = delete $hidden{$vid};
    return unless $hl && %$hl;
    my $redraw;
    my $bottom = $view->{bottom};
    for (my $lp = $view->{buffer}{cur_line}; $lp; $lp = $lp->prev) {
	my $nl = delete $hl->{ $lp->{_irssi} };
	next unless $nl;
	my $ll = $lp;
	for my $i (@$nl) {
	    $win->gui_printtext_after($ll, $i->[1] | MSGLEVEL_NEVER, "${$i}[0]\n", $i->[2]);
	    $ll = $win->last_line_insert;
	    $redraw = 1;
	}
    }
    if ($redraw) {
	$win->command('^scrollback end') if $bottom && !$win->view->{bottom};
	$view->redraw;
    }
    delete $hidden{$vid};
}
sub show_lines {
    for my $win (Irssi::windows) {
	show_win_lines($win);
    }
    %hidden=();
}

sub hide_win_lines {
    my $win = shift;
    my $view = $win->view;
    my $vid = $view->{_irssi};
    my $bottom = $view->{bottom};
    my $redraw;
    my $prev;
    my $lid;
    for (my $lp = $view->{buffer}{cur_line}; $lp; $lp = $prev) {
	$prev = $lp->prev;
	if ($prev && $lp->{info}{level} & ($hide_level | $ext_hidden_level)) {
	    push @{ $hidden{ $vid }
			{ $prev->{_irssi} }
		    }, [ $lp->get_text(1), $lp->{info}{level}, $lp->{info}{time} ],
			$hidden{$vid}{ $lp->{_irssi } } ? @{ (delete $hidden{$vid}{ $lp->{_irssi } }) } : ();
	    $view->remove_line($lp);
	    $redraw = 1;
	}
    }
    if ($redraw) {
	$win->command('^scrollback end') if $bottom && !$win->view->{bottom};
	$view->redraw;
    }
}
sub hide_lines {
    Irssi::signal_remove('gui textbuffer line removed' => 'fix_lines');
    for my $win (Irssi::windows) {
	hide_win_lines($win);
    }
    Irssi::signal_add_last('gui textbuffer line removed' => 'fix_lines');
}

my %hideshow_timed;
sub show_one_timed {
    my $hide = shift;
    for my $win (Irssi::windows) {
	next if $hideshow_timed{ $win->{_irssi} };
	if ($hide) {
	    Irssi::signal_remove('gui textbuffer line removed' => 'fix_lines');
	    hide_win_lines($win);
	    Irssi::signal_add_last('gui textbuffer line removed' => 'fix_lines');
	}
	else {
	    show_win_lines($win);
	}
	$hideshow_timed{$win->{_irssi}} = 1;
	$hideshow_timed{_timer} = Irssi::timeout_add_once(10 + int rand 10, 'show_one_timed', $hide);
	return;
    }
    unless ($hide) {
	show_lines();
    }
    %hideshow_timed = ();
    hideshow() if !!$hide != !!$HIDE;
    return 1;
}
sub hideshow {
    if (exists $hideshow_timed{_timer}) {
	Irssi::timeout_remove(delete $hideshow_timed{_timer});
    }
    %hideshow_timed = ();
    $hideshow_timed{_timer} = Irssi::timeout_add_once(10 + int rand 10, 'show_one_timed', !!$HIDE);
}

sub setup_changed {
    my $old_level = $hide_level;
    $hide_level = Irssi::settings_get_level( set 'level' );
    my $old_hidden = $HIDE;
    $HIDE = Irssi::settings_get_bool( set 'hide' );
    if (!defined $old_hidden || $HIDE != $old_hidden || $old_level != $hide_level) {
	hideshow();
    }
}

sub init_hideshow {
    setup_changed();
    $Irssi::scripts::hideshow::hide_next = undef;
}

sub UNLOAD {
    show_lines();
}

my $multi_msgs_last;

sub prt_text_issue {
    $dest = $_[0];
    my $stripd = $_[2];
    if (ref $dest && $Irssi::scripts::hideshow::hide_next) {
	$multi_msgs_last = undef;
	$dest->{hide} = 1;
	if ($dest->{level} & (MSGLEVEL_QUITS|MSGLEVEL_NICKS)) {
	    $multi_msgs_last = $stripd;
	}
    }
    elsif (ref $dest && $dest->{level} & (MSGLEVEL_QUITS|MSGLEVEL_NICKS)
	       && defined $multi_msgs_last && $multi_msgs_last eq $stripd) {
	$dest->{hide} = 1;
    }
    else {
	$multi_msgs_last = undef;
    }
    $Irssi::scripts::hideshow::hide_next = undef;
}

sub prt_text_ref {
    return unless ref $dest;
    my ($win) = @_;
    if ($HIDE) {
	my $view = $win->view;
	my $vid = $view->{_irssi};
	my $lp = $view->{buffer}{cur_line};
	my $prev = $lp->prev;
	if ($prev && ($dest->{hide} || $lp->{info}{level} & $hide_level)) {
	    my $level = $lp->{info}{level};
	    $level |= $ext_hidden_level if $dest->{hide};
	    push @{ $hidden{ $vid }
			{ $prev->{_irssi} }
		    }, [ $lp->get_text(1), $level, $lp->{info}{time} ];
	    $view->remove_line($lp);
	    delete @{ $hidden{ $vid } }
		{ (grep {
		    $view->{buffer}{first_line}{info}{time} > $hidden{$vid}{$_}[-1][2]
		} keys %{$hidden{$vid}}) };
	    $view->redraw;
	}
    }
    $dest = undef;
}

sub fix_lines {
    my ($view, $rem_line, $prev_line) = @_;
    my $vid = $view->{_irssi};
    my $nl = delete $hidden{$vid}{ $rem_line->{_irssi} };
    if ($nl && $prev_line) {
	push @{ $hidden{$vid} { $prev_line->{_irssi} } }, @$nl
    }
}

sub win_del {
    my ($win) = @_;
    delete $hidden{ $win->view->{_irssi} };
}
Irssi::signal_register({
    'gui textbuffer line removed' => [ qw/Irssi::TextUI::TextBufferView Irssi::TextUI::Line Irssi::TextUI::Line/ ]
});

Irssi::signal_add_last({
    'setup changed'    => 'setup_changed',
    'gui print text finished' => 'prt_text_ref',
    'gui textbuffer line removed' => 'fix_lines',
});
Irssi::signal_add({
    'print text'	      => 'prt_text_issue',
    'window destroyed'	      => 'win_del',
});
Irssi::settings_add_level( setc, set 'level', '' );
Irssi::settings_add_bool( setc, set 'hide', 1 );
Irssi::command_bind({
    'scrollback status' => sub {
	if ($_[0] =~ /\S/) {
	    &Irssi::command_runsub('scrollback status', @_);
	    Irssi::signal_stop;
	}
    },
   'scrollback status hidden' => sub {
       my %vw = map { ($_->view->{_irssi}, $_->{refnum}) } Irssi::windows;
       my ($tl, $ta, $td) = (0, 0, 0);
       for my $v (keys %hidden) {
	   my $hl = $hidden{$v};
	   my ($lc, $dc, $ac) = (0, 0, scalar keys %$hl);
	   for my $k (keys %$hl) {
	       my $ls = $hl->{$k};
	       $lc += @$ls;
	       $dc += 16 + length $_->[0] for @$ls;
	   }
	   $tl += $lc; $ta += $ac; $td += $dc;
	   print CLIENTCRAP sprintf "Window %d: %d lines hidden, %d anchors, %dkB of data", ($vw{$v}//"??"), $lc, $ac, int($dc/1024);
       }
       print CLIENTCRAP sprintf "Total: %d lines hidden, %d anchors, %dkB of data", $tl, $ta, int($td/1024);
   }
});
init_hideshow();

{ package Irssi::Nick }
