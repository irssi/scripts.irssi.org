use strict;
use warnings;
use vars qw($VERSION %IRSSI);

use Irssi;
use HTTP::Tiny;
use JSON::PP;
use Storable qw/store_fd fd_retrieve/;
use POSIX ();

$VERSION = '1.0';
%IRSSI = (
    authors	=> 'Ben Abulafia',
    contact	=> 'ben@synapsereality.io',
    name	=> 'tennis',
    description	=> 'Live tennis scores, rankings and head-to-head from the Live Tennis API',
    license	=> 'GPL',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2026-09-12',
    modules	=> '',
    commands	=> 'tennis',
    selfcheckcmd=> 'tennis check',
);

my $help = << "END";
%9Name%9
  $IRSSI{name} - $IRSSI{description}

%9Version%9
  $VERSION

%9Syntax%9
  /tennis [live [<n>]]        matches in play (default 20, max 50)
  /tennis match <id>          one match in detail
  /tennis rank atp|wta [<n>]  ranking table (default 10, max 50)
  /tennis h2h <a> vs <b>      head-to-head between two players
  /tennis check               self check

%9Settings%9
  /set tennis_apikey <key>    your Live Tennis API key

%9Description%9
  Reads scores from the Live Tennis API, a commercial service run by the
  author of this script. A key is required. The free tier costs nothing and
  needs no card, but it allows 30 requests a minute and 100 a day, so this
  script never polls: it talks to the network only when you type a command.

  In a score line %9*%9 marks the player serving and %9BP%9 marks a break point.
  Games read player 1 first, so "6-4 3-3" is 6-4 in the first set and 3-3
  in the second.

%9Plans%9
  /tennis live and /tennis match work on a free key.
  /tennis rank needs a PRO plan and /tennis h2h a BASIC plan; on a key that
  does not carry them each answers with one line saying so, not a score.

%9See also%9
  https://livetennisapi.com - plans, and a free key
  https://docs.livetennisapi.com - the API reference
END

my $base_url = 'https://api.livetennisapi.com/api/public/v1';
my %bg_process;

# ---------------------------------------------------------------- networking

# irssi runs Perl on its single main loop, so a blocking request would freeze
# the whole client until the server answered. Everything from here down to the
# render_* subs therefore runs in a forked child - the idiom 27 other scripts
# in this repository use - and only the finished lines travel back up the pipe.
sub fetch {
    my ($url, $key) = @_;
    my $http = HTTP::Tiny->new(
        timeout => 20,
        agent   => "irssi/$IRSSI{name} $VERSION ",
    );
    my %headers = ('Accept' => 'application/json');
    # The key goes in a header, never in the URL, so it stays out of every
    # message this script prints and out of any proxy log on the way.
    $headers{'X-API-Key'} = $key if defined $key && $key ne '';
    return $http->get($url, { headers => \%headers });
}

sub work {
    my ($url, $key, $render, @extra) = @_;
    my @line = $render->(fetch($url, $key), @extra);
    # Column padding is convenient to build and ugly to send to a window.
    s/\s+\z// for @line;
    return @line;
}

sub background {
    my ($cmd) = @_;
    my ($fh_r, $fh_w);
    if (!pipe $fh_r, $fh_w) {
        say_line("could not create a pipe: $!");
        return;
    }
    my $pid = fork();
    if (!defined $pid) {
        say_line("could not fork: $!");
        return;
    }
    if ($pid == 0) {
        # THE CHILD MUST NEVER LEAVE THIS BLOCK BY PERL'S NORMAL PATH.
        #
        # fork() left us holding a complete copy of irssi's interpreter and
        # of its buffered file handles. If the renderer died and the
        # exception unwound out of here, it would unwind inside that copy:
        # irssi's own error handling would run a second time, the parent's
        # END blocks and object destructors would fire in the wrong process,
        # and every byte irssi had buffered before the fork would be flushed
        # twice - once by each process. Calling exit() is no escape either,
        # because this repository's test harness replaces CORE::GLOBAL::exit
        # with a croak, so exit() here would itself become an exception.
        #
        # So: catch everything, turn it into a line the parent can print,
        # and leave through POSIX::_exit, which ends this process without
        # unwinding, without running END blocks and without flushing a
        # single inherited buffer.
        my @res;
        if (!eval { @res = &{ $cmd->{cmd} }(@{ $cmd->{args} }); 1 }) {
            my $why = $@;
            $why = 'no reason given' unless defined $why && $why ne '';
            $why =~ s/\s+/ /g;
            @res = ("$IRSSI{name}: the lookup failed: $why");
        }
        my $sent = eval { store_fd \@res, $fh_w; 1 };
        $sent &&= close $fh_w;
        POSIX::_exit($sent ? 0 : 1);
    }
    if (!close $fh_w) {
        say_line("could not close the pipe: $!");
    }
    $cmd->{fh_r} = $fh_r;
    Irssi::pidwait_add($pid);
    $bg_process{$pid} = $cmd;
    return;
}

# The child is already reaped by the time this runs, so its whole answer is
# sitting in the pipe and reading it cannot block. That holds because the
# answer is small by construction - the listing commands clamp themselves to
# 50 short lines, three orders of magnitude under a pipe buffer. Raising that
# clamp far enough to fill the buffer would strand the child mid-write.
sub sig_pidwait {
    my ($pid) = @_;
    return unless exists $bg_process{$pid};
    my $cmd = delete $bg_process{$pid};
    my $res;
    my $ok = eval { $res = fd_retrieve($cmd->{fh_r}); 1 };
    if (!close $cmd->{fh_r}) {
        say_line("could not close the pipe: $!");
    }
    if (!$ok || ref $res ne 'ARRAY') {
        say_line('the lookup ended before it answered');
        return;
    }
    &{ $cmd->{last} }($res);
    return;
}

# --------------------------------------------------------------- the response

sub decode_body {
    my ($res) = @_;
    return unless defined $res->{content} && $res->{content} ne '';
    my $out;
    my $ok = eval { $out = JSON::PP->new->utf8->decode($res->{content}); 1 };
    return unless $ok;
    return $out;
}

# Reduces any failure to one line a reader can act on, and returns nothing at
# all when the response is good, so callers can use it as a plain guard.
# $needs names the plan the endpoint sits behind, for the 403.
sub response_error {
    my ($res, $needs) = @_;
    my $code = $res->{status} || 0;
    my $body = decode_body($res);
    my $detail = '';
    my $error = '';
    if (ref $body eq 'HASH') {
        $error = defined $body->{error} ? $body->{error} : '';
        $detail = defined $body->{detail} ? $body->{detail} : $error;
        $detail =~ s/\s+/ /g;
    }
    my $aside = $detail ne '' ? " ($detail)" : '';

    # HTTP::Tiny reports a transport failure as status 599, reason in content.
    if ($code == 599) {
        my $why = $res->{content} || $res->{reason} || 'no reason given';
        $why =~ s/\s+/ /g;
        return "could not reach api.livetennisapi.com: $why";
    }
    if ($code == 401) {
        return 'the API rejected that key - check /set tennis_apikey';
    }
    if ($code == 403) {
        my $plan = defined $needs && $needs ne '' ? "a $needs plan" : 'a higher plan';
        return "that needs $plan - see https://livetennisapi.com";
    }
    # 410 is not an Error body: it carries the id this one was merged into.
    if ($code == 410) {
        my $to = ref $body eq 'HASH' ? $body->{merged_into} : undef;
        return defined $to ? "that match was merged into #$to - ask for that id"
            : 'that match id was retired and has no replacement';
    }
    if ($code == 404) {
        return "nothing held under that id$aside";
    }
    if ($code == 429) {
        # The free tier is 100 requests a day, so the daily cap is the one a
        # reader of this script actually meets. It says when it lifts.
        if ($error eq 'abuse_throttled') {
            return 'the API has blocked this key for hammering it - fix the '
                . 'caller, do not retry';
        }
        my $scope = ref $body eq 'HASH' ? $body->{scope} : undef;
        if (defined $scope && $scope eq 'day') {
            my $per = ref $body eq 'HASH' ? $body->{limit_per_day} : undef;
            my $when = ref $body eq 'HASH' ? $body->{resets_at} : undef;
            return "this key is out of requests for today"
                . (defined $per ? " ($per a day)" : '')
                . (defined $when ? ", resets $when" : '');
        }
        my $wait = $res->{headers}{'retry-after'};
        my $when = defined $wait && $wait =~ /^\d+$/ ? ", retry in ${wait}s"
            : ', slow down and retry shortly';
        return "the API rate limited this key$when$aside";
    }
    if ($code < 200 || $code > 299) {
        return "the API answered $code$aside";
    }
    if (!defined $body) {
        return 'the API answered something that is not JSON';
    }
    return;
}

# ------------------------------------------------------------------ scoreline

# "Carlos Alcaraz" becomes "Alcaraz"; a doubles team keeps both surnames.
sub surname {
    my ($name) = @_;
    return '?' unless defined $name && $name =~ /\S/;
    my @side;
    for my $half (split m{\s*/\s*}, $name) {
        my @word = split ' ', $half;
        push @side, $word[-1] if @word;
    }
    return '?' unless @side;
    return join '/', @side;
}

# games is player-major: [[6,3],[4,4]] reads "6-4 3-4". A completed match can
# carry empty arrays here, which is why the length is read rather than assumed.
sub fmt_games {
    my ($score) = @_;
    return '' unless ref $score eq 'HASH';
    my $games = $score->{games};
    return '' unless ref $games eq 'ARRAY' && @{$games} >= 2;
    my ($p1, $p2) = ($games->[0], $games->[1]);
    return '' unless ref $p1 eq 'ARRAY' && ref $p2 eq 'ARRAY';
    my $sets = @{$p1} > @{$p2} ? scalar @{$p1} : scalar @{$p2};
    my @out;
    for my $i (0 .. $sets - 1) {
        my $a = defined $p1->[$i] ? $p1->[$i] : '-';
        my $b = defined $p2->[$i] ? $p2->[$i] : '-';
        push @out, "$a-$b";
    }
    return join ' ', @out;
}

sub fmt_sets {
    my ($score) = @_;
    return '' unless ref $score eq 'HASH';
    my $sets = $score->{sets};
    return '' unless ref $sets eq 'ARRAY' && @{$sets} >= 2;
    my ($a, $b) = ($sets->[0], $sets->[1]);
    return '' unless defined $a && defined $b;
    return "$a-$b";
}

# In-game points, player 1 first. In a tiebreak these are the running tiebreak
# count as plain integers rather than 0/15/30/40, and either entry can be null
# - which is what a completed match looks like.
sub fmt_points {
    my ($score) = @_;
    return '' unless ref $score eq 'HASH';
    my $points = $score->{points};
    return '' unless ref $points eq 'ARRAY' && @{$points} >= 2;
    my ($a, $b) = ($points->[0], $points->[1]);
    return '' unless defined $a && defined $b;
    return "$a-$b" . ($score->{is_tiebreak} ? ' TB' : '');
}

# A break point is the receiver one point from taking the server's game: the
# receiver at AD, or at 40 with the server short of 40. A tiebreak has none -
# a point won against the serve there is a mini-break, not a break - and
# without a stated server there is no way to tell a break from a game point.
sub is_break_point {
    my ($score) = @_;
    return 0 unless ref $score eq 'HASH';
    return 0 if $score->{is_tiebreak};
    my $server = $score->{server};
    return 0 unless defined $server && $server =~ /^[12]$/;
    my $points = $score->{points};
    return 0 unless ref $points eq 'ARRAY' && @{$points} >= 2;
    my $held = $points->[$server - 1];
    my $faced = $points->[2 - $server];
    return 0 unless defined $held && defined $faced;
    return 1 if $faced eq 'AD';
    return 1 if $faced eq '40' && ($held eq '0' || $held eq '15' || $held eq '30');
    return 0;
}

sub serve_mark {
    my ($score, $who) = @_;
    return '' unless ref $score eq 'HASH';
    my $server = $score->{server};
    return '' unless defined $server && $server =~ /^[12]$/ && $server == $who;
    return '*';
}

sub match_context {
    my ($match) = @_;
    my @bit;
    push @bit, uc $match->{tour} if defined $match->{tour} && $match->{tour} ne '';
    push @bit, $match->{tournament}
        if defined $match->{tournament} && $match->{tournament} ne '';
    # round_code is the normalised vocabulary; the free-text round is a fallback.
    my $round = $match->{round_code};
    $round = $match->{round} unless defined $round && $round ne '';
    push @bit, $round if defined $round && $round ne '';
    return join ' ', @bit;
}

sub clip {
    my ($text, $width) = @_;
    $text = '' unless defined $text;
    return $text if length($text) <= $width;
    return substr($text, 0, $width - 1) . '~';
}

sub match_line {
    my ($match) = @_;
    my $score = $match->{score};
    my $player = ref $match->{players} eq 'HASH' ? $match->{players} : {};
    my $p1 = ref $player->{p1} eq 'HASH' ? $player->{p1} : {};
    my $p2 = ref $player->{p2} eq 'HASH' ? $player->{p2} : {};
    my $pair = surname($p1->{name}) . serve_mark($score, 1)
        . ' - ' . surname($p2->{name}) . serve_mark($score, 2);
    return sprintf '%8s %-24s %-14s %-7s %-2s %s',
        defined $match->{id} ? '#' . $match->{id} : '#?',
        clip($pair, 24),
        clip(fmt_games($score), 14),
        clip(fmt_points($score), 7),
        is_break_point($score) ? 'BP' : '',
        clip(match_context($match), 20);
}

# ------------------------------------------------------------------ rendering

sub render_live {
    my ($res) = @_;
    my $err = response_error($res);
    return "$IRSSI{name}: $err" if defined $err;
    my $body = decode_body($res);
    my $rows = ref $body eq 'HASH' ? $body->{data} : undef;
    if (ref $rows ne 'ARRAY' || !@{$rows}) {
        return "$IRSSI{name}: no matches are in play right now";
    }
    my @out = "$IRSSI{name}: matches in play (" . scalar(@{$rows}) . ')';
    for my $match (@{$rows}) {
        push @out, match_line($match) if ref $match eq 'HASH';
    }
    my $meta = ref $body eq 'HASH' ? $body->{meta} : undef;
    if (ref $meta eq 'HASH' && $meta->{has_more}) {
        push @out, "$IRSSI{name}: more are in play than were asked for - /tennis live <n>";
    }
    return @out;
}

sub render_match {
    my ($res) = @_;
    my $err = response_error($res);
    return "$IRSSI{name}: $err" if defined $err;
    my $match = decode_body($res);
    if (ref $match ne 'HASH' || !defined $match->{id}) {
        return "$IRSSI{name}: that match id returned nothing usable";
    }
    my $score = $match->{score};
    my $player = ref $match->{players} eq 'HASH' ? $match->{players} : {};
    my @shape;
    push @shape, $match->{surface} if defined $match->{surface};
    push @shape, $match->{indoor} ? 'indoor' : 'outdoor';
    push @shape, $match->{format} if defined $match->{format};
    push @shape, $match->{draw} if defined $match->{draw};
    my @out = "$IRSSI{name}: #$match->{id}  " . match_context($match)
        . (@shape ? '  (' . join(', ', @shape) . ')' : '');
    for my $who (1, 2) {
        my $side = ref $player->{"p$who"} eq 'HASH' ? $player->{"p$who"} : {};
        my @tag;
        push @tag, 'rank ' . $side->{ranking} if defined $side->{ranking};
        push @tag, $side->{country} if defined $side->{country};
        push @out, sprintf '  %-1s %s%s',
            serve_mark($score, $who),
            defined $side->{name} ? $side->{name} : '?',
            @tag ? ' (' . join(', ', @tag) . ')' : '';
    }
    my @state;
    for my $part (['sets', fmt_sets($score)], ['games', fmt_games($score)],
        ['points', fmt_points($score)]) {
        push @state, "$part->[0] $part->[1]" if $part->[1] ne '';
    }
    push @state, 'BREAK POINT' if is_break_point($score);
    push @out, '  ' . join('   ', @state) if @state;
    push @out, '  ' . match_close($match);
    return @out;
}

# How the match stands. outcome is the one closed vocabulary derived from
# status and event_status, so it is what settlement reads - the raw
# event_status spellings are not branched on here.
sub match_close {
    my ($match) = @_;
    my @close;
    push @close, $match->{status} if defined $match->{status};
    push @close, $match->{outcome}
        if defined $match->{outcome}
        && (!defined $match->{status} || $match->{outcome} ne $match->{status});
    if (defined $match->{winner} && $match->{winner} =~ /^[12]$/) {
        my $player = ref $match->{players} eq 'HASH' ? $match->{players} : {};
        my $side = $player->{"p$match->{winner}"};
        push @close, 'won by '
            . surname(ref $side eq 'HASH' ? $side->{name} : undef);
    }
    if (defined $match->{withdrew} && $match->{withdrew} =~ /^[12]$/) {
        my $player = ref $match->{players} eq 'HASH' ? $match->{players} : {};
        my $side = $player->{"p$match->{withdrew}"};
        push @close, surname(ref $side eq 'HASH' ? $side->{name} : undef)
            . ' did not finish';
    }
    push @close, 'scheduled ' . $match->{scheduled_time}
        if defined $match->{scheduled_time}
        && defined $match->{status}
        && $match->{status} eq 'upcoming';
    return @close ? join(', ', @close) : 'no stated status';
}

sub render_rank {
    my ($res, $system) = @_;
    my $err = response_error($res, 'PRO');
    return "$IRSSI{name}: $err" if defined $err;
    my $body = decode_body($res);
    my $rows = ref $body eq 'HASH' ? $body->{data} : undef;
    if (ref $rows ne 'ARRAY' || !@{$rows}) {
        return "$IRSSI{name}: the API held no ranking rows for that table";
    }
    my $when = ref $rows->[0] eq 'HASH' ? $rows->[0]->{effective_date} : undef;
    my @out = "$IRSSI{name}: " . uc($system) . ' singles ranking'
        . (defined $when ? ", effective $when" : '');
    for my $row (@{$rows}) {
        next unless ref $row eq 'HASH';
        # player_name is the name the ranking publisher printed, and is the
        # populated one on a listing row; player_id is null off our roster.
        push @out, sprintf '  %4s  %-28s %7s',
            defined $row->{rank} ? $row->{rank} : '-',
            clip(defined $row->{player_name} ? $row->{player_name} : '?', 28),
            defined $row->{points} ? $row->{points} : '';
    }
    return @out;
}

sub render_h2h {
    my ($res) = @_;
    my $err = response_error($res, 'BASIC');
    return "$IRSSI{name}: $err" if defined $err;
    my $body = decode_body($res);
    # players is null when neither fragment resolved to a person.
    if (ref $body ne 'HASH' || ref $body->{players} ne 'HASH') {
        return "$IRSSI{name}: neither name matched a player the API knows";
    }
    my $p1 = ref $body->{players}{p1} eq 'HASH' ? $body->{players}{p1}{name} : undef;
    my $p2 = ref $body->{players}{p2} eq 'HASH' ? $body->{players}{p2}{name} : undef;
    my $totals = ref $body->{totals} eq 'HASH' ? $body->{totals} : {};
    my @out = sprintf '%s: %s %s - %s %s (%s meetings%s)',
        $IRSSI{name},
        defined $p1 ? $p1 : '?',
        defined $totals->{p1_wins} ? $totals->{p1_wins} : '?',
        defined $totals->{p2_wins} ? $totals->{p2_wins} : '?',
        defined $p2 ? $p2 : '?',
        defined $totals->{meetings} ? $totals->{meetings} : '?',
        $totals->{undecided} ? ", $totals->{undecided} undecided" : '';
    # by_surface splits are keyed p1/p2, unlike the p1_wins/p2_wins totals.
    if (ref $body->{by_surface} eq 'HASH') {
        my @bit;
        for my $surface (sort keys %{ $body->{by_surface} }) {
            my $split = $body->{by_surface}{$surface};
            next unless ref $split eq 'HASH';
            push @bit, sprintf '%s %s-%s', $surface,
                defined $split->{p1} ? $split->{p1} : '?',
                defined $split->{p2} ? $split->{p2} : '?';
        }
        push @out, '  ' . join('  ', @bit) if @bit;
    }
    if (ref $body->{meetings} eq 'ARRAY') {
        my $shown = 0;
        for my $met (@{ $body->{meetings} }) {
            last if $shown >= 5;
            next unless ref $met eq 'HASH';
            # A row with neither a date nor a tournament says nothing.
            next unless defined $met->{date} || defined $met->{tournament};
            $shown++;
            my $won = $met->{winner};
            my $by = !defined $won || $won !~ /^[12]$/ ? '-'
                : $won == 1 ? surname($p1)
                :             surname($p2);
            push @out, sprintf '  %-10s %-20s %-4s %-12s %s',
                defined $met->{date} ? substr($met->{date}, 0, 10) : '-',
                clip(defined $met->{tournament} ? $met->{tournament} : '-', 20),
                clip(defined $met->{round} ? $met->{round} : '-', 4),
                clip($by, 12),
                defined $met->{score} ? $met->{score} : '';
        }
    }
    return @out;
}

# ------------------------------------------------------------------ self check

# The offline half: reading a score and deciding a break point are the only
# parts of this script with logic worth regressing, and neither needs a key
# or the network. Returns the failures and how many cases ran.
sub check_offline {
    my @case = (
        ['a single surname', surname('Carlos Alcaraz'), 'Alcaraz'],
        ['a surname in three parts', surname('Alex de Minaur'), 'Minaur'],
        ['a doubles team keeps both',
            surname('Marcel Granollers / Horacio Zeballos'), 'Granollers/Zeballos'],
        ['a missing name', surname(undef), '?'],
        ['games are player-major', fmt_games({ games => [[6, 3], [4, 4]] }), '6-4 3-4'],
        ['three sets read in order',
            fmt_games({ games => [[6, 3, 2], [4, 6, 1]] }), '6-4 3-6 2-1'],
        ['games of unequal length', fmt_games({ games => [[6, 3], [4]] }), '6-4 3--'],
        ['a completed match has empty games', fmt_games({ games => [[], []] }), ''],
        ['games of no score', fmt_games({}), ''],
        ['sets', fmt_sets({ sets => [1, 0] }), '1-0'],
        ['points', fmt_points({ points => ['40', '30'] }), '40-30'],
        ['points in a tiebreak',
            fmt_points({ points => ['5', '6'], is_tiebreak => 1 }), '5-6 TB'],
        ['points that are null', fmt_points({ points => [undef, undef] }), ''],
        ['the receiver at AD is a break point',
            is_break_point({ server => 1, points => ['40', 'AD'] }), 1],
        ['the server at AD is not',
            is_break_point({ server => 1, points => ['AD', '40'] }), 0],
        ['the receiver at 40-30 is a break point',
            is_break_point({ server => 1, points => ['30', '40'] }), 1],
        ['the receiver at 40-0 is a break point',
            is_break_point({ server => 1, points => ['0', '40'] }), 1],
        ['the receiver at 40-40 is not',
            is_break_point({ server => 1, points => ['40', '40'] }), 0],
        ['player 2 serving is read from the other side',
            is_break_point({ server => 2, points => ['40', '30'] }), 1],
        ['player 2 serving and holding is not',
            is_break_point({ server => 2, points => ['30', '40'] }), 0],
        ['a tiebreak has no break points',
            is_break_point({ server => 1, points => ['6', '7'], is_tiebreak => 1 }), 0],
        ['no server means no break point',
            is_break_point({ points => ['0', '40'] }), 0],
        ['null points mean no break point',
            is_break_point({ server => 1, points => [undef, undef] }), 0],
        ['an empty score means no break point', is_break_point({}), 0],
        ['a missing score means no break point', is_break_point(undef), 0],
        ['the serve marker follows the server',
            serve_mark({ server => 2 }, 2) . serve_mark({ server => 2 }, 1), '*'],
        ['a minute rate limit reads as one line',
            scalar response_error({ status => 429,
                content => '{"error":"rate_limited"}',
                headers => { 'retry-after' => '30' } }),
            'the API rate limited this key, retry in 30s (rate_limited)'],
        ['a spent daily quota names when it lifts',
            scalar response_error({ status => 429,
                content => '{"error":"rate_limited","scope":"day",'
                    . '"limit_per_day":100,"resets_at":"2026-09-13T00:00:00Z"}',
                headers => {} }),
            'this key is out of requests for today (100 a day), '
                . 'resets 2026-09-13T00:00:00Z'],
        ['a refused key reads as one line',
            scalar response_error({ status => 401, content => '' }),
            'the API rejected that key - check /set tennis_apikey'],
        ['an uncovered endpoint names the plan',
            scalar response_error({ status => 403,
                content => '{"error":"upgrade_required"}' }, 'PRO'),
            'that needs a PRO plan - see https://livetennisapi.com'],
        ['a merged match id forwards',
            scalar response_error({ status => 410,
                content => '{"error":"merged","merged_into":4321}' }),
            'that match was merged into #4321 - ask for that id'],
        ['a torn body reads as one line',
            scalar response_error({ status => 200, content => 'not json at all' }),
            'the API answered something that is not JSON'],
        ['a good body reads as no error',
            scalar response_error({ status => 200, content => '{"status":"ok"}' }), ''],
    );
    my @fail;
    for my $case (@case) {
        my ($what, $got, $want) = @{$case};
        $got = '' unless defined $got;
        push @fail, "$what (got '$got', wanted '$want')" if $got ne $want;
    }
    return (\@fail, scalar @case);
}

# The live half. /health takes no key, so a bare install can run this too.
# A health probe that cannot be reached is reported rather than counted as a
# script failure: it says something about the network, not about this file.
sub render_check {
    my ($res, $fail) = @_;
    my @fail = @{$fail};
    return 'Error: ' . join('; ', @fail) if @fail;
    my $err = response_error($res);
    return "ok - the API health probe did not answer ($err)" if defined $err;
    my $body = decode_body($res);
    my $status = ref $body eq 'HASH' ? $body->{status} : undef;
    return 'ok - the API health probe did not answer ok'
        unless defined $status && $status eq 'ok';
    return 'ok';
}

sub print_lines {
    my ($lines) = @_;
    for my $line (@{$lines}) {
        say_raw($line);
    }
    return;
}

sub print_check {
    my ($lines) = @_;
    my $verdict = defined $lines->[0] ? $lines->[0] : 'Error: no verdict';
    say_line("self check: $verdict");
    Irssi::command("selfcheckhelperscript $verdict")
        if exists $Irssi::Script::{'selfcheckhelperscript::'};
    return;
}

sub say_line {
    my ($text) = @_;
    Irssi::print("$IRSSI{name}: $text", MSGLEVEL_CLIENTCRAP);
    return;
}

sub say_raw {
    my ($text) = @_;
    Irssi::print($text, MSGLEVEL_CLIENTCRAP);
    return;
}

# -------------------------------------------------------------------- commands

# Read at call time, never cached, so /set takes effect on the next command.
sub api_key {
    my $key = Irssi::settings_get_str('tennis_apikey');
    return defined $key ? $key : '';
}

sub request {
    my ($path, $query, $render, @extra) = @_;
    my $key = api_key();
    if ($key eq '') {
        say_line('no API key yet - /set tennis_apikey <key>, and a free key '
            . '(no card) is at https://livetennisapi.com');
        return;
    }
    my @pair;
    for my $item (@{ $query || [] }) {
        push @pair, urlencode($item->[0]) . '=' . urlencode($item->[1]);
    }
    my $url = $base_url . $path . (@pair ? '?' . join('&', @pair) : '');
    background({
        cmd  => \&work,
        args => [$url, $key, $render, @extra],
        last => \&print_lines,
    });
    return;
}

sub urlencode {
    my ($raw) = @_;
    my $out = defined $raw ? "$raw" : '';
    utf8::encode($out) if utf8::is_utf8($out);
    $out =~ s/([^A-Za-z0-9._~-])/sprintf '%%%02X', ord $1/ge;
    return $out;
}

sub clamp {
    my ($raw, $fallback, $ceiling) = @_;
    return $fallback unless defined $raw && $raw =~ /^\s*(\d+)\s*$/;
    my $want = $1;
    return $fallback if $want < 1;
    return $ceiling if $want > $ceiling;
    return $want;
}

sub cmd_live {
    my ($args) = @_;
    request('/matches', [['status', 'live'], ['limit', clamp($args, 20, 50)]],
        \&render_live);
    return;
}

sub cmd_match {
    my ($args) = @_;
    my ($id) = $args =~ /^\s*(\d+)\s*$/;
    if (!defined $id) {
        say_line('which match? /tennis match <id> - the ids come from /tennis live');
        return;
    }
    request("/matches/$id", [], \&render_match);
    return;
}

sub cmd_rank {
    my ($args) = @_;
    my ($tour, $count) = $args =~ /^\s*(\S+)(?:\s+(\S+))?/;
    $tour = defined $tour ? lc $tour : '';
    if ($tour ne 'atp' && $tour ne 'wta') {
        say_line('which table? /tennis rank atp|wta [<n>]');
        return;
    }
    # The rank-ordered listing mode takes exactly one system and no player.
    request('/rankings', [['system', $tour], ['limit', clamp($count, 10, 50)]],
        \&render_rank, $tour);
    return;
}

sub cmd_h2h {
    my ($args) = @_;
    my ($p1, $p2) = $args =~ /^\s*(.+?)\s+vs?[.]?\s+(.+?)\s*$/i;
    if (!defined $p1) {
        say_line('two players please: /tennis h2h <a> vs <b>');
        return;
    }
    # The API matches on a name fragment and wants three characters of it.
    if (length($p1) < 3 || length($p2) < 3) {
        say_line('each name needs at least three characters');
        return;
    }
    request('/h2h', [['p1', $p1], ['p2', $p2]], \&render_h2h);
    return;
}

sub cmd_check {
    my ($fail, $total) = check_offline();
    say_line('self check: ' . ($total - @{$fail}) . "/$total offline cases pass");
    background({
        cmd  => \&work,
        args => ["$base_url/health", '', \&render_check, $fail],
        last => \&print_check,
    });
    return;
}

# One command, one handler, subcommands read off the front of the argument
# line. Binding "/tennis live" separately as well would leave it ambiguous
# which of the two handlers irssi called and with how much of the line.
sub cmd_tennis {
    my ($args) = @_;
    $args = '' unless defined $args;
    my ($word, $rest) = $args =~ /^\s*(\S*)\s*(.*)$/s;
    $word = lc $word;
    return cmd_live($rest) if $word eq '' || $word eq 'live';
    return cmd_match($rest) if $word eq 'match';
    return cmd_rank($rest) if $word eq 'rank' || $word eq 'rankings';
    return cmd_h2h($rest) if $word eq 'h2h';
    return cmd_check() if $word eq 'check';
    say_line("no subcommand called '$word' - try /help $IRSSI{name}");
    return;
}

sub cmd_help {
    my ($args) = @_;
    $args = '' unless defined $args;
    $args =~ s/\s+//g;
    if ($args eq $IRSSI{name}) {
        say_raw($help);
        Irssi::signal_stop();
    }
    return;
}

Irssi::signal_add('pidwait', \&sig_pidwait);
Irssi::settings_add_str($IRSSI{name}, 'tennis_apikey', '');
Irssi::command_bind($IRSSI{name}, \&cmd_tennis);
Irssi::command_bind('help', \&cmd_help);
