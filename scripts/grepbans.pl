#!/usr/bin/perl

use strict;
use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
    authors     => 'Nathan Handler',
    contact     => 'nathan.handler@gmail.com',
    name        => 'grepbans',
    description => 'Greps the ban list for the specified pattern',
    license     => 'GPLv3+',
);

my($window, $channel, $pattern, $matches, $running);

$running=0;

sub grepbans {
	my($data,$server,$witem) = @_;

	if($running) {
		Irssi::print("grepbans is already running.");
		return;
	}
	$running=1;

        #Clear variables and register redirects
        &reset();

        #Split command arguments into a nick and a channel separated by a space
	($pattern,$channel)=split(/ /, $data, 2);

        #If no channel is specified, use the current window if it is a channel
	if($channel!~m/^#/ && $pattern!~m/^\s*$/ && $witem->{type} eq "CHANNEL") {
		$channel=$witem->{name};
	}

        #Stop the script and display usage information if they did not specify a pattern or if we can't find a channel to use
	if($channel!~m/^#/ || $pattern=~m/^\s*$/) {
		$window->print("\x02Usage\x02: /grepbans pattern [#channel]");
		$running=0;
		return;
	}

        #Print the name of the channel we are running on
	$window->print("\x02Channel\x02: $channel");

	#Perform a /mode <channel> b
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
#Irssi::signal_add('event empty', 'EMPTY');
Irssi::signal_add('redir err_nosuchchannel', 'ERR_NOSUCHCHANNEL');
Irssi::signal_add('redir rpl_banlist', sub { my($server,$data) = @_; RPL_BANLIST($server, "Ban $data"); });
Irssi::signal_add('redir rpl_endofbanlist', sub { my($server,$data) = @_; RPL_ENDOFBANLIST($server, "Ban $data"); });
Irssi::signal_add('redir rpl_quietlist', sub { my($server,$data) = @_; RPL_BANLIST($server, "Quiet $data"); });
Irssi::signal_add('redir rpl_endofquietlist', sub { my($server,$data) = @_; RPL_ENDOFBANLIST($server, "Quiet $data"); });

sub EMPTY {
	my($server, $data) = @_;

        return if(!$running);

	Irssi::print("\x02EMPTY\x02: $data");
}

sub RPL_BANLIST {
	my($server, $data) = @_;

        return if(!$running);

        my($type, $mask, $setby);
        if($data=~m/^Ban/) {
        	($type, undef, undef, $mask, $setby, undef) = split(/ /, $data, 6);
        }
        elsif($data=~m/^Quiet/) {
                ($type, undef, undef, undef, $mask, $setby, undef) = split(/ /, $data, 7);
        }

        #We only want to display who set the ban/quiet if it is listed as a person
        if($setby=~m/^.*?\.freenode\.net$/i) {
            $setby='';
        }
        else {
            $setby=" (Set by $setby)";
        }
	if($mask=~m/$pattern/i) {
		$window->print("$type against \x02$mask\x02 matches $pattern" . $setby);
		$matches++;
	}
	else {
#		$window->print("$type against \x02$mask\x02 does NOT match $string" . $setby);
	}
}

sub RPL_ENDOFBANLIST {
	my($server, $data) = @_;

        return if(!$running);

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
		if($matches == 0) {
                	$window->print("No matches for $pattern in $channel");
	        }
        	elsif ($matches == 1) {
	                $window->print("There is \x02$matches match\x02 for $pattern in $channel");
	        }
	        else {  
	                $window->print("There are \x02$matches matches\x02 for $pattern in $channel");
	        }
		$running=0;
	}
}

sub ERR_NOSUCHCHANNEL {
	my($server, $data) = @_;

	return if(!$running);

	$window->print("$channel does not exist.");
	$running=0;
}

sub reset {

        return if(!$running);

        $channel='';
	$pattern='';
	$matches=0;
	$window=Irssi::settings_get_str('grepbans_window');
	my $win = Irssi::window_find_name($window);
	if(!defined($win)) {
		$window=Irssi::active_win();
	}
	else {
		$window=$win;
	}

	&register_redirects();
}	

sub register_redirects {

        return if(!$running);

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
}

Irssi::command_bind('grepbans', 'grepbans');
Irssi::settings_add_str('grepbans', 'grepbans_window', '');

