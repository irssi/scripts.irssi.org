use strict;
use warnings;

our $VERSION = '0.4.9';
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
# /set dim_nicks_ignore_hilights <ON|OFF>
# * ignore lines with hilight when dimming
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
my $ignore_hilights = 1;
my $color_letter = 'K';
my @color_code = ("\cD8/"); # update this when you change $color_letter

# nick object cache, chan object cache, line id cache, line id -> window map, -> channel, -> nick, -> nickname, channel -> line ids, channel->nickname->departure time, channel->nickname->{parts of line}
my (%nick_reg, %chan_reg, %history_w, %history_c, %history_n, %history_nn, %history_st, %lost_nicks, %lost_nicks_fs, %lost_nicks_fc, %lost_nicks_bc, %lost_nicks_bs);

our ($dest, $chanref, $nickref);


sub msg_line_tag {
    my ($srv, $msg, $nick, $addr, $targ) = @_;
    local $chanref = $srv->channel_find($targ);
    local $nickref = ref $chanref ? $chanref->nick_find($nick) : undef;
    &Irssi::signal_continue;
}

sub color_to_code {
    my $win = Irssi::active_win;
    my $view = $win->view;
    my $cl = $color_letter;
    if (-1 == index $cl, '$*') {
	$cl = "%$cl\$*";
    }
    $win->print_after(undef, MSGLEVEL_NEVER, "$cl ");
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
    $ignore_hilights = Irssi::settings_get_bool( set 'ignore_hilights' );
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
    my ($ld) = @_;
    local $dest = $ld;
    &Irssi::signal_continue;
}

sub expire_hist {
    for my $ch (keys %history_st) {
	if (@{$history_st{$ch}} > 2 * $history_lines) {
	    my @del = splice @{$history_st{$ch}}, 0, $history_lines;
	    delete @history_w{ @del };
	    delete @history_c{ @del };
	    delete @history_n{ @del };
	    delete @history_nn{ @del };
	}
    }
}

sub prt_text_ref {
    return unless $nickref;
    return unless $dest && defined $dest->{target};
    return unless $dest->{level} & MSGLEVEL_PUBLIC;
    return if $ignore_hilights && $dest->{level} & MSGLEVEL_HILIGHT;

    my ($win) = @_;
    my $view = $win->view;
    my $line_id = $view->{buffer}{_irssi} .','. $view->{buffer}{cur_line}{_irssi};
    $chan_reg{ $chanref->{_irssi} } = $chanref;
    $nick_reg{ $nickref->{_irssi} } = $nickref;
    if (exists $history_w{ $line_id }) {
    }
    $history_w{ $line_id } = $win->{_irssi};
    $history_c{ $line_id } = $chanref->{_irssi};
    $history_n{ $line_id } = $nickref->{_irssi};
    $history_nn{ $line_id } = $nickref->{nick};
    push @{$history_st{ $chanref->{_irssi} }}, $line_id;
    expire_hist();
    my @lost_forever = grep { $view->{buffer}{first_line}{info}{time} > $lost_nicks{ $chanref->{_irssi} }{ $_ } }
	keys %{$lost_nicks{ $chanref->{_irssi} }};
    delete @{$lost_nicks{ $chanref->{_irssi} }}{ @lost_forever };
    delete @{$lost_nicks_fs{ $chanref->{_irssi} }}{ @lost_forever };
    delete @{$lost_nicks_fc{ $chanref->{_irssi} }}{ @lost_forever };
    delete @{$lost_nicks_bc{ $chanref->{_irssi} }}{ @lost_forever };
    delete @{$lost_nicks_bs{ $chanref->{_irssi} }}{ @lost_forever };
    return;
}

sub win_del {
    my ($win) = @_;
    for my $ch (keys %history_st) {
	@{$history_st{$ch}} = grep { exists $history_w{ $_ } &&
				     $history_w{ $_ } != $win->{_irssi} } @{$history_st{$ch}};
    }
    my @del = grep { $history_w{ $_ } == $win->{_irssi} } keys %history_w;
    delete @history_w{ @del };
    delete @history_c{ @del };
    delete @history_n{ @del };
    delete @history_nn{ @del };
    return;
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
	if (exists $history_w{ $line_id }) {
	    my $line_nick = $history_nn{ $line_id };
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
    my $line_nick = $history_nn{ $lrp };
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
	if (exists $lost_nicks_fs{ $cid }{ $line_nick }) {
	    my ($fs, $fc, $bc, $bs) = ($lost_nicks_fs{ $cid }{ $line_nick }, $lost_nicks_fc{ $cid }{ $line_nick }, $lost_nicks_bc{ $cid }{ $line_nick }, $lost_nicks_bs{ $cid }{ $line_nick });
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
		$lost_nicks_fs{ $cid }{ $line_nick } = $1;
		$lost_nicks_fc{ $cid }{ $line_nick } = $2;
		$lost_nicks_bc{ $cid }{ $line_nick } = $4;
		$lost_nicks_bs{ $cid }{ $line_nick } = $5;
		last;
	    }
	}
    } }
    $win->gui_printtext_after($lp->prev, $lp->{info}{level} | MSGLEVEL_NEVER, "$text\n", $lp->{info}{time});
    my $ll = $win->last_line_insert;
    my $line_id = $buffer_id . $ll->{_irssi};
    if (exists $history_w{ $line_id }) {
    }
    grep { $_ eq $lrp and $_ = $line_id } @{$history_st{ $cid }};
    $history_w{ $line_id } = delete $history_w{ $lrp };
    $history_c{ $line_id } = delete $history_c{ $lrp };
    $history_n{ $line_id } = delete $history_n{ $lrp };
    $history_nn{ $line_id } = delete $history_nn{ $lrp };
    $view->remove_line($lp);
    $ll;
}

sub nick_add {
    my ($chan, $nick) = @_;
    if (delete $lost_nicks{ $chan->{_irssi} }{ $nick->{nick} }) {
	my @check_lr = grep { $history_c{ $_ } == $chan->{_irssi} &&
			      $history_n{ $_ } eq $nick->{nick} } keys %history_w;
	if (@check_lr) {
	    $nick_reg{ $nick->{_irssi} } = $nick;
	    for my $li (@check_lr) {
		$history_n{ $li } = $nick->{_irssi};
	    }
	    _alter_lines($chan, \@check_lr, 1);
	}
    }
    delete $lost_nicks_fs{ $chan->{_irssi} }{ $nick->{nick} };
    delete $lost_nicks_fc{ $chan->{_irssi} }{ $nick->{nick} };
    delete $lost_nicks_bc{ $chan->{_irssi} }{ $nick->{nick} };
    delete $lost_nicks_bs{ $chan->{_irssi} }{ $nick->{nick} };
    return;
}

sub nick_del {
    my ($chan, $nick) = @_;
    my @check_lr = grep { $history_n{ $_ } eq $nick->{_irssi} } keys %history_w;
    for my $li (@check_lr) {
	$history_n{ $li } = $nick->{nick};
    }
    if (@check_lr) {
	$lost_nicks{ $chan->{_irssi} }{ $nick->{nick} } = time;
	_alter_lines($chan, \@check_lr, 0);
    }
    delete $nick_reg{ $nick->{_irssi} };
    return;
}

sub nick_change {
    my ($chan, $nick, $oldnick) = @_;
    nick_add($chan, $nick);
}

sub chan_del {
    my ($chan) = @_;
    if (my $del = delete $history_st{ $chan->{_irssi} }) {
	delete @history_w{ @$del };
	delete @history_c{ @$del };
	delete @history_n{ @$del };
	delete @history_nn{ @$del };
    }
    delete $chan_reg{ $chan->{_irssi} };
    delete $lost_nicks{$chan->{_irssi}};
    delete $lost_nicks_fs{$chan->{_irssi}};
    delete $lost_nicks_fc{$chan->{_irssi}};
    delete $lost_nicks_bc{$chan->{_irssi}};
    delete $lost_nicks_bs{$chan->{_irssi}};
    return;
}

Irssi::settings_add_int( setc, set 'history_lines',     $history_lines);
Irssi::settings_add_bool( setc, set 'ignore_hilights',  $ignore_hilights);
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
    'channel destroyed'	      => 'chan_del',
});

sub dumphist {
    my $win = Irssi::active_win;
    my $view = $win->view;
    my $buffer_id = $view->{buffer}{_irssi} .',';
    for (my $lp = $view->{buffer}{first_line}; $lp; $lp = $lp->next) {
	my $line_id = $buffer_id . $lp->{_irssi};
	if (exists $history_w{ $line_id }) {
	    my $k = $history_c{ $line_id };
	    my $kn = $history_n{ $line_id };
	    if (exists $chan_reg{ $k }) {
	    }
	    if (exists $nick_reg{ $kn }) {
	    }
	    if (exists $lost_nicks{ $k } && exists $lost_nicks{ $k }{ $kn }) {
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
# 0.4.9
# - fix default setting not working
# 0.4.8
# - optionally ignore hilighted lines
# 0.4.7
# - fix useless re-reading of settings colour
# 0.4.6
# - fix crash on some lines reported by pierrot
