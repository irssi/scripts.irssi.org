use Irssi;
use LWP::UserAgent;
use Irssi::TextUI;
use strict;

our $VERSION = "0.1";
our %IRSSI = (
    authors     => 'terminaldweller',
    contact     => 'https://terminaldweller.com',
    name        => 'whereami',
    description => 'adds a statusbar item that displays your current IP address',
    license     => 'GPL3 or newer',
    url         => 'https://github.com/irssi/scripts.irssi.org',
);

# adds the statusbar item whereami which displays the IP address being used
# /set whereami_frequency sets how often we make the IP query in miliseconds
# /set whereami_url the url of the service that gives us our IP
# please note that the default url is being provided by cloudflare
# the script also provides a expando called whereami
Irssi::settings_add_int('misc', 'whereami_frequency', 300000);
Irssi::settings_add_str('misc', 'whereami_url', 'https://icanhazip.com');
my $whereami_ip = '0.0.0.0';
my $timeout;

sub whereami {
    my $ua = LWP::UserAgent->new;
    Irssi::timeout_remove($timeout);
    my $server_endpoint = Irssi::settings_get_str('whereami_url');
    my $req = HTTP::Request->new(GET => $server_endpoint);
    my $resp = $ua->request($req);
    if ($resp->is_success) {
        $whereami_ip = $resp->decoded_content;
        $whereami_ip =~ s/[^[:print:]]//g;
    }
    else {
        Irssi::print("HTTP GET error code: ".$resp->code);
        Irssi::print("HTTP GET error message: ".$resp->message);
    }
    $timeout = Irssi::timeout_add_once(Irssi::settings_get_int('whereami_frequency'), 'whereami' , undef);
}

sub whereamiStatusbar {
  my ($item, $get_size_only) = @_;

  $item->default_handler($get_size_only, "{sb ".$whereami_ip."}", undef, 1);
}

Irssi::expando_create('whereami', sub {
  return $whereami_ip;
}, {});

Irssi::command_bind('whereami', \&whereami);
Irssi::statusbar_item_register('whereami', '{sb $0-}', 'whereamiStatusbar');
$timeout = Irssi::timeout_add(Irssi::settings_get_int('whereami_frequency'), 'whereami' , undef);
whereami();
