use strict;
use warnings;

our $VERSION = '0.3'; # 75c8d7a9c21c683
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'mlist',
    description => 'Sortable /(M)LIST.',
    license     => 'ISC',
   );

use experimental 'signatures';
use List::Util qw(min max);
use Irssi;
use Irssi::Irc;
use Irssi::TextUI;

use constant PFM => Irssi::UI::TextDest->can('printformat_module') ? 1 : 0;
use constant SAC => Irssi->can('settings_add_choice') ? 1 : 0;

my %finished;

my %pos;
use constant {
    COUNT	 => 0,
    START	 => 1,
    CHANNEL_LEN	 => 2,
    USERS_LEN	 => 3,
    SORT	 => 4,
    NAME_FILTER	 => 5,
    TOPIC_FILTER => 6,
    MIN		 => 7,
    MAX		 => 8,
    ORDER	 => 9,
    TOPICLEN	 => 10,
    REGEXP       => 11,
};

my %in_progress;
use constant {
    TIME => 0,
    ARGS => 1,
};

my %list;
my %sorted_list;
use constant {
    CHANNEL => 0,
    USERS => 1,
    TOPIC => 2,
    CHANNEL_CLEAN => 3,
};

use constant {
    DESC => -1,
    ASC	 => 1,
};

if (Irssi->can('string_width')) {
    *screen_length = sub { Irssi::string_width($_[0]) };
}
else {
    require Text::CharWidth;
    *screen_length = sub { Text::CharWidth::mbswidth($_[0]) };
}

sub printt ($server, $level, $format, @args) {
    Irssi::Server::printformat($server, '', $level, $format, @args);
}

sub clean_name ($server, $channel) {
    my $chantypes = $server->isupport('chantypes') || '#&';
    my %idchan = split /[:,]/, $server->isupport('idchan') // '';
    my $pfx = substr $channel, 0, 1;
    $channel = substr $channel, 1 + $idchan{$pfx}
	if exists $idchan{$pfx};
    $channel =~ s/^[\Q$chantypes\E]+//;
    "\L$channel"
}

sub sig_liststart {
    my ($server, $args) = @_;
    my $tag = $server->{tag};
    unless ($in_progress{$tag} && $in_progress{$tag}[+TIME]) {
	$_[1] = "321 $_[1]";
	Irssi::signal_emit('default event numeric', @_);
	return;
    }

    printt($server, MSGLEVEL_CLIENTCRAP, 'mlist_liststart', $tag);
}

sub sig_list {
    my ($server, $args) = @_;
    my $tag = $server->{tag};
    unless ($in_progress{$tag} && $in_progress{$tag}[+TIME]) {
	$_[1] = "322 $_[1]";
	Irssi::signal_emit('default event numeric', @_);
	return;
    }

    my @args = split ' :', $args, 2;
    unshift @args, split ' ', shift @args;
    my ($client, $channel, $users, $info) = @args;
    push $list{$tag}->@*, [ $channel, $users, $info, clean_name($server, $channel) ];
    my $count = scalar $list{$tag}->@*;
    unless ($count % 123) {
	my $win = $server->window_find_level(MSGLEVEL_CLIENTCRAP) || Irssi::active_win;
	my $oldline = $win->view->get_bookmark('mlist_list');
	$win->view->remove_line($oldline) if $oldline;

	my $oll = $win->view->{buffer}{cur_line};
	my $duration = time - $in_progress{$tag}[+TIME];
	$win->print("[$tag] [mlist] Channel list in progress: retrieved $count channels in $duration seconds...", MSGLEVEL_NEVER);
	my $ll = $win->view->{buffer}{cur_line};
	$win->view->set_bookmark_bottom('mlist_list')
	    if $ll->{_irssi} ne $oll->{_irssi};
	$win->view->redraw if $oldline;
    }
}

sub sig_listend {
    my ($server, $args) = @_;
    my $tag = $server->{tag};
    unless ($in_progress{$tag} && $in_progress{$tag}[+TIME]) {
	$_[1] = "323 $_[1]";
	Irssi::signal_emit('default event numeric', @_);
	return;
    }

    return unless $in_progress{$tag} && $in_progress{$tag}[+TIME];
    $finished{$tag} = time;
    my $delta = $finished{$tag} - $in_progress{$tag}[+TIME];
    $in_progress{$tag}[+TIME] = 0;
    my $win = $server->window_find_level(MSGLEVEL_CLIENTCRAP) || Irssi::active_win;
    my $oldline = $win->view->get_bookmark('mlist_list');
    $win->view->remove_line($oldline) if $oldline;
    $win->view->redraw if $oldline;
    printt($server, MSGLEVEL_CLIENTCRAP, 'mlist_listend', "$delta", "@{[ scalar $list{$tag}->@* ]}", $tag);
}

sub sig_server_disconnected ($server) {
    my $tag = $server->{tag};
    delete $in_progress{$tag};
}

sub sort_flag ($f) {
    if (!defined $f) {
	'none'
    }
    elsif ($f == +CHANNEL || $f == +CHANNEL_CLEAN) {
	'name'
    }
    elsif ($f == +USERS) {
	'users'
    }
    elsif ($f == +TOPIC) {
	'topic'
    }
    else {
	'none'
    }
}

sub cmd_mlist ($data, $server, $witem) {
    unless ($server) {
	if (+PFM) {
	    Irssi::UI::Window::format_create_dest(undef, MSGLEVEL_CLIENTERROR)->printformat_module('fe-common/core', 'not_connected');
	}
	else {
	    print CLIENTERROR 'Not connected to server';
	}
	return;
    }
    my $tag = $server->{tag};

    $data =~ s/^\s*//;
    $data =~ s/\s*$//;

    my ($opts, $arg) = Irssi::command_parse_options('mlist', $data);
    $opts //= +{};
    my $numarg = " $arg";
    if ($numarg =~ s/\s+(\d+)(?:\s+(\d+))?+$//) {
	$opts->{count} = $1;
	$opts->{start} = $2
	    if defined $2;
	$arg = $numarg;
    }

    my $error = 0;

    if (exists $opts->{clear}) {
	delete $opts->{clear};
	if (keys $opts->%* || $arg) {
	    print CLIENTERROR '[mlist] -clear cannot be used together with other arguments';
	    return;
	}
	if ($in_progress{$tag} && $in_progress{$tag}[+TIME]) {
	    print CLIENTERROR '[mlist] Cannot -clear while the channel list is still being retrieved';
	    return;
	}
	delete $pos{$tag};
	delete $in_progress{$tag};
	delete $finished{$tag};
	delete $sorted_list{$tag};
	if (!exists $list{$tag}) {
	    print CLIENTCRAP '[mlist] There is no channel list';
	}
	else {
	    delete $list{$tag};
	    print CLIENTCRAP '[mlist] Channel list cleared';
	}
	return;
    }

    my ($order, $field, $num, $sort, $show, $prev, $next);
    my ($name_filter, $topic_filter);

    my $s = $opts->{sort} || ($pos{$tag} && sort_flag($pos{$tag}[+SORT])) || (+SAC ? sort_flag(Irssi::settings_get_choice('mlist_default_sort') - 1) : Irssi::settings_get_string('mlist_default_sort'));
    if ($s =~ /^no(ne?)?$/i) {
	$sort = 0;
    }
    else {
	if ($s =~ /^t(o(p(ic?)?)?)?$/i) {
	    $field = +TOPIC;
	    $order = exists $opts->{desc} ? +DESC : +ASC;
	}
	elsif ($s =~ /^u(s(e(rs?)?)?)?/i || $s =~ /^m(e(m(b(e(rs?)?)?)?)?)?/i) {
	    $field = +USERS;
	    $num = 1;
	    $order = exists $opts->{asc} ? +ASC : +DESC;
	}
	elsif ($s =~ /^n(a(me?)?)?/i || $s =~ /^c(h(a(n(n(el?)?)?)?)?)?/i) {
	    $field = +CHANNEL_CLEAN;
	    $order = exists $opts->{desc} ? +DESC : +ASC;
	}
	else {
	    print CLIENTERROR '[mlist] -sort must be one of [topic, users, name]';
	    $error++;
	}
	$sort = 1;
    }
    if (!$opts->{sort} && !exists $opts->{asc} && !exists $opts->{desc} && $pos{$tag}) {
	$order = $pos{$tag}[+ORDER];
    }

    if (exists $opts->{prev}) {
	$prev = 1;
    }
    if (exists $opts->{next}) {
	$next = 1;
    }
    if (exists $opts->{count}) {
    }

    if (exists $opts->{min} && length $opts->{min} && $opts->{min} !~ /^\d+$/) {
	print CLIENTERROR '[mlist] -min is not a number';
	$error++;
    }
    if (exists $opts->{max} && length $opts->{max} && $opts->{max} !~ /^\d+$/) {
	print CLIENTERROR '[mlist] -max is not a number';
	$error++;
    }
    if (exists $opts->{topiclen} && length $opts->{topiclen} && $opts->{topiclen} !~ /^\d+$/) {
	print CLIENTERROR '[mlist] -topiclen is not a number';
	$error++;
    }

    my $conflict = (exists $opts->{sort}) + (exists $opts->{next}) + (exists $opts->{prev});
    if ($conflict > 1) {
	print CLIENTERROR '[mlist] Only one of -sort, -prev, or -next can be specified';
	$error++;
    }

    $conflict = (exists $opts->{asc}) + (exists $opts->{desc});
    if ($conflict > 1) {
	print CLIENTERROR '[mlist] Only one of -asc or -desc can be specified';
	$error++;
    }

    $conflict = (exists $opts->{regexp}) + (exists $opts->{noregexp});
    if ($conflict > 1) {
	print CLIENTERROR '[mlist] Only one of -regexp or -noregexp can be specified';
	$error++;
    }

    my $regexp = exists $opts->{regexp} ? 1 : exists $opts->{noregexp} ? 0 : ($pos{$tag} && $pos{$tag}[+REGEXP]) || 0;
    my $name_f = length $opts->{name} ? $opts->{name} : exists $opts->{name} ? undef : ($pos{$tag} && $pos{$tag}[+NAME_FILTER]) || undef;
    my $topic_f = length $opts->{topic} ? $opts->{topic} : exists $opts->{topic} ? undef : ($pos{$tag} && $pos{$tag}[+TOPIC_FILTER]) || undef;

    if (length $name_f) {
	if ($regexp) {
	    local $@;
	    eval { $name_filter = qr/$name_f/i };
	    if (my $err = $@) {
		$err =~ s/ at .* line .*\.\r?\n//;
		print CLIENTERROR "[mlist] Error in -name regexp: $err";
		$error++;
	    }
	}
	else {
	    my $name = $name_f;
	    $name = "*$name*" unless $name =~ /\*/;
	    $name = "\Q$name";
	    my %fn = ('*' => '.*', '?' => '.');
	    $name =~ s/\\([*?])/$fn{$1}/g;
	    $name_filter = qr/^$name$/;
	}
    }
    else {
	$name_filter = undef;
    }

    if (length $topic_f) {
	if ($regexp) {
	    local $@;
	    eval { $topic_filter = qr/$topic_f/i };
	    if (my $err = $@) {
		$err =~ s/ at .* line .*\.\r?\n//;
		print CLIENTERROR "[mlist] Error in -topic regexp: $err";
		$error++;
	    }
	}
	else {
	    my $topic = $topic_f;
	    $topic = "*$topic*" unless $topic =~ /\*/;
	    $topic = "\Q$topic";
	    my %fn = ('*' => '.*', '?' => '.');
	    $topic =~ s/\\([*?])/$fn{$1}/g;
	    $topic_filter = qr/^$topic$/;
	}
    }
    else {
	$topic_filter = undef;
    }

    my $force = exists $opts->{force};
    delete $opts->{force};
    if ($in_progress{$tag} && $in_progress{$tag}[+TIME] && !$force) {
	print CLIENTERROR '[mlist] Retrieving the channel list is still in progress, be patient...';
	$error++;
    }

    return if $error;

    my $count = $opts->{count} || ($pos{$tag} && $pos{$tag}[+COUNT]) || Irssi::settings_get_int('mlist_default_count');
    my $start = $opts->{start} ? $opts->{start} - 1 : 0;
    my $topiclen = length $opts->{topiclen} ? $opts->{topiclen} : exists $opts->{topiclen} ? -1 : ($pos{$tag} && $pos{$tag}[+TOPICLEN]) || -1;
    my $min = length $opts->{min} ? $opts->{min} : exists $opts->{min} ? undef : ($pos{$tag} && $pos{$tag}[+MIN]) || undef;
    my $max = length $opts->{max} ? $opts->{max} : exists $opts->{max} ? undef : ($pos{$tag} && $pos{$tag}[+MAX]) || undef;

    my @list;
    @list = $list{$tag}->@*
	if $list{$tag};
    if ($sort) {
	@list = sort {
	    $order * ($num ? $a->[$field] <=> $b->[$field]
		: $a->[$field] cmp $b->[$field])
	} @list;
    }
    if ($name_filter) {
	@list = grep { $_->[+CHANNEL] =~ $name_filter } @list;
    }
    if ($topic_filter) {
	@list = grep { $_->[+TOPIC] =~ $topic_filter } @list;
    }
    if ($min) {
	@list = grep { $_->[+USERS] >= $min } @list;
    }
    if ($max) {
	@list = grep { $_->[+USERS] <= $max } @list;
    }

    if ($pos{$tag} && exists $opts->{start}) {
	$pos{$tag}[+START] = $opts->{start} - 1;
    }

    if ($next) {
	unless ($pos{$tag}) {
	    print CLIENTERROR '[mlist] The first page has not been viewed';
	    return;
	}
	if ($pos{$tag}[+START] + $pos{$tag}[+COUNT] > scalar $sorted_list{$tag}->@*) {
	    printt(undef, MSGLEVEL_CLIENTCRAP, 'mlist_endoflist');
	    return;
	}
	$pos{$tag}[+START] += $pos{$tag}[+COUNT];
    }
    elsif ($prev) {
	unless ($pos{$tag}) {
	    print CLIENTERROR '[mlist] The first page has not been viewed';
	    return;
	}
	if (!$pos{$tag}[+START]) {
	    printt(undef, MSGLEVEL_CLIENTCRAP, 'mlist_endoflist');
	    return;
	}
	$pos{$tag}[+START] -= $pos{$tag}[+COUNT];
	$pos{$tag}[+START] = 0
	    if $pos{$tag}[+START] < 0;
    }
    elsif (keys $opts->%*) {
	$sorted_list{$tag} = \@list;
	my $channel_len = max 7, map { screen_length($_->[+CHANNEL]) } @list;
	my $users_len = max 5, map { screen_length($_->[+USERS]) } @list;
	$pos{$tag} = [ $count, $start,
		       $channel_len, $users_len,
		       $field, $name_f, $topic_f, $min, $max, $order, $topiclen, $regexp ];
    }

    if ($pos{$tag} && exists $opts->{count}) {
	$pos{$tag}[+COUNT] = $opts->{count};
    }

    if (keys $opts->%*) {
	if (!$in_progress{$tag}) {
	    print CLIENTERROR '[mlist] No channel list loaded, run /MLIST without count or -sort first';
	    return;
	}
	my @sublist;
	my $i = $pos{$tag}[+START];
	my $start = $i + 1;
	for my $c (1 .. $pos{$tag}[+COUNT]) {
	    my $e = $sorted_list{$tag}[$i];
	    last unless $e;
	    push @sublist, $e;
	    $i++;
	}
	my $end = $i + 1;
	my $channel_len = max 7, map { screen_length($_->[+CHANNEL]) } @sublist;
	my $users_len = max 5, map { screen_length($_->[+USERS]) } @sublist;
	printt($server, MSGLEVEL_CLIENTCRAP, 'mlist_list_header', $tag);
	printt($server, MSGLEVEL_CLIENTCRAP, 'mlist_list_line',
	       (sprintf "%-${channel_len}s", 'Channel'),
	       (sprintf "%${users_len}s", 'Users'),
	       '(Topic info)', '', '', $tag);
	printt($server, MSGLEVEL_CLIENTCRAP, 'mlist_list_line',
	       ('-' x $channel_len),
	       ('-' x $users_len),
	       ('-' x (50 - min 20, $channel_len + $users_len)), '', '', $tag);
	for my $e (@sublist) {
	    printt($server, MSGLEVEL_CLIENTCRAP, 'mlist_list_line',
		   (sprintf "%-${channel_len}s", $e->[0]),
		   (sprintf "%${users_len}s", "$e->[1]"),
		   $topiclen && $topiclen > -1 ? substr $e->[2], 0, $topiclen : $e->[2],
		   "$start", "$end", $tag);
	}
	printt($server, MSGLEVEL_CLIENTCRAP, 'mlist_list_line',
	       ('-' x $channel_len),
	       ('-' x $users_len),
	       ('-' x (50 - min 20, $channel_len + $users_len)), '', '', $tag);

	my $sort_name;
	if (!defined $pos{$tag}[+SORT]) {
	    $sort_name = '(none)';
	}
	elsif ($pos{$tag}[+SORT] == +CHANNEL || $pos{$tag}[+SORT] == +CHANNEL_CLEAN) {
	    $sort_name = 'Name';
	}
	elsif ($pos{$tag}[+SORT] == +USERS) {
	    $sort_name = 'Users';
	}
	elsif ($pos{$tag}[+SORT] == +TOPIC) {
	    $sort_name = 'Topic';
	}
	my $sort_order;
	if (!defined $pos{$tag}[+ORDER]) {
	    $sort_order = '';
	}
	elsif ($pos{$tag}[+ORDER] == +ASC) {
	    $sort_order = 'Asc';
	}
	elsif ($pos{$tag}[+ORDER] == +DESC) {
	    $sort_order = 'Desc';
	}
	printt($server, MSGLEVEL_CLIENTCRAP, 'mlist_list_footer',
	       $sort_name . ($sort_order ? "($sort_order)" : ''),
	       ($pos{$tag}[+NAME_FILTER] // '(none)'),
	       ($pos{$tag}[+TOPIC_FILTER] // '(none)'),
	       ($pos{$tag}[+MIN] // '-'),
	       ($pos{$tag}[+MAX] // '-'),
	       ($in_progress{$tag}[+ARGS] || '(none)'),
	       "@{[ $pos{$tag}[+START] + 1 ]}", "$i", "@{[ scalar $sorted_list{$tag}->@* ]}",
	      $tag);
    }
    else {
	if ($finished{$tag}) {
	    my $td = time - $finished{$tag};

	    if ($td <= 600 && $data eq $in_progress{$tag}[+ARGS]) {
		print CLIENTERROR "[mlist] There is a channel list from $td seconds ago, use -force to reload or /MLIST $count to view it.";
		return;
	    }
	}
	$list{$tag} = [];
	delete $finished{$tag};
	delete $pos{$tag};
	$in_progress{$tag} = [ time, $data ];
	$server->send_raw("LIST $data");
    }
}

sub iaquote ($str) {
    if ($str =~ /"/ || $str =~ /\s/) {
	$str =~ s/(["\\])/\\$1/g;
	$str = "\"$str\"";
    }
    $str
}

sub complete_cmd_mlist ($cl, $win, $word, $start, $ws) {
    my @start = split ' ', $start;
    if (@start) {
	if ($start[-1] =~ /^-s(o(rt?)?)?/i) {
	    my @args = qw(topic users name);
	    @args = grep /^\Q$word/i, @args;
	    push @$cl, @args;
	}
	elsif ($start[-1] =~ /^-na(me?)?/i) {
	    my $server = $win ? $win->{active_server} : undef;
	    my $tag = $server ? $server->{tag} : undef;
	    if (!length $word && $tag && $pos{$tag} && $pos{$tag}[+NAME_FILTER]) {
		unshift @$cl, iaquote($pos{$tag}[+NAME_FILTER]);
	    }
	}
	elsif (lc $start[-1] eq '-topic') {
	    my $server = $win ? $win->{active_server} : undef;
	    my $tag = $server ? $server->{tag} : undef;
	    if (!length $word && $tag && $pos{$tag} && $pos{$tag}[+TOPIC_FILTER]) {
		unshift @$cl, iaquote($pos{$tag}[+TOPIC_FILTER]);
	    }
	}
    }
}

Irssi::theme_register([
    'mlist_list_header' => ('=' x 20) . ' Channel list ' . ('=' x 20),
    'mlist_list_line' => '[$0] $1 %|$2',
    'mlist_list_footer' => 'Sort: $0  Filter: $1  Topic filter: $2  Min: $3  Max: $4  Args: $5  [${6}-$7/$8]',
    'mlist_liststart' => '[mlist] Now retrieving channel list, be patient...',
    'mlist_listend' => '[mlist] Finished retrieving the channel list with $1 channels in $0 seconds',
    'mlist_endoflist' => '[mlist] Reached end of list',
    'mlist_beginningoflist' => '[mlist] Reached beginning of list',
   ]);

Irssi::signal_add_last({
    'event 321' => 'sig_liststart',
    'event 322' => 'sig_list',
    'event 323' => 'sig_listend',
   });

Irssi::signal_add('server disconnected' => 'sig_server_disconnected');

Irssi::settings_add_int('misc', 'mlist_default_count', 20);
if (+SAC) {
    Irssi::settings_add_choice('misc', 'mlist_default_sort', 0, 'none;channel;users;topic');
}
else {
    Irssi::settings_add_string('misc', 'mlist_default_sort', 'none');
}

Irssi::command_bind('mlist' => 'cmd_mlist');
Irssi::command_set_options('mlist' => '+sort +name +min +max +topic regexp noregexp asc desc next prev +topiclen force');

Irssi::signal_register({'complete command ' => [qw[glistptr_char* Irssi::UI::Window string string intptr]]});

Irssi::signal_add('complete command mlist' => 'complete_cmd_mlist');

Irssi::command_bind_last(
    'help' => sub ($args, $server, $witem) {
	if ($args =~ /^mlist *$/i) {
	    print CLIENTCRAP <<HELP
%9Syntax:%9

MLIST <args>
MLIST %|[-sort [topic|users|name]] [-name <channel name filter>] [-min <#>] [-max <#>] [-topic <topic filter>] [-regexp|-noregexp] [-asc|-desc] [-topiclen <#>] [-force] [<count>] [<start>]
MLIST -prev|-next
MLIST -clear

%9Description:%9

    Sort and view the channel list.  Without arguments, or with
    <args>, will request the channel list from the server.  With -sort
    or <count>, will show the retrieved channel list.

%9Parameters:%9

    <args>:          Arguments to pass to the IRC server for server side filtering, see /LIST x or /SHELP LIST.
    -sort:           Sort by channel name, user count, or topic.
    -name:           Filter the channel name by this pattern.
    -min:            Filter by minimum user count.
    -max:            Filter by maximum user count.
    -topic:          Filter the channel topic by this pattern.
    -regexp:         The patterns are regular expressions.
    -noregexp:       The patterns are wildcard masks.
    -asc:            Sort the list in ascending order.
    -desc:           Sort the list in descending order.
    -topiclen:       Limit the length of the topic column to this number of characters.
    -force:          Force refresh the list.
    <count>:         The number of channels to view on one page.
    <start>:         Display the channel list starting at this entry.
    -prev:           View the previous page.
    -next:           View the next page.
    -clear:          Clear the retrieved channel lists.

%9Common server side arguments:%9

     %9<%9%Imax_users%I    ; Show all channels with less than max_users.
     %9>%9%Imin_users%I    ; Show all channels with more than min_users.
     %9C<%9%Imax_minutes%I ; Channels that exist less than max_minutes.
     %9C>%9%Imin_minutes%I ; Channels that exist more than min_minutes.
     %9T<%9%Imax_minutes%I ; Channels with a topic last set less than max_minutes ago.
     %9T>%9%Imin_minutes%I ; Channels with a topic last set more than min_minutes ago.
     %Ipattern%I       ; Channels with names matching pattern. 
     %9!%9%Ipattern%I      ; Channels with names not matching pattern. 
    Note: Patterns may contain * and ?. You may only give one pattern match constraint.
    Example: /MLIST <3,>1,C<10,T>0,#a*  ; 2 users, younger than 10 min., topic set., starts with #a

%9Example:%9

    /MLIST >100
    /MLIST -sort users
    /MLIST 10
    /MLIST -name ubuntu
    /MLIST -next

%9See also:%9 LIST
HELP
	}
    });
