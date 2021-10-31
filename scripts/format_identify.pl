
#!/usr/bin/perl
# ^ to make vim know this is a perl script so I get syntax hilighting.

#####################################################################
### WARNING: This version was restored from google cache          ###
###           by Wouter Coekaerts <coekie@irssi.org>.             ###
###          Syntax might not be exactly the same as the original ###
#####################################################################

# $Id$
use strict;
use vars qw($VERSION %IRSSI);
use Irssi qw(signal_stop signal_emit signal_remove
             signal_add signal_add_first
             settings_add_str settings_get_str settings_add_bool
	     settings_get_bool
             print );
$VERSION = '1.5-dev-coekie';
%IRSSI = (
  authors => 'ResDev (Ben Reser)',
  contact => 'ben@reser.org',
  name  => 'format_identify',
  description => 'Formats msgs and notices when the identify-msg and/or ' .
                 'identify-ctcp capability is available.',
  license => 'GPL2',
  url   => 'http://ben.reser.org/irssi/',
);

# Additional credit to ch for his wash-imsg script which was a starting place
# for this; coekie for pointing me towards the nickcolor script and its
# technique for doing this; Timo Sirainen and Ian Peters for writing nickcolor.

# This script takes advantage of the identify-msg and identify-ctcp
# capabilities of the new dancer ircd.  The identify-msg capability causes the
# first character of a msg or notice to be set to a + if the user is identified
# with nickserve and a - if not.  identify-ctcp does similar for CTCP messages.
# This script removes the tagging and then allows you to configure a
# modification to the formating of the nickname.

# Installation instructions:  Drop this in ~/.irssi/scripts and run
# /script load format_identify.  To make it autorun on startup place it in
# ~/.irssi/scripts/autorun.  This script will detect if the IRC server has
# the identify-msg and identify-ctcp capability.  If it is available it will
# use it.  Messages on servers without support for these capabilities will
# be tagged as unknown.  
# 
# While you can unload this script.  Any servers that you are connected to
# with identify-msg/identify-ctcp turned on will continue to send data
# encoded that way.  This means messages and notices will have a + or -
# appended to the front of them.  CTCPs will be broken.  Unfortunately, there
# is no way to turn off a capability once it is turned on.  You will have to
# disconnect and reconnect to these servers.  This script will warn you when
# unloading the script of this situation.

#
# Configuration:  You can control the formating of the nickname with the
# format_identified_nick, format_unidentified_nick, and format_unknown_nick
# variables.  The default is to do nothing to identified nicks and unknown
# nicks.  while unidentified nicks have a ~ to the beginning of nick.  An
# unknown nick means anytime a message or notice doesn't start with a + or -,
# which will occur when identify-msg isn't enabled.  The format_unknown_nick
# can be really handy to alert you that you don't have identify-msg or
# identify-ctcp set, but is set by default to do nothing since most servers do
# not have identify-msg yet.  In these variables $0 stands for the nick.  You
# can use the standard formating codes or just text in it.  See formats.txt for
# more information on the codes you can use.  Warning about colors.  Using
# colors in this formating will likely break other formating scripts and
# features, in particular the hilight feature of irssi or vice versa.  Remember
# that %n has a different meaning here as explamined in the default.theme file
# that comes with irssi.
#
# Some examples:
# 
# Make unidentified nicks have a ? after the nick: /set
# format_unidentified_nick $0?
#
# Make unidentified nicks red and identified nicks green: /set
# format_identified_nick %G$0 /set format_unidentified_nick %R$0 Note that the
# above will not do the tagging if a message gets hilighted.  Since a hilight
# (line or nick) will override the colors.
#
# So I recommend doing something like this: /set format_identified_nick %G$0
# /set format_unidentified_nick %R~$0
# 
# Make unidentified nicks be unmodified but add a * before identified nicks:
# /set format_identified_nick *$0 /set format_unidentified_nick $0
#
# This script works by modifying the formats irssi uses to display various
# things.  Therefore it is highly recommended that you do not change any of the
# following format variables except through this script: pubmsg pubmsg_channel
# msg_private msg_private_query pubmsg_hilight pubmsg_hilight_channel pubmsg_me
# pubmsg_me_channel action_private action_private_query action_public
# action_public_channel ctcp_requested ctcp_requested_unknown notice_public
# notice_private ctcp_reply ctcp_reply_channel ctcp_ping_reply

#
# To change these formats you need to set the variable (with the set command
# not the format command as usual) of the same name as the format but with
# _identify on the end.  This format has an additional special purpose
# "abstract" that is only used by this script and is parsed and replaced before
# setting the format and giving it to irssi.  It is called format_identify.
# Any format you use with this script should have a {format_identify $0} in it
# to replace where the $0 usually is in the format.  Sometimes it will be $1
# for the nick in the format, in which case you should replace the $1 with
# {format_identify $1}.  For more examples take a look at the defaults at the
# bottom of this script.
#
#
# If you wish to disable the module from applying a change to the nickname in a
# particular place the best way to do it is to simply remove the
# {format_identify $0} from the format that applies.  E.G. to disable the
# format change for a CTCP reply one would do: /set ctcp_reply_identify CTCP
# {hilight $0} reply from {nick $1}: $2
#

# TODO
# * Implement DCC formats, which means figuring out which ones are appropriate
# to try and format.  
# * Allow different formating on the nick for different types of messages.  I'm
# not sure if this is useful...
# 
# It should not be necessary to modify anything in this script.  Everything
# should be able to be modified via the variables it exports as described
# above.
# 

my(@format_identify_message_formats) = qw(pubmsg pubmsg_channel msg_private
                                          msg_private_query pubmsg_hilight
                                          pubmsg_hilight_channel action_private
                                          action_private_query action_public
                                          action_public_channel ctcp_requested
                                          ctcp_requested_unknown pubmsg_me
                                          pubmsg_me_channel
                                         );

my(@format_identify_notice_formats) = qw(notice_public notice_private ctcp_reply
                                         ctcp_reply_channel ctcp_ping_reply);


my %servers;

# Replace the {format_identify $0} place holder with
# whatever the user has setup for their nick formats...
sub replace_format_identify {
	my ($format, $entry) = @_;

	my ($nickarg) = $format =~ /{\s*format_identify\s+?([^\s]+?)\s*}/;
	$entry =~ s/\$0/$nickarg/;
	$format =~ s/{\s*format_identify\s+?[^\s]+?\s*}/$entry/g;
	return $format;
}

# rewrite the message now that we've updated the formats
sub format_identify_rewrite {
	my $signal = shift;
	my $proc = shift;

	signal_stop();
	signal_remove($signal,$proc);
	signal_emit($signal, @_);
	signal_add($signal,$proc);
}

  
# Issue the format update after generating the new format.
sub update_format_identify {
	my ($server,$entry,$nick) = @_;

	my $identify_format = settings_get_str("${entry}_identify");
	my $replaced_format = replace_format_identify($identify_format,$nick);
	$server->command("^format $entry " . $replaced_format);
}

my %saved_colors;
my %session_colors = {};
my @colors = qw/2 3 4 5 6 7 9 10 11 12 13/;

sub simple_hash {
	my ($string) = @_;
	chomp $string;
	my @chars = split //, $string;
	my $counter;

	foreach my $char (@chars) {
		$counter += ord $char;
	}

	$counter = $colors[($counter % @colors)];
	return $counter;
}

sub colourise {
	return if(!settings_get_bool('format_colour'));
	my ($nick) = @_;
	my $color = $saved_colors{$nick};
	if (!$color) {
		$color = $session_colors{$nick};
	}
	if (!$color) {
		$color = simple_hash $nick;
		$session_colors{$nick} = $color;
	}
	$color = "0".$color if ($color < 10);
	return chr(3).$color;
}


# catches the signal for a message removes the + or -, updates the 
# formats and then resends the message event.
sub format_identify_message {
	my ($server, $data, $nick, $address) = @_;
	my ($channel, $msg) = split(/ :/, $data,2);

	if (!$servers{$server->{'real_address'}}->{'IDENTIFY-CTCP'} &&
		!$servers{$server->{'real_address'}}->{'IDENTIFY-MSG'}) {
		my $unknown_nick = settings_get_str('format_unknown_nick');
		foreach my $format (@format_identify_message_formats) {
			update_format_identify($server,$format,colourise($nick).$unknown_nick);
		}
	} elsif(($msg =~ /^\+(.*)/)){
		my $newdata = "$channel :$1";
		my $identified_nick = settings_get_str('format_identified_nick');
		foreach my $format (@format_identify_message_formats) {
			update_format_identify($server,$format,colourise($nick).$identified_nick);
		}
		format_identify_rewrite('event privmsg','format_identify_message', $server,$newdata,$nick,$address);
	} elsif(($msg =~ /^-(.*)/)){
		my $newdata = "$channel :$1";
		my $unidentified_nick = settings_get_str('format_unidentified_nick');
		foreach my $format (@format_identify_message_formats) {
			update_format_identify($server,$format,colourise($nick).$unidentified_nick);
		} 
		format_identify_rewrite('event privmsg','format_identify_message', $server,$newdata,$nick,$address);
	} else {
		my $unknown_nick = settings_get_str('format_unknown_nick');
		foreach my $format (@format_identify_message_formats) {
			update_format_identify($server,$format,colourise($nick).$unknown_nick);
		}
	}
}

# catches the signal for a notice removes the + or -, updates the
# formats and resends the notice event.
sub format_identify_notice {
	my ($server, $data, $nick, $address) = @_;
	my ($channel, $msg) = split(/ :/, $data,2);

	if (!$servers{$server->{'real_address'}}->{'IDENTIFY-CTCP'} &&
		!$servers{$server->{'real_address'}}->{'IDENTIFY-MSG'}) {
		my $unknown_nick = settings_get_str('format_unknown_nick');
		foreach my $format (@format_identify_notice_formats) {
			update_format_identify($server,$format,colourise($nick).$unknown_nick);
		}
	} elsif(($msg =~ /^\+(.*)/)){
		my $newdata = "$channel :$1";
		my $identified_nick = settings_get_str('format_identified_nick');
		foreach my $format (@format_identify_notice_formats) {
			update_format_identify($server,$format,colourise($nick).$identified_nick);
		} 
		format_identify_rewrite('event notice','format_identify_notice', $server,$newdata,$nick,$address);
	} elsif(($msg =~ /^-(.*)/)){
		my $newdata = "$channel :$1";
		my $unidentified_nick = settings_get_str('format_unidentified_nick');
		foreach my $format (@format_identify_notice_formats) {
			update_format_identify($server,$format,colourise($nick).$unidentified_nick);
		}
		format_identify_rewrite('event notice','format_identify_notice', $server,$newdata,$nick,$address);
	} else {
		my $unknown_nick = settings_get_str('format_unknown_nick');
		foreach my $format (@format_identify_notice_formats) {
			update_format_identify($server,$format,colourise($nick).$unknown_nick);
		}
	}
}

# Handle CTCP messages.  Note that messages tagged with identify-ctcp will
# not be seen as CTCPs and will go through event privmsg first.  This script
# will generate new events and send them on through to here.  However CTCPs
# that are not tagged at all will go here first.  So we need to test here
# to see if the message is from a server that does not support identify-ctcp
# and update the format accordingly.
sub format_identify_ctcp_msg {
	my ($server) = @_;

	if (!$servers{$server->{'real_address'}}->{'IDENTIFY-CTCP'}) {
		my $unknown_nick = settings_get_str('format_unknown_nick');
		foreach my $format (@format_identify_message_formats) {
			update_format_identify($server,$format,$unknown_nick);
		}
	}
}

# Handle CTCP replies.  Note that messages tagged with identify-ctcp will
# not be seen as CTCPs and will go through event notice first.  This script
# will generate new events and send them on through to here.  However CTCPs
# that are not tagged at all will go here first.  So we need to test here
# to see if the message is from a server that does not support identify-ctcp
# and update the format accordingly.
sub format_identify_ctcp_reply {
	my ($server) = @_;

	if (!$servers{$server->{'real_address'}}->{'IDENTIFY-CTCP'}) {
		my $unknown_nick = settings_get_str('format_unknown_nick');
		foreach my $format (@format_identify_notice_formats) {
			update_format_identify($server,$format,$unknown_nick);
		}
	}
}

# If we're getting unloaded reset the formats back to their defaults
# so that it doesn't wrongly show people being unidentifed or vice versa.
# Also issue a warning about CTCPs etc being broken.
sub format_identify_unload {
	my ($script,$server,$witem) = @_;
	my @warning_servers = ();

	if ($script =~ /^format_identify(?:\.pl|\.perl)?$/) {
		foreach my $format (@format_identify_message_formats,
			@format_identify_notice_formats) {
			$server->command("^format -reset $format");
		}
		foreach my $server_name (keys %servers) {
			if ( $servers{$server_name}->{'IDENTIFY-MSG'} 
				|| $servers{$server_name}->{'IDENTIFY-CTCP'})
			{
				if($servers{$server_name}->{'USES-CAP'}) {
					$server->command("^quote cap req :-identify-msg");
				} else {
					push @warning_servers, $server_name;
				}
			}
		} 
		print('Warning: Unloading format_identify will leave your messages '.
			'and notices modified and will break CTCPs on the following '.
			'servers: ' . join (',',@warning_servers));
	}
}

# Server responded to capab request.  We want to capture the reply
# and mark it in a hash so we can keep track of which servers have 
# the capabilities. This style of reply will come from dancer or
# hyperion.
sub format_identify_capab_reply {
	my ($server, $data, $server_name) = @_;
	unless (ref($servers{$server_name}) eq 'HASH') {
		$servers{$server_name} = {};
		$servers{$server_name}->{'IDENTIFY-MSG'} = 0;
		$servers{$server_name}->{'IDENTIFY-CTCP'} = 0;
		$servers{$server_name}->{'USES-CAP'} = 0;
	}
	if ($data =~ /:IDENTIFY-MSG$/) {
		$servers{$server_name}->{'IDENTIFY-MSG'} = 1;
		$servers{$server_name}->{'USES-CAP'} = 0;
		Irssi::signal_stop();
		return;
	}
	if ($data =~ /:IDENTIFY-CTCP$/) {
		$servers{$server_name}->{'IDENTIFY-CTCP'} = 1;
		$servers{$server_name}->{'USES-CAP'} = 0;
		Irssi::signal_stop();
		return;
	}
}

# The same as above. This style of reply comes from ircd-seven.
sub format_identify_cap_reply {
	my ($server, $data, $server_name) = @_;
	unless (ref($servers{$server_name}) eq 'HASH') {
		$servers{$server_name} = {};
		$servers{$server_name}->{'IDENTIFY-MSG'} = 0;
		$servers{$server_name}->{'IDENTIFY-CTCP'} = 0;
		$servers{$server_name}->{'USES-CAP'} = 0;
	}
	if ($data =~ /ACK :.*identify-msg/) {
		$servers{$server_name}->{'IDENTIFY-MSG'} = 1;
		$servers{$server_name}->{'IDENTIFY-CTCP'} = 1;
		$servers{$server_name}->{'USES-CAP'} = 1;
		return;
	}
}

# Handles connections to new (to this script) servers and
# attempts to turn on the capabilities it supports.
# We send the request in both formats, for hyperion and ircd-seven.
sub format_identify_connected {
	my $server = shift;
	$server->command("^quote capab IDENTIFY-MSG");
	$server->command("^quote capab IDENTIFY-CTCP");
	$server->command("^quote cap req :identify-msg");
}

# signals to handle the events we need to intercept.
signal_add('event privmsg', 'format_identify_message');
signal_add('event notice', 'format_identify_notice');
signal_add('ctcp msg', 'format_identify_ctcp_msg');
signal_add('ctcp reply', 'format_identify_ctcp_reply');
signal_add('event 290', 'format_identify_capab_reply');
signal_add('event cap', 'format_identify_cap_reply');
signal_add('event connected', 'format_identify_connected');

# On load enumerate the servers and try to turn on 
# IDENTIFY-MSG and IDENTIFY-CTCP
foreach my $server (Irssi::servers()) {
	%servers = ();
	format_identify_connected($server);
}

# signal needed to catch the unload...  Be sure to be the first to
# get it too...
signal_add_first('command script unload', 'format_identify_unload');

settings_add_bool('format_identify', 'format_colour', 1);

# How we format the nick.  $0 is the nick we'll be formating.
settings_add_str('format_identify','format_identified_nick','$0');
settings_add_str('format_identify','format_unidentified_nick','~$0');
settings_add_str('format_identify','format_unknown_nick','$0');

# What we use for the formats...
# Don't modify here, use the /set command or modify in the ~/.irssi/config file.
settings_add_str('format_identify','pubmsg_identify','{pubmsgnick $2 {pubnick {format_identify $0}}}$1');
settings_add_str('format_identify','pubmsg_channel_identify','{pubmsgnick $3 {pubnick {format_identify $0}}{msgchannel $1}}$2');
settings_add_str('format_identify','msg_private_identify','{privmsg {format_identify $0} $1 }$2');
settings_add_str('format_identify','msg_private_query_identify','{privmsgnick {format_identify $0}}$2');
settings_add_str('format_identify','pubmsg_hilight_identify','{pubmsghinick {format_identify $0} $3 $1}$2');
settings_add_str('format_identify','pubmsg_hilight_channel_identify','{pubmsghinick {format_identify $0} $4 $1{msgchannel $2}$3');
settings_add_str('format_identify','action_private_identify','{pvtaction {format_identify $0}}$2');
settings_add_str('format_identify','action_private_query_identify','{pvtaction_query {format_identify $0}}$2');
settings_add_str('format_identify','action_public_identify','{pubaction {format_identify $0}}$1');
settings_add_str('format_identify','action_public_channel_identify', '{pubaction {format_identify $0}{msgchannel $1}}$2');
settings_add_str('format_identify','ctcp_requested_identify','{ctcp {hilight {format_identify $0}} {comment $1} requested CTCP {hilight $2} from {nick $4}}: $3');
settings_add_str('format_identify','ctcp_requested_unknown_identify','{ctcp {hilight {format_identify $0}} {comment $1} requested unknown CTCP {hilight $2} from {nick $4}}: $3');
settings_add_str('format_identify','pubmsg_me_identify','{pubmsgmenick $2 {menick {format_identify $0}}}$1');
settings_add_str('format_identify','pubmsg_me_channel_identify','{pubmsgmenick $3 {menick {format_identify $0}}{msgchannel $1}}$2');
settings_add_str('format_identify','notice_public_identify','{notice {format_identify $0}{pubnotice_channel $1}}$2');
settings_add_str('format_identify','notice_private_identify','{notice {format_identify $0}{pvtnotice_host $1}}$2');
settings_add_str('format_identify','ctcp_reply_identify','CTCP {hilight $0} reply from {nick {format_identify $1}}: $2');
settings_add_str('format_identify','ctcp_reply_channel_identify','CTCP {hilight $0} reply from {nick {format_identify $1}} in channel {channel $3}: $2');
settings_add_str('format_identify','ctcp_ping_reply_identify','CTCP {hilight PING} reply from {nick {format_identify $0}}: $1.$[-3.0]2 seconds');
