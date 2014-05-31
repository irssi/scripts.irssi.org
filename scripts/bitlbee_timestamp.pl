use strict;
use Data::Dumper;
use vars qw($VERSION %IRSSI);
use DateTime;

$VERSION = '0.5';
%IRSSI = (
    authors	=> 'Tijmen "timing" Ruizendaal',
    contact	=> 'tijmen.ruizendaal@gmail.com',
    name	=> 'bitlbee_timestamp',
    description	=> 'Replace Irssi\'s timestamps with those sent by BitlBee',
    license	=> 'GPLv2',
    url		=> 'http://the-timing.nl/stuff/irssi-bitlbee',
    changed	=> '2010-05-01',
);

my $tf = Irssi::settings_get_str('timestamp_format');

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

my $prev_date = '';

sub privmsg {
	my ($server, $data, $nick, $address) = @_;

	# What we need to match: ^B[^B^B^B2010-03-21 16:33:41^B]^B

	if( $server->{tag} eq $bitlbee_server->{tag} ){
	
		my ($target, $text) = split(/ :/, $data, 2);

		#if( $text =~ /^B[^B^B^B[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}^B]^B/ ){

		if( $text =~ /\x02\[\x02\x02\x02.*\x02\]\x02/ ){
			my $window;
			my $timestamp = $text;
			my $time;
			my $date;
			$timestamp =~ s/.*\x02\[\x02\x02\x02(.*?)\x02\]\x02.*/$1/g;
			$text =~ s/\x02\[\x02\x02\x02(.*?)\x02\]\x02 //g;

			($date, $time) = split(/ /, $timestamp);
			if( !$time ){ # the timestamp doesn't have a date
				$time = $date;
				# use today as date
				$date = DateTime->now->ymd;
			}

			if( $date ne $prev_date ){
				if( $target =~ /#|&/ ){ # find channel window based on target
					$window = Irssi::window_find_item($target);
				} else { # find query window based on nick
					$window = Irssi::window_find_item($nick);
				}
				if( $window != undef ){
					my($year, $month, $day) = split(/-/, $date);
					my $dt = DateTime->new(year => $year, month => $month, day => $day);
					my $formatted_date = $day.' '.$dt->month_abbr.' '.$year;
					
					$window->print('Day changed to '.$formatted_date, MSGLEVEL_NEVER);
				}
			}
			$prev_date = $date;
			
			Irssi::settings_set_str('timestamp_format', $time);
			Irssi::signal_continue($server, $target . ' :' . $text, $nick, $address);
			my $escaped = $tf;
			$escaped =~ s/%/%%/g;
			Irssi::settings_set_str('timestamp_format', $tf);
		}
	}
}

Irssi::signal_add('event privmsg', 'privmsg');
