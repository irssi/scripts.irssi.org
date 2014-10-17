# CHANGELOG:
#
# 2010-08-10 (version 1.3)
# * new bitlbee server detection
#
# 2004-11-28:
# * adds join message to query
#
# /statusbar window add join_notice
# use Data::Dumper;

use strict;
use Irssi::TextUI;
#use Irssi::Themes;
use Data::Dumper;

use vars qw($VERSION %IRSSI);

$VERSION = '1.3';
%IRSSI = (
	authors		=> 'Tijmen "timing" Ruizendaal',
	contact		=> 'tijmen.ruizendaal@gmail.com',
	name		=> 'BitlBee_join_notice',
	description 	=> '1. Adds an item to the status bar wich shows [joined: <nicks>] when someone is joining &bitlbee. 2. Shows join messages in the query. (For bitlbee v3.0+)',
	license 	=> 'GPLv2',
	url		=> 'http://the-timing.nl/stuff/irssi-bitlbee',
	changed 	=> '2010-08-10'
);
my %timers;
my $bitlbee_server; # server object
my @control_channels; # mostly: &bitlbee, &facebook etc.
init();

sub init { # if script is loaded after connect
	my @servers = Irssi::servers();
	foreach my $server(@servers) {
		if( $server->isupport('NETWORK') eq 'BitlBee' ){
			$bitlbee_server = $server;
			my @channels = $server->channels();
			foreach my $channel(@channels) {
				if( $channel->{mode} =~ /C/ ){
					push @control_channels, $channel->{name} unless (grep $_ eq $channel->{name}, @control_channels);
				}
			}
		}
	}
}
# if connect after script is loaded
Irssi::signal_add_last('event 005' => sub {
	my( $server ) = @_;
	if( $server->isupport('NETWORK') eq 'BitlBee' ){
		$bitlbee_server = $server;
	}
});
# if new control channel is synced after script is loaded
Irssi::signal_add_last('channel sync' => sub {
	my( $channel ) = @_;
	if( $channel->{mode} =~ /C/ && $channel->{server}->{tag} eq $bitlbee_server->{tag} ){
		push @control_channels, $channel->{name} unless (grep $_ eq $channel->{name}, @control_channels);
	}
});

# BEGIN bitlbee_join_notice.pl

my %online;

sub event_join {
	my ($server, $channel, $nick, $address) = @_;
	$channel =~ s/^://g;
	if ( (grep $_ eq $channel, @control_channels) && $server->{tag} eq $bitlbee_server->{tag}){
		$online{$nick} = 1;
		Irssi::timeout_remove($timers{$nick});
		delete($timers{$nick});
		$timers{$nick} = Irssi::timeout_add_once(7000, 'empty', $nick);
		Irssi::statusbar_items_redraw('join_notice');
		my $window = Irssi::window_find_item($nick);
		if($window){
			$window->printformat(Irssi::MSGLEVEL_JOINS, 'join', $nick, $address, $channel); 
		}
	}
}
sub join_notice {
	my ($item, $get_size_only) = @_; 
	my $line;
	foreach my $key (keys(%online) ){
		$line = $line." ".$key;
	}
	if ($line ne "" ){
		$item->default_handler($get_size_only, "{sb joined:$line}", undef, 1);
		$line = "";
	} else {
		$item->default_handler($get_size_only, "", undef, 1);
	} 
}
sub empty {
	my $nick = shift;
	delete($online{$nick});
	Irssi::timeout_remove($timers{$nick});
	delete($timers{$nick});
	Irssi::statusbar_items_redraw('join_notice');
}

Irssi::signal_add('event join', 'event_join' );
Irssi::statusbar_item_register('join_notice', undef, 'join_notice');
Irssi::statusbars_recreate_items();
Irssi::theme_register([	'join', '{channick_hilight $0} {chanhost $1} has joined {channel $2}', ]);

# END bitlbee_join_notice.pl
