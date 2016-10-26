# Maintains a representation of window activity status in a file
#
# Creates and updates ~/.irssi/activity_file 
# The file contains a comma separated row of data for each window item:
# Window refnum,Window item data_level,Window item name,Item's server tag
#
# Use it for example like this:
# ssh me@server.org "while (egrep '^[^,]*,3' .irssi/activity_file|sed -r 's/[^,]*,[^,]*,(.*),.*/\1/'|xargs echo); do sleep 1; done" | osd_cat -l1

use strict;
use Irssi;
use Fcntl qw(:flock);
use vars qw($VERSION %IRSSI);

$VERSION = "1.00";
%IRSSI = (
    authors     => 'Antti Vähäkotamäki',
    name        => 'activity_file',
    description => 'Maintains a representation of window activity status in a file',
    license     => 'GNU General Public License',
    changed     => 'Wed Jul 19 23:59 EET 2006'
);


my $filename = $ENV{HOME} . '/.irssi/activity_file';
my ($scriptname) = __PACKAGE__ =~ /Irssi::Script::(.+)/;
my $last_values = {};

sub item_status_changed {
    my ($item, $oldstatus) = @_;
    
    return if ! ref $item->{server};

    my $tag = $item->{server}{tag};
    my $name = $item->{name};

    return if ! $tag || ! $name;

    store_status() if ! $last_values->{$tag}{$name} ||
	$last_values->{$tag}{$name}{level} != $item->{data_level};
}

sub store_status {
    my $new_values = {};
    my @items = ();

    for my $window ( sort { $a->{refnum} <=> $b->{refnum} } Irssi::windows() ) {

    	for my $item ( $window->items() ) {

            next if ! ref $item->{server};

            my $tag = $item->{server}{tag};
            my $name = $item->{name};

            next if ! $tag || ! $name;

            $new_values->{$tag}{$name} = {
                tag => $tag,
                name => $name,
                level => $item->{data_level},
                window => $window->{refnum},
            };

            push @items, $new_values->{$tag}{$name};
        }
    }

    if ( open F, "+>>", $filename ) {

        flock F, LOCK_EX;
        seek F, 0, 0;
        truncate F, 0;

        for ( @items ) {
            print F join(',', $_->{window}, $_->{level}, $_->{name}, $_->{tag});
            print F "\n";
        }

        close F; # buffer is flushed and lock is released on close
    }
    else {
        print 'Error in script '. "'$scriptname'" .': Could not open file '
            . $filename .' for writing!';
    }

    $last_values = $new_values;

}

# store initial status
store_status();

Irssi::signal_add_last('window item activity', 'item_status_changed');

