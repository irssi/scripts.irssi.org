use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '0.02';
%IRSSI = (
    authors     => 'Juerd',
    contact	=> '#####@juerd.nl',
    name        => 'autostuff',
    description	=> 'Save current servers, channels and windows for autoconnect and autojoin',
    license	=> 'Public Domain',
    url		=> 'http://juerd.nl/site.plp/irssi',
    changed	=> '2010-03-24 14:35',
);

use Irssi qw(command_bind servers channels windows command);

command_bind autostuff => sub {
    my ($data, $server, $window) = @_;
    for (servers) {
        my $chatnet = $_->{chatnet} || $_->{tag};
        command "/network add $chatnet";
        command "/server add -auto -network $chatnet $_->{address} $_->{port} $_->{password}";
    }
    for (channels) {
        my $chatnet = $_->{server}->{chatnet} || $_->{server}->{tag};
        command "/channel add -auto $_->{name} $chatnet $_->{key}";
    }
    command "/layout save";
    command "/save";
};

command_bind "window clean" => sub {
    for (sort { $b->{refnum} <=> $a->{refnum} } windows) {
        next if $_->{active};
        next if $_->{immortal};
        next if $_->{name};
        command "/window close $_->{refnum}";
    }
};
