use Irssi;
use strict;
use warnings;

# feature nobody asked for in 25 years except Chex who thinks this should be a core feature
our $VERSION = "1.0.0";
our %IRSSI = (
    authors     => 'terminaldweller',
    contact     => 'https://terminaldweller.com',
    name        => 'dont_reconnect',
    description => 'runs rmreconn after servers in the list disconnect',
    license     => 'GPL3 or newer',
    url         => 'https://github.com/irssi/scripts.irssi.org',
);

# dont_reconnect_list = "server1 server2 server3"
Irssi::settings_add_str('misc', 'dont_reconnect_list', '');

sub run_rm_reconn {
    my $server_rec = @_;
    my $recon_list = Irssi::settings_get_str('dont_reconnect_list');
    my @list = split(/ /, $recon_list);

    my $current_server_name = Irssi::server_name($server_rec);

    foreach my $server_name (@list) {
        if ($server_name eq $current_server_name) {
            Irssi::command("rmreconn");
            return;
        }
    }
}

Irssi::signal_add('server disconnect', 'run_rm_reconn');
