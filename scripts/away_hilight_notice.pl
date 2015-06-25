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
#   away_hilight_notice_timeout
#   
#       The default time between notices sent to the same person are 3600
#       seconds or once an hour.
#
#   away_hilight_notice_filter
#   
#       A list of channels, separated by space, on which the script will be
#       disabled.
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
    name        => 'away_hilight_notice.pl',
    description => 'This script will notice your away message in response to a hilight.',
    license     => 'GNU General Public License',
    url         => 'https://github.com/GeertHauwaerts/irssi-scripts/blob/master/src/away_hilight_notice.pl',
    changed     => 'Thu Jun 25 20:46:51 UTC 2015',
);


##
# Register the custom theme formats.
##

Irssi::theme_register([
    'away_hilight_notice_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.',
]);


##
# Declare the script variables.
##

my %lasthilight;


## Function.
#
# Irssi::away_hilight_notice::away_hilight_notice() function.
#
#   Function:       away_hilight_notice()
#   Arguments:      The destination.
#                   The text.
#                   The stripped text.
#   
#   Description:    Sends a notice with your away message.
##

sub away_hilight_notice {
    
    
    ##
    # Parse the parameters.
    ##
    
    my ($dest, $text, $stripped) = @_;
    my $server                   = $dest->{'server'};
    my $hilight                  = Irssi::parse_special('$;');
    
    
    ##
    # Check whether the message is irrelevant.
    ##
    
    if (!$server || !($dest->{'level'} & MSGLEVEL_HILIGHT) || ($dest->{'level'} & (MSGLEVEL_MSGS|MSGLEVEL_NOTICES|MSGLEVEL_SNOTES|MSGLEVEL_CTCPS|MSGLEVEL_ACTIONS|MSGLEVEL_JOINS|MSGLEVEL_PARTS|MSGLEVEL_QUITS|MSGLEVEL_KICKS|MSGLEVEL_MODES|MSGLEVEL_TOPICS|MSGLEVEL_WALLOPS|MSGLEVEL_INVITES|MSGLEVEL_NICKS|MSGLEVEL_DCC|MSGLEVEL_DCCMSGS|MSGLEVEL_CLIENTNOTICE|MSGLEVEL_CLIENTERROR))) {
        return;
    }
    
    
    ##
    # Check whether we are marked as away.
    ##
    
    if ($server->{'usermode_away'}) {
        
        
        ##
        # Loop through each entry in the filter.
        ##
        
        foreach (split /\s+/, Irssi::settings_get_str('away_hilight_notice_filter')) {
            
            
            ##
            # Check if the target is filtered.
            ##
            
            if (lc($dest->{'target'}) eq lc($_)) {
                return;
            }
        }
        
        
        ##
        # Check whether we need to send a notice.
        ##
        
        if (!$lasthilight{lc($hilight)}{'last'} || ($lasthilight{lc($hilight)}{'last'} && ((time() - $lasthilight{lc($hilight)}{'last'}) > Irssi::settings_get_int('away_hilight_notice_timeout')))) {
            $lasthilight{lc($hilight)}{'last'} = time();
            $server->command('^NOTICE ' . $hilight . ' I\'m away (' . $server->{'away_reason'} . ')');
        }
    }
}


## Function.
#
# Irssi::away_hilight_notice::clear_associative_array() function.
#
#   Function:       clear_associative_array()
#   Arguments:      The server.
#   
#   Description:    Remove the timers from the memory.
##

sub clear_associative_array {
    
    
    ##
    # Parse the parameters.
    ##
    
    my ($server) = @_;
    
    
    ##
    # Check whether we are marked as active.
    ##
    
    if (!$server->{'usermode_away'}) {
        %lasthilight = ();
    }
}


##
# Register the signals to hook on.
##

Irssi::signal_add('print text',        'away_hilight_notice');
Irssi::signal_add('away mode changed', 'clear_associative_array');


##
# Register the custom settings.
##

Irssi::settings_add_int('away', 'away_hilight_notice_timeout', 3600);
Irssi::settings_add_str('away', 'away_hilight_notice_filter',  '#bitlbee #twitter');


##
# Display the script banner.
##

Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'away_hilight_notice_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});