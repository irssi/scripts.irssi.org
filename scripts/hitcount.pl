# $Id: hitcount.pl,v 1.3.2.2 2002/03/05 18:19:28 shrike Exp shrike $

use strict;
use vars qw($VERSION %IRSSI);
my @rev = split(/ /, '$Revision: 1.4 $n');
$VERSION = "1.4";
%IRSSI = (
    authors     => 'Riku "Shrike" Lindblad',
    contact     => 'shrike\@addiktit.net, Shrike on IRCNet/QNet/EFNet/DALNet',
    name        => 'hitcount',
    description => 'Add a apache page hitcounter to statusbar',
    sbitems     => 'hitcount',
    license     => 'Free',
    changed     => '$Date: 2017/03/07 $ ',
);

# Changelog:
#
# Revision 1.4  2017/03/07 bw1
# bug fix
#
# Revision 1.3.2.2  2002/03/05 18:19:28  shrike
# Added use vars qw($VERSION %IRSSI);
#
# Revision 1.3.2.1  2002/03/05 18:04:01  shrike
# Damnit, left default refresh to a debug value...
#
# Revision 1.3.1.1  2002/03/05 17:59:47  shrike
# Forgot to turn off debugging...
#
# Revision 1.3  2002/03/05 17:57:04  shrike
# Added use strict
# .. which finally cleared up last of the bugs from the code (hopefully)
# Next on TODO: get the item colors from theme and more configuration options.
#
# Revision 1.2  2002/03/05 17:27:15  shrike
# Added standard script headers (http://juerd.nl/irssi/headers.html)
# Removed call to Irssi::statusbars_recreate_items();
# And a bit of polishing here and there..
# The first two updates bug, need to fix that.
#

#  To install, you also need to put 
#  hitcount = { };
#  into your statusbar code in irssi config
#
# sets:
#  /SET hitcount_regexp - A regexp that identifies your homepage
#  /SET hitcount_refresh - Refresh rate
#  /SET hitcount_access_log - webserver access log

# TODO:
# Add ignore regexp, to prevent f.ex. css-files from increasing counter

use Irssi::TextUI;

# Debug level - higher levels print out more crap
my $debug_level = 0;
# current hitcount
my ($total_hitcount, $my_hitcount) = (0,0);
# change prefixes
my ($my_prefix, $total_prefix) = ("","");
# change from last update
my ($my_change, $total_change) = (0,0);
# hitcount on last update
my ($last_total_hitcount, $last_my_hitcount, $last_refresh) = (0,0,0);
# set default variables
my ($filename, $regexp, $refresh) = ("/var/log/httpd/access.log", "/", 60);
# marker for the refresh
my $refresh_tag;

# read the access_log and count rows, regexp matches
sub get_hitcount {
    my $filename = Irssi::settings_get_str('hitcount_access_log');
    my $regexp = Irssi::settings_get_str('hitcount_regexp');
    
    Irssi::print("Finding match for \"$regexp\"", MSGLEVEL_CLIENTERROR) if($debug_level > 2);
    
    ($total_hitcount, $my_hitcount) = (0,0);
    
    # Go through the access log and count matches to the given regexp
    if(open STUFF, "<", $filename) {
        while (<STUFF>) {
            $total_hitcount++;
            #if(m#$regexp#ois)
            if(m<GET $regexp >) {
                # DEBUG
                Irssi::print("Matched $_", MSGLEVEL_CLIENTERROR) if($debug_level > 3);
                $my_hitcount++;
            }
        }
        close STUFF;
    } else {
        Irssi::print("Failed to open <$filename: $!", MSGLEVEL_CLIENTERROR);
    }

    return($my_hitcount,$total_hitcount);
}

# show the result
sub hitcount {
    my ($item, $get_size_only) = @_;
    
    $item->default_handler($get_size_only, 
        "{sb Hits: $last_my_hitcount/$last_total_hitcount ".
        "$my_prefix$my_change/$total_prefix$total_change}", '', 0);
}

# repeat refresh by interval time
sub refresh_hitcount {
    
    my ($my_hitcount, $my_total_hitcount) = get_hitcount();
    
    # Calculate change since last update
    if ($last_total_hitcount >0) {
        $my_change = $my_hitcount - $last_my_hitcount;
        $total_change = $total_hitcount - $last_total_hitcount;
    }
    
    # Get correct prefix for change
    $my_prefix = "+" if($my_change > 0);
    $my_prefix = "-" if($my_change < 0);
    $my_prefix = ""  if($my_change == 0);
    $total_prefix = "+" if($total_change > 0);
    $total_prefix = "-" if($total_change < 0);
    $total_prefix = "" if($total_change == 0);
    
    # DEBUG
    Irssi::print(
        "$last_my_hitcount/$last_total_hitcount | $my_hitcount/$total_hitcount ".
        "| $my_prefix$my_change $total_prefix$total_change", 
        MSGLEVEL_CLIENTERROR) if($debug_level > 0);

    # show it
    Irssi::statusbar_items_redraw('hitcount');
    
    # last hitcount = current hitcount
    $last_my_hitcount = $my_hitcount;
    $last_total_hitcount = $total_hitcount;
    
    # reset hitcounts
    $my_hitcount = 0;
    $total_hitcount = 0;
    $my_total_hitcount = 0;
}

sub read_settings {
    my $time = Irssi::settings_get_int('hitcount_refresh');
    return if ($time == $last_refresh);

    $last_refresh = $time;
    
    Irssi::timeout_remove($refresh_tag) if ($refresh_tag);
    $refresh_tag = Irssi::timeout_add($time*1000, 'refresh_hitcount', undef);

    refresh_hitcount();
}

# default values
Irssi::settings_add_str('misc', 'hitcount_regexp', $regexp);
Irssi::settings_add_int('misc', 'hitcount_refresh', $refresh);
Irssi::settings_add_str('misc', 'hitcount_access_log', $filename);

# sub to call, string on statusbar, func on statusbar
Irssi::statusbar_item_register('hitcount', 0, 'hitcount');

Irssi::print("Hitcounter version ".$rev[1]." loaded");

read_settings();
Irssi::signal_add('setup changed', 'read_settings');

