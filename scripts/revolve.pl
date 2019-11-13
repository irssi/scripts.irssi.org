use strict;
use warnings;
use Irssi;
use Irssi::TextUI;
use POSIX 'strftime';
use vars qw($VERSION %IRSSI);

$VERSION = "0.0.6"; # 29d237f4fda2f0d
%IRSSI = (
    authors => 'Ryan Freebern',
    contact => 'ryan@freebern.org',
    name => 'revolve',
    description => 'Summarizes multiple sequential joins/parts/quits.',
    license => 'GPL v2 or later',
    url => 'http://github.com/rfreebern/irssi-revolving-door',
);

# Based on compact.pl by Wouter Coekaerts <wouter@coekaerts.be>
# http://wouter.coekaerts.be/irssi/scripts/compact.pl.html

# Usage
# =====
# Once loaded, the script will summarise and remove any
# JOINS/PARTS/QUITS/NICKS

# Options
# =======
# /set revolve_show_nickchain <ON|OFF>
# * whether more than two nick names should be shown when people
#   change nicks
#
# /set revolve_modes <ON|OFF>
# * whether MODES should also be summarised
#
# /set revolve_show_rejoins <ON|OFF>
# * whether rejoins should be displayed instead of clearing them out
#   from QUITS/PARTS silently
#
# /set revolve_show_time <ON|OFF>
# * whether timestamp should be displayed before and after the summary
#   line
#

# To change the look and feel, edit the script source code below:

# -----8<------ do not change this part ----->8-----
use constant {
    JOINS => +MSGLEVEL_JOINS,
    PARTS => +MSGLEVEL_PARTS,
    QUITS => +MSGLEVEL_QUITS,
    NICKS => +MSGLEVEL_NICKS,
    REJOINS => (+MSGLEVEL_JOINS|+MSGLEVEL_PARTS),
    MODES => +MSGLEVEL_MODES,
};


my %msg_level_text;

# ====================== CONFIGURABLE SECTION START ======================
#
# IMPORTANT: all texts and all separators must be distinguishable and
# one must not be a substring of another!
#
#
# here are the heading texts to be shown on the summary line:
#
@msg_level_text{(JOINS, PARTS, QUITS, NICKS, REJOINS, MODES)}=qw/Joins Parts Quits Nicks Cycles Status/;
#
# here after the => are the colour styles to be used for the above heading texts:
#
my %msg_level_style = (
    # style before heading text
    JOINS()   => '%C%I',
    PARTS()   => '%c%I',
    QUITS()   => '%c%I',
    NICKS()   => '%K%I',
    REJOINS() => '%C%I',
    MODES()   => '%K%I',
    # style after heading text separator
    0         => '%I%w',
    # line colour
    -1        => '%w',
   );
#
# here is the time format / style to use if time display is enabled:
# %%H:%%M are passed to strftime
#
my $time_format = '%X5N' . '%%H:%%M' . '%w';
#
# here are the separators used on the summary line:
my $level_separator = ' ── ';
my $nick_separator = ', ';
my $type_separator = ': ';
my $new_nick_separator = ' → ';
my $time_separator = ' | ';
#
# here is the line indentation (10 spaces):
#
my $indentation = ' 'x10;
#
# ======================= CONFIGURABLE SECTION END =======================
#
#
#

my %summary_lines;
my %msg_level_constant = reverse %msg_level_text;
my %prefix_tbl;

sub lrtrim {
    for (@_) {
        s/^\s+//; s/\s+$//;
    }
}

sub dotime {
    my $time = time;
    my $format = $time_format;
    $format =~ y/%/\01/;
    $format =~ s/\01\01/%/g;
    $format = strftime($format, localtime $time);
    $format =~ y/\01/%/;
    $format
}

sub summarize {
    my ($window, $tag, $channel, $nick, $arg, $type) = @_;

    return unless $window;
    my $view = $window->view;
    my $check = $tag . ':' . $channel;

    my $tb = $view->get_bookmark('trackbar');
    $view->set_bookmark_bottom('bottom');
    my $last = $view->get_bookmark('bottom');
    if ($tb && $last->{_irssi} == $tb->{_irssi}) {
        $last = $last->prev;
    }
    my $secondlast = $last ? $last->prev : undef;
    if ($tb && $secondlast && $secondlast->{_irssi} == $tb->{_irssi}) {
        $secondlast = $secondlast->prev;
    }

    # Remove the last line, which should have the join/part/quit message.
    return unless $last->{info}{level} & $type;
    $view->remove_line($last);

    my $pt = $prefix_tbl{$tag} || [];
    my $ptrim = $pt->[0] ? qr/^([\Q$pt->[0]\E]*)/ : qr/^()/;

    # If the second-to-last line is a summary line, parse it.
    my %door = (JOINS() => [], PARTS() => [], QUITS() => [], NICKS() => [], REJOINS() => [], MODES() => []);
    my @summarized = ();
    my $old_time = dotime();
    my $new_time = $old_time;
    if ($secondlast and $summary_lines{$check} and $secondlast->{_irssi} == $summary_lines{$check}) {
        my $csummary = $secondlast->get_text(1);
        my ($time, @x) = split /\Q$time_separator/, $csummary, 3;
        my $summary = $secondlast->get_text(0);
        $summary = (split /\Q$time_separator/, $summary, 3)[1] if @x;
        lrtrim $summary;
        $time = '' unless @x;
        lrtrim $time;
        @summarized = split(/\Q$level_separator/, $summary);
        lrtrim @summarized;
        foreach my $part (@summarized) {
            my ($type, $nicks) = split(/\Q$type_separator/, $part, 2);
            lrtrim $nicks;
            my $ctype = $msg_level_constant{$type};
            $door{$ctype} = [ split(/\Q$nick_separator/, $nicks) ];
            if ($ctype == JOINS || $ctype == REJOINS) {
                for (@{$door{$ctype}}) {
                    s/$ptrim//;
                    $_ = [ $1, $_ ]
                }
            } elsif ($ctype == MODES) {
                for (@{$door{$ctype}}) {
                  s/^([\Q$pt->[0]\E:]*)//;
                  $_ = [ $1, $_ ];
                }
            }
        }
        $view->remove_line($secondlast);
        $old_time = $time;
    }

    my $rejoins = Irssi::settings_get_bool('revolve_show_rejoins');
    my $nickchain = Irssi::settings_get_bool('revolve_show_nickchain');
    if ($type == JOINS) { # Join
        if (grep { $_ eq $nick } @{$door{+PARTS}}, @{$door{+QUITS}}) {
            for (PARTS, QUITS) {
                @{$door{+$_}} = grep { $_ ne $nick } @{$door{+$_}};
            }
            push(@{$door{+REJOINS}}, [ '', $nick ])
                if $rejoins;
        } else {
            push(@{$door{+$type}}, [ '', $nick ]);
        }
    } elsif ($type == QUITS || $type == PARTS) { # Quit / Part
        for (MODES) {
            @{$door{+$_}} = grep { $_->[1] ne $nick } @{$door{+$_}};
        }
        if (grep { $_->[1] eq $nick } @{$door{+JOINS}}, @{$door{+REJOINS}}) {
            for (JOINS, REJOINS) {
                @{$door{+$_}} = grep { $_->[1] ne $nick } @{$door{+$_}};
            }
            push @{$door{+$type}}, $nick
                if $rejoins;
        } else {
            push @{$door{+$type}}, $nick;
        }
    } elsif ($type == NICKS) {
        my $new_nick = $arg;
        my $nick_found = 0;
        foreach my $known_nick (@{$door{+NICKS}}) {
            my @alt_nicks = split(/\Q$new_nick_separator/, $known_nick);
            my $orig_nick = $alt_nicks[0];
            my $current_nick = $alt_nicks[-1];
            if ($current_nick eq $nick) {
                if ($new_nick eq $orig_nick) {
                    if ($nickchain) {
                        $known_nick = $new_nick;
                    } else {
                        @{$door{+NICKS}} = grep { $_ ne $known_nick } @{$door{+NICKS}};
                    }
                } else {
                    if ($nickchain) {
                        @alt_nicks = grep { $_ ne $orig_nick && $_ ne $new_nick } @alt_nicks;
                        $known_nick = join $new_nick_separator, $orig_nick, @alt_nicks, $new_nick;
                    } else {
                        $known_nick = "$orig_nick$new_nick_separator$new_nick";
                    }
                }
                $nick_found = 1;
                last;
            }
        }
        if (!$nick_found) {
            push(@{$door{+NICKS}}, "$nick$new_nick_separator$new_nick");
        }
        # Update nicks in join lists.
        foreach my $part (JOINS, REJOINS, MODES) {
            foreach (@{$door{$part}}) {
                $_->[1] = $new_nick if $_->[1] eq $nick;
            }
        }
    } elsif ($type == MODES) {
        my $mode = $arg;
        my ($spec, @args) = split ' ', $mode;
        my $type = '+';
        my $i = 0;
        for my $c (split //, $spec) {
            if ($c eq '+' || $c eq '-') {
                $type = $c;
            } else {
                my @ent = grep { $_->[1] eq $args[$i] } @{$door{+JOINS}}, @{$door{+REJOINS}};
                my $p = substr $pt->[0], (index $pt->[1], $c), 1;
                if (@ent) {
                    if ($type eq '+') {
                        $ent[0][0] = $p . $ent[0][0];
                    } else {
                        $ent[0][0] =~ s/\Q$p\E//;
                    }
                } elsif (my ($e) = grep { $_->[1] eq $args[$i]} @{$door{+MODES}}) {
                    my $pos = $e->[0];
                    my $neg = '';
                    if ($pos =~ s/^(.*)://) {
                        $neg = $1;
                    }
                    if ($type eq '+') {
                        $pos = $p . $pos;
                        $neg =~ s/\Q$p\E//;
                    } else {
                        $neg = $p . $neg;
                        $pos =~ s/\Q$p\E//;
                    }
                    $e->[0] = length $neg ? "$neg:$pos" : $pos;
                } else {
                    push @{$door{+MODES}}, [ $type eq '+' ? $p : "$p:", $args[$i] ];
                }
            }
        }
    }

    foreach my $part (JOINS, REJOINS, MODES) {
        foreach (@{$door{$part}}) {
            $_ = $_->[0].$_->[1];
        }
    }

    @summarized = ();
    my $level = MSGLEVEL_NEVER;
    foreach my $part (JOINS, PARTS, QUITS, REJOINS, NICKS, MODES) {
        if (@{$door{$part}}) {
            push @summarized, $msg_level_style{$part} . $msg_level_text{$part} . $type_separator . $msg_level_style{0}
                . join($nick_separator, @{$door{$part}});
            $level |= $part;
        }
    }

    my $summary = join($msg_level_style{-1}.$level_separator, @summarized);
    if (Irssi::settings_get_bool('revolve_show_time')) {
        $summary = $old_time.$msg_level_style{-1}.$time_separator.$summary;
        $summary .= $msg_level_style{-1}.$time_separator.$new_time
            if $old_time ne $new_time;
    }
    if (@summarized) {
        $window->print($indentation. '%|'. $msg_level_style{-1}.$summary, $level);
        # Get the line we just printed so we can log its ID.
        $view->set_bookmark_bottom('bottom');
        $last = $view->get_bookmark('bottom');
        $summary_lines{$check} = $last->{_irssi};
    } else {
        delete $summary_lines{$check};
    }

    $view->redraw();
}

sub delete_and_summarize {
    return unless our @summary;
    my ($tag, $channel, $nick, $arg, $type) = @summary;
    # "delete_and_summarize: $type";
    my ($dest) = @_;
    return unless $dest->{server} && $dest->{server}{tag} eq $tag;
    return if defined $channel && $dest->{target} ne $channel;
    &Irssi::signal_continue;
    summarize($dest->{window}, $tag, $dest->{target}, $nick, $arg, $type);
}

sub summarize_join {
    my ($server, $channel, $nick, $address, $reason) = @_;
    local our @summary = ($server->{tag}, $channel, $nick, undef, JOINS);
    &Irssi::signal_continue;
}

sub summarize_quit {
    my ($server, $nick, $address, $reason) = @_;
    local our @summary = ($server->{tag}, undef, $nick, undef, QUITS);
    &Irssi::signal_continue;
}

sub summarize_part {
    my ($server, $channel, $nick, $address, $reason) = @_;
    local our @summary = ($server->{tag}, $channel, $nick, undef, PARTS);
    &Irssi::signal_continue;
}

sub summarize_nick {
    my ($server, $new_nick, $old_nick, $address) = @_;
    local our @summary = ($server->{tag}, undef, $old_nick, $new_nick, NICKS);
    &Irssi::signal_continue;
}

sub update_prefixes {
    my ($server) = @_;
    my $prefix = $server->can('isupport') && $server->isupport('prefix') || '(ohv)@%+';
    $prefix =~ s/^\((.*?)\)//;
    my $modes = $1;
    $prefix_tbl{$server->{tag}} = [ $prefix, $modes ];
}

sub summarize_irc_mode {
    my ($server, $channel, $nick, $address, $mode) = @_;
    return unless Irssi::settings_get_bool('revolve_modes');
    my ($spec, @args) = split ' ', $mode;
    return unless @args;
    update_prefixes($server) unless $prefix_tbl{$server->{tag}};
    my $modes = $prefix_tbl{$server->{tag}}[1];
    return unless $spec =~ /^([-+][\Q$modes\E]+)+$/;
    local our @summary = ($server->{tag}, $channel, $nick, $mode, MODES);
    &Irssi::signal_continue;
    my $dest = $server->format_create_dest($channel, MSGLEVEL_MODES, $server->window_find_closest($channel, MSGLEVEL_MODES));
    Irssi::signal_emit('print starting', $dest);
}

Irssi::signal_register({'print starting'=>[qw[Irssi::UI::TextDest]]});
Irssi::settings_add_bool('revolve', 'revolve_show_nickchain', 0);
Irssi::settings_add_bool('revolve', 'revolve_modes', 0);
Irssi::settings_add_bool('revolve', 'revolve_show_rejoins', 0);
Irssi::settings_add_bool('revolve', 'revolve_show_time', 0);
Irssi::signal_add('message join', 'summarize_join');
Irssi::signal_add('message part', 'summarize_part');
Irssi::signal_add('message quit', 'summarize_quit');
Irssi::signal_add('message nick', 'summarize_nick');
Irssi::signal_add('message irc mode', 'summarize_irc_mode');
Irssi::signal_add('print text', 'delete_and_summarize');
Irssi::signal_add_last('event 376', 'update_prefixes');
