# xdcc autoget, to automate searching and downloading xdcc packs from xdcc bots based on chosen search strings
# 
# long description: You add a bunch of xdcc bots and search terms, as well as an optional format string (for TV shows that have multiple releases or formats (basically gets appended to the end of a search after the episode #)).
#                   The script will go through each bot simultaneously, and download any packs it finds that matches. 
#                   It stores the name and bot and pack number of each downloaded file to avoid redownloading, and incorporates automated (and sane default) timeouts to avoid flooding bots (and getting ignored/muted/kicked/banned).
#                   There is also a statusbar that you can add.
#                   It used to give a lot of detailed information on what was happening, but since the program now does all bots simultaneously it would be a clusterfuck, so now it gives only basic info on whether autoget is running.
# 
# requires that you enable dcc_autoget and dcc_autoresume. Also requires File::Dir and Try::Tiny which can be installed with the command >>> sudo perl -MCPAN -e 'install "File::HomeDir"' && sudo perl -MCPAN -e 'install "Try::Tiny"'
# made because torrents are watched by the feds, but xdcc lacks an RSS feed equivalent.
# if you encounter any problems, fix it yourself you lazy bastard (or get me to), then contact me so I can add your fix and bump that version #
# 
# BeerWare License. Use any part you want, but buy me a beer if you ever meet me and liked this hacked together broken PoS
# Somewhat based off of DCC multiget by Kaveh Moini.
# 
# USE: to add the statusbar : /statusbar [name] add ag_statusbar
#      for help             : ag_help
#      to run               : ag_run
#      to halt at next      : ag_stop
#      to reset all settings: ag_reset
#      to set the server    : ag_server 
#      to add a bot         : ag_botadd BOT1 BOT2 *** BOTN
#      to remove a bot      : ag_botrem BOT1 BOT2 *** BOTN
#      to add string        : ag_add "[TEXT STRING OF TV SHOW/CHINESE CARTOON/ETC]","[ETC]",***,"[ETC]" 
#      to remove strings    : ag_rem "[TEXT STRING OF TV SHOW/CHINESE CARTOON/ETC]","[ETC]",***,"[ETC]" 
#      to see terms and bots: ag_list
#      to clear     cache   : ag_clearcache
#      ag_next_delay                 : delay between full transfers
#      ag_dcc_closed_retry_delay     : delay after premature transfer
#      ag_bot_delay: delay between request and when you "SHOULD" get it
#      ag_interrun_delay             : delay (in minutes, the rest seconds) between finishing a round and starting another
#      ag_autorun                    : whether to run on startup
#      ag_xdcc_send_prefix           : the xdcc message before the pack #
#      ag_xdcc_find_prefix           : the xdcc message before the search term
#      ag_bot_file                   : where your bot list is stored
#      ag_search_file                : where your search list is stored

use strict;
use warnings;

use Irssi 20090331;
use Irssi;
use Irssi::TextUI;
use Text::ParseWords;
use autodie; 		# die if problem reading or writing a file
use File::HomeDir;
use File::Copy;
use Try::Tiny;
use vars qw($VERSION %IRSSI);

$VERSION = 2.0;
%IRSSI = (
	name => "autoget", 
	description => "XDCC Autoget, for automated searching and downloading of xdcc packs",
	license => "BeerWare Version 42",
	changed => "$VERSION",
	authors => "MarshalMeatball",
	contact => "mobilegundamseed\@hotmail.com",
);

Irssi::settings_add_int($IRSSI{'name'}, "ag_next_delay", 10);
Irssi::settings_add_int($IRSSI{'name'}, "ag_dcc_closed_retry_delay", 10);
Irssi::settings_add_int($IRSSI{'name'}, "ag_bot_delay", 30);
Irssi::settings_add_int($IRSSI{'name'}, "ag_interrun_delay", 2);
Irssi::settings_add_bool($IRSSI{'name'}, "ag_autorun", 1);
Irssi::settings_add_bool($IRSSI{'name'}, "ag_episodic", 0);
Irssi::settings_add_str($IRSSI{'name'}, "ag_xdcc_send_prefix", "xdcc send");
Irssi::settings_add_str($IRSSI{'name'}, "ag_xdcc_cancel_prefix", "xdcc cancel");
Irssi::settings_add_str($IRSSI{'name'}, "ag_find_prefix", "!find");
Irssi::settings_add_str($IRSSI{'name'}, "ag_format", "");
Irssi::settings_add_str($IRSSI{'name'}, "ag_folder", File::HomeDir->my_home);

my @totags = ();	#timeout tags (need to be purged between send requests maybe)

my $nexdelay;		#delay for next pack
my $dcrdelay;		#delay if transfer closed prematurely
my $botdelay;		#max time to wait for the bot to respond
my $exedelay;		#delay (in minutes) between finishing one run and starting another

my $initflag;			#flag controls whether AG starts on IRSSI boot (if in autorun), or on LOAD
my $runningflag = 0;		#flag keeps ag from running more than one instance of itself at a time
my @msgflag = ();		#flag controls whether bot has responded to search request
my @getmsgflag = ();		#flag keeps track of getmsg signals
my $episodicflag;		#flag controls whether to search episode by episode (eg instead of searching boku no pice, it'll search for boku no pico 1, then boku no pico 2, etc as long as results show up)
my @formatflag = ();		#flag controls whether a format is appended to the end of an episodic search string
my @reqpackflag = ();		#flag to avoid multiple download requests
my @downloadflag = ();		#flag to avoid multiple download requests

my $sendprefix;		#virtually universal xdcc send, cancel, and find prefixes
my $cancelprefix;
my $findprefix;
my $format;			#format option for episodic. Can be edited if you want a certain size, eg 720p; x264; aXXo; etc
my $folder;

&ag_setsettings;

my $botsfilename = $folder . "/bots.txt";
my $searchesfilename = $folder . "/searches.txt";
my $cachefilename = $folder . "/cache.txt";

my $dccflag = 0;	#flag so that dccs aren't mistakenly thought of belonging to AG

my @terms;		#lists of search terms, bots, and pack numbers (for current bot only)
my @bots;
my @packs;
my @finished;		#list of packs already downloaded and their filenames
my @filenames;		#list of filenames of files currently being downloaded
my $statusbarmessage = "No connection";

my @termcounter = ();	#counters for array position
my @packcounter = ();
my @episode = ();

my $server;		#current server

sub ag_init		#init system
{
	Irssi::print "AG | Autoget V$VERSION initiated";
	Irssi::print "AG | /ag_help for help";
	&ag_list;
	if ($episodicflag)
	{
		Irssi::print "AG | Episodic: Yes";
		Irssi::print "AG | Preffered format: $format";
	}
	else {Irssi::print "AG | Episodic: No";}
	Irssi::print "AG | Data folder: $folder";
}

sub ag_list
{
	&ag_getbots;
	my $m = "";
	foreach my $n (@bots)
	{
		$m = $m . $n . ", ";
	}
	Irssi::print "AG | Bots: " . $m;
	$m = "";
	&ag_getterms;
	foreach my $n (@terms)
	{
		$m = $m . $n . ", ";
	}
	Irssi::print "AG | Terms: " . $m;

}

sub ag_initserver	#init server
{
	Irssi::signal_remove("server connected", "ag_server");
	$statusbarmessage = "Connected";
	$server = $_[0];
	if (!$runningflag) {Irssi::timeout_add_once(5000, sub { &ag_run; }, []);}
	else {Irssi::timeout_add_once(5000, sub { $statusbarmessage = "Inactive"; }, []);}
}

sub ag_server	#init server
{
	$server = Irssi::active_server();
}

sub ag_help
{
	Irssi::print "to add the statusbar : /statusbar [name] add ag_statusbar";
	Irssi::print "for this help        : ag_help";
	Irssi::print "to run               : ag_run";
	Irssi::print "to halt at next      : ag_stop";
	Irssi::print "to reset all settings: ag_reset";
	Irssi::print "to set the server    : ag_server";
	Irssi::print "to add a bot         : ag_botadd BOT1 BOT2 *** BOTN";
	Irssi::print "to remove a bot      : ag_botrem BOT1 BOT2 *** BOTN";
	Irssi::print "to add string        : ag_add \"[TEXT STRING OF SEARCH]\",\"[ETC]\",***,\"[ETC]\"";
	Irssi::print "to remove strings    : ag_rem \"[TEXT STRING OF SEARCH]\",\"[ETC]\",***,\"[ETC]\"";
	Irssi::print "to see terms and bots: ag_list";
	Irssi::print "to clear cache       : ag_clearcache";
	Irssi::print "ag_next_delay            : delay between full transfers";
	Irssi::print "ag_dcc_closed_retry_delay: delay after premature transfer";
	Irssi::print "ag_bot_delay             : max time to wait for the bot to respond";
	Irssi::print "ag_interrun_delay        : delay (in minutes, the rest seconds) between finishing a round and starting another";
	Irssi::print "ag_autorun               : whether to run on startup";
	Irssi::print "ag_episodic              : search ep 1, if found then search ep 2. Use for series if bot limits search results. Results may vary depending on bot and search term";
	Irssi::print "ag_xdcc_send_prefix      : the xdcc message before the pack #";
	Irssi::print "ag_xdcc_cancel_prefix    : the xdcc message to cancel a transfer";
	Irssi::print "ag_xdcc_find_prefix      : the xdcc message before the search term";
	Irssi::print "ag_format                : universal string appended to the end of each search in episodic. Use if more than one format exists";
	Irssi::print "ag_folder                : Location for data files. ~/.irssi/ reccomended";
}

sub ag_getbots		#reads in bot list
{
	open(BOTS, "<", $botsfilename);
	@bots = <BOTS>;
	chomp(@bots);
	close(BOTS);
}

sub ag_getterms		#reads in search term list
{
	open(SEARCHES, "<", $searchesfilename);
	@terms = <SEARCHES>;
	chomp(@terms);
	close(SEARCHES);
}

sub ag_getfinished		#reads in finished packs list
{
	open(FINISHED, "<", $cachefilename);
	@finished = <FINISHED>;
	chomp(@finished);
	@finished = ag_uniq(@finished);
	close(FINISHED);
}

sub ag_clearcache		#clears cache of saved packs
{
	unlink $cachefilename;
	open(FINISHED, ">>", $cachefilename);
	close(FINISHED);
}

sub ag_search		#searches bots for packs
{
	(my $botcounter) = $_[0];
	$msgflag[$botcounter] = 0;	#unset message flag so that ag_skip knows no important message has arrived
	if($episodicflag)	#episodic searches are complicated
	{
		my $ep = sprintf("%.2d", $episode[$botcounter]);
		if ($format ne "" and $formatflag[$botcounter])
		{
			ag_message("msg $bots[$botcounter] $findprefix $terms[$termcounter[$botcounter]] $ep $format");	#first search with format
			if ($episode[$botcounter] == 1)	#if no formated version found, try again with just the search string + ep#
			{
 				push(@{$totags[$botcounter]}, Irssi::timeout_add_once($botdelay * 1000, sub { $formatflag[$botcounter] = 0; &ag_search($botcounter); } , []));
 			}
			else
			{
 				push(@{$totags[$botcounter]}, Irssi::timeout_add_once($botdelay * 1000, sub { &ag_skip($botcounter); } , []));	
			}
		}
		else
		{
			ag_message("msg $bots[$botcounter] $findprefix $terms[$termcounter[$botcounter]] $ep" );
 			push(@{$totags[$botcounter]}, Irssi::timeout_add_once($botdelay * 1000, sub { &ag_skip($botcounter); } , []));
		}
	}
	else		#if not episodic, just search and skip
	{
		ag_message("msg $bots[$botcounter] $findprefix $terms[$termcounter[$botcounter]]" );
		push(@{$totags[$botcounter]}, Irssi::timeout_add_once($botdelay * 1000, sub { &ag_skip($botcounter); } , []));
	}
}

sub ag_remtimeouts	#remove timeouts to avoid multiple instances of everything
{
	my($botcounter) = @_;
	foreach my $to (@{$totags[$botcounter]})	#remove timeouts and clear array
	{
		Irssi::timeout_remove($to);
	}
	$totags[$botcounter] = ();
}

sub ag_getmsg		#runs when bot sends privmsg. Avoid talking to bots to keep this from sending useless shit that breaks things
{	
	my $message = $_[1];
	my $botname = $_[2];
	$botname =~ tr/[A-Z]/[a-z]/;
	
	my $botcounter = 0;
	foreach my $bot (@bots)
	{
		$bot =~ tr/[A-Z]/[a-z]/;
		if ($botname eq $bots[$botcounter])	#if it's your bot
		{
			&ag_remtimeouts($botcounter);	#stop any skips from happening
			ag_getpacks($message, $botcounter);	#and check for any new packs in the message
			my @packlist = @{$packs[$botcounter]};
			if ($#packlist < 0 and !$msgflag[$botcounter])	#set up only one possible skip per search
			{
				my $temp = $botcounter;
				push(@{$totags[$botcounter]}, Irssi::timeout_add_once($nexdelay * 1000, sub { &ag_skip($temp); } , []));
			}
			if($#packlist >= 0){ &ag_packrequest($botcounter); }	#if there are any packs,
			$msgflag[$botcounter] = 1;		#let everyone know that the current bot has replied
		}
		$botcounter++;
	}
}

sub ag_getpacks
{
	my($message, $botcounter) = @_;
	my @temp = split(' ', $message);	#split up the message into 'words'
	&ag_getfinished;
	
	my $newpackflag = 1;
	foreach my $m (@temp)		#find packs (#[NUMBER]: format)
	{ 
		if ($m =~ m{#(\d+):})
		{
			foreach my $n (@finished)		#don't redownload finished packs
			{
				if ($n eq "$bots[$botcounter] $1") {$newpackflag = 0;}
				last if ($n eq "$bots[$botcounter] $1");
			}
			if($newpackflag){push(@{$packs[$botcounter]}, $1);}	#push all new pack numbers to list of packs
		}
	}
	@{$packs[$botcounter]} = ag_uniq(@{$packs[$botcounter]});	#remove duplicates
}

sub ag_packrequest	#sends the xdcc send request, and retries on failure
{
	my($botcounter) = @_;
	&ag_remtimeouts($botcounter);
	if (!$reqpackflag[$botcounter])
	{
		$reqpackflag[$botcounter] = 1;
		ag_message("msg $bots[$botcounter] $sendprefix $packs[$botcounter][$packcounter[$botcounter]]");
		push(@{$totags[$botcounter]}, Irssi::timeout_add_once($botdelay * 1000, sub { if (!$downloadflag[$botcounter]) { &ag_packrequest($botcounter); } } , []));
	}
}

sub ag_opendcc	#runs on DCC recieve init
{
	&Irssi::signal_continue;
	my ($gdcc) = @_;	#current pack
	my $botname = $gdcc->{'nick'};
	my $filename = $gdcc->{'arg'};
	my $filedownloadflag = 0;
	$botname =~ tr/[A-Z]/[a-z]/;

	foreach my $file (@filenames)
	{
		if ($file eq $filename) {$filedownloadflag = 1;}
	}

	my $botcounter = 0;	
	foreach my $bot (@bots)
	{
		$bot =~ tr/[A-Z]/[a-z]/;
		if ($botname eq $bot and !$filedownloadflag)	#if it's our bot and the file is not already being downloaded, let user know, and stop any further AG pack requests until finished
		{
			$getmsgflag[$botcounter] = 0;
	
			&ag_remtimeouts($botcounter);
			$dccflag = 0;
			$downloadflag[$botcounter] = 1;
			foreach my $n (@finished)		#don't redownload finished packs
			{
				if ($n eq $gdcc->{'arg'})	#if file already downloaded, cancel
				{
					Irssi::signal_remove("dcc destroyed", "ag_closedcc");
					$gdcc->close;
					$gdcc->{'skipped'} = $gdcc->{'size'};
					$gdcc->{'transfd'} = $gdcc->{'size'};
					ag_closedcc($gdcc);				
					Irssi::signal_add("dcc destroyed", "ag_closedcc");
				}
				last if ($n eq $gdcc->{'arg'});
			}
			push(@filenames, $filename);
		}
		elsif ($botname eq $bot and $filedownloadflag)
		{
			Irssi::signal_remove("dcc destroyed", "ag_closedcc");
			Irssi::signal_add("dcc destroyed", "ag_dummyclosedcc");
			ag_message("msg $bots[$botcounter] $cancelprefix");
			$gdcc->close;
			ag_skip($botcounter);			
		}
		$botcounter++;
	}
}

sub ag_skip
{
	my($botcounter) = @_;
	my @packlist = ();
	try {my @packlist = @{$packs[$botcounter]} or die;}	#workaround for @{} being dumb if an array inside of an array is empty 
	catch {};
	#Irssi::print "ag_skip $msgflag $episodicflag $episode $#packs $packcounter $#terms $termcounter $#bots $botcounter"; 
	&ag_remtimeouts($botcounter);	#stop any other skips
	$reqpackflag[$botcounter] = 0;		#allow pack requests now that transfer is finished
	if($episodicflag)
	{
		$packs[$botcounter] = ();		#delete and reset packlist
		$packcounter[$botcounter] = 0;
		
		if ($msgflag[$botcounter])	#if the bot replied, then that means there were episodes, but we already have them
		{
			$episode[$botcounter]++;
			&ag_search($botcounter);
		}
		elsif ($termcounter[$botcounter] < $#terms)	#otherwise just increment terms
		{
			$episode[$botcounter] = 1;
			$formatflag[$botcounter] = 1;
			$termcounter[$botcounter]++;
			$packcounter[$botcounter] = 0;
			&ag_search($botcounter);
		}
		else	#if last episode on last search on last term finished, then resets counters and starts over
		{
			$episode[$botcounter] = 1;
			$formatflag[$botcounter] = 1;
			$termcounter[$botcounter] = 0;
			$packcounter[$botcounter] = 0;
			push(@{$totags[$botcounter]}, Irssi::timeout_add_once($exedelay * 1000 * 60, sub { &ag_search($botcounter); } , []));
			$runningflag = 0;
		}
	}
	elsif ($packcounter[$botcounter] < $#packlist)
	{
		$packcounter[$botcounter]++;
		&ag_search($botcounter);
	}
	elsif ($termcounter[$botcounter] < $#terms)
	{
		$packs[$botcounter] = ();		#delete last terms packlist
		$termcounter[$botcounter]++;
		$packcounter[$botcounter] = 0;
		&ag_search($botcounter);
	}
	else	#if last pack on last search on last term finished, then resets counters and starts over
	{
		$episode[$botcounter] = 1;
		$formatflag[$botcounter] = 1;
		$packs[$botcounter] = ();		#delete last bots packlist
		$termcounter[$botcounter] = 0;
		$packcounter[$botcounter] = 0;
		push(@{$totags[$botcounter]}, Irssi::timeout_add_once($exedelay * 1000 * 60, sub { &ag_search($botcounter); } , []));
		$runningflag = 0;
	}
}

sub ag_dummyclosedcc
{
	Irssi::signal_remove("dcc destroyed", "ag_dummyclosedcc");
	Irssi::signal_add("dcc destroyed", "ag_closedcc");
}

sub ag_closedcc
{
	my ($dcc) = @_;	#current pack
	my $botname = $dcc->{'nick'};	#get the bots name, and checks if it's the one we want
	my $filename = $dcc->{'arg'};
	$botname =~ tr/[A-Z]/[a-z]/;

	my $botcounter = 0;
	foreach my $bot (@bots)
	{
		$bot =~ tr/[A-Z]/[a-z]/;

		if ($botname eq $bot and $reqpackflag[$botcounter])	#checks if the is the bot
		{ 
			my $temp = $botcounter;
			my @packlist = $packs[$botcounter];
			my @termlist = $terms[$botcounter];

			@filenames = grep { $_ ne $filename } @filenames;			#remove the file from the list of files being transferred
			$reqpackflag[$botcounter] = 0;
	#		if ($dccflag == 0) {Irssi::signal_add("dcc request", "ag_opendcc");}	#if so, reinits DCC get signal for the next pack
			$dccflag = 1;
			
			&ag_remtimeouts($botcounter);
					
			if ($dcc->{'skipped'} == $dcc->{'size'})
			{
				ag_message("msg $bots[$botcounter] $cancelprefix");		#workaround because IRSSI doesn't actually 'get' packs if they're already downloaded, causing long stalls if left unattended.
			}
			if ($dcc->{'transfd'} == $dcc->{'size'})
			{
				ag_addfinished($dcc->{'arg'}, $botcounter);

				if($episodicflag)
				{
					if ($packcounter[$botcounter] < $#packlist)
					{
						$packcounter[$botcounter]++;
						push(@{$totags[$botcounter]}, Irssi::timeout_add_once($nexdelay * 1000, sub { &packrequest($temp); }, []));
					}
					else
					{
						$packs[$botcounter] = ();		#delete packlist
						$packcounter[$botcounter] = 0;
						$episode[$botcounter]++;
						push(@{$totags[$botcounter]}, Irssi::timeout_add_once($nexdelay * 1000, sub { &ag_search($temp); }, []));
					}
				}
				else
				{
					if ($packcounter[$botcounter] < $#packlist)
					{
						$packcounter[$botcounter]++;
						push(@{$totags[$botcounter]}, Irssi::timeout_add_once($nexdelay * 1000, sub { &ag_search($temp); }, []));
					}
					elsif ($termcounter[$botcounter] < $#termlist)
					{
						$packs[$botcounter] = ();		#delete last terms packlist
						$termcounter[$botcounter]++;
						$packcounter[$botcounter] = 0;
						push(@{$totags[$botcounter]}, Irssi::timeout_add_once($nexdelay * 1000, sub { &ag_search($temp); }, []));
					}
					else	#if last pack on last search on last bot finished, then resets counters and starts over
					{
						$packs[$botcounter] = ();
						$termcounter[$botcounter] = 0;
						$packcounter[$botcounter] = 0;
						push(@{$totags[$botcounter]}, Irssi::timeout_add_once($exedelay * 1000 * 60, sub { &ag_search($botcounter); } , []));
						$runningflag = 0;
					}
				}
			}
			else
			{
				push(@{$totags[$botcounter]}, Irssi::timeout_add_once($dcrdelay * 1000, sub { &ag_packrequest($temp); }, []));
			}
		}
		$botcounter++;
	}
}
	
sub ag_message
{
	(my $message) = $_[0];
	$server->command("$message");
}

sub ag_uniq		#only returns unique entries
{
	my %seen;
	grep !$seen{$_}++, @_;
}

sub ag_bar		#prints the message to the statusbar
{
	my ($item, $get_size_only) = @_;
	$item->default_handler($get_size_only, "{sb %_AG:%_ $statusbarmessage}", "", 1);
}


sub ag_addfinished		#save finished downloads
{
	my ($filename, $botcounter) = @_;
	open(FINISHED, ">>", $cachefilename);
	print FINISHED $bots[$botcounter] . " " . $packs[$botcounter][$packcounter[$botcounter]] . "\n";		#print pack to file	
	print FINISHED $filename . "\n";		#print name to file	
	close(FINISHED);	
}


sub ag_parseadd		#parses add arguments for storage
{
	my ($file, @args) = @_;
	my @temp;
	my @fil;
	foreach my $arg (@args)
	{
		push (@temp, $arg); 
	}
	open(FILE, "<", $file);
	@fil = <FILE>;
	chomp(@fil);
	unlink "$file";
	open(FILE, ">", $file);
	push(@fil, @temp);
	my %hTmp;
	foreach my $sLine (@fil)		#remove duplicate lines
	{
		next if $sLine =~ m/^\s*$/;  #remove empty lines. Without this, still destroys empty lines except for the first one.
		$sLine=~s/^\s+//;            #strip leading/trailing whitespace
		$sLine=~s/\s+$//;
		print FILE qq{$sLine\n} unless ($hTmp{$sLine}++);
	}
	close(FILE);
	&ag_getbots;
	&ag_getterms;
}

sub ag_parserem		#parses remove arguments for deletion from file
{
	my ($file, @args) = @_;
	my @temp;
	my @temp2;
	my @fil;
	foreach my $arg (@args)
	{
		push (@temp, $arg); 
	}
	open(FILE, "<", $file);
	@fil = <FILE>;
	chomp(@fil);
	my %hTmp;
	foreach my $fileLine (@fil)		#get each entry already stored
	{
		foreach my $tempLine (@temp)
		{
			if ($fileLine eq $tempLine)	#if entry in file and arguments
			{
				$hTmp{$fileLine}++;	#set flag to not copy
			}
			push(@temp2, qq{$fileLine}) unless $hTmp{$fileLine};	#copy other lines to other temp file
		}
	}
	@fil = @temp2;	#rewrite old file
	unlink "$file";
	open(FILE, ">", $file);
	%hTmp = ();
	foreach my $sLine (@fil)		#remove duplicate lines
	{
		next if $sLine =~ m/^\s*$/;  #remove empty lines. Without this, still destroys empty lines except for the first one.
		$sLine=~s/^\s+//;            #strip leading/trailing whitespace
		$sLine=~s/\s+$//;
		print FILE qq{$sLine\n} unless ($hTmp{$sLine}++);
	}
	close(FILE);
}

sub ag_add	#add search terms
{
	&ag_server;
	my @args = quotewords('\s+', 0, $_[0]);	#split arguments (words in brackets not seperated)
	if ($#args < 0)
	{
		Irssi::print "AG | too few arguments";
		Irssi::print "AG | usage: ag_add <search terms>";
		return;
	}
	ag_parseadd($searchesfilename, @args);
	&ag_list;
}

sub ag_rem	#remove ssearch terms
{
	&ag_server;
	my @args = quotewords('\s+', 0, $_[0]);
	if ($#args < 0)
	{
		Irssi::print "AG | too few arguments";
		Irssi::print "AG | usage: ag_rem <search terms>";
		return;
	}
	ag_parserem($searchesfilename, @args);
	&ag_list;
}

sub ag_botadd	#add bots
{
	&ag_server;
	my @args = quotewords('\s+', 0, $_[0]);
	if ($#args < 0)
	{
		Irssi::print "AG | too few arguments";
		Irssi::print "AG | usage: ag_botsadd <bots>";
		return;
	}
	ag_parseadd($botsfilename, @args);
	&ag_list;
}

sub ag_botrem	#remove bots
{
	&ag_server;
	my @args = quotewords('\s+', 0, $_[0]);
	if ($#args < 0)
	{
		Irssi::print "AG | too few arguments";
		Irssi::print "AG | usage: ag_rem <search terms>";
		return;
	}
	ag_parserem($botsfilename, @args);
	&ag_list;
}

sub ag_run	#main loop
{
	Irssi::signal_add("dcc request", "ag_opendcc");		#init DCC recieve init flag
	Irssi::signal_add("message irc notice", "ag_getmsg");
	if (!$initflag) {ag_server(Irssi::active_server());}
	if($runningflag == 0)
	{
		$runningflag = 1;
		&ag_getbots;
		&ag_getterms;
				
		if($#bots < 0 or $#terms < 0) {	$statusbarmessage = "No bots or no search terms."; Irssi::timeout_add_once(1000, sub { &ag_run; }, []);}
		else 
		{
			$statusbarmessage = "Active";
			my $botcounter = 0;
			foreach my $bot (@bots)
			{
				$totags[$botcounter] = ();
				$msgflag[$botcounter] = 1;			#flag controls whether bot has responded to search request
				$getmsgflag[$botcounter] = 0;		#flag keeps track of getmsg signals
				$formatflag[$botcounter] = 1;		#flag controls whether a format is appended to the end of an episodic search string
				$reqpackflag[$botcounter] = 0;		#flag to avoid multiple download requests
				$downloadflag[$botcounter] = 0;		#flag to avoid multiple download requests
				$termcounter[$botcounter] = 0;
				$packcounter[$botcounter] = 0;
				$episode[$botcounter] = 1;
				$packs[$botcounter] = ();
				&ag_search($botcounter);
				$botcounter++;
			}
		}
	}
}

sub ag_stop
{
	Irssi::signal_remove("dcc request", "ag_opendcc");
	Irssi::signal_remove("message irc notice", "ag_getmsg");
	
	my $botcounter = 0;
	foreach my $bot (@bots)
	{
		&ag_remtimeouts($botcounter);	#stop any skips from happening
		ag_message("msg $bot $cancelprefix");
		$getmsgflag[$botcounter] = 0;
		$botcounter++;
		@msgflag = ();
		@formatflag = ();
		@reqpackflag = ();
		@downloadflag = ();
		@termcounter = ();
		@packcounter = ();
		@episode = ();
	}

	if($runningflag == 1)
	{
		$runningflag = 0;
		$statusbarmessage = "Inactive";
	}
	$dccflag = 0;
	@terms = ();
	@bots = ();
	@packs = ();
	@finished = ();
	$botcounter = 0;	
}

sub ag_restart
{
	$statusbarmessage = "Inactive";
	Irssi::signal_remove("dcc request", "ag_opendcc");
	Irssi::signal_remove("message irc notice", "ag_getmsg");
	
	my $botcounter = 0;
	foreach my $bot (@bots)
	{
		$getmsgflag[$botcounter] = 0;
		&ag_remtimeouts($botcounter);
		ag_message("msg $bot $cancelprefix");
		$botcounter++;
	}

	if($runningflag == 1)
	{
		$runningflag = 0;
	}
	@msgflag = ();
	@formatflag = ();
	@reqpackflag = ();
	@downloadflag = ();
	$dccflag = 0;
	Irssi::signal_add("server connected", "ag_initserver");
}
sub ag_reset
{
	Irssi::settings_set_int("ag_next_delay", 10);
	Irssi::settings_set_int("ag_dcc_closed_retry_delay", 10);
	Irssi::settings_set_int("ag_bot_delay", 30);
	Irssi::settings_set_int("ag_interrun_delay", 15);
	Irssi::settings_set_bool("ag_autorun", 1);
	Irssi::settings_set_bool("ag_episodic", 0);
	Irssi::settings_set_str("ag_xdcc_send_prefix", "xdcc send");
	Irssi::settings_set_str("ag_xdcc_cancel_prefix", "xdcc cancel");
	Irssi::settings_set_str("ag_find_prefix", "!find");
	Irssi::settings_set_str("ag_format", "");
	Irssi::settings_set_str("ag_folder", File::HomeDir->my_home);
	&ag_setettings;
}

sub ag_setsettings
{
	$nexdelay = Irssi::settings_get_int("ag_next_delay");
	$dcrdelay = Irssi::settings_get_int("ag_dcc_closed_retry_delay");
	$botdelay = Irssi::settings_get_int("ag_bot_delay");
	$exedelay = Irssi::settings_get_int("ag_interrun_delay");
	$initflag = Irssi::settings_get_bool("ag_autorun");
	$episodicflag = Irssi::settings_get_bool("ag_episodic");
	$sendprefix = Irssi::settings_get_str("ag_xdcc_send_prefix");
	$cancelprefix = Irssi::settings_get_str("ag_xdcc_cancel_prefix");
	$findprefix = Irssi::settings_get_str("ag_find_prefix");
	$format = Irssi::settings_get_str("ag_format");
	$folder = Irssi::settings_get_str("ag_folder");
}

open(BOTS, ">>", $botsfilename);		#makes bots, searches, and finished file if they don't exist
close(BOTS);
open(SEARCHES, ">>", $searchesfilename);
close(SEARCHES);
open(FINISHED, ">>", $cachefilename);
close(FINISHED);

Irssi::statusbar_item_register('ag_statusbar', 0, 'ag_bar');
Irssi::timeout_add(100, sub { Irssi::statusbars_recreate_items(); Irssi::statusbar_items_redraw("ag_bar"); } , []);

&ag_init;
if ($initflag) {Irssi::signal_add("server connected", "ag_initserver");}

Irssi::signal_add("server disconnected", "ag_restart");
Irssi::signal_add("server lag disconnect", "ag_restart");
Irssi::signal_add("setup changed", "ag_setsettings");
Irssi::signal_add("dcc destroyed", "ag_closedcc");

Irssi::command_bind("ag_help", "ag_help");
Irssi::command_bind("ag_run", "ag_run");
Irssi::command_bind("ag_stop", "ag_stop");
Irssi::command_bind("ag_reset", "ag_reset");
Irssi::command_bind("ag_server", "ag_server");
Irssi::command_bind("ag_add", "ag_add");
Irssi::command_bind("ag_rem", "ag_rem");
Irssi::command_bind("ag_botadd", "ag_botadd");
Irssi::command_bind("ag_botrem", "ag_botrem");
Irssi::command_bind("ag_list", "ag_list");
Irssi::command_bind("ag_clearcache", "ag_clearcache");

