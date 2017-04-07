# BitchX TAB complete style
# for irssi 0.7.99 by bd@bc-bd.org
#
# <tab> signal handling learned from dictcomplete by Timo Sirainen
#
# thx go out to fuchs, darix, dg, peder and all on #irssi who helped
#
#########
# USAGE
###
# 
# In a channel window type "ab<tab>" to see a list of nicks starting
# with "ab".
# If you now press <tab> again, irssi will default to its own nick
# completion method.
# If you enter more characters you can use <tab> again to see a list
# of the matching nicks, or to complete the nick if there is only
# one matching.
#
# The last completion is saved so if you press "<tab>" with an empty
# input line, you get the last completed nick.
#
# Now there is a statusbar item where you can see the completing
# nicks instead of in the channel window. There are two ways to 
# use it:
#
#	1) Inside another statusbar
#
#		/set niq_show_in_statusbar ON
#		/statusbar window add -before more niq
#
#	2) In an own statusbar
#
#		/statusbar niq enable
#		/statusbar niq add niq
#		/statusbar niq disable
#		/set niq_show_in_statusbar ON
#		/set niq_own_statusbar ON
#
#	  You can also hide the bar when not completing nicks by using
#
#		/set niq_hide_on_inactive ON
#
#########
# OPTIONS
#########
#
# /set niq_show_in_statusbar <ON|OFF>
#		* ON  : show the completing nicks in a statusbar item
#		* OFF : show the nicks in the channel window
#
# /set niq_own_statusbar <ON|OFF>
#		* ON  : use an own statusbar for the nicks
#		* OFF : just use an item
#
# /set niq_hide_on_inactive <ON|OFF>
#		* ON  : hide the own statusbar on inactivity
#		* OFF : dont hide it
#
# /set niq_color_char <ON|OFF>
#		* ON  : colors the next unlikely character
#		* OFF : boring no colors
#
###
################
###
# Changelog
#
# Version 0.5.7
# - use configured completion_char instead of a colon
# - removed old, unused code
# - fixed url
# - fixed documentation leading to emtpy statusbar
# - removed warning about a problem with irssi version 0.8.4
#
# Version 0.5.6
# - work around an use problem
#
# Version 0.5.5
# - fixed completion for nicks starting with special chars
#
# Version 0.5.4
# - removed unneeded sort() of colored nicks
# - moved colored nick generation to where it is needed
# - the statusbar only worked with colorized nicks (duh!)
# 
# Version 0.5.3
#	- stop nickcompleting if last char is the completion_char
#	  which is in most cases ':'
#
# Version 0.5.2
#	- fixed vanishing statusbar. it wrongly was reset on any
#	  privmsg.
#
# Version 0.5.1
#	- changed statusbar to be off by default since most people 
#	  dont use the latest fixed version.
#
# Version 0.5
#	- added own statusbar option
#  - added color char option
#
# Version 0.4
#	- added an niq statusbar
#
# Version 0.3
#  - added default to irssi method on <tab><tab>
#
# Version 0.2 
#  - added lastcomp support
#
# Version 0.1
#  - initial release
###
################

use Irssi;
use Irssi::TextUI;
use strict;

use vars qw($VERSION %IRSSI);

$VERSION="0.5.7";
%IRSSI = (
	authors=> 'BC-bd',
	contact=> 'bd@bc-bd.org',
	name=> 'niq',
	description=> 'BitchX like Nickcompletion at line start plus statusbar',
	sbitems=> 'niq',
	license=> 'GPL v2',
	url=> 'https://bc-bd.org/cgi-bin/gitweb.cgi?p=irssi.git;a=summary',
);

my($lastword,$lastcomp,$niqString);

$lastcomp = "";
$lastword = "";

# build our nick with completion_char, add to complist and stop the signal
sub buildNickAndStop {
	my ($complist,$nick) = @_;
	my $push = $nick.Irssi::settings_get_str('completion_char');
		
	$lastcomp = $nick;
	$lastword = "";
	push (@{$complist}, $push);

	if (Irssi::settings_get_bool('niq_show_in_statusbar') == 1) {
		drawStatusbar("");
	}

	Irssi::signal_stop();
}

# the signal handler
sub sig_complete {
	my ($complist, $window, $word, $linestart, $want_space) = @_;

	# still allow channel- #<tab>, /set n<tab>, etc completion.
	if ($linestart ne "") {
		return;
	}

	# also back out if nothing has been entered and lastcomp is ""
	if ($word eq "") {
		if ($lastcomp ne "") {
			buildNickAndStop($complist,$lastcomp);
			return;
		} else {
			return;
		}
	}
	if (rindex($word,Irssi::settings_get_str('completion_char')) == length($word) -1) {
		chop($word);
		buildNickAndStop($complist,$word,0);
		return;
	}

	my $channel = $window->{active};

	# the completion is ok if this is a channel
	if ($channel->{type} ne "CHANNEL") 
	{
		return;
	}

	my (@nicks);

	# get the matching nicks but quote this l33t special chars like ^
	my $shortestNick = 999;
	my $quoted = quotemeta $word;
	foreach my $n ($channel->nicks()) {
		if ($n->{nick} =~ /^$quoted/i && $window->{active_server}->{nick} ne $n->{nick}) {
			push(@nicks,$n->{nick});
			if (length($n->{nick}) < $shortestNick) {
				$shortestNick = length($n->{nick});
			}
		}
	}

	@nicks = sort(@nicks);
	
	# if theres only one nick return it.
	if (scalar @nicks eq 1)
	{
		buildNickAndStop($complist,$nicks[0]);
	} elsif (scalar @nicks gt 1) {
		# check if this is <tab> or <tab><tab>
		if ($lastword eq $word) {
			# <tab><tab> so default to the irssi method
			sort(@nicks);
			for (@nicks) {
				$_ .= Irssi::settings_get_str ('completion_char');
			}

			push (@{$complist}, @nicks);

			# but delete lastword to be ready for the next <tab>
			$lastword = "";

			if (Irssi::settings_get_bool('niq_show_in_statusbar') == 1) {
				drawStatusbar("");
			}

			return;
		} else {
			# <tab> only so just print
		
			# build string w/o colored nicks
			if (Irssi::settings_get_bool('niq_color_char') == 1) {
				$niqString = "";
				foreach my $n (@nicks) {
					my $coloredNick = $n;
					$coloredNick =~ s/($quoted)(.)(.*)/$1%_$2%_$3/i;
					$niqString .= "$coloredNick ";
				}
			} else {
				$niqString = join(" ",@nicks);
			}
			
			if (Irssi::settings_get_bool('niq_show_in_statusbar') == 1) {
				drawStatusbar($niqString);
			} else {
				$window->print($niqString);
			}

			Irssi::signal_stop();

			# remember last word
			$lastword = $word;

			return;
		}
	} 
}

sub emptyBar() {
	$lastword = "";
	
	drawStatusbar("");
}

sub drawStatusbar() {
	my ($word) = @_;

	if (Irssi::settings_get_bool('niq_own_statusbar') == 1) {
		if (Irssi::settings_get_bool('niq_hide_on_inactive') == 1) {
			if ($word eq "") {
				Irssi::command("statusbar niq disable");
			} else {
				Irssi::command("statusbar niq enable");
			}
		}
	}

	$niqString = "{sb $word}";
	Irssi::statusbar_items_redraw('niq');
}

sub niqStatusbar() {
	my ($item, $get_size_only) = @_;

	$item->default_handler($get_size_only, $niqString, undef, 1);
}

Irssi::signal_add_first('complete word', 'sig_complete');
Irssi::signal_add_last('window changed', 'emptyBar');
Irssi::signal_add('message own_public', 'emptyBar');

Irssi::statusbar_item_register('niq', '$0', 'niqStatusbar');
Irssi::statusbars_recreate_items();

Irssi::settings_add_bool('misc', 'niq_show_in_statusbar', 0);
Irssi::settings_add_bool('misc', 'niq_own_statusbar', 0);
Irssi::settings_add_bool('misc', 'niq_hide_on_inactive', 1);
Irssi::settings_add_bool('misc', 'niq_color_char', 1);
