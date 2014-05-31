use Irssi;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '0.0.7';
%IRSSI = (
	authors     => 'Wouter Coekaerts, Koenraad Heijlen',
	contact     => 'vipie@ulyssis.org, wouter@coekaerts.be',
	name        => 'away_verbose',
	description => 'A verbose away script, displays a verbose away/back message in the channels you are in. BUT it can limit the channels (not spamming every channel!)',
	license     => 'GNU GPL version 2',
	url         => 'http://vipie.studentenweb.org/dev/irssi/',
	changed     => '2004-01-01'
);

#--------------------------------------------------------------------
# Changelog
#--------------------------------------------------------------------
#
# away_verbose.pl 0.7 (2004-01-01)
# * Wouter Coekaerts
# 	- don't hard code the command char
# 
# away_verbose.pl 0.5 (2002-11-17)
# * James Seward 
# 	- make regex case insensitive
# 
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# Public Variables
#--------------------------------------------------------------------
my $away_time_texts = "wk,wks,day,days,hr,hrs,min,mins,sec,secs";
my ($away_set, $away_time, $away_reason, $away_silent)=(0,0,"",0);
my %myHELP = ();


#--------------------------------------------------------------------
# Help function
#--------------------------------------------------------------------
sub cmd_help { 
	my ($about) = @_;

	%myHELP = (
		back => "
BACK 

Away is unset, the time you were away is displayed in the channel with the reason.

like this: /me away_back_text_part1 <reason> away_back_text_part2 TIME

Currently it will display:  
/me " . Irssi::settings_get_str('away_back_text_part1') . " Some Reason " . Irssi::settings_get_str('away_back_text_part2') . " " . &secs2text(10000) . "

You can change this by changing the settings (with /set setting_name):

* away_back_text_part1     (default: is back from)
* away_back_text_part2     (default: after)
* away_time_texts          (default: wk,wks,day,days,hr,hrs,min,mins,sec,secs)

",

		gone => "
GONE <your away reason> 

Sets you away with the given reason, and displays it publically on the allowed channels.

like this: /me away_gone_text <reason>

Currently it will display:
/me " . Irssi::settings_get_str('away_gone_text') . " Some Reason 

You can change this by changing the settings (with /set setting_name):

* away_gone_text     (default: is gone:)


How do I decide on which channels they away message is displayed?
-----------------------------------------------------------------

You set 2 settings:  away_order_channels, away_allow_channels.

away_order_channels = [allow|exclude] 
     Should the channels be allowed or excluded using a regular expression. (exclude = all but the matching channels).

away_allow_channels = <regular expression>
     The regular expression limiting the channels (eg 'linux|home' without the '').
",

		awe => "
AWE [<your away reason>]

When a reason is given, it acts as GONE
When no reason is supplied it acts as BACK.

SEE ALSO: HELP BACK, HELP GONE
",

);

	if ( $about =~ /(back|gone|awe)/i ) { 
		Irssi::print($myHELP{$1});
	} 
}


#--------------------------------------------------------------------
# Translate the number of seconds to a human readable format.
#--------------------------------------------------------------------
sub secs2text {
	$away_time_texts = Irssi::settings_get_str('away_time_texts');
	my ($secs) = @_;
	my ($wk_,$wks_,$day_,$days_,$hr_,$hrs_,$min_,$mins_,$sec_,$secs_) = (0,1,2,3,4,5,6,7,8,9,10);
	my @texts = split(/,/,$away_time_texts);
	my $mins=int($secs/60); $secs -= ($mins*60);
	my $hrs=int($mins/60); $mins -= ($hrs*60);
	my $days=int($hrs/24); $hrs -= ($days*24);
	my $wks=int($days/7); $days -= ($wks*7);
	my $text = (($wks>0) ? (($wks>1) ? "$wks $texts[$wks_] " : "$wks $texts[$wk_] ")  : "" ); 
	$text .= (($days>0) ? (($days>1) ? "$days $texts[$days_] " : "$days $texts[$day_] ")  : "" );
	$text .= (($hrs>0) ? (($hrs>1) ? "$hrs $texts[$hrs_] " : "$hrs $texts[$hr_] ")  : "" );
	$text .= (($mins>0) ? (($mins>1) ? "$mins $texts[$mins_] " : "$mins $texts[$min_] ")  : "" );
	$text .= (($secs>0) ? (($secs>1) ? "$secs $texts[$secs_] " : "$secs $texts[$sec_] ")  : "" );
	$text =~ s/ $//;
	return $text;
}

#--------------------------------------------------------------------
# Output the public away on all permitted channels.
#--------------------------------------------------------------------
sub away_describe_pub_channels {
	my $away_allow_channels=Irssi::settings_get_str('away_allow_channels');
	my $away_order_channels=Irssi::settings_get_str('away_order_channels');
	my ($server,$text) = @_;
	foreach my $server (Irssi::servers) {
		foreach my $chan ($server->channels) {
		
			if ((($server->{chatnet} .":". $chan->{name}) =~ /$away_allow_channels/i) != ($away_order_channels eq "exclude")) {
				$server->command("DESCRIBE $chan->{name} $text");
			}
		}
	}
}

#--------------------------------------------------------------------
# Set the away reason, and call the function to do the announce.
#--------------------------------------------------------------------
sub away_setaway {
	my ($server, $reason)=@_;
	
	my $away_gone_text=Irssi::settings_get_str('away_gone_text');

	$server->command("AWAY " . $reason);
	away_describe_pub_channels($server,"$away_gone_text $reason");
	$away_time=time;
	$away_reason=$reason;
	$away_set=1;
}

#--------------------------------------------------------------------
# Remove the away reason, and call the function to do the announce.
#--------------------------------------------------------------------
sub away_back {
	my($server)=@_;
	
	my $away_back_text_part1=Irssi::settings_get_str('away_back_text_part1');
	my $away_back_text_part2=Irssi::settings_get_str('away_back_text_part2');

	if ( $away_set ) {
		$server->command("AWAY");
		away_describe_pub_channels($server,"$away_back_text_part1 $away_reason $away_back_text_part2 " . secs2text(time - $away_time));
		$away_time=0;
		$away_reason="";
		$away_set=0;

	} else {
		Irssi::print("Don't use back if you are not away! OXYMORON");
		Irssi::print("(ed. note) OXYMORON: a combination of contradictory or incongruous words (as cruel kindness)");
		return;
	}
}

#--------------------------------------------------------------------
# Defintion of /gone, /back and /awe
#--------------------------------------------------------------------
sub gone {
	my ($args, $server, $item) = @_;
	away_setaway($server,$args);
}

sub back {
	my ($args, $server, $item) = @_;
	away_back($server);
}

sub cmd_away {
	my ($args, $server, $item) = @_;
	
	if ( $args ) {
		away_setaway($server,$args);
	} else  {
		away_back($server);
	}
}


#--------------------------------------------------------------------
# Irssi::Settings / Irssi::command_bind
#--------------------------------------------------------------------

Irssi::settings_add_str('away', 'away_allow_channels', "^\$");
Irssi::settings_add_str('away', 'away_order_channels', "exclude");
Irssi::settings_add_str('away', 'away_time_texts', $away_time_texts);

Irssi::settings_add_str('away', 'away_gone_text', "is gone:");
Irssi::settings_add_str('away', 'away_back_text_part1', "is back from");
Irssi::settings_add_str('away', 'away_back_text_part2', "after");

Irssi::command_bind("gone", "gone", "Advanced Away");
Irssi::command_bind("back", "back", "Advanced Away");
Irssi::command_bind("awe","cmd_away", "Advanced Away");

Irssi::command_bind("help","cmd_help", "Irssi commands");

#--------------------------------------------------------------------
# This text is printed at Load time.
#--------------------------------------------------------------------

Irssi::print("Use /back, /gone <reason>, or the toggle /awe [<reason>]");
Irssi::print("Use /away [<reason>] for silent away");
Irssi::print("Use /help back or gone or awe for more information."); 


#- end
