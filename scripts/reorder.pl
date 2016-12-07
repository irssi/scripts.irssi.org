# Save window layout to an arbitrary file and load layouts upon demand
# Useful for being able to temporarily reorder your windows and then reverting to your "normal" layout
# Also useful as an easy way to reorder your windows
#
# A special thanks to billnye, Zed` and Bazerka for their help
#
# Usage:
#  /layout_save filename
#    Saves the layout to the textfile "filename.layout"
#  /layout_load filename
#    Loads the layout from the textfile "filename.layout"
#
# TODO:
#   Check the layout file for a number used twice
#   On script load, run a layout_load
#   On channel join, run load: channel joined
#

use strict;
use Irssi;
use Data::Dumper;
use vars qw($VERSION %IRSSI);
use POSIX 'strftime';

%IRSSI = (
    authors     => "Isaac Good",
    contact     => "irssi\@isaacgood.com",
    name        => "reorder",
    description => "Reordering windows based on a textfile.",
    license     => "GPL",
);
$VERSION = '1.0';

# Map user input to a valid filename
sub GetFilename
{
    my ($filename) = @_;

    # On no input, use a default filename.
    unless (length($filename))
    {
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
        $filename = POSIX::strftime("%y%m%d", $sec, $min, $hour, $mday, $mon, $year);
        # If you prefer not having datestamped filenames, uncomment:
        # $filename = "default";
    }

    # Use glob expansion to match things like ~/
    my $glob = glob($filename);
    $filename = $glob if $glob;

    # Only handle directories when using an absolute path.
    if ($filename =~ /\// and $filename !~ /^\//)
    {
        print "I don't like /'s in filenames. Unless you want to specify an absolute path.";
        return;
    }

    # Add a file extension
    $filename .= '.layout' unless ($filename =~ /\.layout$/);

    # Use get_irssi_dir() unless using an absolute path
    if ($filename !~ /\//) {
        my $path = Irssi::get_irssi_dir();
        $path .= '/' unless ($path =~ /\/$/);
        $filename = $path . $filename;
    }

    return $filename;
}

# Check a filename exists and can be read.
sub CanReadFile
{
    my ($filename) = @_;
    unless (-f $filename)
    {
        print "No such file $filename";
        return 0;
    }
    unless (-r $filename)
    {
        print "Can not read file $filename";
        return 0;
    }
    return 1;
}

# Save the current layout to file
sub CmdLayoutSave
{
    my ($filename, $data, $more) = @_;
    my $FH;

    $filename = GetFilename($filename);
    return unless ($filename);

    unless(open $FH, ">", $filename)
    {
        print "Can not open $filename";
        return;
    }

    # Order by ref. Print ref and an id tag
    for my $win (sort {$a->{'refnum'} <=> $b->{'refnum'}} Irssi::windows())
    {
        my $id = $win->{'name'} ? $win->{'name'} : $win->{'active'}->{'name'};
        my $tag = $win->{'active'}->{'server'}->{'tag'};
        printf $FH "%d\t%s:%s\n", $win->{'refnum'}, $id, $tag;
    }
    close $FH;
    print "Layout saved to $filename";
}

# Load a list and use it to reorder
sub CmdLayoutLoad
{
    my ($filename, $data, $more) = @_;
    $filename = GetFilename($filename);

    return unless ($filename);
    return unless CanReadFile($filename);

    my @layout;
    my ($ref, $id, $tag, $FH);

    # Pull the refnum and id
    unless(open $FH, "<", $filename)
    {
        print "Can not open file $filename.";
        return;
    }
    while (my $line = <$FH>)
    {
        chomp $line;
        my ($ref, $id) = split(/\t/, $line, 2);
        next unless ($ref and $id);

        push @layout, {refnum => $ref, id => $id};
    }
    close $FH;

    # For each layout item from the file, find the window and set it's ref to that number
    for my $position (sort {$a->{'refnum'} <=> $b->{'refnum'}} @layout)
    {
        for my $win (Irssi::windows())
        {
            $id = $win->{'name'} ? $win->{'name'} : $win->{'active'}->{'name'};
            $tag = $win->{'active'}->{'server'}->{'tag'};
            $id .= ":" . $tag;
            if ($id eq $position->{'id'})
            {
                $win->set_refnum($position->{'refnum'});
                last;
            }
        }
    }
}

Irssi::command_bind( 'layout_save', 'CmdLayoutSave' );
Irssi::command_bind( 'layout_load', 'CmdLayoutLoad' );
