#
# This script will change your nickname if in given time (/SET collision_time [seconds])
# there are more than specific number of collisions (/SET collision_count [number]) on
# single channel. After change next nick collisions are ignored for given time
# (/SET collsion_ignore [seconds]).
# Settings:
#		/SET collision_avoid [On/Off] (default is on, if off - action disabled)
#		/SET collision_count [number]
#		/SET collision_time [seconds]
#		/SET collision_ignore [seconds]
#		/SET collision_baselen [0-6]

use strict;
use Irssi;
use Irssi::Irc;

use vars qw($VERSION %IRSSI);
$VERSION = "0.2.3";
%IRSSI = (
	'authors'		=> 'Marcin Rozycki',
	'contact'		=> 'derwan@irssi.pl',
	'name'			=> 'nocollide',
	'description'		=> 'Automatically changes nick (to randnick or uid on ircd 2.11) when certain amount of nick colissions'.
	                           'takes place on channel',
	'url'			=> 'http://derwan.irssi.pl',
	'license'		=> 'GNU GPL v2',
	'changed'		=> 'Mon Feb 16 10:08:59 CET 2004',
);

my $default_time = 5;
my $default_count = 2;
my $default_ignore = 10;
my $default_baselen = 5;

Irssi::settings_add_bool('misc', 'collision_avoid', 1);
Irssi::settings_add_int('misc', 'collision_time', $default_time);
Irssi::settings_add_int('misc', 'collision_count', $default_count);
Irssi::settings_add_int('misc', 'collision_ignore', $default_ignore);
Irssi::settings_add_int('misc', 'collision_baselen', $default_baselen);

my %collision = ();
my %collision_changed = ();

sub sig_message_quit {
	my ($server, $nick, $null, $quit_msg) = @_;

	# based on cras'es kills.pl
	return if ($quit_msg !~ /^Killed \(([^ ]*) \((.*)\)\)$/ or !$server or !$server->{connected} or
			!$nick or !Irssi::settings_get_bool('collision_avoid'));

	my $time = time(); my $tag = lc($server->{tag}); my $change = 0;

	my $check_time = Irssi::settings_get_int('collision_time');
	$check_time = $default_time if (!$check_time or $check_time !~ /^\d+$/);

	my $check_count = Irssi::settings_get_int('collision_count');
	$check_count = $default_count if (!$check_count or $check_count !~ /^\d+$/);
	$check_count = 10 if (--$check_count > 10);

	my $ignore = Irssi::settings_get_int('collision_ignore');
	$ignore = $default_ignore if (!$ignore or $ignore !~ /^\d+$/);

	my $version = $server->{version};
	$version = 0 unless ( defined $version );
	
	my @list = $server->nicks_get_same($nick);
	while (my $channel = shift(@list)) {
		shift(@list);

		my $chan = lc($channel->{name});
		unshift @{$collision{$tag}{$chan}}, $time; $#{$collision{$tag}{$chan}} = 10;
		next if ( $server->{nick} =~ m/^\d/ );
		
		next unless ($check_count > 0 and $check_time > 0);

		my $test = $collision{$tag}{$chan}[$check_count];
		if ($test and $test >= ($time - $check_time)) {
			my $last = $collision_changed{$tag};
			next if ($last and ($time - $last) < $ignore);
			
			$collision_changed{$tag} = $time;
			delete $collision{$tag}{$chan};
			next if ($change++);

			if ( $version =~ m/^2.11/ ) {
				$channel->print("%RNick collision alert%n in %_".$channel->{name}."%_ \(rate ".($check_count + 1)."\:$check_time\). Changing nick to %_uid%_!", MSGLEVEL_CLIENTCRAP);
				$server->send_raw('NICK 0');
				next;
			}
			
			my $len = Irssi::settings_get_int('collision_baselen');
			$len = 6 if ($len > 6);
			my $nick = randnick(substr($server->{nick}, 0, $len));
			$channel->print("%RNick collision alert%n in %_".$channel->{name}."%_ \(rate ".($check_count + 1)."\:$check_time\). Changing nick to \'%_$nick%_\'", MSGLEVEL_CLIENTCRAP);
			$server->command("NICK $nick");
		}
	}
}

# str randnick($prefix, $nicklen);
# returns random nickname
sub randnick {
	my ($base, $length) = @_;
	$length = 9 if (!$length or $length !~ /^\d+$/);

	# based on fahren's void.scr for LiCe
	my $chars = 'aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ_-0123456789';
	my $cchars = (length($base)) ? 64 : 53;

	while (length($base) < $length)
	{
		$base .= substr($chars, int(rand($cchars)), 1);
		$cchars = 64 if ($cchars == 53);
	}
	return $base;
}

Irssi::signal_add_first('message quit', 'sig_message_quit');
