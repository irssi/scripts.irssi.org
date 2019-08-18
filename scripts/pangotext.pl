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
# all other tags are fully nestable. Tags noted below with 'attributes'
# also have attributes that can be specified (ie <tag attrib=value>) no spaces
# are allowed in attribute names or values.
# inverse,inv   Reverse foreground and background of text 
# bold,b        Bold text 
# underline,ul  Underlines text
# rainbow,rb    Colorizes text with a rainbow (no inner tags)
# checker       Colorizes text with a checker pattern (no inner tags)
# gradiant      Colorizes text with a gradiant (no inner tags, attribs { start, end })
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
#   # Gradiants allow start and end range specifier in by color name:
#   /pango <gradiant start=green end=red>some gradiant text here</gradiant>
#   /pango <gradiant>default gradiant range</gradiant>
#   /pango <gradiant start=lightcyan end=white>a light gradiant</gradiant>
# 
##############################################################################################
use strict;
use warnings;

use Irssi;
use Irssi::Irc;
use utf8;

our $VERSION = "1.2";
our %IRSSI = (
    authors     => 'fprintf',
    contact     => 'fprintf@github.com',
    name        => 'pangotext',
    description => 'Render text with various color modifications using HTML tag syntax.',
    license     => 'GNU GPLv2 or later',
);

# Color metadata
my %color = (
    white => 0,
    black => 1,
    blue => 2,
    green => 3,
    lightred => 4,
    red => 5,
    purple => 6,
    orange => 7,
    yellow => 8,
    lightgreen => 9,
    cyan => 10,
    lightcyan => 11,
    lightblue => 12,
    lightpurple => 13,
    gray => 14,
    lightgray => 15,
);

my @color_order = (
    'white', 'lightgray', 'lightcyan', 'lightblue', 'lightgreen',
    'lightpurple', 'yellow', 'lightred', 'orange', 'red', 'purple',
    'cyan', 'blue', 'green', 'gray', 'black' 
);
my %color_ordermap;
for (my $i = 0; $i < @color_order; ++$i) {
    $color_ordermap{$color_order[$i]} = $i;
}

# Allowed tags
my %tag_registry = (
    'rb' => \&rainbow,
    'rainbow' => \&rainbow,
    'checker' => \&checker,

    'gradiant' => \&gradiant,
    'gradient' => \&gradiant,
    'grad' => \&gradiant,

    'ul' => \&underline,
    'underline' => \&underline,
    'bold' => \&bold,
    'b' => \&bold,
    'inverse' => \&inverse,
    'inv' => \&inverse,
);

my $utf8;

##############################################################################################
# Utils
##############################################################################################

sub palettize
{
    my ($text, $palette) = @_;
    return $text if (!$palette || ref($palette) ne 'ARRAY');

    # Colorize the text using the given palette
    my $count = 0;
    my $render = '';
    foreach my $let (split(//,$text)) {
        $let .= ',' if ($let eq ','); 
        $render .= $let =~ /\s/ ? $let : sprintf("\003%02d%s", $$palette[$count++ % scalar(@$palette)], $let);
    }
    return sprintf("%s\003", $render);
}

##############################################################################################
# Render tags
##############################################################################################
sub rainbow
{
    my $text = shift;
    my @palette = (
        2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
    );
    return palettize($text, \@palette);
}

sub gradiant
{
    my ($text, $attribs) = @_;
    $attribs ||= {};
    $attribs->{start} ||= 'white';
    $attribs->{end} ||= 'lightpurple';

    # Build the palette based on the given color range
    my @palette = ();
    my ($start,$end) = ($color_ordermap{$attribs->{start}},$color_ordermap{$attribs->{end}});
    # Fancy way to find min and max 
    my $min = ($start,$end)[$start > $end];
    my $max = ($start,$end)[$start < $end];
    for (my $i = $min; $i <= $max; ++$i) {
        push(@palette, $color{$color_order[$i % scalar(@color_order)]}); # Wrap colors around if they overlap
    }

    # Palettize the text
    return palettize($text, \@palette);
}

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

sub underline
{
    my $text = shift;
    return sprintf("\037%s\037", $text);
}

sub inverse
{
    my $text = shift;
    return sprintf("\026%s\026", $text);
}

##############################################################################################
# Renderer function
##############################################################################################

sub render
{
    my ($text) = @_; 

    while ($text =~ /<\s*([^>\s]+)\s*([^>]*)>(.+?)<\/?\1>/g) {
        my ($action,$extra,$msg) = ($1,$2,$3);
        my $mstart = $-[0];
        my $mend = pos($text);
        my %attribs = ();

        (%attribs) = $extra =~ /(\S+)\s*=\s*(\S+)/g;

        if (!exists($tag_registry{$action})) {
            Irssi::print("[/pango error] invalid action: $action");
            next;
        }

        # Render our text
        $msg = $tag_registry{$action}->($msg,\%attribs);
        my $len = $mend - $mstart;
        my $index = $mend - $len;
        # Insert it
        substr($text, $index, $len, $msg);
    }
    return $text;
}

##############################################################################################
# Irssi interface
##############################################################################################
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
    if ($utf8) {
        utf8::decode($text)
    }

    if ($dest->{type} eq "CHANNEL" || $dest->{type} eq "QUERY") {
        $dest->command("/msg " . $dest->{name} . " " . render($text));
    }
}


Irssi::command_bind("pango", \&pango);

$utf8= Irssi::settings_get_str('term_charset') eq 'UTF-8';

# vim:set ts=4 sw=4 expandtab:
