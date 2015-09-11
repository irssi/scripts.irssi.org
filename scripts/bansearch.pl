#!/usr/bin/perl

use strict;
use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI);

$VERSION = "1.1";
%IRSSI = (
    authors     => ['Nathan Handler', 'Joseph Price'],
    contact     => ['nathan.handler@gmail.com', 'pricechild@ubuntu.com'],
    name        => 'bansearch',
    description => 'Searches for bans, quiets, and channel modes affecting a user',
    license     => 'GPLv3+',
);

my($channel,$person,$nick,$user,$host,$real,$account,$string,$issues,$running,@jchannels,@jchannelstocheck);

$running=0;

sub bansearch {
	my($data,$server,$witem) = @_;

	if($running) {
		Irssi::print("bansearch is already running.");
	}

	$running=1;
	@jchannels=();
	@jchannelstocheck=();

        #Clear variables and register redirects
        &reset();

        #Split command arguments into a nick and a channel separated by a space
	($person,$channel)=split(/ /, $data, 2);

        #If no channel is specified, use the current window if it is a channel
	if($channel!~m/^#/ && $person!~m/^\s*$/ && $witem->{type} eq "CHANNEL") {
		$channel=$witem->{name};
	}

        #Stop the script and display usage information if they did not specify a person or if we can't find a channel to use
	if($channel!~m/^#/ || $person=~m/^\s*$/) {
		Irssi::active_win()->print("\x02Usage\x02: /bansearch nick [#channel]");
		$running=0;
		return;
	}

        #Print the name of the channel we are running on
	Irssi::active_win()->print("\x02Channel\x02: $channel");

        #Perform a /who <user> %uhnar
	$server->redirect_event('who',1, $person, 0, undef,
	{
	  'event 352' => 'redir rpl_whoreply',
          'event 354' => 'redir rpl_whospcrpl',
	  'event 315' => 'redir rpl_endofwho',
	  'event 401' => 'redir err_nosuchnick',
	  '' => 'event empty',
	}
	);
	$server->send_raw("WHO $person %uhnar");
}	
#Irssi::signal_add('event empty', 'EMPTY');
Irssi::signal_add('redir rpl_whoreply', 'RPL_WHOREPLY');
Irssi::signal_add('redir rpl_whospcrpl', 'RPL_WHOREPLY');
Irssi::signal_add('redir rpl_endofwho', 'RPL_ENDOFWHO');
Irssi::signal_add('redir err_nosuchnick', 'ERR_NOSUCHNICK');
Irssi::signal_add('redir err_nosuchchannel', 'ERR_NOSUCHCHANNEL');
Irssi::signal_add('redir rpl_banlist', sub { my($server,$data) = @_; RPL_BANLIST($server, "Ban $data"); });
Irssi::signal_add('redir rpl_endofbanlist', sub { my($server,$data) = @_; RPL_ENDOFBANLIST($server, "Ban $data"); });
Irssi::signal_add('redir rpl_quietlist', sub { my($server,$data) = @_; RPL_BANLIST($server, "Quiet $data"); });
Irssi::signal_add('redir rpl_endofquietlist', sub { my($server,$data) = @_; RPL_ENDOFBANLIST($server, "Quiet $data"); });
Irssi::signal_add('redir rpl_channelmodeis', 'RPL_CHANNELMODEIS');

sub EMPTY {
	my($server, $data) = @_;

        return if(!$running);

	Irssi::print("\x02EMPTY\x02: $data");
}

sub RPL_BANLIST {
	my($server, $data) = @_;

        return if(!$running);

        my($type, $mask, $setby, $banchannel, $jchannel);
        if($data=~m/^Ban/) {
        	($type, undef, $banchannel, $mask, $setby, undef) = split(/ /, $data, 6);
        }
        elsif($data=~m/^Quiet/) {
                ($type, undef, $banchannel, undef, $mask, $setby, undef) = split(/ /, $data, 7);
        }
	my $maskreg = $mask;
	$maskreg=~s/\$\#.*$//;	#Support matching ban-forwards
	$maskreg=~s/\./\\./g;
	$maskreg=~s/\//\\\//g;
	$maskreg=~s/\@/\\@/g;
	$maskreg=~s/\[/\\[/g;
	$maskreg=~s/\]/\\]/g;
	$maskreg=~s/\|/\\|/g;
	$maskreg=~s/\?/\./g;
	$maskreg=~s/\*/\.\*\?/g;

        #We only want to display who set the ban/quiet if it is listed as a person
        if($setby=~m/^.*?\.freenode\.net$/i) {
            $setby='';
        }
        else {
            $setby=" (Set by $setby)";
        }

	if($maskreg=~m/^\$/) {	#extban
		if($maskreg=~m/^\$a:(.*?)$/i) {
			if($account=~m/^$1$/i && $account!~m/^0$/) {
				Irssi::active_win()->print("$type against \x02$mask\x02 in $banchannel matches $account" . $setby);
				$issues++;
			}
			else {
#				Irssi::active_win()->print("$type against \x02$mask\x02 does NOT match $account" . $setby);
			}
		}
		if($channel == $banchannel) {
			if($maskreg=~m/^\$j:(.*?)$/i) {
				$jchannel = $1;
				if(!($jchannel ~~ @jchannels)) {
					push(@jchannels, $jchannel);
					push(@jchannelstocheck, $jchannel);
					Irssi::active_win()->print("Following bans in " . $jchannel . " will " . $type . " " . $person . " in " . $channel . $setby);
				}
			}
		}
		if($maskreg=~m/^\$~a$/i) {
			if($account=~m/^0$/) {
				Irssi::active_win()->print("$type against \x02$mask\x02 in $banchannel matches unidentified user." . $setby);
				$issues++;
			}
			else {
#				Irssi::active_win()->print("$type against \x02$mask\x02 does NOT match $account" . $setby);
			}
		}
		if($maskreg=~m/^\$r:(.*?)$/i) {
			if($real=~m/^$1$/i) {
				Irssi::active_win()->print("$type against \x02$mask\x02 in $banchannel matches real name of $real" . $setby);
				$issues++;
			}
			else {
#				Irssi::active_win()->print("$type against \x02$mask\x02 does NOT match real name of $real" . $setby);
			}
		}
		if($maskreg=~m/^\$x:(.*?)$/i) {
			my $full = "$nick!user\@host\#$real";
			if($full=~m/^$1$/i) {
				Irssi::active_win()->print("$type against \x02$mask\x02 in $banchannel matches $full" . $setby);
				$issues++;
			}
			else {
#				Irssi::active_win()->print("$type against \x02$mask\x02 does NOT match $full" . $setby);
			}
		}
	}
	else {	#Normal Ban
		if($string=~m/^$maskreg$/i) {
			Irssi::active_win()->print("$type against \x02$mask\x02 in $banchannel matches $string" . $setby);
			$issues++;
		}
		else {
#			Irssi::active_win()->print("$type against \x02$mask\x02 does NOT match $string" . $setby);
		}
	}
}

sub RPL_ENDOFBANLIST {
	my($server, $data) = @_;

        return if(!$running);

#	Irssi::active_win()->print("End of Ban List");
	if($data=~m/^Ban/) {
		$server->redirect_event('mode q',1, $channel, 0, undef,
		{
		  'event 728' => 'redir rpl_quietlist',
		  'event 729' => 'redir rpl_endofquietlist',
		  '' => 'event empty',
		}
		);
		$server->send_raw("MODE $channel q");
	}
	elsif($data=~m/^Quiet/) {
		$server->redirect_event('mode channel',1, $channel, 0, undef,
		{
		  'event 324' => 'redir rpl_channelmodeis',
		  '' => 'event empty',
		}
		);
		if (@jchannelstocheck) {
			my $nextchannel = pop(@jchannelstocheck);
			$server->redirect_event('mode b',1, $nextchannel, 0, undef, 
				{
	  	  	  	  'event 367' => 'redir rpl_banlist',
	  	  	  	  'event 368' => 'redir rpl_endofbanlist',
	  	  	  	  'event 403' => 'redir err_nosuchchannel',
	  	  	  	  '' => 'event empty',
				}
			);
			$server->send_raw("MODE $nextchannel b");
		} else {
			$server->send_raw("MODE $channel");
		}
	}
}

sub RPL_WHOREPLY {
	my($server, $data) = @_;

        return if(!$running);

        (undef, $user, $host, $nick, $account, $real) = split(/ /, $data, 6);
        $real=~s/^://;
        Irssi::active_win()->print("\x02User\x02: $nick [$account] ($real) $user\@$host");
}

sub RPL_ENDOFWHO {
	my($server, $data) = @_;

        return if(!$running);

	if($nick=~m/^$/ && $user=~m/^$/ && $host=~m/^$/) {
		Irssi::active_win()->print("$person is currently offline.");
		return;
	}
	$string="$nick!$user\@$host";
	$server->redirect_event('mode b',1, $channel, 0, undef, 
	{
	  'event 367' => 'redir rpl_banlist',
	  'event 368' => 'redir rpl_endofbanlist',
	  'event 403' => 'redir err_nosuchchannel',
	  '' => 'event empty',
	}
	);
	$server->send_raw("MODE $channel b");
}

sub ERR_NOSUCHNICK {
	my($server, $data) = @_;

        return if(!$running);

	Irssi::active_win()->print("$person is currently offline.");
	$running=0;
}

sub ERR_NOSUCHCHANNEL {
	my($server, $data) = @_;

        return if(!$running);

	Irssi::active_win()->print("$channel does not exist.");
	$running=0;
}

sub RPL_CHANNELMODEIS {
	my($server, $data) = @_;

        return if(!$running);

	my(undef, undef, $modes, $args) = split(/ /, $data, 4);
	Irssi::active_win()->print("\x02Channel Modes\x02: $modes");
	if($modes=~m/i/) {
		Irssi::active_win()->print("Channel is \x02invite-only\x02 (+i)");
		$issues++;
	}
	if($modes=~m/k/) {
		Irssi::active_win()->print("Channel has a \x02password\x02 (+k)");
		$issues++;
	}
	if($modes=~m/r/) {
		if($account=~m/^0$/) {
			Irssi::active_win()->print("Channel is \x02blocking unidentified users\x02 (+r) and user is not identified");
			$issues++;
		}
	}
	if($modes=~m/m/) {
                if($server->channel_find("$channel")) {
		    my $n = $server->channel_find("$channel")->nick_find("$nick");
		    if($n->{voice} == 0 && $n->{op} == 0) {
		    	Irssi::active_win()->print("Channel is \x02moderated\x02 (+m) and user is not voiced or oped");
		    	$issues++;
		    }
                }
                else {
                    Irssi::active_win()->print("Channel is \x02moderated\x02 (+m) and user might not be voiced or oped");
                    $issues++;
                }
	}

	if($issues == 0) {
		Irssi::active_win()->print("There does not appear to be anything preventing $person from joining/talking in $channel");
	}
	elsif ($issues == 1) {
		Irssi::active_win()->print("There is \x02$issues issue\x02 that might be preventing $person from joining/talking in $channel");
	}
	else {
		Irssi::active_win()->print("There are \x02$issues issues\x02 that might be preventing $person from joining/talking in $channel");
	}
	$running=0;
}

sub reset {

        return if(!$running);

        $channel='';
        $person='';
        $nick='';
        $user='';
        $host='';
        $real='';
        $account='';
        $string='';
	$issues=0;

	&register_redirects();
}	

sub register_redirects {

        return if(!$running);

        #who
        Irssi::Irc::Server::redirect_register('who', 0, 0,
        { "event 352" => 1,    # start events
          "event 354" => -1,
        },
        {                      # stop events
          "event 315" => 1,    # End of Who List
          "event 401" => 1,    # No Such Nick
        },
        undef,                 # optional events
        );

	#mode b
	Irssi::Irc::Server::redirect_register('mode b', 0, 0,
  	{ "event 367" => 1 }, # start events
	{ 		      # stop events
	  "event 368" => 1,   # End of channel ban list
	  "event 403" => 1,   # no such channel
	  "event 442" => 1,   # "you're not on that channel"
	  "event 479" => 1    # "Cannot join channel (illegal name)"
	},
	undef, 		      # optional events
	);

        #mode q
        Irssi::Irc::Server::redirect_register('mode q', 0, 0,
        { "event 728" => 1 }, # start events
        {                     # stop events
          "event 729" => 1,   # End of channel quiet list
          "event 403" => 1,   # no such channel
          "event 442" => 1,   # "you're not on that channel"
          "event 479" => 1,   # "Cannot join channel (illegal name)"
      },
      undef,                  # optional events
      );

	#mode channel
	Irssi::Irc::Server::redirect_register('mode channel', 0, 0, undef,
	{ # stop events
	  "event 324" => 1, # MODE-reply
	  "event 403" => 1, # no such channel
	  "event 442" => 1, # "you're not on that channel"
	  "event 479" => 1  # "Cannot join channel (illegal name)"
	},
	{ "event 329" => 1 } # Channel create time
	);
}

Irssi::command_bind('bansearch', 'bansearch');
