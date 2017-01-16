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

$VERSION = "0.02";

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'invitejoin.pl',
    description => 'This script will join a channel if somebody invites you to it.',
    license     => 'Public Domain',
    url         => 'http://irssi.hauwaerts.be/invitejoin.pl',
    changed     => 'Di 3. Jan 19:46:51 CET 2017',
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
    'invitejoin_delusage', '%R>>%n %_Invitejoin:%_ Insufficient parameters: Usage "%_/INVITEJOIN delnick ircnet nick%_".',
    'invitejoin_delled', '%R>>%n %_Invitejoin:%_ Deleted %_$1%_ on %_$0%_ from allowed list.',
    'invitejoin_nfound', '%R>>%n %_Invitejoin:%_ The nick %_$1%_ on %_$0%_ could not be found.',
    'allowed_nicks_info', '%_Ircnet             Nick%_',
    'allowed_nicks_empty', '%R>>%n %_Invitejoin:%_ Your allowed nick list is empty.',
    'allowed_nicks_print', '$[18]0 $1',
    'invite_denied', '%R>>%n %_Invitejoin:%_ Invite from nick %_$1%_ on %_$0%_ to %_$2%_ not followed because it is not in the allowed list.',
]);

sub load_allowed_nicks {
    my ($file) = @_;
    @allowed_nicks = ();
    if (-e $file) {
        open(my $fh, "<", $file);
        local $/ = "\n";

        while (<$fh>) {
            chomp;
            my $new_allowed = new_allowed_nick(split("\t"));
            if (($new_allowed->{net} ne "") && ($new_allowed->{nick} ne "")) {
                push(@allowed_nicks, $new_allowed);
            }
        }
        close($fh);
    }
}

sub save_allowed_nicks {
    my ($file) = @_;
    open(my $fh, ">", $file) or die "Can't create $file. Reason: $!";

    for my $allowed (@allowed_nicks) {
      print($fh join("\t", $allowed->{net}, $allowed->{nick}) . "\n");
    }

    close($fh);
}

sub new_allowed_nick {
    my $anick = {};

    $anick->{net}  = shift;
    $anick->{nick} = shift;

    return $anick;
}

sub add_allowed_nick {
    my ($network, $nick) = split(" ", $_[0], 2);
    my ($correct_net);
    
    if ($network eq "" || $nick eq "") {
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
        push(@allowed_nicks, new_allowed_nick($network, $nick));
        save_allowed_nicks("$irssidir/$allowed_nicks_file");
            
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'saved_nick', $network, $nick);
    }
}

sub del_allowed_nick {
    my ($ircnet, $nick) = split(" ", $_[0], 2);

    if ($ircnet eq "") {
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

sub is_allowed_nick {
  my ($server, $nick) = @_;

  # If no allowed nicks are specified (initial configuration) accept
  # all invite requests, which mimics previous behavior of this script
  return 1 if @allowed_nicks == 0;

  return (grep {
    $_->{net}  eq $server->{tag} &&
    $_->{nick} eq $nick
  } @allowed_nicks) > 0;
}

sub invitejoin {
    my ($server, $channel, $nick, $address) = @_;
    my $invitejoin = Irssi::settings_get_bool('invitejoin');

    if ($invitejoin) {
      if (is_allowed_nick($server, $nick)) {
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

Irssi::command_bind('invitejoin', 'invitejoin_runsub');
Irssi::command_bind('invitejoin addnick',  'add_allowed_nick');
Irssi::command_bind('invitejoin delnick',  'del_allowed_nick');
Irssi::command_bind('invitejoin listnick', 'list_allowed_nicks');
Irssi::command_bind('invitejoin help' => sub { Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invitejoin_help', $help) });

Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'invitejoin_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
