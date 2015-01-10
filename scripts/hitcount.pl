# $Id: hitcount.pl,v 1.3.2.2 2002/03/05 18:19:28 shrike Exp shrike $

use strict;
use vars qw($VERSION %IRSSI);
my @rev = split(/ /, "$Revision: 1.3.2.2 $n");
$VERSION = "1.3";
%IRSSI = (
	    authors     => 'Riku "Shrike" Lindblad',
	    contact     => 'shrike\@addiktit.net, Shrike on IRCNet/QNet/EFNet/DALNet',
	    name        => 'hitcount',
	    description => 'Add a apache page hitcounter to statusbar',
	    license     => 'Free',
	    changed     => '$Date: 2002/03/05 18:19:28 $ ',
	  );

# Changelog:
#
# $Log: hitcount.pl,v $
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
my ($total_hitcount, $my_hitcount) = (0);
# change prefixes
my ($my_prefix, $total_prefix) = ("");
# change from last update
my ($my_change, $total_change) = (0);
# hitcount on last update
my ($last_total_hitcount, $last_my_hitcount, $last_refresh) = (0);
# set default variables
my ($filename, $regexp, $refresh) = ("/var/log/apache/access.log", "/", 60);

sub get_hitcount {
    my $filename = Irssi::settings_get_str('hitcount_access_log');
    my $regexp = Irssi::settings_get_str('hitcount_regexp');
    
    Irssi::print("Finding match for \"".my $regexp."\"", MSGLEVEL_CLIENTERROR) if($debug_level > 2);
    
    ($total_hitcount, $my_hitcount) = (0);
    
    # Go through the access log and count matches to the given regexp
    if(open STUFF, "<", $filename)
    {
   	while (<STUFF>) 
	{
	    $total_hitcount++;
	    if(/$regexp/ois)
	    {
		# DEBUG
		Irssi::print("Matched $_", MSGLEVEL_CLIENTERROR) if($debug_level > 3);
		$my_hitcount++;
	    }
	}
	close STUFF;
    }
    else
    {
	Irssi::print("Failed to open <$filename: $!", MSGLEVEL_CLIENTERROR);
    }
    return($my_hitcount,$total_hitcount);
}

sub hitcount {
    my ($item, $get_size_only) = @_;
    
    # DEBUG
    Irssi::print("$get_size_only | $last_my_hitcount/$last_total_hitcount | $my_hitcount/$total_hitcount | $my_prefix$my_change $total_prefix$total_change", MSGLEVEL_CLIENTERROR) if($debug_level > 0);
    
    my ($my_hitcount, $my_total_hitcount) = get_hitcount();
    
    if($my_hitcount eq '') { $my_hitcount = 0; }
    
    # Calculate change since last update
    $my_change = $my_hitcount - $last_my_hitcount;
    $total_change = $total_hitcount - $last_total_hitcount;
    
    # Get correct prefix for change
    $my_prefix = "+" if($my_change > 0);
    $my_prefix = "-" if($my_change < 0);
    $my_prefix = ""  if($my_change == 0);
    $total_prefix = "+" if($total_change > 0);
    $total_prefix = "-" if($total_change < 0);
    $total_prefix = "" if($total_change == 0);
    
    $item->default_handler($get_size_only, undef, "$last_my_hitcount $last_total_hitcount $my_prefix$my_change $total_prefix$total_change", 1);
    
    # last hitcount = current hitcount
    $last_my_hitcount = $my_hitcount;
    $last_total_hitcount = $total_hitcount;
    
    # reset hitcounts
    $my_hitcount = 0;
    $total_hitcount = 0;
    $my_total_hitcount = 0;
}

sub refresh_hitcount {
    get_hitcount();
    Irssi::statusbar_items_redraw('hitcount');
}

sub read_settings {
    my $time = Irssi::settings_get_int('hitcount_refresh');
    return if ($time == $last_refresh);

    $last_refresh = $time;
    Irssi::timeout_remove(my $refresh_tag) if (my $refresh_tag);
    $refresh_tag = Irssi::timeout_add($time*1000, 'refresh_hitcount', undef);
}

# default values
Irssi::settings_add_str('misc', 'hitcount_regexp', $regexp);
Irssi::settings_add_int('misc', 'hitcount_refresh', $refresh);
Irssi::settings_add_str('misc', 'hitcount_access_log', $filename);
# sub to call, string on statusbar, func on statusbar
Irssi::statusbar_item_register('hitcount', '{sb Hits: $0%K/%N$1 $2%K/%N$3}', 'hitcount');

read_settings();
Irssi::signal_add('setup changed', 'read_settings');

Irssi::print("Hitcounter version ".$rev[1]." loaded");
