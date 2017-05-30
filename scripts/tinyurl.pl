#
# by Atoms

use strict;
use WWW::Shorten::TinyURL;
use WWW::Shorten 'TinyURL';

use vars qw($VERSION %IRSSI);

use Irssi qw(command_bind active_win);
$VERSION = '1.1';
%IRSSI = (
    authors	=> 'Atoms',
    contact	=> 'atoms@tups.lv',
    patch   => 'spowers@dimins.com',
    name	=> 'tinyurl',
    description	=> 'create a tinyurl from a long one',
    license	=> 'GPL',
);

command_bind(
    tinyurl => sub {
        my ($msg, $server, $witem) = @_;
        my $answer = tinyurl($msg);
        
        if ($answer) {
            print CLIENTCRAP "$answer";

            if ($witem && ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY')) {
  	            $witem->command("MSG " . $witem->{name} ." ". $answer);
            }
        }
    }
);

sub tinyurl {
    my $url = shift;

    my $res = makeashorterlink($url);

    if (defined $res) {
        return $res;
    } else {
        print CLIENTCRAP "ERROR: tinyurl: tinyurl is down or not pingable";
        return "";
    }
}
