#
# psybnc like oidentd support for irssi
#
# requirements:
# - oidentd (running)
# - your user needs "spoof" permissions in the /etc/oidentd.conf
#   looks like:
#   "user youruser {
#        default {
#            allow spoof;
#        }
#   }"
#
#  if you want to spoof local user you need:
#  "allow spoof_all;" 
#
# - this script works like psybnc oidentd support.              
#   that means it writes ~/.ispoof and ~/.oidentd.conf
#   these files have to be writeable.
#
# usage:
# - just run the script.
#
# configuration:
# - the script uses the active "username" field for the connect.
#   you can alter it global via "/set user_name" 
#   or per ircnet with "/ircnet add -user ident somenet"
#
# how it works:
# on connect it writes ~/.ispoof and ~/.oidentd.conf
# you CAN have RACE CONDITIONS HERE. 
# so delay your connects a bit.
#

use vars qw ( $VERSION %IRSSI );

$VERSION = "0.0.2";
%IRSSI = (
    authors     => 'darix',
    contact     => 'darix@irssi.org',
    name        => 'oidenty',
    description => 'oidentd support for irssi',
    license     => 'BSD License',
    url         => 'http://www.irssi.de'
);
#
use strict;
use warnings;

use Irssi qw ( signal_add  );
use IO::File;

signal_add 'server looking' => sub {
    my ( $server ) = @_;

    my $fh = new IO::File "$ENV{'HOME'}/.ispoof", "w";
    if ( $fh ) {
        $fh->print ( "$server->{'username'}" );
        undef $fh;
    }
    else {
        print ( CRAP "cant open $ENV{'HOME'}/.ispoof for writing. $!" );
    }

    $fh = new IO::File "$ENV{'HOME'}/.oidentd.conf", "w";
    if ( $fh ) {
        $fh->print ( "global { reply \"$server->{'username'}\" }" );
        undef $fh;
    }
    else {
        print ( CRAP "cant open $ENV{'HOME'}/.oidentd.conf for writing. $!" );
    }

};

print (CRAP "loaded $IRSSI{'name'} v$VERSION by $IRSSI{'authors'} <$IRSSI{'contact'}>. use it at \cBYOUR OWN RISK\cB");
print (CRAP "$IRSSI{'description'}");
