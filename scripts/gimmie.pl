use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
    authors => 'PrincessLeia2',
    contact => 'lyz\@princessleia.com ',
    name => 'gimmie',
    description => 'a bot script, using ! followed by anything the script will say (as an action): gets nickname anything',
    license => 'GNU GPL v2 or later',
    url => 'http://www.princessleia.com/'
);

sub event_privmsg {
my ($server, $data, $nick, $mask, $target) =@_;
my ($target, $text) = $data =~ /^(\S*)\s:(.*)/;
     return if ( $text !~ /^!/i );
        if ( $text =~ /^!coffee$/i ) {
        	$server->command ( "action $target hands $nick a steaming cup of coffee" );
	}
        elsif ($text =~ /^!chimay$/i ) {
        	$server->command ( "action $target hands $nick a glass of Chimay" );
	}
        elsif ($text =~ /^!pepsi$/i ) {
        	$server->command ( "action $target gives $nick a can of Star Wars Pepsi" );
	}
        elsif ($text =~ /^!ice cream$/i ) {
        	$server->command ( "action $target gives $nick a chocolate ice cream with lots of cherries" );
	}
        elsif ($text =~ /^!$nick$/i ) {
        	$server->command ( "msg $target get yourself?" );
	}
        else {
        	my ($gimmie) = $text =~ /!(.*)/;
        	$server->command ( "action $target Gets $nick $gimmie \0032<\%)");
	}
}
Irssi::signal_add('event privmsg', 'event_privmsg');
