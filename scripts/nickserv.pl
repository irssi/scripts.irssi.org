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

$VERSION = "1.8";

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'nickserv.pl',
    description => 'This script will authorize you into NickServ.',
    license     => 'GNU General Public License',
    url         => 'http://irssi.hauwaerts.be/nickserv.pl',
    changed     => 'Fri Jun  6 12:03:04 CEST 2008',
);

my @nickservnet = ();
my $nickservnet_file = "nickserv.networks";

my @nickservauth = ();
my $nickservauth_file = "nickserv.auth";

my $irssidir = Irssi::get_irssi_dir();

my $help = <<EOF;

Usage: (all on one line)
/NICKSERV [addnet <ircnet> <services\@host>]
          [addnick <ircnet> <nickname> <password>]
          [delnet <ircnet>]
          [delnick <ircnet> <nick>]
          [help listnet listnick]

addnet:     Add a new network into the NickServ list.
addnick:    Add a new nickname into the NickServ list.
delnet:     Delete a network from the NickServ list.
delnick:    Delete a nickname from the NickServ list.
listnet:    Display the contents of the NickServ network list.
listnick:   Display the contents of the NickServ nickname list.
help:       Display this useful little helptext.

Examples: (all on one line)
/NICKSERV addnet Freenode NickServ\@services.
/NICKSERV addnick Freenode Geert mypass

/NICKSERV delnet Freenode
/NICKSERV delnick Freenode Geert

Note: This script doesn't allow wildcards into the NickServ hostname. You must use the full services\@host.
      Both /NICKSERV and /NS are valid commands.
EOF

Irssi::theme_register([
    'nickserv_usage_network', '%R>>%n %_NickServ:%_ Insufficient parameters: Usage "%_/NICKSERV addnet ircnet services@host%_".',
    'nickserv_usage_nickname', '%R>>%n %_NickServ:%_ Insufficient parameters: Usage "%_/NICKSERV addnick ircnet nickname password%_".',
    'nickserv_delusage', '%R>>%n %_NickServ:%_ Insufficient parameters: Usage "%_/NICKSERV delnet ircnet%_".',
    'nickserv_delnickusage', '%R>>%n %_NickServ:%_ Insufficient parameters: Usage "%_/NICKSERV delnick ircnet nickname%_".',
    'nickserv_delled', '%R>>%n %_NickServ:%_ Deleted %_$0%_ and his nicknames from the NickServ ircnet list.',
    'nickserv_delled_nick', '%R>>%n %_NickServ:%_ Deleted %_$1%_ from the NickServ list on $0.',
    'nickserv_nfound', '%R>>%n %_NickServ:%_ The NickServ ircnet %_$0%_ could not be found.',
    'nickserv_nfound_nick', '%R>>%n %_NickServ:%_ The NickServ nickname %_$0%_ could not be found on $1.',
    'nickserv_usage', '%R>>%n %_NickServ:%_ Insufficient parameters: Use "%_/NICKSERV help%_" for further instructions.',
    'nickserv_no_net', '%R>>%n %_NickServ:%_ Unknown Irssi ircnet %_$0%_.',
    'nickserv_wrong_host', '%R>>%n %_NickServ:%_ Malformed services hostname %_$0%_.',
    'already_loaded_network', '%R>>%n %_NickServ:%_ The ircnet %_$0%_ already exists in the NickServ ircnet list, please remove it first.',
    'nickserv_loaded_nick', '%R>>%n %_NickServ:%_ The nickname %_$0%_ already exists in the NickServ authlist on %_$1%_, please remove it first.',
    'nickserv_not_loaded_net', '%R>>%n %_NickServ:%_ The ircnet %_$0%_ doesn\'t exists in the NickServ ircnet list, please add it first.',
    'saved_nickname', '%R>>%n %_NickServ:%_ Added nickname %_$1%_ on %_$0%_.',
    'network_print', '$[!-2]0 $[20]1 $2',
    'password_request', '%R>>%n %_NickServ:%_ Auth Request from NickServ on %_$0%_.',
    'password_accepted', '%R>>%n %_NickServ:%_ Password accepted on %_$0%_.',
    'password_wrong', '%R>>%n %_NickServ:%_ Password denied on %_$0%_. Please change the password.',
    'network_info', '%_ # Ircnet               Services hostname%_',
    'network_empty', '%R>>%n %_NickServ:%_ Your NickServ ircnet list is empty.',
    'nickname_print', '$[!-2]0 $[20]1 $[18]2 $3',
    'nickname_info', '%_ # Ircnet               Nickname           Password%_',
    'nickname_empty', '%R>>%n %_NickServ:%_ Your NickServ authlist is empty.',
    'nickserv_help', '$0',
    'saved_network', '%R>>%n %_NickServ:%_ Added services mask "%_$1%_" on %_$0%_.',
    'nickserv_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.'
]);

sub load_nickservnet {

    my ($file) = @_;

    @nickservnet = ();

    if (-e $file) {
        local *F;
        open(F, "<$file");
        local $/ = "\n";

        while (<F>) {
            chop;
            my $new_nsnet = new_nickserv_network(split("\t"));
  
            if (($new_nsnet->{name} ne "") && ($new_nsnet->{host} ne "")) {
                push(@nickservnet, $new_nsnet);
            }
        }
        
        close(F);
    }
}

sub save_nickservnet {

    my ($file) = @_;

    return unless scalar @nickservnet; # there's nothing to save

    if (-e $file) {
        local *F;
        open(F, ">$file");

        for (my $n = 0; $n < @nickservnet; ++$n) {
            print(F join("\t", $nickservnet[$n]->{name}, $nickservnet[$n]->{host}) . "\n");
        }
    
        close(F);
    } else {
        create_network_file($file);
        save_nickservnet($file);
    }
}

sub create_network_file {
    
    my ($file) = @_;
    
    open(F, ">$file") or die "Can't create $file. Reason: $!";
}

sub new_nickserv_network {

    my $nsnet = {};

    $nsnet->{name} = shift;
    $nsnet->{host} = shift;

    return $nsnet;
}

sub load_nickservnick {

    my ($file) = @_;

    @nickservauth = ();

    if (-e $file) {
        local *F;
        open(F, "<$file");
        local $/ = "\n";

        while (<F>) {
            chop;
            my $new_nsnick = new_nickserv_nick(split("\t"));
  
            if (($new_nsnick->{ircnet} ne "") && ($new_nsnick->{nick} ne "") && ($new_nsnick->{pass} ne "")) {
                push(@nickservauth, $new_nsnick);
            }
        }
        
        close(F);
    }
}

sub save_nickservnick {

    my ($file) = @_;

    return unless scalar @nickservauth; # there's nothing to save

    if (-e $file) {
        local *F;
        open(F, ">$file");

        for (my $n = 0; $n < @nickservauth; ++$n) {
            print(F join("\t", $nickservauth[$n]->{ircnet}, $nickservauth[$n]->{nick}, $nickservauth[$n]->{pass}) . "\n");
        }
    
        close(F);
    } else {
        create_nick_file($file);
        save_nickservnick($file);
    }
}

sub create_nick_file {
    
    my ($file) = @_;
    
    my $umask = umask 0077; # save old umask
    open(F, ">$file") or die "Can't create $file. Reason: $!";
    umask $umask;
}

sub new_nickserv_nick {

    my $nsnick = {};

    $nsnick->{ircnet} = shift;
    $nsnick->{nick} = shift;
    $nsnick->{pass} = shift;

    return $nsnick;
}

sub add_nickname {
    
    my ($network, $nickname, $password) = split(" ", @_[0], 3);
    my ($correct_network, $correct_nickname, $correct_password);

    if ($network eq "" || $nickname eq "" || $password eq "") {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_usage_nickname');
        return;
    }
    
    if ($network) {
        if (!already_loaded_net($network)) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_not_loaded_net', $network);
            return;
        } else {
            $correct_network = 1;
        }
    }
    
    if ($nickname) {
        if (already_loaded_nick($nickname, $network)) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_loaded_nick', $nickname, $network);
            return;
        } else {
            $correct_nickname = 1;
        }
    }
    
    if ($correct_network && $correct_nickname) {
        push(@nickservauth, new_nickserv_nick($network, $nickname, $password));
        save_nickservnick("$irssidir/$nickservauth_file");
            
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'saved_nickname', $network, $nickname);
    }
}

sub add_network {
    
    my ($network, $hostname) = split(" ", @_[0], 2);
    my ($correct_net, $correct_host);
    
    if ($network eq "" || $hostname eq "") {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_usage_network');
        return;
    }
    
    if ($network) {
        my ($ircnet) = Irssi::chatnet_find($network);
        
        if (!$ircnet) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_no_net', $network);
            return;
        } elsif (already_loaded_net($network)) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'already_loaded_network', $network);
            return;
        } else {
            $correct_net = 1;
        }
    }
 
    if ($hostname) {
        if ($hostname !~ /^[.+a-zA-Z0-9_-]{1,9}@[.+a-zA-Z0-9_-]{1,}$/) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_wrong_host', $hostname);
            return;
        } else {
            $correct_host = 1;
        }
    }
    
    if ($correct_net && $correct_host) {
        push(@nickservnet, new_nickserv_network($network, $hostname));
        save_nickservnet("$irssidir/$nickservnet_file");
            
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'saved_network', $network, $hostname);
    }
}

sub already_loaded_net {

    my ($ircnet) = @_;
    my $loaded = check_loaded_net($ircnet);

    if ($loaded > -1) {
        return 1;
    }
    
    return 0;
}

sub check_loaded_net {

    my ($ircnet) = @_;

    $ircnet = lc($ircnet);

    for (my $loaded = 0; $loaded < @nickservnet; ++$loaded) {
        return $loaded if (lc($nickservnet[$loaded]->{name}) eq $ircnet);
    }
    
    return -1;
}

sub already_loaded_nick {
    
    my ($nickname, $network) = @_;
    my $loaded = check_loaded_nick($nickname, $network);
    
    if ($loaded > -1) {
        return 1;
    }
    
    return 0
}

sub check_loaded_nick {
    
    my ($nickname, $network) = @_;
    
    $nickname = lc($nickname);
    $network = lc($network);
    
    for (my $loaded = 0; $loaded < @nickservauth; ++$loaded) {
        return $loaded if (lc($nickservauth[$loaded]->{nick}) eq $nickname && lc ($nickservauth[$loaded]->{ircnet}) eq $network);
    }
    
    return -1;
}

sub list_net {
    
    if (@nickservnet == 0) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'network_empty');
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'network_info');

        for (my $n = 0; $n < @nickservnet ; ++$n) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'network_print', $n, $nickservnet[$n]->{name}, $nickservnet[$n]->{host});
        }
    }
}

sub list_nick {
    
    if (@nickservauth == 0) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickname_empty');
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickname_info');

        for (my $n = 0; $n < @nickservauth ; ++$n) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickname_print', $n, $nickservauth[$n]->{ircnet}, $nickservauth[$n]->{nick}, "*" x length($nickservauth[$n]->{pass}));
        }
    }
}

sub nickserv_notice {
    
    my ($server, $data, $nick, $address) = @_;
    my ($target, $text) = $data =~ /^(\S*)\s:(.*)/;

    if (is_nickserv($server->{tag}, $address)) {
        if ($text =~ /^If this is your nickname, type \/msg NickServ/ || $text =~ /^This nickname is registered and protected.  If it is your/ || $text =~ /This nickname is registered\. Please choose a different nickname,/ || $text =~ /^This nickname is registered. Please choose a different nickname/) {
            my $password = get_password($server->{tag}, $server->{nick});
            
            if ($password == -1) {
                Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'password_request', $server->{tag});
                Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_nfound_nick', $server->{nick}, $server->{tag});
                Irssi::signal_stop();
                return;
            }
            
            Irssi::signal_stop();
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'password_request', $server->{tag});
            $server->command("^MSG NickServ IDENTIFY $password");
        } elsif ($text =~ /If this is your nickname, type \/NickServ/) {
            my $password = get_password($server->{tag}, $server->{nick});

            if ($password == -1) {
                Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'password_request', $server->{tag});
                Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_nfound_nick', $server->{nick}, $server->{tag});
                Irssi::signal_stop();
                return;
            }

            Irssi::signal_stop();
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'password_request', $server->{tag});
            $server->command("^QUOTE NickServ :IDENTIFY $password");
        } elsif ($text =~ /If this is your nickname, type \/msg NS/) {
            my $password = get_password($server->{tag}, $server->{nick});

            if ($password == -1) {
                Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'password_request', $server->{tag});
                Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_nfound_nick', $server->{nick}, $server->{tag});
                Irssi::signal_stop();
                return;
            }

            Irssi::signal_stop();
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'password_request', $server->{tag});
            $server->command("^MSG NS IDENTIFY $password");
        } elsif ($text =~ /If you do not (.*) within one minute, you will be disconnected/) {
            Irssi::signal_stop();
        } elsif ($text =~ /^This nickname is owned by someone else/) {
            Irssi::signal_stop();
        } elsif ($text =~ /^nick, type (.*)  Otherwise,/) {
            Irssi::signal_stop();
        } elsif ($text =~ /^please choose a different nick./) {
            Irssi::signal_stop();
        } elsif ($text =~ /^You have already identified/ || $text =~ /^This nick is already identified./) {
            Irssi::signal_stop();
        } elsif ($text =~ /^Password accepted - you are now recognized/) {
            Irssi::signal_stop();
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'password_accepted', $server->{tag});
        } elsif ($text =~ /^Password Incorrect/ || $text =~ /^Password incorrect./) {
            Irssi::signal_stop();
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'password_wrong', $server->{tag});
        }
    }
}

sub is_nickserv {
    
    my ($net, $host) = @_;

    for (my $loaded = 0; $loaded < @nickservnet; ++$loaded) {
        return 1 if (lc($nickservnet[$loaded]->{name}) eq lc($net) && lc($nickservnet[$loaded]->{host}) eq lc($host));
    }
    return 0;
}

sub get_password {
    
    my ($ircnet, $nick) = @_;
    
    for (my $loaded = 0; $loaded < @nickservauth; ++$loaded) {
        return $nickservauth[$loaded]->{pass} if (lc($nickservauth[$loaded]->{ircnet}) eq lc($ircnet) && lc($nickservauth[$loaded]->{nick}) eq lc($nick));
    }
    
    return -1;
}

sub del_network {

    my ($ircnet) = split(" ", @_[0], 1);
    my ($ircnetindex);

    if ($ircnet eq "") {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_delusage');
        return;
    }

    for (my $index = 0; $index < @nickservnet; ++$index) {
        if (lc($nickservnet[$index]->{name}) eq lc($ircnet)) {
            $ircnetindex = 1;
        }
    }
    
    if ($ircnetindex) {
        @nickservnet = grep {lc($_->{name}) ne lc($ircnet)} @nickservnet;
        @nickservauth = grep {lc($_->{ircnet}) ne lc($ircnet)} @nickservauth;
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_delled', $ircnet);
        save_nickservnet("$irssidir/$nickservnet_file");
        save_nickservnick("$irssidir/$nickservauth_file");
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_nfound', $ircnet);
    }
}

sub del_nickname {
    
    my ($ircnet, $nickname) = split(" ", @_[0], 2);
    my ($nickindex);
    
    if ($ircnet eq "" || $nickname eq "") {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_delnickusage');
        return;
    }

    for (my $index = 0; $index < @nickservauth; ++$index) {
        if (lc($nickservauth[$index]->{ircnet}) eq lc($ircnet) && lc($nickservauth[$index]->{nick}) eq lc($nickname)) {
            $nickindex = splice(@nickservauth, $index, 1);
        }   
    }

    if ($nickindex) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_delled_nick', $ircnet, $nickname);
        save_nickservnick("$irssidir/$nickservauth_file");
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_nfound_nick', $ircnet, $nickname);
    }
}

sub nickserv_runsub {
    
    my ($data, $server, $item) = @_;
    $data =~ s/\s+$//g;
    
    if ($data) {
        Irssi::command_runsub('nickserv', $data, $server, $item);
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_usage');
    }
}

load_nickservnet("$irssidir/$nickservnet_file");
load_nickservnick("$irssidir/$nickservauth_file");

Irssi::command_bind('nickserv', 'nickserv_runsub');
Irssi::command_bind('ns', 'nickserv_runsub');

Irssi::command_bind('nickserv addnet', 'add_network');
Irssi::command_bind('ns addnet', 'add_network');

Irssi::command_bind('nickserv addnick', 'add_nickname');
Irssi::command_bind('ns addnick', 'add_nickname');

Irssi::command_bind('nickserv listnet', 'list_net');
Irssi::command_bind('ns listnet', 'list_net');

Irssi::command_bind('nickserv listnick', 'list_nick');
Irssi::command_bind('ns listnick', 'list_nick');

Irssi::command_bind('nickserv delnet', 'del_network');
Irssi::command_bind('ns delnet', 'del_network');

Irssi::command_bind('nickserv delnick', 'del_nickname');
Irssi::command_bind('ns delnick', 'del_nickname');

Irssi::command_bind('nickserv help' => sub { Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_help', $help) });
Irssi::command_bind('ns help' => sub { Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_help', $help) });

Irssi::signal_add('event notice', 'nickserv_notice');
Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
