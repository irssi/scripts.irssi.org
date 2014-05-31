# INSTALLATION
# [&bitlbee] set typing_notice true
# <@root> typing_notice = `true'
# AND
# /statusbar window add typing_notice
#
# SETTINGS
# [bitlbee]
# bitlbee_send_typing = ON
#   -> send typing messages to buddies
# bitlbee_typing_allwin = OFF
#   -> show typing notifications in all windows
#
# 
# Changelog:
#
# 2010-08-09 (version 1.7.1)
# * Multiple control channels supported by checking chanmodes
#
# 2010-07-27 (version 1.7)
# * Using new server detection for latest BitlBee support
#
# 2010-07-26 (version 1.6.3)
# * Removed checking if nicks exists in &bitlbee channel, this because BitlBee 
#   can be used without control channel from this date
#
# 2007-03-03 (version 1.6.2)
# * Fix: timers weren't deleted correctly. This resulted in huge mem usage.
#
# 2006-11-02 (version 1.6.1)
# * Sending typing works again.
#
# 2006-10-27 (version 1.6)
# * 'channel sync' re-implemented.
# * bitlbee_send_typing was a string setting, It's a boolean now, like it should.
#
# 2006-10-24 (version 1.5)
# * Sending notices to online users only. ( removed this again at 2010-07-26, see above )
# * Using the new get_channel function;
#
# 2005-12-15 (version 1.42):
# * Fixed small bug with typing notices disappearing under certain circumstances
#   in channels
# * Fixed bug that caused outgoing notifications not to work 
# * root cares not about our typing status.
#
# 2005-12-04 (version 1.41):
# * Implemented stale states in statusbar (shows "(stale)" for OSCAR connections) 
# * Introduced bitlbee_typing_allwin (default OFF). Set this to ON to make
#   typing notifications visible in all windows.
#
# 2005-12-03 (version 1.4):
# * Major code cleanups and rewrites for bitlbee 1.0 with the updated typing
#   scheme. TYPING 0, TYPING 1, and TYPING 2 are now supported from the server.
# * Stale states (where user has typed in text but has stopped typing) are now
#   recognized.
# * Bug where user thinks you are still typing if you close the window after
#   typing something and then erasing it quickly.. fixed.
# * If a user signs off while they are still typing, the notification is removed
# This update by Matt "f0rked" Sparks
#
# 2005-08-26:
# Some fixes for AIM, Thanks to Dracula.
#
# 2005-08-16:
# AIM supported, for sending notices, using CTCP TYPING 0. (Use the AIM patch from Hanji http://get.bitlbee.org/patches/)
# 
# 2004-10-31:
# Sends typing notice to the bitlbee server when typing a message in irssi. bitlbee > 0.92
#
# 2004-06-11:
# shows [typing: ] in &bitlbee with multiple users.
#
use strict;
use Irssi::TextUI;
use Data::Dumper;

use vars qw($VERSION %IRSSI);

$VERSION = '1.7.1';
%IRSSI = (
	authors	 	=> 'Tijmen "timing" Ruizendaal, Matt "f0rked" Sparks',
	contact		=> 'tijmen.ruizendaal@gmail.com, root@f0rked.com',
	name		=> 'BitlBee_typing_notice',
	description	=> '1. Adds an item to the status bar wich shows [typing] when someone is typing a message on the supported IM-networks	2. Sends typing notices to the supported IM networks (the other way arround). (For bitlbee 3.0+)',
	license	 	=> 'GPLv2',
	url		=> 'http://the-timing.nl/stuff/irssi-bitlbee, http://f0rked.com',
	changed	 	=> '2010-08-09',
);

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

# How often to check if we are typing, or on msn,
# how long to keep the typing notice up, or check
# if the other user is still typing...
my $KEEP_TYPING_TIMEOUT = 1;
my $STOP_TYPING_TIMEOUT = 7;

my %timer_tag;

my %typing;
my %tag;
my $line;
my %out_typing;
my $lastkey;
my $keylog_active = 1;
my $command_char = Irssi::settings_get_str('cmdchars'); # mostly: /
my $to_char = Irssi::settings_get_str("completion_char"); # mostly: :

sub event_ctcp_msg {
	my ($server, $msg, $from, $address) = @_;
	return if $server->{tag} ne $bitlbee_server->{tag};
	if ( my($type) = $msg =~ "TYPING ([0-9])" ){
		Irssi::signal_stop();
		if( $type == 0 ){
			unset_typing($from);
		} elsif( $type == 1 ){
			$typing{$from}=1;
			if( $address !~ /\@login\.oscar\.aol\.com/ and $address !~ /\@YAHOO/ and $address !~ /\@login\.icq\.com/ ){
				Irssi::timeout_remove($tag{$from});
				delete($tag{$from});
				$tag{$from}=Irssi::timeout_add_once($STOP_TYPING_TIMEOUT*1000,"unset_typing",$from);
			}
			redraw($from);
		} elsif( $type == 2 ){
			stale_typing($from);
		}
	}
}

sub unset_typing {
	my($from,$no_redraw)=@_;
	delete $typing{$from} if $typing{$from};
	Irssi::timeout_remove($tag{$from});
	delete($tag{$from});
	redraw($from) if !$no_redraw;
}

sub stale_typing {
	my($from)=@_;
	$typing{$from}=2;
	redraw($from);
}

sub redraw {
	my($from)=@_;
	my $window = Irssi::active_win();
	my $name = $window->get_active_name();
	
	# only redraw if current window equals to the typing person, is a control channel or if allwin is set
	if( $from eq $name || (grep $_ eq $name, @control_channels) || Irssi::settings_get_bool("bitlbee_typing_allwin") ){
		Irssi::statusbar_items_redraw('typing_notice');
	}
}	

sub event_msg {
	my ($server,$data,$from,$address,$target) = @_;
	return if $server->{tag} ne $bitlbee_server->{tag};
	my $channel=Irssi::active_win()->get_active_name();
	unset_typing $from, "no redraw";
	unset_typing $channel;
}

sub event_quit {
	my $server = shift;
	return if $server->{tag} ne $bitlbee_server->{tag};
	my $nick = shift;
	unset_typing $nick;
}

sub typing_notice {
	my ($item, $get_size_only) = @_;
	my $window = Irssi::active_win();
	my $channel = $window->get_active_name();
	
	if (exists($typing{$channel})) {
		my $append=$typing{$channel}==2 ? " (stale)" : "";
		$item->default_handler($get_size_only, "{sb typing$append}", 0, 1);
	} else {
		$item->default_handler($get_size_only, "", 0, 1);
		Irssi::timeout_remove($tag{$channel});
		delete($tag{$channel});
	}
	# we check for correct windows again, because the statusbar item is redrawn after window change too.
	if( (grep $_ eq $channel, @control_channels) || Irssi::settings_get_bool("bitlbee_typing_allwin")) {
		foreach my $key (keys(%typing)) {
			$line .= " ".$key;
			if ($typing{$key}==2) { $line .= " (stale)"; }
		}
		if ($line ne "") {
			$item->default_handler($get_size_only, "{sb typing:$line}", 0, 1);
			$line = "";
		}
	} 
}

sub window_change {
	Irssi::statusbar_items_redraw('typing_notice');
	my $win = !Irssi::active_win() ? undef : Irssi::active_win()->{active};
	if (ref $win && ($win->{server}->{tag} eq $bitlbee_server->{tag})) {
		if (!$keylog_active) {
			$keylog_active = 1;
			Irssi::signal_add_last('gui key pressed', 'key_pressed');
		}
	} else {
		if ($keylog_active) {
			$keylog_active = 0;
			Irssi::signal_remove('gui key pressed', 'key_pressed');
		}
	}
}

sub key_pressed {
	return if !Irssi::settings_get_bool("bitlbee_send_typing");
	my $key = shift;
	if ($key != 9 && $key != 10 && $lastkey != 27 && $key != 27 
	   && $lastkey != 91 && $key != 126 && $key != 127) 
	{
		my $server = Irssi::active_server();
		my $window = Irssi::active_win();
		my $nick = $window->get_active_name();

		if ($server->{tag} eq $bitlbee_server->{tag} && $nick ne "(status)" && $nick ne "root") {
			if( grep $_ eq $nick, @control_channels ){ # send typing if in control channel
				my $input = Irssi::parse_special("\$L");
				my ($first_word) = split(/ /,$input);
				if ($input !~ /^$command_char.*/ && $first_word =~ s/$to_char$//){
					send_typing($first_word);
				}
			} else { # or any other channels / query
				my $input = Irssi::parse_special("\$L");
				if ($input !~ /^$command_char.*/ && length($input) > 0){
					send_typing($nick);
				}
			}
		}
	}
	$lastkey = $key;
}

sub out_empty {
	my ($a) = @_;
	my($nick,$tag)=@{$a};
	delete($out_typing{$nick});
	Irssi::timeout_remove($timer_tag{$nick});
	delete($timer_tag{$nick});
	$bitlbee_server->command("^CTCP $nick TYPING 0");
}

sub send_typing {
	my $nick = shift;
	if (!exists($out_typing{$nick}) || time - $out_typing{$nick} > $KEEP_TYPING_TIMEOUT) {
		$bitlbee_server->command("^CTCP $nick TYPING 1");
		$out_typing{$nick} = time;
		### Reset 'stop-typing' timer
		Irssi::timeout_remove($timer_tag{$nick});
		delete($timer_tag{$nick});

		### create new timer
		$timer_tag{$nick} = Irssi::timeout_add_once($STOP_TYPING_TIMEOUT*1000, 'out_empty', ["$nick", $bitlbee_server->{tag}]);
	}
}

#README: Delete the old bitlbee_send_typing string from ~/.irssi/config. A boolean is better.

sub db_typing { 
	print "Detected channels: ";
	print Dumper(@control_channels);
	print "Detected server tag: ".$bitlbee_server->{tag};
	print "Tag: ".Dumper(%tag);	
	print "Timer Tag: ".Dumper(%timer_tag);	
	print "Typing: ".Dumper(%typing);	
	print "Out Typing: ".Dumper(%out_typing);	
}

Irssi::command_bind('db_typing','db_typing');

Irssi::settings_add_bool("bitlbee","bitlbee_send_typing",1);
Irssi::settings_add_bool("bitlbee","bitlbee_typing_allwin",0);

Irssi::signal_add("ctcp msg", "event_ctcp_msg");
Irssi::signal_add("message private", "event_msg");
Irssi::signal_add("message public", "event_msg");
Irssi::signal_add("message quit", "event_quit");
Irssi::signal_add_last('window changed', 'window_change');
Irssi::signal_add_last('gui key pressed', 'key_pressed');
Irssi::statusbar_item_register('typing_notice', undef, 'typing_notice');
Irssi::statusbars_recreate_items();
