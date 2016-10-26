#
# Copyright (C) 2015 by Morten Lied Johansen <mortenjo@ifi.uio.no>
#

use strict;

use Irssi;
use Irssi::Irc;

# ======[ Script Header ]===============================================

use vars qw{$VERSION %IRSSI};
($VERSION) = '$Revision: 1.0 $' =~ / (\d+\.\d+) /;
%IRSSI = (
          name        => 'msg2notice',
          authors     => 'Morten Lied Johansen',
          contact     => 'mortenjo@ifi.uio.no',
          license     => 'GPL',
          description => 'For a configured list of nicks, convert all their messages to a notice',
         );

# ======[ Variables ]===================================================

my(%nicks);

# ======[ Helpers ]=====================================================

# --------[ crap ]------------------------------------------------------

sub crap {
    my $template = shift;
    my $msg = sprintf $template, @_;
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'msg2notice_crap', $msg);
}

# --------[ list_nicks ]------------------------------------------------

sub list_nicks {
    my $count = keys %nicks;

    crap("Listing $count nicks");
    foreach my $nick (keys %nicks) {
        crap($nick);
    }
}

# --------[ add_nick ]--------------------------------------------------

sub add_nick {
    my($nick) = @_;

    $nick =~ s/^\s+|\s+$//g;
    $nicks{$nick} = 1;
    crap("Added $nick to list");
}

# --------[ del_nick ]--------------------------------------------------

sub del_nick {
    my($nick) = @_;

    $nick =~ s/^\s+|\s+$//g;
    delete $nicks{$nick};
    crap("Removed $nick from list");
}

# --------[ load_nicks ]------------------------------------------------

sub load_nicks {
    my($file) = Irssi::get_irssi_dir."/msg2notice";
    my($count) = 0;
    my($mask,$net,$channel,$flags,$flag);
    local(*FILE);

    %nicks = ();
    if (open FILE, "<", $file) {
        while (<FILE>) {
            add_nick($_);
        }
        close FILE;
        $count = keys %nicks;

        crap("Loaded $count nicks");
    } else {
        crap("Unable to open $file for loading: $!");
    }
}

# --------[ save_nicks ]------------------------------------------------

sub save_nicks {
    my($auto) = @_;
    my($file) = Irssi::get_irssi_dir."/msg2notice";
    my($count) = 0;
    local(*FILE);

    return if $auto && !Irssi::settings_get_bool('msg2notice_autosave');

    if (open FILE, ">", $file) {
        for my $nick (keys %nicks) {
            $count++;
            print FILE "$nick\n";
        }
        close FILE;

        crap("Saved $count nicks to $file")
          unless $auto;
    } else {
        crap("Unable to open $file for saving: $!");
    }
}

# ======[ Hooks ]=======================================================

# --------[ sig_event_privmsg ]-----------------------------------------

sub sig_event_privmsg {
	my ($server, $data, $sender_nick, $sender_address) = @_;

	if (exists $nicks{$sender_nick}) {
		Irssi::signal_emit('event notice', $server, $data, $sender_nick, $sender_address);
		Irssi::signal_stop();
	}
}

# --------[ sig_setup_reread ]------------------------------------------

sub sig_setup_reread {
    load_nicks;
}

# --------[ sig_setup_save ]--------------------------------------------

sub sig_setup_save {
    my($mainconf,$auto) = @_;
    save_nicks($auto);
}

# ======[ Commands ]====================================================

# --------[ MSG2NOTICE ]------------------------------------------------

# Usage: /MSG2NOTICE [list|add|del|load|save] <nick> [<nick> ...]
sub cmd_msg2notice {
    my($param,$serv,$chan) = @_;
    my(@split) = split " ", $param;
    my $cmd = shift @split;
    my $save = 0;

    if ($cmd eq "list") {
        list_nicks;
    } elsif ($cmd eq "add") {
        while (@split) {
            add_nick(shift @split);
            $save = 1;
        }
    } elsif ($cmd eq "del") {
        while (@split) {
            del_nick(shift @split);
            $save = 1;
        }
    } elsif ($cmd eq "load") {
        load_nicks;
    } elsif ($cmd eq "save") {
        save_nicks;
    } else {
        crap("Unknown command: $cmd");
    }

    if ($save) {
        save_nicks(1);
    }
}

# ======[ Setup ]=======================================================

# --------[ Register commands ]-----------------------------------------

Irssi::command_bind('msg2notice', \&cmd_msg2notice);

# --------[ Register settings ]-----------------------------------------

Irssi::settings_add_bool('msg2notice', 'msg2notice_autosave', 1);

# --------[ Register signals ]------------------------------------------

Irssi::signal_add('event privmsg', \&sig_event_privmsg);
Irssi::signal_add('setup saved', 'sig_setup_save');
Irssi::signal_add('setup reread', 'sig_setup_reread');

# --------[ Register formats ]------------------------------------------

Irssi::theme_register(
[
 'msg2notice_crap',
 '{line_start}{hilight Msg->Notice:} $0',
]);

# --------[ Load config ]-----------------------------------------------

load_nicks;

# ======[ END ]=========================================================
