use strict;
use Irssi 20020300;
use Irssi::Irc;

# /SET aidle_max_idle_time <seconds>
# - specifies max possible idle time
# /SET aidle_ircnets IRCNet EFnet
# - specifies IRCNets where anty idler will be on
# SET -clear aidle_ircnets makes aidle work on every network;
# /SET aidle_only_when_away - makes aidler work only when you're away
 
use vars qw($VERSION %IRSSI); 
$VERSION = "1.1b";
%IRSSI = (
	authors 	=> "Maciek \'fahren\' Freudenheim",
	contact 	=> "fahren\@bochnia.pl", 
	name 		=> "Antyidler",
	description 	=> "Antyidler with random time",
	license 	=> "GNU GPLv2 or later",
	changed		=> "Thu Jan  2 02:58:34 CET 2003"
);

# Changelog:
# 1.1b
# - removed "hoho, <chatnet>" message :)
# 1.1
# - added /set'tings
# 1.0
# - fixed that annoying "your_nick: is away blah blah" message

my %aidle;

Irssi::settings_add_int 'aidle', 'aidle_max_idle_time', '180';
$aidle{'max'} = Irssi::settings_get_int 'aidle_max_idle_time';

Irssi::settings_add_str 'aidle', 'aidle_ircnets', '';
@{$aidle{'ircnets'}} = (split(/ +/, Irssi::settings_get_str('aidle_ircnets')));

Irssi::settings_add_bool 'aidle', 'aidle_only_when_away', 0;
$aidle{'away'} = Irssi::settings_get_bool 'aidle_only_when_away';

$aidle{'timer'} = Irssi::timeout_add $aidle{'max'} * 1000, 'antyidlesend', '';

sub antyidlesend {
	for my $server (Irssi::servers()) {
		next if (not $server->{'connected'} or ($aidle{'away'} and not $server->{'usermode_away'})
			 or (@{$aidle{'ircnets'}} and not grep {lc $server->{'chatnet'} eq lc $_} @{$aidle{'ircnets'}}));
		$server->send_raw("PRIVMSG " . $server->{nick} . " IDLE");
		Irssi::timeout_remove $aidle{'timer'};
		$aidle{'timer'} = Irssi::timeout_add int(rand($aidle{'max'})+1) * 1000, 'antyidlesend', '';
	}
}

Irssi::signal_add 'setup changed' => sub {
	$aidle{'away'} = Irssi::settings_get_bool 'aidle_only_when_away';
	my $max_idle_time = Irssi::settings_get_int 'aidle_max_idle_time';
	if ($max_idle_time < $aidle{'max'}) {
		Irssi::timeout_remove $aidle{'timer'};
		$aidle{'timer'} = Irssi::timeout_add int(rand($max_idle_time)+1) * 1000, 'antyidlesend', '';
	}
	$aidle{'max'} = $max_idle_time;
	@{$aidle{'ircnets'}} = (split(/[\s,|-]+/, Irssi::settings_get_str('aidle_ircnets')));
	foreach my $ircnet (@{$aidle{'ircnets'}}) {
		Irssi::print("%RWarning%n - no such chatnet \'$ircnet\' !", MSGLEVEL_CLIENTERROR) unless (Irssi::chatnet_find($ircnet));
	}
}; 

Irssi::signal_add "event 301" => sub {
	my ($server, $data) = @_;

	my ($fnick, $snick, undef) = split(' ', $data);

	Irssi::signal_stop() if $fnick eq $snick;
};

Irssi::signal_add "default ctcp msg" => sub {
	my ($server, $data, $sender, $addr, $target) = @_;

	Irssi::signal_stop() if ($sender eq $target && $data eq "IDLE");
};
