##############################################################################################
# pangotext.pl - Specify color patterns in a text message using html-esque tags. In the
#  same vein as pangotext.
#
# DESCRIPTION
# The purpose of this script is to allow you to write text to the current channel with
# complex color patterns, using simple html tag syntax. This allows you to do things like
# send a rainbow-colored message where only part of the message is rainbow colored easily.
#
# USAGE
# /pango <message text here>
# NOTE: You can't put tags inside tags marked 'no inner tags' below
# all other tags are fully nestable
# inverse,inv   Reverse foreground and background of text 
# bold,b        Bold text 
# underline,ul  Underlines text
# rainbow,rb    Colorizes text with a rainbow (no inner tags)
# checker       Colorizes text with a checker pattern (no inner tags)
# ...more to if you can think of any add more functions...
#
# EXAMPLES
# This script makes most sense if you just use it and see how awesome it is. Here
# are some example usages you should check out.
#   # Send a message with a colorful rainbow
#   /pango Hi guys, here's a <rainbow>rainbow</rainbow> for you.
#   /pango Hi guys, here's a <inverse><rainbow>rainbow</rainbow></inverse> for you. # Shows an inverse rainbow
#   /pango Hi guys, here's a <bold><rainbow>rainbow</rainbow></bold> for you.       # Shows a bright rainbow
#
#   # Send a message with a checker pattern and a rainbow and underlined text also
#   /pango <b>Let's play a game</b> <ul>of</ul> <checker>checkers</checker>! Or do you like
#     it better inversed <inverse><checker>inversed checkers</checker></inverse>!
# 
##############################################################################################
use warnings;

use Irssi;
use Irssi::Irc;

$VERSION = "0.2";
%IRSSI = (
    authors     => 'fprintf',
    contact     => 'fprintf@github.com',
    name        => 'pangotext',
    description => 'Render text with various color modifications using HTML tag syntax.',
    license     => 'GNU GPLv2 or later',
);

##############################################################################################
# Render tags
##############################################################################################
sub rainbow
{
    my $text = shift;
    my @palette = (
        2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
    );
    my $rainbow = '';
    my $count = 0;
    foreach my $let (split(//,$text)) {
        $let .= ',' if ($let eq ',');
        $rainbow .= $let =~ /\s/ ? $let : sprintf("\003%02d%s", $palette[$count++ % scalar(@palette)], $let);
    }
    return sprintf("%s\003", $rainbow);
}
sub rb { return rainbow($_[0]); }

sub checker
{
    my $text = shift;
    my $rainbow = '';
    my $count = 0;
    # Black on red, red on black
    my @palette = ('01,04', '04,01');
    foreach my $let (split(//,$text)) { 
        $let .= ',' if ($let eq ',');
        $rainbow .= $let =~ /\s/ ? $let : sprintf("\003%s%s", $palette[$count++ % scalar(@palette)], $let);
    }
    return sprintf("%s\003", $rainbow);
}

sub bold
{
    my $text = shift;
    return sprintf("\002%s\002", $text);
}
# Alias for bold
sub b { return bold($_[0]); }

# Alias for underline
sub underline
{
    my $text = shift;
    return sprintf("\037%s\037", $text);
}
sub ul { return underline($_[0]); }

# Inverse colors of text
sub inverse
{
    my $text = shift;
    return sprintf("\026%s\026", $text);
}
sub inv { return inverse($_[0]); }

sub replaceTags
{
    my ($text) = @_; 

    while ($text =~ /<([^>]+)>(.+?)<\/\1>/g) {
        my ($action,$msg) = ($1,$2);

        if (!defined &{$action}) {
            Irssi::print("[/pango error] invalid action: $action");
            next;
        }

        # Render our text
        $msg = &{$action}($msg);
        my $len = pos($text) - $-[0]; # $-[0] is the position of the start of the last rgex match
        my $index = pos($text) - $len;
        # Insert it
        substr($text, $index, $len, $msg);
    }
    return $text;
}

# /pango
# Send message to current channel
# with rendered text
# See functions above for available tags
sub pango {
    my ($text, $server, $dest) = @_;

    if (!$server || !$server->{connected}) {
        Irssi::print("[/pango error] not connected to server");
        return;
    }

    return unless $dest;

    if ($dest->{type} eq "CHANNEL" || $dest->{type} eq "QUERY") {
        $dest->command("/msg " . $dest->{name} . " " . replaceTags($text));
    }
}


Irssi::command_bind("pango", \&pango);
