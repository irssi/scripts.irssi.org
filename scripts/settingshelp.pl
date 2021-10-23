use strict;
use warnings;
use Irssi;

our $VERSION = '1.4.0'; # 8d8dcd26fee5309
our %IRSSI = (
    authors     => 'Rocco Caputo (dngor), Nei',
    contact     => 'rcaputo@cpan.org, Nei @ anti@conference.jabber.teamidiot.de',
    name        => 'settingshelp',
    description => "Irssi settings notes and documentation",
    license     => 'CC BY-SA 2.5, http://creativecommons.org/licenses/by-sa/2.5/',
   );

# Usage
# =====
# Now you can do:
#
#   /help set setting_here
#
# to print out its documentation (as far as it was documented)


my %help;

{
    my $res = load_help();
    my @res = split "\n", $res if defined $res;
    while (@res) {
	my @info;
	my $soon = 0;
	my $setting;
	my $val;
	my $old_setting;
	my $old_val;
	while (defined(my $line = shift @res)) {
	    if ($line =~ /^\((\w+)\)=/i) {
		if (@info) {
		    unshift @res, $line;
		    last;
		}
		$old_setting = $setting;
		$soon = 1;
		$setting = $1;
	    }
	    elsif ($soon == 1 && $line =~ /^(?:` (.*) `|`(.*)` \*\*`(.*)`\*\*)$/) {
		$old_val = $val;
		$val = defined $1 ? $1 : "$2 = $3";
		$soon++;
	    }
	    elsif ($soon == 2 && $line =~ /^\s*$/) {
		# skip
		$soon++;
	    }
	    elsif ($soon && $line =~ /^([: ]|$)/) {
		next if $line =~ /^:?\s+$/;
		next if $line =~ /^:?\s+!/;
		next if $line =~ /^:?\s+```/;
		$line =~ s/^[: ]\s?//;
		push @info, $line;
	    }
	    elsif (@info) {
		unshift @res, $line;
		last;
	    }
	}
	unshift @info, $val if defined $val;
	s/`//g for @info;
	s/\\\\/\\/g for @info;
	pop @info if @info && !length $info[-1];
	if (@info) {
	    if ($old_val && $old_setting) {
		my $sep =($old_val =~ s/^\Q$old_setting\E\s+=(\s+|\s*$)//i) ? '' : ':';
		my $clr = !$sep && !$old_val ? '-clear ' : '';
		my @info2 = ("/set $clr\cB\L$old_setting\E\cB$sep ".($old_val),'',
			     "    see /help set \cB\L$setting\E\cB",'');
		s/%/%%/g for @info2;
		s/^(\s+)/$1%|/gm for @info2;
		push @{$help{"settings/$old_setting"}}, @info2;
	    }
	    my $sep =($info[0] =~ s/^\Q$setting\E\s+=(\s+|\s*$)//i) ? '' : ':';
	    my $clr = !$sep && !length $info[0] ? '-clear ' : '';
	    my @info2 = ("/set $clr\cB\L$setting\E\cB$sep ".(shift @info),'',(map {"    $_"} @info),'');
	    s/%/%%/g for @info2;
	    s/^(\s+)/$1%|/gm for @info2;
	    for (@info2) {
		if (s/%\|\| (.*) \|$/$1/) {
		    s/ \| / | %|/g;
		    s/\\([\|]\S+)/$1 /g;
		    s/\s+$//;
		}
	    }
	    push @{$help{"settings/$setting"}}, @info2;
	}
    }
}

print CLIENTCRAP '%U%_Irssi Settings documentation licence%: ' . $IRSSI{license};
print CLIENTCRAP '%:You can now read help for settings with %_/HELP SET settingname%_';

Irssi::signal_add_first(
	'command help' => sub {
		if ($_[0] =~ s|^set\s+|settings/|i && $_[0] ne 'settings/' && ($_[0]="\L$_[0]")
		   && $_[0] =~ /^(.*?)(?:\s+|$)/ && exists $help{$1}) {
			print CLIENTCRAP join "\n", '', '%_Setting:%_%:', @{$help{$1}};
			Irssi::signal_stop;
		}
	}
       );
Irssi::signal_register({'complete command ' => [qw[glistptr_char* Irssi::UI::Window string string intptr]]});
Irssi::signal_add_last(
	"complete command help" => sub {
		my ($cl, $win, $word, $start, $ws) = @_;
		if (lc $start eq 'set') {
			&Irssi::signal_continue;
			Irssi::signal_emit('complete command set', $cl, $win, $word, '', $ws);
		}
	}
       );

sub load_help { <<'__HELP__'; }
# Settings Documentation

Irssi settings notes. Updated for 1.2.2

This is not an attempt to document Irssi completely. It should be used along with the documents at [Documentation](/) for more complete understanding of how Irssi works. For example, the startup HOWTO and tips/tricks show sample uses for these settings, including some very useful stuff.

See the [appendix](#a-credits) for credits and license information of this document.

##  [completion]

(completion_auto)=
`completion_auto` **`OFF`**

: Tell Irssi to detect incomplete nicknames in your input and look up their completions automatically. Incomplete nicknames are detected when you input text that matches /^(\S+)${completion_character}/. For example:

      vis: hello

  will be expanded to

      visitors: hello

  when you press enter. So will:

      vis:hello
      Vis::Hello(12);

  This will eventually bite you.

(completion_char)=
`completion_char` **`:`**

: The text that Irssi puts after a tab-completed nickname, or that it uses to detect nicknames when you have completion_auto turned on. Some people alter this to colorize the completion character, creating the oft-dreaded bold colon.

(completion_empty_line)=
`completion_empty_line` **`ON`**

: When this setting is OFF, tab completion will be disabled when the input line is empty. Disabling it is useful when pasting text that starts with a tab character, since that normally results in a /msg to a recent target.

  Added in Irssi 1.0.0

(completion_keep_word)=
`completion_keep_word` **`ON`**

: Whether to keep the original word that was completed, in the list of completions. This way, you can "undo" accidential completions more easily with Shift-Tab.

  Added in Irssi 1.2.0

(completion_keep_privates)=
`completion_keep_privates` **`10`**

: Irssi keeps a list of nicknames from private messages (sent and received) to search during nick completion. This setting determines how many nicknames are held.

(completion_keep_publics)=
`completion_keep_publics` **`50`**

: Irssi keeps a list of nicknames from public messages (sent and received) to search during nick completion. This setting determines how many nicknames are held.

(completion_nicks_lowercase)=
`completion_nicks_lowercase` **`OFF`**

: When enabled, Irssi forces completed nicknames to lowercase. Manually typed nicknames retain their case.

(completion_strict)=
`completion_strict` **`OFF`**

: When on, nicknames are matched strictly. That is, the partial nickname you enter must be at the beginning of a nickname in one of Irssi's lists.

  When off, Irssi will first try a strict match. If a strict match can't be found, Irssi will look for nicknames that match when their leading non-alphanumeric characters are removed. For example:
 
      vis: hello

  With strict completion on, it will only match nicknames beginning with vis. With strict completion off, it may match visitors or _visitors_ or [visitors], and so on.

(completion_nicks_match_case)=
`completion_nicks_match_case` **`auto`**

: Whether to enforce the case of the letters you typed while completing nicks. Accepted values:

  `never`
  : ignore the case of nicks when completing.

  `always`
  : nicks are only completed when the case matches.

  `auto` (default)
  : as soon as you type an uppercase letter, the nick case has to match.

  Added in Irssi 1.0.0

##  [dcc]

(dcc_autoaccept_lowports)=
`dcc_autoaccept_lowports` **`OFF`**

: When this setting is OFF, Irssi will not auto-accept DCC requests from privileged ports (those below 1024) even when auto-accept is otherwise on.

(dcc_autochat_masks)=
`dcc_autochat_masks` **` `**

: Set dcc_autochat_masks with user masks to auto-accept chat requests from. When unset, Irssi's auto-accept settings work for everyone who tries to DCC chat you. The drawbacks can range from annoying through downright dangerous. Use auto-accept with care.

(dcc_autoget)=
`dcc_autoget` **`OFF`**

: Turn DCC auto-get on or off. When on, Irssi will attempt to auto-get files sent to you.

  This feature can be abused, so it is usually off by default. If you enable it, consider also setting dcc_autoget_masks and dcc_autoget_max_size to make this feature more secure.

(dcc_autoget_masks)=
`dcc_autoget_masks` **` `**

: Set dcc_autoget_masks with user masks to automatically accept files sent to you via DCC. When unset, Irssi's auto-get settings will work for everyone who attempts to send you files.

  This setting is only significant if dcc_autoget is ON.

(dcc_autoget_max_size)=
`dcc_autoget_max_size` **`0k`**

: Set to nonzero to limit the size of files that Irssi will auto-get.

  Note: Because of the way DCC works, someone may advertise a file at once size but try to send you something larger. According to src/irc/dcc/dcc-autoget.c, this only filters the request based on the advertised size.

  This setting is only significant if dcc_autoget is ON.

(dcc_autorename)=
`dcc_autorename` **`OFF`**

: Turn on this setting to automatically rename received files so they don't overwrite existing files.

  I think this setting may thwart dcc_autoresume, since the auto-resume feature looks for existing filenames when resuming. Auto-renaming downloads makes sure that filenames never conflict, so resuming is not possible.

(dcc_autoresume)=
`dcc_autoresume` **`OFF`**

: When on, dcc_autoresume will cause Irssi to look for existing files with the same name as a new DCC transfer. If a file already exists by that name, Irssi will try to resume the transfer by appending any new data to the existing file.

  I think this option clashes with dcc_autorename. See dcc_autorename for more information.

  Dcc_autoresume is ignored if dcc_autoget is off.

(dcc_download_path)=
`dcc_download_path` **`~`**

: The path to a directory where Irssi will store DCC downloads.

(dcc_file_create_mode)=
`dcc_file_create_mode` **`644`**

: The mode in which new files are created.

  > 644 is read/write by you, and readable by everybody else.
  >
  > 600 is read/write by you, nobody else can read or write.

(dcc_mirc_ctcp)=
`dcc_mirc_ctcp` **`OFF`**

: Tells Irssi to send CTCP messages that are compatible with mIRC clients. This lets you use /me actions in DCC chats with mIRC users, among other things.

(dcc_own_ip)=
`dcc_own_ip` **` `**

: Set dcc_own_ip to force Irssi to always send DCC requests from a particular virtual host (vhost). Irssi will always bind sockets to this address when answering DCC requests. Otherwise Irssi will determine your IP address on its own.

(dcc_port)=
`dcc_port` **`0`**

: The smallest port number that Irssi will use when initiating DCC requests. Irssi picks a port at random when this is set to zero.

  dcc_port can be two ports, separated by a space. In that case, Irssi will pick a port between the two numbers, inclusively. For example:

      /set dcc_port 10000 20000

(dcc_send_replace_space_with_underscore)=
`dcc_send_replace_space_with_underscore` **`OFF`**

: When enabled, Irssi will replace spaces with underscores in the names of files you send. It should only be necessary when sending files to clients that don't support quoted filenames, or if you hate spaces in filenames.

(dcc_timeout)=
`dcc_timeout` **`5min`**

: How long to keep track of pending DCC requests. Requests that do not receive responses within this time will be automatically canceled.

(dcc_upload_path)=
`dcc_upload_path` **`~`**

: The path where you keep public files available to send via DCC.

##  [flood]

(autoignore_time)=
`autoignore_time` **`5min`**

: Irssi can auto-ignore people who are flooding. autoignore_time sets the amount of time to keep someone ignored. Irssi will automatically unignore them after this period of time has elapsed.

(autoignore_level)=
`autoignore_level` **` `**

: The type or types of messages that will trigger auto-ignore.

(flood_max_msgs)=
`flood_max_msgs` **`4`**

(flood_timecheck)=
`flood_timecheck` **`8`**

: Irssi will treat text as flooding if more than flood_max_msgs messages are received during flood_timecheck seconds. In the case above, five or more messages matching autoignore_level over the course of eight seconds will trigger flood protection. See autoignore_time to set the amount of time someone will remain ignored if it's determined that they're flooding.

(cmds_max_at_once)=
`cmds_max_at_once` **`5`**

: How many commands you can send immediately before server-side flood protection starts.

  IRC servers also perform flood checking, and they will gleefully disconnect you if you are abusing them. The cmds_max_at_once setting lets Irssi know how many rapid messages it can get away with while remaining under the IRC server's radar.

(cmd_queue_speed)=
`cmd_queue_speed` **`2200msec`**

: The time to wait between sending commands to an IRC server. Used to prevent Irssi from flooding you off if you must auto-kick/ban lots of people at once.

(max_ctcp_queue)=
`max_ctcp_queue` **`5`**

: The maximum number of pending CTCP requests to keep. Requests beyond max_ctcp_queue will be discarded.

##  [history]

(max_command_history)=
`max_command_history` **`100`**

: The number of lines of your own input to keep for recall.

(rawlog_lines)=
`rawlog_lines` **`200`**

: Irssi's raw log is a buffer of raw IRC messages. It's used for debugging Irssi and maybe some other things. This setting tells Irssi how many raw messages to keep around.

(scroll_page_count)=
`scroll_page_count` **`/2`**

: How many pages to scroll the scrollback buffer when pressing page-up or page-down. Expressed as a number of lines, or as a fraction of the screen:

  /2
  : Scroll half a page.
  
  .33
  : Scroll about a third of a page.
  
  4
  : Scroll four lines.

(scrollback_burst_remove)=
`scrollback_burst_remove` **`10`**

: This is a speed optimization: Don't bother removing messages from the scrollback buffer until the line limit has been exceeded by scrollback_burst_remove lines. This lets Irssi do its memory management in chunks rather than one line at a time.

(scrollback_lines)=
`scrollback_lines` **`500`**

: The maximum number of messages to keep in your scrollback history. Set to 0 if you don't want to limit scrollback by a line count. The scrollback_time setting will be used even if scrollback_lines is zero.

  Setting scrollback_lines to zero also seems to thwart the scrollback_burst_remove optimization.

(scrollback_time)=
`scrollback_time` **`1day`**

: Keep at least scrollback_time worth of messages in the scrollback buffer, even if it means having more than scrollback_lines lines in the buffer.
  Valid formats for the setting are:

  > day/hour/minute/min/second/sec/millisecond/millisec/msecond/msec

  and the plural forms of the above: days, hours etc

  The maximum value is 24 days

(scrollback_max_age)=
`scrollback_max_age` **`0`**

: Delete messages older than the given time in each scrollback buffer. The given time has the same format as the scrollback_time setting. Note: messages can only be deleted when there is activity in a buffer. Thus, "day changed" messages will trigger deletion in inactive buffers.

  Currently, the oldest time you can set is 24days.

  Added in Irssi 1.3

(window_history)=
`window_history` **`OFF`**

: When turned ON, command history will be kept per-window. When off, Irssi uses a single command history for all windows.

##  [log]

(autolog)=
`autolog` **`OFF`**

: Automatically log everything, or at least the types of messages defined by autolog_level.

(autolog_colors)=
`autolog_colors` **`OFF`**

: Whether to save colors in autologs. Colors make logs harder to parse and grep, but they may be vital for channels that deal heavily in ANSI art, or something.

(autolog_ignore_targets)=
`autolog_ignore_targets` **` `**

: A space separated list of targets to exclude from autologging

  See `activity_hide_targets` for additional ways to specify targets in Irssi 1.0.0+.

  Added in Irssi 0.8.13

(autolog_level)=
`autolog_level` **`all -crap -clientcrap -ctcps`**

: The types of messages to auto-log. See the autolog setting.

(autolog_path)=
`autolog_path` **`~/irclogs/$tag/$0.log`**

: The path where autolog saves logs.

  $0 is the target (channel or query name usually)  
  $1 is the server tag (same as $tag)

  See Appendix B for Irssi's special variables. Irssi's special variables can be used to do fancy things like daily log rotations.

(autolog_only_saved_channels)=
`autolog_only_saved_channels` **`OFF`**

: Only autolog channels that are added in /channel list

  Added in Irssi 1.2.0

(awaylog_colors)=
`awaylog_colors` **`ON`**

: Whether to store color information in /away logs.

(awaylog_file)=
`awaylog_file` **`~/.irssi/away.log`**

: Where to log messages while you're away.

  I assume Irssi's special variables also work here. See Appendix B for more information about them.

(awaylog_level)=
`awaylog_level` **`msgs hilight`**

: The types of messages to log to awaylog_file while you're away.

(log_close_string)=
`log_close_string` **`--- Log closed %a %b %d %H:%M:%S %Y`**

: The message to log when logs are closed.

  See Appendix C for the meanings of Irssi's time format codes.

(log_create_mode)=
`log_create_mode` **`600`**

: The permissions to use when creating log files.

  600 is read/write by you, but nobody else can see them. A sensible default mode. It can also be set to 644 if you want the rest of the world to read your logs.

(log_day_changed)=
`log_day_changed` **`--- Day changed %a %b %d %Y`**

: The message to log when a new day begins.

  See Appendix C for the meanings of Irssi's time format codes.

(log_open_string)=
`log_open_string` **`--- Log opened %a %b %d %H:%M:%S %Y`**

: The message to log when a log is opened.

  See Appendix C for the meanings of Irssi's time format codes.

(log_theme)=
`log_theme` **` `**

: Logs can have a different theme than what you see on the screen. This can be used to create machine-parseable versions of logs, for example.

(log_timestamp)=
`log_timestamp` **`%H:%M `**

: The time format for log timestamps.

  See Appendix C for the meanings of Irssi's time format codes.

(log_server_time)=
`log_server_time` **`auto`**

: Whether to log the timestamp as sent by the server, or the time when this message was received by Irssi. Also see /SET show_server_time

  `off`
  : log timestamp when received

  `on`
  : log timestamp as provided by server

  `auto` (default)
  : follow show_server_time setting

  Added in Irssi 1.3

##  [lookandfeel]

(active_window_ignore_refnum)=
`active_window_ignore_refnum` **`ON`**

: When set ON, the active_window key (meta-a by default) switches to the window with the highest activity level that was last activated.

  When set OFF, the pre-0.8.15 behavior is used: it switches to the window with the highest activity level with the lowest refnum.

  Added in Irssi 0.8.15

(activity_hide_level)=
`activity_hide_level` **` `**

: Message levels that don't count towards channel activity. That is, channels won't be marked as active if messages of these types appear.

(activity_hide_targets)=
`activity_hide_targets` **` `**

: Sometimes you don't care at all about a window's activity. This can be set to a space separated list of windows that will never appear to be active.

  | Syntax              | Version added | Description                                                      |
  | ------------------- | ------------- | ---------------------------------------------------------------- |
  | exactname           | 0.8.0         | Ignore activity in window 'exactname'                            |
  | tag/exactname       | 0.8.6         | Ignore activity on network 'tag' and window 'exactname'          |
  | *                   | 1.0.0         | Ignore activity in all windows                                   |
  | tag/*               | 1.0.0         | Ignore all activity on network 'tag'                             |
  | ::all               | 1.1.0         | Ignore activity in all windows                                   |
  | ::channels          | 1.1.0         | Ignore activity in all channels                                  |
  | ::queries           | 1.1.0         | Ignore activity in all queries                                   |
  | ::dccqueries        | 1.1.0         | Ignore activity in all dcc chats                                 |
  | #chan\|[=]nick      | 1.1.0         | Ignore activity in named target(channel, query, dcc chat)        |
  | tag/::all           | 1.1.0         | Ignore all activity on network 'tag'                             |
  | tag/::channels      | 1.1.0         | Ignore activity in all channels on network 'tag'                 |
  | tag/::queries       | 1.1.0         | Ignore activity in all queries on network 'tag'                  |
  | tag/::dccqueries    | 1.1.0         | Ignore activity in all dcc chats on network 'tag'                |
  | tag/#chan\|[=]nick  | 1.1.0         | Ignore activity in named channel/query/dcc chat on network 'tag' |

(activity_hilight_level)=
`activity_hilight_level` **`MSGS DCCMSGS`**

: There are times when you want to highlight channel activity in a window. Like when someone sends you a private message, or a DCC message. activity_hilight_level sets the kind of messages you think are extra important.

(activity_msg_level)=
`activity_msg_level` **`PUBLIC`**

: Flag a channel as active when messages of this type are displayed there.

(activity_hide_window_hidelevel)=
`activity_hide_window_hidelevel` **`ON`**

: Do not flag a window as active if the message is hidden with /window hidelevel

  Added in Irssi 1.2.0

(activity_hide_visible)=
`activity_hide_visible` **`ON`**

: Whether to hide the active flag when the window is visible.

  Added in Irssi 1.2.0

(actlist_names)=
`actlist_names` **`OFF`**

: Turn on to add active items names in 'act' statusbar item.

(actlist_prefer_window_name)=
`actlist_prefer_window_name` **`OFF`**

: Whether to show the window name instead of the item name when actlist_names is enabled.

  Added in Irssi 1.3

(actlist_sort)=
`actlist_sort` **`refnum`**

: Specifies the sorting type used for the activity bar. Accepted values:

  `refnum` (default)
  : windows are listed in numeric order

  `recent`
  : windows with more recent activity appear first

  `level`
  : sort by window level (hilight, msg, etc), same ordering used by active_window command. Windows with the same level are sorted by refnum.

  `level,recent`
  : same as level, but windows with the same level are sorted by recent.

  Added in Irssi 0.8.12. Before Irssi 0.8.12, a boolean `actlist_moves` setting existed, which was equivalent to setting actlist_sort to refnum.

(autoclose_query)=
`autoclose_query` **`0`**

: Automatically close query windows after autoclose_query seconds of inactivity. Setting autoclose_query to zero will keep them open until you decide to close them yourself.

(autoclose_windows)=
`autoclose_windows` **`ON`**

: Automatically close windows when nobody is in them. This keeps your window list tidy, but it means that query windows may rearrange as people log off then privately message you later.

(autocreate_own_query)=
`autocreate_own_query` **`ON`**

: Turn on to automatically create query windows when you /msg someone.

(autocreate_query_level)=
`autocreate_query_level` **`MSGS DCCMSGS`**

: Automatically create query windows when receiving these types of messages.

(autocreate_windows)=
`autocreate_windows` **`ON`**

: When on, create new windows for certain operations, such as /join. When off, everything is just dumped into one window.

(autocreate_split_windows)=
`autocreate_split_windows` **`OFF`**

: Automatically created windows will be created as split windows with this setting on.

  Split windows are the kind where multiple windows are on one screen.

(autofocus_new_items)=
`autofocus_new_items` **`ON`**

: Switch the focus to a new item when it's created. This may be disturbing at first when combined with query window auto-creation, and it may be downright dangerous if it causes you to accidentally misdirect messages.

(autostick_split_windows)=
`autostick_split_windows` **`OFF`**

: Whether creating split windows (or showing windows) will automatically stick them to the split window (/window stick on)

  The default was changed to `OFF` in Irssi 1.2.0

(autounstick_windows)=
`autounstick_windows` **`ON`**

: Whether windows should automatically unstick when you try to /window show or /window hide them

  Added in Irssi 1.2.0

(beep_msg_level)=
`beep_msg_level` **` `**

: Beep when messages match this level mask.

(beep_when_away)=
`beep_when_away` **`ON`**

: Should beeps be noisy when you're /away? Great for people who sleep near their terminals or keep Irssi running at work. :)

(beep_when_window_active)=
`beep_when_window_active` **`ON`**

: Should beeps be noisy in a window you're watching? Perhaps not, since you are theoretically watching that window. You ARE watching it, aren't you?

(bell_beeps)=
`bell_beeps` **`OFF`**

: Removed in Irssi 1.0.0.

  Tell Irssi whether bell characters (chr 7, ^G) included inside IRC messages should actually cause beeps. This doesn't mean that highlights will make a beep sound, this means that anyone in any irc channel can cause unexplained beeps.

  Since its only purpose is to be annoying, we decided to remove this. [See this issue for details](https://github.com/irssi/irssi/issues/524).

  Any guide that recommended enabling this to make beeps work is wrong. This setting is not needed for that.

(break_wide)=
`break_wide` **`OFF`**

: When on, wide characters (fullwidth / CJK / east asian) are always considered line breaking points then wrapping lines for display, instead of only wrapping on space characters.

  Example:

  ```ascidia.repl#fig_break_wide
           ╔═══════════════════════════════════════════════════════════╗
      OFF: ║10:31 -!- 火火火火火火火火火火ab                           ║
           ║          cd火火火火火火火火火火胡火火火火火后ab           ║
           ║          cd火火火火火火火火火火火                         ║
           ╚═══════════════════════════════════════════════════════════╝

           ╔═══════════════════════════════════════════════════════════╗
      ON:  ║10:31 -!- 火火火火火火火火火火ab cd火火火火火火火火火火胡火║
           ║          火火火火后ab cd火火火火火火火火火                ║
           ╚═══════════════════════════════════════════════════════════╝
  ```

  Added in Irssi 1.1.0

(chanmode_expando_strip)=
`chanmode_expando_strip` **`OFF`**

: When on, $M will not return mode parameters.

  This means for example that the channel limit and channel key won't be shown in your statusbar (a common place where $M is used) (but also not in all other places that refer to $M for whatever reason).

(colors)=
`colors` **`ON`**

: Enable or disable colors.

(emphasis)=
`emphasis` **`ON`**

: Enable or disable real underlining and bolding when someone says `*bold*` or `_underlined_`.

(emphasis_italics)=
`emphasis_italics` **`OFF`**

: Enable or disable applying real italics when someone says `/italics/`.

  Note: not all terminals support this. Most notably, if the TERM environment variable is set to screen, it won't work.

  Added in Irssi 0.8.17

(emphasis_multiword)=
`emphasis_multiword` **`OFF`**

: Turn on to allow `*more than one word bold*` and `_multiple underlined words_`. Used in conjunction with the emphasis setting.

(emphasis_replace)=
`emphasis_replace` **`OFF`**

: If emphasis is turned on, the `*` or `_` characters indicating emphasis will be removed when the word is made bold or underlined. Some people find this looks cleaner.

  See the emphasis setting for more information.

(expand_escapes)=
`expand_escapes` **`OFF`**

: Detect escapes in input, and expand them to the characters they describe. For example

      \t

  Is literally '\\' and 't' when expand_escapes is off, but it's the tab character (chr 9) when expand_escapes is on.

(hide_colors)=
`hide_colors` **`OFF`**

: Hide mIRC and ANSI colors when turned on. This can be used to eliminate angry fruit salad syndrome in some channels.

(hide_server_tags)=
`hide_server_tags` **`OFF`**

: Server tags are prefixes to some messages (server messages?) that let you know which server the message came from. They're often considered noisy, so this option lets you hide them.

(hide_text_style)=
`hide_text_style` **`OFF`**

: Hide bold, blink, underline, and reverse attributes.

(hilight_act_color)=
`hilight_act_color` **`%M`**

: The color to use to highlight window activity in the status bar. That's the section that shows [Act: ...].

  See Appendix D for Irssi's color codes.

(hilight_color)=
`hilight_color` **`%Y`**

: The default color for /hilight.

  See Appendix D for Irssi's color codes.

(hilight_level)=
`hilight_level` **`PUBLIC DCCMSGS`**

: The types of messages that can be highlighted.

(hilight_nick_matches)=
`hilight_nick_matches` **`ON`**

: Tell Irssi whether it should automatically highlight text that starts with your nickname.

(hilight_nick_matches_everywhere)=
`hilight_nick_matches_everywhere` **`OFF`**

: Turn on to extend hilight_nick_matches to match your nickname everywhere in messages, not just at the beginning.

  Added in Irssi 0.8.18

(indent)=
`indent` **`10`**

: How many columns to indent subsequent lines of a wrapped message.

  Attention: This can be overwritten by themes.

(indent_always)=
`indent_always` **`OFF`**

: Should we indent the long words that are forcibly wrapped to the next line? This can break long words such as URLs by inserting spaces in the middle of them.

  Turn off if you would like to copy/paste or otherwise use URLs from your terminal.

(mirc_blink_fix)=
`mirc_blink_fix` **`OFF`**

: Some terminals interpret bright background colors as blinking text. mIRC doesn't support blinking at all. This fixes the blinky terminals by replacing high colors with their low equivalents.

  From Irssi's ChangeLog:

  > /SET mirc_blink_fix - if ON, the bright/blink bit is stripped
  > from MIRC colors. Set this to ON, if your terminal shows bright
  > background colors as blinking.

(colors_ansi_24bit)=
`colors_ansi_24bit` **`OFF`**

: Enable the use of 24-bit color codes, when compiled with `-Denable-true-color=yes`.

  Note: not all terminals support this. If yours does not, it may result in horrible screen distortion.

  Added in Irssi 0.8.17

(names_max_columns)=
`names_max_columns` **`6`**

: Maximum number of columns to use for /names listing. Also shown on channel join. Set to 0 for as many as fit in your terminal.

(names_max_width)=
`names_max_width` **`0`**

: Maximum number of columns to consume with a /names listing. Overrides names_max_columns if non-zero. Set to 0 for as many as fit in your terminal.

(print_active_channel)=
`print_active_channel` **`OFF`**

: Always print the channel with the nickname (like nick:channel) even if the message is from the channel you currently have active.

(query_track_nick_changes)=
`query_track_nick_changes` **`ON`**

: Query windows will track nick changes when this is on. That is, when receiving a message from an unknown nick, it looks for a query with a matching user@host before creating a new one, and if it finds one, it gets renamed to use the new nick.

(reuse_unused_windows)=
`reuse_unused_windows` **`OFF`**

: When set on, Irssi will reuse unused windows when looking for a new window to put something in. Otherwise unused windows are ignored, and new ones are always created.

(scroll)=
`scroll` **`ON`**

: Set scroll ON to have Irssi scroll your screen when it fills up. Set it OFF to require manual scrolling.

  Warning: If set to OFF, this will stop scrolling in all windows and not reenable scrolling even if you set it back to ON. (You need to manually scroll to the bottom in each window first.)

(show_away_once)=
`show_away_once` **`ON`**

: When on, only show /away messages in the window that's currently open. Otherwise the message will appear in every window you share with the away person.

(away_notify_public)=
`away_notify_public` **`OFF`**

: Whether to show /away changes of other users in the channel. Only affects servers that actively inform about away changes.

  Added in Irssi 1.3

(show_names_on_join)=
`show_names_on_join` **`ON`**

: Display the list of names in a channel when you join that channel. It's generally recommended, but you can disable it for pathologically huge channels or in case you just don't care. Also see show_names_on_join_limit, which overrules this setting.

(show_names_on_join_limit)=
`show_names_on_join_limit` **`18`**

: Do not show the NAMES list on join if there are more than show_names_on_join_limit users in the channel.

  Added in Irssi 1.3

(show_extended_join)=
`show_extended_join` **`OFF`**

: Whether to show extended join information (real name and services account) when others users join the channel. Only affects servers that send extended joins information.

  Added in Irssi 1.3

(show_nickmode)=
`show_nickmode` **`ON`**

: Prefix nicknames with their channel status:

  voiced 
  : `+`

  half-op
  : `%`

  op
  : `@`

(show_nickmode_empty)=
`show_nickmode_empty` **`ON`**

: If a person has no channel modes, prefix their nickname with a blank space. This keeps nicknames of normal people aligned with those of voiced, half-opped, and opped people.

(show_account_notify)=
`show_account_notify` **`OFF`**

: Whether to show account changes of other users in the channel. Only affects servers that actively inform about account changes.

  Added in Irssi 1.3

(show_own_nickchange_once)=
`show_own_nickchange_once` **`OFF`**

: Squash your own nick-change messages so they appear only once, not once in every window you have on that network.

(show_quit_once)=
`show_quit_once` **`OFF`**

: When turned on, a quit message will only be shown once. Otherwise it will be displayed in every window you share with the quitter.

(show_server_time)=
`show_server_time` **`OFF`**

: Whether to show the server-provided time on messages when available, or only the local time of reception.

  Added in Irssi 1.3

(term_appkey_mode)=
`term_appkey_mode` **`ON`**

: If this is ON, the application keys mode is used, which is needed for some terminals.

  Turn this off if your terminal doesn't need this mode and you need to bind meta-O (that's an uppercase O)

  Added in Irssi 0.8.19

(term_charset)=
`term_charset` **`UTF-8`**

: Sets your native terminal character set. Irssi will take this into consideration when it needs to delete multibyte characters, for example.

  A common value is utf-8 for Unicode/UTF-8 enabled terminals.

  TODO - Does this still support Chinese terminal emulators? (Used to be term_type big5 in old Irssi.)

(term_force_colors)=
`term_force_colors` **`OFF`**

: Always display colors, even when the terminal type says colors aren't supported. Useful for working around really dumb terminals.

(theme)=
`theme` **`default`**

: Irssi supports themes that can change most of the client's look and feel. This setting lets you name the theme you wish to use.

(timestamp_format)=
`timestamp_format` **`%H:%M`**

: How to format the time used in timestamps.

  See Appendix C for the meanings of Irssi's time format codes.

(timestamp_format_alt)=
`timestamp_format_alt` **`%a %e %b %H:%M`**

: How to format messages with an old timestamp, for example messages from the past emitted by the server.

  Added in Irssi 1.3

(timestamp_level)=
`timestamp_level` **`ALL`**

: Types of messages to prefix a timestamp to. Useful for explicit or automatic timestamps.

  Once timestamping is temporarily turned on, it may stay on for timestamp_timeout seconds.

(timestamp_timeout)=
`timestamp_timeout` **`0`**

: The amount of time to leave timestamps on after a timestamp_level message triggered timestamping. Useful for people who think timestamps are noisy but would like timestamps for important conversations.

(timestamps)=
`timestamps` **`ON`**

: Turn timestamps on or off. When off, not even timestamp_level will trigger them.

(tls_verbose_connect)=
`tls_verbose_connect` **`ON`**

: When this setting is ON, Irssi displays TLS connection information on connect, which includes the certificate chain, protocol version, cipher suite and fingerprints. Example:

      -!- Irssi: Connecting to irc.example.net [198.51.100.1] port 6697
      -!- Irssi: Certificate Chain:
      -!- Irssi:   Subject: CN: irc.example.net
      -!- Irssi:   Issuer:  C: US, O: Let's Encrypt, CN: Let's Encrypt Authority X3
      -!- Irssi:   Subject: C: US, O: Let's Encrypt, CN: Let's Encrypt Authority X3
      -!- Irssi:   Issuer:  O: Digital Signature Trust Co., CN: DST Root CA X3
      -!- Irssi: Protocol: TLSv1.2 (256 bit, DHE-RSA-AES256-GCM-SHA384)
      -!- Irssi: EDH Key: 2048 bit DH
      -!- Irssi: Public Key: 4096 bit RSA, valid from Mar 20 05:16:00 2017 GMT to Jun 18 05:16:00 2017 GMT
      -!- Irssi: Public Key Fingerprint:  DE:AD:BE:EF:DE:AD:BE:EF:DE:AD:BE:EF:DE:AD:BE:EF:DE:AD:BE:EF:DE:AD:BE:EF:DE:AD:BE:EF:DE:AD:BE:EF (SHA256)
      -!- Irssi: Certificate Fingerprint: CA:FE:BA:BE:CA:FE:BA:BE:CA:FE:BA:BE:CA:FE:BA:BE:CA:FE:BA:BE:CA:FE:BA:BE:CA:FE:BA:BE:CA:FE:BA:BE (SHA256)

  Added in Irssi 1.0.0

(use_msgs_window)=
`use_msgs_window` **`OFF`**

: Use a single window for all private messages. This setting only makes sense if automatic query windows is turned off.

(use_status_window)=
`use_status_window` **`ON`**

: Create a separate window for all server status messages, so they don't clutter up your channels.

(whois_hide_safe_channel_id)=
`whois_hide_safe_channel_id` **`ON`**

: Hides the unique id of !channels in /whois output (IRCNet/irc2 networks only).

  E.g. shows !channel instead of !12345channel

  Added in Irssi 0.8.10

(window_auto_change)=
`window_auto_change` **`OFF`**

: Turn this on to automatically switch to newly-created windows. This may cause you to misdirect messages, so be careful.

(window_check_level_first)=
`window_check_level_first` **`OFF`**

(window_default_level)=
`window_default_level` **`NONE`**

: From Irssi's ChangeLog:

  Added /SET window_check_level_first and /SET window_default_level. This allows you to keep all messages with specific level in it's own window, even if it was supposed to be printed in channel window. patch by mike@po.cs.msu.su

  Try to choose better the window where we print when matching by level and multiple windows have a match. Should fix problems with query windows with a default msgs window + /SET window_check_level_first ON.

  Wouter Coekaerts has made a nice explanation about this, see <<http://wouter.coekaerts.be/site/irssi/wclf>>

(window_default_hidelevel)=
`window_default_hidelevel` **`HIDDEN`**

: The default /window hidelevel for newly created windows. You can add other levels here to hide joins/parts/quits by default.

  Added in Irssi 1.2.0

(windows_auto_renumber)=
`windows_auto_renumber` **`ON`**

: Closing windows can create gaps in the window list. When windows_auto_renumber is turned on, however, windows are shifted to lower numbers in the list to fill those gaps.

(scrollback_format)=
`scrollback_format` **`ON`**

: Whether to store the format and arguments for printed text in the scrollback, or the final rendered text instead. Turning it off restores pre-1.3 behaviour. Some features may not work depending on this setting.

  Added in Irssi 1.3

##  [misc]

(auto_whowas)=
`auto_whowas` **`ON`**

: Automatically try /whowas if you /whois someone who isn't online.

(ban_type)=
`ban_type` **`normal`**

: The default ban type to use: normal, user, host, domain, custom? See /help ban for a description of ban types.

(capsicum)=
`capsicum` **`OFF`**

: FreeBSD/Capsicum builds only: Capsicum is a lightweight OS capability and sandbox framework provided by FreeBSD.

  This setting is only read when starting Irssi. See `docs/capsicum.txt` for usage details and limitations.

  Added in Irssi 1.1.0

(capsicum_irclogs_path)=
`capsicum_irclogs_path` **`~/irclogs`**

: FreeBSD/Capsicum builds only: Path that Irssi is allowed to write irc logs to.

  Added in Irssi 1.1.0

(capsicum_port_min)=
`capsicum_port_min` **`6667`**

(capsicum_port_max)=
`capsicum_port_max` **`9999`**

: FreeBSD/Capsicum builds only: Range of ports that Irssi is allowed to connect to.

  Added in Irssi 1.1.0

(channel_max_who_sync)=
`channel_max_who_sync` **`1000`**

: The maximum number of users that may be in a channel for Irssi to issue a

      /who #channel

  in order to obtain the hostmasks of every participant.

  If this is set too high, IRC servers might kick you for Sendq exceeded.

  Added in Irssi 0.8.10

(channel_sync)=
`channel_sync` **`ON`**

: Set whether Irssi should synchronize a channel on join. When enabled, Irssi will gather extra information about a channel: modes, who list, ban list, ban exceptions, and invite list.

(account_max_chase)=
`account_max_chase` **`10`**

: Maximum number of JOINs where Irssi will try to query the ACCOUNT using WHOX.

  Added in Irssi 1.3

(cmdchars)=
`cmdchars` **`/`**

: Prefix characters that tell Irssi that your input is a command rather than chat text.

(ctcp_userinfo_reply)=
`ctcp_userinfo_reply` **`$Y`**

: The reply to send when someone queries your user information. By default, it's $Y, which is defined by the real_name setting.

  See [](a_b) for more special variables you can use.

(ctcp_version_reply)=
`ctcp_version_reply` **`irssi v$J - running on $sysname $sysarch`**

: What to tell someone when they query your client's version.

  Some people consider announcing your client and operating system type and version to be a security hole. Those people change this setting.

(group_multi_mode)=
`group_multi_mode` **`ON`**

: Consolidate multiple consecutive channel modes into a single message. This will delay the display of channel modes for a short period of time while it waits to see if multiple modes are occurring.

(help_path)=
`help_path` **`/usr/local/share/irssi/help`**

: One or more paths where Irssi will look for its help database. Multiple paths are separated by :. It's very important that this is correct.

(hide_netsplit_quits)=
`hide_netsplit_quits` **`ON`**

: Don't display quit messages if they're the product of a netsplit. Some people find this helpful, while others find it creepy.

(ignore_signals)=
`ignore_signals` **` `**

: Operating system signals to ignore. May be zero or more of: int, quit, term, alrm, usr1, and usr2.

(join_auto_chans_on_invite)=
`join_auto_chans_on_invite` **`ON`**

: Automatically join a channel when invited to it, if that channel was previously added to the autojoin list (`/channel add -auto`).

(key_timeout)=
`key_timeout` **`0`**

: Time in msecs to wait until a key combo is flushed. If it's set to 0 (the default), there's no timeout, and key combos will wait until the next keystroke before processing.

  This is useful if you have key combos that extend others. For example, if you have `meta-a` and `meta-a-meta-b` this setting allows you to use `meta-a` after waiting some time.

  Setting it to very low values may result in issues such as partial key combos getting processed accidentally. 1000 or 500 might be good starting points

  Restart Irssi to enable the new timeout.

  Added in Irssi 1.1.0

(kick_first_on_kickban)=
`kick_first_on_kickban` **`OFF`**

: Kickban will normally ban first, then kick. Turn this option on to reverse the situation, which can create a race condition if the user rejoins between your kick and the subsequent ban.

(knockout_time)=
`knockout_time` **`5min`**

: Knockouts are temporary kickbans. Knockout_time is the default amount of time before each temporary ban is lifted.

  See /help knockout

(lag_check_time)=
`lag_check_time` **`1min`**

: How long to wait between active lag checks. Irssi will passively check for lag when you're active, but sometimes it's necessary to actively check. This is the minimum amount of time between active checks.

(lag_max_before_disconnect)=
`lag_max_before_disconnect` **`5min`**

: Irssi detects your lag and will reconnect you automatically if your lag exceeds this value.

(lag_min_show)=
`lag_min_show` **`1sec`**

: Lag is a part of life on IRC. Don't bother displaying lag that's below this threshold, presumably because you consider it to be insignificant.

(massjoin_max_joins)=
`massjoin_max_joins` **`3`**

: If nonzero, detect mass joins. A mass join is when someone joins more than massjoin_max_joins per massjoin_max_wait seconds.

  TODO - Or is this when more than massjoin_max_joins people join per massjoin_max_wait seconds, regardless of the user mask?

(massjoin_max_wait)=
`massjoin_max_wait` **`5000`**

: The amount of time to watch for mass-joins, in seconds.

  5000 is probably a bit too much.

(max_wildcard_modes)=
`max_wildcard_modes` **`6`**

: When set nonzero, don't mass op/deop/kick more than this many people. Commands that let you do things to other nicks can take wildcards. For example

      /kick floodbot* flooding

  would kick everybody whose nickname began with floodbot. Unless there were more than max_wildcard_modes of them.

  This setting prevents you from embarassment like:

      /kick *

  You can specify -yes if you really want to do it:

      /kick -yes *

(netjoin_max_nicks)=
`netjoin_max_nicks` **`10`**

: When non-zero, limits the number of nicknames to display during netjoins.

(netsplit_max_nicks)=
`netsplit_max_nicks` **`10`**

: When non-zero, limits the number of nicknames to display during netsplits.

(netsplit_nicks_hide_threshold)=
`netsplit_nicks_hide_threshold` **`15`**

: Limit the number of nicks to display during netsplits to this many. Or don't limit them at all, if this is set to 0.

(notify_check_time)=
`notify_check_time` **`1min`**

: How often to check for someone online when /notify is on.

(notify_whois_time)=
`notify_whois_time` **`5min`**

: How often to check /whois on a user who's online, to see if their /away or idle status changes.

(opermode)=
`opermode` **` `**

: When set, Irssi will set your modes to match opermode when you /oper up. For example, you might

      /set opermode +s 1048575

(override_coredump_limit)=
`override_coredump_limit` **`OFF`**

: Allow really really big coredumps if this is set on.

(part_message)=
`part_message` **` `**

: Default message to send when parting a channel.

(paste_detect_time)=
`paste_detect_time` **`5msecs`**

: Irssi will detect pastes when your input has less than this much time between lines.

(paste_join_multiline)=
`paste_join_multiline` **`ON`**

: Irssi will try to concatenate multiple lines into a single lined message when these lines have the same indentation level and look like they were copied out of Irssi.

  It's useful for quoting e-mail or other large-text messages, but it will probably bite you if you try to pasted indented text, such as code listings. Irssi will join multiple lines of code, destroying any structure you wanted to preserve.

  Added in Irssi 0.8.10

(paste_use_bracketed_mode)=
`paste_use_bracketed_mode` **`OFF`**

: Enables bracketed paste mode, which is an alternative to the time-based paste detection.

  If supported by the terminal, it's much more reliable since Irssi knows exactly where and when a paste starts and ends, because the terminal sends special control sequences (the "brackets") indicating those positions.

  To take full advantage of this feature, time-based paste detection should be disabled by setting `paste_detect_time` to 0.

  See <https://cirw.in/blog/bracketed-paste> for more details on how this works.

  Added in Irssi 0.8.18

(paste_verify_line_count)=
`paste_verify_line_count` **`5`**

: Ask you whether you meant to paste something if it's longer than this many lines.

(quit_message)=
`quit_message` **`leaving`**

: Default message to send when /quit'ting.

(recode)=
`recode` **`ON`**

: This setting allows you to disable Irssi's recode functionality, if you prefer your messages not being messed with.

  Added in Irssi 0.8.10

(recode_autodetect_utf8)=
`recode_autodetect_utf8` **`ON`**

: Irssi's recode system is broken. This tries to cover up for it by leaving messages intact that seem to decode fine as Unicode UTF-8.

  Added in Irssi 0.8.10

(recode_fallback)=
`recode_fallback` **`CP1252`**

: If you have Irssi compiled with recode support and Irssi believes that a message you received did not recode properly in your terminal default character set (or the specified one), it will recode the message using this character set.

  (CP1252, the Irssi default, is the Microsoft(R) Windows default character set for Western Europe.)

  Also see /help recode for more details about recoding.

  Added in Irssi 0.8.10

(recode_out_default_charset)=
`recode_out_default_charset` **` `**

: The outgoing character set you want your messags to be recoded into, if different from your term_charset.

  Added in Irssi 0.8.10

(recode_transliterate)=
`recode_transliterate` **`ON`**

: If enabled, Irssi tells iconv to try and replace characters that don't recode well with similar looking ones that exist in the target character set.

  If disabled, Irssi replaces the character it could not recode with a ? instead.

  Added in Irssi 0.8.10

(settings_autosave)=
`settings_autosave` **`ON`**

: Automatically save your settings when you quit Irssi, or once per hour, rather than waiting for you to /save them yourself.

(split_line_end)=
`split_line_end` **` `**

: When automatically splitting long lines, this is added to the end of line fragments.

  Added in Irssi 0.8.17

(split_line_on_space)=
`split_line_on_space` **`ON`**

: When this is ON, Irssi tries to split long lines on spaces, instead of splitting in the middle of words.

  Added in Irssi 0.8.18

(split_line_start)=
`split_line_start` **` `**

: When automatically splitting long lines, this is added to the beginning of line fragments.
:
: Added in Irssi 0.8.17

(STATUS_OPER)=
`STATUS_OPER` **`*`**

: Determines what's shown in the `$O` expando when the user is an oper.
:
: TODO - why

(usermode)=
`usermode` **`+i`**

: Default modes to set yourself once you've connected to a server.

(notice_channel_context)=
`notice_channel_context` **`ON`**

: Whether Irssi should recognise the channel context in /notices and show the notice in the appropriate channel window.

  Added in Irssi 1.2.0

(wall_format)=
`wall_format` **`[Wall/$0] $1-`**

: Format for wall messages.

(write_buffer_size)=
`write_buffer_size` **`0`**

: Amount of text (logs, etc) to buffer in memory before writing to disk. Useful for minimizing disk access.

(write_buffer_timeout)=
`write_buffer_timeout` **`0`**

: Amount of time to keep text in memory. A buffer is flushed to disk if the text in it is this old, even if the buffer isn't full.

  Useful in conjunction with really large write_buffer_size values, to prevent a lot of text from being lost if Irssi crashes or is killed.

(window_number_commands)=
`window_number_commands` **`ON`**

: Whether `/<number>` can be used to change windows.

  Added in Irssi 1.2.0

(wcwidth_implementation)=
`wcwidth_implementation` **`system`**

: The implementation Irssi should use to calculate and match the width of characters (like emoji) to the width that the terminal emulator assumes. If these widths don't add up, lines may not line up. Accepted values:

  `old`
  : the old built-in calculation (may be preferable on old systems)

  `system` (default)
  : use the calculation of your operating system

  `julia`
  : use the calculation of the utf8proc library (only when compiled with utf8proc)

  Added in Irssi 1.2.0

(quit_on_hup)=
`quit_on_hup` **`OFF`**

: Whether Irssi should /quit itself on receiving the HUP signal or reload its config instead. This setting may be desirable if you want to /quit Irssi with the [x] button on your terminal emulator window.

  Added in Irssi 1.3

(autoload_modules)=
`autoload_modules` **`perl otr`**

: Which modules should be loaded on Irssi start.

  Added in Irssi 1.3

##  [perl]

(perl_use_lib)=
`perl_use_lib` **`/usr/local/perl-582/i386-freebsd`**

: Which perl library to use, in case you have many to choose from.

##  [proxy]

(proxy_address)=
`proxy_address` **` `**

: The address of your IRC proxy.

(proxy_password)=
`proxy_password` **` `**

: The password to use if the proxy requires authentication.

(proxy_port)=
`proxy_port` **`6667`**

: The port of your IRC proxy.

(proxy_string)=
`proxy_string` **`CONNECT %s %d`**

: How to tell your proxy to initiate a connection.

  I haven't found documentation for the codes used in proxy_string.

  TODO - How do you tell Irssi to connect through a proxy that requires authentication?

(proxy_string_after)=
`proxy_string_after` **` `**

: Text to send after setting NICK and USER through a proxy.

(use_proxy)=
`use_proxy` **`OFF`**

: Tell Irssi whether it should connect through a proxy server.

##  [server]

(alternate_nick)=
`alternate_nick` **` `**

: An alternate nickname to use if your preferred one is already taken.

(hostname)=
`hostname` **` `**

: Your source hostname. Useful when you're on a multi-host system, and you want to look like you're connecting from a particular host.

  This setting tells Irssi which IP to bind to.

(nick)=
`nick` **`$IRCNICK`**

: Your main, preferred nick.

(real_name)=
`real_name` **`$IRCNAME`**

: Your real name.

(resolve_prefer_ipv6)=
`resolve_prefer_ipv6` **`OFF`**

: Turn this option on to prefer using an ipv6 address when a host has both ipv4 and ipv6 addresses.

(resolve_reverse_lookup)=
`resolve_reverse_lookup` **`OFF`**

: Removed in Irssi 1.3. See [resolve_reverse_lookup issues](https://github.com/irssi/irssi/issues?q=resolve_reverse_lookup) for more information.

(sasl_disconnect_on_failure)=
`sasl_disconnect_on_failure` **`ON`**

: Turn this option off to continue connecting to servers even when sasl authentication errors happen.

  Added in Irssi 1.0.0

(server_connect_timeout)=
`server_connect_timeout` **`5min`**

: How long to wait for a connection to be established.

  Be careful using very short timeouts. Servers may recognize the activity as abuse.

(server_reconnect_time)=
`server_reconnect_time` **`5min`**

: How long to wait between reconnects to the same server. Some servers will k-line you if you reconnect too quickly, so be careful setting this value lower.

  Setting the value to -1 will disable reconnects

(skip_motd)=
`skip_motd` **`OFF`**

: Turn this on to avoid displaying the server's message of the day. Messages of the day are often noisy, and few people actually read them, but they contain important information amongst the ASCII art and song lyrics. :)

(user_name)=
`user_name` **`$IRCUSER`**

: Set your system user name. This is used in times when you don't have working ident.

##  [servers]

(channels_rejoin_unavailable)=
`channels_rejoin_unavailable` **`ON`**

: Attempt to rejoin a channel if it's temporarily unavailable. Channels may be unavailable during netsplits.

(rejoin_channels_on_reconnect)=
`rejoin_channels_on_reconnect` **`ON`**

: Determines whether channels are rejoined on reconnect. Possible values are OFF, ON and AUTO:

  `off`
  : no channels are rejoined.

  `on` (default)
  : all channels are rejoined.

  `auto`
  : only channels configured with autojoins are rejoined.

  Added in Irssi 0.8.18. `auto` was added in Irssi 1.0.0

(starttls_sts)=
`starttls_sts` **`ON`**

: Whether to automatically add a starttls flag to a server once STARTTLS has succeeded.

  Added in Irssi 1.3

##  [irssiproxy]

Also see [proxy.txt](/documentation/proxy) for more information about the irssiproxy module.

(irssiproxy_ports)=
`irssiproxy_ports` **` `**

: A space-separated list of `networktag=port` that the irssiproxy should listen on. If you connect to the port, you will share the connection of the specified network in your Irssi.

  The special network name `?=port` can be used to select the network through your connect password.

  `?` was added in Irssi 1.0.0

(irssiproxy_password)=
`irssiproxy_password` **` `**

: The password required to connect to the irssiproxy.

(irssiproxy_bind)=
`irssiproxy_bind` **` `**

: The interface that the irssiproxy should listen on.

(irssiproxy)=
`irssiproxy` **`ON`**

: Here you can enable and disable the proxy.

  Added in Irssi 0.8.18

* * *

(a_a)=
##  Appendix A: Levels 

Levels are categories of messages that can be ignored or otherwise matched. Categories may be combined. For example, you may want to ignore only private messages (MSG) from someone, or you might really hate them and ignore MSGS and PUBLIC. Or even ALL.

See /help levels for a better, probably more current explanation of the different kinds of levels Irssi supports. Meanwhile:

| Level           | Description                              |
| --------------- | ---------------------------------------- |
|   CRAP          | ?                                        |
|   MSGS          | Match messages privately sent to you.    |
|   PUBLIC        | Match messages sent to public channels.  |
|   NOTICES       | Match NOTICE messages.                   |
|   SNOTES        | Match server notices.                    |
|   CTCPS         | Match CTCP messages.                     |
|   ACTIONS       | Match CTCP actions.                      |
|   JOINS         | Match join messages.                     |
|   PARTS         | Match part messages.                     |
|   QUITS         | Match quit messages.                     |
|   KICKS         | Match kick messages.                     |
|   MODES         | Match mode changes.                      |
|   TOPICS        | Match topic changes.                     |
|   WALLOPS       | Match wallops.                           |
|   INVITES       | Match invite requests.                   |
|   NICKS         | Match nickname changes.                  |
|   DCC           | DCC related messages.                    |
|   DCCMSGS       | Match DCC chat messages.                 |
|   CLIENTNOTICE  | Irssi's notices.                         |
|   CLIENTCRAP    | Miscellaneous Irssi messages.            |
|   CLIENTERROR   | Irssi's error messages.                  |
|                 |                                          |
|   ALL           | All previous message levels combined.    |
|                 |                                          |
|   HILIGHT       | Match highlighted messages.              |
|   NOHILIGHT     | Don't check a message's highlighting.    |
|   NO_ACT        | Don't trigger channel activity.          |
|   NEVER         | Never ignore, never log.                 |
|   LASTLOG       | Never ignore, never log.                 |

* * *

(a_b)=
##  Appendix B: Special Variables and Expandos 

Several settings allow special variables. These variables will be replaced by the text they represent at the time they're used. Not at the time you set the setting!

They are mostly used for formatting text in themes.

From <https://github.com/ailin-nemui/irssi/blob/master/docs/special_vars.txt>:


NOTE: This is just a slightly modified file taken from EPIC's help.

### Special Variables and Expandos

Irssi supports a number of reserved, dynamic variables, sometimes
referred to as expandos.  They are special in that the client is
constantly updating their values automatically.  There are also
numerous variable modifiers available.

| Modifier          | Description                                       |
| ----------------- | ------------------------------------------------- |
| $variable         | A normal variable, expanding to the first match of: <br>  1) an internal SET variable <br> 2) an environment variable |
| $[num]variable    | Expands to the variables value, with 'num' width. <br> If the number is negative, the value is right-aligned. <br> The value is padded to meet the width with the character given after number (default is space). <br> The value is truncated to specified width unless '!' character precedes the number. <br> If '.' character precedes the number the value isn't padded, just truncated. |
| $#variable        | Expands to the number of words in $variable. If $variable is omitted, it assumes $* |
| $@variable        | Expands to the number of characters in $variable. if $variable is omitted, it assumes $* |
| $($subvariable)   | This is somewhat similar to a pointer, in that the value of $subvar is taken as the name of the variable to expand to.  Nesting is allowed. |
| ${expression}     | Permits the value to be embedded in another string unambiguously. |
| $!history!        | Expands to a matching entry in the client's command history, wildcards allowed. |

Whenever an alias is called, these expandos are set to the arguments
passed to it.  If none of these expandos are used in the alias, or
the $() form shown above, any arguments passed will automatically be
appended to the last command in the alias.

| Expando | Description                                               |
| ------- | --------------------------------------------------------- |
| $*      | expands to all arguments passed to an alias               |
| $n      | expands to argument 'n' passed to an alias (counting from zero) |
| $n-m    | expands to arguments 'n' through 'm' passed to an alias   |
| $n-     | expands to all arguments from 'n' on passed to an alias   |
| $-m     | expands to all arguments up to 'm' passed to an alias     |
| $~      | expands to the last argument passed to an alias           |

These variables are set and updated dynamically by the client.  The
case of $A .. $Z is important.

| Variable | Description                                              |
| -------- | -------------------------------------------------------- |
| $,       | last person who sent you a MSG                           |
| $.       | last person to whom you sent a MSG                       |
| $:       | last person to join a channel you are on                 |
| $;       | last person to send a public message to a channel you are on |
| $A       | text of your AWAY message, if any                        |
| $B       | body of last MSG you sent                                |
| $C       | current channel                                          |
| $D       | last person that NOTIFY detected a signon for            |
| $E       | idle time                                                |
| $F       | time client was started, $time() format                  |
| $H       | current server numeric being processed                   |
| $I       | channel you were last INVITEd to                         |
| $J       | client version text string                               |
| $K       | current value of CMDCHARS                                |
| $k       | first character in CMDCHARS                              |
| $L       | current contents of the input line                       |
| $M       | modes of current channel, if any                         |
| $N       | current nickname                                         |
| $O       | value of STATUS_OPER if you are an irc operator          |
| $P       | if you are a channel operator in $C, expands to a '@'    |
|          |                                                          |
| $Q       | nickname of whomever you are QUERYing                    |
| $R       | version of current server                                |
| $S       | current server name                                      |
| $T       | target of current input (channel or nick of query)       |
| $U       | value of cutbuffer                                       |
| $V       | client release date (format YYYYMMDD)                    |
| $W       | current working directory                                |
| $X       | your /userhost $N address (user@host)                    |
| $Y       | value of REALNAME                                        |
| $Z       | time of day (hh:mm, can be changed with /SET timestamp_format) |
| $$       | a literal '$'                                            |
|          |                                                          |
| $versiontime      | prints time of the Irssi version in HHMM format |
| $sysname          | system name (eg. Linux)                         |
| $sysrelease       | system release (eg. 2.2.18)                     |
| $sysarch          | system architecture (eg. i686)                  |
| $topic            | channel topic                                   |
| $usermode         | user mode                                       |
| $cumode           | own channel user mode                           |
| $cumode_space     | like $cumode, but gives space if there's no mode. |
| $tag              | server tag                                      |
| $chatnet          | chat network of server                          |
| $winref           | window reference number                         |
| $winname          | window name                                     |
| $itemname         | like $T, but use item's visible_name which may be different <br> (eg. $T = !12345chan, $itemname = !chan) |

For example, assume you have the following alias:

    /alias blah msg $D Hi there!

If /blah is passed any arguments, they will automatically be appended
to the MSG text.  For example:

    /blah oops                    /* command as entered */
    Hi there! oops                /* text sent to $D */

Another useful form is ${}.  In general, variables can be embedded
inside strings without problems, assuming the surrounding text could
not be misinterpreted as part of the variable name.  This form
guarantees that surrounding text will not affect the expression's
return value.

    /eval echo foo$Nfoo             /* breaks, looks for $nfoo */
    /eval echo foo${N}foo           /* ${N} returns current nickname */
    fooYourNickfoo                  /* returned by above command */

* * *

(a_c)=
##  Appendix C: Time Formats 

Messages that describe times are formatted according to the strftime() function in C. According to FreeBSD's strftime() man page, parts of the format represented with % and a letter code are expanded in the following ways.

| Format | Description |
| ------ | ----------- |
| %A     | is replaced by national representation of the full weekday name. |
| %a     | is replaced by national representation of the abbreviated weekday name. |
| %B     | is replaced by national representation of the full month name. |
| %b     | is replaced by national representation of the abbreviated month name. |
| %C     | is replaced by (year / 100) as decimal number; single digits are preceded by a zero. |
| %c     | is replaced by national representation of time and date. |
| %D     | is equivalent to ``%m/%d/%y''. |
| %d     | is replaced by the day of the month as a decimal number (01-31). |
| %E* %O* | POSIX locale extensions.  The sequences %Ec %EC %Ex %EX %Ey %EY %Od %Oe %OH %OI %Om %OM %OS %Ou %OU %OV %Ow %OW %Oy are supposed to provide alternate representations. <br> Additionly %OB implemented to represent alternative months names (used standalone, without day mentioned). |
| %e     | is replaced by the day of month as a decimal number (1-31); single digits are preceded by a blank. |
| %F     | is equivalent to ``%Y-%m-%d''. |
| %G     | is replaced by a year as a decimal number with century.  This year is the one that contains the greater part of the week (Monday as the first day of the week). |
| %g     | is replaced by the same year as in ``%G'', but as a decimal number without century (00-99). |
| %H     | is replaced by the hour (24-hour clock) as a decimal number (00-23). |
| %h     | the same as %b. |
| %I     | is replaced by the hour (12-hour clock) as a decimal number (01-12). |
| %j     | is replaced by the day of the year as a decimal number (001-366). |
| %k     | is replaced by the hour (24-hour clock) as a decimal number (0-23); single digits are preceded by a blank. |
| %l     | is replaced by the hour (12-hour clock) as a decimal number (1-12); single digits are preceded by a blank. |
| %M     | is replaced by the minute as a decimal number (00-59). |
| %m     | is replaced by the month as a decimal number (01-12). |
| %n     | is replaced by a newline. |
| %O*    | the same as %E*. |
| %p     | is replaced by national representation of either ante meridiem or post meridiem as appropriate. |
| %R     | is equivalent to ``%H:%M''. |
| %r     | is equivalent to ``%I:%M:%S %p''. |
| %S     | is replaced by the second as a decimal number (00-60). |
| %s     | is replaced by the number of seconds since the Epoch, UTC (see mktime(3)). |
| %T     | is equivalent to ``%H:%M:%S''. |
| %t     | is replaced by a tab. |
| %U     | is replaced by the week number of the year (Sunday as the first day of the week) as a decimal number (00-53). |
| %u     | is replaced by the weekday (Monday as the first day of the week) as a decimal number (1-7). |
| %V     | is replaced by the week number of the year (Monday as the first day of the week) as a decimal number (01-53).  If the week containing January 1 has four or more days in the new year, then it is week 1; otherwise it is the last week of the previous year, and the next week is week 1. |
| %v     | is equivalent to ``%e-%b-%Y''. |
| %W     | is replaced by the week number of the year (Monday as the first day of the week) as a decimal number (00-53). |
| %w     | is replaced by the weekday (Sunday as the first day of the week) as a decimal number (0-6). |
| %X     | is replaced by national representation of the time. |
| %x     | is replaced by national representation of the date. |
| %Y     | is replaced by the year with century as a decimal number. |
| %y     | is replaced by the year without century as a decimal number (00-99). |
| %Z     | is replaced by the time zone name. |
| %z     | is replaced by the time zone offset from UTC; a leading plus sign stands for east of UTC, a minus sign for west of UTC, hours and minutes follow with two digits each and no delimiter between them (common form for RFC 822 date headers). |
| %+     | is replaced by national representation of the date and time (the format is similar to that produced by date(1)). |
| %%     | is replaced by `%'. |

* * *

(a_d)=
##  Appendix D: Color Codes 

Irssi defines codes to represent colors. They work like the `strftime()` codes in Appendix C.

From <https://irssi.org/documentation/formats>:

Irssi's colors that you can use in text formats, hilights, etc. :

|      |      |      | text     | text         | background |
| ---- | ---- | ---- | -------- | ------------ | ---------- |
|  %k  |  %K  |  %0  | black    | dark grey    | black      |
|  %r  |  %R  |  %1  | red      | bold red     | red        |
|  %g  |  %G  |  %2  | green    | bold green   | green      |
|  %y  |  %Y  |  %3  | yellow   | bold yellow  | yellow     |
|  %b  |  %B  |  %4  | blue     | bold blue    | blue       |
|  %m  |  %M  |  %5  | magenta  | bold magenta | magenta    |
|  %p  |  %P  |      | magenta  | (think: purple) |         |
|  %c  |  %C  |  %6  | cyan     | bold cyan    | cyan       |
|  %w  |  %W  |  %7  | white    | bold white   | white      |

|      |      |      |                                      |
| ---- | ---- | ---- | ------------------------------------ |
|  %n  |  %N  |      | Changes the color to default color, removing all other coloring and formatting. %N is always the terminal's default color. %n is usually too, except in themes it changes to previous color, ie. hello = %Rhello%n and %G{hello} world would print hello in red, and %n would turn back into %G making world green. |
|  %F  |      |      | Blinking on/off (think: flash)       |
|  %U  |      |      | Underline on/off                     |
|  %8  |      |      | Reverse on/off                       |
|  %9  |  %_  |      | Bold on/off                          |
|  %I  |      |      | Italic on/off                        |
|  %:  |      |      | Insert newline                       |
|  %\| |      |      | Marks the indentation position       |
|  %#  |      |      | Monospace font on/off (useful with lists and GUI) |
|  %%  |      |      | A single %                           |
|  %XAB |     |  %xAB | Color from extended plane (A=1-7, B=0-Z) |
|  %ZAABBCC | |  %zAABBCC | HTML color (in hex notation)    |

In .theme files %n works a bit differently. See default.theme for more
information.


* * *

(a_credits)=
## Appendix E: Credits and copyright

We respect the work of others. Parts of this document have been collected from other locations. Wherever possible, we have made every effort to locate and attribute the original authors. Please let us know if we've overlooked you.

We ask the same respect in return.

The original portions of this document are Copyright 2005 by Rocco Caputo rcaputo@cpan.org and Nei (on irc.libera.chat #irssi). Other portions are Copyright by their respective authors or licensors.

This work is licensed under a Creative Commons Attribution-ShareAlike 2.5 License. Please see <https://creativecommons.org/licenses/by-sa/2.5/> for details. Summary:

> You are free:
>
>   * to copy, distribute, display, and perform this work
>   * to make derivative works
>   * to make commercial use of this work
>
> Under the following conditions:
>
> Attribution.
> : You must attribute the work in the manner specified
>   by the author or licensor.
>
> Share Alike.
> : If you alter, transform, or build upon this work,
>   you may distribute the resulting work only under a license
>   identical to this one.
>
> * For any reuse or distribution, you must make clear to others the
>   license terms of this work.
> * Any of these conditions can be waived if you get permision from
>   the copyright holder.
>
> Your fair use and other rights are in no way affected by the above.


Sorry for the heavy license crap. Coekie wanted clarification.

<script src="../_static/prerenderimg.js"></script>
__HELP__
