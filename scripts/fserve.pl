#!/usr/bin/perl -w
#############################################################################
#
#	FServe - file server for Irssi using DCC
#
#	Copyright (C) 2001 Martin Persson
#	Copyright (C) 2003 Andriy Gritsenko
#	Copyright (C) 2002-2004 Piotr Krukowiecki
#
#
#	If you have any comments, bug reports or anything else
#	please contact me at piotr at pingu.ii.uj.edu.pl
#
#	"Official" home page is at http://pingu.ii.uj.edu.pl/~piotr/irssi
#
#
#	This program is free software; you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation; either version 2 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#
#	Changelog 
#	====================================================================
#
#	TODO:
#		- when sending e.g. 3/2 files (e.g. because of min_upload), fserve
#		  ad should say it's 3/2 sends, not 2/2 as it is now
#		- BUG: doesn't work if root_dir contains '+' ?
#		- Improve distro: /fs distro clear, etc
#		- possibility to, in case of failed send, not to resend file at once
#		  but to requeue it in slot X
#		- More control in sends/queues (e.g. changing resends left, etc)
#		- /fs show_current_sends_to_channel 
#		- restricted @find
#		- user priorities: new priority_user option in queue_priority +
#		  /fs priouser nick
#		- @find should search thorough dirs as well.
#		- incorporate flood protection
#		? make sure all server tags and user nicks are first lc()'ed
#		? don't use send_user_msg, it's redundant
#		? don't use message levels, but set window number
#			instead (might be better)
#		- Add '/fs queue all' or '/fs queue *' etc.
#
#	2.0.0 (2004.05.09)
#	* released rc4 without changes. Still a lot to do, but it's quite stable.
#
#	2.0.0rc4 (2004.01.27)
#	* fixed "() queued  (0 B)" queued files
#
#	2.0.0rc3 (2003.06.19)
#	* fserve.pl works with old (before 0.8.6) irssi
#	* bugfix: min_upload was not working
#	* more documentation
#
#	2.0.0rc2 (2003.06.09)
#	* fixed 'send speed < 0' bug
#	* some queue-oriented fixes
#	* fixed '/fs delt' to update remaining sends and queues
#	* added '/fs queue *' to display all queues.
#
#	2.0.0rc1 (2003.06.01) Happy Child's Day :)
#	* Changed format of config file, it won't work with old (1.2.4 and 
#		older file). If you're upgrading from 1.3.x and newer, just add
#		"[ConfigFileVersion 1.0]" (without '"') at the beginning of the 
#		file.
#		This should be the last user-visible change of config/queue files.
#	* More documentation in /fs help
#	* Reseting upload_counter after having sent file
#	* renamed ignore_chat to ctcp_only
#	* renamed short_notice to custom_notice, added custom_notice_fields
#	* @find responses more Sysreset-like
#
#	Important changes between 1.2.4 and 2.0.0rc1 
#		(for detailed version look at fserve-1.4.0pre6)
#		Many thanks to Andriy Gritsenko for his work on the fserve.
#	* multiple server support 
#	* multiple queue support (patch from A.G)
#	* good documentation: '/fs help' (although it's still not complete)
#	* changed format of queue file, saved sends and queues won't be back.
#	* many bugfixes, small fixes, changes in server logic etc.
#	* big patch from A.G, too much changes to list here.
#	
#		
#	1.2.4
#   * bug workaround: removing ghost users (not tested... i don't have 
#		such problems...)
#	* Removed window_close_on_quit - it was causing irssi to crash
#	* Patch from Daniel Seifert (dseifert at gmx dot de):
#		- added dont_notify option (to define channels where no notifies
#	  		should be sent to) 
#		- english corrections
#		
#	1.2.3
#	* Added:
#		- offline_message which is displayed when someone wants to access
#			disabled fserve
#		- fserve responds to !olist if (restricted_level > 0) and to 
#			!vlist if (restricted_level == 1)
#		- fserve responds to "!list <my irc nick>"
#	* bug (?) workaround: sometimes fserve thinks it's still sending 
#		the file when it's not. Now it's checking for such ghost sends
#		and removes them from sends list
#	* bugfix: can send files containing "'" now
#	
#	1.2.2
#	* works with irssi 0.8.6 now, but doesn't work with irssi 0.8.5 and
#	  former (incompatybile change in irssi 0.8.6 :( )
#
#   1.2.1
#	* bugfix: @find didn't reported any files if there was only one match
#
#	1.2.0
#	* IMPORTANT CHANGE: there is no longer 'ops_priority' setting. You must
#		use 'queue_priority' instead (irssi will switch to it automatically 
#		when loading old config). queue_priority is a list of space separated
#		priorities: "normal", "voice", "halfop", "op" and "others". Queue
#		is sorted according to the order in which they appear in queue_priority.
#		For example, if you set it to 'voice others normal' then first in queue
#		will be voiced people, then people with priority not mentioned in 
#		queue_priority (in this case halfops and ops), then normal people.
#		If 'others' doesn't exists in queue_priority it's assumed to be at
#		the end
#	* Added:
#		- '/fs sortqueue' to sort queue according to queue_prority
#		- count_send_as_queue setting. If set to 1 user sends take
#			place in queue. For example, if it's set and user_slots == 1, 
#			user can have only one send, or only one queued file.
#		- distro mode (/fs set distro, distro_file). When distro = 1
#			fileserver counts how many times each file was sent, and first 
#			sends files with lowest send count.
#			In fact, distro setting isn't simply 0/1. It's a PROBABILITY of
#			using distro mode for the send. The values should be from range
#			[0,1], where 0 means don't use distro mode at all, and 1 means
#			allways use distro mode. For example when it's set to 0.7 it'll
#			use distro mode in 7 cases of 10 (more or less). 
#		- '/fs distro stats' displays send count for files
#	* bugfix: 
#		- send speed was wrongly calculated.
#		- fserve could sometimes use wrong network 
#		- exit, bye shoult works now. Patch from Jan Rekorajski 
#			(baggins at sith.mimuw.edu.pl). Chat windows are closed unless
#			close_window_on_quit is set to 0
#	* in conffile, queuefile and log_name you can use $IRSSI as part of the 
#		path. It will be changed to Irssis home directory.
#	* hopefully better support for fserve explorers etc (changed 'dir' output)
#	* people who use different command char then '/' in /command shouldn't
#		have problems now
#	* some other fixes/changes
#
#	1.1.3
#	* added:
#		- +v/+%/+o only fserve. setting restricted_level to 3 means only ops 
#			can access, to 2 only ops and halfops, to 1 only ops, halfops and 
#			voiced users can access. if it's 0 everybody can access.
#
#	1.1.2
#	* added: 
#		- !request support (/fs set request)
#
#	1.1.1
#	* bugfix:
#		- works with files containing more than one space in row 
#			(e.g. 'blah  blah')
#	* added: 
#		- /fs set autosave_on_close - when set to 1 sends and queues
#			will be saved on /fs off
#
#	1.1.0
#	* bugfix:
#		- Enabling debug (/fs set debug 1) works now
#	* New:
#		- /fs set content - adds "On Fserve:(content)" to notice.
#		- /fs set motdfile - gets MOTD from file
#		- /fs set recache_interval - does /fs recache every recache_interval
#			seconds			
#		- /ctcp ... NoResend
#
#	1.0.0
#	-----
#	* added:
#		- sending small files without waiting in queues 
#		  (/fs set instant_send). Patch from Jan Rekorajski 
#  		  (baggins at sith.mimuw.edu.pl)
#		- @find support (/fs set find, /fs set find_results). Patch from 
#		  Jan Rekorajski (baggins at sith.mimuw.edu.pl
#		- queuefile and $conffile in $fs_prefs{}
#		- /fs notify #channel1 #channel2 #etc
#		- current upstream is displayed in server notice
#		- resends ($max_resends) and better min_cps handling ($speedp). New
#			log position (dcc_soft_fail) if resend is possibile
#		- MOTD - '/fs set motd blah blah'
#	* bugfixes
#		- fserver should respond to all !list's (comparing # names not cases s.)
#		- fixed '/fs insert file'
#		- displays notice with correct colors even if Note: contains braces
#		- queued position reported after queueing file by +o/+v with 
#			ops_priority on
#	* moved most usefull variables to %fs_prefs (/fs set ...)
#	* priority users are moved to the beginnign of the queue
#	* 'Autosaving...' is not printed anymore unless in debug mode
#	* Previously if ops_priority was on and nick was +o/+v the file was added
#		even if there was no free queue slot. Now it's not added, unless
#	  	ops_priority > 2. 
#	* if irc server disconnects, fserve will change to 'frozen' state and will
#		wait for reconnection, then will wait next 150s to join channels etc.
#		If send will fail in that time then it will be moved to queue.
#		If you want to manually connect to new irc server, do /fs off, /fs on
#
#	--
#	Changes above by Cvbge (piotr at pingu.ii.uj.edu.pl) 
#	--	
#
#	0.6.0
#	-----
#
#	* Merged patch from Ethan Fischer (allanon@crystaltokyo.com)
#   	  - added ignore_chat option that, when turned on, ignores the
#    	    trigger if said in the channel; it also changes the trigger 
#   	    advertisement to "/ctcp nick !trigger"
#   	  - added ops_priority option that, when set to 1, force-adds 
#   	    requests from to the top of the download queue regardless of
#           queue size; when set to 2, it does the same thing for voices
#   	  - added log_name option to specify the name of a logfile which 
#           will be used to store transfer logs; the log contains the time 
#           a dcc transfer finishes, whether it finished or failed, filename,
#           nick, bytes sent, start time, and end time
#         - added a kludge to kill dcc chats after an "exit" in sig_timeout()
#   	  - added a -clear option to the set command (eg, /fs set -clear
#           log_name) which sets the variable to an empty string
#
#   	* Merged patch from Brian (btherl@optushome.com.au)
#         - Avoid division by zero when dcc send takes 0 time to complete
#   	  - new user command "read" - allows reading of small (<30k) files,
#           such as checksum files
#         - set line delimeter before load_config()
#   	  - formatting of function headers
#
#   	thanks for the patches guys :)
#
#   	* the bytecounter now also counts the number of bytes sent
#   	  for failed transfers as well as successful transfers
#         (with respects to resumed files)
#   	* some bugfixes I don't remember ;)
#
#############################################################################

# Best viewed with TAB size = 4 !

use strict;
no strict 'refs';

use Irssi;
use Irssi::Irc;

use vars qw($VERSION %IRSSI);

$VERSION = "2.0.0";
my $conffile = '$IRSSI/fserve.conf';

%IRSSI = (
	authors		=> 'Piotr Krukowiecki & others',
	contact		=> 'piotr at pingu.ii.uj.edu.pl',
	name		=> 'FServe',
	description	=> 'File server for irssi',
	license		=> 'GPL v2',
	url			=> 'http://pingu.ii.uj.edu.pl/~piotr/irssi'
);


my @welcome_msg = (
	"FServe $VERSION for Irssi",
	"-",
	"Commands: ls dir cd get read dequeue clr_queue queue sends",
	"          help who stats quit",
);

my @help_msg = (
	"-=[ Available commands ]=-",
	"  ls / dir       - list files in current directory",
	"  cd <dir>       - changes current directory to <dir>",
	"                   (note: <dir> is case sensitive!)",
	"  get <file>     - inserts <file> into the queue",
	"  read <file>    - displays contents of <file>",
	"  dequeue <nr>   - removes file in slot <nr>",
	"  clr_queue[s]   - removes your queued files",
	"  queue[s]       - lists the queue",
	"  sends          - lists active sends",
	"  who            - lists users online",
	"  stats          - shows some statistice",
	"  quit           - closes the connection",
);

my @srv_help_msg = (
	"command - [params] description\003\n",
	"on      - [0] enables fileserver",
	"off     - [0] disables fileserver",
	"save    - [0] save config file",
	"load    - [0] load config file",
	"saveq   - [0] saves sends/queues",
	"loadq   - [0] loads the queues",
	"set     - [0/2] sets variables",
	"addq    - [0] adds new queue",
	"delq    - [1] deletes queue",
	"selq    - [1] sets default queue for next 4 commands",
	"setq    - [0/2] sets queue variables",
	"queue   - [0-1] lists file queue",
	"sortq   - [0-1] sorts queue",
	"move    - [2-3] moves queue slots around",
	"insert  - [3] inserts a file in queue",
	"clear   - [1] removes queued files",
	"sends   - [0] lists active sends",
	"who     - [0] lists users online",
	"stats   - [0] shows server statistics",
	"recache - [0] updates filecache\003\n",
	"Usage: /fs <command> [<arguments>]",
	"For parameter info type /fs <cmd>",
	"Please read beginning of the fserve.pl (the changelog)",
	"for more information",
);

###############################################################################
#	fileserver preferences (/fs set <var> <data>)
#	default values, feel free to change them
###############################################################################
my %fs_prefs = (
	auto_save			=> 599,
	autosave_on_close	=> 1,
	clr_dir				=> "\00312",
	clr_file			=> "\00315",
	clr_hi				=> "\00312",
	clr_txt				=> "\00315",
	count_send_as_queue	=> 0,
	debug				=> 0,
	distro				=> 0,
	distro_file			=> '$IRSSI/fserve.distro',
	idle_time			=> 120,
	ignores				=> "",
	log_name			=> '$IRSSI/fserve.log',	 # FIXME should be renamed to logfile or similar
	max_queues			=> 10,
	max_sends			=> 2,
	max_time			=> 600,
	max_users			=> 5,
	min_upload			=> 0,
	motd				=> '',
	motdfile			=> '',
	offline_message		=> '',	# is displayed when someone wants to enter disabled fserve
	queuefile			=> '$IRSSI/fserve.queue',
	recache_interval	=> 3607,
);

my %fs_queue_defaults = (
	channels			=> '#CHANGE_ME',
	content				=> '',
	ctcp_only			=> 1,
	custom_notice		=> 1,
	custom_notice_fields=> "trigger sends queues min_cps note content",
	dont_notify			=> "",
	find				=> 3,
	guaranted_queues	=> 0,
	guaranted_sends		=> 0,
	ignore_msg			=> 1,
	ignores				=> "",
	instant_send		=> 10240,
	max_queues			=> 10,
	max_resends			=> 3,
	max_sends			=> 2,
	min_cps				=> 9728,
	motd				=> '',
	nice				=> 0,
	note				=> '',
	notify_interval		=> 0,
	notify_on_join		=> 0,
	queue_priority		=> "", 
	request				=> "",
	restricted_level	=> 0,
	root_dir			=> '/path/to/files/CHANGE_ME',
	servers				=> 'CHANGE_ME',
	speed_warnings		=> 1,
	trigger				=> '!trigger',
	user_slots			=> 3,
);

###############################################################################
#	fileserver statistics
###############################################################################
my %fs_stats = (
	record_cps	=> 0,
	rcps_nick	=> "",
	sends_ok	=> 0,			# sends succeeded
	sends_fail	=> 0,			# sends failed
	transfd		=> 0,			# total bytes transferred
	login_count	=> 0,			# total number of logins
);

my @fs_queues = ();
my @fs_sends = ();
my %fs_users = ();
my %fs_distro = ();

###############################################################################
#	private variables
###############################################################################
my $fs_enabled = 0; 	# always start disabled
my $online_time = 0;	# time since last script restart
my $timer_tag;
my $logfp;
my @kill_dcc;
my $upload_counter = 0;
my $last_upload = 0;
my $last_upload_check = 0;
my $motdfile_modified = 0;	#when was motd file last modified
my @motd = ();
my $default_queue = 0;
my $next_queue = 0;
my $FD = "'"; # old irssi (<0.8.6) doesn't use "'" in /dcc send 'file'

###############################################################################
#	setup signal handlers
###############################################################################
Irssi::signal_add_first('event privmsg', 'sig_event_privmsg');
Irssi::signal_add_first('event join', 'sig_event_join');
Irssi::signal_add_first('default ctcp msg', 'sig_ctcp_msg');
Irssi::signal_add_last('dcc chat message', 'sig_dcc_msg');

Irssi::signal_add_last('dcc connected', 'sig_dcc_connected');
Irssi::signal_add('dcc destroyed', 'sig_dcc_destroyed');

Irssi::signal_add('nicklist changed', 'sig_nicklist_changed');

Irssi::command_bind('fs', 'sig_fs_command');
print_msg("FServe version $VERSION");
print_log("FServe starting up");

$_ = $conffile;
s/\$IRSSI/Irssi::get_irssi_dir()/e or s/~/$ENV{"HOME"}/;
if (-e) {       
	load_config();
} else {
	print_msg("If this is your first time using this fserve");
	print_msg("I advise you to read help (/fs help)");
}	
if (!@fs_queues) {
	print_debug("Added inital trigger");
	push (@fs_queues, { %fs_queue_defaults });
	@{$fs_queues[$#fs_queues]->{queue}} = ();
}

{ 
	my $ver = 'Very Old';
	eval { $ver = Irssi::version(); };
	if ($ver - 20021117 < 0) {
		print_debug("Detected old irssi version: $ver") ;
		$FD = "";
	}
}

if ($fs_prefs{distro} and $fs_prefs{distro_file}) {
	$_ = $fs_prefs{distro_file};
	s/\$IRSSI/Irssi::get_irssi_dir()/e or s/~/$ENV{"HOME"}/;
	if (-e) {
		load_distro($_) and print_msg("Distro file loaded");
	}
}

###############################################################################
#	prints debug messages in the (fserve_dbg) window
###############################################################################
sub print_debug
{
	if ($fs_prefs{debug}) {
		Irssi::print("<DBG> @_", MSGLEVEL_CLIENTERROR);
	}
}

###############################################################################
#	prints server message in current window
###############################################################################
sub print_msg
{
	Irssi::active_win()->print("$fs_prefs{clr_txt} @_");
}
		
sub print_what_we_did {
	Irssi::print("@_", MSGLEVEL_CLIENTCRAP);
}

sub max($$) { return @_[0]>@_[1]?@_[0]:@_[1]; }
sub min($$) { return @_[0]<@_[1]?@_[0]:@_[1]; }

###############################################################################
###############################################################################
##
##		Signal handler routines
##
###############################################################################
###############################################################################

sub get_max_sends($) {
	my $qn = @_[0];
	
	my $qu_msends = $fs_queues[$qn]->{max_sends};
	my $gl_msends = $fs_prefs{max_sends};
	my $guaranted_sends = $fs_queues[$qn]->{guaranted_sends};

	my $current_sends = $fs_queues[$qn]->{sends};
	my $free_sends = 
		max( $guaranted_sends - $current_sends,
			min($gl_msends - @fs_sends, $qu_msends - $current_sends) );
	$free_sends = 0	if ($free_sends < 0);
	my $max_sends = max( $guaranted_sends, min($qu_msends,$gl_msends) );
	
	return ($current_sends, $free_sends, $max_sends);
}

sub get_max_queues($) {
	my $qn = @_[0];

	my $qu_mqueues = $fs_queues[$qn]->{max_queues};
	my $gl_mqueues = $fs_prefs{max_queues};
	my $guaranted_queues = $fs_queues[$qn]->{guaranted_queues};
	# TODO: keep this somewhere?
	my $gl_current_queues = 0;
	foreach (0 .. $#fs_queues) {
		$gl_current_queues += @{$fs_queues[$_]->{queue}};
	}	

	my $current_queues = @{$fs_queues[$qn]->{queue}};
	my $free_queues = 
		max( $guaranted_queues - $current_queues,
			min($gl_mqueues - $gl_current_queues, 
				$qu_mqueues - $current_queues) );
	$free_queues = 0 if ($free_queues < 0);
	my $max_queues = max( $guaranted_queues, min($qu_mqueues, $gl_mqueues) );
	
	return ($current_queues, $free_queues, $max_queues);
}

###############################################################################
#	updates some variables when DCC CHAT is established
###############################################################################
sub sig_dcc_connected
{
	my ($dcc) = @_;
	my $tag = $dcc->{servertag};
	my $user_id = $dcc->{nick}."@".$tag; 
	print_debug("DCC connected: $dcc->{type} $user_id");

	return if ($dcc->{type} ne "CHAT" || !defined $fs_users{$user_id});
	
	print_debug("User $user_id connected!");
	$fs_users{$user_id}{status} = 0;
	$fs_users{$user_id}{time} = 0;
	$fs_stats{login_count}++;

	foreach (@welcome_msg) {
		send_user_msg($tag, $dcc->{nick}, $_);
	}
	send_user_msg($tag, $dcc->{nick}, "-");
		
	my $qn = $fs_users{$user_id}{queue};
	my ($curr_queues, $free_queues, $max_queues) = get_max_queues($qn);
	my ($curr_sends, $free_sends, $max_sends) = get_max_sends($qn);

	send_user_msg($tag, $dcc->{nick}, "Current/Free/Max Sends: ".
		"$curr_sends/$free_sends/$max_sends");
	send_user_msg($tag, $dcc->{nick}, "Current/Free/Max Queues: ".
		"$curr_queues/$free_queues/$max_queues");
	send_user_msg($tag, $dcc->{nick}, "Your queue: ".
		count_user_files($tag, $dcc->{nick}, $qn).
		"/$fs_queues[$qn]->{user_slots}");
		
	send_user_msg($tag, $dcc->{nick}, "Instant send: ".
		size_to_str($fs_queues[$qn]{instant_send}))
		if ($fs_queues[$qn]{instant_send} > 0);
		
	if ($fs_prefs{motdfile}) {
		send_user_msg($tag, $dcc->{nick}, "-");
		my $f = $fs_prefs{motdfile};
		$f =~ s/\$IRSSI/Irssi::get_irssi_dir()/e or $f =~ s/~/$ENV{"HOME"}/; 
		if (! ((-f $f) and (-r $f))) {
			print_msg("FServe: '$f' doesn't exists, isn't plain file or is not readable");
		} else {
			my $lm = (stat($f))[9];
			if ($motdfile_modified < $lm) {
				$motdfile_modified = $lm;
				@motd = ();
				open(FILE, "<", $f);
				while(<FILE>) {
					chomp;
					s/\t/       /g;
					push @motd, $_;
				}
				close(FILE, $f);
			}
			foreach (@motd) {
				send_user_msg($tag, $dcc->{nick}, $_);			
			}
		}
	}

	if (length($fs_prefs{motd})) {
		send_user_msg($tag, $dcc->{nick}, "-");
		send_user_msg($tag, $dcc->{nick}, "$fs_prefs{motd}");
	}
	if (length($fs_queues[$qn]{motd})) {
		send_user_msg($tag, $dcc->{nick}, "-");
		send_user_msg($tag, $dcc->{nick}, "$fs_queues[$qn]{motd}");
	}
	send_user_msg($tag, $dcc->{nick}, "-");
	send_user_msg($tag, $dcc->{nick}, '[\]');
}

###############################################################################
#	cleanups after DCC CHAT/SEND disconnects
###############################################################################
sub sig_dcc_destroyed
{
	my ($dcc) = @_;
	my $nick = $dcc->{nick};
	my $server = $dcc->{server};
	my $server_tag = $dcc->{servertag};
	my $user_id = $nick.'@'.$server_tag;

	print_debug("DCC destroyed: $dcc->{type} $user_id '$dcc->{arg}'");

	if ($dcc->{type} eq "CHAT" && defined $fs_users{$user_id}) {
		delete $fs_users{$user_id};
		print_debug("Users left: ".keys %fs_users);
	} elsif ($dcc->{type} eq "SEND") {
		foreach my $sn (0 .. $#fs_sends) {
			print_debug("check slot $sn: ".
				"user=$fs_sends[$sn]->{nick}\@$fs_sends[$sn]->{server_tag}, ".
				"file=$fs_sends[$sn]->{file}.");
			if ($fs_sends[$sn]->{nick} eq $nick &&
				$fs_sends[$sn]->{server_tag} eq $server_tag &&
				$fs_sends[$sn]->{file} eq $dcc->{arg}) {
				print_debug("found send in slot $sn");
				if ($dcc->{transfd} == $fs_sends[$sn]->{size}) {
					print_log("dcc_finish $dcc->{arg} $user_id ".
							  "$dcc->{skipped} $dcc->{transfd} ".
							  "$dcc->{starttime} ".time());
					print_debug("file was finished");
					$fs_stats{sends_ok}++;
					if ($fs_prefs{distro}) {
						$fs_distro{$dcc->{arg}}{$dcc->{transfd}}++; 
						save_distro();
					}

					## Update speed record (if new)
					if (time() > $dcc->{starttime}) {
						my $speed = ($dcc->{transfd}-$dcc->{skipped})/
							(time() - $dcc->{starttime});

					    if ($speed > $fs_stats{record_cps}) {
						    $fs_stats{record_cps} = $speed;
						    $fs_stats{rcps_nick} = $nick;
					    }
					}
				} else {
					if ($fs_sends[$sn]->{transfd} == -1) {
						# send was too slow
						print_log("dcc_abort $dcc->{arg} $user_id ".
								  "$dcc->{skipped} $dcc->{transfd} ".
								  "$dcc->{starttime} ".time());
					} else {
						$fs_sends[$sn]->{resends} += 1;
						$fs_sends[$sn]->{warns} = 0;
						$fs_sends[$sn]->{dontwarn} = 0;
						delete $fs_sends[$sn]->{transfd};
						
						if ($fs_sends[$sn]->{resends} <= 
							$fs_queues[$fs_sends[$sn]{queue}]{max_resends}) {
							
							# queue it for resending
							# don't resend right now, you may be treated as flood
							my $fsq = $fs_queues[$fs_sends[$sn]->{queue}]->{queue};
							# TODO should be parametrized (in which slot requeue)
							my $resended_queue = 0;
							foreach (0 .. $#{$fsq}) {
								last if (!${$fsq}[$_]->{resends});
								$resended_queue++;
							}
							$resended_queue = 1
								if (!$resended_queue && @{$fsq}>0);
							print_debug("requeued $dcc->{arg} for ".
										"$user_id in slot $resended_queue, ".
										"resend $fs_sends[$sn]->{resends}");
							splice(@{$fsq}, $resended_queue, 0, { %{$fs_sends[$sn]} });
							$server->command("^NOTICE ".
								"$fs_sends[$sn]->{nick} ".
								"$fs_prefs{clr_txt} Send failed on try ".
								$fs_sends[$sn]->{resends}." of ".
								($fs_queues[$fs_sends[$sn]{queue}]{max_resends}+1).
								". Type /ctcp ".
								"$$server{nick} NoReSend to cancel "
								."any further resends.")
								if ($server && $server->{connected});
							print_what_we_did("NOTICE ".
								"$fs_sends[$sn]->{nick} ".
								"$fs_prefs{clr_txt} Send failed on try ".
								$fs_sends[$sn]->{resends}." of ".
								($fs_queues[$fs_sends[$sn]{queue}]{max_resends}+1).
								". Type /ctcp ".
								"$$server{nick} NoReSend to cancel "
								."any further resends.")
								if ($server && $server->{connected});
							print_log("dcc_soft_fail $dcc->{arg} $user_id ".
									  "$dcc->{skipped} $dcc->{transfd} ".
									  "$dcc->{starttime} ".time());
						} else {
							print_log("dcc_fail $dcc->{arg} $user_id ".
									  "$dcc->{skipped} $dcc->{transfd} ".
									  "$dcc->{starttime} ".time());
						}
					}
					$fs_stats{sends_fail}++;
				}
				
				## Update bytes transferred
				$fs_stats{transfd} += ($dcc->{transfd} - $dcc->{skipped});
				splice(@fs_sends, $sn, 1); # FIXME : decrease number of sends?
				print_debug("SEND closed to $user_id, file: ".
					"$dcc->{arg}, bytes sent: ".
					($dcc->{transfd}-$dcc->{skipped}).
					" (sent from slot $sn, ".@fs_sends." slots now)");
				return;
			}
		}
	}
}

###############################################################################
#	handles dcc chat messages
###############################################################################
sub sig_dcc_msg
{
	my $dcc = shift (@_);
	my $msg = @_[0]; 
	my $user_id = $dcc->{nick}.'@'.$dcc->{servertag};

	# ignore messages from unconnected dcc chats
	return unless ($fs_enabled && defined $fs_users{$user_id});

	# reset idle time for user
	$fs_users{$user_id}{status} = 0;
	
	my ($cmd, $args) = split(' ', $msg, 2);
	$cmd = lc($cmd);

	if ($cmd eq "dir" || $cmd eq "ls") {
		list_dir($user_id, "$args");
	} elsif ($cmd eq "cd") {
		change_dir($user_id, "$args");
	} elsif ($cmd eq "cd..") { # darn windows users ;)
		change_dir($user_id, '..');
	} elsif ($cmd eq "get") {
		queue_file($user_id, "$args");
	} elsif ($cmd eq "dequeue") {
		$args =~ s/^\D*(\d+)\D*$/$1/; # stupid leechers, we have to remove garbage
		dequeue_file($user_id, $args);
	} elsif ($cmd eq "clr_queue" || $cmd eq "clr_queues") {
		clear_queue($user_id, 0, $fs_users{$user_id}{queue});
	} elsif ($cmd eq "queue" || $cmd eq "queues") {
		display_queue($user_id, $fs_users{$user_id}{queue});
	} elsif ($cmd eq "sends") {
		display_sends($user_id);
	} elsif ($cmd eq "who") {
		display_who($user_id);
	} elsif ($cmd eq "stats") {
		display_stats($user_id);
	} elsif ($cmd eq "read") {
		display_file($user_id, "$args");
	} elsif ($cmd eq "help") {
		foreach (@help_msg) {
			send_user_msg($dcc->{servertag}, $dcc->{nick}, $_);
		}
	} elsif ($cmd eq "exit" || $cmd eq "quit" || $cmd eq "bye") {
		push(@kill_dcc, $user_id);
	}
}

###############################################################################
# server, nick, queue_number 
###############################################################################
sub try_connecting_user ($$$)
{
	my ($server, $sender, $qn) = @_;
	my $tag = $server->{tag};
	
	if (defined($fs_users{$sender."@".$tag})) {
		if (!$fs_users{$sender."@".$tag}{ignore} && 
			$fs_queues[$qn]->{ignore_msg}) {
			$server->command("^NOTICE $sender $fs_prefs{clr_txt}".
				"A DCC chat offer has already been sent to you!");
			print_what_we_did("NOTICE $sender $fs_prefs{clr_txt}".
				"A DCC chat offer has already been sent to you!");
		}
	
		$fs_users{$sender."@".$tag}{ignore} = 1;
		return 1;
	}
			
	if (keys(%fs_users) < $fs_prefs{max_users}) {
		if (!$fs_queues[$qn]->{restricted_level}) {
			initiate_dcc_chat($server, $sender, $qn);
			return 1;
		} else {
			foreach (split (' ', $fs_queues[$qn]->{channels})) {
				my $ch = $server->channel_find($_);  
				next if !$ch;
				my $n = $ch->nick_find($sender); 
				next if !$n;
				if (($n->{op}) or  
					(($fs_queues[$qn]->{restricted_level} < 3) && $n->{halfop}) or
					(($fs_queues[$qn]->{restricted_level} < 2) && $n->{voice})) {
						initiate_dcc_chat($server, $sender, $qn);
						return 1;
				}		
			}
			$server->command("^NOTICE $sender $fs_prefs{clr_txt}I'm sorry,"
				." but this trigger is restricted. You need to be an".
				(($fs_queues[$qn]->{restricted_level} == 3) ? " op" :
				(($fs_queues[$qn]->{restricted_level} == 2) ? " op or halfop" :
				" op, halfop or voiced")) . " to access this trigger");
			print_what_we_did("NOTICE $sender $fs_prefs{clr_txt}I'm sorry,"
				." but this trigger is restricted. You need to be an".
				(($fs_queues[$qn]->{restricted_level} == 3) ? " op" :
				(($fs_queues[$qn]->{restricted_level} == 2) ? " op or halfop" :
				" op, halfop or voiced")) . " to access this trigger");
		}
	} else {	
		$server->command("^NOTICE $sender $fs_prefs{clr_txt}".
			"Sorry, server is full (".
			$fs_prefs{clr_hi}.$fs_prefs{max_users}.
			$fs_prefs{clr_txt}.")!");
		print_what_we_did("NOTICE $sender $fs_prefs{clr_txt}".
			"Sorry, server is full (".
			$fs_prefs{clr_hi}.$fs_prefs{max_users}.
			$fs_prefs{clr_txt}.")!");
	}
	return 0;
}


###############################################################################
#	handles ctcp messages
###############################################################################
sub sig_ctcp_msg
{
	my ($server, $args, $sender, $addr, $target) = @_;
	$args = uc($args);
	$args =~ s/\s*$//; # strip ending spaces
	my $tag = $server->{tag};

	return if ($fs_prefs{ignores} &&
		$server->masks_match($fs_prefs{ignores}, $sender, $addr));	

	if (!$fs_enabled) {
		# find queue where the trigger is
		foreach (0 .. $#fs_queues) {
			next if ($args ne uc($fs_queues[$_]->{trigger}));
			next if ($fs_queues[$_]{ignores} &&
				$server->masks_match($fs_queues[$_]{ignores}, $sender, $addr));
 
			foreach my $s (split(' ', $fs_queues[$_]->{servers})) {
				if (uc($s) eq uc($tag) && 
					user_in_channel($server, $sender, $fs_queues[$_])) {
				
					$server->command("^NOTICE $sender $fs_prefs{clr_txt}".
						"Sorry, fserve is currently offline. $fs_prefs{offline_message}");
					print_what_we_did("NOTICE $sender $fs_prefs{clr_txt}".
						"Sorry, fserve is currently offline. $fs_prefs{offline_message}");
					Irssi::signal_stop();
					return;
				}
			} # loop over servers
		} # loop over queues
		Irssi::signal_stop();
		return;
	}
	
	print_debug("CTCP from $sender: '$args'");

	if ($args eq "NORESEND") {
		my $found = 0;
		foreach (0 .. $#fs_sends) {
			if ($fs_sends[$_]{nick} eq $sender && 
				$fs_sends[$_]{server} eq $tag) {
				print_debug("$sender: Canceling resends of $fs_sends[$_]->{file}");
				$fs_sends[$_]->{resends} = $fs_queues[$fs_sends[$_]{queue}]{max_resends};
				$found++;
			}
		}
		my $message = ($found?
						"Resend: All resends ($found) for currently sending ".
						"files have been canceled." :
						"Resend: You currently have no sending files set ".
						"to resend.");
		$server->command("^MSG $sender $message");
		print_what_we_did("MSG $sender $message");
		Irssi::signal_stop();
		return;
	} # end NORESEND


	foreach my $qn (0 .. $#fs_queues) {
		next if ($args ne uc($fs_queues[$qn]->{trigger}));	
		print_debug("Got trigger in queue $qn");
		next if ($fs_queues[$qn]{ignores} &&
			$server->masks_match($fs_queues[$qn]{ignores}, $sender, $addr));
		print_debug("Not ignoring user");
		
		print_debug("Servers are $fs_queues[$qn]->{servers}");
		foreach my $s (split(' ', $fs_queues[$qn]->{servers})) {
			print_debug("Checking server $s against $tag");
			next if (uc($tag) ne uc($s) || 
				!user_in_channel($server, $sender, $fs_queues[$qn]));
			print_debug("Good tag and user in chan");

			if (try_connecting_user($server, $sender, $qn)) {
				Irssi::signal_stop();
				return;
			}
		}
	}
	Irssi::signal_stop();
	return;
}

###############################################################################
#	notifies joining users
###############################################################################
sub sig_event_join
{
	my ($server, $data, $sender, $addr) = @_;
	my ($target) = ($data =~ /:(.*)/);

	return if (!$fs_enabled);

	foreach my $qn (0 .. $#fs_queues) {			
		next if (!$fs_queues[$qn]->{notify_on_join});				
		next if ($fs_queues[$qn]{ignores} && 
			$server->masks_match($fs_queues[$qn]{ignores}, $sender, $addr));
			
		foreach my $s (split(' ', $fs_queues[$qn]->{servers})) {
			next if (uc($s) ne uc($server->{tag}));
			foreach my $channel (split(' ', $fs_queues[$qn]->{channels})) {
				next if (uc($channel) ne uc($target));
				show_notice($server, $sender, $qn);
			} # loop over channels
		} # loop over servers
		
	} # loop over queues

}

###############################################################################
#	handles channel and private messages
###############################################################################
sub sig_event_privmsg
{
	my ($server, $data, $sender, $addr) = @_;
	my ($target, $text) = split(/ :/, $data, 2);

	return if (!$fs_enabled);
	return if ($fs_prefs{ignores} && 
		$server->masks_match($fs_prefs{ignores}, $sender, $addr));

	foreach my $qn (0 .. $#fs_queues) {		
		next if ($fs_queues[$qn]{ignores} && 
			$server->masks_match($fs_queues[$qn]{ignores}, $sender, $addr));
		foreach my $s (split(' ', $fs_queues[$qn]->{servers})) {
			next if (uc($s) ne uc($server->{tag}));
			foreach my $channel (split(' ', $fs_queues[$qn]->{channels})) {	  
				next if (uc($channel) ne uc($target));
	

				# trigger typed
				if (!$fs_queues[$qn]->{ctcp_only} && 
					uc($text) eq uc($fs_queues[$qn]->{trigger})) {
					try_connecting_user($server, $sender, $qn);
					return;
				}
				
				# strip extra spaces
				$_ = uc($text);
				s/\s+$//; s/^\s+$//; s/\s+/ /g;
				if (($_ eq '!LIST') || ($_ eq ('!LIST '.uc($$server{nick}))) ||
					($_ eq '!OLIST' and $fs_queues[$qn]->{restricted_level}) ||
					($_ eq '!VLIST' and $fs_queues[$qn]->{restricted_level} == 1)
					) {
					show_notice($server, $sender, $qn);
				}
				if (length($fs_queues[$qn]->{request}) && ($_ eq '!REQUEST'))
				{
					my $msg = "[$fs_prefs{clr_hi}Request$fs_prefs{clr_txt}] ".
						  "Message:[$fs_prefs{clr_hi}$fs_queues[$qn]->{request}".
						  "$fs_prefs{clr_txt}] - FServe $VERSION";
					$server->command("^NOTICE $sender $fs_prefs{clr_txt}$msg");
					print_what_we_did("NOTICE $sender $fs_prefs{clr_txt}$msg");
				}
	
				if ($fs_queues[$qn]->{find}) {
					if (/^\@FIND /) {
						if ($sender !~ /^#/) {
							show_find($server, $sender, $text, $qn);
						}
					}
				}
				
			} # loop over channels
		} # loop over servers
	} # loop over queues
}


###############################################################################
#	updates userinfo on nick changes
###############################################################################
sub sig_nicklist_changed
{
	my ($chan, $nick, $oldnick) = @_;
	my $server_tag = $chan->{server}{tag};

	print_debug("NICK CHANGE: $oldnick -> $nick->{nick}\@$server_tag on $chan->{name}");

	foreach my $qn (0 .. $#fs_queues) {
	
		my $ch_ok = 0; 
		my $srv_ok = 0;
		foreach (split(' ', $fs_queues[$qn]->{channels})) {
			if (uc($_) eq uc($chan->{name})) {
				$ch_ok = 1;
				last;
			}	
		}
		foreach (split(' ', $fs_queues[$qn]->{servers})) {
			if (uc($_) eq uc($server_tag)) {
				$srv_ok = 1;
				last;
			}	
		}

		next unless ($ch_ok && $srv_ok);

		
		my $old_user_id = $oldnick.'@'.$server_tag;
		my $user_id = $nick->{nick}.'@'.$server_tag;

		if (defined $fs_users{$old_user_id}) {
			print_debug("Changing connected user data");
			# update user data
			my $rec = $fs_users{$old_user_id};
			delete $fs_users{$old_user_id};
			$fs_users{$user_id} = { %{$rec} };
		}
		
		# update queue
		my $fsq = $fs_queues[$qn]->{queue};
		foreach (0 .. $#{$fsq}) {
			if (${$fsq}[$_]->{nick} eq $oldnick &&
				${$fsq}[$_]->{server_tag} eq $server_tag) {
				print_debug("Changing queued file data");
				${$fsq}[$_]->{nick} = $nick->{nick};
			}
		}
		
		# DONT update sends - irssi bug?
		# irssi doesn't change nick in dcc sends
#		foreach (0 .. $#fs_sends) {
#			if ($fs_sends[$_]->{nick} eq $oldnick &&
#				$fs_sends[$_]->{server_tag} eq $server_tag) {
#				$fs_sends[$_]->{nick} = $nick->{nick};
#			}
#		}
		
	}
}

###############################################################################
#	sig_timeout():	called once every second
###############################################################################
sub sig_timeout
{
	# kill connections that said "bye", campers, ghost users etc.
	foreach (@kill_dcc) {
		my ($nick, $servertag) = split('@', $_);
		my $server = Irssi::server_find_tag($servertag);
		next if (!$server || !$server->{connected});
		print_debug("Closing dcc chat to $nick on $servertag");
	    $server->command("DCC CLOSE CHAT $nick");
	}
	@kill_dcc = ();

	my $time = time();

	# check for campers...
	foreach (keys %fs_users) {
		$fs_users{$_}{time}++;
		if ($fs_users{$_}{status} >= 0) {
			$fs_users{$_}{status}++;
			my ($nick, $server_tag) = split('@', $_);

			if ($fs_users{$_}{status} > $fs_prefs{idle_time}) {
				send_user_msg($server_tag, $nick, 
					"Idletime ($fs_prefs{clr_hi}".
					"$fs_prefs{idle_time}$fs_prefs{clr_txt} sec) ".
					"reached, disconnecting!");
				push(@kill_dcc, $_);
			} elsif ($fs_users{$_}{time} > $fs_prefs{max_time}) {
				send_user_msg($server_tag, $nick, 
					"Does this look like a campsite? (".
					"$fs_prefs{clr_hi}$fs_prefs{max_time} ".
					"sec$fs_prefs{clr_txt})");
				push(@kill_dcc, $_);
			}
		# 7 minutes for user to connect
		} elsif ($fs_users{$_}{status} == -1 and $fs_users{$_}{time} > 420) {
			print_msg("BUG workaround: probably ghost user '$_'. Removing from user list .");
			delete $fs_users{$_};
		}
	}
	
	return if (! $fs_enabled);
	
	$online_time++;

	# auto save config file
	if ($fs_prefs{auto_save} && $time % $fs_prefs{auto_save} == 0) {
		print_debug("Autosaving...");
		save_config();
		save_queue();
	}

	# update all $queue->{sends}
	# FIXME: Do this 'the old way'
	# FIXME: BUG: since number of sends is computed only every second
	#  users could exploit this and gain more sends/queues then allowed
	foreach (0 .. $#fs_queues) { $fs_queues[$_]->{sends} = 0; }
	foreach (0 .. $#fs_sends) { $fs_queues[$fs_sends[$_]->{queue}]->{sends}++; }
#	foreach (0 .. $#fs_queues) { 
#		print_debug("Trigger #" . $_ . " have " . $fs_queues[$_]->{sends} .
#			" sends.") ; 
#	}

	# First send forced sends	
	my $file_sent = 0;
	foreach (0 .. $#fs_queues) {
		if ($fs_queues[$_]->{sends} < $fs_queues[$_]->{guaranted_sends}) {
			if (run_queue($fs_queues[$_]) == 0) { 
				$file_sent = 1;
				$upload_counter = 0;
				print_debug("Sent forced queue");
				last;
			}
		}
	}

	# send only one file per second.
	if (!$file_sent) {
		if (send_next_file() == 0) {
			$file_sent = 1;
			$upload_counter = 0;
			print_debug("Sent normal queue");
		}
	}
	
	# check for min upload (up to 2*max_sends+1)
	# FIXME don't use 2*m_s+1 but parametrize
	if (!$file_sent && @fs_sends >= $fs_prefs{max_sends} && 
		$time > $last_upload_check &&
	    @fs_sends <= 2*$fs_prefs{max_sends} && ($time % 60) == 0) {
		my $curr_ups = 0;
		foreach my $dcc (Irssi::Irc::dccs()) {
			if ($dcc->{type} eq 'SEND') {
				$curr_ups += ($dcc->{transfd}-$dcc->{skipped})/($time - $last_upload_check);
			}
		}
		$curr_ups -= $last_upload;
		$last_upload += $curr_ups;
		$last_upload_check = $time;
		if ($curr_ups > 0 && $curr_ups < $fs_prefs{min_upload}) {
			$upload_counter++;
			print_debug("Upload $curr_ups is below minimal, counter is $upload_counter");
			if ($upload_counter > 4) {
				send_next_file(1);
				$upload_counter = 0;
			}
		} else {
			$upload_counter = 0;
		}
	}

	# recache files
	if ($fs_prefs{recache_interval} && 
		$time % $fs_prefs{recache_interval} == 0) {
		update_files();
	}

	# notify channels
	foreach my $qn (0 .. $#fs_queues) {
		if ($fs_queues[$qn]->{notify_interval} && 
		    $time % $fs_queues[$qn]->{notify_interval} == 0) {
			foreach (split(' ', $fs_queues[$qn]->{channels})) {
				foreach my $s (split(' ', $fs_queues[$qn]->{servers})) {
					my $server = Irssi::server_find_tag($s);
					next if (!$server || !$server->{connected});
					show_notice($server, $_, $qn);
				}
			}
		}
	}

	# check speed of sends
	if (($time % 60) == 0) {
		for (my $s = $#fs_sends; $s >= 0; $s--) {
			if ($fs_queues[$fs_sends[$s]{queue}]{min_cps}) {
				check_send_speed($s);
			}
		}
	}
}

###############################################################################
#	check_send_speed(): aborts send in $slot if speed < $fs_prefs{min_cps}
###############################################################################
sub check_send_speed
{
	my ($s) = @_;
	print_debug("check_sends_speed: checking speed of ".
		"$fs_sends[$s]->{nick}\@$fs_sends[$s]->{server_tag}".
		" $fs_sends[$s]->{file}");

	foreach my $dcc (Irssi::Irc::dccs()) {
		print_debug("check_sends_speed: checking DCC ".
			"$dcc->{nick}\@$dcc->{servertag} $dcc->{arg}");
		
		next if ($dcc->{type} ne 'SEND' ||
			$dcc->{nick} ne $fs_sends[$s]->{nick} ||
			$dcc->{servertag} ne $fs_sends[$s]->{server_tag} ||
			$dcc->{arg} ne $fs_sends[$s]->{file});
			
		print_debug ("Found send");
		return unless ($dcc->{starttime});
			
		if (defined $fs_sends[$s]->{transfd}) {
			my $speed = ($dcc->{transfd}-$fs_sends[$s]->{transfd})/60;
			my $min_cps = $fs_queues[$fs_sends[$s]{queue}]{min_cps};
			if ($speed < 0) {
				print_msg("BUG: send speed < 0 ($speed). Send number $s, ".
					"dcc->transfd='$dcc->{transfd}', fs_sends->transfd='".
					$fs_sends[$s]->{transfd} . "', skipped='".
					$dcc->{skipped}. "', starttime='$dcc->{starttime}'. ".
					"Please report this to maintainer (the best is to attach ".
					"log output of last couple of minutes). Listing sends:");
				display_sends('!fserve!');
			}
			if ($speed < $min_cps) {
				# too slow...

				if ($fs_sends[$s]->{warns} < 
					$fs_queues[$fs_sends[$s]{queue}]->{speed_warnings}) {

					# but he/she still has a chanse...
					my $warn_msg;
					my $last_warn_msg;

					print_debug("$dcc->{nick}: send is too slow ($speed),".
						" but warns=".$fs_sends[$s]->{warns});

					if (!$fs_sends[$s]->{dontwarn}) {

						if ($fs_sends[$s]->{warns} == 0) {
							$warn_msg = "First warning";
						} elsif ($fs_sends[$s]->{warns} == 1) {
							$warn_msg = "Second warning";
						} else {
							$warn_msg = "Warning";
							$fs_sends[$s]->{dontwarn} = 1;
							$last_warn_msg = ' Next warnings will be suppressed.';
						}
						my $server = $dcc->{server};
						if ($server && $server->{connected}) {
							$server->command("^NOTICE $fs_sends[$s]->{nick} ".
								$fs_prefs{clr_txt}.$warn_msg.
								": the speed of your send (".
								$fs_prefs{clr_hi}.size_to_str($speed)."/s".
								$fs_prefs{clr_txt}.") is less than min CPS ".
								"requirement (".$fs_prefs{clr_hi}.
								size_to_str($min_cps)."/s".
								$fs_prefs{clr_txt}.").".$last_warn_msg);
							print_what_we_did("NOTICE $fs_sends[$s]->{nick} ".
								$fs_prefs{clr_txt}.$warn_msg.
								": the speed of your send (".
								$fs_prefs{clr_hi}.size_to_str($speed)."/s".
								$fs_prefs{clr_txt}.") is less than min CPS ".
								"requirement (".$fs_prefs{clr_hi}.
								size_to_str($min_cps)."/s".
								$fs_prefs{clr_txt}.").".$last_warn_msg);
						}
					}

					$fs_sends[$s]->{warns} += 1;
				} else {
					# we must finish him :(
					my $server = $dcc->{server};
					print_debug("$dcc->{nick}: warns=".
						$fs_sends[$s]->{warns}.
						" and speed is too slow ($speed)");
					if ($server && $server->{connected}) {
						$server->command("^NOTICE $fs_sends[$s]->{nick} ".
							$fs_prefs{clr_txt}."The speed of your send (".
							$fs_prefs{clr_hi}.size_to_str($speed)."/s".
							$fs_prefs{clr_txt}.") is less than min CPS ".
							"requirement (".$fs_prefs{clr_hi}.
							size_to_str($min_cps)."/s".
							$fs_prefs{clr_txt}."), aborting...");
						print_what_we_did("NOTICE $fs_sends[$s]->{nick} ".
							$fs_prefs{clr_txt}."The speed of your send (".
							$fs_prefs{clr_hi}.size_to_str($speed)."/s".
							$fs_prefs{clr_txt}.") is less than min CPS ".
							"requirement (".$fs_prefs{clr_hi}.
							size_to_str($min_cps)."/s".
							$fs_prefs{clr_txt}."), aborting...");

						$fs_sends[$s]{transfd} = -1;
						$server->command("DCC CLOSE SEND $dcc->{nick}");
					}
					# FIXME: don't return here?
					return; # don't touch $fs_sends[$s] anymore!
				}
			} else {
				if ($fs_sends[$s]->{warns}) {
					print_debug("$dcc->{nick}: speed is ok ($speed), reset speed warnings");
					$fs_sends[$s]->{warns} = 0;
				}
			}
		}
		$fs_sends[$s]->{transfd} = $dcc->{transfd};
		return;
	}
	# Could not find active send matching out record - delete it
	# Don't know why it happens, one possibility is the file name in 
	# dcc_destroyed do not match the one recoreded in fs_sends, but don't
	# know how it's possibile 
	print_debug("BUG?: cannot find file $fs_sends[$s]->{file} sending to ".
		"$fs_sends[$s]->{nick}\@$fs_sends[$s]->{server_tag}");
	print_debug("Active sends:");
	foreach (Irssi::Irc::dccs()) {
		print_debug("$_->{nick}\@$_->{servertag} -> $_->{arg}")
			if ($_->{type} eq 'SEND');
	}
	print_debug("Removing lost send");
	splice(@fs_sends, $s, 1);
}


sub do_help 
{
	my $arg = lc(join(" ", @_));
	print_msg ("Arg is '$arg'");
	
	if (! $arg) { print_msg("
Help for FServe

All FServe commands are executed using '/fs <command>' 
syntax.
To get more help about specific topic type 
'/fs help <topic>'.

List of available help topics:
* commands - available commands
* tutorial - how to set up simple file server
* bugs - known bugs/limitations (TODO)
");	return; }

	if ($arg eq "commands") { print_msg("
List of FServe commands. 

To get more help about specific command type
'/fs help <command>'.

v* on      - enable fileserver
v* off     - disable fileserver
v* save    - save config file
v* load    - load config file
v* saveq   - save sends and queues
v* loadq   - load queues
v* set     - list/set global settings
v* sett    - list/set trigger variables
v* addt    - add new trigger
v* delt    - delete trigger
v* selt    - set default trigger 
v* queue   - list file queue
v* sortt   - sort trigger
v* move    - move queue slots around
* insert  - insert a file into queue
* clear   - remove queued files
* sends   - list active sends
* who     - list online online
* stats   - show server statistics
* distro  - show distro statistics
* recache - update filecache
* notify  - show fserve ad to user/channel
* help    - show help
"); return; }

	if ($arg eq "on") {	print_msg("
ON

Enables FServe, updates filecache.
Doesn't load saved queues.

See also: LOADQ
"); return; }
	
	if ($arg eq "off") { print_msg("
OFF

Disables FServe. 
If 'autosave_on_close' is 1 saves sends and queues.

See also: SAVEQ
"); return; }

	if ($arg eq "save") { print_msg("
SAVE

Saves config file.
");	return; }

	if ($arg eq "load") { print_msg("
LOAD

Loads config file.
");	return; }

	if ($arg eq "saveq") { print_msg("
SAVEQ

Saves sends and queues.

See also: LOADQ
");	return; }

	if ($arg eq "loadq") { print_msg("
LOADQ

Loads sends and queues (sends are put 
in the queues as first)

See also: SAVEQ
");	return; }

	if ($arg eq "set") { print_msg("
SET [-clear] [variable value]

If used without arguments lists global settings.

You can unset variable with -clear switch, 
for example: /fs set -clear offline_message

To get help for specific variable use
/fs help set <variable_name>

See also: SETT
");	return; }

	if ($arg eq "sett") { print_msg("
SETT [-clear] [variable value]

If used without arguments lists current trigger
settings.
You can select current trigger with '/fs selt <number>'

You can unset variable with -clear switch, 
for example: /fs sett -clear offline_message

To get help for specific variable use
/fs help sett <variable_name>

See also: SET, SELT
");	return; }

	if ($arg eq "addt") { print_msg("
ADDT

Adds new trigger.

See also: SELT
");	return; }

	if ($arg eq "delt") { print_msg("
DELT <trigger number>

Removes trigger.
It does not remove files from queues.

See also: SELT
");	return; }

	if ($arg eq "selt") { print_msg("	
SELT <trigger number>

Selects default trigger.

The default trigger is used as default for
MOVE, QUEUE, SETT, SORTT commands.
");	return; }

	if ($arg eq "queue") { print_msg("
QUEUE [<trigger number>]

Displays queued files.
If used without argument uses default trigger.
You can use '*' as an argument to display all 
queued files.

See also: SELT
");	return; }

	if ($arg eq "sortt") { print_msg("	
SORTT [<trigger number>]

Sorts queued files according to queue_priority.
If used without argument uses default trigger.

See also: SELT
");	return; }

	if ($arg eq "move") { print_msg("
MOVE [<trigger number>] <from> <to>

Moves files queued in trigger <trigger number> (or default
trigger) from position <from> to position <to>.

See also: SELT
");	return; }

	if ($arg eq "distro") { print_msg("	
DISTRO stats

Displays send count for files

See also: SET distro
");	return; }

	if ($arg eq "set auto_save") { print_msg("
SET auto_save <seconds>

Every <seconds> seconds saves config, sends and 
queues

See also: SET autosave_on_close
");	return; }
	
	if ($arg eq "set autosave_on_close") { print_msg("
SET autosave_on_close 0|1

When set to 1 sends and queues will be saved in /fs off

See also: SET auto_save
");	return; }
	
	if ($arg =~ /^set clr_(dir|file|hi|txt)$/) { print_msg("
SET clr_dir <color>
SET clr_file <color>
SET clr_hi <color>
SET clr_txt <color>

This settings controll colors in fserve.
Currently it's a little bit inconsistent.
You can set <color> using ^C<txt_color>,<bg_color>
(standart irssi/bitchx colors), for example
/SET clr_txt ^C12
to set text color to blue.

Remember to use xy color codes, i.e. don't use 
^C9 but use ^C09. If not displaying files that start 
with a number will be fscked ;)
");	return; }
	
	if ($arg eq "set count_send_as_queue") { print_msg("
SET count_send_as_queue 0|1

If set to 1 sends user have are counted as queues.
So if user have 1 send and 2 file queued, and 
user_slots is set to 3 the user won't be able
to queue any more files (because has 2 queues and
1 send = 3 files). If count_send_as_queue was 0
the user would be able to queue one more file.

See also: SETT user_slots
");	return; }
	
	if ($arg eq "set debug") { print_msg("
SET debug 0|1

When set to 1 enables diagnostic messages
");	return; }

	if ($arg eq "set distro" || $arg eq "set distro_file" ) { print_msg("
SET distro <probability>
SET distro_file <file_name>

When <probability> is 1 fileserver counts how many times 
each file was sent, and first sends files with lowest send 
count.

In fact, distro setting isn't simply 0/1. It's a PROBABILITY of
using distro mode for the send. The values should be from range
[0,1], where 0 means don't use distro mode at all, and 1 means
allways use distro mode. 

For example when it's set to 0.7 it'll use distro mode in 7 
cases of 10 (more or less). 

See also: DISTRO
");	return; }

	if ($arg eq "set idle_time" || $arg eq "set max_time") { print_msg("	
SET idle_time <s1>
SET max_time <s2>

Controls how much time the user can be connected with
fserve on dcc chat.

User will be disconnected after either:
<s1> seconds of inactivity
<s2> seconds since connecting
");	return; }
	
	if ($arg eq "set ignores" || $arg eq "sett ignores") { print_msg("
SET ignores <mask> <mask2> ...
SETT ignores <mask> <mask2> ...

Using this settings you can 'ban' users from the fserve.
Fserve won't respond to !list nor trigger.

The <mask> is in normal nick!ident\@host format,
you can use '*' and '?'.
");	return; }
	
	if ($arg eq "set log_name") { print_msg("
SET log_name <file>

Logs file transfers to <file>

You can use \$IRSSI and ~ that specify irssi's home
and your home directory.
");	return; }

	if ($arg eq "set max_queues" || 
		$arg =~ /^sett (max_queues|guaranted_queues)$/){ print_msg("
SET max_queues <val>
SETT max_queues <val>
SETT guaranted_queues <val>

Those setting are responsibile for number of queues for 
the trigger and for whole fserve.

Algorithm used to compute number of free/max queues:

Maximum queues := 
  max( guaranted_queues, 
       min(global max_queues, trigger max_queues) )

Free queues := 
  max( guaranted_queues - number of trigger queues,
       min( global max_queues - number of all queues, 
            trigger max_queues - number of queue queues ) )

In short:
a) the trigger has at least guaranted_queues queues
b) maximum number of queues is the smallest value of 
   global and trigger max_queues, except for (a)

See also: SET max_sends

TODO: examples of usage
");	return; }

	if ($arg eq "set max_sends" || 
		$arg =~ /^sett (max_sends|guaranted_sends)$/){ print_msg("
SET max_sends <val>
SETT max_sends <val>
SETT guaranted_sends <val>

Those setting are responsibile for number of sends for 
the trigger and for the whole fserve.

Algorithm used to compute number of free/max sends:

Maximum sends := 
  max( guaranted_sends, 
       min(global max_sends, trigger max_sends) )

Free sends := 
  max( guaranted_sends - number of trigger sends,
       min( global max_sends - number of all sends, 
            trigger max_sends - number of trigger sends ) )

In short:
a) the trigger has at least guaranted_sends sends
b) maximum number of sends is the smallest value of 
   global and trigger max_sends, except for (a)

See also: SET max_queues, SET min_upload
");	return; }

	if ($arg eq "set max_users") { print_msg("
SET max_users <number>

Sets how many users can connect to the fserve.
");	return; }
	
	if ($arg eq "set min_upload") { print_msg("
SET min_upload <bps>

Tries to make sure that sum of upload speeds
of all dcc sends is >= <bps>. If for 4 minutes 
it's no it tries to send next file, even if
there is already max_sends sends.
");	return; }

	if ($arg eq "set motd" or $arg eq "set motdfile" or 
		$arg eq "sett motd") { print_msg("
SET <motd>
SET <motd_file>
SETT <motd>

Specifies messages that will be displayed in welcome message
after user connects to fserve.
The message can be read from file <motd_file>.
In <motd_file> you can use \$IRSSI and ~ that specify irssi's 
home and your home directory.
");	return; }

	if ($arg eq "set offline_message") { print_msg("
SET offline_message <message>

When fserve is offline and user tries to connect
to it using ctcp trigger fserve sends notice:
'Sorry, fserve is currently offline. <message>'
");	return; }

	if ($arg eq "set queuefile") { print_msg("
SET queuefile <file>

Saves sends and queues to <file>

You can use \$IRSSI and ~ that specify irssi's 
home and your home directory.
");	return; }
	
	if ($arg eq "set recache_interval") { print_msg("
SET recache_interval <seconds>

Every <seconds> does /fs recache.
");	return; }
	
	if ($arg eq "sett channels") { print_msg("
SETT channels <#channel1> [#channel2 ...]

Space separated list of channels on which this
trigger will work.

See also: SETT servers
");	return; }
	
	if ($arg eq "sett content" or $arg eq "sett note") { print_msg("
SETT content <content>
SETT note <note>

Text that can be displayed in fserve ad.

See also: SETT custom_notice
");	return; }

	if ($arg eq "sett ctcp_only") { print_msg("
SETT ctcp_only 0|1

If set to 1 fserve will ignore triggers typed
on channels. It'll only respond to /ctcp.

If set to 0 it will respond to both triggers typed
on channels and used in /ctcp. 
");	return; }
	
	if ($arg eq "sett custom_notice" || $arg eq "sett custom_notice_fields") { print_msg("
SETT custom_notice 0|1
SETT custom_notice_fields <list of fields>

Controls what will be included in fserver ad. 
If custom_notice is 0 then everything is included.
If it's 1 then only fields specified in <list of fields>
will be included.
If it's 1 and custom_notice_fields is empty then fserve
doesn't show ad at all (but it still respond to trigger
etc.)

Possibile fields: trigger, sends, queues, min_cps, online,
accessed, snagged, record, current_upstream, serving,
note, content

Example: 
/fs sett custom_notice_fields trigger note content
");	return; }
	
	if ($arg eq "sett dont_notify") { print_msg("
");	return; }
	if ($arg eq "sett find") { print_msg("
");	return; }
	if ($arg eq "sett ignore_msg") { print_msg("
");	return; }
	if ($arg eq "sett instant_send") { print_msg("
");	return; }
	if ($arg eq "sett max_resends") { print_msg("
");	return; }
	if ($arg eq "sett min_cps") { print_msg("
");	return; }
	if ($arg eq "sett nice") { print_msg("
");	return; }
	if ($arg eq "sett notify_interval") { print_msg("
");	return; }

	if ($arg eq "sett notify_on_join") { print_msg("
SETT notify_on_join 0|1

When on, users joining a served channel will
be sent an fserve notice.
");	return; }
	
	if ($arg eq "sett queue_priority") { print_msg("
");	return; }
	if ($arg eq "sett request") { print_msg("
");	return; }
	if ($arg eq "sett restricted_level") { print_msg("
");	return; }
	if ($arg eq "sett root_dir") { print_msg("
");	return; }
	
	if ($arg eq "sett servers") { print_msg("
SETT servers <server_tag> [server_tag_2 ...]

Space separated list of server tags on which this 
trigger will work.
Please read tutorial on how to add server tags.

See also SETT channels, tutorial
");	return; }
	
	if ($arg eq "sett speed_warnings") { print_msg("
");	return; }
	if ($arg eq "sett trigger") { print_msg("
");	return; }

	if ($arg eq "sett user_slots") { print_msg("
SETT user_slots <number>

Number of file user can queue (sometimes
files being sent counts as well - see
SET count_send_as_queue).

See also: SET count_send_as_queue
");	return; }

	if ($arg eq "tutorial") {
		print_msg("
Setting up simple file server.

After loading fserve you need to at least 
- add first trigger with '/fs addt'
- set up 'root_dir', 'servers' and 'channels'
  For example: 
  /fs sett root_dir /home/me/fs_root
  /fs sett servers aniv
  /fs sett channels #smurfs
  
The 'aniv' is the name if irc network you'll be using.
You can add irc networks with '/ircnet add', for example:
/ircnet add aniv
and then
/server add -ircnet aniv irc.aniverse.com 

You can now enable the FServe with '/fs on'!

Some other things you should know:
- you can list global and trigger-specific settings with 
  '/fs set' and '/fs sett'
- you can add more triggers with '/fs addt' and choose default 
  trigger with '/fs selt <number>'
- 'servers' and 'channels' can be a list of space separated 
  values, for example '#smurfs #gumibears #wuzzles'
- '/fs help' has help for all FServe commands and settings
");
	return;
	}
	
	if ($arg eq "bugs") { print_msg("
Limitations:

There can be only one send per user on irc server, no matter
how many trigger there are. Maybe this should be changed to
1 send/trigger or even be parametrized. Comments welcomme.
");	return; }

	print_msg("No such help topic: $arg");
}

##############################################################################
# Handle an "/fs *" type command
###############################################################################
sub sig_fs_command
{
	my ($cmd_line, $server, $win_item) = @_;
	my @args = split(' ', $cmd_line);

	if (@args <= 0 || lc($args[0]) eq 'help') {
		shift @args;
		do_help(@args);
		return;
	}

	# convert command to lowercase
	my $cmd = lc(shift(@args));

	if ($cmd eq 'on') {
		unless ($fs_enabled) {
			update_files();
			$timer_tag = Irssi::timeout_add(1000, 'sig_timeout', 0);
			$fs_enabled = 1;
		}
		print_msg("Fileserver online!");
	} elsif ($cmd eq 'off') {
		if ($fs_enabled) {
			$fs_enabled = 0;			
			Irssi::timeout_remove($timer_tag);
			print_msg("Sends & Queue saved") 
				if ($fs_prefs{autosave_on_close} && (!save_queue()));
			print_msg("Distro file saved") if ($fs_prefs{distro} and !save_distro());
		}
		print_msg("Fileserver offline!");
	} elsif ($cmd eq 'set' || $cmd eq 'sett') {
		my $hash;
		if ($cmd eq 'set') {
			$hash = \%fs_prefs;
		} else {
			$hash = $fs_queues[$default_queue];
		}
		if (@args == 0) {
			my $msg = "[$fs_prefs{clr_hi}FServe Variables$fs_prefs{clr_txt}]";
			if ($cmd eq 'sett') {
				$msg .= " for queue $default_queue";
			}
			print_msg($msg);
			foreach (sort(keys %{$hash})) {
				if (/clr/) {
					print_msg("$_ $fs_prefs{clr_hi}=$fs_prefs{clr_txt} ".
							  "$hash->{$_}COLOR");
				} elsif ($cmd eq 'sett' && ($_ eq 'queue' || $_ eq 'cache' ||
						$_ eq 'sends' || $_ eq 'filecount' || $_ eq 'bytecount')) {
					next;
				} else {
					print_msg("$_ $fs_prefs{clr_hi}=$fs_prefs{clr_txt} ".
							  $hash->{$_});
				}
			}
			print_msg("\003\n$fs_prefs{clr_txt}Ex: /fs set max_users 4");
		} elsif (@args < 2) {
			print_msg("Error: usage /fs $cmd <var> <value>");
	    } elsif ($args[0] eq '-clear' && defined $hash->{$args[1]}) {
			print_msg("Clearing $args[1]");
			$hash->{$args[1]} = "";
			if ($args[1] eq 'log_name' && $logfp) {
			    print_log("Closing log.");
			    close($logfp);
			    undef $logfp;
			}
		} elsif (defined $hash->{$args[0]}) {
			my $var = shift(@args);
			return if ($cmd eq 'sett' && ($var eq 'queue' || $var eq 'cache' ||
				$var eq 'sends' || $var eq 'filecount' || $var eq 'bytecount'));
			$hash->{$var} = "@args";
			if ($var =~ /^clr/) {
				print_msg("Setting: $var $fs_prefs{clr_hi}=$hash->{$var}COLOR");
			} else {
				print_msg("Setting: $var $fs_prefs{clr_hi}=$fs_prefs{clr_txt} ".
						  $hash->{$var});
			}
			if ($var eq 'log_name') {
				if ($logfp) {
					print_log("Closing log.");
					close($logfp);
					undef $logfp;
				}
				print_log("Opening log.");
			} elsif ($var eq 'motdfile') {
				$motdfile_modified = 0;				
			}
		} else {
			print_msg("Error: unknown variable ($args[0])");
		}
	} elsif ($cmd eq 'save') {
		print_msg("Config file saved!") if (!save_config());
	} elsif ($cmd eq 'load') {
		print_msg("Config file loaded!") if (!load_config());
	} elsif ($cmd eq 'saveq') {
		print_msg("Sends & Queue saved!") if (!save_queue());
	} elsif ($cmd eq 'loadq') {
		print_msg("Queue loaded!") if (!load_queue());
	} elsif ($cmd eq 'who') {
		display_who('!fserve!');
	} elsif ($cmd eq 'recache') {
		update_files();
	} elsif ($cmd eq 'queue') {
		if (@args < 1) {
			display_queue('!fserve!', $default_queue);
		} elsif ($args[0] eq '*') {
			foreach (0 .. $#fs_queues) {
				display_queue('!fserve!', $_);
			}
		} elsif ($args[0] > $#fs_queues) {
			print_msg("Usage /fs queue [<queue>]");
		} else {
			display_queue('!fserve!', $args[0]);
		}
	} elsif ($cmd eq 'sends') {
		display_sends('!fserve!');
	} elsif ($cmd eq 'sortt') {
		if (@args < 1) {
			sort_queue($default_queue);
		} elsif ($args[0] > $#fs_queues) {
			print_msg("Usage /fs sortt [<queue>]");
		} else {
			sort_queue($args[0]);
		}
	} elsif ($cmd eq 'stats') {
		display_stats('!fserve!');
		foreach (0 .. $#fs_queues) {
			print_msg("Queue $_: ".scalar(@{$fs_queues[$_]->{queue}}).'/'.
					  $fs_queues[$_]->{max_queues}." files");
		}
	} elsif ($cmd eq 'insert') {
		if (@args < 3 || $args[0] > $#fs_queues) {
			print_msg("Usage /fs insert <queue> <nick> <file>");
			return;
		}
		my $qn = shift(@args);
		my $nick_id = shift(@args);
		srv_queue_file($nick_id, "@args", $qn);
	} elsif ($cmd eq 'move') {
		if (@args < 2 || (@args > 2 && $args[0] > $#fs_queues)) {
			print_msg("Usage /fs move [<queue>] <from> <to>");
		} elsif (@args == 2) {
			srv_move_slot($args[0], $args[1], $fs_queues[$default_queue]->{queue});
		} else {
			srv_move_slot($args[1], $args[2], $fs_queues[$args[0]]->{queue});
		}
	} elsif ($cmd eq 'clear') {
		if (@args < 1) {
			print_msg("Usage /fs clear <nick> | /fs clear -all");
			return;
		}
		foreach (0 .. $#fs_queues) {
			if ($args[0] eq '-all') {
				my @nullqueue = ();
				$fs_queues[$_]->{queue} = [ @nullqueue ];
			} else {
				clear_queue($args[0], 1, $_);
			}
		}
	} elsif ($cmd eq 'notify') {
		return unless ($fs_enabled);
		# TODO /fs notify #channel server
		# FIXME not working?
		foreach my $qn (0 .. $#fs_queues) {
			if (@args == 0) {
				foreach my $s (split(' ', $fs_queues[$qn]->{servers})) {						
					my $server = Irssi::server_find_tag($s);
					next if (!$server || !$server->{connected});
					foreach (split(' ', $fs_queues[$qn]->{channels})) {
						show_notice($server, $_, $qn);
					}
				}
			} else {
				foreach my $s (split(' ', $fs_queues[$qn]->{servers})) {						
					my $server = Irssi::server_find_tag($s);
					next if (!$server || !$server->{connected});
					foreach (@args) {
						show_notice($server, $_, $qn)
							if ($fs_queues[$qn]->{channels} =~ /.*$_.*/i);
					}
				}
			}	
		}
	} elsif ($cmd eq 'distro') {
		if ($args[0] eq 'stats') {
			foreach (sort keys %fs_distro) {
				foreach my $size (sort keys %{$fs_distro{$_}}) {
					print_msg("$_ (".$size." B) $fs_distro{$_}{$size}");
				}
			}
		} else {
			print_msg("Usage: /fs distro stats");
		}
	} elsif ($cmd eq 'selt') {
		if (@args < 1 || $args[0] > $#fs_queues) {
			print_msg("Usage: /fs selt <queue>");
			return;
		}
		$default_queue = $args[0];
		print_msg("Selecting trigger: $default_queue");
	} elsif ($cmd eq 'addt') {
		print_msg("Adding trigger: ".scalar(@fs_queues));
		push (@fs_queues, { %fs_queue_defaults });
		@{$fs_queues[$#fs_queues]->{queue}} = ();
	} elsif ($cmd eq 'delt') {
		if (@args < 1 || $args[0] > $#fs_queues) {
			print_msg("Usage: /fs delt <trigger_no>");
			return;
		} elsif (@fs_queues < 2) {
			print_msg("You cannot remove last trigger!");
			return;
		}
		my $qn = $args[0];
		if ($fs_queues[$qn]->{sends}) {
			print_msg('There are on-going sends for this trigger,');
			print_msg('please stop them first before removing the trigger.');
			print_msg('(If you think fserve.pl should act differently');
			print_msg('in this case please drop me a mail. Thanks)');
			return;
		}
		splice (@fs_queues, $qn, 1);
		foreach (@fs_sends) {
			if ($_->{queue} > $qn) {
				$_->{queue}--;
			}
		}
		foreach ($qn .. $#fs_queues) {
			foreach my $q (@{$fs_queues[$_]->{queue}}) {
				$q->{queue}--;
			}
		}
		if ($default_queue >= $qn) {
			$default_queue--;
		}
		print_msg("Trigger $qn deleted");
	} else {
		print_msg("Unrecognized command /fs $cmd");
	}
}

###############################################################################
###############################################################################
##	
##		Script subroutines
##
###############################################################################
###############################################################################

###############################################################################
#	initiate_dcc_chat($server, $nick, $qn): inits a dcc chat & sets some 
#	variables for $nick
###############################################################################
sub initiate_dcc_chat
{
	my ($server, $nick, $qn) = @_;

	print_debug("Initiating DCC CHAT to $nick for queue $qn");

	my %nickinfo = ();
	$nickinfo{status} 	= -1;
	$nickinfo{time} 	= 0;
	$nickinfo{ignore}	= 0;
	$nickinfo{dir} 		= '/';
	$nickinfo{queue}	= $qn;
	$nickinfo{server}	= $server->{tag};

	$fs_users{$nick."@".$server->{tag}} = { %nickinfo };
	$server->command("DCC CHAT $nick");
}

###############################################################################
#	show_notice($server, $dest, $qn): displays server notice to $dest
#	($dest = #channel or nick)
###############################################################################
sub show_notice
{
	my ($server, $dest, $qn) = @_;
	my $queue = $fs_queues[$qn];

	foreach ($fs_queues[$qn]{dont_notify}) {
		return if ($_ eq $dest);
	}
	
	my $msg = "\002(\002FServe Online\002)\002";
	
	my @fields_list = ("trigger", "sends", "queues", "min_cps", "online", 
		"accessed", "snagged", "record", "current_upstream", "serving",
		"note", "content");
	
	if ($queue->{custom_notice}) {
		return if (!$queue->{custom_notice_fields}); # Don't send the ad
		@fields_list = split(' ', $queue->{custom_notice_fields});
	}
		
	foreach (@fields_list) {
		/trigger/ && do { 
			$msg .= " Trigger:(/ctcp $$server{nick} $queue->{trigger})";
			next; 
		};
		/sends/ && do { 
			my ($curr_sends, $free_sends, $max_sends) = get_max_sends($qn);
			$msg .= " Sends:(".($max_sends-$free_sends)."/$max_sends)";
			next; 
		};
		/queues/ && do { 
			my ($curr_queues, $free_queues, $max_queues) = get_max_queues($qn);
			$msg .= " Queues:(".($max_queues-$free_queues)."/$max_queues)";
			next; 
		};			
		/min_cps/ && do { 
			if ($queue->{min_cps}) {
				$msg .= ' Min CPS:('.size_to_str($queue->{min_cps}).'/s)';
			}
			next; 
		};
		/online/ && do { 
		    $msg .= ' Online:('.(keys %fs_users)."/$fs_prefs{max_users})";
			next; 
		};
		/accessed/ && do { 
    		$msg .= " Accessed:($fs_stats{login_count} times)";
			next; 
		};
		/snagged/ && do { 
			$msg .= ' Snagged:('.size_to_str($fs_stats{transfd}).' in '.
				($fs_stats{sends_ok}+$fs_stats{sends_fail}).' files)';
			next; 
		};
		/record/ && do { 
			if ($fs_stats{record_cps}) {
				$msg .= ' Record CPS:('.size_to_str($fs_stats{record_cps}).
				'/s by '.$fs_stats{rcps_nick}.')';
			}
			next; 
		};
		/current_upstream/ && do { 
			my $curr_ups = 0;
			foreach my $dcc (Irssi::Irc::dccs()) {
				if ($dcc->{type} eq 'SEND') {
					$curr_ups += ($dcc->{transfd}-$dcc->{skipped})/
						(time() - $dcc->{starttime} + 1);
				}
			}
			$msg .= ' Current Upstream:('.size_to_str($curr_ups).'/s)';
			next; 
		};
		/serving/ && do { 
			$msg .= ' Serving:('.size_to_str($queue->{bytecount}).' in '.
				"$queue->{filecount} files)";
			next; 
		};
		/note/ && do { 
			if (length($queue->{note})) {
				$msg .= " Note:($fs_prefs{clr_hi}$queue->{note}$fs_prefs{clr_txt})";
			}
			next; 
		};
		/content/ && do { 
			if (length($queue->{content})) {
				$msg .= " On FServe:($fs_prefs{clr_hi}$queue->{content}$fs_prefs{clr_txt})";
			}
			next; 
		};
		print_debug("Unknown notice field: $_");
	}

	$msg =~ s/\(/\($fs_prefs{clr_hi}/g;
	$msg =~ s/\)/$fs_prefs{clr_txt}\)/g;

	$msg .= " [FServe.pl $VERSION]";
		
	if ($dest =~ /^#/) {
		$server->command("MSG $dest $fs_prefs{clr_txt}$msg");
	} else {
		$server->command("^NOTICE $dest $fs_prefs{clr_txt}$msg");
		print_what_we_did("NOTICE $dest $fs_prefs{clr_txt}$msg");
	}
}

###############################################################################
#       show_find($server, $who, $file, $qn): displays @find notice to $who
###############################################################################
sub show_find
{
	my ($server, $who, $file, $qn) = @_;

	$file =~ s/^\@find //i;
	$file = "\Q$file\E";
	$file =~ s/([\\]?[* ])+/.*/g;

	print_debug("requested find patter '$file' in queue $qn");
	# prepare list
	my @founds = ();
	foreach my $dir (keys %{$fs_queues[$qn]->{cache}}) {
		my $files = $fs_queues[$qn]->{cache}{$dir}{files};
		my $sizes = $fs_queues[$qn]->{cache}{$dir}{sizes};

		$dir =~ s/$/\//;
		$dir =~ s/^\/+//;
		foreach my $i (0 .. $#{$files}) {
			$_ = ${$files}[$i];
#			print_debug("Checking against '$_'");
			if (/$file/i) { # hmm.. check Sysreset response...
#				print_debug("This file matches!");
				push (@founds, (scalar(@founds)+1).". File: (".
					$fs_prefs{clr_dir}.$dir.$_.$fs_prefs{clr_txt}.") Size:(".
					size_to_str(${$sizes}[$i]).")");
			}
		}
	}

	if (!@founds) {
		return;
	}

	my ($curr_sends, $free_sends, $max_sends) = get_max_sends($qn);
	my ($curr_queues, $free_queues, $max_queues) = get_max_queues($qn);
	
	my $message = "(\@Find Results) - [FServe.pl $VERSION]";
	$server->command("^MSG $who $message");
	print_what_we_did("MSG $who $message");
	$message = "Found ".@founds." file(s) on trigger:(".$fs_prefs{clr_hi}.
		"/ctcp $server->{nick} $fs_queues[$qn]->{trigger}".$fs_prefs{clr_txt}.
		") Sends:(".($max_sends-$free_sends)."/$max_sends)".
		" Queues:(".($max_queues-$free_queues)."/$max_queues)";
	$server->command("^MSG $who $message");
	print_what_we_did("MSG $who $message");
	
	foreach (0 .. $#founds) {
		last if ($_ >= $fs_queues[$qn]->{find});
		$server->command("^MSG $who $founds[$_]");
		print_what_we_did("MSG $who $founds[$_]");
	}
	if (@founds > $fs_queues[$qn]->{find}) {
		$server->command("^MSG $who Too many results to display!");
		print_what_we_did("MSG $who Too many results to display!");
	} else {
		$server->command("^MSG $who End of \@Find.");
		print_what_we_did("MSG $who End of \@Find.");
	}
}

###############################################################################
#	change_dir($nick, $dir): changes directory for $nick
###############################################################################
sub change_dir
{
	my ($nick, $dir) = @_;
	my ($irc_nick, $server_tag) = split('@', $nick);
	my $qn = $fs_users{$nick}{queue};

	$dir =~ s/\x03//g; # remove colors if any
	my @dir_fields = ();
	unless (substr($dir, 0, 1) eq '/') {
		@dir_fields = split('/', $fs_users{$nick}{dir});
	}

	foreach (split('/', $dir)) {
		next if ($_ eq '.');
		if ($_ eq '..') {
			pop(@dir_fields);
		} else {
			push(@dir_fields, $_);
		}
	}

	my $new_dir = '/'.join('/', @dir_fields);
	$new_dir =~ s/\/+/\//g;		# remove excessive '/'

	if (defined $fs_queues[$qn]->{cache}{$new_dir}) {
		$fs_users{$nick}{dir} = $new_dir;
		send_user_msg($server_tag, $irc_nick, 
			"[$fs_prefs{clr_hi}$new_dir$fs_prefs{clr_txt}]");
	} else {
		send_user_msg($server_tag, $irc_nick, 
			"[$fs_prefs{clr_hi}$new_dir$fs_prefs{clr_txt}] doesn't exist!");
	}
}

###############################################################################
#	list_dir($nick): list contents of current directory for $nick
###############################################################################
sub list_dir
{
	my ($nick) = @_;
	my ($irc_nick, $server_tag) = split('@', $nick);
	my $qn = $fs_users{$nick}{queue};
	my $dir = $fs_queues[$qn]->{cache}{$fs_users{$nick}{dir}};
	my @filelist = ();

	$_ = $fs_users{$nick}{dir};
	s/\/+$//;
	send_user_msg($server_tag, $irc_nick, 
		"Listing [$fs_prefs{clr_hi}$_/*.*$fs_prefs{clr_txt}]");

	# print the directories sorted
	send_user_msg($server_tag, $irc_nick, $fs_prefs{clr_dir}."..") 
		if ($fs_users{$nick}{dir} ne "/");
	send_user_msg($server_tag, $irc_nick, 
		$fs_prefs{clr_dir}.$_.$fs_prefs{clr_txt}.'/') 
		foreach (sort(@{${$dir}{dirs}}));

	# prepare filelist
	foreach (0 .. $#{${$dir}{files}}) {
		push(@filelist, ${$dir}{files}[$_]."  ".
		     size_to_str(${$dir}{sizes}[$_]));
	}

	# print the files sorted
	send_user_msg($server_tag, $irc_nick, $fs_prefs{clr_file}.$_) 
		foreach(sort(@filelist));
	send_user_msg($server_tag, $irc_nick, 
		"End [$fs_prefs{clr_hi}$fs_users{$nick}{dir}$fs_prefs{clr_txt}]");
}

###############################################################################
#	srv_queue_file($nick_id, $file, $qn): queues to queue $qn file for $nick_id,
#				      server use only
#				      (no max_queue and/or duplicate check)
###############################################################################
sub srv_queue_file
{
	my ($nick_id, $path, $qn) = @_;
	my ($nick, $server_tag) = split('@', $nick_id);
	$path =~ s/~/$ENV{"HOME"}/;

	unless (-e $path || -f $path) {
		print_msg("Invalid file: '$path'");
		return;
	}

	my $size = (stat($path))[7];
	$path =~ /(.*)\/(.*)/;
	$path = $1;
	my $file = $2;    

	push(@{$fs_queues[$qn]->{queue}}, { queue => $qn, nick => $nick,
		 file => $file, size => $size,
		 dir => $path, resends => 0, warns => 0, server_tag => $server_tag });
		 
	print_msg($fs_prefs{clr_hi}.'#'.@{$fs_queues[$qn]->{queue}}.
			  $fs_prefs{clr_txt}.": Queuing '$fs_prefs{clr_hi}$file".
			  "$fs_prefs{clr_txt}' for $fs_prefs{clr_hi}$nick".
			  "$fs_prefs{clr_txt} ($server_tag) in queue ".
			  "$fs_prefs{clr_hi}$qn$fs_prefs{clr_txt}!");
}

###############################################################################
#	srv_move_slot($slot, $dest, [ @queue ]): moves queue slots around
###############################################################################
sub srv_move_slot
{
	my ($slot, $dest, $fsq) = @_;

	$slot--;
	$dest--;

	unless (defined ${$fsq}[$slot] || defined ${$fsq}[$dest]) {
		print_msg("Error: Invalid slot numbers!");
		return;
	}
	print_debug("srv_move_slot: Will move $slot to $dest");

	my %rec = %{${$fsq}[$slot]};
	splice(@{$fsq}, $slot, 1);
	splice(@{$fsq}, $dest, 0, { %rec });

	print_msg("Moved slot $fs_prefs{clr_hi}#".($slot+1).$fs_prefs{clr_txt}.
			  " to $fs_prefs{clr_hi}#".($dest+1));
}

###############################################################################
#	get_user_flag($server, $nick,$qn): returns highest user flag 
#		(normal/voice/halfop/op) among all channels from fs_queues[$qn]->{channels}
###############################################################################
sub get_user_flag {
	my ($server,$nick,$qn) = @_;
	
	my $bestflag = "normal";
	foreach my $channelName (split(' ', $fs_queues[$qn]->{channels})) {
		my $channel = $server->channel_find($channelName);
		next if !$channel;
		my $n = $channel->nick_find($nick);
		next if !$n;
		if ($n->{op}) {
			return "op";
		} elsif ($n->{halfop}) {
			$bestflag = "halfop";
		} elsif ($n->{voice} and $bestflag ne "halfop") {
			$bestflag = "voice";
		}
		# max 4 categories - see sort_queue() also
	}
	return $bestflag;
}

###############################################################################
#	sort_queue($qn): sorts queue according to queue_priority 
#				  returns where was moved last position
###############################################################################
	# queue_priority format:
	# group1 group2 ... groupN
	# where groupX is one of: others, normal, voice, halfop, op
	# for example:
	#   normal voice others
	# means that first in queue are "normal" people, then people who are +v,
	# and then the rest - ops and halfops
	#
	# When some server is disconnected then all people on this server are
	# sorted last in the queue.
sub sort_queue {
	my ($qn) = @_;

	print_debug ("sort_queue: $qn");
	return ($#{$fs_queues[$qn]->{queue}})
		if (!$fs_queues[$qn]->{queue_priority});

	my %prio;
	my $n = 1;  # highest priority is 0 - resended queue
	foreach (split (/ +/, $fs_queues[$qn]->{queue_priority})) {
		if (/others/) {
			foreach my $type ("normal", "voice", "halfop", "op") {
				if (not exists $prio{$type}) {
					$prio{$type} = $n;
				}
			}
		} else {
			$prio{$_} = $n;
		}
		$n++;
	}
	# in case there is no 'others' in queue_priority we assume it's last
	foreach my $type ("normal", "voice", "halfop", "op") {
		if (not exists $prio{$type}) {
			$prio{$type} = $n;
		}
	}
	my $max_prio = $n;

	my @uprio = (0, 0, 0, 0, 0); # assume max 4 categories + resends :)
	my $fsq = $fs_queues[$qn]->{queue};
	my $dmsg = 'Sorting...';
	# now do sorting
	foreach (0 .. $#{$fsq}) {
		if (${$fsq}[$_]->{resends}) {
			$n = 0;
		} else {
			my $server = Irssi::server_find_tag(${$fsq}[$_]->{server_tag});
			if (!$server || !$server->{connected}) {
				$n = $max_prio;
			} else {
				$n = $prio{get_user_flag($server, ${$fsq}[$_]->{nick}, $qn)};
			}
		}

		# re-sort these positions 0 .. $_
		splice(@{$fsq}, $uprio[$n], 0, splice(@{$fsq}, $_, 1))
			if ($uprio[$n] != $_);

		$dmsg .= " $_:$uprio[$n]";
		# update @uprio
		$uprio[$_]++ foreach ($n .. $#uprio);
	}
	print_debug($dmsg);

	# $n now has prio for last moved position
	return $uprio[$n]-1;
}

###############################################################################
#	queue_file($nick, $file): queues $file for $nick. 
###############################################################################
sub queue_file
{
	my ($nick, $ufile) = @_;
	$ufile =~ s/\s+$//; 
	my $qn = $fs_users{$nick}{queue};
	my ($file, $size);
	my ($irc_nick, $server_tag) = split('@', $nick);

	print_debug("queue_file: '$ufile' for $nick in queue $qn");
	# try to find the filename in cache
	my $files = $fs_queues[$qn]->{cache}{$fs_users{$nick}{dir}}{files};
	my $sizes = $fs_queues[$qn]->{cache}{$fs_users{$nick}{dir}}{sizes};

	my $fsq = $fs_queues[$qn]->{queue};

	foreach (0 .. $#{$files}) {
		if (uc(${$files}[$_]) eq uc($ufile)) {
			$file = ${$files}[$_];
			$size = ${$sizes}[$_];
			last;
		}
	}

	unless (defined $file) {
		send_user_msg($server_tag, $irc_nick, 
			"Invalid filename: '$fs_prefs{clr_hi}$ufile$fs_prefs{clr_txt}'!");
		return;
	}

	my $server = Irssi::server_find_tag($server_tag);
	if (!$server || !$server->{connected}) {
		print_msg("Error: this should never happen!!! #002");
		return;
	}

	if ($size <= $fs_queues[$qn]{instant_send}) {
		my $sfile = $fs_queues[$qn]->{root_dir}.$fs_users{$nick}{dir}.'/'.$file;
		$sfile =~ s/\/+/\//g;
		if (-e $sfile && -f $sfile) {
			send_user_msg($server_tag, $irc_nick, 
				"Sending '$fs_prefs{clr_hi}$file$fs_prefs{clr_txt}'");
			$sfile =~ s/'/\\'/g;
			$server->command("DCC SEND $irc_nick $FD$sfile$FD");
			return;
		}
	}

	my ($curr_queues, $free_queues, $max_queues) = get_max_queues($qn);
	my ($curr_sends, $free_sends, $max_sends) = get_max_sends($qn);

	if (count_user_files($server_tag, $irc_nick, $qn) >= 
		$fs_queues[$qn]->{user_slots}) {
		send_user_msg($server_tag, $irc_nick, 
			"No sends are available and you have ".
			"used all your queue slots ($fs_prefs{clr_hi}".
			"$fs_queues[$qn]->{user_slots}$fs_prefs{clr_txt})");
		return;
	} elsif ($free_queues <= 0) {
		send_user_msg($server_tag, $irc_nick, 
			"No send or queue slots are available!");
		return;
	} else {
		foreach (0 .. $#{$fsq}) {
			if (${$fsq}[$_]->{nick} eq $irc_nick && 
				${$fsq}[$_]->{file} eq $file &&
				${$fsq}[$_]->{server_tag} eq $server_tag) {
				send_user_msg($server_tag, $irc_nick, 
					"You have already queued '".
					"$fs_prefs{clr_hi}$file$fs_prefs{clr_txt}'".
					" in slot #$fs_prefs{clr_hi}".($_+1).
					"$fs_prefs{clr_txt}!");
				return;
			}
		}
	}

	push(@{$fsq}, { queue => $qn, nick => $irc_nick, file => $file, 
		size => $size, dir => $fs_queues[$qn]->{root_dir}.$fs_users{$nick}{dir},
	 	resends => 0, warns => 0, server_tag => $server_tag });

	my $place = sort_queue($qn);	
	print_debug("queue_file: queued on place $place");
	
	send_user_msg($server_tag, $irc_nick, 
		"Queued '$fs_prefs{clr_hi}$file$fs_prefs{clr_txt}".
		"' (".$fs_prefs{clr_hi}.size_to_str($size).
		$fs_prefs{clr_txt}.") in slot ".$fs_prefs{clr_hi}.'#'.
		($place+1) .$fs_prefs{clr_txt});
}

###############################################################################
#	dequeue_file($nick, $slot): dequeues file in slot $slot for $nick
###############################################################################
sub dequeue_file
{
	my ($nick, $slot) = @_;
	my ($irc_nick, $server_tag) = split('@', $nick);
	my $fsq = $fs_queues[$fs_users{$nick}{queue}]->{queue};

	$slot -= 1;
	if (defined ${$fsq}[$slot]) {
		if (${$fsq}[$slot]->{nick} eq $irc_nick &&
			${$fsq}[$slot]->{server_tag} eq $server_tag) {
			my $filename = ${$fsq}[$slot]{file};
			splice(@{$fsq}, $slot, 1);
			send_user_msg($server_tag, $irc_nick, "Removing '$fs_prefs{clr_hi}".
				"$filename$fs_prefs{clr_txt}', you now have $fs_prefs{clr_hi}".
				count_queued_files($server_tag, $irc_nick,$fs_users{$nick}{queue}).
				"$fs_prefs{clr_txt} file(s) queued!");
		} else {
			send_user_msg($server_tag, $irc_nick, 
				"You can't dequeue other peoples files!!!");
		}
	} else {
		send_user_msg($server_tag, $irc_nick, 
			"Queue slot $fs_prefs{clr_hi}#".($slot+1).
			$fs_prefs{clr_txt}." doesn't exist!");
	}
}

###############################################################################
#	clear_queue($nick, $is_server, $qn): clears all queued files for $nick
###############################################################################
sub clear_queue
{
	my ($nick, $is_server, $qn) = @_;
	my ($irc_nick, $server_tag) = split('@', $nick);
	my $fsq = $fs_queues[$qn]->{queue};
	my $count = 0;

	if (count_queued_files($server_tag, $irc_nick, $qn) == 0) {
		if ($is_server) {
			print_msg("$fs_prefs{clr_hi}$nick$fs_prefs{clr_txt} doesn't ".
					  "have any files queued!");
		} else {
			send_user_msg($server_tag, $irc_nick, "You don't have any queued files!");
		}
	} else {
		for (my $i = $#{$fsq}; $i >= 0; $i--) {
			if (${$fsq}[$i]->{nick} eq $irc_nick && 
				${$fsq}[$i]->{server_tag} eq $server_tag) {
				splice(@{$fsq}, $i, 1);
				$count++;
			}
		}

		$irc_nick = '!fserve!' if ($is_server);
		send_user_msg($server_tag, $irc_nick, 
			"Successfully dequeued $fs_prefs{clr_hi}".
			"$count$fs_prefs{clr_txt} file(s)!");
	}
}

###############################################################################
#	display_queue($nick, $qn): displays queue to $nick
###############################################################################
sub display_queue
{
	my ($nick, $qn) = @_;
	my ($irc_nick, $server_tag) = split('@', $nick);
	my $queue = $fs_queues[$qn];
	my $fsq = $queue->{queue};
	my $m_server = (split(' ', $queue->{servers}) > 1);

	my ($curr_queues, $free_queues, $max_queues) = get_max_queues($qn);
	if ($nick eq '!fserve!') {
		send_user_msg($server_tag, $irc_nick, 
			"$curr_queues/$free_queues/$max_queues Current/Free/Max queues ".
			"for trigger #".$qn.":");
	} else {
		send_user_msg($server_tag, $irc_nick, 
			$fs_prefs{clr_hi}.$curr_queues.$fs_prefs{clr_txt}."/".
			$fs_prefs{clr_hi}.$max_queues.$fs_prefs{clr_txt}.
			" file(s) queued for this trigger. ".$fs_prefs{clr_hi}.
			$free_queues.$fs_prefs{clr_txt}." free slot(s) left.");
	}	
	
	foreach (0 .. $#{$fsq}) {
		my $msg = "  $fs_prefs{clr_hi}#".($_+1)."$fs_prefs{clr_txt}".
			": $fs_prefs{clr_hi}${$fsq}[$_]->{nick}$fs_prefs{clr_txt}".
			($m_server?" (${$fsq}[$_]->{server_tag})":"").
			" queued $fs_prefs{clr_hi}${$fsq}[$_]->{file}$fs_prefs{clr_txt}".
			" (".$fs_prefs{clr_hi}.size_to_str(${$fsq}[$_]->{size}).
			$fs_prefs{clr_txt}.")";
		if (${$fsq}[$_]->{resends}) {
			$msg .= " (Resend #".${$fsq}[$_]->{resends}.")";
		}
		send_user_msg($server_tag, $irc_nick, $msg);
	}
}

###############################################################################
#	display_who($user_id): shows users connected to $user_id
###############################################################################
sub display_who
{
	my ($user_id) = @_;
	my ($nick, $server_tag) = split('@', $user_id);

	send_user_msg($server_tag, $nick, $fs_prefs{clr_hi}.keys(%fs_users).
		$fs_prefs{clr_txt}.' user(s) online!');
	
	foreach (keys(%fs_users)) {
		my ($n, $s_tag) = split('@', $_);		
		if ($fs_users{$_}{status} == -1) {
			send_user_msg($server_tag, $nick, 
				"  $fs_prefs{clr_hi}$n$fs_prefs{clr_txt} ($s_tag):".
						  " connecting...");
		} else {
			send_user_msg($server_tag, $nick, 
				"  $fs_prefs{clr_hi}$n$fs_prefs{clr_txt} ($s_tag):".
				" online $fs_prefs{clr_hi}$fs_users{$_}{time}s".
				"$fs_prefs{clr_txt} idle: $fs_prefs{clr_hi}".
				"$fs_users{$_}{status}s");
		}
	}
}

###############################################################################
#	display_sends($nick): shows active sends to $nick
###############################################################################
sub display_sends
{
	my ($nick) = @_;
	my ($irc_nick, $server_tag) = split('@', $nick);
	my $guaranted_sends;
	my $qtext = "";
	my $qn = -1;

	if (defined $fs_users{$nick}) {
		$qn = $fs_users{$nick}{queue};
	}


	if ($qn != -1) { # user - show only this queue sends
		my ($curr_sends, $free_sends, $max_sends) = get_max_sends($qn);
		send_user_msg($server_tag, $irc_nick, 
			"Sending $fs_prefs{clr_hi}".$curr_sends.'/'.
			 $max_sends.$fs_prefs{clr_txt}." file(s) for this trigger. ".
			 $fs_prefs{clr_hi}.$free_sends.$fs_prefs{clr_txt}." free sends left.");
	} else { # me - show all sends
		send_user_msg($server_tag, $irc_nick, 
			"Sending $fs_prefs{clr_hi}".@fs_sends.'/'.
			$fs_prefs{max_sends}.$fs_prefs{clr_txt}." file(s)!");
	}

	foreach my $dcc (Irssi::Irc::dccs()) {
		next if ($dcc->{type} ne 'SEND');
		
		foreach (0 .. $#fs_sends) {
			next if ($dcc->{nick} ne $fs_sends[$_]{nick} ||
				$dcc->{arg} ne $fs_sends[$_]{file} ||
				$dcc->{servertag} ne $fs_sends[$_]{server_tag});
				
			if ($qn < 0) {
				$qtext = " for queue #".$fs_sends[$_]->{queue};
			} else {
				last if ($fs_sends[$_]->{queue} != $qn);
			}
			
			if ($dcc->{starttime} == 0 ||
				($dcc->{transfd}-$dcc->{skipped}) == 0) {
				send_user_msg($server_tag, $irc_nick, 
					"  $fs_prefs{clr_hi}#".($_+1).
					"$fs_prefs{clr_txt}: Waiting for ".
					$fs_prefs{clr_hi}.$dcc->{nick}.$fs_prefs{clr_txt}.
					" ($dcc->{servertag}) to accept $fs_prefs{clr_hi}".
					"$dcc->{arg}".
					$fs_prefs{clr_txt}." (".$fs_prefs{clr_hi}.
					size_to_str($fs_sends[$_]->{size}).
					$fs_prefs{clr_txt}.")".$qtext);
				last;
			}
				
			my $perc = sprintf("%.1f%%", ($dcc->{transfd}/$dcc->{size})*100);
			my $speed = ($dcc->{transfd}-$dcc->{skipped})/(time() - $dcc->{starttime} + 1);
			my $left  = ($dcc->{size} - $dcc->{transfd}) / $speed;
			send_user_msg($server_tag, $irc_nick, 
				"  $fs_prefs{clr_hi}#".($_+1)."$fs_prefs{clr_txt}:".
				" $fs_prefs{clr_hi}$dcc->{nick}$fs_prefs{clr_txt} ".
				"($dcc->{servertag}) has ".
				$fs_prefs{clr_hi}.$perc.$fs_prefs{clr_txt}.
				" of '$fs_prefs{clr_hi}$dcc->{arg}$fs_prefs{clr_txt}'".
				" at ".$fs_prefs{clr_hi}.size_to_str($speed)."/s".
				$fs_prefs{clr_txt}." (".$fs_prefs{clr_hi}.
				time_to_str($left).$fs_prefs{clr_txt}." left)".
				$qtext);
			last;
		}
	}

}

###############################################################################
#	display_stats($nick): displays server statistics to $nick
###############################################################################
sub display_stats
{
	my ($nick) = @_;
	my ($irc_nick, $server_tag) = split('@', $nick);

	send_user_msg($server_tag, $irc_nick, "-=[ Server Statistics ]=-");
	send_user_msg($server_tag, $irc_nick, "  Online for ".$fs_prefs{clr_hi}.time_to_str($online_time));
	send_user_msg($server_tag, $irc_nick, "  Access Count: ".$fs_prefs{clr_hi}.$fs_stats{login_count});
	send_user_msg($server_tag, $irc_nick, " ");
	send_user_msg($server_tag, $irc_nick, "  Successful Sends: ".$fs_prefs{clr_hi}.$fs_stats{sends_ok});
	send_user_msg($server_tag, $irc_nick, "  Bytes Transferred: ".$fs_prefs{clr_hi}.size_to_str($fs_stats{transfd}));
	send_user_msg($server_tag, $irc_nick, "  Failed Sends: ".$fs_prefs{clr_hi}.$fs_stats{sends_fail});
	send_user_msg($server_tag, $irc_nick, "  Record CPS: ".$fs_prefs{clr_hi}.size_to_str($fs_stats{record_cps})."/s");
}

###############################################################################
## Shows a small file to the user
###############################################################################
sub display_file ($$) {
	my ($nick, $ufile) = @_;
	my ($irc_nick, $server_tag) = split('@', $nick);
	my $queue = $fs_queues[$fs_users{$nick}{queue}];
	my ($file, $size, $dir, $filepath);

	# try to find the filename in cache
	my $files = $queue->{cache}{$fs_users{$nick}{dir}}{files};
	my $sizes = $queue->{cache}{$fs_users{$nick}{dir}}{sizes};

	foreach (0 .. $#{$files}) {
		if (uc(${$files}[$_]) eq uc($ufile)) {
			$file = ${$files}[$_];
			$size = ${$sizes}[$_];
			last;
		}
	}

	$dir = $queue->{root_dir} . $fs_users{$nick}{dir};
	$filepath = "$dir" . "/" . "$ufile";

	unless (defined $file) {
		send_user_msg($server_tag, $irc_nick, "Invalid filename: " .
			"'$fs_prefs{clr_hi}$ufile$fs_prefs{clr_txt}'!");
		return;
	}

	if ($size > 30000) {
		send_user_msg($server_tag, $irc_nick, "File too large: " .
			"'$fs_prefs{clr_hi}$ufile$fs_prefs{clr_txt}'!");
		return;
	}

	unless (open (RFILE, "<", $filepath)) {
		send_user_msg($server_tag, $irc_nick, "Couldn't open file: " .
			"'$fs_prefs{clr_hi}$ufile$fs_prefs{clr_txt}'!");
		print_msg("Could not open file $filepath");
		return;
	}

	while (my $line = <RFILE>) {
		chomp $line;
		send_user_msg($server_tag, $irc_nick, $line);
	}

	unless (close (RFILE)) {
		print_debug("Couldn't close file: $filepath");
		return;
	}

	return 1;
}

###############################################################################
#	send_next_file(): send a file from not forced queues
###############################################################################
sub send_next_file
{
	my ($ignore_free_sends) = @_;
	
	# first step: reorder queues
	my @que_numb = (0 .. $#fs_queues);
	splice (@que_numb, 0, 0, (splice(@que_numb, $next_queue)));

	# First use queues with lowest 'nice', then queues with least sends.
	my @min_queue = sort { 
		$fs_queues[$a]->{nice} <=> $fs_queues[$b]->{nice} or 
		$fs_queues[$a]->{sends} <=> $fs_queues[$b]->{sends} 
		} @que_numb;

	# step 2b: select a queue
	foreach my $i (@min_queue) {
		my $free_sends = (get_max_sends($i))[1];
		next if ($free_sends == 0 and !$ignore_free_sends);  

		
		if (!run_queue($fs_queues[$i])) {
			$next_queue++;
			$next_queue = 0	if ($next_queue >= scalar(@fs_queues));
			print_debug("send_next_file(): next queue will be $next_queue");
			return 0;
		}
	}
	return 1;
}

###############################################################################
#	run_queue($queue): try to send the next file in $queue
###############################################################################
sub run_queue
{
	my ($queue) = @_;
	my %entry = ();
	my ($next, $nextcount, $nextfile) = (-1); 

	# step through the queue
	for (my $i = 0; $i < @{$queue->{queue}}; ) {
		%entry = %{ ${$queue->{queue}}[$i] };
		my $server = Irssi::server_find_tag($entry{server_tag});
		if (!$server || !$server->{connected}) {
			$i++;
			next;
		}
		
		my $in_channel  = user_in_channel($server, $entry{nick}, $queue);
		my $send_active = send_active_for($entry{server_tag}, $entry{nick});
		my $file = $entry{dir}.'/'.$entry{file};
		$file =~ s/\/+/\//g;

		# rand() returns [0,1) so if distro is == 0 this is always false,
		# and if distro == 1 this is allways true
		my $use_distro = (rand() < $fs_prefs{distro}) ? 1 : 0;
		
		# send file if user in channel and has no sends active
		if (!$send_active && $in_channel && -e $file && -f $file) {
			if (!$use_distro) {
				$next = $i;
				$nextfile = $file;	
				last;
			}
			my $count =  $fs_distro{$entry{file}}{$entry{size}};
			if ($next < 0 or $nextcount > $count) {
				$next = $i;
				$nextcount = $count;
				$nextfile = $file;			
			}
			$i++;
			next;
		}
			
		# remove entry if user wasn't in channel of file didn't exist
		if (!$send_active) {
			Irssi::print("User $fs_prefs{clr_hi}$entry{nick} ".
				"$fs_prefs{clr_txt} not in channel or file doesn't exists,".
				" removing $entry{file}".
				$fs_prefs{clr_txt}." from queue...");
			splice(@{$queue->{queue}}, $i, 1);
			# next slot will have same index
		} else {
            $i++;
        }
	}

	return 1 if ($next == -1);

	%entry = %{ ${$queue->{queue}}[$next] };
	my $server = Irssi::server_find_tag($entry{server_tag});
	$server->command("^NOTICE $entry{nick} ".$fs_prefs{clr_txt}.
					 "Sending you your queued file (".$fs_prefs{clr_hi}.
					 size_to_str($entry{size}).$fs_prefs{clr_txt}.")");
	print_what_we_did("NOTICE $entry{nick} ".$fs_prefs{clr_txt}.
					 "Sending you your queued file (".$fs_prefs{clr_hi}.
					 size_to_str($entry{size}).$fs_prefs{clr_txt}.")");
	$nextfile =~ s/'/\\'/g;
	$server->command("DCC SEND $entry{nick} $FD$nextfile$FD");
	push(@fs_sends, { %entry });
	splice(@{$queue->{queue}}, $next, 1);
	return 0;
}

###############################################################################
#	update_files():	update the cache from $fs_prefs{root_dir}
###############################################################################
sub update_files
{
	my $filecount;
	my $bytecount;

	print_msg("Caching files, please wait!");
	# update the cache
	foreach my $qn (0 .. $#fs_queues) {
		delete $fs_queues[$qn]->{cache};
		cache_dir($fs_queues[$qn]->{root_dir},$fs_queues[$qn]);

		$filecount = 0;
		$bytecount = 0;
		foreach my $dir (keys %{$fs_queues[$qn]->{cache}}) {
			$filecount += @{$fs_queues[$qn]->{cache}{$dir}{files}};
			$bytecount += $_ foreach (@{$fs_queues[$qn]->{cache}{$dir}{sizes}});
		}

		$fs_queues[$qn]->{filecount} = $filecount;
		$fs_queues[$qn]->{bytecount} = $bytecount;

		print_msg("Queue $qn: cached $filecount file(s) (".size_to_str($bytecount).") in ".
				  (keys(%{$fs_queues[$qn]->{cache}}))." dir(s)!");
	}	
}

###############################################################################
#	cache_dir($dir): recursive filecaching subroutine
###############################################################################
sub cache_dir
{
	my ($dir, $queue) = @_;
	my @dirs  = ();
	my @files = ();
	my @sizes = ();

	opendir($dir, "$dir");
	while (my $entry = readdir($dir)) {
		if (!($entry eq '.') && !($entry eq '..')) {
			my $full_path = $dir.'/'.$entry;
			if (-d $full_path) {
				push(@dirs, $entry);
				cache_dir($full_path, $queue);
			} elsif (-f $full_path) {
				push(@sizes, (stat($full_path))[7]);
				push(@files, $entry);
			}
		}
	}

	closedir($dir);

	$dir =~ s/$queue->{root_dir}//;
	$dir = '/' if (length($dir) == 0);

	$queue->{cache}{$dir} = { dirs => [ @dirs ], files => [ @files ],
						sizes => [ @sizes ] };
}

###############################################################################
#	count_queued_files($server_tag, $nick,$qn): returns number of queued files 
#		for $nick
###############################################################################
sub count_queued_files
{
	my ($server_tag, $nick, $qn) = @_;
	my $count = 0;
	
	foreach (0 .. $#{$fs_queues[$qn]->{queue}}) {
		$count++ 
			if (${$fs_queues[$qn]->{queue}}[$_]->{nick} eq $nick &&
				${$fs_queues[$qn]->{queue}}[$_]->{server_tag} eq $server_tag);
	}

	return $count;
}

###############################################################################
#	count_user_files($server_tag, $nick, $qn): returns number of queued and 
#	sended files for $nick
###############################################################################
sub count_user_files {
	my ($server_tag, $nick, $qn) = @_;

	if (!$fs_prefs{count_send_as_queue}) {
		return count_queued_files($server_tag, $nick, $qn);
	}

	my $count = count_queued_files($server_tag, $nick, $qn);
	foreach (0 .. $#fs_sends) {
		$count++ 
			if ($fs_sends[$_]->{nick} eq $nick && 
				$fs_sends[$_]->{server_tag} eq $server_tag);
	}

	return $count;
}

###############################################################################
#	send_active_for($server_tag, $nick): true if currently sending file to 
#		$nick
###############################################################################
sub send_active_for
{
	my ($server_tag, $nick) = @_;

	foreach (0 .. $#fs_sends) {
		return 1 if ($fs_sends[$_]{nick} eq $nick && 
			$fs_sends[$_]{server_tag} eq $server_tag);
	}

	return 0;
}

###############################################################################
#	user_in_channel($server,$nick,$queue): true if user is on any 
#		$queue->{channels}
###############################################################################
sub user_in_channel
{
	my ($server, $nick, $queue) = @_;

	foreach (split(' ', $queue->{channels})) {
#		print_debug("Checking channel $_");
		my $channel = $server->channel_find($_);
		if ($channel && $channel->{joined} && $channel->nick_find($nick)) {
			return 1;
		}
	}

	return 0;
}

###############################################################################
#	send_user_msg($servertag, $nick, $msg):	sends a msg to $nick using dcc if 
#	available
###############################################################################
sub send_user_msg
{
	my ($servertag, $nick, $msg) = @_;

	if ($nick eq "!fserve!") {
		print_msg($msg);
	} else {
		my $server = Irssi::server_find_tag($servertag);
		if (!$server || !$server->{connected}) {
			return;
		}

		my $cmd = ((defined $fs_users{$nick."@".$servertag})?"MSG =$nick":"MSG $nick");
		$server->command("$cmd $fs_prefs{clr_txt}$msg");
	}
}

###############################################################################
#	size_to_str($size): returns a formatted size string
###############################################################################
sub size_to_str
{
	my ($size) = @_;

	if ($size < 1024) {
		$size = int($size) . " B";
	} elsif ($size < 1048576) {
		$size = sprintf("%.1f kB", $size/1024);
	} elsif ($size < 1073741824) {
		$size = sprintf("%.2f MB", $size/1048576);
	} elsif ($size < 1099511627776) {
		$size = sprintf("%.2f GB", $size/1073741824);
	} else {
		$size = sprintf("%.3f TB", $size/1099511627776);
	}

	return $size;
}

###############################################################################
#	time_to_str($time): returns a formatted time string
###############################################################################
sub time_to_str
{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = gmtime(shift(@_));

	return sprintf("%dd %dh %dm %ds", $yday, $hour, $min, $sec) if ($yday);
	return sprintf("%dh %dm %ds", $hour, $min, $sec) if ($hour);
	return sprintf("%dm %ds", $min, $sec) if ($min);
	return sprintf("%ds", $sec);
}

###############################################################################
#	save_config(): saves preferences & statistics to file
###############################################################################
sub save_config
{
	my $f = $conffile; 
	$f =~ s/\$IRSSI/Irssi::get_irssi_dir()/e or $f =~ s/~/$ENV{"HOME"}/; 
	if (!open(FILE, ">", $f)) {
		print_msg("Unable to open $f for writing!");
		return 1;
	}

	print (FILE "[ConfigFileVersion 1.0]\n");
	
	# save preferences
	print(FILE "[common]\n");
	foreach (sort(keys %fs_prefs)) {
		print(FILE "$_=$fs_prefs{$_}\n");
	}

	# save statistics
	print(FILE "[stats]\n");
	foreach (sort(keys %fs_stats)) {
		print(FILE "$_=$fs_stats{$_}\n");
	}

	#save queues settings
	foreach my $qn (0 .. $#fs_queues) {
		print(FILE "[queue $qn]\n");
		foreach (sort(keys %{$fs_queues[$qn]})) {
			next if ($_ eq 'queue' || $_ eq 'cache' || $_ eq 'sends' ||
					 $_ eq 'filecount' || $_ eq 'bytecount');
			print(FILE "$_=$fs_queues[$qn]->{$_}\n");
		}
	}

	close(FILE);
	return 0;
}

###############################################################################
#	load_distro($file) 
###############################################################################
sub load_distro {
	my $file = $_[0];
	if (!open(FILE, "<", $file)) {
		print_msg("Unable to open $file for reading!");
		return 0;
	}

	# file format:
	# sent_count file_size file_name
	
	my ($count, $size, $name);
	while (<FILE>) {
		chomp;
		($count, $size, $name) = split(/ /, $_, 3);
		if (($count !~ /\d+/) or ($size !~ /\d+/) or (!$name)) { 
			print_msg("Error in $file in line $.");
			close(FILE);
			return 0;
		}
		$fs_distro{$name}{$size} = $count;
	}
	
	close(FILE);
	return 1; # ok
}


###############################################################################
#	save_distro() 
###############################################################################
sub save_distro 
{
	return 0 if (!$fs_prefs{distro_file});

	my $f = $fs_prefs{distro_file}; 
	$f =~ s/\$IRSSI/Irssi::get_irssi_dir()/e or $f =~ s/~/$ENV{"HOME"}/; 

	if (!open(FILE, ">", $f)) {
		print_msg("Unable to open $f for writing!");
		return 1;
	}

	foreach (sort keys %fs_distro) {
		foreach my $size (sort keys %{$fs_distro{$_}}) {
			print FILE "$fs_distro{$_}{$size} $size $_\n";
		}
	}

	close(FILE);
	return 0;
}

###############################################################################
#	load_config(): loads preferences & statistics from file
###############################################################################
sub load_config
{

	my $f = $conffile; 
	$f =~ s/\$IRSSI/Irssi::get_irssi_dir()/e or $f =~ s/~/$ENV{"HOME"}/; 
	if (!open(FILE, "<", $f)) {
		print_msg("Unable to open $f for reading!");
		return 1;
	}

	local $/ = "\n";

	my $config_version = <FILE>;
	chomp $config_version;
	if ($config_version !~ /^\[ConfigFileVersion 1\.[0-9]+]$/) {
		print_msg("Config file format not recognized!");
		print_msg("FServe 2.0 and newer won't work with config file");
		print_msg(" created by earlier versions on FServe.");
		return 1;
	}
												
	my $hash = \%fs_prefs; 
	my %garbage = ();

	while (<FILE>) {
		chomp;
		if (/^\[(.*)\]$/) { # next chapter
			if ($1 eq "common") {
				$hash = \%fs_prefs;
			} elsif ($1 eq "stats") {
				$hash = \%fs_stats;
			} elsif ($1 =~ /queue (.*)$/) {
				while (!defined $fs_queues[$1]) {
					push (@fs_queues, { %fs_queue_defaults });
					@{$fs_queues[$#fs_queues]->{queue}} = ();
				}
				$hash = $fs_queues[$1];
			} else {
				print_msg("Unknown config section: $_");
				$hash = \%garbage;
			}
			next;
		}
		my ($entry, $value) = split('=', $_, 2);
		if (defined $hash->{$entry}) {
			$hash->{$entry} = $value;
		} else {
			print_msg("unknown entry: $_");
		}
	}

	close(FILE);
	return 0;
}


###############################################################################
#	save_queue(): saves the current sends & queue to file
###############################################################################
sub save_queue
{
	my $f = $fs_prefs{queuefile}; 
	$f =~ s/\$IRSSI/Irssi::get_irssi_dir()/e or $f =~ s/~/$ENV{"HOME"}/; 

	if (!open(FILE, ">", $f)) {
		print_msg("Unable to open $f for writing!");
		return 1;
	}

	print (FILE "[QueueFileVersion 1.0]\n");

	# save the sends (for resuming)
	foreach my $slot (0 .. $#fs_sends) {
		foreach (sort keys %{$fs_sends[$slot]}) {
			next if ($_ eq "dontwarn");
			next if ($_ eq "transfd");
			if ($_ eq "warns") {
				print(FILE "$_=>0\0");
			} else {
				print(FILE "$_=>$fs_sends[$slot]->{$_}\0");
			}
		}
		print(FILE "\n");
	}
	
	# save the queues
	foreach (0 .. $#fs_queues) {
		my $fsq = $fs_queues[$_]->{queue};
		foreach my $slot (0 .. $#{$fsq}) {
			foreach (sort keys %{${$fsq}[$slot]}) {
				next if ($_ eq "dontwarn");
				next if ($_ eq "transfd");
				if ($_ eq "warns") {
					print(FILE "$_=>0\0");
				} else {
					print(FILE "$_=>${$fsq}[$slot]->{$_}\0");
				}
			}
			print(FILE "\n");
		}
	}

	close(FILE);
	return 0;
}

###############################################################################
#	load_queue(): (re)loads the queue from file
###############################################################################
sub load_queue
{
	my $f = $fs_prefs{queuefile}; 
	$f =~ s/\$IRSSI/Irssi::get_irssi_dir()/e or $f =~ s/~/$ENV{"HOME"}/; 
	
	if (!open(FILE, "<", $f)) {
		print_msg("Unable to open $f for reading!");
		return 1;
	}
	
	my $queue_version = <FILE>;
	chomp $queue_version;
	if ($queue_version !~ /^\[QueueFileVersion 1\.[0-9]+]$/) {
		print_msg("Queue file format not recognized!");
		print_msg("FServe 2.0 and newer won't work with queue file");
		print_msg(" created by earlier versions on FServe.");
		return 1;
	}

	if (!@fs_queues) {
		# create a very first queue :)
		push (@fs_queues, { %fs_queue_defaults });
		@{$fs_queues[$#fs_queues]->{queue}} = ();
	}

	# empty all queues
	foreach (0 .. $#fs_queues) {
		@{$fs_queues[$_]->{queue}} = ();
	}

	while (<FILE>) {
		s/\n//g;
		my %rec = ();
		my $ignore = 0;

		foreach my $line (split("\0", $_)) {
			my ($entry, $value) = split('=>', $line, 2);
			$rec{$entry} = $value;
		}
#		print_debug("Read: $rec{nick}|$rec{server_tag}|$rec{file}|$rec{queue}");

		# don't put it in queue if it is sending
		foreach (0 .. $#fs_sends) {
#			print_debug("Checking if it's not in fs_sends with: $fs_sends[$_]->{nick}|$fs_sends[$_]->{server_tag}|$fs_sends[$_]->{file}|$fs_sends[$_]->{queue}");
			if ($rec{nick} eq $fs_sends[$_]->{nick} &&
				$rec{file} eq $fs_sends[$_]->{file} &&
				$rec{queue} eq $fs_sends[$_]->{queue} &&
				$rec{server_tag} eq $fs_sends[$_]->{server_tag}) {
				$ignore = 1;
			}
		}

		if (!$ignore) {
			# check if it's sending already but isn't in %fs_sends
			foreach (Irssi::Irc::dccs()) {
#				print_debug("Checking if it's not sending with: $_->{nick}|$_->{servertag}|$_->{arg}");
				if ($_->{type} eq 'SEND' && $_->{nick} eq $rec{nick} &&
					$_->{arg} eq $rec{file} &&
					$rec{server_tag} eq $_->{servertag}) {
					print_debug("send of '$rec{file}' for $rec{nick}\@$rec{server_tag} was lost, adding to fs_sends");
					push(@fs_sends, { %rec });
					$ignore = 1;
					last;
				}
			}
		}
		if (!$ignore) {
			my $fsq;
			if (defined $rec{queue}) {
				if (!defined $fs_queues[$rec{queue}]) {
					print_msg("unknown queue #$rec{queue}");
					next;
				}
				$fsq = $fs_queues[$rec{queue}]->{queue};
			} else {
				$fsq = $fs_queues[0]->{queue};
			}
			# add to queue
			if ($rec{resends}) {
				# count resended files
				my $place = 0;
				foreach (0 .. $#{$fsq}) {
					$place++ if (${$fsq}[$_]->{resends});
				}
				splice(@{$fsq}, $place, 0, { %rec });
			} else {
				push(@{$fsq}, { %rec });
			}
		}
	}

	close(FILE);
	return 0;
}

###############################################################################
# print_log(): write line to log file
###############################################################################
sub print_log
{
	my $f = $fs_prefs{log_name}; 
	$f =~ s/\$IRSSI/Irssi::get_irssi_dir()/e or $f =~ s/~/$ENV{"HOME"}/; 
	if (!$logfp && $fs_prefs{log_name} && open(LOGFP, ">>", $f)) {
		$logfp = \*LOGFP;
		select((select($logfp), $|++)[0]);
	}
	return if !$logfp;
	my ($msg) = @_;
	$msg =~ s/^\s*|\s*$//gs;
	print $logfp localtime()." $msg\n";
}

# vim:noexpandtab:ts=4
