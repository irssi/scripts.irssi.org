#!/usr/bin/perl -w

## Bugreports and Licence disclaimer.
#
# For bugreports and other improvements contact Geert Hauwaerts <geert@irssi.org>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this script; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
##

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = '0.02';

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'invitejoin.pl',
    description => 'This script will join a channel if somebody invites you to it.',
    license     => 'Public Domain',
    url         => 'https://github.com/irssi/scripts.irssi.org/blob/master/scripts/invitejoin.pl',
    changed     => 'Di 17. Jan 19:32:45 CET 2017',
);

my $help = <<EOF;

/SET    invitejoin 0|1
/TOGGLE invitejoin
          Description: If this setting is turned on, you will join the channel
          when invited to.

Default is to follow every invite, you can specify a list of allowed nicks.

/INVITEJOIN [addnick <ircnet> <nick>]
            [delnick <ircnet> <nick>]
            [listnick]
            [help]

addnick:     Add a new nickname on the given net as allowed autoinvite source.
delnick:     Delete a nickname from the allowed list.
listnick:    Display the contents of the allowed nickname list.
help:        Display this useful little helptext.

Examples: (all on one line)
/INVITEJOIN addnick Freenode ChanServ

Note: This script doesn't allow wildcards
EOF

my @allowed_nicks = ();
my $allowed_nicks_file = "invitejoin.nicks";

my $irssidir = Irssi::get_irssi_dir();

Irssi::theme_register([
    'invitejoin_usage', '%R>>%n %_Invitejoin:%_ Insufficient parameters: Use "%_/INVITEJOIN help%_" for further instructions.',
    'invitejoin_help', '$0',
    'invitejoin_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.',
    'invitejoin_invited', '%R>>%n %_Invitejoin:%_ Joined $1 (Invited by $0).',
    'invitejoin_usage_add_nick', '%R>>%n %_Invitejoin:%_ Insufficient parameters: Usage "%_/INVITEJOIN addnick ircnet ChanServ%_".',
    'invitejoin_no_net', '%R>>%n %_Invitejoin:%_ Unknown Irssi ircnet %_$0%_.',
    'saved_nick', '%R>>%n %_Invitejoin:%_ Added allowed nick "%_$1%_" on %_$0%_.',
    'nick_already_present', '%R>>%n %_Invitejoin:%_ Nick already present.',
    'invitejoin_delusage', '%R>>%n %_Invitejoin:%_ Insufficient parameters: Usage "%_/INVITEJOIN delnick ircnet nick%_".',
    'invitejoin_delled', '%R>>%n %_Invitejoin:%_ Deleted %_$1%_ on %_$0%_ from allowed list.',
    'invitejoin_nfound', '%R>>%n %_Invitejoin:%_ The nick %_$1%_ on %_$0%_ could not be found.',
    'allowed_nicks_info', '%_Ircnet             Nick%_',
    'allowed_nicks_empty', '%R>>%n %_Invitejoin:%_ Your allowed nick list is empty. All invites will be followed.',
    'allowed_nicks_print', '$[18]0 $1',
    'invite_denied', '%R>>%n %_Invitejoin:%_ Invite from nick %_$1%_ on %_$0%_ to %_$2%_ not followed because it is not in the allowed list.',
]);

sub load_allowed_nicks {
    my ($file) = @_;

    @allowed_nicks = load_file($file, sub {
        my $new_allowed = new_allowed_nick(@_);

        return undef if ($new_allowed->{net} eq '' || $new_allowed->{nick} eq '');
        return $new_allowed;
    });
}

sub save_allowed_nicks {
    my ($file) = @_;
    save_file($file, \@allowed_nicks, \&allowed_nick_to_list);
}

sub allowed_nick_to_list {
    my $allowed_nick = shift;

    return (
        $allowed_nick->{net},
        $allowed_nick->{nick}
    );
}

sub new_allowed_nick {
    return {
        net   => shift,
        nick  => shift
    };
}

# file: filename to be read
# parse_line_fn: receives array of entries of a single line as input, should
#     return parsed data object or undef in the data is incomplete
# returns: parsed data array
sub load_file {
    my ($file, $parse_line_fn) = @_;
    my @parsed_data = ();

    if (-e $file) {
        open(my $fh, "<", $file);
        local $/ = "\n";

        while (<$fh>) {
            chomp;
            my $data = $parse_line_fn->(split("\t"));
            push(@parsed_data, $data) if $data;
        }

        close($fh);
    }

    return @parsed_data;
}

# file: filename to be written, is created accessable only by the user
# data_ref: array ref of data entries
# serialize_fn: receives a data reference and should return an array or tuples
#     for that data that will be serialized into one line
sub save_file {
    my ($file, $data_ref, $serialize_fn) = @_;

    create_private_file($file) unless -e $file;

    open(my $fh, ">", $file) or die "Can't create $file. Reason: $!";

    for my $data (@$data_ref) {
        print($fh join("\t", $serialize_fn->($data)), "\n");
    }

    close($fh);
}

sub create_private_file {
    my ($file) = @_;
    my $umask = umask 0077; # save old umask
    open(my $fh, ">", $file) or die "Can't create $file. Reason: $!";
    close($fh);
    umask $umask;
}

sub add_allowed_nick {
    my ($network, $nick) = split(" ", $_[0], 2);
    my ($correct_net);

    if ($network eq '' || $nick eq '') {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invitejoin_usage_add_nick');
        return;
    }

    if ($network) {
        my ($ircnet) = Irssi::chatnet_find($network);
        if (!$ircnet) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invitejoin_no_net', $network);
            return;
        } else {
            $correct_net = 1;
        }
    }

    if ($correct_net && $nick) {
        if (is_nick_in_list($network, $nick)) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nick_already_present');
            return;
        }

        push(@allowed_nicks, new_allowed_nick($network, $nick));
        save_allowed_nicks("$irssidir/$allowed_nicks_file");

        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'saved_nick', $network, $nick);
    }
}

sub del_allowed_nick {
    my ($ircnet, $nick) = split(" ", $_[0], 2);

    if ($ircnet eq '' || $nick eq '') {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invitejoin_delusage');
        return;
    }

    my $size_before = scalar(@allowed_nicks);
    @allowed_nicks = grep { ! ($_->{net} eq $ircnet && $_->{nick} eq $nick) } @allowed_nicks;
    my $size_after = scalar(@allowed_nicks);

    if ($size_after != $size_before) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invitejoin_delled', $ircnet, $nick);
        save_allowed_nicks("$irssidir/$allowed_nicks_file");
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invitejoin_nfound', $ircnet, $nick);
    }

    if ($size_after == 0) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'allowed_nicks_empty');
    }
}

sub list_allowed_nicks {
    if (@allowed_nicks == 0) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'allowed_nicks_empty');
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'allowed_nicks_info');

        for my $allowed (@allowed_nicks) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'allowed_nicks_print', $allowed->{net}, $allowed->{nick});
        }
    }
}

sub invitejoin_runsub {
    my ($data, $server, $item) = @_;
    $data =~ s/\s+$//g;

    if ($data) {
        Irssi::command_runsub('invitejoin', $data, $server, $item);
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invitejoin_usage');
    }
}

sub is_nick_in_list {
    my ($net, $nick) = @_;

    return (grep {
        $_->{net}  eq $net &&
        $_->{nick} eq $nick
    } @allowed_nicks) > 0;
}

sub is_allowed_nick {
    my ($net, $nick) = @_;

    # If no allowed nicks are specified (initial configuration) accept
    # all invite requests.
    # # (This mimics previous behavior of this script
    # before there was an allowed list)
    return 1 if @allowed_nicks == 0;

    return is_nick_in_list($net, $nick);
}

sub invitejoin {
    my ($server, $channel, $nick, $address) = @_;
    my $invitejoin = Irssi::settings_get_bool('invitejoin');

    if ($invitejoin) {
        if (is_allowed_nick($server->{tag}, $nick)) {
            $server->command("join $channel");

            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invitejoin_invited', $nick, $channel);
            Irssi::signal_stop();
        }
        else {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invite_denied', $server->{tag}, $nick, $channel);
        }
    }
}

Irssi::signal_add('message invite', 'invitejoin');

Irssi::settings_add_bool('invitejoin', 'invitejoin' => 1);

load_allowed_nicks("$irssidir/$allowed_nicks_file");

Irssi::command_bind('invitejoin',           'invitejoin_runsub');
Irssi::command_bind('invitejoin addnick',   'add_allowed_nick');
Irssi::command_bind('invitejoin delnick',   'del_allowed_nick');
Irssi::command_bind('invitejoin listnick',  'list_allowed_nicks');
Irssi::command_bind('invitejoin help' => sub { Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invitejoin_help', $help) });

Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invitejoin_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
