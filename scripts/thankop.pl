use Irssi 0.8.10 ();
use strict;

use vars qw($VERSION %IRSSI);

$VERSION="0.1.7";
%IRSSI = (
	authors=> 'BC-bd',
	contact=> 'bd@bc-bd.org',
	name=> 'thankop',
	description=> 'Remembers the last person oping you on a channel',
	license=> 'GPL v2',
	url=> 'https://bc-bd.org/svn/repos/irssi/trunk/',
);

# $Id #
# 
#########
# USAGE
###
#
# Type '/thankop' in a channel window to thank the person opping you
#
##########
# OPTIONS
####
#
# /set thankop_command [command]
#		* command  : to be executed. The following $'s are expanded
#		    $N : Nick (some dude)
#		    
#		eg:
#		
#		  /set thankop_command say $N: w00t!
#
#		Would say
#
#		  <nick>: w00t!
#
#		To the channel you got op in, with <nick> beeing the nick who
#		opped you
#
################
###
# Changelog
#
# Version 0.1.7
#  - fix crash if used in a window != CHANNEL
#  - do not thank someone who has already left
#
# Version 0.1.6
#  - added support for multiple networks, thanks to senneth
#  - adapted to signal changes in 0.8.10
#
# Version 0.1.5
#  - change back to setting instead of theme item
#
# Version 0.1.4
#  - added theme item to customize the message (idea from mordeth)
#
# Version 0.1.3
#  - removed '/' from the ->command (thx to mordeth)
#  - removed debug messages (where commented out)
#  
# Version 0.1.2
#  - added version dependency, since some 0.8.4 users complained about a not
#      working script
#  
# Version 0.1.1
#  - unsetting of hash values is done with delete not unset.
#
# Version 0.1.0
#  - initial release
#  
###
################

my %op;

sub cmd_thankop {
	my ($data, $server, $witem) = @_;

	if (!$witem || ($witem->{type} =! "CHANNEL")) {
		Irssi::print("thankop: Window not of type CHANNEL");
		return;
	}

	my $tag = $witem->{server}->{tag}.'/'.$witem->{name};

	# did we record who opped us here
	if (!exists($op{$tag})) {
		$witem->print("thankop: I don't know who op'ed you in here");
		return;
	}

	my $by = $op{$tag};

	# still here?
	if (!$witem->nick_find($by)) {
		$witem->print("thankop: $by already left");
		return;
	}

	my $cmd = Irssi::settings_get_str('thankop_command');
				
	$cmd =~ s/\$N/$by/;
	$witem->command($cmd);
}

sub mode_changed {
	my ($channel, $nick, $by, undef, undef) = @_;

	return if ($channel->{server}->{nick} ne $nick->{nick});

	# since 0.8.10 this is set after signals have been processed
	return if ($channel->{chanop});

	my $tag = $channel->{server}->{tag}.'/'.$channel->{name};

	$op{$tag} = $by;
}

sub channel_destroyed {
	my ($channel) = @_;

	my $tag = $channel->{server}->{tag}.'/'.$channel->{name};

	delete($op{$tag});
}

Irssi::command_bind('thankop','cmd_thankop');
Irssi::signal_add_last('nick mode changed', 'mode_changed');

Irssi::settings_add_str('thankop', 'thankop_command', 'say $N: opthx');
