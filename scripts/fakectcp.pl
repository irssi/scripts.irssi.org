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

$VERSION = "1.03";

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@irssi.org',
    name        => 'fakectcp.pl',
    description => 'This script sends fake ctcp replies to a client using a fake ctcp list.',
    license     => 'GNU General Public License',
    url         => 'http://irssi.hauwaerts.be/default.pl',
    changed     => 'Wed Sep 17 23:00:11 CEST 2003',
);

my @fakectcp = ();
my $fakectcp_file = "fctcplist";
my $irssidir = Irssi::get_irssi_dir();

my $help = <<EOF;

Usage: (all on one line)
/FCTCP [-add||-replace <ctcp-item> <ctcp-reply>] [-del <ctcp-item>] [-list] [-help]

-add:     Add a new fake ctcp-reply to the list.
-del:     Delete a fake ctcp-reply from the list.
-list:    Display the contents of the fake ctcp-reply list.
-help:    Display this usefull little helpfile.
-replace: Replace a excisting fake reply with a new one. If the old one doesn't excists, the new one will be added by default.

Examples: (all on one line)
/FCTCP -add CHRISTEL We all love christel, don't we! :)
/FCTCP -add LOCATION I'm at home, reading some helpfiles.

/FCTCP -del CHRISTEL
/FCTCP -del LOCATION

Note: The caps are not obligated. The default parameter is -list.
EOF

Irssi::theme_register([
    'fctcp_info', ' # ctcpitem             ctcpreply',
    'fctcp_empty', '%R>>%n %_FCTCP:%_ Your fake ctcp list is empty.',
    'fctcp_added', '%R>>%n %_FCTCP:%_ Added %_$0%_ ($1) to the fake ctcp list.',
    'fctcp_replaced', '%R>>%n %_FCTCP:%_ Replaced the old fake reply %_$0%_ with the new one ($1)',
    'fctcp_delled', '%R>>%n %_FCTCP:%_ Deleted %_$0%_ from the fake ctcp list.',
    'fctcp_nfound', '%R>>%n %_FCTCP:%_ Can\'t find $0 in the fake ctcp list.',
    'fctcp_delusage', '%R>>%n %_FCTCP:%_ Usage: /FCTCP -del <ctcp-item>',
    'fctcp_usage', '%R>>%n %_FCTCP:%_ Usage: /FCTCP -add <ctcp-item> <ctcp-reply>',
    'fctcp_repusage', '%R>>%n %_FCTCP:%_ Usage: /FCTCP -replace <ctcp-item> <ctcp-reply>',
    'fctcp_nload', '%R>>%n %_FCTCP:%_ Could not load the fake ctcp list.',
    'fctcp_request', '%R>>%n %_FCTCP:%_ Used the fake reply %_$1%_ on %_$0%_',
    'fctcp_loaded', '%R>>%n %_FCTCP:%_ The fake reply %_$0%_ already exists, use %_/FCTCP -del $0%_ to remove it from the list.',
    'fctcp_print', '$[!-2]0 $[20]1 $2',
    'fctcp_help', '$0',
    'loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.'
]);

sub ctcpreply {

    my ($server, $data, $nick, $address, $target) = @_;
    my ($findex);

    $data = lc($data);

    return unless (lc($server->{nick}) eq lc($target));

    if (!already_loaded($data)) {
        $findex = check_loaded($data);
        $server->command("^NCTCP $nick $data $fakectcp[$findex]->{reply}");
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_request', $nick, $data);
        Irssi::signal_stop();
    }
}

sub new_fctcp {

    my $fctcp = {};

    $fctcp->{item} = shift;
    $fctcp->{reply} = shift;

    return $fctcp;
}

sub already_loaded {

    my ($item) = @_;
    my $loaded = check_loaded($item);

    if ($loaded > -1) {
        return 0;
    }
    
    return 1;
}

sub check_loaded {

    my ($item) = @_;

    $item = lc($item);

    for (my $loaded = 0; $loaded < @fakectcp; ++$loaded) {
        return $loaded if (lc($fakectcp[$loaded]->{item}) eq $item);
    }
    
    return -1;
}

sub load_fakectcplist {

    my ($file) = @_;

    @fakectcp = ();

    if (-e $file) {
        local *F;
        open(F, "<$file");
        local $/ = "\n";

        while (<F>) {
            chop;
            my $new_fctcp = new_fctcp(split("\t"));
  
            if (($new_fctcp->{item} ne "") && ($new_fctcp->{reply} ne "")) {
            push(@fakectcp, $new_fctcp);
            }
        }
        
        close(F);
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_nload');
    }
}

sub save_fakectcplist {

    my ($file) = @_;

    local *F;
    open(F, ">$file") or die "Could not load the fake ctcpreply list for writing";

    for (my $n = 0; $n < @fakectcp; ++$n) {
        print(F join("\t", $fakectcp[$n]->{item}, $fakectcp[$n]->{reply}) . "\n");
    }
    
    close(F);
}

sub addfakectcp {

    my ($ctcpitem, $ctcpreply) = split (" ", $_[0], 2);

    if (($ctcpitem eq "") || ($ctcpreply eq "")) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_usage');
        return;
    } elsif (!already_loaded($ctcpitem)) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_loaded', $ctcpitem);
        return;
    }

    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_added', $ctcpitem, $ctcpreply);
    push(@fakectcp, new_fctcp($ctcpitem, $ctcpreply));
    save_fakectcplist("$irssidir/$fakectcp_file");
}

sub delfakectcp {

    my ($fdata) = @_;
    my ($fdataindex);

    if ($fdata eq "") {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_delusage');
        return;
    }

    for (my $index = 0; $index < @fakectcp; ++$index) {
        if (lc($fakectcp[$index]->{item}) eq $fdata) {
        $fdataindex = splice(@fakectcp, $index, 1);
        }
    }

    if ($fdataindex) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_delled', $fdata);
        save_fakectcplist("$irssidir/$fakectcp_file");
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_nfound', $fdata);
    }
}

sub replacefakectcp {

    my ($ctcpitem, $ctcpreply) = split (" ", $_[0], 2);
    my ($fdataindex);

    if (($ctcpitem eq "") || ($ctcpreply eq "")) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_repusage');
        return;
    } 

    if (!already_loaded($ctcpitem)) {
        for (my $index = 0; $index < @fakectcp; ++$index) {
            if (lc($fakectcp[$index]->{item}) eq $ctcpitem) {
                $fdataindex = splice(@fakectcp, $index, 1);
            } elsif ($fdataindex) {
                save_fakectcplist("$irssidir/$fakectcp_file");
            } 
        }
    }

    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_replaced', $ctcpitem, $ctcpreply);
    push(@fakectcp, new_fctcp($ctcpitem, $ctcpreply));
    save_fakectcplist("$irssidir/$fakectcp_file");
}

sub fakectcp {

    my ($cmdoption, $ctcpitem, $ctcpreply) = split (" ", $_[0], 3);

    $ctcpitem = lc($ctcpitem);
    $cmdoption = lc($cmdoption);

    if ($cmdoption eq "-add") {
        addfakectcp("$ctcpitem $ctcpreply");
        return;
    } elsif ($cmdoption eq "-del") {
        delfakectcp("$ctcpitem");
        return;
    } elsif ($cmdoption eq "-help") {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_help', $help);
        return;
    } elsif ($cmdoption eq "-replace") {
        replacefakectcp("$ctcpitem $ctcpreply");
        return;
    }

    if (@fakectcp == 0) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_empty');
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_info');

        for (my $n = 0; $n < @fakectcp ; ++$n) {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'fctcp_print', $n, $fakectcp[$n]->{item}, $fakectcp[$n]->{reply});
        }
    }
}

load_fakectcplist("$irssidir/$fakectcp_file");

Irssi::signal_add('default ctcp msg', 'ctcpreply');
Irssi::command_bind('fctcp', 'fakectcp');
Irssi::command_set_options('fctcp','add del list help replace');
Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
