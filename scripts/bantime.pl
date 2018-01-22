use strict;
use Irssi; # developed using irssi 0.8.9.CVS

# I recommend rebinding irssi's default 'BAN' to 'bantimes' (/alias BAN BANTIME)

use vars qw($VERSION %IRSSI);
$VERSION = '1.03';
%IRSSI = (
	authors		=> "David O\'Rourke",
	contact		=> "phyber [at] #irssi",
	name		=> "bantime",
	description	=> "Print time when ban was set in a nicer way. eg. 23m, 40s ago.",
	license		=> "GPLv2",
	changed		=> "02/03/2009",
);

sub duration {
	my ($when) = @_;

	my $diff = (time - $when);
	my $day = int($diff / 86400); $diff -= ($day * 86400);
	my $hrs = int($diff / 3600); $diff -= ($hrs * 3600);
	my $min = int($diff / 60); $diff -= ($min * 60);
	my $sec = $diff;

	my $str;
	$str .= "${day}d " if $day;
	$str .= "${hrs}h " if $day or $hrs;
	$str .= "${min}m " if $day or $hrs or $min;
	$str .= "${sec}s"; # seconds should always be shown

	return $str;
}

sub cmd_bans {
	my ($args, $server, $witem) = @_;
	return if not ($witem && $witem->{type} eq "CHANNEL");
	my $channel = $witem->{name};

	if (!$witem->bans()) {
		$witem->printformat(
			MSGLEVEL_CLIENTCRAP,
			'bantime_nobans',
			$channel);
		return;
	}

	my $count = 1;
	foreach my $ban ($witem->bans()) {
		if (!$ban->{setby} || !$ban->{time}) {
			$witem->printformat(
				MSGLEVEL_CLIENTCRAP,
				'bantime',
				$count,
				$channel,
				$ban->{ban});
		}
		else {
			my $bantime;
			if (Irssi::settings_get_bool('bantime_show_date')) {
				$bantime = localtime($ban->{time}) . ": ";
				$bantime =~ s/\s+/ /g;
			}
			$bantime .= duration($ban->{time});
			$witem->printformat(
				MSGLEVEL_CLIENTCRAP,
				'bantime_long',
				$count,
				$channel,
				$ban->{ban},
				$ban->{setby},
				$bantime);
		}
		$count++;
	}
}

Irssi::theme_register([
	'bantime', '{line_start}$0 - {channel $1}: ban {ban $2}',
	'bantime_long', '{line_start}$0 - {channel $1}: ban {ban $2} {comment by {nick $3}, $4 ago}',
	'bantime_nobans', '{line_start}{hilight Irssi:} No bans in channel {channel $0}'
]);
Irssi::command_bind('bantime', 'cmd_bans');
Irssi::print("Loaded $IRSSI{name} $VERSION");
Irssi::settings_add_bool('bantime', 'bantime_show_date' => 0);

#############
# ChangeLog #
#############
# 02.03.2009: 1.03
# Minor cosmetic changes to the script.
# 28.02.2007: 1.03
# duration() now returns a nicer string.  Fields arn't visible if they're zero.
# Random bits cleaned up.
# 28.04.2005: 1.01
# Removed redundant '$bantime2' variable, left over from a setting that was removed earlier.
# 19.03.2005: 1.0
# Removed dependancy on Time::Duration by using duration().
# Removed obsolete 'bantime_short_format' setting.
# Increased version to 1.0
# 11.01.2004: Jan 11 2004: 04:30
# Added new bantime_show_date setting. Displays the date the ban was set along with the time info.
# 11.01.2004: Jan 11 2004: 04:05
# Added new bantime_short_format setting. Displays the time in a nice short format. (#irssi: ban *!*@test.testing [by phyber, 3d 5h 54m 59s ago])
# 11.01.2004: Jan 11 2004: 03:49
# Changed handling bans without setby/time information closer to how irssi does.
# 08.01.2004: Jan 08 2004: 02:46
# Fixed a bug which occured if the IRCd didn't tell us who set the bans at which time. eg. IRCNet if a user doesn't have +o.
# 08.01.2004: Jan 08 2004: 01:52
# Initial Release.  Many thanks to coekie for helping me with my scripting.
