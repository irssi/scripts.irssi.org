use strict; # use warnings;

# FIXME COULD SOMEONE PLEASE TELL ME HOW TO SHUT UP
#
# ...
# Variable "*" will not stay shared at (eval *) line *.
# Variable "*" will not stay shared at (eval *) line *.
# ...
# Can't locate package Irssi::Nick for @Irssi::Irc::Nick::ISA at (eval *) line *.
# ...
#
# THANKS

use Irssi (); # which is the minimum required version of Irssi ?
use Irssi::TextUI;

use vars qw($VERSION %IRSSI);

$VERSION = '0.5';
%IRSSI = (
    authors     => 'BC-bd, Veli, Timo \'cras\' Sirainen, Wouter Coekaerts, Nei',
    contact     => 'bd@bc-bd.org, veli@piipiip.net, tss@iki.fi, wouter@coekaerts.be, Nei@QuakeNet',
    name        => 'wlstat',
    description => 'Adds a window list in the status area. Based on chanact.pl by above authors.',
    license     => 'GNU GPLv2 or later',
);

# adapted by Nei

###############
# original comment
# ###########
# # Adds new powerful and customizable [Act: ...] item (chanelnames,modes,alias).
# # Lets you give alias characters to windows so that you can select those with
# # meta-<char>.
# #
# # for irssi 0.8.2 by bd@bc-bd.org
# #
# # inspired by chanlist.pl by 'cumol@hammerhart.de'
# #
# #########
# # Contributors
# #########
# #
# # veli@piipiip.net   /window_alias code
# # qrczak@knm.org.pl  chanact_abbreviate_names
# # qerub@home.se      Extra chanact_show_mode and chanact_chop_status
# #
#
# FURTHER THANKS TO
# ############
# # buu, fxn, Somni, Khisanth, integral, tybalt89   for much support in any aspect perl
# # and the channel in general ( #perl @ freenode ) and especially the ir_* functions
# #
# # Valentin 'senneth' Batz ( vb@g-23.org ) for the pointer to grep.pl, continuous support
# #                                         and help in digging up ir_strip_codes
# #
# # OnetrixNET technology networks for the debian environment
# #
# # Monkey-Pirate.com / Spaceman Spiff for the webspace
# #
#

######
# M A I N    P R O B L E M
#####
#
# It is impossible to place the wlstat on a statusbar together with other items, because I
# do not know how to calculate the size that it is going to get granted, and therefore I
# cannot do the linebreaks properly.
# This is what is missing to make a nice script out of wlstat.
# If you have any ideas, please contact me ASAP :).
#
######

######
# UTF-8 PROBLEM
#####
#
# Please help me find a solution to this:
# this be your statusbar, it is using up the maximum term size
# [[1=1]#abc [2=2]#defghi]
# 
# now consider this example: "ascii" characters are marked with ., utf-8 characters with *
# [[1=1]#... [2=2]#...***]
#
# you should think that this is how it would be displayed? WRONG!
# [[1=1]#... [2=2]#...***   ]
#
# this is what Irssi does.. I believe my length calculating code to be correct, however, I'd
# love to be proven wrong (or receive any other fix, too, of course!)
#
######

#########
# USAGE
###
#
# copy the script to ~/.irssi/scripts/
#
# In irssi:
#
#		/script load wlstat
#
#
# Hint: to get rid of the old [Act:] display
#     /statusbar window remove act
#
# to get it back:
#     /statusbar window add -after lag -priority 10 act
#
##########
# OPTIONS
########
#
# /set wlstat_display_nokey <string>
# /set wlstat_display_key <string>
#		* string : Format String for one window. The following $'s are expanded:
#		    $C : Name
#		    $N : Number of the Window
#		    $Q : meta-Keymap
#		    $H : Start highlighting
#		    $S : Stop highlighting
#     IMPORTANT: don't forget to use $S if you used $H before!
#
# /set wlstat_separator <string>
#     * string : Charater to use between the channel entries
#     you'll need to escape " " space and "$" like this:
#     "/set wlstat_separator \ "
#     "/set wlstat_separator \$"
#     and {}% like this:
#     "/set wlstat_separator %{"
#     "/set wlstat_separator %}"
#     "/set wlstat_separator %%"
#     (reason being, that the separator is used inside a {format })
#
# /set wlstat_hide_data <num>
#     * num : hide the window if its data_level is below num
#     set it to 0 to basically disable this feature,
#               1 if you don't want windows without activity to be shown
#               2 to show only those windows with channel text or hilight
#               3 to show only windows with hilight
#
# /set wlstat_maxlines <num>
#     * num : number of lines to use for the window list (0 to disable)
#
# /set wlstat_sort <-data_level|-last_line|refnum>
#     * you can change the window sort order with this variable
#         -data_level : sort windows with hilight first
#         -last_line  : sort windows in order of activity
#         refnum      : sort windows by window number
#
# /set wlstat_placement <top|bottom>
# /set wlstat_position <num>
#     * these settings correspond to /statusbar because wlstat will create
#       statusbars for you
#     (see /help statusbar to learn more)
#
# /set wlstat_all_disable <ON|OFF>
#     * if you set wlstat_all_disable to ON, wlstat will also remove the
#       last statusbar it created if it is empty.
#       As you might guess, this only makes sense with wlstat_hide_data > 0 ;)
#
###
# WISHES
####
#
# if you fiddle with my mess, provide me with your fixes so I can benefit as well
#
# Nei =^.^= ( QuakeNet accountname: ailin )
#

my $actString = [];   # statusbar texts
my $currentLines = 0;
my $resetNeeded;      # layout/screen has changed, redo everything
my $needRemake;       # "normal" changes
#my $callcount = 0;
my $globTime = undef; # timer to limit remake() calls

my %statusbars;       # currently active statusbars

# maybe I should just tie the array ?
sub add_statusbar {
	for (@_) {
		# add subs
		for my $l ($_) { eval {
			no strict 'refs'; # :P
			*{"wlstat$l"} = sub { wlstat($l, @_) };
		}; }
		Irssi::command("statusbar wl$_ reset");
		Irssi::command("statusbar wl$_ enable");
		if (lc Irssi::settings_get_str('wlstat_placement') eq 'top') {
			Irssi::command("statusbar wl$_ placement top");
		}
		if ((my $x = int Irssi::settings_get_int('wlstat_position')) != 0) {
			Irssi::command("statusbar wl$_ position $x");
		}
		Irssi::command("statusbar wl$_ add -priority 100 -alignment left barstar");
		Irssi::command("statusbar wl$_ add wlstat$_");
		Irssi::command("statusbar wl$_ add -priority 100 -alignment right barend");
		Irssi::command("statusbar wl$_ disable");
		Irssi::statusbar_item_register("wlstat$_", '$0', "wlstat$_");
		$statusbars{$_} = {};
	}
}

sub remove_statusbar {
	for (@_) {
		Irssi::command("statusbar wl$_ reset");
		Irssi::statusbar_item_unregister("wlstat$_"); # XXX does this actually work ?
		# DO NOT REMOVE the sub before you have unregistered it :))
		for my $l ($_) { eval {
			no strict 'refs';
			undef &{"wlstat$l"};
		}; }
		delete $statusbars{$_};
	}
}

sub syncLines {
	my $temp = $currentLines;
	$currentLines = @$actString;
	#Irssi::print("current lines: $temp new lines: $currentLines");
	my $currMaxLines = Irssi::settings_get_int('wlstat_maxlines');
	if ($currMaxLines > 0 and @$actString > $currMaxLines) {
		$currentLines = $currMaxLines;
	}
	return if ($temp == $currentLines);
	if ($currentLines > $temp) {
		for ($temp .. ($currentLines - 1)) {
			add_statusbar($_);
			Irssi::command("statusbar wl$_ enable");
		}
	}
	else {
		for ($_ = ($temp - 1); $_ >= $currentLines; $_--) {
			Irssi::command("statusbar wl$_ disable");
			remove_statusbar($_);
		}
	}
}

my %keymap;

sub get_keymap {
	my ($textDest, undef, $cont_stripped) = @_;
	if ($textDest->{'level'} == 524288 and $textDest->{'target'} eq '' and !defined($textDest->{'server'})) {
		if ($cont_stripped =~ m/meta-(.)\s+change_window (\d+)/) { $keymap{$2} = "$1"; }
		Irssi::signal_stop();
	}
}

sub update_keymap {
	%keymap = ();
	Irssi::signal_remove('command bind' => 'watch_keymap');
	Irssi::signal_add_first('print text' => 'get_keymap');
	Irssi::command('bind'); # stolen from grep
	Irssi::signal_remove('print text' => 'get_keymap');
	Irssi::signal_add('command bind' => 'watch_keymap');
	Irssi::timeout_add_once(100, 'eventChanged', undef);
}

# watch keymap changes
sub watch_keymap {
	Irssi::timeout_add_once(1000, 'update_keymap', undef);
}

update_keymap();

sub expand {
	my ($string, %format) = @_;
	my ($exp, $repl);
	$string =~ s/\$$exp/$repl/g while (($exp, $repl) = each(%format));
	return $string;
}

# FIXME implement $get_size_only check, and user $item->{min|max-size} ??
sub wlstat {
	my ($line, $item, $get_size_only) = @_;

	if ($needRemake) {
		$needRemake = undef;
		remake();
	}

	my $text = $actString->[$line];  # DO NOT set the actual $actString->[$line] to '' here or
	$text = '' unless defined $text; # you'll screw up the statusbar counter ($currentLines)
	$item->default_handler($get_size_only, $text, '', 1);
}

my %strip_table = (
	# fe-common::core::formats.c:format_expand_styles
	#      delete                format_backs  format_fores bold_fores   other stuff
	(map { $_ => '' } (split //, '04261537' .  'kbgcrmyw' . 'KBGCRMYW' . 'U9_8:|FnN>#[')),
	#      escape
	(map { $_ => $_ } (split //, '{}%')),
);
sub ir_strip_codes { # strip %codes
	my $o = shift;
	$o =~ s/(%(.))/exists $strip_table{$2} ? $strip_table{$2} : $1/gex;
	$o
}

sub ir_parse_special {
	my $o; my $i = shift;
	my $win = Irssi::active_win();
	my $server = Irssi::active_server();
	if (ref $win and ref $win->{'active'}) {
		$o = $win->{'active'}->parse_special($i);
	}
	elsif (ref $win and ref $win->{'active_server'}) {
		$o = $win->{'active_server'}->parse_special($i);
	}
	elsif (ref $server) {
		$o =  $server->parse_special($i);
	}
	else {
		$o = Irssi::parse_special($i);
	}
	$o
}

sub sb_expand { # expand {format }s (and apply parse_special for $vars)
	ir_parse_special(
		Irssi::current_theme->format_expand(
			shift,
			(
				Irssi::EXPAND_FLAG_IGNORE_REPLACES
					|
				Irssi::EXPAND_FLAG_IGNORE_EMPTY
			)
		)
	)
}
sub sb_strip {
	ir_strip_codes(
		sb_expand(shift)
	); # does this get us the actual length of that s*ty bar :P ?
}
sub sb_length {
	# unicode cludge, d*mn broken Irssi
	# screw it, this will fail from broken joining anyway (and cause warnings)
	if (lc Irssi::settings_get_str('term_type') eq 'utf-8') {
		my $temp = sb_strip(shift);
		# try to switch on utf8
		eval {
			no warnings;
			require Encode;
			#$temp = Encode::decode_utf8($temp); # thanks for the hint, but I have my reasons for _utf8_on
			Encode::_utf8_on($temp);
		};
		length($temp)
	}
	else {
		length(sb_strip(shift))
	}
}

# !!! G*DD*MN Irssi is adding an additional layer of backslashitis per { } layer
# !!! AND I still don't know what I need to escape.
# !!! and NOONE else seems to know or care either.
# !!! f*ck open source. I mean it.
# XXX any Irssi::print debug statement leads to SEGFAULT - why ?

# major parts of the idea by buu (#perl @ freenode)
# thanks to fxn and Somni for debugging
#	while ($_[0] =~ /(.)/g) {
#		my $c = $1; # XXX sooo... goto kills $1
#		if ($q eq '%') { goto ESC; }

## <freenode:#perl:tybalt89> s/%(.)|(\{)|(\})|(\\|\$)/$1?$1:$2?($level++,$2):$3?($level>$min_level&&$level--,$3):'\\'x(2**$level-1).$4/ge;  # untested...
sub ir_escape {
	my $min_level = $_[1] || 0; my $level = $min_level;
	my $o = shift;
	$o =~ s/
		(	%.	)	| # $1
		(	\{	)	| # $2
		(	\}	)	| # $3
		(	\\	)	| # $4
		(	\$(?=.)	)	| # $5
		(	\$	) # $6
	/
		if ($1) { $1 } # %. escape
		elsif ($2) { $level++; $2 } # { nesting start
		elsif ($3) { if ($level > $min_level) { $level--; } $3 } # } nesting end
		elsif ($4) { '\\'x(2**$level) } # \ needs \\escaping
		elsif ($5) { '\\'x(2**$level-1) . '$' . '\\'x(2**$level-1) } # and $ needs even more because of "parse_special"
		else { '\\'x(2**$level-1) . '$' } # $ needs \$ escaping
	/gex;
	$o
}
#sub ir_escape {
#	my $min_level = $_[1] || 0; my $level = $min_level;
#	my $o = shift;
#	$o =~ s/
#		(	%.	)	| # $1
#		(	\{	)	| # $2
#		(	\}	)	| # $3
#		(	\\	|	\$	)	# $4
#	/
#		if ($1) { $1 } # %. escape
#		elsif ($2) { $level++; $2 } # { nesting start
#		elsif ($3) { if ($level > $min_level) { $level--; } $3 } # } nesting end
#		else { '\\'x(2**($level-1)-1) . $4 } # \ or $ needs \\escaping
#	/gex;
#	$o
#}

sub ir_fe { # try to fix format stuff
	my $x = shift;
	# XXX why do I have to use two/four % here instead of one/two ?? answer: you screwed up in ir_escape
	$x =~ s/([%{}])/%$1/g;
	$x =~ s/(\\|\$)/\\$1/g;
	#$x =~ s/(\$(?=.))|(\$)/$1?"\\\$\\":"\\\$"/ge; # I think this should be here (logic), but it doesn't work that way :P
	#$x =~ s/\\/\\\\/g; # that's right, escape escapes
	$x
}

sub remake () {
	#$callcount++;
	#my $xx = $callcount; Irssi::print("starting remake [ $xx ]");
	my ($hilight, $number, $display);
	my $separator = '{sb_act_sep ' . Irssi::settings_get_str('wlstat_separator') . '}';
	my $custSort = Irssi::settings_get_str('wlstat_sort');
	my $custSortDir = 1;
	if ($custSort =~ /^[-!](.*)/) {
		$custSortDir = -1;
		$custSort = $1;
	}

	$actString = [];
	my ($line, $width) = (0, [Irssi::windows]->[0]{'width'} - sb_length('{sb x}'));
	foreach my $win (
		sort {
			(
				( (int($a->{$custSort}) <=> int($b->{$custSort})) * $custSortDir )
					||
				($a->{'refnum'} <=> $b->{'refnum'})
			)
		} Irssi::windows
	) {
		$actString->[$line] = '' unless defined $actString->[$line] or Irssi::settings_get_bool('wlstat_all_disable');

		# all stolen from chanact, what does this code do and why do we need it ?
		!ref($win) && next;

		my $name = $win->get_active_name;
		my $active = $win->{'active'};
		my $colour = $win->{'hilight_color'};
		if (!defined $colour) { $colour = ''; }

		if ($win->{'data_level'} < Irssi::settings_get_int('wlstat_hide_data')) { next; } # for Geert
		if    ($win->{'data_level'} == 0) { $hilight = '{sb_act_none '; }
		elsif ($win->{'data_level'} == 1) { $hilight = '{sb_act_text '; }
		elsif ($win->{'data_level'} == 2) { $hilight = '{sb_act_msg '; }
		elsif ($colour             ne '') { $hilight = "{sb_act_hilight_color $colour "; }
		elsif ($win->{'data_level'} == 3) { $hilight = '{sb_act_hilight '; }
		else                              { $hilight = '{sb_act_special '; }

		$number = $win->{'refnum'};
		$display = (defined $keymap{$number} and $keymap{$number} ne '')
				?
			(
				Irssi::settings_get_str('wlstat_display_key')
					||
				Irssi::settings_get_str('wlstat_display_nokey')
			)
				:
			Irssi::settings_get_str('wlstat_display_nokey')
		;

		my $add = expand($display,
			C => ir_fe($name),
			N => $number,
			Q => ir_fe($keymap{$number}),
			H => $hilight,
			S => '}{sb_background}'
		);
		#$temp =~ s/\{\S+?(?:\s(.*?))?\}/$1/g;
		#$temp =~ s/\\\\\\\\/\\/g; # XXX I'm actually guessing here, someone point me to docs please
		$actString->[$line] = '' unless defined $actString->[$line];

		# XXX how can I check whether the content still fits in the bar? this would allow
		# XXX wlstatus to reside on a statusbar together with other items...
		if (sb_length(ir_escape($actString->[$line] . $add)) >= $width) { # XXX doesn't correctly handle utf-8 multibyte ... help !!?
			$actString->[$line] .= ' ' x ($width - sb_length(ir_escape($actString->[$line])));
			$line++;
		}
		$actString->[$line] .= $add . $separator;
		# XXX if I use these prints, output layout gets screwed up... why ?
		#Irssi::print("line $line: ".$actString->[$line]);
		#Irssi::print("temp $line: ".$temp);
	}

	# XXX the Irssi::print statements lead to the MOST WEIRD results
	# e.g.: the loop gets executed TWICE for p > 0 ?!?
	for (my $p = 0; $p < @$actString; $p++) { # wrap each line in {sb }, escape it properly, etc.
		my $x = $actString->[$p];
		$x =~ s/\Q$separator\E([ ]*)$/$1/;
		#Irssi::print("[$p]".'current:'.join'.',split//,sb_strip(ir_escape($x,0)));
		#Irssi::print("assumed length before:".sb_length(ir_escape($x,0)));
		$x = "{sb $x}";
		#Irssi::print("[$p]".'new:'.join'.',split//,sb_expand(ir_escape($x,0)));
		#Irssi::print("[$p]".'new:'.join'.',split//,ir_escape($x,0));
		#Irssi::print("assumed length after:".sb_length(ir_escape($x,0)));
		$x = ir_escape($x);
		#Irssi::print("[$p]".'REALnew:'.join'.',split//,sb_strip($x));
		$actString->[$p] = $x;
		# XXX any Irssi::print debug statement leads to SEGFAULT (sometimes) - why ?
	}
	#Irssi::print("remake [ $xx ] finished");
}

sub wlstatHasChanged () {
	$globTime = undef;
	my $temp = Irssi::settings_get_str('wlstat_placement').Irssi::settings_get_int('wlstat_position');
	if ($temp ne $resetNeeded) { wlreset(); return; }
	#Irssi::print("wlstat has changed, calls to remake so far: $callcount");
	$needRemake = 1;

	#remake();
	if (
		($needRemake and Irssi::settings_get_bool('wlstat_all_disable'))
			or
		(!Irssi::settings_get_bool('wlstat_all_disable') and $currentLines < 1)
	) {
		$needRemake = undef;
		remake();
	}
	# XXX Irssi crashes if I try to do this without timer, why ? What's the minimum delay I need to use in the timer ?
	Irssi::timeout_add_once(100, 'syncLines', undef);

	for (keys %statusbars) {
		Irssi::statusbar_items_redraw("wlstat$_");
	}
}

sub eventChanged () { # Implement a change queue/blocker -.-)
	if (defined $globTime) {
		Irssi::timeout_remove($globTime);
	} # delay the update further
	$globTime = Irssi::timeout_add_once(10, 'wlstatHasChanged', undef);
}

#$needRemake = 1;
sub resizeTerm () {
	Irssi::timeout_add_once(100, 'eventChanged', undef);
}

Irssi::settings_add_str('wlstat', 'wlstat_display_nokey', '[$N]$H$C$S');
Irssi::settings_add_str('wlstat', 'wlstat_display_key', '[$Q=$N]$H$C$S');
Irssi::settings_add_str('wlstat', 'wlstat_separator', "\\ ");
Irssi::settings_add_int('wlstat', 'wlstat_hide_data', 0);
Irssi::settings_add_int('wlstat', 'wlstat_maxlines', 9);
Irssi::settings_add_str('wlstat', 'wlstat_sort', 'refnum');
Irssi::settings_add_str('wlstat', 'wlstat_placement', 'bottom');
Irssi::settings_add_int('wlstat', 'wlstat_position', 0);
Irssi::settings_add_bool('wlstat', 'wlstat_all_disable', 0);

# remove old statusbars
my %killBar;
sub get_old_status {
	my ($textDest, $cont, $cont_stripped) = @_;
	if ($textDest->{'level'} == 524288 and $textDest->{'target'} eq '' and !defined($textDest->{'server'})) {
		if ($cont_stripped =~ m/^wl(\d+)\s/) { $killBar{$1} = {}; }
		Irssi::signal_stop();
	}
}
sub killOldStatus {
	%killBar = ();
	Irssi::signal_add_first('print text' => 'get_old_status');
	Irssi::command('statusbar');
	Irssi::signal_remove('print text' => 'get_old_status');
	remove_statusbar(keys %killBar);
}
#killOldStatus();

sub wlreset {
	$actString = [];
	$currentLines = 0; # 1; # mhmmmm .. we actually enable one line down there so let's try this.
	$resetNeeded = Irssi::settings_get_str('wlstat_placement').Irssi::settings_get_int('wlstat_position');
	#update_keymap();
	killOldStatus();
	# Register statusbar
	#add_statusbar(0);
	#Irssi::command('statusbar wl0 enable');
	resizeTerm();
}

wlreset();

my $Unload;
sub unload ($$$) {
	$Unload = 1;
	Irssi::timeout_add_once(10, sub { $Unload = undef; }, undef); # pretend we didn't do anything ASAP
}
Irssi::signal_add_first('gui exit' => sub { $Unload = undef; }); # last try to catch a sigsegv
sub UNLOAD {
	if ($Unload) { # this might well crash Irssi... try /eval /script unload someotherscript ; /quit (= SEGFAULT !)
		$actString = ['']; # syncLines(); # XXX Irssi crashes when trying to disable all statusbars ?
		killOldStatus();
	}
}

sub addPrintTextHook { # update on print text
	return if $_[0]->{'level'} == 262144 and $_[0]->{'target'} eq '' and !defined($_[0]->{'server'});
	if (Irssi::settings_get_str('wlstat_sort') =~ /^[-!]?last_line$/) {
		Irssi::timeout_add_once(100, 'eventChanged', undef);
	}
}

#sub _x { my ($x, $y) = @_; ($x, sub { Irssi::print('-->signal '.$x); eval "$y();"; }) }
#sub _x { @_ }
Irssi::signal_add_first(
	'command script unload' => 'unload'
);
Irssi::signal_add_last({
	'setup changed' => 'eventChanged',
	'print text' => 'addPrintTextHook',
	'terminal resized' => 'resizeTerm',
	'setup reread' => 'wlreset',
	'window hilight' => 'eventChanged',
});
Irssi::signal_add({
	'window created' => 'eventChanged',
	'window destroyed' => 'eventChanged',
	'window name changed' => 'eventChanged',
	'window refnum changed' => 'eventChanged',
	'window changed' => 'eventChanged',
	'window changed automatic' => 'eventChanged',
});

#Irssi::signal_add('nick mode changed', 'chanactHasChanged'); # relicts

###############
###
#
# Changelog
#
# 0.5a
# - add setting to also hide the last statusbar if empty (wlstat_all_disable)
# - reverted to old utf8 code to also calculate broken utf8 length correctly
# - simplified dealing with statusbars in wlreset
# 
# 0.4d
# - fixed order of disabling statusbars
# - several attempts at special chars, without any real success
#   and much more weird new bugs caused by this
# - setting to specify sort order
# - reduced timeout values
# - added wlstat_hide_data for Geert Hauwaerts ( geert@irssi.org ) :)
# - make it so the dynamic sub is actually deleted
# - fix a bug with removing of the last separator
# - take into consideration parse_special
# 
# 0.3b
# - automatically kill old statusbars
# - reset on /reload
# - position/placement settings
#
# 0.2
# - automated retrieval of key bindings (thanks grep.pl authors)
# - improved removing of statusbars
# - got rid of status chop
#
# 0.1
# - rewritten to suit my needs
# - based on chanact 0.5.5

