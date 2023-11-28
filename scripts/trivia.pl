use Irssi;
use strict;

our $VERSION = "1.0.0";
our %IRSSI = (
    authors     => 'terminaldweller',
    contact     => 'https://terminaldweller.com',
    name        => 'trivia',
    description => 'lets you add trivial info for a window as a expando',
    license     => 'GPL3 or newer',
    url         => 'https://github.com/irssi/scripts.irssi.org',
);

my %trivia_list = ();
my $trivia = "";

sub window_changed_handler {
    my $window = Irssi::active_win();
    my $server = Irssi::active_server();
    my $current_window_item_string = $server->{tag}."/".$window->{active}->{name};

    if ($window && $window->{active}->{name} eq "") {
        $trivia = "Irssi";
        return;
    }

    foreach my $key (keys %trivia_list) {
        if ($current_window_item_string =~ m/$key/) {
            $trivia = $trivia_list{$key};
            return;
        }
    }

    $trivia = "IRC";
}

Irssi::expando_create('trivia', sub {
  return $trivia;
}, {});

sub setup_changed {
    %trivia_list = map { my @temp = split(',', $_); $temp[0] => $temp[1] } split(' ', Irssi::settings_get_str('trivia_list'));
}

# Settings
# /set trivia_list server1/#channel,info server2/#channel2,info2
Irssi::settings_add_str('misc','trivia_list','');

Irssi::signal_add('window changed' => 'window_changed_handler');
Irssi::signal_add('setup changed' => 'setup_changed');

%trivia_list = map { my @temp = split(',', $_); $temp[0] => $temp[1] } split(' ', Irssi::settings_get_str('trivia_list'));
Irssi::print(%trivia_list);
