#
# $Id: fleech.pl,v 1.41 2003/01/11 23:07:48 piotr Exp $
#
# This script works the best with sysreset file server. For other file 
# server types you probably need to add regexps.
#
# Commands: (for "/fleech add" uses current irc server - make sure nick is
# 	on this server (e.g. execute "/fleech" commands in the window with 
# 	channel in which a nick is, or use C-x))
# 	
# Setting trigger: (<trigger> is a command you'd use to connect to fserve
#	without "/ctcp nick" part. Currently only /ctcp triggers are supported)
# /fleech add nick trigger <trigger>  
# 
# Adding file: (<file> is a file with full path, with "/" not "\" even if 
# 	fserve is run on windows)
# /fleech add nick file <file>
# 
# Adding multiple files with one command: (see also 'Multiple files' section 
#   below for examples and better description)
# /fleech add nick rfile xxx{01,5}yy\{\\{y 
#   
# Starting leeching:
# /fleech go
#
# Listing status:
# /fleech list
#
# Removing Completed file records:
# /fleech clrc
#
# There is also /fleech set command which is currently not documented 
# (RTFS :P), and a couple of /set fleech_ settings
#
# Example usage: ('nick' is fserve's nick)
# /fleech add nick trigger !get me
# /fleech add nick file lonewolf/Lone Wolf vol15 Story74.rar
# /fleech add nick file Lone Wolf15.jpg
# /fleech list
# /fleech go
#
# Multiple files: [patch by Stylianos Papadopoulos]
#	 Suppose you want to get files abc.r00, abc.r01, ..., abc.r45. 
#	 You can add them all with one command:
#		/fleech add nick rfile path/to/file/abc.r{00,45}
#	 The "{00,45}" will be replaced by 00, 01, ..., 45 and files will be 
#	 added for download.
#	 If the file name have "{" or "\" in it you need to escape such characters
#	 with a "\", so "{" -> "\{", "\" -> "\\"
#	 For example:
#		/fleech add nick rfile xxx{01,5}yy\{\\{y
#	will add xxx01yy{\{y, xxx02yy{\{y, ... , xxx05yy{\{y for download.
#
#
# TODO:
# - when get is closed and we're checking if there are other the same gets, 
# 	check only for gets with bigger tranfd
# - loading, saving leechs
# - user should be able to specify his own regexps for checking if file was
# 	queued etc, connect this with some name, and notify fleech.pl that
# 	server-nick fserve is that type fserve
#
# Changes:
# 0.0.2i (2005.03.06):
# 	- Multiple files adding with "/fleech add nick rfile" command, patch
# 	  from Stylianos Papadopoulos [papasv69 //at// hotmail //dot// com] 
# 	  (thanks!)
# 0.0.2h (2003.04.13):
# 	- /fleech set <oldnick> nick <newnick>
# 	- some other small fixes/changes
# 0.0.2g (2003.01.13):
#	- rechecking bugfix
# 0.0.2f (2003.01.12):
# 	- new command "/fleech clrc" to remove record of complete files 
# 	- some sanity checks in /fleech set
# 0.0.2e (2003.01.10): 
#	- should work when fserv changes nick. Because of this, use
#		"/fleech add nick trigger !trigger" and not, like previously,
#		"/fleech add nick trigger /ctcp nick !trigger".
#


use Irssi;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "0.0.2i";
%IRSSI = (
	authors	=> 'Piotr Krukowiecki',
	name	=> 'fleech',
	contact	=> 'piotr //at// krukowiecki //dot// net',
	description	=> 'fserve leecher - helps you download files from file servers',
	license	=> 'GNU GPL v2', 
	url	=> 'http://www.krukowiecki.net/code/irssi/'
);


### Data model: (i know this sucks :( )
# servertag->nick-> %hash:
# 	trigger->$
# 	path->@ (where are we in file server?)
# 	state->$ 
# 	type->$ (type of server, for example default, sysreset etc)
# 	lastaction->$ (when was last action performed/received)
# 	cfile->$ (number of file we're operating now, -1 if none (i.e. the send has come or fserver ACK'ed queueing/sending the file)
# 	files->@ of %hash: 
# 		name (file name with full path)
# 		state (complete, in transfer, not complete, etc.)
# 		depth (how deep in dirs the file is. file in root dir == 0)
# 		size (size of file, -1 means yet unknown)

my %serv = ();
my $dbglog = "";
#my $dbglog = Irssi::get_irssi_dir() . "/fleech.dbg";

my %states = (
	'0' => 'Nothing done', 
	'1' => 'Initiating connection', # sent e.g. "/ctcp nick trigger"
	'2' => 'Connecting', # accepted chat by "/dcc chat nick"
	'3' => 'Connected, waiting till end of welcome message', # dcc chat established, probably reading welcome message
	'4' => 'Connected, changing dir', # sent "cd dir"
	'5' => 'Connected, queueing files', # sent "get file"
	'6' => 'Files queued', # we belive we have queued all files we could
	'7'	=> 'All files complete', # we belive we have all files we wanted
	'8'	=> 'Slots Full', # can't queue cause slots full
	);

my %fstates = (
	'0'	=> 'File not complete', 
	'1'	=> 'Transfer in progress', # the files is currently being send to us
	'2'	=> 'Completed',	# we assume we have whole file on disk
	'3' => 'File queued', # we assume it's in queue
	);

my %servers = (
	'SysReset.*FileServer'	=> 'sysreset',
	'I.*-.*n.*-.*v.*-.*i.*-.*s.*-.*i.*-.*o.*-.*n.*File Server with Advanced File Serving features'	=> 'invision', # stupid colors
	'Edward_K Script'	=> 'edward_k',
	);
	
# TODO : Check more servers for regexps
my %patterns = ( 
	'default'	=> {
		'EoWM'	=> '\[\\\]', # End of Welcome Message
		'file queued'	=> 'queue(d|ing).*in.*slot|add.*file.*to.*slot',
		'my slots full'	=> 'queue slot.*full|have filled.*queue slots|no.*sends.*avail',
		'sending file'	=> 'sending',
		'invalid file name'	=> 'invalid filename|not.*valid.*file',
		'already queued'	=> 'already.*(queued|sending)',
		'dir changed'	=> '\[\\\.*\]',
		},
	'sysreset' => {
		'EoWM'	=> '\[\\\]', # End of Welcome Message
		'file queued'	=> 'Adding your file to queue slot.*The file will send when the next send slot is open', #ok
		'my slots full'	=> 'Sorry, all of your queue slots are full', #ok
		'all slots full'	=> 'Sorry, all send and queue slots are full', #ok
		'sending file'	=> 'Sending File', #ok
		'invalid file name'	=> 'Invalid file name, please use the form:', #OK
		'already sending'	=> 'That file is already sending', # ok
		'already queued'	=> 'That file has already been queued in slot', # ok
		'dir changed'	=> '\[\\\.*\]', #ok
		'press S'	=> "[[]'C' for more, 'S' to stop[]]", 
		},
	'edward_k' => {
		'EoWM'	=> '\[\\\]', #ok
		'file queued'	=> 'Queuing.*It has been placed in queue slot.*, it will send when sends are available',  #ok
		'my slots full'	=> 'Sorry, there are too many sends in progress right now and you have used all your queue slots\. If you still want to get a file please wait for one to finish and try again',  #ok
#		'all slots full'	=> 'Sorry, all send and queue slots are full', 
		'sending file'	=> 'Sending', #ok 
#		'already sending'	=> 'That file is already sending',  # not have?
		'already queued'	=> 'Sorry, that queue already exists in queue slot.*, you have already queued that file', #ok
		'dir changed'	=> '\[\\\.*\]', # ok 
		},
	'invision'	=> {
		'EndoWM'	=> '\[\\\]', # End of Welcome Message
		'file queued'	=> 'The file has been queued in slot|Thë.*file.*has beèn.*quëued.*in.*slót', #ok 1,2
		'my slots full'    => 'Invision has determined you have used all your queue slots', #ok 2
		'all slots full'	=> 'Sorry but the Maximum Allowed Queues of.*has been reached\. Please try again later',
		'sending file'	=> 'InstaSending|Sending .*(MB)+.*\.', #ok1
		'invalid file name'	=> 'File does not exists|ERROR:.*That is not a valid File', #ok1,2
		'already queued'	=> 'hàt queüé.*alreadý.*e×ísts in.*queuè slot.*, try ãnother fìlè', # ok1
		'dir changed'	=> '\[\\\.*\]', #ok
		},
	'lamielle' => { #
		'EoWM'	=> '\[\\\]', # OK
		'my slots full'	=> 'You already have a send going, please do not try to get another file till it has stopped',
		'invalid file name'	=> 'Invalid filename', #OK
		'dir changed'	=> '\[\\\.*\]', #ok
		},
	);

###
# "DCC CHAT from nick" came (or dcc send from nick, but we don't care)
sub sig_dcc_request {
	my ($dcc, $sendaddr) = @_;
	print_dbg("Signal 'dcc request': type '$dcc->{type}' from '$dcc->{nick}' on '$dcc->{servertag}' arg '$dcc->{arg}' sendaddr '$sendaddr'", 3);
	my $nick = lc $dcc->{'nick'};
	my $tag = $dcc->{'servertag'};

	return if (($dcc->{type} ne 'CHAT')
		or (not exists $serv{$tag})
		or (not exists $serv{$tag}{$nick})
		or ($serv{$tag}{$nick}{'state'} != 1));
		
	print_dbg("Accepting connection", 3);
	$serv{$tag}{$nick}{'state'} = 2;
	$serv{$tag}{$nick}{'lastaction'} = time();
	$dcc->{'server'}->command("DCC CHAT $dcc->{nick}");
}

###
# dcc chat established or dcc get established
sub sig_dcc_connected {
	my $dcc = @_[0];
	print_dbg("Signal 'dcc connected': type '$dcc->{type}' from '$dcc->{nick}' on '$dcc->{servertag}' arg '$dcc->{arg}'", 3);
	my $nick = lc $dcc->{'nick'};
	my $tag = $dcc->{'servertag'};
	
	return if ((not exists $serv{$tag})
			or (not exists $serv{$tag}{$nick}));
	my $fserv = get_fserv($tag, $nick);
	if ($dcc->{'type'} eq 'CHAT') {
		return if ($$fserv{'state'} != 2);
	
		print_dbg("Connection established", 3);
		$$fserv{'state'} = 3;
		$$fserv{'lastaction'} = time();
		return;
	}
	if ($dcc->{'type'} eq 'GET') {
		print_dbg("We have get!", 3);
		
		my $fnumber = find_file($fserv, $dcc->{'arg'});
		if ($fnumber == -1) {
			print_dbg("We have not queued this file", 3);
			return;
		}

		my $file = $$fserv{'files'}[$fnumber];
		if ($$file{'state'} == 2) {
			print_dbg("File completed, ignoring send", 3);
			return;
		}
		
		$$file{'state'} = 1;
		$$file{'size'} = $dcc->{'size'};
		$$fserv{'lastaction'} = time();
		$$fserv{'cfile'} = -1 if ($fnumber == $$fserv{'cfile'});

		if (($$fserv{'state'} == 0 or $$fserv{'state'} == 6 or
			$$fserv{'state'} == 8) and 
			(find_file_to_queue($tag, $nick) != -1)) {
			initiate_connection($tag, $nick);
			return;
		}
		return;
	}
}


###
# Finds number of file with name filename. File name has spaces changed
# to underscores and the search is case nonsensitive
# Does not care about file state
# nick record, filename
sub find_file_modified ($$) {
	my ($fserv, $file) = @_;
	my $number = -1;
	foreach (@{$$fserv{files}}) {
		$number++;
		my $name = $$_{'name'};	
		$name =~ tr/A-Z /a-z_/;	# FIXME : i hope locales won't be a problem...
		return $number 
			if ($name =~ m/^\Q${file}\E$/i or $name =~ m/\/\Q${file}\E$/i);
	}
	return -1;
}

###
# Finds number of file with name filename. Searches for exact match.
# Does not care about file state
# nick record, filename
sub find_file_exact($$) {
	my ($fserv, $file) = @_;
	my $number = -1;
	foreach (@{$$fserv{files}}) {
		$number++;
		return $number if ($$_{name} eq $file or $$_{name} =~ m|/\Q${file}\E$|);
	}
	return -1;
}

sub find_file($$) {
	my ($fserv, $file) = @_;
	my $num = find_file_exact($fserv, $file);
	return $num if ($num >= 0);
	return find_file_modified($fserv, $file);
}

### 
# End of dcc chat or end of dcc get
sub sig_dcc_destroyed {
	my $dcc = @_[0];
	print_dbg("Signal 'dcc destroyed': type '$dcc->{type}' from '$dcc->{nick}' on '$dcc->{servertag}' arg '$dcc->{arg}'", 3);
	my $nick = lc $dcc->{'nick'};
	my $tag = $dcc->{'servertag'};

	return if ((not exists $serv{$tag})
		or (not exists $serv{$tag}{$nick}));
	
	my $fserv = get_fserv($tag, $nick);
	
	if ($dcc->{'type'} eq 'CHAT') { # TODO : sometimes we should reconnect at once (when?)
		print_dbg("Chat connection closed", 3);
		$$fserv{'state'} = 0 if ($$fserv{'state'} < 6);
		$$fserv{'cfile'} = -1; 
		$$fserv{'lastaction'} = time();
		@{$$fserv{'path'}} = ();
		
		return;
	}

	if ($dcc->{'type'} eq 'GET') {
		my $fnumber = find_file($fserv, $dcc->{'arg'});
		if ($fnumber == -1) {
			print_dbg("We have not queued this file", 3);
			return;
		}

		my $file = $$fserv{'files'}[$fnumber];
		if ($$file{'state'} == 2) {
			print_dbg("File completed, ignoring this event", 3);
			return;
		}
		
		print_dbg("Dcc get connection closed", 3);
		$$fserv{'lastaction'} = time();

		if ($dcc->{'size'} == $dcc->{'transfd'}) {
			$$fserv{'files'}[$fnumber]{'state'} = 2;
			$$fserv{'cfile'} = -1 if ($fnumber == $$fserv{'cfile'}); # possibile if we had send for the file from before script was loaded
		} else {
			if (!gets_exists($tag, $dcc->{'nick'}, $dcc->{'arg'})) {
				$$fserv{'files'}[$fnumber]{'state'} = 0;
				$$fserv{cfile} = -1 if ($fnumber == $$fserv{cfile}); # possibile if we had send for the file from before script was loaded
			}
		}

		if (all_files_complete($tag, $nick)) { 
			$$fserv{'state'} = 7;
			print_dbg("Leeching complete for nick $nick\@$tag", 2);
			return;
		}

		if (($$fserv{'state'} == 0 or $$fserv{'state'} == 6 or
			$$fserv{'state'} == 8) and
			(find_file_to_queue($tag, $nick) != -1)) { 
			initiate_connection($tag, $nick);
			return;
		}
		
		return;
	}
}

###
# Text was send thorough dcc chat
# $dcc->{arg} is CHAT, what else can it be if type == CHAT?
sub sig_dcc_chat_message {
	my ($dcc, $message) = @_;
	print_dbg("Signal 'dcc chat message': type '$dcc->{type}' from '$dcc->{nick}' on '$dcc->{servertag}' arg '$dcc->{arg}' message '$message'", 3);
	my $nick = lc $dcc->{'nick'};
	my $tag = $dcc->{'servertag'};

	return if ((not exists $serv{$tag})
		or (not exists $serv{$tag}{$nick})
		or ($dcc->{'type'} ne 'CHAT'));
	
	my $fserv = get_fserv($tag, $nick);
	$$fserv{'lastaction'} = time();
	if ($$fserv{'state'} == 3) { # waiting till end of welcome message
		if ($$fserv{'type'} eq 'default') {
			foreach (keys %servers) {
				if ($message =~ /$_/i) {
					$$fserv{'type'} = $servers{$_};
					print_dbg("Recognized '$_' server", 2);
					last;
				}
			}
		}
		if ($message =~ /$patterns{$$fserv{'type'}}{'EoWM'}/i) { 
			print_dbg("Got End of Welcome Message", 3);
			get_next_file($dcc->{'server'}, $nick);
			return;
		}
		if ((exists $patterns{$$fserv{'type'}}{'press S'} and 
			$message =~ /$patterns{$$fserv{'type'}}{'press S'}/i)) {
			print_dbg("Pressing S", 3);
			$dcc->{'server'}->command("MSG =$dcc->{nick} S");
			return;
		}
		return;
	}
	if ($$fserv{'state'} == 4) { # changing dir
		# TODO : should check $message for 'directory not existing' etc
		print_dbg("Current state 4", 3);
		if ($message =~ /$patterns{$$fserv{'type'}}{'dir changed'}/i) {
			print_dbg("Directory successfully changed", 3);
			get_next_file($dcc->{'server'}, $nick);
		}
		return;
	}
	if ($$fserv{'state'} == 5) { # sent "get file"
		print_dbg("Current state 5", 3);
		if ((exists $patterns{$$fserv{'type'}}{'file queued'} and 
			$message =~ /$patterns{$$fserv{'type'}}{'file queued'}/i) or
			(exists $patterns{$$fserv{'type'}}{'sending file'} and 
			$message =~ /$patterns{$$fserv{'type'}}{'sending file'}/i)) { 
			print_dbg("File successfully queued", 3);
			if ($$fserv{'cfile'} != -1) {
				$$fserv{'files'}[$$fserv{'cfile'}]{'state'} = 3;
				$$fserv{'cfile'} = -1;
			}
			get_next_file($dcc->{'server'}, $nick);
			return;
		}
		if ((exists $patterns{$$fserv{'type'}}{'my slots full'} and 
			$message =~ /$patterns{$$fserv{'type'}}{'my slots full'}/i)) {
			print_dbg("Can't queue file, my slots full", 3);
			$$fserv{'cfile'} = -1;
			$$fserv{'state'} = 8;
			$dcc->{'server'}->command("MSG =$dcc->{nick} quit");
			return;
		}
		if ((exists $patterns{$$fserv{'type'}}{'all slots full'} and
			$message =~ /$patterns{$$fserv{'type'}}{'all slots full'}/i)) { 
			print_dbg("Can't queue file, all slots full", 3);
			$$fserv{'cfile'} = -1;
			$$fserv{'state'} = 0;
			$dcc->{'server'}->command("MSG =$dcc->{nick} quit");
			return;
		}
		if ((exists $patterns{$$fserv{'type'}}{'already queued'} and 
			$message =~ /$patterns{$$fserv{'type'}}{'already queued'}/i) or
			(exists $patterns{$$fserv{'type'}}{'already sending'} and 
			$message =~ /$patterns{$$fserv{'type'}}{'already sending'}/i)) { # the same as 'file queued'
			print_dbg("File has been already queued/sending", 3);
			if ($$fserv{'cfile'} != -1) {
				$$fserv{'files'}[$$fserv{'cfile'}]{'state'} = 3; # TODO : can it be that the file is in transfer?
				$$fserv{'cfile'} = -1;
			}
			get_next_file($dcc->{'server'}, $nick);
			return;
		}
		if (exists $patterns{$$fserv{'type'}}{'sending file'} and 
			$message =~ /$patterns{$$fserv{'type'}}{'sending file'}/i) { # the same as 'file queued'
			print_dbg("File is being send at once", 3);
			if ($$fserv{'cfile'} != -1) {
				$$fserv{'files'}[$$fserv{'cfile'}]{'state'} = 3;
				$$fserv{'cfile'} = -1;
			}
			get_next_file($dcc->{'server'}, $nick);
			return;
		}
	}
}

###
sub sig_no_such_nick {
	my ($server, $args, $sender_nick, $sender_address) = @_;
	my ($myself, $nick) = split(/ /, $args, 3);	
	print_dbg("no such nick '$nick' on '$server->{tag}'", 3);
	$nick = lc $nick;
	my $tag = $server->{'tag'};
	return if ((not exists $serv{$tag}) or (not exists $serv{$tag}{$nick})
		or ($serv{$tag}{$nick}{'state'} != 1));
	
	$serv{$tag}{$nick}{'state'} = 0;
	$serv{$tag}{$nick}{'lastaction'} = time();
	print_dbg("Changed state to 0", 3);
}

###
#
sub sig_nicklist_changed {
	my ($chan, $nick, $oldnick) = @_;
	print_dbg("Nick change on $chan->{server}{tag} from $oldnick to $nick->{nick}", 3);
	$nick = lc($nick->{'nick'});
	my $tag = $chan->{'server'}{'tag'};
	if ((exists $serv{$tag}) and
		(exists $serv{$tag}{$oldnick})) {
		print_dbg("Changing record for this nick", 3);
		my $record = delete $serv{$tag}{$oldnick};
		$serv{$tag}{$nick} = $record;
	}
}

###
# server tag, nick, filename
sub gets_exists($$$) {
	my ($tag, $nick, $file) = @_;
	foreach (Irssi::Irc::dccs()) {
		print_dbg("gets_exists: checking nick: '$_->{nick}', serv: '$_->{servertag}', type: '$_->{type}', arg: '$_->{arg}'", 4);
		return 1 if ($_->{'type'} eq 'GET' and $tag eq $_->{servertag}
			and $nick eq $_->{nick} and $file eq $_->{arg});
	}
	print_dbg("gets_exists: FOUND NO GETS", 3);
	return 0;
}

### 
# Tries to get next file, we must be connected to fserv
# server, nick
sub get_next_file($$) {
	my ($server, $nick) = @_;
	my $fserv = get_fserv($server->{tag}, $nick);
	my $fnumber = find_file_to_queue($server->{tag}, $nick);
	if ($fnumber == -1) {
		if (all_files_complete($server->{tag}, $nick)) {
			$$fserv{state} = 7;
			print_dbg("Leeching complete for nick $nick\@$server->{tag}", 2);
			$server->command("MSG =$nick quit");
			return;
		}
		# TODO : should wait a bit and see if the send comes
		$$fserv{state} = 6;
		print_dbg("Queued all files possibile", 3);
		$server->command("MSG =$nick quit");
		return;
	}
	
	print_dbg("Will try to get file number $fnumber", 3) 	
		if ($$fserv{state} != 4);
	
	if (change_dir($server->{tag}, $nick, $fnumber)) {
		print_dbg("We're in the dir where the file is", 4);
		
		$$fserv{state} = 5;
		my @arr = split ('/', $$fserv{files}[$fnumber]{name});
		$server->command("MSG =$nick get "
			.(pop @arr) );
		
		return;
	}
	return;		
}

###
# server tag, nick, file number
# Tries to change current directory on fserve to the one where the file is
# If it's in the dir returns true, if not yet returs false
sub change_dir($$$) {
	my ($tag, $nick, $fileno) = @_;
	my $fserv = get_fserv($tag, $nick);
	my $file = $$fserv{files}[$fileno];
	
	my $server = Irssi::server_find_tag($tag);
	if (!$server) {
		# TODO : must do sth more in this case
		print_dbg("Could not find server '$tag'", 3);
		return;
	}
	
	$$fserv{state} = 4;
	
	# simple case, file in root and we're in root
	return 1 if (@{$$fserv{path}} == 0 and $$file{depth} == 0); 

	# we are deeper than the file, we must go up for sure.
	if ($$file{depth} < @{$$fserv{path}}) { 
		print_dbg("change_dir: #5", 4);
		pop @{$$fserv{path}};
		$$fserv{lastaction} = time();
		$server->command("MSG =$nick cd ..");
		return 0;
	}

	my @fpath = split ('/', $$file{name}); pop @fpath; # has all dirs
	print_dbg("File we want to traverse is '@fpath'", 4);

	# we're in root dir, must cd to first dir for sure
	if (@{$$fserv{path}} == 0) { 
		print_dbg("change_dir: #10", 4);
		push (@{$$fserv{path}}, $fpath[0]);
		$$fserv{lastaction} = time();
		$server->command("MSG =$nick cd $fpath[0]");
		return 0;
	}

	my @path = @{$$fserv{path}}; # just to have thing easier
	while (@path) {
		print_dbg("change_dir: comparing '$fpath[0]' and '$path[0]'", 4);
		last if ($fpath[0] ne $path[0]); # go on as long as dirs are equal
		shift @fpath; shift @path;
		print_dbg("Current path='@path', fpath='@fpath'", 4);
	}
	if (@path == 0) { # so far we are on good path
		print_dbg("change_dir: #15", 4);
		return 1 if (@fpath == 0); # yup! no more dirs!
		
		print_dbg("change_dir: #20", 4);
		# must go deeper
		push (@{$$fserv{path}}, $fpath[0]);
		print_dbg("Going deeper, path='@path', fpath='@fpath'", 4);
		$$fserv{lastaction} = time();
		$server->command("MSG =$nick cd $fpath[0]");
		return 0;
	}
	
	print_dbg("change_dir: #25", 4);
	# dir is different - must go up
	pop @{$$fserv{path}};
	$$fserv{lastaction} = time();
	$server->command("MSG =$nick cd ..");
}

###
# Returns -1 if can't find it 
# server tag, nick
sub find_file_to_queue($$) {
	my ($tag, $nick) = @_;
	my $fserv = get_fserv($tag, $nick);
	
	return $$fserv{cfile} if ($$fserv{cfile} >= 0);
	
	my $fnumber = -1;
	foreach my $file (@{$$fserv{files}}) {
		$fnumber++;
		next unless ($$file{'state'} == 0);
		$$fserv{cfile} = $fnumber;
		return $fnumber;
	}
	return -1;
}

###
# server tag, nick
sub all_files_complete($$) {
	my ($tag, $nick) = @_;
	my $fserv = get_fserv($tag, $nick);
	foreach (@{$$fserv{files}}) {
		return 0 if ($$_{'state'} != 2); # FIXME : probably will have to be fixed when implemented missing files etc
	}
	return 1;
}

###
# server tag, nick
sub get_fserv($$) {
	my ($tag, $nick) = @_;
	return \%{$serv{$tag}{$nick}};
}

###
# server tag, nick, trigger
sub add_trigger ($$$) {
	my ($tag, $nick, $trigger) = @_;	
	$nick = lc $nick;
	my $fserv = get_fserv($tag,$nick);
	if (not exists $$fserv{trigger}) {
		@{$$fserv{path}} = ();
		$$fserv{state} = 0;
		$$fserv{type} = 'default';
		$$fserv{cfile} = -1;
		$$fserv{lastaction} = 0; # when was last action performed
		@{$$fserv{files}} = ();
	}
	$$fserv{trigger} = $trigger;
}

###
# server tag, nick, file
sub add_file ($$$) {
	my ($tag, $nick, $file) = @_;	
	$nick = lc $nick;
	my $fserv = get_fserv($tag,$nick);
	$file =~ s{^/}{}; 
	$file =~ s{/$}{};  
	my $depth = ($file =~ tr|/||); # counting number of slashes ...
	push (@{$$fserv{files}}, 
		{ 'name' => $file, 'state' => 0, 'depth' => $depth,
		'size' => -1});	
}

###
# server tag, nick
sub initiate_connection($$) {
	my ($tag, $nick) = @_;
	my $server = Irssi::server_find_tag($tag);
	if (!$server) {
		print_dbg("Could not find server '$tag'", 3);
		return;
	}
	my $fserv = get_fserv($tag,$nick);
	print_dbg("Initiating connection with $nick", 3);
	$$fserv{state} = 1;
	$$fserv{lastaction} = time();
	$server->command("CTCP $nick $$fserv{trigger}");
}

###
# server tag, nick
sub execute_next_command ($$) {
	my ($tag, $nick) = @_;
	
	my $fserv = get_fserv($tag,$nick);

	if ($$fserv{'state'} == 0 or $$fserv{'state'} == 6 or $$fserv{'state'} == 8) {
		initiate_connection($tag, $nick);
	}

	# if it's for example 'changing dir' don't wait for response but
	# execute next command (i.e. next cd or get)
}

###
#
sub time4check {
	my ($tag, $nick, $fserv);
	my $time = time();
	print_dbg("Time 4 check", 3);
	my $recheck = Irssi::settings_get_int('fleech_recheck_interval');
	my $conn_timeout = Irssi::settings_get_int('fleech_max_connecting_time');
	foreach $tag (keys %serv) {
		while (($nick, $fserv) = each %{$serv{$tag}}) { 
			next if ($$fserv{'lastaction'} == 0);
			$$fserv{'state'} = 0 
				if (($$fserv{'state'} == 1 or $$fserv{'state'} == 2) 
				and	($time > $$fserv{'lastaction'} + $conn_timeout));
			next if (($$fserv{'state'} != 0 and $$fserv{'state'} != 6 
				and $$fserv{'state'} != 8) or
				($time < $$fserv{'lastaction'} + $recheck) or
				(find_file_to_queue($tag, $nick) == -1));
				
			print_dbg ("Checking '$nick'\@'$tag'", 4);
			execute_next_command($tag, $nick);
		}
	}
}

###
# text[, level]
sub print_dbg {
	my ($txt, $mlvl) = @_;
	my $lvl = Irssi::settings_get_int('fleech_verbose_level');
if ($dbglog) {
	if (not open (DBGLOG, ">>", $dbglog)) {
		$dbglog = "";
	} else {
	#	print_dbg("fleech.pl $VERSION loaded");		
	print DBGLOG time() . " $txt\n" if ($dbglog);
	}
} 
	Irssi::print("$txt") if ($mlvl < $lvl);
}

###
# server tag, nick
sub list_nick ($$) {
	my ($s, $nick) = @_;
	my $fserv = get_fserv($s, $nick);
	print_dbg("Nick: '$nick'");
	print_dbg("  type   : '$$fserv{type}'");
	print_dbg("  trigger: '$$fserv{trigger}'");
	print_dbg("  state  : '$$fserv{state}' "
		."($states{$$fserv{state}})");
	print_dbg("  cfile  : '$$fserv{cfile}'", 2);
	print_dbg("  path   : '@{$$fserv{path}}'", 2);
	print_dbg("  lastaction: '$$fserv{lastaction}'", 2);
	print_dbg("  files  :");
	my $fn = 0;
	foreach my $file (@{$$fserv{files}}) {
		print_dbg("    $fn)", 1); $fn++;
		print_dbg("    name : '$$file{name}'");
		print_dbg("    depth: '$$file{depth}'", 2);
		print_dbg("    size : '$$file{size}'", 1);
		print_dbg("    state: '$$file{state}' ($fstates{$$file{state}})");
	}
}
#############################
# take a string and expand it to an array of strings by substituting {00x,y} with 00x,00x+1,..,y
# \{ is substituted with { and \\ with \ so \{->{ and \\{->\{
sub expand_str($){
    my ($str)=@_;
    #print Dumper($str);
    $str=~s/\%/\%\%/g;
    my $from=0;
    my $to=0;
    my $zeros='';
    if($str=~s/(^|[^\\])((\\\\)*)(\{(\d+),(\d+)\})/$1$2\%s/){
 #print "matched\n";
 $from=$5;
 $to=$6;
 $zeros=$from;
 if($from=~/^0/){
     $zeros='0'.length($from);
 }else{
     $zeros='';
 }
    }
    $str=~s/\\\{/\{/g;
    $str=~s/\\\\/\\/g;
    #print Dumper($str);#" $str $from,$to\n";
    my $toret=[];
    for(my $i=$from;$i<=$to;$i++){
 push @$toret,sprintf($str,sprintf('%'.$zeros.'d',$i));
    }
    return $toret;
}

###
# /fleech add nick trigger /ctcp nick dupa
# /fleech add nick file /dir/file
sub cmd_fleech {
	my ($data, $server, $channel) = @_;

	my ($command, $nick, $rest) = split (" ", $data, 3);
	$_ = $command;
	if (/^list/) {
		foreach my $s (keys %serv) {
			print_dbg("Server '$s'");
			foreach my $nick (keys %{$serv{$s}}) {
				list_nick($s, $nick);
			}
		}
		return;
	}
	if (/^add/) {
		my ($type, $command) = split (" ", $rest, 2);	
		print_dbg("Adding type '$type' for '$nick' on '$server->{tag}': '$command'", 4);
		if ($type eq 'trigger') {
			add_trigger($server->{tag}, $nick, $command);
			return;
		}
		if ($type eq 'file') {
			if (not exists $serv{$server->{'tag'}} or 
				not exists $serv{$server->{'tag'}}{lc($nick)}) {
				print_dbg("No such server or nick record");
				return;
			}
			add_file($server->{tag}, $nick, $command);
   return;
  }
  if ($type eq 'rfile') {
   if (not exists $serv{$server->{'tag'}} or 
    not exists $serv{$server->{'tag'}}{lc($nick)}) {
    print_dbg("No such server or nick record");
    return;
   }
   my $papasv_list=expand_str($command);
   my $papasv_item;
   foreach $papasv_item (@$papasv_list){
    #Irssi::print($papasv_item);
    add_file($server->{tag}, $nick, $papasv_item);
   }
			return;
		}
		print_dbg("Unknown type '$type'");
		return;
	}
	if (/^del/) {
	}
	if (/^set/) { 
		# set nick field value
		# or in case of field == file:
		# set nick file number field value
		# or in case of field == nick:
		# set nick nick newnick 
		# For example:
		# /fleech set somenick type sysreset
		# /fleech set somenick file 2 state complete
		# /fleech set somenick nick newnick
		my ($field, $rest) = split (" ", $rest, 2);
		if (not exists $serv{$server->{'tag'}} or 
			not exists $serv{$server->{'tag'}}{lc($nick)}) {
			print_dbg("No such server or nick record");
			return;
		}
		if ($field eq 'files') {
			my ($fn, $field, $rest) = split (" ", $rest, 3);
			$serv{$server->{'tag'}}{lc($nick)}{'files'}[$fn]{$field} = $rest;
			return;
		} elsif ($field eq 'nick') {
			if ((exists $serv{$server->{'tag'}}) and
				(exists $serv{$server->{'tag'}}{lc($nick)})) {
				my $record = delete $serv{$server->{'tag'}}{lc($nick)};
				$serv{$server->{'tag'}}{lc($rest)} = $record;
				return;
			}
			Irssi::print("No such server or nick");
			return;
		}	
		$serv{$server->{'tag'}}{lc($nick)}{$field} = $rest;
		return; 
	}
	if (/^go/) {
		foreach my $s (keys %serv) {
			foreach my $n (keys %{$serv{$s}}) {
				if ($serv{$s}{$n}{state} == 0) {
					execute_next_command($s, $n);
				}
			}
		}
		return;
	}
	if (/^clrc/) {
		my $fc = 0;
		foreach my $s (keys %serv) {
			foreach my $n (keys %{$serv{$s}}) {
				my $f = scalar @{$serv{$s}{$n}{'files'}};
				while (--$f >= 0) {
					if ($serv{$s}{$n}{'files'}[$f]{'state'} == 2) {
						print_dbg("Removing from $n '"
							."$serv{$s}{$n}{files}[$f]{name}'", 1);
						splice @{$serv{$s}{$n}{'files'}}, $f, 1;
						$fc++;
					}
				}
				@{$serv{$s}{$n}{'files'}} = () if (not @{$serv{$s}{$n}{'files'}});
			}
		}
		print_dbg("Removed $fc file(s)") if ($fc);
		return;
	}

}

# FIXME: which one of signal_add{,_first,_last} use?
Irssi::signal_add_last('nicklist changed', 'sig_nicklist_changed');
Irssi::signal_add_last('dcc request', 'sig_dcc_request');
Irssi::signal_add_last('dcc connected', 'sig_dcc_connected');
Irssi::signal_add_last('dcc destroyed', 'sig_dcc_destroyed');
Irssi::signal_add_last('dcc chat message', 'sig_dcc_chat_message');
Irssi::signal_add("event 401", "sig_no_such_nick");

 
Irssi::command_bind('fleech', 'cmd_fleech');		

Irssi::settings_add_int($IRSSI{'name'}, 'fleech_verbose_level', 1); # 0 - no messages at all, 1 - std messages, 2 - more verbose, 3 - even more verbose, 4 - debug messages
Irssi::settings_add_int($IRSSI{'name'}, 'fleech_recheck_interval', 60*30); # check if can queue more files every this seconds 
Irssi::settings_add_int($IRSSI{'name'}, 'fleech_max_connecting_time', 60*5); # if fserv in state 1 or 2 more than this seconds, reset it to state 0
Irssi::settings_add_int($IRSSI{'name'}, 'fleech_timeout', 60); # functions that checks timeouts etc is called every this seconds

my $ttag = Irssi::timeout_add(1000*Irssi::settings_get_int('fleech_timeout'), "time4check", undef);
	


# vim:ts=4:noexpandtab
