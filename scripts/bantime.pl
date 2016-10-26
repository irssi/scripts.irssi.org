use strict;
use Irssi; # developed using irssi 0.8.9.CVS
use Time::Duration; # calculates the ban duration.  
# either of the following should install the module
# perl -MCPAN -e 'install Time::Duration' 
# cpan -i Time::Duration
# apt-get install libtime-duration-perl

# I recommend rebinding irssi's default /BANS from 'ban' to 'bantimes' (/alias BANS BANTIME)

use vars qw($VERSION %IRSSI);
$VERSION = "0.5";
%IRSSI = (
        authors         => "David O\'Rourke",
        contact         => "phyber\@\#irssi",
        name            => "bantime",
        description     => "Print time when ban was set in a nicer way. eg. 23 mins, 40 secs ago.",
        license         => "GPLv2",
	changed		=> "08.01.2004 02:46"
);

sub cmd_bans {
	my ($args, $server, $witem) = @_;
	return if not ($witem && $witem->{type} eq "CHANNEL");
	my $currenttime = time;
	my $channel = $witem->{name};
	my $count = 1;
	foreach my $ban ($witem->bans()) {
		my ($bansetby, $bantime);
		if ($ban->{setby}) {
			$bansetby = $ban->{setby};
		} 
		else { $bansetby = "*Unavailable"; }
		
		if ($ban->{time}) {
			$bantime = duration_exact($currenttime - $ban->{time}) . " ago";
		} 
		else { $bantime = "*Unavailable"; }
		
		$witem->printformat(MSGLEVEL_CLIENTCRAP, 'bantime_long',  $count, $channel, $ban->{ban}, $bansetby, $bantime);
		$count += 1;
	}
}

Irssi::theme_register(['bantime_long', '{line_start}$0 - {channel $1}: ban {ban $2} {comment by {nick $3}, $4}']);
Irssi::command_bind('bantime', 'cmd_bans');
Irssi::print("Loaded $IRSSI{name} $VERSION");

#############
# ChangeLog #
#############
# 08.01.2004: Jan 08 2004: 02:46
# Fixed a bug which occured if the IRCd didn't tell us who set the bans at which time. eg. IRCNet if a user doesn't have +o.
# 08.01.2004: Jan 08 2004: 01:52
# Initial Release.  Many thanks to coekie for helping me with my scripting.
