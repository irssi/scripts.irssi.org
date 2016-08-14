# Author: culb (nightfrog)
# Version: 1
# Description: Automatically load and unload scripts
#              as they change in the irssi scripts directory
#
# Note: Scripts are supposed to be linked to the autorun directory
#       so this script only monitors *irssi directory*/scripts
#       Follow the instructions at https://scripts.irssi.org

use strict;
use warnings;
use File::Spec;
use File::ChangeNotify;
use File::Basename qw( basename dirname );
use Irssi qw( command get_irssi_dir timeout_add_once );

our $VERSION = 1;
our %IRSSI = (
	authors     => 'culb (nightfrog)',
	contact     => 'the01culb@gmail.com',
	description => 'Automatically load and unload scripts as they change',
	license     => 'BSD',
);

BEGIN{
	if( dirname(__FILE__) ne get_irssi_dir . '/scripts' )
	{
		Irssi::print( "\002\0034Place the ". basename(__FILE__) .
						" file in the scripts directory\002",
						MSGLEVEL_CLIENTERROR );
	}
}

my $watch = File::ChangeNotify->instantiate_watcher(
	directories => [
		File::Spec->catdir( get_irssi_dir . '/scripts' ),
	],
	filter => qr/\.(?:pl)$/
);

timeout_add_once 1000, sub
{
	for my $events ( $watch->new_events() )
	{
		if( $events->type eq 'modify' )# reload
		{
			command( 'script load ' . basename $events->path );
		}
		if( $events->type eq 'create' )# load
		{
			command( 'script load ' . basename $events->path );
		}
		if( $events->type eq 'delete' )# delete
		{
			command( 'script unload ' . basename $events->path );
		}
	}
},
    undef
;
