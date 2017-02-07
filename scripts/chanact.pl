use Irssi 20020101.0001 ();
use strict;
# FIXME use warning;
use Irssi::TextUI;

use vars qw($VERSION %IRSSI);

$VERSION = "0.5.14";
%IRSSI = (
    authors     => 'BC-bd, Veli',
    contact     => 'bd@bc-bd.org, veli@piipiip.net',
    name        => 'chanact',
    description => 'Adds new powerful and customizable [Act: ...] item (chanelnames,modes,alias). Lets you give alias characters to windows so that you can select those with meta-<char>',
    license     => 'GNU GPLv2 or later',
    url         => 'https://bc-bd.org/svn/repos/irssi/chanact'
);

# Adds new powerful and customizable [Act: ...] item (chanelnames,modes,alias).
# Lets you give alias characters to windows so that you can select those with
# meta-<char>.
#
# for irssi 0.8.2 by bd@bc-bd.org
#
# inspired by chanlist.pl by 'cumol@hammerhart.de'
#
#########
# Contributors
#########
#
# veli@piipiip.net   /window_alias code
# qrczak@knm.org.pl  chanact_abbreviate_names
# qerub@home.se      Extra chanact_show_mode and chanact_chop_status
# madduck@madduck.net Better channel aliasing (case-sensitive, cross-network)
#                     chanact_filter_windowlist basis
# Jan 'jast' Krueger <jast@heapsort.de>, 2004-06-22
# Ivo Timmermans <ivo@o2w.nl>	win->{hilight} patch
# 
#########
# USAGE
###
# 
# copy the script to ~/.irssi/scripts/
#
# In irssi:
#
#		/script load chanact
#		/statusbar window add -after act chanact
#
# If you want the item to appear on another position read the help
# for /statusbar.
# To remove the [Act: 1,2,3] item type:
#
#		/statusbar window remove act
#
# To see all chanact options type:
#
# 	/ set chanact_
#
# After these steps you have your new statusbar item and you can start giving
# aliases to your windows. Go to the window you want to give the alias to
# and say:
#
#		/window_alias <alias char>
#
# You can remove the aliases with from an aliased window:
#
#		/window_unalias
#
# To see a list of your windows use:
#
#		/window list
#
# To make your bindings permanent you will need to save the config and layout
# before quiting irssi:
#
# 		/save
# 		/layout save
#
#########
# OPTIONS
#########
#
# /set chanact_chop_status <ON|OFF>
#               * ON  : shorten (Status) to S
#               * OFF : don't do it
#
# /set chanact_sort <refnum|activity|level+refnum|level+activity>
#  	sort by ...
#		refnum		: refnum
#		activity	: last active window
#		level+refnum	: data_level of window, then refnum
#		level+activity	: data_level then activity
#
# /set chanact_display <string>
#		* string : Format String for one Channel. The following $'s are expanded:
#		    $C : Channel
#		    $N : Number of the Window
#		    $M : Mode in that channel
#		    $H : Start highlightning
#		    $S : Stop highlightning
#		* example:
#		
#		      /set chanact_display $H$N:$M.$S$C
#		      
#		    will give you on #irssi.de if you have voice
#		    
#		      [3:+.#irssi.de]
#
#		    with '3:+.' highlighted and the channel name printed in regular color
#
# /set chanact_display_alias <string>
#   as 'chanact_display' but is used if the window has an alias and
#   'chanact_show_alias' is set to on.
# 
# /set chanact_show_names <ON|OFF>
#		* ON  : show the channelnames after the number/alias
#		* OFF : don't show the names
#
# /set chanact_abbreviate_names <int>
#               * 0     : don't abbreviate
#               * <int> : strip channel name prefix character and leave only
#                         that many characters of the proper name
#
# /set chanact_show_alias <ON|OFF>
#		* ON  : show the aliase instead of the refnum
#		* OFF : shot the refnum
#
# /set chanact_header <str>
# 	* <str> : Characters to be displayed at the start of the item.
# 	          Defaults to: "Act: "
#
# /set chanact_separator <str>
#		* <str> : Charater to use between the channel entries
#
# /set chanact_autorenumber <ON|OFF>
#		* ON  : Move the window automatically to first available slot
#		        starting from "chanact_renumber_start" when assigning 
#		        an alias to window. Also moves the window back to a
#		        first available slot from refnum 1 when the window
#		        loses it's alias.
#		* OFF : Don't move the windows automatically
#
# /set chanact_renumber_start <int>
# 		* <int> : Move the window to first available slot after this
# 		          num when "chanact_autorenumber" is ON.
#
# /set chanact_remove_hash <ON|OFF>
# 		* ON  : Remove &#+!= from channel names
# 		* OFF : Don't touch channel names
#
# /set chanact_remove_prefix <string>
# 		* <string> : Regular expression used to remove from the
# 		             beginning of the channel name.
# 		* example  :
# 		    To shorten a lot of debian channels:
# 		    
# 			/set chanact_remove_prefix deb(ian.(devel-)?)?
#
# /set chanact_filter <int>
# 		* 0 : show all channels
# 		* 1 : hide channels without activity
# 		* 2 : hide channels with only join/part/etc messages
# 		* 3 : hide channels with text messages
# 		* 4 : hide all channels (now why would you want to do that)
#
# /set chanact_filter_windowlist <string>
#		* <string> : space-separated list of windows for which to use
#			     chanact_filter_windowlist_level instead of
#			     chanact_filter.
#			     
#			     Alternatively, an entry can be postfixed with
#			     a comma (',') and the level to use for that
#			     window.
#
#			     The special string @QUERIES matches all queries.
#
# /set chanact_filter_windowlist_level <int>
#   Use this level to filter all windows listed in chanact_filter_windowlist.
#   You can use these two settings to apply different filter levels to different
#   windows. Defaults to 0.
#
#########
# HINTS
#########
#
# If you have trouble with wrong colored entries your 'default.theme' might
# be too old. Try on a shell:
#
# 	$ mv ~/.irssi/default.theme /tmp/
#
# And in irssi:
#	/reload
#	/save
#
###
#################

my %show = (
	0 => "{%n ",			# NOTHING
	1 => "{sb_act_text ",		# TEXT
	2 => "{sb_act_msg ",		# MSG
	3 => "{sb_act_hilight ",	# HILIGHT
);

# comparison operators for our sort methods
my %sort = (
	'refnum'	=> '$a->{refnum} <=> $b->{refnum};',
	'activity'	=> '$b->{last_line} <=> $a->{last_line};',
	'level+refnum'	=> '$b->{data_level} <=> $a->{data_level} ||
				$a->{refnum} <=> $b->{refnum};',
	'level+activity'=> '$b->{data_level} <=> $a->{data_level} ||
				$b->{last_line} <=> $a->{last_line};',
);

my ($actString,$needRemake);

sub expand {
  my ($string, %format) = @_;
  my ($exp, $repl);
  $string =~ s/\$$exp/$repl/g while (($exp, $repl) = each(%format));
  return $string;
}

# method will get called every time the statusbar item will be displayed
# but we dont need to recreate the item every time so we first
# check if something has changed and only then we recreate the string
# this might just save some cycles
# FIXME implement $get_size_only check, and user $item->{min|max-size}
sub chanact {
	my ($item, $get_size_only) = @_;

	if ($needRemake) {
		remake();
	}
	
	$item->default_handler($get_size_only, $actString, undef, 1);
}

# build a hash to easily access special levels based on
# chanact_filter_windowlist
sub calculate_windowlist() {
	my @matchlist = split ' ', Irssi::settings_get_str('chanact_filter_windowlist');
	my $default = Irssi::settings_get_int('chanact_filter_windowlist_level');

	my %windowlist;
	foreach my $m (@matchlist) {
		my ($name, $level) = split(/,/, $m);
		$windowlist{$name} = $level ? $level : $default;
	}

	return %windowlist;
}

# calculate level per window
sub calculate_levels(@) {
	my (@windows) = @_;

	my %matches = calculate_windowlist();
	my $default = Irssi::settings_get_int('chanact_filter');

	my %levels;

	foreach my $win (@windows) {
		# FIXME we could use the next statements to weed out entries in
		# @windows that we will not need later on
		!ref($win) && next;

		my $name = $win->get_active_name;

		if (exists($matches{$name})) {
			$levels{$name} = $matches{$name};
		} else {
			$levels{$name} = $default;
		}
	}

	if (exists($matches{'@QUERIES'})) {
		$levels{'@QUERIES'} = $matches{'@QUERIES'};
	} else {
		$levels{'@QUERIES'} = $default;
	}

	return %levels;
}

# this is the real creation method
sub remake() {
	my ($afternumber,$finish,$hilight,$mode,$number,$display,@windows);
	my $separator = Irssi::settings_get_str('chanact_separator'); 
	my $abbrev = Irssi::settings_get_int('chanact_abbreviate_names');
	my $remove_prefix = Irssi::settings_get_str('chanact_remove_prefix');
	my $remove_hash = Irssi::settings_get_bool('chanact_remove_hash');

	my $method = $sort{Irssi::settings_get_str('chanact_sort')};
	@windows = sort { eval $method } Irssi::windows();

	my %levels = calculate_levels(@windows);

	$actString = "";
	foreach my $win (@windows) {
		# since irssi is single threaded this shouldn't happen
		!ref($win) && next;

		my $active = $win->{active};

		# define $type to emtpy string and overwrite if we do have an
		# active item. we need this to display windows without active
		# items e.g. '(status)'
		my $type = "";
		$type = $active->{type} if $active;

		my $name = $win->get_active_name;

		my $filter_level =
			$type eq 'QUERY' ? $levels{'@QUERIES'} : $levels{$name};

		# now, skip windows with data of level lower than the
		# filter level
		next if ($win->{data_level} < $filter_level);

		# alright, the activity is important, let's show the window
		# after a bit of additional processing.

		# (status) is an awfull long name, so make it short to 'S'
		# some people don't like it, so make it configurable
		if (Irssi::settings_get_bool('chanact_chop_status')
		    && $name eq "(status)") {
			$name = "S";
		}
	
		# check if we should show the mode
		$mode = "";
		if ($type eq "CHANNEL") {
			my $server = $win->{active_server};
			!ref($server) && next;

			my $channel = $server->channel_find($name);
			!ref($channel) && next;

			my $nick = $channel->nick_find($server->{nick});
			!ref($nick) && next;
			
			if ($nick->{op}) {
				$mode = "@";
			} elsif ($nick->{voice}) {
				$mode = "+";
			} elsif ($nick->{halfop}) {
				$mode = "%";
			}
		}

		# in case we have a specific hilightcolor use it
		if ($win->{hilight_color}) {
			$hilight = "{sb_act_hilight_color $win->{hilight_color} ";
		} else {
			$hilight = $show{$win->{data_level}};
		}

		if ($remove_prefix) {
			$name =~ s/^([&#+!=]?)$remove_prefix/$1/;
		}
		if ($abbrev) {
			if ($name =~ /^[&#+!=]/) {
				$name = substr($name, 1, $abbrev + 1);
			} else {
				$name = substr($name, 0, $abbrev);
			}
		}
		if ($remove_hash) {
			$name =~ s/^[&#+!=]//;
		}

		if (Irssi::settings_get_bool('chanact_show_alias') == 1 && 
				$win->{name} =~ /^([a-zA-Z+]):(.+)$/) {
			$number = "$1";
			$display = Irssi::settings_get_str('chanact_display_alias'); 
		} else {
			$number = $win->{refnum};
			$display = Irssi::settings_get_str('chanact_display'); 
		}

		# fixup { and } in nicks, those are used by irssi themes
		$name =~ s/([{}])/%$1/g;

		$actString .= expand($display,"C",$name,"N",$number,"M",$mode,"H",$hilight,"S","}{sb_background}").$separator;
	}

	# assemble the final string
	if ($actString ne "") {
		# Remove the last separator
		$actString =~ s/$separator$//;
		
		$actString = "{sb ".Irssi::settings_get_str('chanact_header').$actString."}";
	}

	# no remake needed any longer
	$needRemake = 0;
}

# method called because of some events. here we dont remake the item but just
# remember that we have to remake it the next time we are called
sub chanactHasChanged()
{
	# if needRemake is already set, no need to trigger a redraw as we will
	# be redrawing the item anyway.
	return if $needRemake;

	$needRemake = 1;

	Irssi::statusbar_items_redraw('chanact');
}

sub setup_changed {
	my $method = Irssi::settings_get_str('chanact_sort');

	unless (exists($sort{$method})) {
		Irssi::print("chanact: invalid sort method, setting to 'refnum'."
			." valid methods are: ".join(", ", sort(keys(%sort))));
		my $method = Irssi::settings_set_str('chanact_sort', 'refnum');
	}

	chanactHasChanged();
}

# Remove alias
sub cmd_window_unalias {
	my ($data, $server, $witem) = @_;

	if ($data ne '') {
		Irssi::print("chanact: /window_unalias does not take any ".
			"parameters, Run it in the window you want to unalias");
		return;
	}

	my $win = Irssi::active_win();
	my $name = Irssi::active_win()->{name};

	# chanact'ified windows have a name like this: X:servertag/name
	my ($key, $tag) = split(/:/, $name);
	($tag, $name) = split('/', $tag);

	# remove alias only of we have a single character keybinding, if we
	# haven't the name was not set by chanact, so we won't blindly unset
	# stuff
	if (length($key) == 1) {
		$server->command("/bind -delete meta-$key");
	} else {
		Irssi::print("chanact: could not determine keybinding. ".
			"Won't unbind anything");
	}

	# set the windowname back to it's old one. We don't bother checking
	# for a vaild name here, as we want to remove the current one and if
	# worse comes to wors set an empty one.
	$win->set_name($name);

	# if autorenumbering is off, we are done.
	return unless (Irssi::settings_get_bool('chanact_autorenumber'));

	# we are renumbering, so move the window to the lowest available
	# refnum.
	my $refnum = 1;
	while (Irssi::window_find_refnum($refnum) ne "") {
		$refnum++;
	}

	$win->set_refnum($refnum);
	Irssi::print("chanact: moved wintow to refnum $refnum");
}

# function by veli@piipiip.net
# Make an alias
sub cmd_window_alias {
	my ($data, $server, $witem) = @_;
	my $rn_start = Irssi::settings_get_int('chanact_renumber_start');

	unless ($data =~ /^[a-zA-Z+]$/) {
		Irssi::print("Usage: /window_alias <char>");
		return;
	}

	# in case of an itemless window $witem is undef, thus future operations
	# on it fail. to prevent this we pull in the current window.
	#
	# Also we need to initialize $winname, else we would get a broken name:
	#
	#	'name' => 'S:IRCnet/S:IRCnet/',
	#
	my $window;
	my $winname = "";
	if (defined($witem)) {
		$window = $witem->window();
		$winname = $witem->{name};
	} else {
		$window = Irssi::active_win();
		$winname = $window->{name};
	}

	cmd_window_unalias($data, $server, $witem);

	my $winnum = $window->{refnum};
	
	if (Irssi::settings_get_bool('chanact_autorenumber') == 1 &&
			$window->{refnum} < $rn_start) {
		my $old_refnum = $window->{refnum};

		$winnum = $rn_start;
 
		# Find the first available slot and move the window
		while (Irssi::window_find_refnum($winnum) ne "") { $winnum++; }
		$window->set_refnum($winnum);
		
		Irssi::print("Moved the window from $old_refnum to $winnum");
	}
	
	my $winserver = $window->{active_server}->{tag};
	my $winhandle = "$winserver/$winname";
	# cmd_window_unalias relies on a certain format here
	my $name = "$data:$winhandle";

	$window->set_name($name);
	$server->command("/bind meta-$data change_window $name");
	Irssi::print("Window $winhandle is now accessible with meta-$data");
}

$needRemake = 1;

# Window alias command
Irssi::command_bind('window_alias','cmd_window_alias');
Irssi::command_bind('window_unalias','cmd_window_unalias');

# our config item
Irssi::settings_add_str('chanact', 'chanact_display', '$H$N:$M$C$S');
Irssi::settings_add_str('chanact', 'chanact_display_alias', '$H$N$M$S');
Irssi::settings_add_int('chanact', 'chanact_abbreviate_names', 0);
Irssi::settings_add_bool('chanact', 'chanact_show_alias', 1);
Irssi::settings_add_str('chanact', 'chanact_separator', " ");
Irssi::settings_add_bool('chanact', 'chanact_autorenumber', 0);
Irssi::settings_add_bool('chanact', 'chanact_remove_hash', 0);
Irssi::settings_add_str('chanact', 'chanact_remove_prefix', "");
Irssi::settings_add_int('chanact', 'chanact_renumber_start', 50);
Irssi::settings_add_str('chanact', 'chanact_header', "Act: ");
Irssi::settings_add_bool('chanact', 'chanact_chop_status', 1);
Irssi::settings_add_str('chanact', 'chanact_sort', 'refnum');
Irssi::settings_add_int('chanact', 'chanact_filter', 0);
Irssi::settings_add_str('chanact', 'chanact_filter_windowlist', "");
Irssi::settings_add_int('chanact', 'chanact_filter_windowlist_level', 0);

# register the statusbar item
Irssi::statusbar_item_register('chanact', '$0', 'chanact');
# according to cras we shall not call this
# Irssi::statusbars_recreate_items();

# register all that nifty callbacks on special events
Irssi::signal_add_last('setup changed', 'setup_changed');
Irssi::signal_add_last('window changed', 'chanactHasChanged');
Irssi::signal_add_last('window item changed', 'chanactHasChanged');
Irssi::signal_add_last('window hilight', 'chanactHasChanged');
Irssi::signal_add_last('window item hilight', 'chanactHasChanged');
Irssi::signal_add("window created", "chanactHasChanged");
Irssi::signal_add("window destroyed", "chanactHasChanged");
Irssi::signal_add("window name changed", "chanactHasChanged");
Irssi::signal_add("window activity", "chanactHasChanged");
Irssi::signal_add("print text", "chanactHasChanged");
Irssi::signal_add('nick mode changed', 'chanactHasChanged');

###############
###
#
# Changelog
#
# 0.5.14
# 	- fix itemless window handling, thx Bazerka
# 	- fix /window_alias for itemless windows
# 	- fix /window_unalias. Also longer takes an argument
# 	- added sorting by level, based on patch by Bazerka
# 		+ retired chanact_sort_by_activity, integrated in chanact_sort
#
# 0.5.13
# 	- trivial cleanup in cmd_window_alias()
# 	- updated documentation regarding /layout save, thx Bazerka
# 	- removed cmd_rebuild_aliases(), no longer working since we use channel
# 	  names to select windows and not refnums
# 	- removed refnum_changed(), see cmd_rebuild_aliases() above
#
# 0.5.12
# 	- Use comma instead of colon as windowlist separator, patch by martin f.
# 	  krafft, reported by James Vega
#
# 0.5.11
#	- added chanact_filter_windowlist based on a patch by madduck@madduck.net
# 	- fixed display error for nicks/channels with { or } in them
# 	- fixed chanact_header, was hidden behind chanact_filter
# 	- fixed documentation
# 		+ removed chanact_show_mode, long gone
#
# 0.5.10
# 	- fixed irssi crash when using Irssi::print from within remake()
#       - added option to filter out some data levels, based on a patch by
#         Juergen Jung <juergen@Winterkaelte.de>, see
#         https://bc-bd.org/trac/irssi/ticket/15
#         	+ retired chanact_show_all in favour of chanact_filter
#
# 0.5.9
# 	- changes by stefan voelkel
# 		+ sort channels by activity, see
# 		  https://bc-bd.org/trac/irssi/ticket/5, based on a patch by jan
# 		  krueger
# 		+ fixed chrash on /exec -interactive, see
# 		https://bc-bd.org/trac/irssi/ticket/7
#
# 	- changes by Jan 'jast' Krueger <jast@heapsort.de>, 2004-06-22
# 		+ updated documentation in script's comments
#
# 	- changes by Ivo Timmermans <ivo@o2w.nl>
# 		+ honor actcolor /hilight setting if present
#
# 0.5.8
# - made aliases case-sensitive and include network in channel names by madduck
#
# 0.5.7
# - integrated remove patch by Christoph Berg <myon@debian.org>
#
# 0.5.6
# - fixed a bug (#1) reported by Wouter Coekaert
# 
# 0.5.5
# - some speedups from David Leadbeater <dgl@dgl.cx>
# 
#
# 0.5.4
# - added help for chanact_display_alias
#
# 0.5.3
# - added '+' to the available chars of aliase's
# - added chanact_display_alias to allow different display modes if the window
#   has an alias
#
# 0.5.2
# - removed unused chanact_show_name settings (thx to Qerub)
# - fixed $mode display
# - guarded reference operations to (hopefully) fix errors on server disconnect
# 
# 0.5.1
# - small typo fixed
#
# 0.5.0
# - changed chanact_show_mode to chanact_display. reversed changes from
#   Qerub through that, but kept funcionality.
# - removed chanact_color_all since it is no longer needed
# 
# 0.4.3
# - changes by Qerub
#   + added chanact_show_mode to show the mode just before the channel name
#   + added chanact_chop_status to be able to control the (status) chopping
#     [bd] minor implementation changes
# - moved Changelog to the end of the file since it is getting pretty big
#
# 0.4.2
# - changed back to old version numbering sheme
# - added '=' to Qrczak's chanact_abbreviate_names stuff :)
# - added chanact_header
#
# 0.41q
#	- changes by Qrczak
#		+ added setting 'chanact_abbreviate_names'
#		+ windows are sorted by refnum; I didn't understand the old
#		  logic and it broke sorting for numbers above 9
#
# 0.41
#	- minor updates
#		+ fixed channel sort [veli]
#		+ removed few typos and added some documentation [veli]
#
# 0.4
#	- merge with window_alias.pl
#		+ added /window_alias from window_alias.pl by veli@piipiip.net
#		+ added setting 'chanact_show_alias'
#		+ added setting 'chanact_show_names'
#		+ changed setting 'chanact_show_mode' to int
#		+ added setting 'chanact_separator' [veli]
#		+ added setting 'chanact_autorenumber' [veli]
#		+ added setting 'chanact_renumber_start' [veli]
#		+ added /window_unalias [veli]
#		+ moved setting to their own group 'chanact' [veli]
#
# 0.3
#	- merge with chanlist.pl
#		+ added setting 'chanact_show_mode'
#		+ added setting 'chanact_show_all'
#
# 0.2
#	- added 'Act' to the item
#		- added setting 'chanact_color_all'
#		- finally found format for statusbar hilight
#
# 0.1
#	- Initial Release
#
###
################
