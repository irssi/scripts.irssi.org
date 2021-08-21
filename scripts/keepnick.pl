#
# Copyright (C) 2001-2021 by Peder Stray <peder.stray@gmail.com>
#

use strict;
use Irssi 20011118.1727;
use Irssi::Irc;

use vars qw{$VERSION %IRSSI};
($VERSION) = '$Revision: 1.19.1 $' =~ / (\d+(\.\d+)+) /;
%IRSSI = (
	  name        => 'keepnick',
	  authors     => 'Peder Stray',
	  contact     => 'peder.stray@gmail.com',
	  url         => 'https://github.com/pstray/irssi-keepnick',
	  license     => 'GPL',
	  description => 'Try to get your nick back when it becomes available.',
	 );

my(%keepnick);		# nicks we want to keep
my(%getnick);		# nicks we are currently waiting for
my(%inactive);		# inactive chatnets
my(%manual);		# manual nickchanges

sub change_nick {
    my($server,$nick) = @_;
    $server->redirect_event('keepnick nick', 1, ":$nick", -1, undef,
			    {
			     "event nick" => "redir keepnick nick",
			     "" => "event empty",
			    });
    $server->send_raw("NICK :$nick");
}

sub check_nick {
    my($server,$net,$nick);

    %getnick = ();	# clear out any old entries

    for $net (keys %keepnick) {
	next if $inactive{$net};
	$server = Irssi::server_find_chatnet($net);
	next unless $server;
	next if lc $server->{nick} eq lc $keepnick{$net};

	$getnick{$net} = $keepnick{$net};
    }

    for $net (keys %getnick) {
	$server = Irssi::server_find_chatnet($net);
	next unless $server;
	next unless ref($server) eq 'Irssi::Irc::Server'; # this only work on IRC
	$nick = $getnick{$net};
	if (lc $server->{nick} eq lc $nick) {
	    delete $getnick{$net};
	    next;
	}
	$server->redirect_event('keepnick ison', 1, '', -1, undef,
				{ "event 303" => "redir keepnick ison" });
	$server->send_raw("ISON :$nick");
    }
}

sub load_nicks {
    my($file) = Irssi::get_irssi_dir."/keepnick";
    my($count) = 0;
    local(*CONF);

    %keepnick = ();
    open CONF, "<", $file;
    while (<CONF>) {
	my($net,$nick) = split;
	if ($net && $nick) {
	    $keepnick{lc $net} = $nick;
	    $count++;
	}
    }
    close CONF;

    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_crap',
		       "Loaded $count nicks from $file");
}

sub save_nicks {
    my($auto) = @_;
    my($file) = Irssi::get_irssi_dir."/keepnick";
    my($count) = 0;
    local(*CONF);

    return if $auto && !Irssi::settings_get_bool('keepnick_autosave');

    open CONF, ">", $file;
    for my $net (sort keys %keepnick) {
	print CONF "$net\t$keepnick{$net}\n";
	$count++;
    }
    close CONF;

    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_crap',
		       "Saved $count nicks to $file")
	unless $auto;
}

sub server_printformat {
    my($server,$level,$format,@params) = @_;
    my($emitted) = 0;
    for my $win (Irssi::windows) {
	for my $item ($win->items) {
	    next unless ref $item;
	    if ($item->{server}{chatnet} eq $server->{chatnet}) {
		$item->printformat($level,$format,@params);
		$emitted++;
		last;
	    }
	}
    }
    $server->printformat(undef,$level,$format,@params)
	unless $emitted;
}

# if anyone changes their nick, check if we want their old one.
sub sig_message_nick {
    my($server,$newnick,$oldnick) = @_;
    my($chatnet) = lc $server->{chatnet};
    if (lc $oldnick eq lc $getnick{$chatnet}) {
	change_nick($server, $getnick{$chatnet});
    }
}

# if we change our nick, check it to see if we wanted it and if so
# remove it from the list.
sub sig_message_own_nick {
    my($server,$newnick,$oldnick) = @_;
    my($chatnet) = lc $server->{chatnet};
    if (lc $newnick eq lc $keepnick{$chatnet}) {
	delete $getnick{$chatnet};
	if ($inactive{$chatnet}) {
	    delete $inactive{$chatnet};
	    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_unhold',
			       $newnick, $chatnet);
	}
    } elsif (lc $oldnick eq lc $keepnick{$chatnet} &&
	     lc $newnick eq lc $manual{$chatnet}) {
	$inactive{$chatnet} = 1;
	delete $getnick{$chatnet};
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_hold',
			   $oldnick, $chatnet);
    }
}

sub sig_message_own_nick_block {
    my($server,$new,$old,$addr) = @_;
    Irssi::signal_stop();
    if (Irssi::settings_get_bool('keepnick_quiet')) {
	Irssi::printformat(MSGLEVEL_NICKS | MSGLEVEL_NO_ACT,
			   'keepnick_got_nick', $new, $server->{chatnet});
    } else {
	server_printformat($server, MSGLEVEL_NICKS | MSGLEVEL_NO_ACT,
			   'keepnick_got_nick', $new, $server->{chatnet});
    }
}

# if anyone quits, check if we want their nick.
sub sig_message_quit {
    my($server,$nick) = @_;
    my($chatnet) = lc $server->{chatnet};
    if (lc $nick eq lc $getnick{$chatnet}) {
	change_nick($server, $getnick{$chatnet});
    }
}

sub sig_redir_keepnick_ison {
    my($server,$text) = @_;
    my $nick = $getnick{lc $server->{chatnet}};
    change_nick($server, $nick)
      unless $text =~ /:\Q$nick\E\s?$/i;
}

sub sig_redir_keepnick_nick {
    my($server,$args,$nick,$addr) = @_;
    Irssi::signal_add_first('message own_nick', 'sig_message_own_nick_block');
    Irssi::signal_emit('event nick', @_);
    Irssi::signal_remove('message own_nick', 'sig_message_own_nick_block');
}

# main setup is reread, so let us do it too
sub sig_setup_reread {
    load_nicks;
}

# main config is saved, and so we should save too
sub sig_setup_save {
    my($mainconf,$auto) = @_;
    save_nicks($auto);
}

# Usage: /KEEPNICK [-net <chatnet>] [<nick>]
sub cmd_keepnick {
    my(@params) = split " ", shift;
    my($server) = @_;
    my($chatnet,$nick,@opts);

    # parse named parameters from the parameterlist
    while (@params) {
	my($param) = shift @params;
	if ($param =~ /^-(chat|irc)?net$/i) {
	    $chatnet = shift @params;
	} elsif ($param =~ /^-/) {
	    Irssi::print("Unknown parameter $param");
	} else {
	    push @opts, $param;
	}
    }
    $nick = shift @opts;

    # check if the ircnet specified (if any) is valid, and if so get the
    # server for it
    if ($chatnet) {
	my($cn) = Irssi::chatnet_find($chatnet);
	unless ($cn) {
	    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_crap',
			       "Unknown chat network: $chatnet");
	    return;
	}
	$chatnet = $cn->{name};
	$server = Irssi::server_find_chatnet($chatnet);
    }

    # if we need a server, check if the one we got is connected.
    unless ($server || ($nick && $chatnet)) {
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_crap',
			   "Not connected to server");
	return;
    }

    # lets get the chatnet, and the nick we want
    $chatnet ||= $server->{chatnet};
    $nick    ||= $server->{nick};

    # check that we really have a chatnet
    unless ($chatnet) {
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_crap',
			   "Unable to find server network, maybe you forgot /server add before connecting?");
	return;
    }

    if ($inactive{lc $chatnet}) {
	delete $inactive{lc $chatnet};
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_unhold',
			   $nick, $chatnet);
    }

    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_add', $nick,
		       $chatnet);

    $keepnick{lc $chatnet} = $nick;

    save_nicks(1);
    check_nick();
}

# Usage: /UNKEEPNICK [<chatnet>]
sub cmd_unkeepnick {
    my($chatnet,$server) = @_;

    # check if the ircnet specified (if any) is valid, and if so get the
    # server for it
    if ($chatnet) {
	my($cn) = Irssi::chatnet_find($chatnet);
	unless ($cn) {
	    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_crap',
			       "Unknown chat network: $chatnet");
	    return;
	}
	$chatnet = $cn->{name};
    } else {
	$chatnet = $server->{chatnet};
    }

    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_remove',
		       $keepnick{lc $chatnet}, $chatnet);

    delete $keepnick{lc $chatnet};
    delete $getnick{lc $chatnet};

    save_nicks(1);
}

# Usage: /LISTNICK
sub cmd_listnick {
    my(@nets) = sort keys %keepnick;
    my $net;
    if (@nets) {
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_list_header');
	for (@nets) {
	    $net = Irssi::chatnet_find($_);
	    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_list_line',
			       $keepnick{$_},
			       $net ? $net->{name} : ">$_<",
			       $inactive{$_}?'inactive':'active');
	}
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_list_footer');
    } else {
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'keepnick_list_empty');
    }
}

sub cmd_nick {
    my($data,$server) = @_;
    my($nick) = split " ", $data;
    return unless $server;
    $manual{lc $server->{chatnet}} = $nick;
}

Irssi::settings_add_bool('keepnick', 'keepnick_autosave', 1);
Irssi::settings_add_bool('keepnick', 'keepnick_quiet', 0);

Irssi::theme_register(
[
 'keepnick_crap',
 '{line_start}{hilight Keepnick:} $0',

 'keepnick_add',
 '{line_start}{hilight Keepnick:} Now keeping {nick $0} on [$1]',

 'keepnick_remove',
 '{line_start}{hilight Keepnick:} Stopped trying to keep {nick $0} on [$1]',

 'keepnick_hold',
 '{line_start}{hilight Keepnick:} Nickkeeping deactivated on [$1]',

 'keepnick_unhold',
 '{line_start}{hilight Keepnick:} Nickkeeping reactivated on [$1]',

 'keepnick_list_empty',
 '{line_start}{hilight Keepnick:} No nicks in keep list',

 'keepnick_list_header',
 '',

 'keepnick_list_line',
 '{line_start}{hilight Keepnick:} Keeping {nick $0} in [$1] ($2)',

 'keepnick_list_footer',
 '',

 'keepnick_got_nick',
 '{hilight Keepnick:} Nickstealer left [$1], got {nick $0} back',

]);

Irssi::signal_add('message quit', 'sig_message_quit');
Irssi::signal_add('message nick', 'sig_message_nick');
Irssi::signal_add('message own_nick', 'sig_message_own_nick');

Irssi::signal_add('redir keepnick ison', 'sig_redir_keepnick_ison');
Irssi::signal_add('redir keepnick nick', 'sig_redir_keepnick_nick');

Irssi::signal_add('setup saved', 'sig_setup_save');
Irssi::signal_add('setup reread', 'sig_setup_reread');

Irssi::command_bind("keepnick", "cmd_keepnick");
Irssi::command_bind("unkeepnick", "cmd_unkeepnick");
Irssi::command_bind("listnick", "cmd_listnick");
Irssi::command_bind("nick", "cmd_nick");

Irssi::timeout_add(12000, 'check_nick', '');

Irssi::Irc::Server::redirect_register('keepnick ison', 0, 0,
			 undef,
			 {
			  "event 303" => -1,
			 },
			 undef );

Irssi::Irc::Server::redirect_register('keepnick nick', 0, 0,
			 undef,
			 {
			  "event nick" => 0,
			  "event 432" => -1,	# ERR_ERRONEUSNICKNAME
			  "event 433" => -1,	# ERR_NICKNAMEINUSE
			  "event 437" => -1,	# ERR_UNAVAILRESOURCE
			  "event 484" => -1,	# ERR_RESTRICTED
			 },
			 undef );

load_nicks;
