# This script adds command /lwho that shows 
# locally logged users in current window

use strict;
use vars qw($VERSION %IRSSI);
$VERSION = '0.01a';
%IRSSI = (
 authors     => 'Mika',
 contact     => '[Mika] @ IRCnet',
 name        => 'Local who',
 description => 'Displays users logged on system in current window, simple one',
 license     => '-',
 url         => '-',
 changed     => 'none',
 bugs        => 'none?'
);


use Irssi;
use Sys::Hostname;

Irssi::command_bind('lwho' => sub {
        my $floodi = " ---- users logged on system \cB". hostname ."\cB";
        my $output = `w`;
        $floodi =~ s/ - $//;
        Irssi::active_win()->print("$floodi\n$output ----", MSGLEVEL_CRAP);
    }
);

Irssi::print("local who $VERSION by [Mika]");
