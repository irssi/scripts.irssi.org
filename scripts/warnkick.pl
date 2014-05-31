# warnkick.pl v0.0.2 by Svante Kvarnstrom <svarre@undernet.org>
#
# This script will warn you if you get kicked out of a channel which 
# isn't your current "active" channel, and also hilight the refnum
# to the channel you got kicked from, eg.:
#
# [03:42.50] >> zaei (~zaei@zaei.users.undernet.org) kicked you 
# from #gentoo: GRUB GRUB GRUB GRUB GRUB GRUB GRUB GRUB GRUB
#
# This program is free software, you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of 
# MERCHANTABILITY or FITNESS FOR A PERTICULAR PURPOSE. See the 
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General License 
# along with this program; if not, write to the Free Software 
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

# ----------------------------------------------------------------------

use Irssi qw(printformat signal_add theme_register);
use Irssi::Irc;

use strict;
use vars qw($VERSION %IRSSI);

# ----------------------------------------------------------------------

$VERSION = "0.0.3";
%IRSSI = (
    authors     =>  'Svante Kvarnström',
#    contact     =>  'svarre@undernet.org',
	contact		=>	'sjk@ankeborg.nu',
    name        =>  'warnkick',
    description =>  'warns you if someone kicks you out of a channel',
    license     =>  'GPL',
	url			=>  'http://ankeborg.nu',
    changed     =>  'Tue Sep 28 03:51 CEST 2004',
);

# ----------------------------------------------------------------------

sub event_kick {
    my ($server, $chan, $nick, $knick, $address, $reason) = @_;
    my $win = Irssi::active_win();
    my $kchan = $server->window_find_item($chan);

    return if $win->{refnum} == $kchan->{refnum} || $server->{nick} ne $nick;

    Irssi::active_win()->printformat(MSGLEVEL_CLIENTCRAP, 'warnkick', $knick, $address, $chan, $reason);
    $kchan->activity(4);
}

# ----------------------------------------------------------------------

theme_register([
    'warnkick_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.',
    'warnkick', '%R>>%n $0 ($1) kicked you from $2: $3'
]);

# ----------------------------------------------------------------------

signal_add("message kick", "event_kick");

printformat(MSGLEVEL_CLIENTCRAP, 'warnkick_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});

