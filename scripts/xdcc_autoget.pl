# xdcc autoget, to automate searching and downloading xdcc packs from xdcc bots based on chosen search strings
# 
# long description: You add a bunch of xdcc bots and search terms using the provided functionality, or by adding lines to the searches.txt and bots.txt files
#                   For searching for episodes, a search term should use '#' as a placeholder for the episode number.
#                   eg., If the release of Boku no Pico you want to download uses a naming scheme such that episode 1 is "Boku no Pico - ep01 (1080p HEVC).mkv", then your search term should be "Boku no Pico - ep# (1080p HEVC).mkv"
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
#      to halt              : ag_stop
#      to reset all settings: ag_reset
#      to set the server    : ag_server 
#      to add a bot         : ag_botadd BOT1 BOT2 *** BOTN
#      to remove a bot      : ag_botrem BOT1 BOT2 *** BOTN
#      to add string        : ag_add "[TEXT STRING OF TV SHOW/CHINESE CARTOON/ETC]","[ETC]",***,"[ETC]" 
#      to remove strings    : ag_rem "[TEXT STRING OF TV SHOW/CHINESE CARTOON/ETC]","[ETC]",***,"[ETC]" 
#      to see terms and bots: ag_list
#      to clear cache       : ag_clearcache
#      ag_next_delay             : delay between full transfers
#      ag_dcc_closed_retry_delay : delay after premature transfer
#      ag_bot_delay              : delay between request and when you "SHOULD" get it
#      ag_interrun_delay         : delay (in minutes, the rest seconds) between finishing a round and starting another
#      ag_autorun                : whether to run on startup
#      ag_xdcc_send_prefix       : the xdcc message before the pack #
#      ag_xdcc_find_prefix       : the xdcc message before the search term
#      ag_bot_file               : where your bot list is stored
#      ag_search_file            : where your search list is stored

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

$VERSION = "2.0";
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
my @reqpackflag = ();		#flag to avoid multiple download requests
my @downloadflag = ();		#flag to avoid multiple download requests
my @skipunfinishedflag = ();	#flag to tell ag_closedcc to not redownload an unfinished file

my $sendprefix;		#virtually universal xdcc send, cancel, and find prefixes
my $cancelprefix;
my $findprefix;
my $folder;

&ag_setsettings;

my $botsfilename = $folder . "/bots.txt";
my $searchesfilename = $folder . "/searches.txt";
my $cachefilename = $folder . "/cache.txt";

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
	&ag_getfinished;
	if ($episodicflag) {Irssi::print "AG | Episodic: Yes";}
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
	Irssi::print "for help             : ag_help";
	Irssi::print "to run               : ag_run";
	Irssi::print "to halt              : ag_stop";
	Irssi::print "to reset all settings: ag_reset";
	Irssi::print "to set the server    : ag_server ";
	Irssi::print "to add a bot         : ag_botadd BOT1 BOT2 *** BOTN";
	Irssi::print "to remove a bot      : ag_botrem BOT1 BOT2 *** BOTN";
	Irssi::print "to add string        : ag_add \"[TEXT STRING OF SEARCH]\",\"[ETC]\",***,\"[ETC]\" ";
	Irssi::print "to remove strings    : ag_rem \"[TEXT STRING OF SEARCH]\",\"[ETC]\",***,\"[ETC]\" ";
	Irssi::print "to see terms and bots: ag_list";
	Irssi::print "to clear cache       : ag_clearcache";
	Irssi::print "ag_next_delay             : delay between full transfers";
	Irssi::print "ag_dcc_closed_retry_delay : delay after premature transfer";
	Irssi::print "ag_bot_delay              : delay between request and when you \"SHOULD\" get it";
	Irssi::print "ag_interrun_delay         : delay (in minutes, the rest seconds) between finishing a round and starting another";
	Irssi::print "ag_autorun                : whether to run on startup";
	Irssi::print "ag_xdcc_send_prefix       : the xdcc message before the pack #";
	Irssi::print "ag_xdcc_find_prefix       : the xdcc message before the search term";
	Irssi::print "ag_bot_file               : where your bot list is stored";
	Irssi::print "ag_search_file            : where your search list is stored";
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
	&ag_clearcache;
	@finished = nsort(@finished);	#sort normally
	open(FINISHED, ">", $cachefilename);
	foreach my $finish (@finished)
	{
		print FINISHED $finish . "\n";		#print name to file	
	}	
		close(FINISHED);	
}

sub nsort {		#shamelessly ripped from Sort::Naturally
	my($cmp, $lc);
	return @_ if @_ < 2;   # Just to be CLEVER.

	my($x, $i);  # scratch vars

	map
		$_->[0],

	sort {
		# Uses $i as the index variable, $x as the result.
		$x = 0;
		$i = 1;

		while($i < @$a and $i < @$b) {
			last if ($x = ($a->[$i] cmp $b->[$i])); # lexicographic
			++$i;

			last if ($x = ($a->[$i] <=> $b->[$i])); # numeric
			++$i;
		}

		$x || (@$a <=> @$b) || ($a->[0] cmp $b->[0]);
	}

	map {
		my @bit = ($x = defined($_) ? $_ : '');

		if($x =~ m/^[+-]?(?=\d|\.\d)\d*(?:\.\d*)?(?:[Ee](?:[+-]?\d+))?\z/s) {
			# It's entirely purely numeric, so treat it specially:
			push @bit, '', $x;
		} else {
			# Consume the string.
			while(length $x) {
				push @bit, ($x =~ s/^(\D+)//s) ? lc($1) : '';
				push @bit, ($x =~ s/^(\d+)//s) ?    $1  :  0;
			}
		}

		\@bit;
	}
	@_;
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
	if($episodicflag)	
	{
		my $searchterm;
		my @words = split(/#/, $terms[$termcounter[$botcounter]]);
		my $ep = sprintf("%.2d", $episode[$botcounter]);
		if ($#words > 0){$searchterm = "$words[0]$ep$words[1]";}
		else {$searchterm = "$words[0] $ep";}

		ag_message("msg $bots[$botcounter] $findprefix $searchterm" );
		push(@{$totags[$botcounter]}, Irssi::timeout_add_once($botdelay * 1000, sub { ag_skip($botcounter); } , []));
	}
	else		#if not episodic, just search and skip
	{
		ag_message("msg $bots[$botcounter] $findprefix $terms[$termcounter[$botcounter]]" );
		push(@{$totags[$botcounter]}, Irssi::timeout_add_once($botdelay * 1000, sub { ag_skip($botcounter); } , []));
	}
}

sub ag_remtimeouts	#remove timeouts to avoid multiple instances of everything
{
	my($botcounter) = @_;
	foreach my $to (@{$totags[$botcounter]})	#remove timeouts and clear array
	{
		Irssi::timeout_remove($to);
	}
	@{$totags[$botcounter]} = ();
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
			ag_getpacks($message, $botcounter);	#check for any new packs in the message
			my @packlist = @{$packs[$botcounter]};
			if($#packlist >= 0){ ag_packrequest($botcounter); }	#if there are any packs,
			$msgflag[$botcounter] = 1;		#let everyone know that the current bot has replied
		}
		$botcounter++;
	}
}

sub ag_getpacks			#if ($m =~ m{#(\d+):})
{
	my($message, $botcounter) = @_;
	my @temp = split(/[#,]/, $message);	#split up the message into 'words'
	my $timeoutscleared = 0;
	
	my $newpackflag = 1;
	foreach my $m (@temp)		#find packs (#[NUMBER]: format)
	{ 
		if ($m =~ m/(\d+):(.+)/)
		{
			if (!$timeoutscleared)	#reset timeouts if any packs are found
			{
				ag_remtimeouts($botcounter); 
				$timeoutscleared = 0;
				push(@{$totags[$botcounter]}, Irssi::timeout_add_once($nexdelay * 1000, sub { ag_skip($botcounter); } , []));
			}
			foreach my $n (@finished)		#don't redownload finished packs
			{
				my $filename = $2;
				$filename =~ tr/[ ']/[__]/;
				if ($n eq "$bots[$botcounter] $1" or $n eq $filename) {$newpackflag = 0;}
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
	ag_remtimeouts($botcounter);
	if (!$reqpackflag[$botcounter])
	{
		$reqpackflag[$botcounter] = 1;
		ag_message("msg $bots[$botcounter] $sendprefix $packs[$botcounter][$packcounter[$botcounter]]");
		push(@{$totags[$botcounter]}, Irssi::timeout_add_once($botdelay * 1000, sub { if (!$downloadflag[$botcounter]) { ag_packrequest($botcounter); } } , []));
	}
}

sub ag_opendcc	#runs on DCC recieve init
{
	&Irssi::signal_continue;
	my ($gdcc) = @_;	#current pack
	my $botname = $gdcc->{'nick'};
	my $filename = $gdcc->{'arg'};
	my $filedownloadflag = 0;
	
	$filename =~ tr/[ ']/[__]/;
	$botname =~ tr/[A-Z]/[a-z]/;
	
	foreach my $file (@filenames){ if ($file eq $filename){ $filedownloadflag = 1; }}

	my $botcounter = 0;	
	foreach my $bot (@bots)
	{
		$bot =~ tr/[A-Z]/[a-z]/;
		if ($botname eq $bot and !$filedownloadflag)	#if it's our bot and the file is not already being downloaded, let user know, and stop any further AG pack requests until finished
		{
			ag_remtimeouts($botcounter);	#stop any other skips
			$getmsgflag[$botcounter] = 0;
						
			$downloadflag[$botcounter] = 1;
			foreach my $n (@finished)		#don't redownload finished packs
			{
				if ($n eq $gdcc->{'arg'})	#if file already downloaded, cancel
				{
					ag_message("msg $bots[$botcounter] $cancelprefix" );
					ag_addfinished($gdcc->{'arg'}, $botcounter);
					$skipunfinishedflag[$botcounter] = 1;
					$gdcc->close;
				}
				last if ($n eq $gdcc->{'arg'});
			}
			push(@filenames, $filename);
		}
		elsif ($botname eq $bot and $filedownloadflag)	#don't download packs that are being downloaded by other bots
		{
			ag_message("msg $bots[$botcounter] $cancelprefix" );
			$skipunfinishedflag[$botcounter] = 1;
			$gdcc->close;
		}
		$botcounter++;
	}
}

sub ag_skip
{
	my($botcounter) = @_;
	my @packlist = @{$packs[$botcounter]//[]};	#if $packs[botcounter] is undefined, pass an empty array reference
	ag_remtimeouts($botcounter);	#stop any other skips
	$reqpackflag[$botcounter] = 0;		#allow pack requests now that transfer is finished
	if($episodicflag)
	{
		if ($msgflag[$botcounter])	#if the bot replied, then that means there were episodes, but we already have them
		{
			if ($packcounter[$botcounter] < $#packlist)
			{
				$packcounter[$botcounter]++;
				ag_packrequest($botcounter);
			}
			else
			{
				$episode[$botcounter]++;
				ag_search($botcounter);
			}
		}
		elsif ($termcounter[$botcounter] < $#terms)	#otherwise just increment terms
		{
			$episode[$botcounter] = 1;
			$termcounter[$botcounter]++;
			$packcounter[$botcounter] = 0;
			ag_search($botcounter);
		}
		else	#if last episode on last search on last term finished, then resets counters and starts over
		{
			$episode[$botcounter] = 1;
			$termcounter[$botcounter] = 0;
			$packcounter[$botcounter] = 0;
			push(@{$totags[$botcounter]}, Irssi::timeout_add_once($exedelay * 1000 * 60, sub { ag_search($botcounter); } , []));
		}
	}
	elsif ($packcounter[$botcounter] < $#packlist)
	{
		$packcounter[$botcounter]++;
		ag_packrequest($botcounter);
	}
	elsif ($termcounter[$botcounter] < $#terms)
	{
		$packs[$botcounter] = ();		#delete last terms packlist
		$termcounter[$botcounter]++;
		$packcounter[$botcounter] = 0;
		ag_search($botcounter);
	}
	else	#if last pack on last search on last term finished, then resets counters and starts over
	{
		$episode[$botcounter] = 1;
		$packs[$botcounter] = ();		#delete last bots packlist
		$termcounter[$botcounter] = 0;
		$packcounter[$botcounter] = 0;
		push(@{$totags[$botcounter]}, Irssi::timeout_add_once($exedelay * 1000 * 60, sub { ag_search($botcounter); } , []));
	}
}

sub ag_closedcc
{
	my ($dcc) = @_;	#current pack
	my $botname = $dcc->{'nick'};	#get the bots name, and checks if it's the one we want
	my $filename = $dcc->{'arg'};
	my $delayoverride = 1;		#speed divider for the delays before next load, to avoid flooding when cancelling a pack
	$botname =~ tr/[A-Z]/[a-z]/;
	
	my $botcounter = 0;
	foreach my $bot (@bots)
	{
		$bot =~ tr/[A-Z]/[a-z]/;

		if ($botname eq $bot and $reqpackflag[$botcounter])	#checks if this is the bot
		{ 
			my $temp = $botcounter;
			my @packlist = $packs[$botcounter];
			my @termlist = $terms[$botcounter];

			$reqpackflag[$botcounter] = 0;
			
			if (!$skipunfinishedflag[$botcounter])
			{
				$filename =~ tr/[ ']/[__]/;
				@filenames = grep { $_ ne $filename } @filenames;		#remove the file from the list of files being transferred
			}
			ag_remtimeouts($botcounter);
					
			if ($dcc->{'skipped'} == $dcc->{'size'})
			{
				$delayoverride = 2;						#doubles the delay for next message to make up for prematurely sending xdcc cancel
				if (!$skipunfinishedflag[$botcounter]) {ag_message("msg $bots[$botcounter] $cancelprefix");}		#workaround to cancel packs avoiding stalls if left unattended.
			}
			if ($dcc->{'transfd'} == $dcc->{'size'} or $skipunfinishedflag[$botcounter])
			{
				if (!$skipunfinishedflag[$botcounter])
				{
	 				ag_addfinished($dcc->{'arg'}, $botcounter);
	 			}
				$skipunfinishedflag[$botcounter] = 0;				#reset any skip flags
				if($episodicflag)
				{
					if ($packcounter[$botcounter] < $#packlist)
					{
						$packcounter[$botcounter]++;
						Irssi::timeout_add_once($nexdelay * 1000 * $delayoverride, sub { ag_packrequest($temp); }, []);
					}
					else
					{
						$packs[$botcounter] = ();		#delete packlist
						$packcounter[$botcounter] = 0;
						$episode[$botcounter]++;
						Irssi::timeout_add_once($nexdelay * 1000 * $delayoverride, sub { ag_search($temp); }, []);
					}
				}
				else
				{
					if ($packcounter[$botcounter] < $#packlist)
					{
						$packcounter[$botcounter]++;
						Irssi::timeout_add_once($nexdelay * 1000 * $delayoverride, sub { ag_search($temp); }, []);
					}
					elsif ($termcounter[$botcounter] < $#termlist)
					{
						$packs[$botcounter] = ();		#delete last terms packlist
						$termcounter[$botcounter]++;
						$packcounter[$botcounter] = 0;
						Irssi::timeout_add_once($nexdelay * 1000 * $delayoverride, sub { ag_search($temp); }, []);
					}
					else	#if last pack on last search on last bot finished, then resets counters and starts over
					{
						$packs[$botcounter] = ();
						$termcounter[$botcounter] = 0;
						$packcounter[$botcounter] = 0;
						Irssi::timeout_add_once($exedelay * 1000 * 60, sub { ag_search($temp); } , []);
					}
				}
			}
			else
			{
				push(@{$totags[$botcounter]}, Irssi::timeout_add_once($dcrdelay * 1000 * $delayoverride, sub { ag_packrequest($temp); }, []));
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
	$filename =~ tr/[ ']/[__]/;
	print FINISHED $filename . "\n";		#print name to file	
	close(FINISHED);
	ag_getfinished;
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
	ag_getbots;
	ag_getterms;
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
	ag_server;
	my @args = quotewords('\s+', 0, $_[0]);	#split arguments (words in brackets not seperated)
	if ($#args < 0)
	{
		Irssi::print "AG | too few arguments";
		Irssi::print "AG | usage: ag_add <search terms>";
		return;
	}
	ag_parseadd($searchesfilename, @args);
	ag_list;
}

sub ag_rem	#remove ssearch terms
{
	ag_server;
	my @args = quotewords('\s+', 0, $_[0]);
	if ($#args < 0)
	{
		Irssi::print "AG | too few arguments";
		Irssi::print "AG | usage: ag_rem <search terms>";
		return;
	}
	ag_parserem($searchesfilename, @args);
	ag_list;
}

sub ag_botadd	#add bots
{
	ag_server;
	my @args = quotewords('\s+', 0, $_[0]);
	if ($#args < 0)
	{
		Irssi::print "AG | too few arguments";
		Irssi::print "AG | usage: ag_botsadd <bots>";
		return;
	}
	ag_parseadd($botsfilename, @args);
	ag_list;
}

sub ag_botrem	#remove bots
{
	ag_server;
	my @args = quotewords('\s+', 0, $_[0]);
	if ($#args < 0)
	{
		Irssi::print "AG | too few arguments";
		Irssi::print "AG | usage: ag_rem <search terms>";
		return;
	}
	ag_parserem($botsfilename, @args);
	ag_list;
}

sub ag_run	#main loop
{
	if (!$initflag) {ag_server(Irssi::active_server());}
	if($runningflag == 0)
	{
		$runningflag = 1;
		ag_getbots;
		ag_getterms;
				
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
				$reqpackflag[$botcounter] = 0;		#flag to avoid multiple download requests
				$downloadflag[$botcounter] = 0;		#flag to avoid multiple download requests
				$skipunfinishedflag[$botcounter] = 0;
				$termcounter[$botcounter] = 0;
				$packcounter[$botcounter] = 0;
				$episode[$botcounter] = 1;
				$packs[$botcounter] = ();
				ag_search($botcounter);
				$botcounter++;
			}
		}
	}
}

sub ag_stop
{	
	my $botcounter = 0;
	foreach my $bot (@bots)
	{
		ag_remtimeouts($botcounter);	#stop any skips from happening
		ag_message("msg $bot $cancelprefix");
		$botcounter++;
	}
	@getmsgflag = ();
	@msgflag = ();
	@reqpackflag = ();
	@downloadflag = ();
	@skipunfinishedflag = ();
	@termcounter = ();
	@packcounter = ();
	@episode = ();
	@filenames = ();

	if($runningflag == 1)
	{
		$runningflag = 0;
		$statusbarmessage = "Inactive";
	}
	@terms = ();
	@bots = ();
	@packs = ();
	$botcounter = 0;	
}

sub ag_restart
{
	$statusbarmessage = "No Connection";
	ag_stop();
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

Irssi::signal_add("dcc request", "ag_opendcc");
Irssi::signal_add("message irc notice", "ag_getmsg");
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

