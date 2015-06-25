#!/usr/bin/perl -w

## Bugreports and Licence disclaimer.
#
# For bugreports and other improvements contact Geert Hauwaerts <geert@hauwaerts.be>
#
#   This program is free software; you can redistribute it and/or modify it
#   under the terms of the GNU General Public License as published by the Free
#   Software Foundation; either version 2 of the License, or (at your option)
#   any later version.
#   
#   This program is distributed in the hope that it will be useful, but WITHOUT
#   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
#   more details.
#   
#   You should have received a copy of the GNU General Public License along with
#   this script; if not, write to the Free Software Foundation, Inc., 59 Temple
#   Place, Suite 330, Boston, MA  02111-1307  USA.
##


## Documentation.
#
# Versioning:
#
#   This script uses the YEAR.FEATURE.REVISION versioning scheme and must abide
#   by the follwing rules:
#   
#       1) when adding a new feature, you must increase the FEATURE
#          numeric by one;
#       
#       2) when fixing a bug, you must increase the REVISION numeric
#          by one; and
#       
#       3) the first feature or bug change in any given year must set the YEAR
#          numeric to the two digit representation of the current year, and
#          reset the FEATURE and REVISION numerics to 01.
#
# Settings:
#
#   active_notice_show_in_status_window
#   
#       When enabled, notices will also be sent to the status window.
##


##
# Load the required libraries.
##

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);


##
# Declare the administrative information.
##

$VERSION = '15.01.01';

%IRSSI = (
    authors     => 'Geert Hauwaerts',
    contact     => 'geert@hauwaerts.be',
    name        => 'active_notice.pl',
    description => 'This script shows incoming notices into the active channel.',
    license     => 'GNU General Public License',
    url         => 'https://github.com/GeertHauwaerts/irssi-scripts/blob/master/src/active_notice.pl',
    changed     => 'Thu Jun 25 20:46:51 UTC 2015',
);


##
# Register the custom theme formats.
##

Irssi::theme_register([
    'active_notice_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.'
]);


## Function.
#
# Irssi::active_notice::notice_move() function.
#
#   Function:       notice_move()
#   Arguments:      The destination.
#                   The text.
#                   The stripped text.
#   
#   Description:    Print received notices into the active window.
##

sub notice_move {
    
    
    ##
    # Parse the parameters.
    ##
    
    my ($dest, $text, $stripped) = @_;
    my $server                   = $dest->{'server'};
    
    
    ##
    # Check whether the message is irrelevant.
    ##
    
    if (!$server || !($dest->{level} & MSGLEVEL_NOTICES) || $server->ischannel($dest->{'target'})) {
        return;
    }
    
    
    ##
    # Fetch the source, destination and status windows.
    ##
    
    my $witem  = $server->window_item_find($dest->{'target'});
    my $status = Irssi::window_find_name("(status)");
    my $awin   = Irssi::active_win();
    
    
    ##
    # Check whether we have a window for the source of the notice.
    ##
    
    if (!$witem) {
        
        
        ##
        # Check whether the notice originated from the status window.
        ##
        
        if ($awin->{'name'} eq "(status)") {
            return;
        }
        
        
        ##
        # Print the notice in the active window.
        ###
        
        $awin->print($text, MSGLEVEL_NOTICES);
        
        
        ##
        # Check whether the notice needs to be printed in the status window.
        ##
        
        if (!Irssi::settings_get_bool('active_notice_show_in_status_window')) {
            Irssi::signal_stop();
        }
    } else {
        
        
        ##
        # Check whether we need to print the notice in the status window.
        ##
        
        if (($awin->{'name'} ne "(status)") && (Irssi::settings_get_bool('active_notice_show_in_status_window'))) {
            $status->print($text, MSGLEVEL_NOTICES);
        }
        
        
        ##
        # Check whether the notice originated from the active window.
        ##
        
        if ($witem->{'_irssi'} == $awin->{'active'}->{'_irssi'}) {
            return;
        }
        
        
        ##
        # Print the notice in the active window.
        ##
        
        $awin->print($text, MSGLEVEL_NOTICES);
    }
}


##
# Register the signals to hook on.
##

Irssi::signal_add('print text', 'notice_move');


##
# Register the custom settings.
##

Irssi::settings_add_bool('active_notice', 'active_notice_show_in_status_window', 1);


##
# Display the script banner.
##

Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'active_notice_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});