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

$VERSION = "1.12";

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'nickserv.pl',
    description => 'This script will authorize you into NickServ.',
    license     => 'GNU General Public License',
    url         => 'https://github.com/irssi/scripts.irssi.org/blob/master/scripts/nickserv.pl',
    changed     => 'Wed Jun 27 19:23 CEST 2018',
);

my $irssidir = Irssi::get_irssi_dir();

my @nickservnet = ();
my $nickservnet_file = "$irssidir/nickserv.networks";

my @nickservauth = ();
my $nickservauth_file = "$irssidir/nickserv.auth";

my @nickservpostcmd = ();
my $nickservpostcmd_file = "$irssidir/nickserv.postcmd";

my $help = <<EOF;

Usage: (all on one line)
/NICKSERV [addnet <ircnet> <services\@host>]
          [addnick <ircnet> <nickname> <password>]
          [addpostcmd <ircnet> <nickname> <command>]
          [delnet <ircnet>]
          [delnick <ircnet> <nick>]
          [delpostcmd <ircnet> <nick>]
          [help listnet listnick listpostcmd]

addnet:      Add a new network into the NickServ list.
addnick:     Add a new nickname into the NickServ list.
addpostcmd:  Add a new post auth command for nickname into the NickServ list.
delnet:      Delete a network from the NickServ list.
delnick:     Delete a nickname from the NickServ list.
delpostcmd:  Deletes all post auth commands for the given nickame.
listnet:     Display the contents of the NickServ network list.
listnick:    Display the contents of the NickServ nickname list.
listpostcmd: Display the contents of the NickServ postcmd list.
help:        Display this useful little helptext.

Examples: (all on one line)
/NICKSERV addnet Freenode NickServ\@services.
/NICKSERV addnick Freenode Geert mypass
/NICKSERV addpostcmd Freenode Geert ^MSG ChanServ invite #heaven

/NICKSERV delnet Freenode
/NICKSERV delnick Freenode Geert

Note: This script doesn't allow wildcards into the NickServ hostname. You must use the full services\@host.
      Both /NICKSERV and /NS are valid commands.
EOF

Irssi::theme_register([
    'nickserv_usage_network', '%R>>%n %_NickServ:%_ Insufficient parameters: Usage "%_/NICKSERV addnet ircnet services@host%_".',
    'nickserv_usage_nickname', '%R>>%n %_NickServ:%_ Insufficient parameters: Usage "%_/NICKSERV addnick ircnet nickname password%_".',
    'nickserv_usage_postcmd', '%R>>%n %_NickServ:%_ Insufficient parameters: Usage "%_/NICKSERV addpostcmd ircnet nickname command%_".',
    'nickserv_delusage', '%R>>%n %_NickServ:%_ Insufficient parameters: Usage "%_/NICKSERV delnet ircnet%_".',
    'nickserv_delnickusage', '%R>>%n %_NickServ:%_ Insufficient parameters: Usage "%_/NICKSERV delnick ircnet nickname%_".',
    'nickserv_delpostcmdusage', '%R>>%n %_NickServ:%_ Insufficient parameters: Usage "%_/NICKSERV delpostcmd ircnet nickname%_".',
    'nickserv_delled', '%R>>%n %_NickServ:%_ Deleted %_$0%_ and it\'s nicknames and post commands from the NickServ ircnet list.',
    'nickserv_delled_nick', '%R>>%n %_NickServ:%_ Deleted %_$1%_ and it\'s post commands from the NickServ list on $0.',
    'nickserv_delled_postcmd', '%R>>%n %_NickServ:%_ Deleted all entries for %_$1%_ from the NickServ postcmd list on $0.',
    'nickserv_nfound', '%R>>%n %_NickServ:%_ The NickServ ircnet %_$0%_ could not be found.',
    'nickserv_nfound_nick', '%R>>%n %_NickServ:%_ The NickServ nickname %_$0%_ could not be found on $1.',
    'nickserv_nfound_postcmd', '%R>>%n %_NickServ:%_ The NickServ post commands for nickname %_$1%_ could not be found on $0.',
    'nickserv_usage', '%R>>%n %_NickServ:%_ Insufficient parameters: Use "%_/NICKSERV help%_" for further instructions.',
    'nickserv_no_net', '%R>>%n %_NickServ:%_ Unknown Irssi ircnet %_$0%_.',
    'nickserv_wrong_host', '%R>>%n %_NickServ:%_ Malformed services hostname %_$0%_.',
    'already_loaded_network', '%R>>%n %_NickServ:%_ The ircnet %_$0%_ already exists in the NickServ ircnet list, please remove it first.',
    'nickserv_loaded_nick', '%R>>%n %_NickServ:%_ The nickname %_$0%_ already exists in the NickServ authlist on %_$1%_, please remove it first.',
    'nickserv_not_loaded_net', '%R>>%n %_NickServ:%_ The ircnet %_$0%_ doesn\'t exists in the NickServ ircnet list, please add it first.',
    'nickserv_not_loaded_nick', '%R>>%n %_NickServ:%_ The nickname %_$0%_ doesn\'t exists in the NickServ authlist on %_$1%_, please add it first.',
    'saved_nickname', '%R>>%n %_NickServ:%_ Added nickname %_$1%_ on %_$0%_.',
    'saved_postcmd', '%R>>%n %_NickServ:%_ Added postcmd %_$1%_ on %_$0%_: %_%2%_.',
    'network_print', '$[!-2]0 $[20]1 $2',
    'password_request', '%R>>%n %_NickServ:%_ Auth Request from NickServ on %_$0%_.',
    'password_accepted', '%R>>%n %_NickServ:%_ Password accepted on %_$0%_.',
    'password_wrong', '%R>>%n %_NickServ:%_ Password denied on %_$0%_. Please change the password.',
    'network_info', '%_ # Ircnet               Services hostname%_',
    'network_empty', '%R>>%n %_NickServ:%_ Your NickServ ircnet list is empty.',
    'nickname_print', '$[!-2]0 $[20]1 $[18]2 $3',
    'nickname_info', '%_ # Ircnet               Nickname           Password%_',
    'nickname_empty', '%R>>%n %_NickServ:%_ Your NickServ authlist is empty.',
    'postcmd_print', '$[!-2]0 $[20]1 $[18]2 $3',
    'postcmd_info', '%_ # Ircnet               Nickname           Postcmd%_',
    'postcmd_empty', '%R>>%n %_NickServ:%_ Your NickServ postcmd list is empty.',
    'nickserv_help', '$0',
    'saved_network', '%R>>%n %_NickServ:%_ Added services mask "%_$1%_" on %_$0%_.',
    'nickserv_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.'
]);

sub load_nickservnet {

    my ($file) = @_;

    @nickservnet = load_file($file, sub {
        my $new_nsnet = new_nickserv_network(@_);
        return undef if ($new_nsnet->{name} eq "" || $new_nsnet->{host} eq "");
        return $new_nsnet;
    });
}

sub save_nickservnet {

    save_file($nickservnet_file, \@nickservnet, \&nickservnet_as_list);
}

sub new_nickserv_network {

    return {
        name => shift,
        host => shift
    };
}

sub nickservnet_as_list {

    my $nickserv_net = shift;

    return (
      $nickserv_net->{name},
      $nickserv_net->{host}
    );
}

sub load_nickservnick {

    my ($file) = @_;

    @nickservauth = load_file($file, sub {
        my $new_nsnick = new_nickserv_nick(@_);

        return undef if ($new_nsnick->{ircnet} eq "" || $new_nsnick->{nick} eq "" || $new_nsnick->{pass} eq "");
        return $new_nsnick;
    });
}

sub save_nickservnick {

    save_file($nickservauth_file, \@nickservauth, \&nickserv_nick_as_list);
}

sub new_nickserv_nick {

    return {
        ircnet    => shift,
        nick      => shift,
        pass      => shift
    };
}

sub nickserv_nick_as_list {

    my $nickserv_nick = shift;
    return (
        $nickserv_nick->{ircnet},
        $nickserv_nick->{nick},
        $nickserv_nick->{pass}
    );
}

sub load_nickservpostcmd {

    my ($file) = @_;

    @nickservpostcmd = load_file($file, sub {
        my $new_postcmd = new_postcmd(@_);

        return undef if ($new_postcmd->{ircnet} eq "" || $new_postcmd->{nick} eq "" || $new_postcmd->{postcmd} eq "");
        return $new_postcmd;
    });
}

sub save_nickservpostcmd {

    save_file($nickservpostcmd_file, \@nickservpostcmd, \&postcmd_as_list);
}

sub new_postcmd {

    return {
        ircnet    => shift,
        nick      => shift,
        postcmd   => shift
    };
}

sub postcmd_as_list {
    my $postcmd = shift;

    return (
        $postcmd->{ircnet},
        $postcmd->{nick},
        $postcmd->{postcmd}
    );
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

sub add_nickname {

    my ($network, $nickname, $password) = split(" ", $_[0], 3);
    my ($correct_network, $correct_nickname);

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
        save_nickservnick();

        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'saved_nickname', $network, $nickname);
    }
}

sub add_postcmd {

    my ($network, $nickname, $postcmd) = split(" ", $_[0], 3);
    my ($correct_network, $correct_nickname);

    if ($network eq "" || $nickname eq "" || $postcmd eq "") {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_usage_postcmd');
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
        if (!already_loaded_nick($nickname, $network)) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_not_loaded_nick', $nickname, $network);
            return;
        } else {
            $correct_nickname = 1;
        }
    }

    if ($correct_network && $correct_nickname) {
        push(@nickservpostcmd, new_postcmd($network, $nickname, $postcmd));
        save_nickservpostcmd();

        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'saved_postcmd', $network, $nickname, $postcmd);
    }
}

sub add_network {

    my ($network, $hostname) = split(" ", $_[0], 2);
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
        if ($hostname !~ /^[.+a-zA-Z0-9_-]{1,}@[.+a-zA-Z0-9_-]{1,}$/) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_wrong_host', $hostname);
            return;
        } else {
            $correct_host = 1;
        }
    }

    if ($correct_net && $correct_host) {
        push(@nickservnet, new_nickserv_network($network, $hostname));
        save_nickservnet();

        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'saved_network', $network, $hostname);
    }
}

sub already_loaded_net {

    my ($ircnet) = @_;

    $ircnet = lc($ircnet);

    for my $loaded (@nickservnet) {
        return 1 if (lc($loaded->{name}) eq $ircnet);
    }

    return 0;
}

sub already_loaded_nick {
    my ($nickname, $network) = @_;

    $nickname = lc($nickname);
    $network = lc($network);

    for my $loaded (@nickservauth) {
        return 1 if (lc($loaded->{nick}) eq $nickname &&
                     lc($loaded->{ircnet}) eq $network);
    }

    return 0;
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

sub list_postcmd {

    if (@nickservpostcmd == 0) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'postcmd_empty');
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'postcmd_info');

        for (my $n = 0; $n < @nickservpostcmd ; ++$n) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'postcmd_print', $n, $nickservpostcmd[$n]->{ircnet}, $nickservpostcmd[$n]->{nick}, $nickservpostcmd[$n]->{postcmd});
        }
    }
}

sub nickserv_notice {

    my ($server, $data, $nick, $address) = @_;
    my ($target, $text) = $data =~ /^(\S*)\s:(.*)/;

    if (is_nickserv($server->{tag}, $address)) {
        $text =~ s/[[:cntrl:]]+//g; # remove control crap

        if ($text =~ /^(?:\(?If this is your nick(?:name)?, type|Please identify via|Type) \/msg NickServ (?i:identify)/ || $text =~ /^This nickname is registered and protected.  If it is your/ || $text =~ /This nickname is registered\. Please choose a different nickname/) {
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
        } elsif ($text =~ /^You have already identified/ || $text =~ /^This nick is already identified./ || $text =~ /^You are already logged in as/) {
            Irssi::signal_stop();
        } elsif ($text =~ /^Password accepted - you are now recognized/ || $text =~ /^You are now identified for/) {
            Irssi::signal_stop();
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'password_accepted', $server->{tag});
            run_postcmds($server, $server->{tag}, $server->{nick})
        } elsif ($text =~ /^Password Incorrect/ || $text =~ /^Password incorrect./) {
            Irssi::signal_stop();
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'password_wrong', $server->{tag});
        }
    }
}

sub run_postcmds {
	my ($server, $ircnet, $nick) = @_;
	return if @nickservpostcmd == 0;

	for my $cmd (@nickservpostcmd) {
		if ($ircnet eq $cmd->{ircnet} &&
        $nick   eq $cmd->{nick} &&
        $cmd->{postcmd}) {
			$server->command($cmd->{postcmd});
		}
	}
}

sub is_nickserv {

    my ($net, $host) = @_;

    for (my $loaded = 0; $loaded < @nickservnet; ++$loaded) {
        return 1 if (lc($nickservnet[$loaded]->{name}) eq lc($net) &&
                     lc($nickservnet[$loaded]->{host}) eq lc($host));
    }
    return 0;
}

sub get_password {

    my ($ircnet, $nick) = @_;

    for (my $loaded = 0; $loaded < @nickservauth; ++$loaded) {
        return $nickservauth[$loaded]->{pass} if (lc($nickservauth[$loaded]->{ircnet}) eq lc($ircnet) &&
                                                  lc($nickservauth[$loaded]->{nick}) eq lc($nick));
    }

    return -1;
}

sub del_network {

    my ($ircnet) = split(" ", $_[0], 1);
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
        @nickservpostcmd = grep {lc($_->{ircnet}) ne lc($ircnet)} @nickservpostcmd;
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_delled', $ircnet);
        save_nickservnet();
        save_nickservnick();
        save_nickservpostcmd();
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_nfound', $ircnet);
    }
}

sub del_nickname {

    my ($ircnet, $nickname) = split(" ", $_[0], 2);
    my ($nickindex);

    if ($ircnet eq "" || $nickname eq "") {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_delnickusage');
        return;
    }

    for (my $index = 0; $index < @nickservauth; ++$index) {
        if (lc($nickservauth[$index]->{ircnet}) eq lc($ircnet) &&
            lc($nickservauth[$index]->{nick}) eq lc($nickname)) {
            $nickindex = splice(@nickservauth, $index, 1);
        }
    }

    if ($nickindex) {
        @nickservpostcmd = grep {lc($_->{ircnet}) ne lc($ircnet) ||
                                 lc($_->{nick}) ne lc($nickname)}
                           @nickservpostcmd;

        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_delled_nick', $ircnet, $nickname);
        save_nickservnick();
        save_nickservpostcmd();
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_nfound_nick', $ircnet, $nickname);
    }
}

sub del_postcmd {

    my ($ircnet, $nickname) = split(" ", $_[0], 2);

    if ($ircnet eq "" || $nickname eq "") {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_delpostcmdusage');
        return;
    }

    my $size_before = scalar(@nickservpostcmd);
    @nickservpostcmd = grep { !( lc($_->{ircnet}) eq lc($ircnet) && lc($_->{nick}) eq lc($nickname) )} @nickservpostcmd;
    my $size_after = scalar(@nickservpostcmd);

    if ($size_before != $size_after) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_delled_postcmd', $ircnet, $nickname);
        save_nickservpostcmd();
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_nfound_postcmd', $ircnet, $nickname);
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

load_nickservnet($nickservnet_file);
load_nickservnick($nickservauth_file);
load_nickservpostcmd($nickservpostcmd_file);

Irssi::command_bind('nickserv', 'nickserv_runsub');
Irssi::command_bind('ns', 'nickserv_runsub');

Irssi::command_bind('nickserv help' => sub { Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_help', $help) });
Irssi::command_bind('ns help' => sub { Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_help', $help) });

# "command binding" -> "function name" mapping
for my $cmd ((
  ['addnet'       => 'add_network'],
  ['addnick'      => 'add_nickname'],
  ['addpostcmd'   => 'add_postcmd'],
  ['listnet'      => 'list_net'],
  ['listnick'     => 'list_nick'],
  ['listpostcmd'  => 'list_postcmd'],
  ['delnet'       => 'del_network'],
  ['delnick'      => 'del_nickname'],
  ['delpostcmd'   => 'del_postcmd'],
)) {
  Irssi::command_bind("nickserv $cmd->[0]", $cmd->[1]);
  Irssi::command_bind("ns $cmd->[0]",       $cmd->[1]);
}

Irssi::signal_add('event notice', 'nickserv_notice');
Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'nickserv_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
