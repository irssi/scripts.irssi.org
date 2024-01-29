use Irssi;
use strict;
use warnings;

our $VERSION = "1.0.0";
our %IRSSI = (
    authors     => 'terminaldweller',
    contact     => 'https://terminaldweller.com',
    name        => 'server_status',
    description => 'gives you the count of connected and unconnected servers as an expando',
    license     => 'GPL3 or newer',
    url         => 'https://github.com/irssi/scripts.irssi.org',
);

my $server_status_count = "";
my $timeout;

Irssi::settings_add_int('misc', 'server_status_count_freq', 100000);

sub server_status {
    Irssi::timeout_remove($timeout);
    my $connected_count = 0;
    my $unconnected_count = 0;

    for my $server (Irssi::servers()) {
        if ($server->{'connected'}) {
            $connected_count++;
        } else {
            $unconnected_count++;
        }
    }

    $server_status_count = $connected_count."/".$unconnected_count;

    $timeout = Irssi::timeout_add_once(Irssi::settings_get_int('server_status_count_freq'), 'server_status' , undef);
}

Irssi::expando_create('server_status_count', sub {
  return $server_status_count;
}, {});

$timeout = Irssi::timeout_add(Irssi::settings_get_int('server_status_count_freq'), 'server_status' , undef);
server_status();
