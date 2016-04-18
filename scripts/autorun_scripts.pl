### vague's note: original script by nightfrog, below is nightfrog's notes on this
###
### Usage note: 
### For best performance, make sure Linux::Inotify2 is installed, File::ChangeNotify
### doesn't have a dependency on it and if Linux::Inotify2 isn't installed
### File::ChangeNotify will fall back to using File::ChangeNotify::Watcher::Default
### which is a poor choice and rarely works
###
### The script will attempt to autorun newly created or modified files in the
### autorun directory, it will also unload scripts that are deleted from the
### autorun directory
#
# Author : nightfrog
# Version: 1
#
# Watch the scripts directory for changes and handle them accordingly.
#
# If you are adding/deleting/changing scripts on a regular basis then this is handy
#
# Why I created this..
# When I'm creating a script I will keep Irssi open in a terminal and an editor in
# another side by side. When I save my changes in the editor this script will reload
# it for me and I will be able to look at the Irssi terminal and see if I get errors
# or not. If not, I can go to Irssi and test my creation.

# ---- NOTE ---- #
# Symlink them to autorun like http://scripts.irssi.org recommends


use strict;
use warnings;
use File::Spec;
use File::ChangeNotify;
use File::Basename qw( basename );
use Irssi qw(timeout_add command get_irssi_dir);

use vars qw($VERSION %IRSSI);
$VERSION = "0.1";
%IRSSI = (
          authors       => "Jari Matilainen, original script by nightfrog",
          contact       => 'vague!#irssi@freenode on irc',
          name          => "autorun_scripts",
          description   => "Autorun scripts/symlinks created in the scripts/autorun directory",
          license       => "GPLv2",
          changed       => "18/04/2016 15:10:00 CEST"
);

my $watch = File::ChangeNotify->instantiate_watcher(
    directories => [
        File::Spec->catdir( get_irssi_dir() . '/scripts/autorun' ),
    ],
    filter => qr/\.(?:pl)$/,
    follow_symlinks => 1,
);

timeout_add( 1000, sub {
    for my $events ( $watch->new_events() ) {
        if ( $events->type eq 'modify' ){ # reload
            Irssi::print('Reloading ' . basename $events->path);
            command( 'script load ' . basename $events->path );
        }
        if ( $events->type eq 'create' ) { # load
            Irssi::print('Loading ' . basename $events->path);
            command( 'script load ' . basename $events->path );
        }
        if ( $events->type eq 'delete' ) { # delete
            Irssi::print('Unloading ' . basename $events->path);
            command( 'script unload ' . basename $events->path );
        }
    }
}, undef);
