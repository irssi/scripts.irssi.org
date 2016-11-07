use strict;
use warnings;

our $VERSION = '0.8.10'; # 865d608a5aa6332
our %IRSSI = (
    authors     => 'Rocco Caputo (dngor), Nei',
    contact     => 'rcaputo@cpan.org, Nei @ anti@conference.jabber.teamidiot.de',
    name        => 'settingshelp',
    description => "Irssi $VERSION settings notes and documentation",
    license     => 'CC BY-SA 2.5, http://creativecommons.org/licenses/by-sa/2.5/',
   );

# Usage
# =====
# Now you can do:
#
#   /help set setting_here
#
# to print out its documentation (as far as it was included in the
# Irssi 0.8.18 settings notes)

# NOTE
# ====
# the original settings.text is included in a heredoc string at the
# end of this script.

my $setting;
my %help;
my $help;
my $license;
my $header = 1;
for (split "\n", $help) {
	chomp;
	if (/^\s*$/) {
		undef $header;
	}
	if (/^  (\w.*) =/) {
		$setting =  "\L$1";
	}
	elsif (/^ {3}/ || /^\s*$/) {}
	else { undef $setting }
	if ($setting) {
		push @{$help{"settings/$setting"}}, $_
	}
	if (/License/) {
		print CLIENTCRAP '%U%_Irssi Settings documentation license%:' unless $license;
		$license = 1;
	}
	if ($header || $license) {
		print CLIENTCRAP $_;
	}
}

print CLIENTCRAP '%:You can now read help for settings with %_/HELP SET settingname%_';

Irssi::signal_add_first(
	'command help' => sub {
		if ($_[0] =~ s|^set\s+|settings/|i && $_[0] ne 'settings/' && ($_[0]="\L$_[0]")
		   && $_[0] =~ /^(.*?)(?:\s+|$)/ && exists $help{$1}) {
			print CLIENTCRAP join "\n", '%_Setting:%_%:', @{$help{$1}};
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

UNITCHECK { $help = <<'END'; }
Irssi 0.8.10 settings notes.  Gathered through much effort by Rocco
Caputo <rcaputo at cpan dot org> (aka "dngor").  Includes original
work by Nei, and advice and guidance from irc.freenode.net #irssi.

This is not an attempt to document Irssi completely.  It should be
used along with the documents at <http://irssi.org/documentation> for
more complete understanding of how irssi works.  For example, the
startup HOWTO and tips/tricks show sample uses for these settings,
including some very useful stuff.

We respect the work of others.  Parts of this document have been
collected from other locations.  Wherever possible, we have made every
effort to locate and attribute the original authors.  Please let us
know if we've overlooked you.

We ask the same respect in return.  The Copyright and license notices
are at the end.

-----

2005-Dec-08: (dngor)

  Switched to Creative Commons' ShareAlike license.  We'd like to
  thank Coekie <coekie@irssi.org> for pointing out out that the
  previous license was weak, and that he could just alter it and
  redistribute our work without attribution.

  Minor revisions throughout a major portion of the document.

2005-Dec-07: (Nei)

  Set example values to default values where appropriate.
  Add new settings from 0.8.10.
  Sorted settings according to my local /set output.

  (dngor) Marked the 0.8.10 settings as coming from that version.

2005-Dec-01: (Nei)

  Updated some links. Renamed term_type.

2005-06-05: (dngor)

  Tweaked an example to use the same command the surrounding text said
  it was.

2005-05-04: (dngor)

  Not terribly significant.  All edits happened in the introduction.

-----

[completion]

  completion_strict = OFF

    When on, nicknames are matched strictly.  That is, the partial
    nickname you enter must be at the beginning of a nickname in one
    of irssi's lists.

    When off, irssi will first try a strict match.  If a strict match
    can't be found, irssi will look for nicknames that match when
    their leading non-alphanumeric characters are removed.  For
    example:

      vis: hello

    With strict completion on, it will only match nicknames beginning
    with "vis".  With strict completion off, it may match "visitors"
    or "_visitors_" or "[visitors]", and so on.

  completion_keep_privates = 10

    Irssi keeps a list of nicknames from private messages to search
    during nick completion.  This setting determines how many
    nicknames are held.

    TODO - Is this list maintained by people who privately message
    you, who you privately message, or both?

  completion_char = :

    The text that irssi puts after a tab-completed nickname, or that
    it uses to detect nicknames when you have completion_auto turned
    on.  Some people alter this to colorize the completion character,
    creating the oft-dreaded "bold colon".

  completion_auto = OFF

    Tell irssi to detect incomplete nicknames in your input and look
    up their completions automatically.  Incomplete nicknames are
    detected when you input text that matches
    /^(\S+)${completion_character}/.  For example:

      vis: hello

    will be expanded to

      visitors: hello

    when you press enter.  So will:

      vis:hello
      Vis::Hello(12);

    This will eventually bite you.

  completion_nicks_lowercase = OFF

    When enabled, irssi forces completed nicknames to lowercase.
    Manually typed nicknames retain their case.

  completion_keep_publics = 50

    Irssi keeps a list of nicknames from public messages to search
    during nick completion.  This setting determines how many
    nicknames are held.

    TODO - Is this list maintained by watching who you speak to, who
    speak to you, or both?

[dcc]

  dcc_autorename = OFF

    Turn on this setting to automatically rename received files so
    they don't overwrite existing files.

    I think this setting may thwart dcc_autoresume, since the
    auto-resume feature looks for existing filenames when resuming.
    Auto-renaming downloads makes sure that filenames never conflict,
    so resuming is not possible.

  dcc_autoresume = OFF

    When on, dcc_autoresume will cause irssi to look for existing
    files with the same name as a new DCC transfer.  If a file already
    exists by that name, irssi will try to resume the transfer by
    appending any new data to the existing file.

    I think this option clashes with dcc_autorename.  See
    dcc_autorename for more information.

    Dcc_autoresume is ignored if dcc_autoget is off.

  dcc_timeout = 5min

    How long to keep track of pending DCC requests.  Requests that do
    not receive responses within this time will be automatically
    canceled.

  dcc_autoget = OFF

    Turn DCC auto-get on or off.  When on, irssi will attempt to
    auto-get files sent to you.
    
    This feature can be abused, so it is usually off by default.  If
    you enable it, consider also setting dcc_autoget_masks and
    dcc_autoget_max_size to make this feature more secure.

  dcc_upload_path = ~

    The path where you keep public files available to send via DCC.

  dcc_autoget_masks =

    Set dcc_autoget_masks with user masks to automatically accept
    files sent to you via DCC.  When unset, irssi's auto-get settings
    will work for everyone who attempts to send you files.

    This setting is only significant if dcc_autoget is ON.

  dcc_autoget_max_size = 0k

    Set to nonzero to limit the size of files that irssi will
    auto-get.

    Note: Because of the way DCC works, someone may advertise a file
    at once size but try to send you something larger.  According to
    src/irc/dcc/dcc-autoget.c, this only filters the request based on
    the advertised size.

    This setting is only significant if dcc_autoget is ON.

  dcc_send_replace_space_with_underscore = OFF

    When enabled, irssi will replace spaces with underscores in the
    names of files you send.  It should only be necessary when sending
    files to clients that don't support quoted filenames, or if you
    hate spaces in filenames.

  dcc_own_ip =

    Set dcc_own_ip to force irssi to always send DCC requests from a
    particular virtual host (vhost).  Irssi will always bind sockets
    to this address when answering DCC requests.  Otherwise irssi will
    determine your IP address on its own.

  dcc_download_path = ~

    The path to a directory where irssi will store DCC downloads.

  dcc_file_create_mode = 644

    The mode in which new files are created.

      644 is read/write by you, and readable by everybody else.  600
      is read/write by you, nobody else can read or write.

  dcc_port = 0

    The smallest port number that irssi will use when initiating DCC
    requests.  Irssi picks a port at random when this is set to zero.

    dcc_port can be two ports, separated by a space.  In that case,
    irssi will pick a port between the two numbers, inclusively.  For
    example:

      /set dcc_port 10000 20000

  dcc_autochat_masks =

    Set dcc_autochat_masks with user masks to auto-accept chat
    requests from.  When unset, irssi's auto-accept settings work for
    everyone who tries to DCC chat you.  The drawbacks can range from
    annoying through downright dangerous.  Use auto-accept with care.

  dcc_mirc_ctcp = OFF

    Tells irssi to send CTCP messages that are compatible with mIRC
    clients.  This lets you use "/me" actions in DCC chats with mIRC
    users, among other things.

  dcc_autoaccept_lowports = OFF

    When this setting is OFF, irssi will not auto-accept DCC requests
    from privileged ports (those below 1024) even when auto-accept is
    otherwise on.

[flood]

  autoignore_time = 5min

    Irssi can auto-ignore people who are flooding.  autoignore_time
    sets the amount of time to keep someone ignored.  Irssi will
    automatically unignore them after this period of time has elapsed.

  autoignore_level =

    The type or types of messages that will trigger auto-ignore.

  flood_max_msgs = 4
  flood_timecheck = 8

    Irssi will treat text as flooding if more than flood_max_msgs
    messages are received during flood_timecheck seconds.  In the case
    above, five or more messages matching autoignore_level over the
    course of eight seconds will trigger flood protection.  See
    autoignore_time to set the amount of time someone will remain
    ignored if it's determined that they're flooding.

  cmds_max_at_once = 5

    How many commands you can send immediately before server-side
    flood protection starts.

    IRC servers also perform flood checking, and they will gleefully
    disconnect you if you are abusing them.  The cmds_max_at_once
    setting lets irssi know how many rapid messages it can get away
    with while remaining under the IRC server's radar.

  cmd_queue_speed = 2200msec

    The time to wait between sending commands to an IRC server.  Used
    to prevent irssi from flooding you off if you must auto-kick/ban
    lots of people at once.

  max_ctcp_queue = 5

    The maximum number of pending CTCP requests to keep.  Requests
    beyond max_ctcp_queue will be discarded.

[history]

  scrollback_save_formats = OFF

    Turn on to save formats in the scrollback buffer, so that old
    messages are not changed by new themes.  Turn off so the current
    theme applies to your entire scrollback buffer.

    Setting this to OFF doesn't seem to do anything, however.

  scroll_page_count = /2

    How many pages to scroll the scrollback buffer when pressing
    page-up or page-down.  Expressed as a number of lines, or as a
    fraction of the screen:

      /2  = Scroll half a page.
      .33 = Scroll about a third of a page.
      4   = Scroll four lines.

    <http://bugs.irssi.org/index.php?do=details&id=254> contains a
    patch thet lets you specify a negative number to scroll "all but
    this many" lines.  That is, -1 will scroll a full page minus one
    line, for people who like that.

  window_history = OFF

    When turned ON, command history will be kept per-window.  When
    off, irssi uses a single command history for all windows.

  max_command_history = 100

    The number of lines of your own input to keep for recall.

  scrollback_time = 1day

    Keep at least scrollback_time worth of messages in the scrollback
    buffer, even if it means having more than scrollback_lines lines
    in the buffer.

  rawlog_lines = 200

    Irssi's raw log is a buffer of raw IRC messages.  It's used for
    debugging irssi and maybe some other things.  This setting tells
    irssi how many raw messages to keep around.

  scrollback_lines = 500

    The maximum number of messages to keep in your scrollback history.
    Set to 0 if you don't want to limit scrollback by a line count.
    The scrollback_time setting will be used even if scrollback_lines
    is zero.

    Setting scrollback_lines to zero also seems to thwart the
    scrollback_burst_remove optimization.

  scrollback_burst_remove = 10

    This is a speed optimization: Don't bother removing messages from
    the scrollback buffer until the line limit has been exceeded by
    scrollback_burst_remove lines.  This lets irssi do its memory
    management in chunks rather than one line at a time.

    TODO - Is this right?

[log]

  log_close_string = --- Log closed %a %b %d %H:%M:%S %Y

    The message to log when logs are closed.

    See Appendix C for the meanings of Irssi's time format codes.

  log_timestamp = %H:%M

    The time format for log timestamps.

    See Appendix C for the meanings of Irssi's time format codes.

  autolog_colors = OFF

    Whether to save colors in autologs.  Colors make logs harder to
    parse and grep, but they may be vital for channels that deal
    heavily in ANSI art, or something.

  autolog_level = all -crap -clientcrap -ctcps

    The types of messages to auto-log.  See the autolog setting.

  awaylog_colors = ON

    Whether to store color information in /away logs.

  log_day_changed = --- Day changed %a %b %d %Y

    The message to log when a new day begins.

    See Appendix C for the meanings of Irssi's time format codes.

  autolog = OFF

    Automatically log everything, or at least the types of messages
    defined by autolog_level.

  autolog_path = ~/irclogs/$tag/$0.log

    The path where autolog saves logs.

    See Appendix B for Irssi's special variables.  Irssi's special
    variables can be used to do fancy things like daily log rotations.

  awaylog_level = msgs hilight

    The types of messages to log to awaylog_file while you're away.

  awaylog_file = ~/.irssi/away.log

    Where to log messages while you're away.
    
    I assume irssi's special variables also work here.  See Appendix B
    for more information about them.

  log_theme =

    Logs can have a different theme than what you see on the screen.
    This can be used to create machine-parseable versions of logs, for
    example.

  log_create_mode = 600

    The permissions to use when creating log files.

    600 is read/write by you, but nobody else can see them.  A
    sensible default mode.  It can also be set to 644 if you want the
    rest of the world to read your logs.

  log_open_string = --- Log opened %a %b %d %H:%M:%S %Y

    The message to log when a log is opened.

    See Appendix C for the meanings of Irssi's time format codes.

[lookandfeel]

  show_names_on_join = ON

    Display the list of names in a channel when you join that channel.
    It's generally recommended, but you can disable it for
    pathologically huge channels or in case you just don't care.

  window_check_level_first = OFF
  window_default_level = NONE

    From irssi's ChangeLog:

    Added /SET window_check_level_first and /SET window_default_level.
    This allows you to keep all messages with specific level in it's
    own window, even if it was supposed to be printed in channel
    window.  patch by mike@po.cs.msu.su

    Try to choose better the window where we print when matching by
    level and multiple windows have a match.  Should fix problems with
    query windows with a default msgs window + /SET
    window_check_level_first ON.

    Wouter Coekaerts has made a nice explanation about this, see
    <http://wouter.coekaerts.be/site/irssi/wclf>

  emphasis = ON

    Enable or disable real underlining and bolding when someone says
    *bold* or _underlined_.

  autocreate_split_windows = OFF

    Automatically created windows will be created as split windows
    with this setting on.

    Split windows are the kind where multiple windows are on one
    screen.

  beep_msg_level =

    Beep when messages match this level mask.

  actlist_moves = OFF

    When on, irssi rearranges the activity list so windows with more
    recent activity appear first.  Otherwise windows are listed in
    numeric order.

  hilight_nick_matches = ON

    Tell irssi whether it should automatically highlight text that
    matches your nickname.

  emphasis_multiword = OFF

    Turn on to allow *more than one word bold* and _multiple
    underlined words_.  Used in conjunction with the emphasis setting.

  hide_colors = OFF

    Hide mIRC and ANSI colors when turned on.  This can be used to
    eliminate "angry fruit salad" syndrome in some channels.

  names_max_width = 0

    Maximum number of columns to consume with a /names listing.
    Overrides names_max_columns if non-zero.  Set to 0 for "as many as
    fit in your terminal".

  mirc_blink_fix = OFF

    Some terminals interpret bright background colors as blinking
    text.  mIRC doesn't support blinking at all.  This fixes the
    blinky terminals by replacing high colors with their low
    equivalents.

    From irssi's ChangeLog:

      /SET mirc_blink_fix - if ON, the bright/blink bit is stripped
      from MIRC colors. Set this to ON, if your terminal shows bright
      background colors as blinking.

  autoclose_windows = ON

    Automatically close windows when nobody is in them.  This keeps
    your window list tidy, but it means that query windows may
    rearrange as people log off then privately message you later.

  bell_beeps = OFF

    Tell irssi whether bell characters (chr 7, ^G) should actually
    cause beeps.
    
    According to Nei, bell_beeps seems to cover the case where a beep
    is caused by a printed message/format.  It's unrelated to activity
    beeps.

  hide_server_tags = OFF

    Server tags are prefixes to some messages (server messages?) that
    let you know which server the message came from.  They're often
    considered noisy, so this option lets you hide them.

  show_nickmode = ON

    Prefix nicknames with their channel status:
    
      voiced  +
      half-op %
      op      @

  theme = default

    Irssi supports themes that can change most of the client's look
    and feel.  This setting lets you name the theme you wish to use.

  timestamps = ON

    Turn timestamps on or off.  When off, not even timestamp_level
    will trigger them.

  indent = 10

    How many columns to indent subsequent lines of a wrapped message.

    Attention: This can be overwritten by themes.

  timestamp_format = %H:%M

    How to format the time used in timestamps.

    See Appendix C for the meanings of Irssi's time format codes.

  activity_msg_level = PUBLIC

    Flag a channel as active when messages of this type are displayed
    there.

  print_active_channel = OFF

    Always print the channel with the nickname (like <nick:channel>)
    even if the message is from the channel you currently have active.

  autoclose_query = 0

    Automatically close query windows after autoclose_query seconds of
    inactivity.  Setting autoclose_query to zero will keep them open
    until you decide to close them yourself.

  activity_hide_targets =

    Sometimes you don't care at all about a channel's activity.  This
    can be set to a list of channels that will never appear to be
    active.

  use_msgs_window = OFF

    Use a single window for all private messages.  This setting only
    makes sense if automatic query windows is turned off.

  timestamp_timeout = 0

    The amount of time to leave timestamps on after a timestamp_level
    message triggered timestamping.  Useful for people who think
    timestamps are noisy but would like timestamps for important
    conversations.

  use_status_window = ON

    Create a separate window for all server status messages, so they
    don't clutter up your channels.

  windows_auto_renumber = ON

    Closing windows can create gaps in the window list.  When
    windows_auto_renumber is turned on, however, windows are shifted
    to lower numbers in the list to fill those gaps.

  show_nickmode_empty = ON

    If a person has no channel modes, prefix their nickname with a
    blank space.  This keeps nicknames of normal people aligned with
    those of voiced, half-opped, and opped people.

  beep_when_away = ON

    Should beeps be noisy when you're /away?  Great for people who
    sleep near their terminals or keep irssi running at work. :)

  timestamp_level = ALL

    Types of messages to prefix a timestamp to.  Useful for explicit
    or automatic timestamps.
    
    Once timestamping is temporarily turned on, it may stay on for
    timestamp_timeout seconds.

  indent_always = OFF

    Should we indent the long words that are forcibly wrapped to the
    next line?  This can break long "words" such as URLs by inserting
    spaces in the middle of them.

    Turn off if you would like to copy/paste or otherwise use URLs
    from your terminal.

  hilight_color = %Y

    The default color for /hilight.

    See Appendix D for Irssi's color codes.

  emphasis_replace = OFF

    If emphasis is turned on, the * or _ characters indicating
    emphasis will be removed when the word is made bold or underlined.
    Some people find this looks cleaner.

    See the emphasis setting for more information.

  hilight_level = PUBLIC DCCMSGS

    The types of messages that can be highlighted.

  hilight_act_color = %M

    The color to use to highlight window activity in the status bar.
    That's the section that shows "[Act: ...]".

    See Appendix D for Irssi's color codes.

  expand_escapes = OFF

    Detect escapes in input, and expand them to the characters they
    describe.  For example

      \t

    Is literally '\' and 't' when expand_escapes is off, but it's the
    tab character (chr 9) when expand_escapes is on.

  autocreate_windows = ON

    When on, create new windows for certain operations, such as /join.
    When off, everything is just dumped into one window.

  autocreate_query_level = MSGS DCCMSGS

    Automatically create query windows when receiving these types of
    messages.

  term_auto_detach = OFF

    Automatically detach from the terminal when it disappears.

    This doesn't actually work.  Or if it does, there's currently no
    way to re-attach to the terminal.  It may be useful for setting up
    daemons where you don't want to run nohup or screen, however.

  hide_text_style = OFF

    Hide bold, blink, underline, and reverse attributes.

  whois_hide_safe_channel_id = ON

    Introduced in 0.8.10.

    Hides the unique id of !channels in /whois output (IRCNet/irc2
    networks only).

    E.g. shows !channel instead of !12345channel

  names_max_columns = 6

    Maximum number of columns to use for /names listing.  Also shown
    on channel join.  Set to 0 for "as many as fit in your terminal".

  chanmode_expando_strip = OFF

    When on, $M will not return mode parameters.

    This means for example that the channel limit and channel key
    won't be shown in your statusbar (a common place where $M is used)
    (but also not in all other places that refer to $M for whatever
    reason).

  show_quit_once = OFF

    When turned on, a quit message will only be shown once.  Otherwise
    it will be displayed in every window you share with the quitter.

  show_away_once = ON

    When on, only show /away messages in the window that's currently
    open.  Otherwise the message will appear in every window you share
    with the away person.

  autocreate_own_query = ON

    Turn on to automatically create query windows when you /msg
    someone.

  term_charset = US-ASCII

    Sets your native terminal character set.  Irssi will take this
    into consideration when it needs to delete multibyte characters,
    for example.

    A common value is utf-8 for Unicode/UTF-8 enabled terminals.

    TODO - Does this still support Chinese terminal emulators? (Used
    to be term_type = big5 in old Irssi.)

  activity_hilight_level = MSGS DCCMSGS

    There are times when you want to highlight channel activity in a
    window.  Like when someone sends you a private message, or a DCC
    message.  Activity_highlight_level sets the kind of messages you
    think are extra important.

  autostick_split_windows = ON

    TODO - What is this?

    Nei says:  Setting split windows to stick means that their content
    won't change.  Best thing to come up with a viable description
    might be if you tried it.

    f0rked has written an excellent guide to irssi's split windows:
    <http://f0rked.com/articles/irssisplit>

  query_track_nick_changes = ON

    Query windows will track nick changes when this is on.  That is,
    it looks for a matching user@host if a message comes in with an
    unknown nick.

    TODO - Really?

  scroll = ON

    Set scroll ON to have irssi scroll your screen when it fills up.
    Set it OFF to require manual scrolling.

    Warning: If set to OFF, this will stop scrolling in all windows
    and not reenable scrolling even if you set it back to ON. (You
    need to manually scroll to the bottom in each window first.)

  window_auto_change = OFF

    Turn this on to automatically switch to newly-created windows.
    This may cause you to misdirect messages, so be careful.

  beep_when_window_active = ON

    Should beeps be noisy in a window you're watching?  Perhaps not,
    since you are theoretically watching that window.  You ARE
    watching it, aren't you?

  activity_hide_level =

    Message levels that don't count towards channel activity.  That
    is, channels won't be marked as "active" if messages of these
    types appear.

  show_own_nickchange_once = OFF

    Squash your own nick-change messages so they appear only once, not
    once in every window you have on that network.

  reuse_unused_windows = OFF

    When set on, irssi will reuse unused windows when looking for a
    new window to put something in.  Otherwise unused windows are
    ignored, and new ones are always created.

  colors = ON

    Enable or disable colors.

  term_force_colors = OFF

    Always display colors, even when the terminal type says colors
    aren't supported.  Useful for working around really dumb
    terminals.

  autofocus_new_items = ON

    Switch the focus to a new item when it's created.  This may be
    disturbing at first when combined with query window auto-creation,
    and it may be downright dangerous if it causes you to accidentally
    misdirect messages.

[misc]

  opermode =

    When set, irssi will set your modes to match opermode when you
    /oper up.  For example, you might

      /set opermode +s 1048575

  channel_max_who_sync = 1000

    Introduced in 0.8.10.

    The maximum number of users that may be in a channel for Irssi to
    issue a

      /who #channel

    in order to obtain the hostmasks of every participant.

    If this is set too high, IRC servers might kick you for "Sendq
    exceeded".

  recode_autodetect_utf8 = ON

    Introduced in 0.8.10.

    Irssi's recode system is broken.  This tries to cover up for it by
    leaving messages intact that seem to decode fine as Unicode UTF-8.

  lag_check_time = 1min

    How long to wait between active lag checks.  Irssi will passively
    check for lag when you're active, but sometimes it's necessary to
    actively check.  This is the minimum amount of time between active
    checks.

  quit_message = leaving

    Default message to send when /quit'ting.

  paste_detect_time = 5msecs

    Irssi will detect pastes when your input has less than this much
    time between lines.

  notify_check_time = 1min

    How often to check for someone online when /notify is on.

  help_path = /usr/local/share/irssi/help

    One or more paths where irssi will look for its help database.
    Multiple paths are separated by ":".  It's very important that
    this is correct.

  ctcp_userinfo_reply = $Y

    The reply to send when someone queries your user information.  By
    default, it's "$Y", which is defined by the real_name setting.

    See <http://irssi.org/documentation/special_vars> for more special
    variables you can use.

  override_coredump_limit = ON

    Allow really really big coredumps if this is set on.

  join_auto_chans_on_invite = ON

    Automatically join a channel when invited to it.

    TODO - Does this only work with channels on the /channel add -auto
    list?

  netjoin_max_nicks = 10

    When non-zero, limits the number of nicknames to display during
    netjoins.

    TODO - Is this correct?

  paste_join_multiline = ON

    Introduced in 0.8.10.

    Irssi will try to concatenate multiple lines into a single lined
    message when these lines have the same indentation level and
    "look" like they were copied out of Irssi.

    It's useful for quoting e-mail or other large-text messages, but
    it will probably bite you if you try to pasted indented text, such
    as code listings.  Irssi will join multiple lines of code,
    destroying any structure you wanted to preserve.

  channel_sync = ON

    Set whether irssi should synchronize a channel on join.  When
    enabled, irssi will gather extra information about a channel:
    modes, who list, ban list, ban exceptions,  and invite list.

  paste_detect_keycount = 5

    Introduced in 0.8.10.

    TODO - What's this?

  recode_fallback = CP1252

    Introduced in 0.8.10.

    If you have Irssi compiled with recode support and Irssi believes
    that a message you received did not recode properly in your
    terminal default character set (or the specified one), it will
    recode the message using this character set.

    (CP1252, the irssi default, is the Microsoft(R) Windows default
    character set for Western Europe.)

    Also see /help recode for more details about recoding.

  notify_idle_time = 1hour

    Irssi will notify you when someone you're watching becomes idle
    for this long.

  massjoin_max_joins = 3

    If nonzero, detect mass joins.  A mass join is when someone joins
    more than massjoin_max_joins per massjoin_max_wait seconds.

    TODO - Or is this when more than massjoin_max_joins people join
    per massjoin_max_wait seconds, regardless of the user mask?

  write_buffer_size = 0

    Amount of text (logs, etc) to buffer in memory before writing to
    disk.  Useful for minimizing disk access.

  write_buffer_timeout = 0

    Amount of time to keep text in memory.  A buffer is flushed to
    disk if the text in it is this old, even if the buffer isn't full.

    Useful in conjunction with really large write_buffer_size values,
    to prevent a lot of text from being lost if irssi crashes or is
    killed.

  STATUS_OPER = *

    TODO - What's this?

  recode = ON

    Introduced in 0.8.10.

    This setting allows you to disable irssi's recode functionality,
    if you prefer your messages not being messed with.

  ban_type = normal

    The default ban type to use: normal, user, host, domain, custom?
    See "/help ban" for a description of ban types.

  lag_max_before_disconnect = 5min

    Irssi detects your lag and will reconnect you automatically if
    your lag exceeds this value.

  part_message =

    Default message to send when parting a channel.

  auto_whowas = ON

    Automatically try /whowas if you /whois someone who isn't online.

  paste_verify_line_count = 5

    Ask you whether you meant to paste something if it's longer than
    this many lines.

  max_wildcard_modes = 6

    When set nonzero, don't mass op/deop/kick more than this many
    people.  Commands that let you do things to other nicks can take
    wildcards.  For example

      /kick floodbot* flooding

    would kick everybody whose nickname began with "floodbot".  Unless
    there were more than max_wildcard_modes of them.

    This setting prevents you from embarassment like:

      /kick *

    You can specify "-yes" if you really want to do it:

      /kick -yes *

  hide_netsplit_quits = ON

    Don't display quit messages if they're the product of a netsplit.
    Some people find this helpful, while others find it creepy.

  knockout_time = 5min

    Knockouts are temporary kickbans.  Knockout_time is the default
    amount of time before each temporary ban is lifted.

    See /help knockout

  massjoin_max_wait = 5000

    The amount of time to watch for mass-joins.

    I'm not sure which unit of time is used to measure
    massjoin_max_wait.

  lag_min_show = 1sec

    Lag is a part of life on IRC.  Don't bother displaying lag that's
    below this threshold, presumably because you consider it to be
    insignificant.

  wall_format = [Wall/$0] $1-

    Format for wall messages.

  netsplit_nicks_hide_threshold = 15

    Limit the number of nicks to display during netsplits to this
    many.  Or don't limit them at all, if this is set to 0.

  settings_autosave = ON

    Automatically save your settings when you quit irssi, or once per
    hour, rather than waiting for you to /save them yourself.

  translation =

    Set the translation table to use.  See Appendix E.

    TODO - Does this still work even?

  group_multi_mode = ON

    Consolidate multiple consecutive channel modes into a single
    message.  This will delay the display of channel modes for a short
    period of time while it waits to see if multiple modes are
    occurring.

  recode_out_default_charset =

    Introduced in 0.8.10.

    The outgoing character set you want your messags to be recoded
    into, if different from your term_charset.

  cmdchars = /

    Prefix characters that tell irssi that your input is a command
    rather than chat text.

  notify_whois_time = 5min

    How often to check /whois on a user who's online, to see if their
    /away or idle status changes.

  kick_first_on_kickban = OFF

    Kickban will normally ban first, then kick.  Turn this option on
    to reverse the situation, which can create a race condition if the
    user rejoins between your kick and the subsequent ban.

  recode_transliterate = ON

    Introduced in 0.8.10.

    If enabled, irssi tells iconv to try and replace characters that
    don't recode well with similar looking ones that exist in the
    target character set.

    If disabled, irssi replaces the character it could not recode with
    a "?" instead.

  usermode = +i

    Default modes to set yourself once you've connected to a server.

  ignore_signals =

    Operating system signals to ignore.  May be zero or more of: int,
    quit, term, alrm, usr1, and usr2.

  netsplit_max_nicks = 10

    When non-zero, limits the number of nicknames to display during
    netsplits.

    TODO - Is this correct?

  ctcp_version_reply = irssi v$J - running on $sysname $sysarch

    What to tell someone when they query your client's version.
    
    Some people consider announcing your client and operating system
    type and version to be a security hole.  Those people change this
    setting.

[perl]

  perl_use_lib = /usr/local/perl-582/i386-freebsd

    Which perl library to use, in case you have many to choose from.

[proxy]

  use_proxy = OFF

    Tell irssi whether it should connect through a proxy server.

  proxy_string = CONNECT %s %d

    How to tell your proxy to initiate a connection.

    I haven't found documentation for the codes used in proxy_string.

    TODO - How do you tell irssi to connect through a proxy that
    requires authentication?

  proxy_string_after =

    Text to send after setting NICK and USER through a proxy.

  proxy_address =
  proxy_port = 6667

    The address and port of your IRC proxy.

  proxy_password =

    The password to use if the proxy requires authentication.

[server]

  server_connect_timeout = 5min

    How long to wait for a connection to be established.

    Be careful using very short timeouts.  Servers may recognize the
    activity as abuse.

  resolve_reverse_lookup = OFF

    When connecting, resolve the server's IP address back into its
    hostname.  Probably useful for figuring out exactly which server
    you're on after resolving a round-robin host.

  ssl_cacert =
  ssl_cafile =
  ssl_cert =
  ssl_pkey =
  ssl_verify = OFF
  use_ssl = OFF

    SSL options.  Set the certificates and keys, and stuff you'll use
    to connect to a secure server.

    TODO - Does verify work? If so, how?

  hostname =

    Your source hostname.  Useful when you're on a multi-host system,
    and you want to look like you're connecting from a particular
    host.

    This setting tells irssi which IP to bind to.

  user_name = $IRCUSER

    Set your system user name.  This is used in times when you don't
    have working ident.

  resolve_prefer_ipv6 = OFF

    Turn this option on to prefer using an ipv6 address when a host
    has both ipv4 and ipv6 addresses.

  nick = $IRCNICK

    Your main, preferred nick.

  alternate_nick =

    An alternate nickname to use if your preferred one is already
    taken.

  real_name = $IRCNAME

    Your "real" "name".

  skip_motd = OFF

    Turn this on to avoid displaying the server's message of the day.
    Messages of the day are often noisy, and few people actually read
    them, but they contain important information amongst the ASCII art
    and song lyrics. :)

  server_reconnect_time = 5min

    How long to wait between reconnects to the same server.  Some
    servers will k-line you if you reconnect too quickly, so be
    careful setting this value lower.

[servers]

  channels_rejoin_unavailable = ON

    Attempt to rejoin a channel if it's "temporarily unavailable".
    Channels may be unavailable during netsplits.

-----

Appendix A: Levels

Levels are categories of messages that can be ignored or otherwise
matched.  Categories may be combined.  For example, you may want to
ignore only private messages (MSG) from someone, or you might really
hate them and ignore MSGS and PUBLIC.  Or even ALL.

See "/help levels" for a better, probably more current explanation of
the different kinds of levels irssi supports.  Meanwhile:

  CRAP          - ?
  MSGS          - Match messages privately sent to you.
  PUBLIC        - Match messages sent to public channels.
  NOTICES       - Match NOTICE messages.
  SNOTES        - Match server notices.
  CTCPS         - Match CTCP messages.
  ACTIONS       - Match CTCP actions.
  JOINS         - Match join messages.
  PARTS         - Match part messages.
  QUITS         - Match quit messages.
  KICKS         - Match kick messages.
  MODES         - Match mode changes.
  TOPICS        - Match topic changes.
  WALLOPS       - Match wallops.
  INVITES       - Match invite requests.
  NICKS         - Match nickname changes.
  DCC           - DCC related messages.
  DCCMSGS       - Match DCC chat messages.
  CLIENTNOTICE  - Irssi's notices.
  CLIENTCRAP    - Miscellaneous irssi messages.
  CLIENTERROR   - Irssi's error messages.

  ALL           - All previous message levels combined.

  HILIGHT       - Match highlighted messages.
  NOHILIGHT     - Don't check a message's highlighting.
  NO_ACT        - Don't trigger channel activity.
  NEVER         - Never ignore, never log.
  LASTLOG       - Never ignore, never log.

-----

Appendix B: Special Variables and Expandos

Several settings allow special variables.  These variables will be
replaced by the text they represent at the time they're used.  Not at
the time you set the setting!

They are mostly used for formatting text in themes.

From <http://irssi.org/documentation/special_vars> :

  NOTE: This is just a slightly modified file taken from EPIC's help.

  Special Variables and Expandos

  Irssi supports a number of reserved, dynamic variables, sometimes
  referred to as expandos.  They are special in that the client is
  constantly updating their values automatically.  There are also
  numerous variable modifiers available.

     Modifier          Description
     $variable         A normal variable, expanding to the first match
                       | of:
                       |  1) an internal SET variable
                       |  2) an environment variable
     $[num]variable    Expands to the variables value, with 'num' width.
                       | If the number is negative, the value is
                       | right-aligned.
                       | The value is padded to meet the width with the
                       | character given after number (default is
                       | space).
                       | The value is truncated to specified width
                       | unless '!' character precedes the number. If
                       | '.' character precedes the number the value
                       | isn't padded, just truncated.
     $#variable        Expands to the number of words in $variable. If
                       | $variable is omitted, it assumes $*
     $@variable        Expands to the number of characters in $variable.
                       | if $variable is omitted, it assumes $*
     $($subvariable)   This is somewhat similar to a pointer, in that
                       | the value of $subvar is taken as the name of
                       | the variable to expand to.  Nesting is allowed.
     ${expression}     Permits the value to be embedded in another
                       | string unambiguously.
     $!history!        Expands to a matching entry in the client's
                       | command history, wildcards allowed.

  Whenever an alias is called, these expandos are set to the arguments
  passed to it.  If none of these expandos are used in the alias, or
  the $() form shown above, any arguments passed will automatically be
  appended to the last command in the alias.

     Expando   Description
     $*        expands to all arguments passed to an alias
     $n        expands to argument 'n' passed to an alias (counting from
               zero)
     $n-m      expands to arguments 'n' through 'm' passed to an alias
     $n-       expands to all arguments from 'n' on passed to an alias
     $-m       expands to all arguments up to 'm' passed to an alias
     $~        expands to the last argument passed to an alias

  These variables are set and updated dynamically by the client.  The
  case of $A .. $Z is important.

     Variable   Description
     $,         last person who sent you a MSG
     $.         last person to whom you sent a MSG
     $:         last person to join a channel you are on
     $;         last person to send a public message to a channel you
                are on
     $A         text of your AWAY message, if any
     $B         body of last MSG you sent
     $C         current channel
     $D         last person that NOTIFY detected a signon for
     $E         idle time
     $F         time client was started, $time() format
     $H         current server numeric being processed
     $I         channel you were last INVITEd to
     $J         client version text string
     $K         current value of CMDCHARS
     $k         first character in CMDCHARS
     $L         current contents of the input line
     $M         modes of current channel, if any
     $N         current nickname
     $O         value of STATUS_OPER if you are an irc operator
     $P         if you are a channel operator in $C, expands to a '@'

     $Q         nickname of whomever you are QUERYing
     $R         version of current server
     $S         current server name
     $T         target of current input (channel or nick of query)
     $U         value of cutbuffer
     $V         client release date (format YYYYMMDD)
     $W         current working directory
     $X         your /userhost $N address (user@host)
     $Y         value of REALNAME
     $Z         time of day (hh:mm, can be changed with /SET
                timestamp_format)
     $$         a literal '$'

     $versiontime         prints time of the irssi version in HHMM
                          format
     $sysname             system name (eg. Linux)
     $sysrelease          system release (eg. 2.2.18)
     $sysarch             system architecture (eg. i686)
     $topic               channel topic
     $usermode            user mode
     $cumode              own channel user mode
     $cumode_space        like $cumode, but gives space if there's no
                          mode.
     $tag                 server tag
     $chatnet             chat network of server
     $winref              window reference number
     $winname             window name
     $itemname            like $T, but use item's visible_name which may
                          be different (eg. $T = !12345chan, $itemname =
                          !chan)

  For example, assume you have the following alias:

     alias blah msg $D Hi there!

  If /blah is passed any arguments, they will automatically be appended
  to the MSG text.  For example:

     /blah oops                      /* command as entered */
     "Hi there! oops"                /* text sent to $D */

  Another useful form is ${}.  In general, variables can be embedded
  inside strings without problems, assuming the surrounding text could
  not be misinterpreted as part of the variable name.  This form
  guarantees that surrounding text will not affect the expression's
  return value.

     /eval echo foo$Nfoo             /* breaks, looks for $nfoo */
     /eval echo foo${N}foo           /* ${N} returns current nickname */
     fooYourNickfoo                  /* returned by above command */

-----

Appendix C: Time Formats

Messages that describe times are formatted according to the strftime()
function in C.  According to FreeBSD's strftime() man page, parts of
the format represented with "%" and a letter code are expanded in the
following ways.

  %A    is replaced by national representation of the full weekday name.

  %a    is replaced by national representation of the abbreviated
         weekday name.

  %B    is replaced by national representation of the full month name.

  %b    is replaced by national representation of the abbreviated month
         name.

  %C    is replaced by (year / 100) as decimal number; single digits are
         preceded by a zero.

  %c    is replaced by national representation of time and date.

  %D    is equivalent to ``%m/%d/%y''.

  %d    is replaced by the day of the month as a decimal number (01-31).

  %E* %O*
         POSIX locale extensions.  The sequences %Ec %EC %Ex %EX %Ey %EY
         %Od %Oe %OH %OI %Om %OM %OS %Ou %OU %OV %Ow %OW %Oy are
         supposed to provide alternate representations.

         Additionly %OB implemented to represent alternative months
         names (used standalone, without day mentioned).

  %e    is replaced by the day of month as a decimal number (1-31);
         single digits are preceded by a blank.

  %F    is equivalent to ``%Y-%m-%d''.

  %G    is replaced by a year as a decimal number with century.  This
         year is the one that contains the greater part of the week
         (Monday as the first day of the week).

  %g    is replaced by the same year as in ``%G'', but as a decimal
         number without century (00-99).

  %H    is replaced by the hour (24-hour clock) as a decimal number
         (00-23).

  %h    the same as %b.

  %I    is replaced by the hour (12-hour clock) as a decimal number
         (01-12).

  %j    is replaced by the day of the year as a decimal number
         (001-366).

  %k    is replaced by the hour (24-hour clock) as a decimal number
         (0-23); single digits are preceded by a blank.

  %l    is replaced by the hour (12-hour clock) as a decimal number
         (1-12); single digits are preceded by a blank.

  %M    is replaced by the minute as a decimal number (00-59).

  %m    is replaced by the month as a decimal number (01-12).

  %n    is replaced by a newline.

  %O*   the same as %E*.

  %p    is replaced by national representation of either "ante meridiem"
         or "post meridiem" as appropriate.

  %R    is equivalent to ``%H:%M''.

  %r    is equivalent to ``%I:%M:%S %p''.

  %S    is replaced by the second as a decimal number (00-60).

  %s    is replaced by the number of seconds since the Epoch, UTC (see
         mktime(3)).

  %T    is equivalent to ``%H:%M:%S''.

  %t    is replaced by a tab.

  %U    is replaced by the week number of the year (Sunday as the first
         day of the week) as a decimal number (00-53).

  %u    is replaced by the weekday (Monday as the first day of the week)
         as a decimal number (1-7).

  %V    is replaced by the week number of the year (Monday as the first
         day of the week) as a decimal number (01-53).  If the week
         containing January 1 has four or more days in the new year,
         then it is week 1; otherwise it is the last week of the
         previous year, and the next week is week 1.

  %v    is equivalent to ``%e-%b-%Y''.

  %W    is replaced by the week number of the year (Monday as the first
         day of the week) as a decimal number (00-53).

  %w    is replaced by the weekday (Sunday as the first day of the week)
         as a decimal number (0-6).

  %X    is replaced by national representation of the time.

  %x    is replaced by national representation of the date.

  %Y    is replaced by the year with century as a decimal number.

  %y    is replaced by the year without century as a decimal number
         (00-99).

  %Z    is replaced by the time zone name.

  %z    is replaced by the time zone offset from UTC; a leading plus
         sign stands for east of UTC, a minus sign for west of UTC,
         hours and minutes follow with two digits each and no delimiter
         between them (common form for RFC 822 date headers).

  %+    is replaced by national representation of the date and time (the
         format is similar to that produced by date(1)).

  %%    is replaced by `%'.

-----

Appendix D: Color Codes

Irssi defines codes to represent colors.  They work like the
strftime() codes in Appendix C.

From <http://irssi.org/documentation/formats> :

  Irssi's colors that you can use in text formats, hilights, etc. :

                          text            text            background
  ---------------------------------------------------------------------
  %k      %K      %0      black           dark grey       black
  %r      %R      %1      red             bold red        red
  %g      %G      %2      green           bold green      green
  %y      %Y      %3      yellow          bold yellow     yellow
  %b      %B      %4      blue            bold blue       blue
  %m      %M      %5      magenta         bold magenta    magenta
  %p      %P              magenta (think: purple)
  %c      %C      %6      cyan            bold cyan       cyan
  %w      %W      %7      white           bold white      white
  %n      %N              Changes the color to "default color", removing
                          all other coloring and formatting. %N is
                          always the terminal's default color. %n is
                          usually too, except in themes it changes to
                          "previous color", ie. hello = "%Rhello%n" and
                          "%G{hello} world" would print hello in red,
                          and %n would turn back into %G making world
                          green.
  %F                      Blinking on/off (think: flash)
  %U                      Underline on/off
  %8                      Reverse on/off
  %9      %_              Bold on/off
  %:                      Insert newline
  %|                      Marks the indentation position
  %#                      Monospace font on/off (useful with lists and
                          GUI)
  %%                      A single %

  In .theme files %n works a bit differently. See default.theme for more
  information.

-----

Appendix E comes directly from
<http://irc.fu-berlin.de/irc/help/SET/TRANSLATION.html> :

  Usage: SET TRANSLATION <character translation table>

  The TRANSLATION variable defines a character translation table.  By
  default, ircII assumes that all text processed over the network is
  in the ISO 8859/1 map, also known as Latin-1.  This is identical to
  standard ASCII, except that it is extended with additional
  characters in the range 128-255.  Many environments by default use
  the Latin-1 map, such as X Windows, MS Windows, AmigaDOS, and modern
  ANSI terminals including Digital VT200, VT300, VT400 series and
  MS-Kermit.  However, many older environments use non-standard
  extensions to ASCII, and yet others use 7-bit national replacement
  sets.

  Some available settings for the TRANSLATION variable:

  8-bit sets:
    CP437               Old IBM PC, compatibles and Atari ST.
    CP850               New IBM PC compatibles and IBM PS/2.
    DEC_MCS             DEC Multinational Character Set.
                        VAX/VMS.  VT320's and other 8-bit
                        Digital terminals use this set by
                        default, but I recommend changing to
                        Latin-1 in the terminal Set-Up.
    DG_MCS              Data General Multinational Character Set.
    HP_MCS              Hewlett Packard Extended Roman 8.
    LATIN_1             ISO 8859/1.  Default.
    MACINTOSH           Apple Macintosh computers and boat
                        anchors.
    NEXT                NeXT.

  7-bit sets:
    ASCII               ANSI ASCII, ISO Reg. 006.  For American
                        terminals in 7-bit environments.  Use
                        this one if everything else fails.
    DANISH              Norwegian/Danish.
    DUTCH               Dutch.
    FINNISH             Finnish.
    FRENCH              ISO French, ISO Reg. 025.
    FRENCH_CANADIAN     French in Canada.
    GERMAN              ISO German, ISO Reg. 021.
    IRV                 International Reference Version, ISO
                        Reg. 002.  For use pedantic in ISO 646
                        environments.
    ITALIAN             ISO Italian, ISO Reg. 015.
    JIS                 JIS ASCII, ISO Reg. 014.  Japanese
                        ASCII hybrid.
    NORWEGIAN_1         ISO Norwegian, Version 1, ISO Reg. 060.
    NORWEGIAN_2         ISO Norwegian, Version 2, ISO Reg. 061.
    PORTUGUESE          ISO Portuguese, ISO Reg. 016.
    PORTUGUESE_COM      Portuguese on Digital terminals.
    RUSSIAN             Russian
    RUSSIAN_ALT         Alternative Russian.
    SPANISH             ISO Spanish, ISO Reg. 017.
    SWEDISH             ISO Swedish, ISO Reg. 010.
    SWEDISH_NAMES       ISO Swedish for Names, ISO Reg. 011.
    SWEDISH_NAMES_COM   Swedish.  Digital, Hewlett Packard.
    SWISS               Swiss.
    UNITED_KINGDOM      ISO United Kingdom, ISO Reg. 004.
    UNITED_KINGDOM_COM  United Kingdom on DEC and HP terminals.

  Please forward any extra translation tables to the ircII development
  team by using the ircbug utility that comes with the package, or,
  failing that, sending mail to ircii-bugs@eterna.com.au directly.

-----

Copyright & License.

The original portions of this document are Copyright 2005 by Rocco
Caputo <rcaputo@cpan.org> and Nei (on irc.freenode.net #irssi).  Other
portions are Copyright by their respective authors or licensors.

This work is licensed under a Creative Commons Attribution-ShareAlike
2.5 License.  Please see http://creativecommons.org/licenses/by-sa/2.5/
for details.  Summary:

  You are free:

    * to copy, distribute, display, and perform this work
    * to make derivative works
    * to make commercial use of this work

  Under the following conditions:

    Attribution.  You must attribute the work in the manner specified
    by the author or licensor.

    Share Alike.  If you alter, transform, or build upon this work,
    you may distribute the resulting work only under a license
    identical to this one.

  * For any reuse or distribution, you must make clear to others the
  license terms of this work.
  * Any of these conditions can be waived if you get permision from
  the copyright holder.

  Your fair use and other rights are in no way affected by the above.

Sorry for the heavy license crap.  Coekie wanted clarification.

END
