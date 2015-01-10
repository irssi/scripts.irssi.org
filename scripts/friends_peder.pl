# friends - irssi 0.8.4.CVS
#
#    $Id: friends.pl,v 1.34 2004/03/08 21:47:12 peder Exp $
#
# Copyright (C) 2001, 2002, 2003 by Peder Stray <peder@ninja.no>
#

use strict;
use Irssi 20020427.2353;
use Irssi::Irc;
use Irssi::TextUI;

use Data::Dumper;
$Data::Dumper::Indent = 1;

# ======[ Script Header ]===============================================

use vars qw{$VERSION %IRSSI};
($VERSION) = '$Revision: 1.34 $' =~ / (\d+\.\d+) /;
%IRSSI = (
          name        => 'friends',
          authors     => 'Peder Stray',
          contact     => 'peder@ninja.no',
          url         => 'http://ninja.no/irssi/friends.pl',
          license     => 'GPL',
          description => 'Basicly an autoop script with a nice interface and nick coloring ;)',
         );

# ======[ Variables ]===================================================

my(%friends, @friends);

my(%flagshort) = (
		  op => 'o',
		  voice => 'v',
		  color => 'c',
		 );
my(%flaglong) = map { $flagshort{$_} => $_ } keys %flagshort;

# ======[ Helper functions ]============================================

# --------[ crap ]------------------------------------------------------

sub crap {
    my $template = shift;
    my $msg = sprintf $template, @_;
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'friends_crap', $msg);
}

# --------[ load_friends ]----------------------------------------------

sub load_friends {
    my($file) = Irssi::get_irssi_dir."/friends";
    my($count) = 0;
    my($mask,$net,$channel,$flags,$flag);
    local(*FILE);

    %friends = ();
    open FILE, "<", $file;
    while (<FILE>) {
	($mask,$net,$channel,$flags) = split;
	for (split //, $flags) {
	    if ($flag = $flaglong{$_}) {
		$friends{$mask}{lc $net}{lc $channel}{$flag} = 1;
	    }
	}
    }
    close FILE;
    $count = keys %friends;
    
    crap("Loaded $count friends from $file");
}

# --------[ save_friends ]----------------------------------------------

sub save_friends {
    my($auto) = @_;
    my($file) = Irssi::get_irssi_dir."/friends";
    my($count) = 0;
    local(*FILE);

    return if $auto && !Irssi::settings_get_bool('friends_autosave');

    open FILE, ">", $file;
    for my $mask (keys %friends) {
	$count++;
	for my $net (keys %{$friends{$mask}}) {
	    for my $channel (keys %{$friends{$mask}{$net}}) {
		print FILE "$mask\t$net\t$channel\t".
		  join("", sort map {$flagshort{$_}} keys %{$friends{$mask}{$net}{$channel}}).
		    "\n";
	    }
	}
    }
    close FILE;

    crap("Saved $count friends to $file")
      unless $auto;
}

# --------[ is_friends_window ]-----------------------------------------

sub is_friends_window {
    my($win) = @_;
    return $win->{name} eq '<Friends>';
}

# --------[ get_friends_window ]----------------------------------------

sub get_friends_window {
    my($win) = Irssi::window_find_name('<Friends>');
    if ($win) {
	$win->set_active;
    } else {
	Irssi::command("window new hide");
	$win = Irssi::active_win;
	$win->set_name('<Friends>');
	$win->set_history('<Friends>');
    }
    return $win;
}

# --------[ get_friend ]------------------------------------------------

sub get_friend {
    my($channel,$nick) = @_;
    my($server) = $channel->{server};
    my($chan) = lc $channel->{name};
    my($net) = lc $server->{chatnet};
    my($flags,@friend);
    
    for my $mask (keys %friends) {
	next unless $server->mask_match_address($mask, 
						$nick->{nick},
						$nick->{host});
	for my $n ('*', $net) {
	    for my $c ('*', $chan) {
		if (exists $friends{$mask}{$n}{$c}) {
		    for my $flag (keys %{$friends{$mask}{$n}{$c}}) {
			$flags->{$flag} = 1;
		    }
		}
	    }
	}
	return $flags if $flags;
    }
    return undef;
}

# --------[ check_friends ]---------------------------------------------

sub check_friends {
    my($channel, @nicks) = @_;
    my(%op,%voice);
    my($nick,$friend,$list); 
    my(@friends);

    return unless $channel->{chanop} || $channel->{ownnick}{op};

    for $nick (@nicks) {
	$friend = get_friend($channel, $nick);
	next unless $friend;
	next if $nick->{nick} eq $channel->{server}{nick};
	if ($friend->{op} && !$nick->{op}) {
	    $op{$nick->{nick}} = 1;
	}
	if ($friend->{voice} && !$nick->{voice}) {
	    $voice{$nick->{nick}} = 1;
	}
	push @friends, ($nick->{op}?'@':'').
	  ($nick->{voice}?'+':'').$nick->{nick};
    }

    if (@friends && Irssi::settings_get_bool("friends_show_check")) {
	my($max) = Irssi::settings_get_int("friends_max_nicks");
	@friends = sort @friends;
	$channel->printformat(MSGLEVEL_CLIENTCRAP,
			      @friends>$max 
			      ? 'friends_check_more' : 'friends_check',
			      join(" ", splice @friends, 0, $max),
			      scalar @friends);
    }

    if ($list = join " ", sort keys %op) {
        $channel->command("op $list");
    }
    if ($list = join " ", sort keys %voice) {
        $channel->command("voice $list");
    }
}

# --------[ update_friends_hash ]---------------------------------------

sub update_friends_hash {
    %friends = ();
    for (@friends) {
	my($num,$mask,$chan,$net,$flags) = @$_;
	for (split //, $flags) {
	    $friends{$mask}{$net}{$chan}{$flaglong{$_}} = 1;
	}
    }
}

# --------[ update_friends_window ]-------------------------------------

sub update_friends_window {
    my($win) = Irssi::window_find_name('<Friends>');
    my($view);
    my($num) = 0;
    my($mask,$net,$channel,$flags);

    my(%net);

    if ($win) {
	@friends = ();
	for $mask (sort keys %friends) {
	    for $net (sort keys %{$friends{$mask}}) {
		for $channel (sort keys %{$friends{$mask}{$net}}) {
		    $flags = join "", sort map {$flagshort{$_}} 
		      keys %{$friends{$mask}{$net}{$channel}};
		    push @friends, [ ++$num, $mask, $channel, $net, $flags ];
		}
	    }
	}

	$view = $win->view;
	$view->remove_all_lines();
	$view->clear();
	$win->printformat(MSGLEVEL_NEVER, 'friends_header',
			  '##', 'Mask', 'Channel', 'ChatNet', 'Flags');
	for (@friends) {
	    ($num,$mask,$channel,$net,$flags) = @$_;
	    if (!$net{$net}) {
		my($n) = Irssi::chatnet_find($net);
		$net{$net} = $n?$n->{name}:$net;
	    }
	    $win->printformat(MSGLEVEL_NEVER, 'friends_line',
			      $num, $mask, $channel, $net{$net}, $flags);
	}
	$win->printformat(MSGLEVEL_NEVER, 'friends_footer', scalar @friends);
    }
}

# ======[ Signal Hooks ]================================================

# --------[ sig_send_command ]------------------------------------------

sub sig_send_command {
    my($win) = Irssi::active_win;
    if (is_friends_window($win)) {
	my($cmd,@param) = split " ", $_[0];
	my($changed) = 0;

	Irssi::signal_stop;

	for (lc $cmd) {
	    s,^/,,;
	    if (/^m(ask)?$/) {
		$changed = subcmd_friends_mask($win,@param);

	    } elsif (/^c(han(nel)?)?$/) {
		$changed = subcmd_friends_channel($win,@param);

	    } elsif (/^(?:n(et)?|chat(net)?)$/) {
		$changed = subcmd_friends_net($win,@param);
		
	    } elsif (/^del(ete)?$/) {
		$changed = subcmd_friends_delete($win,@param);
		
	    } elsif (/^f(lags?)?$/) {
		$changed = subcmd_friends_flags($win,@param);

	    } elsif (/^s(ave)?/) {
		save_friends();

	    } elsif (/^(?:e(xit)?|q(uit)?)$/) {
		$win->destroy;

	    } elsif (/^(?:h(elp)?|\?)$/) {
		subcmd_friends_help($win);

	    } else {
		$win->print("CMD: $cmd @{[map{\"[$_]\"}@param]}");

	    }
	}

	if ($changed) {
	    update_friends_hash();
	    update_friends_window();
	    save_friends(1);
	}
    }
}

# --------[ sig_massjoin ]----------------------------------------------

sub sig_massjoin {
    my($channel, $nicks) = @_;
    check_friends($channel, @$nicks);
}

# --------[ sig_nick_mode_changed ]-------------------------------------

sub sig_nick_mode_changed {
    my($channel, $nick) = @_;
    if ($channel->{synced} && $channel->{server}{nick} eq $nick->{nick}) {
	check_friends($channel, $channel->nicks);
    }
}

# --------[ sig_channel_sync ]------------------------------------------

sub sig_channel_sync {
    my($channel) = @_;
    check_friends($channel, $channel->nicks);
}

# --------[ sig_setup_reread ]------------------------------------------

sub sig_setup_reread {
    load_friends;
}

# --------[ sig_setup_save ]--------------------------------------------

sub sig_setup_save {
    my($mainconf,$auto) = @_;
    save_friends($auto);
}

# --------[ sig_window_changed ]----------------------------------------

sub sig_window_changed {
    my($new,$old) = @_;
    if (is_friends_window($new)) {
	update_friends_window();
    }
}

# --------[ sig_message_public ]----------------------------------------

sub sig_message_public {
    my($server, $msg, $nick, $addr, $target) = @_;
    my($window,$theme,$friend,$oform,$nform);
    my($channel) = $server->channel_find($target);

    return unless $channel;

    my($color) = Irssi::settings_get_str("friends_nick_color");

    $friend = get_friend($channel, $channel->nick_find($nick));

    if ($friend && $color =~ /^[rgbcmykpwRGBCMYKPWFU0-9_]$/) {
	$window = $server->window_find_item($target);
	$theme = $window->{theme} || Irssi::current_theme;
	
	$oform = $nform = $theme->get_format('fe-common/core', 'pubmsg');
	$nform =~ s/(\$(\[-?\d+\])?0)/%$color$1%n/g;

	$window->command("^format pubmsg $nform");
	Irssi::signal_continue(@_);
	$window->command("^format pubmsg $oform");
    }
}

# --------[ sig_message_irc_action ]------------------------------------

sub sig_message_irc_action {
    my($server, $msg, $nick, $addr, $target) = @_;
    my($window,$theme,$friend,$oform,$nform);
    my($channel) = $server->channel_find($target);

    return unless $channel;

    my($color) = Irssi::settings_get_str("friends_nick_color");

    $friend = get_friend($channel, $channel->nick_find($nick));

    if ($friend && $color =~ /^[rgbcmykpwRGBCMYKPWFU0-9_]$/) {
	$window = $server->window_find_item($target);
	$theme = $window->{theme} || Irssi::current_theme;
	
	$oform = $nform = $theme->get_format('fe-common/irc', 
					     'action_public');
	$nform =~ s/(\$(\[-?\d+\])?0)/%$color$1%n/g;

	$window->command("^format action_public $nform");
	Irssi::signal_continue(@_);
	$window->command("^format action_public $oform");
    }
}

# ======[ Commands ]====================================================

# --------[ FRIENDS ]---------------------------------------------------

# Usage: /FRIENDS
sub cmd_friends {
    my($win) = get_friends_window;
    update_friends_window();
}

# --------[ subcmd_friends_channel ]------------------------------------

sub subcmd_friends_channel {
    my($win,$num,$chan) = @_;

    unless ($chan && defined $num) {
	$win->print("Syntax: CHANNEL <num> <channel>", MSGLEVEL_NEVER);
	return;
    }

    unless (0 < $num && $num <= @friends) {
	$win->print("Error: Element $num not in list", MSGLEVEL_NEVER);
	return;
    }

    $friends[$num-1][2] = $chan;

    return 1;
}

# --------[ subcmd_friends_delete ]-------------------------------------

sub subcmd_friends_delete {
    my($win,$num) = @_;

    unless (defined $num) {
	$win->print("Syntax: DELETE <num>", MSGLEVEL_NEVER);
	return;
    }
    
    unless (0 < $num && $num <= @friends) {
	$win->print("Error: Element $num not in list", MSGLEVEL_NEVER);
	return;
    }
    
    splice @friends, $num-1, 1;

    return 1;
}

# --------[ subcmd_friends_flags ]--------------------------------------

sub subcmd_friends_flags {
    my($win,$num,$flags) = @_;
    my(%f);
    
    unless ($flags && defined $num) {
	$win->print("Syntax: FLAGS <num> <flags>", MSGLEVEL_NEVER);
	return;
    }

    unless (0 < $num && $num <= @friends) {
	$win->print("Error: Element $num not in list", MSGLEVEL_NEVER);
	return;
    }
    
    $friends[$num-1][4] = join "", sort grep {!$f{$_}++}
      split //, $flags;

    return 1;
}

# --------[ subcmd_friends_help ]---------------------------------------

sub subcmd_friends_help {
    my($win) = @_;

    $win->print(q{CHANNEL <num> <channel>    - set channel

    <channel> is either a channel name or * for all
}, MSGLEVEL_NEVER);

    $win->print(q{DELETE  <num>              - delete entry
}, MSGLEVEL_NEVER);

    $win->print(q{FLAGS   <num> <flags>      - set flags

    <flags> is a list of c (color), o (give op), v (give voice)
}, MSGLEVEL_NEVER);

    $win->print(q{MASK    <num> <mask>       - set mask

    <mask> is in the usual nick!user@host format
}, MSGLEVEL_NEVER);

    $win->print(q{NET     <num> <net>        - set net

   <net> is one of your defined ircnets or * for all
}, MSGLEVEL_NEVER);

}

# --------[ subcmd_friends_mask ]---------------------------------------

sub subcmd_friends_mask {
    my($win, $num, $mask) = @_;

    unless ($mask && defined $num) {
	$win->print("Syntax: MASK <num> <mask>", MSGLEVEL_NEVER);
	return;
    }
    
    unless (0 < $num && $num <= @friends) {
	$win->print("Error: Element $num not in list", MSGLEVEL_NEVER);
	return;
    }
    
    unless ($mask =~ /^.+!.+@.+$/) {
	$win->print("Error: Mask $mask is not valid", MSGLEVEL_NEVER);
    }
    
    $friends[$num-1][1] = $mask;

    return 1;
}

# --------[ subcmd_friends_net ]----------------------------------------

sub subcmd_friends_net {
    my($win,$num,$net) = @_;
    my($n);

    unless ($net && defined $num) {
	$win->print("Syntax: NET <num> <net>", MSGLEVEL_NEVER);
	return;
    }

    unless (0 < $num && $num <= @friends) {
	$win->print("Error: Element $num not in list", MSGLEVEL_NEVER);
	return;
    }
    
    if ($net eq '*') {
	# all is well
    } elsif ($n = Irssi::chatnet_find($net)) {
	$net = $n->{name};
    } else {
	$win->print("Error: No defined chatnet named $net",
		    MSGLEVEL_NEVER);
	return;
    }
    
    $friends[$num-1][3] = $net;

    return 1;
}

# --------[ ADDFRIEND ]-------------------------------------------------

# Usage: /ADDFRIEND <nick>|<mask> [<channel>|* [<net>|*]]
#                                 [-mask host|normal|domain|full]
#			          [-flags <flags>]
sub cmd_addfriend {
    my($param,$serv,$chan) = @_;
    my(@param,@flags);
    my($type) = Irssi::Irc::MASK_USER | Irssi::Irc::MASK_DOMAIN;
    my($mask,$flags,$channel,$net);
    my(@split) = split " ", $param;

    while (@split) {
	$_ = shift @split;
	if (/^-m(ask)?$/) {
	    $_ = shift @split;
	    if (/^h(ost)?$/) {
		$type = Irssi::Irc::MASK_HOST;
	    } elsif (/^n(ormal)?$/) {
		$type = Irssi::Irc::MASK_USER
	              | Irssi::Irc::MASK_DOMAIN;
	    } elsif (/^d(omain)?$/) {
		$type = Irssi::Irc::MASK_DOMAIN;
	    } elsif (/^f(ull)?$/) {
		$type = Irssi::Irc::MASK_NICK
	              | Irssi::Irc::MASK_USER
		      | Irssi::Irc::MASK_HOST;
	    } else {
		# fjekk
	    }
	} elsif (/^-flags?$/) {
	    $flags = shift @split;
	} else {
	    push @param, $_;
	}
    }
    ($mask,$channel,$net) = @param;

    unless ($mask) {
	crap("/ADDFRIEND [-mask full|normal|host|domain] [-flags <[o][v][c]>] <nick|mask> [<channel> [<chatnet>]]]");
	return;
    }

    $flags ||= "o";

    unless ($channel) {
	if ($chan) {
	    $channel = $chan->{name};
	} else {
	    crap("/ADDFRIEND needs a channel.");
	    return;
	}
    }

    unless ($net) {
	if ($serv) {
	    $net = $serv->{chatnet};
	} else {
	    crap("/ADDFRIEND needs a chatnet.");
	    return;
	}
    }

    # is this a nick we need to expand?
    unless ($mask =~ /.+!.+@.+/) {
	my($nick);
	if ($net ne '*') {
	    unless ($serv = Irssi::server_find_chatnet($net)) {
		crap("Error locating server for $net.");
		return;
	    }
	} else {
	    unless ($serv) {
		crap("Need a server for nick expansion");
		return
	    }
	}
	if ($channel ne '*') {
	    unless ($chan = $serv->channel_find($channel)) {
		crap("Error locating channel $channel.");
		return;
	    }
	} else {
	    unless ($chan) {
		crap("Need a channel for nick expansion");
		return;
	    }
	}
	unless ($nick = $chan->nick_find($mask)) {
	    crap("Error locating nick $mask.");
	    return;
	}
	$mask = Irssi::Irc::get_mask($nick->{nick}, $nick->{host}, $type);
    }

    for my $flag (split //, $flags) {
	unless ($flag = $flaglong{$flag}) {
	    crap("Unknown flag [$flag]");
	    next;
	}
	push @flags, $flag;
	$friends{$mask}{lc $net}{lc $channel}{$flag} = 1;
    }

    if (@flags) {
	crap("Added %s for %s in %s on %s.",
	     join(",", @flags), $mask, $channel, $net);
    }

    save_friends(1);
}

# ======[ Setup ]=======================================================

# --------[ Register settings ]-----------------------------------------

Irssi::settings_add_bool('friends', 'friends_autosave', 1);
Irssi::settings_add_int('friends', 'friends_max_nicks', 10);
Irssi::settings_add_bool('friends', 'friends_show_check', 1);

Irssi::settings_add_str('friends', 'friends_nick_color', '');

# --------[ Register formats ]------------------------------------------

Irssi::theme_register(
[
 'friends_crap',
 '{line_start}{hilight Friends:} $0',

 'friends_check',
 '{line_start}{hilight Friends} checked: $0',

 'friends_check_more',
 '{line_start}{hilight Friends} checked: $0 (+$1 more)',

 'friends_header',
 '<%W$[2]0%n> <%W$[33]1%n> <%W$[13]2%n> <%W$[13]3%n> <%W$[5]4%n>',

 'friends_line',
 '[%R$[-2]0%n] $[35]1 $[15]2 $[15]3 $[7]4',

 'friends_footer',
 "\n".'%4 List contains $0 friends %>%n',

]);

# --------[ Register signals ]------------------------------------------

Irssi::signal_add_first("send command", "sig_send_command");

Irssi::signal_add_last("massjoin", "sig_massjoin");
Irssi::signal_add_last("nick mode changed", "sig_nick_mode_changed");
Irssi::signal_add_last("channel sync", "sig_channel_sync");

Irssi::signal_add('setup saved', 'sig_setup_save');
Irssi::signal_add('setup reread', 'sig_setup_reread');

Irssi::signal_add('window changed', 'sig_window_changed');

Irssi::signal_add_first('message public', 'sig_message_public');
Irssi::signal_add_first('message irc action', 'sig_message_irc_action');

# --------[ Register commands ]-----------------------------------------

Irssi::command_bind('friends', 'cmd_friends');
Irssi::command_bind('addfriend', 'cmd_addfriend');

# --------[ Register timers ]-------------------------------------------

# --------[ Load config ]-----------------------------------------------

load_friends;

# ======[ END ]=========================================================

# Local Variables:
# header-initial-hide: t
# mode: header-minor
# end:
