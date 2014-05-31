##
# doublefilter.pl
#
# Removes double messages, even if they appear on different channels.
# The script stores every message it sees in a query or a channel into
# a FIFO (a queue), if new, or increases the counter for that message.
# Any message already in the FIFO is further ignored (e.g. doesn't show
# up in any window).
#
# Customization:
#
# /set filter_length <n>
# Sets the number of lines the script remembers in a FIFO to <n>.
# Setting filter_length to 1 simulates the behaviour of repeat.pl, but
# it depends on ignore_window if doublefilter.pl ignores the windows the
# message gets to.
# Default is currently set to 5.
#
# /set show_repeat on/off
# If set to ON, shows the count for lines the script moves out of the FIFO.
# Default is OFF.
# (Idea is blatantly ripped from repeat.pl.)
#
# /set ignore_window on/off
# If set to OFF, and if filter_length is set to 1, it emulates repeat.pl.
# If set to ON, double messages get also filtered if they appear in different
# windows (queries or channels).
# Default is ON.
# (This idea was also inspired by repeat.pl.)
#
# History:
#
# 0.1 Initial release.
#
# 0.2 Counter for messages
#
# 0.3 If desired, filters per message window, thus emulating repeat.pl
##

use strict;
use Irssi;
use Data::Dumper;

use vars qw($VERSION %IRSSI);
$VERSION = "0.3";
%IRSSI = (
	  authors	=> "Karl Siegemund",
	  contact	=> "q \[at\] spuk.de",
	  name		=> "doublefilter",
	  description	=> "Filters msgs which appear the same on different channels.",
	  license	=> "GPLv2",
	  changed	=> "22.04.2005 9:50GMT"
);

my %lastmsgs = ();
my %count =    ();
my %window =   ();

sub filter_check {
    my $max  = Irssi::settings_get_int('filter_length');
    my $show = Irssi::settings_get_bool('show_repeat');
    my $win  = Irssi::settings_get_bool('ignore_window');
    my ($server, $msg, $nick, undef, $target) = @_;
    my $refnum = -1;
    ($target, $msg) = split / :/,$msg,2;
    if (!$win) {
	$refnum = $server->window_find_item($target)->{refnum};
    }
    $msg = "<$nick> $msg";
    if (exists $count{$refnum}{$msg}) {
	Irssi::signal_stop();
	++$count{$refnum}{$msg};
	return;
    }
    if(exists $lastmsgs{$refnum}) {
	$lastmsgs{$refnum} = [ $msg, @{$lastmsgs{$refnum}} ];
    } else {
	$lastmsgs{$refnum} = [ $msg ];
    }
    if(scalar @{$lastmsgs{$refnum}} > $max) {
	my $last = pop @{$lastmsgs{$refnum}};
	print "$last\n*** Repeated $count{$refnum}{$last} times."
	    if $show && $count{$refnum}{$last};
	delete $count{$refnum}{$last};
    }
    $count{$refnum}{$msg} = 0;
}

sub window_change {
    my $new = shift->{refnum};
    my $old = shift;

    $count{$new}    = $count{$old};
    $lastmsgs{$new} = $lastmsgs{$old};

    delete $count{$old};
    delete $lastmsgs{$old};
}

sub window_destroyed {
    my $ref = shift->{refnum};

    delete $count{$ref};
    delete $lastmsgs{$ref};
}

Irssi::settings_add_int ('doublefilter', 'filter_length' => '5');
Irssi::settings_add_bool('doublefilter', 'show_repeat' => 0);
Irssi::settings_add_bool('doublefilter', 'ignore_window' => 1);

Irssi::signal_add_first('event privmsg', \&filter_check);
Irssi::signal_add_last('window refnum changed', \&window_change);
Irssi::signal_add_last('window destroyed', \&window_destroyed);
