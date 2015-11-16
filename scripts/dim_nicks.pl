use strict;
use warnings;

our $VERSION = '0.4.6'; # 373036720cc131b
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'dim_nicks',
    description => 'Dims nicks that are not in channel anymore.',
    license     => 'GNU GPLv2 or later',
   );

# Usage
# =====
# Once loaded, this script will record the nicks of each new
# message. If the user leaves the room, the messages will be rewritten
# with the nick in another colour/style.
#
# Depending on your theme, tweaking the forms settings may be
# necessary. With the default irssi theme, this script should just
# work.

# Options
# =======
# /set dim_nicks_color <colour>
# * the colour code to use for dimming the nick, or a string of format
#   codes with the special token $* in place of the nick (e.g. %I$*%I
#   for italic)
#
# /set dim_nicks_history_lines <num>
# * only this many lines of messages are remembered/rewritten (per
#   window)
#
# /set dim_nicks_forms_skip <num>
# /set dim_nicks_forms_search_max <num>
# * these two settings limit the range where to search for the
#   nick.
#   It sets how many forms (blocks of irssi format codes or
#   non-letters) to skip at the beginning of line before starting to
#   search for the nick, and from then on how many forms to search
#   before stopping.
#   You should set this to the appropriate values to avoid (a) dimming
#   your timestamp (b) dimming message content instead of the nick.
#   To check your settings, you can use the command
#     /script exec Irssi::Script::dim_nicks::debug_forms


no warnings 'redefine';
use constant IN_IRSSI => __PACKAGE__ ne 'main' || $ENV{IRSSI_MOCK};
use Irssi 20140701;
use Irssi::TextUI;
use Encode;


sub setc () {
    $IRSSI{name}
}

sub set ($) {
    setc . '_' . $_[0]
}

my $history_lines = 100;
my $skip_forms = 1;
my $search_forms_max = 5;
my $color_letter = 'K';

my (%nick_reg, %chan_reg, %history, %history_st, %lost_nicks, %lost_nicks_backup);

my ($dest, $chanref, $nickref);

sub clear_ref {
    $dest = undef;
    $chanref = undef;
    $nickref = undef;
}

sub msg_line_tag {
    my ($srv, $msg, $nick, $addr, $targ) = @_;
    $chanref = $srv->channel_find($targ);
    $nickref = ref $chanref ? $chanref->nick_find($nick) : undef;
}

sub msg_line_clear {
    clear_ref();
}

my @color_code;

sub color_to_code {
    my $win = Irssi::active_win;
    my $view = $win->view;
    if (-1 == index $color_letter, '$*') {
	$color_letter = "%$color_letter\$*";
    }
    $win->print_after(undef, MSGLEVEL_NEVER, "$color_letter ");
    my $lp = $win->last_line_insert;
    my $color_code = $lp->get_text(1);
    $color_code =~ s/ $//;
    $view->remove_line($lp);
    @color_code = split /\$\*/, $color_code, 2;
}

sub setup_changed {
    $history_lines = Irssi::settings_get_int( set 'history_lines' );
    $skip_forms = Irssi::settings_get_int( set 'forms_skip' );
    $search_forms_max = Irssi::settings_get_int( set 'forms_search_max' );
    my $new_color = Irssi::settings_get_str( set 'color' );
    if ($new_color ne $color_letter) {
	$color_letter = $new_color;
	color_to_code();
    }
}

sub init_dim_nicks {
    setup_changed();
}

sub prt_text_issue {
    ($dest) = @_;
    clear_ref() unless defined $dest->{target};
    clear_ref() unless $dest->{level} & MSGLEVEL_PUBLIC;
}

sub expire_hist {
    for my $ch (keys %history_st) {
	if (@{$history_st{$ch}} > 2 * $history_lines) {
	    my @del = splice @{$history_st{$ch}}, 0, $history_lines;
	    delete @history{ @del };
	}
    }
}

sub prt_text_ref {
    return unless $nickref;
    my ($win) = @_;
    my $view = $win->view;
    my $line_id = $view->{buffer}{_irssi} .','. $view->{buffer}{cur_line}{_irssi};
    $chan_reg{ $chanref->{_irssi} } = $chanref;
    $nick_reg{ $nickref->{_irssi} } = $nickref;
    if (exists $history{ $line_id }) {
    }
    $history{ $line_id } = [ $win->{_irssi}, $chanref->{_irssi}, $nickref->{_irssi}, $nickref->{nick} ];
    push @{$history_st{ $chanref->{_irssi} }}, $line_id;
    expire_hist();
    my @lost_forever = grep { $view->{buffer}{first_line}{info}{time} > $lost_nicks{ $chanref->{_irssi} }{ $_ } }
	keys %{$lost_nicks{ $chanref->{_irssi} }};
    delete @{$lost_nicks{ $chanref->{_irssi} }}{ @lost_forever };
    delete @{$lost_nicks_backup{ $chanref->{_irssi} }}{ @lost_forever };
    clear_ref();
}

sub win_del {
    my ($win) = @_;
    for my $ch (keys %history_st) {
	@{$history_st{$ch}} = grep { exists $history{ $_ } &&
					 $history{ $_ }[0] != $win->{_irssi} } @{$history_st{$ch}};
    }
    my @del = grep { $history{ $_ }[0] == $win->{_irssi} } keys %history;
    delete @history{ @del };
}

sub _alter_lines {
    my ($chan, $check_lr, $ad) = @_;
    my $win = $chan->window;
    return unless ref $win;
    my $view = $win->view;
    my $count = $history_lines;
    my $buffer_id = $view->{buffer}{_irssi} .',';
    my $lp = $view->{buffer}{cur_line};
    my %check_lr = map { $_ => undef } @$check_lr;
    my $redraw;
	my $bottom = $view->{bottom};
    while ($lp && $count) {
	my $line_id = $buffer_id . $lp->{_irssi};
	if (exists $check_lr{ $line_id }) {
	    $lp = _alter_line($buffer_id, $line_id, $win, $view, $lp, $chan->{_irssi}, $ad);
	    unless ($lp) {
		last;
	    }
	    $redraw = 1;
	}
    } continue {
	--$count;
	$lp = $lp->prev;
    }
    if ($redraw) {
	$win->command('^scrollback end') if $bottom && !$win->view->{bottom};
	$view->redraw;
    }
}

my $irssi_mumbo = qr/\cD[`-i]|\cD[&-@\xff]./;
my $irssi_mumbo_no_partial = qr/(?<!\cD)(?<!\cD[&-@\xff])/;
my $irssi_skip_form_re = qr/((?:$irssi_mumbo|[.,*@%+&!#$()=~'";:?\/><]+(?=$irssi_mumbo|\s))+|\s+)/;

sub debug_forms {
    my $win = Irssi::active_win;
    my $view = $win->view;
    my $lp = $view->{buffer}{cur_line};
    my $count = $history_lines;
    my $buffer_id = $view->{buffer}{_irssi} .',';
    while ($lp && $count) {
	my $line_id = $buffer_id . $lp->{_irssi};
	# $history{ $line_id } = [ $win->{_irssi}, $chanref->{_irssi}, $nickref->{_irssi}, $nickref->{nick} ];
	if (exists $history{ $line_id }) {
	    my $line_nick = $history{ $line_id }[3];
	    my $text = $lp->get_text(1);
	    pos $text = 0;
	    my $from = 0;
	    for (my $i = 0; $i < $skip_forms; ++$i) {
		last unless
		    scalar $text =~ /$irssi_skip_form_re/g;
		$from = pos $text;
	    }
	    my $to = $from;
	    for (my $i = 0; $i < $search_forms_max; ++$i) {
		last unless
		    scalar $text =~ /$irssi_skip_form_re/g;
		$to = pos $text;
	    }
	    my $pre = substr $text, 0, $from;
	    my $search = substr $text, $from, $to-$from;
	    my $post = substr $text, $to;
	    unless ($to > $from) {
	    } else {
		my @nick_reg;
		unshift @nick_reg, quotemeta substr $line_nick, 0, $_ for 1 .. length $line_nick;
		no warnings 'uninitialized';
		for my $nick_reg (@nick_reg) {
		    last if $search
		        =~ s/(\Q$color_code[0]\E\s*)?((?:$irssi_mumbo)+)?$irssi_mumbo_no_partial($nick_reg)((?:$irssi_mumbo)+)?(\s*\Q$color_code[0]\E)?/<match>$1$2<nick>$3<\/nick>$4$5<\/match>/;
		    last if $search
			=~ s/(?:\Q$color_code[0]\E)?(?:(?:$irssi_mumbo)+?)?$irssi_mumbo_no_partial($nick_reg)(?:(?:$irssi_mumbo)+?)?(?:\Q$color_code[1]\E)?/<nick>$1<\/nick>/;
		}
	    }
	    my $msg = "$pre<search>$search</search>$post";
	    #$msg =~ s/([^[:print:]])/sprintf '\\x%02x', ord $1/ge;
	    $msg =~ s/\cDe/%|/g; $msg =~ s/%/%%/g;
	    $win->print(setc." form debug: [$msg]", MSGLEVEL_CLIENTCRAP);
	    return;
	}
    } continue {
	--$count;
	$lp = $lp->prev;
    }
    $win->print(setc." form debug: no usable line found", MSGLEVEL_CLIENTCRAP);
}

sub _alter_line {
    my ($buffer_id, $lrp, $win, $view, $lp, $cid, $ad) = @_;
    my $line_nick = $history{ $lrp }[3];
    my $text = $lp->get_text(1);
    pos $text = 0;
    my $from = 0;
    for (my $i = 0; $i < $skip_forms; ++$i) {
	last unless
	    scalar $text =~ /$irssi_skip_form_re/g;
	$from = pos $text;
    }
    my $to = $from;
    for (my $i = 0; $i < $search_forms_max; ++$i) {
	last unless
	    scalar $text =~ /$irssi_skip_form_re/g;
	$to = pos $text;
    }
    return $lp unless $to > $from;
    my @nick_reg;
    unshift @nick_reg, quotemeta substr $line_nick, 0, $_ for 1 .. length $line_nick;
    { no warnings 'uninitialized';
    if ($ad) {
	if (exists $lost_nicks_backup{ $cid }{ $line_nick }) {
	    my ($fs, $fc, $bc, $bs) = @{$lost_nicks_backup{ $cid }{ $line_nick }};
	    my $sen = length $bs ? $color_code[0] : '';
	    for my $nick_reg (@nick_reg) {
		last if
		    (substr $text, $from, $to-$from)
			=~ s/(?:\Q$color_code[0]\E)?(?:(?:$irssi_mumbo)+?)?$irssi_mumbo_no_partial($nick_reg)(?:(?:$irssi_mumbo)+?)?(?:\Q$color_code[1]\E)?/$fc$1$bc$sen/;
	    }
	}
    }
    else {
	for my $nick_reg (@nick_reg) {
	    if (
		(substr $text, $from, $to-$from)
		    =~ s/(\Q$color_code[0]\E\s*)?((?:$irssi_mumbo)+)?$irssi_mumbo_no_partial($nick_reg)((?:$irssi_mumbo)+)?(\s*\Q$color_code[0]\E)?/$1$2$color_code[0]$3$color_code[1]$4$5/) {
		$lost_nicks_backup{ $cid }{ $line_nick } = [ $1, $2, $4, $5 ];
		last;
	    }
	}
    } }
    $win->gui_printtext_after($lp->prev, $lp->{info}{level} | MSGLEVEL_NEVER, "$text\n", $lp->{info}{time});
    my $ll = $win->last_line_insert;
    my $line_id = $buffer_id . $ll->{_irssi};
    if (exists $history{ $line_id }) {
    }
    grep { $_ eq $lrp and $_ = $line_id } @{$history_st{ $cid }};
    $history{ $line_id } = delete $history{ $lrp };
    $view->remove_line($lp);
    $ll;
}

sub nick_add {
    my ($chan, $nick) = @_;
    if (delete $lost_nicks{ $chan->{_irssi} }{ $nick->{nick} }) {
	my @check_lr = grep { $history{ $_ }[1] == $chan->{_irssi} &&
				  $history{ $_ }[2] eq $nick->{nick} } keys %history;
	if (@check_lr) {
	    $nick_reg{ $nick->{_irssi} } = $nick;
	    for my $li (@check_lr) {
		$history{ $li }[2] = $nick->{_irssi};
	    }
	    _alter_lines($chan, \@check_lr, 1);
	}
    }
    delete $lost_nicks_backup{ $chan->{_irssi} }{ $nick->{nick} };
}

sub nick_del {
    my ($chan, $nick) = @_;
    my @check_lr = grep { $history{ $_ }[2] eq $nick->{_irssi} } keys %history;
    for my $li (@check_lr) {
	$history{ $li }[2] = $nick->{nick};
    }
    if (@check_lr) {
	$lost_nicks{ $chan->{_irssi} }{ $nick->{nick} } = time;
	_alter_lines($chan, \@check_lr, 0);
    }
    delete $nick_reg{ $nick->{_irssi} };
}

sub nick_change {
    my ($chan, $nick, $oldnick) = @_;
    nick_add($chan, $nick);
}

sub chan_del {
    my ($chan) = @_;
    if (my $del = delete $history_st{ $chan->{_irssi} }) {
	delete @history{ @$del };
    }
    delete $chan_reg{ $chan->{_irssi} };
    delete $lost_nicks{$chan->{_irssi}};
    delete $lost_nicks_backup{$chan->{_irssi}};
}

Irssi::settings_add_int( setc, set 'history_lines',     $history_lines);
Irssi::signal_add_last({
    'setup changed'    => 'setup_changed',
});
Irssi::signal_add({
    'print text'	      => 'prt_text_issue',
    'gui print text finished' => 'prt_text_ref',
    'nicklist new'	      => 'nick_add',
    'nicklist changed'	      => 'nick_change',
    'nicklist remove'	      => 'nick_del',
    'window destroyed'	      => 'win_del',
    'message public'	      => 'msg_line_tag',
    'message own_public'      => 'msg_line_clear',
    'channel destroyed'	      => 'chan_del',
});

sub dumphist {
    my $win = Irssi::active_win;
    my $view = $win->view;
    my $buffer_id = $view->{buffer}{_irssi} .',';
    for (my $lp = $view->{buffer}{first_line}; $lp; $lp = $lp->next) {
	my $line_id = $buffer_id . $lp->{_irssi};
	if (exists $history{ $line_id }) {
	    my $k = $history{ $line_id };
	    if (exists $chan_reg{ $k->[1] }) {
	    }
	    if (exists $nick_reg{ $k->[2] }) {
	    }
	    if (exists $lost_nicks{ $k->[1] } && exists $lost_nicks{ $k->[1] }{ $k->[2] }) {
	    }
	}
    }
}
Irssi::settings_add_str( setc, set 'color', $color_letter);
Irssi::settings_add_int( setc, set 'forms_skip', $skip_forms);
Irssi::settings_add_int( setc, set 'forms_search_max', $search_forms_max);

init_dim_nicks();

{ package Irssi::Nick }

# Changelog
# =========
# 0.4.6
# - fix crash on some lines reported by pierrot
