# xdcc autogetter, to automate searching and downloading xdcc packs based on chosen search strings
# requires that you enable dcc_autoget and dcc_autoresume. Also requires File::Dir which can be installed with the command >>> sudo perl -MCPAN -e 'install "File::HomeDir"'
# made because torrents are watched by the feds, but xdcc lacks RSS feeds.
# if you encounter any problems, fix it yourself you lazy bastard (or get me to), then contact me so I can add your fix and bump that version #
# BeerWare License. Use any part you want, but buy me a beer if you ever meet me and liked this hacked together broken PoS
# Somewhat based off of DCC multiget by Kaveh Moini.
# USE: for help             : ag_help
#      to run               : ag_run
#      to halt at next      : ag_stop
#      to reset all settings: ag_reset
#      to set the server    : ag_server 
#      to add a bot         : ag_botadd BOT1 BOT2 *** BOTN
#      to remove a bot      : ag_botrem BOT1 BOT2 *** BOTN
#      to add string        : ag_add "[TEXT STRING OF TV SHOW/CHINESE CARTOON/ETC]","[ETC]",***,"[ETC]" 
#      to remove strings    : ag_rem "[TEXT STRING OF TV SHOW/CHINESE CARTOON/ETC]","[ETC]",***,"[ETC]" 
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

use Irssi;
use Text::ParseWords;
use autodie; # die if problem reading or writing a file
use File::HomeDir;
use File::Copy;
use Irssi 20090331;
use vars qw($VERSION %IRSSI);

$VERSION = 1.3;
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
Irssi::settings_add_int($IRSSI{'name'}, "ag_interrun_delay", 15);
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
my $msgflag = 1;		#flag controls whether bot has responded to search request
my $termisepisodicflag = 0;	#flag controls whether 
my $episodicflag;		#flag controls whether to search episode by episode (eg instead of searching boku no pice, it'll search for boku no pico 1, then boku no pico 2, etc as long as results show up)
my $formatflag = 1;		#flag controls whether a format is appended to the end of an episodic search string
my $reqpackflag = 0;		#flag to avoid multiple download requests
my $downloadflag = 0;		#flag to avoid multiple download requests
my $newpackflag = 1;

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

my $termcounter = 0;	#counters for array position
my $botcounter = 0;	
my $packcounter = 0;
my $episode = 1;

my $server;		#current server

sub ag_init		#init system
{
	Irssi::print "AG | Autoget initiated";
	Irssi::print "AG | /ag_help for help";
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
	if ($episodicflag)
	{
		Irssi::print "AG | Episodic: Yes";
		Irssi::print "AG | Preffered format: $format";
	}
	else {Irssi::print "AG | Episodic: No";}
	Irssi::print "AG | Data folder: $folder";
}

sub ag_initserver	#init server
{
	Irssi::signal_remove("server connected", "ag_server");
	$server = $_[0];
	if (!$runningflag) {push(@totags, Irssi::timeout_add_once(5000, sub { &ag_run; }, []));}
}

sub ag_server	#init server
{
	$server = Irssi::active_server();
}

sub ag_help
{
	Irssi::print "for this help        : ag_help";
	Irssi::print "to run               : ag_run";
	Irssi::print "to halt at next      : ag_stop";
	Irssi::print "to reset all settings: ag_reset";
	Irssi::print "to set the server    : ag_server";
	Irssi::print "to add a bot         : ag_botadd BOT1 BOT2 *** BOTN";
	Irssi::print "to remove a bot      : ag_botrem BOT1 BOT2 *** BOTN";
	Irssi::print "to add string        : ag_add \"[TEXT STRING OF SEARCH]\",\"[ETC]\",***,\"[ETC]\"";
	Irssi::print "to remove strings    : ag_rem \"[TEXT STRING OF SEARCH]\",\"[ETC]\",***,\"[ETC]\"";
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
 	$msgflag = 0;	#unset message flag so that ag_skip knows no important message has arrived
	if($episodicflag)	#episodic searches are complicated
	{
		my $ep = sprintf("%.2d", $episode);
		if ($format ne "" and $formatflag)
		{
			ag_message("msg $bots[$botcounter] $findprefix $terms[$termcounter] $ep $format");	#first search with format
			if ($episode == 1)
			{
				push(@totags, Irssi::timeout_add_once($botdelay * 1000, sub { $formatflag = 0; &ag_search; } , []));	#if no formated version found, try again with just the search string + ep#
			}
			else
			{
				push(@totags, Irssi::timeout_add_once($botdelay * 1000, sub { &ag_skip; } , []));	
			}
		}
		else
		{
			ag_message("msg $bots[$botcounter] $findprefix $terms[$termcounter] $ep" );
			push(@totags, Irssi::timeout_add_once($botdelay * 1000, sub { &ag_skip; } , []));
		}
	}
	else		#if not episodic, just search and skip
	{
		ag_message("msg $bots[$botcounter] $findprefix $terms[$termcounter]" );
		push(@totags, Irssi::timeout_add_once($botdelay * 1000, sub { &ag_skip; } , []));
	}
	Irssi::signal_add("message irc notice", "ag_getmsg");
}

sub ag_remtimeouts	#remove timeouts to avoid multiple instances of everything
{
	foreach my $to (@totags)	#remove timeouts and clear array
	{
		Irssi::timeout_remove($to);
	}
	@totags = ();
}

sub ag_getmsg		#runs when bot sends privmsg. Avoid talking to bots to keep this from sending useless shit that breaks things
{	
	my $message = $_[1];
	my $botname = $_[2];
	$botname =~ tr/[A-Z]/[a-z]/;
	$bots[$botcounter] =~ tr/[A-Z]/[a-z]/;
	
	if ($botname eq $bots[$botcounter] and !$msgflag)	#if it's your bot
	{
		&ag_remtimeouts;	#stop any skips from happening
		ag_getpacks($message);	#and check for any new packs in the message
		if ($#packs < 0) { push(@totags, Irssi::timeout_add_once($nexdelay * 1000, sub { &ag_skip; } , [])); }	#set up only one possible skip per search
		if($#packs >= 0){ &ag_packrequest; }	#if there are any packs,
		$msgflag = 1;		#let everyone know that the current bot has replied
	}
}

sub ag_getpacks
{
	my($message) = @_;
	my @temp = split(' ', $message);	#split up the message into 'words'
	&ag_getfinished;
	
	foreach my $m (@temp)		#find packs (#[NUMBER]: format)
	{ 
		$newpackflag = 1;
		if ($m =~ m{#(\d+):})
		{
			foreach my $n (@finished)		#don't redownload finished packs
			{
				if ($n eq "$bots[$botcounter] $1") {$newpackflag = 0;}
				last if ($n eq "$bots[$botcounter] $1");
			}
			if($newpackflag){push(@packs, $1);}	#push all new pack numbers to list of packs
		}
	}
	@packs = ag_uniq(@packs);	#remove duplicates
}

sub ag_packrequest	#sends the xdcc send request, and retries on failure
{
	&ag_remtimeouts;
	if (!$reqpackflag)
	{
		$reqpackflag = 1;
		Irssi::signal_add("dcc get receive", "ag_opendcc");		#init DCC recieve init flag
		ag_message("msg $bots[$botcounter] $sendprefix $packs[$packcounter]");
		push(@totags, Irssi::timeout_add_once($botdelay * 1000, sub { if (!$downloadflag) { Irssi::print "AG | Connection failed"; Irssi::print "AG | retrying: " . $bots[$botcounter] . " " .$packs[$packcounter]; &ag_packrequest; } } , []));
	}
}

sub ag_opendcc	#runs on DCC recieve init
{
	my ($gdcc) = @_;	#current pack
	my $botname = $gdcc->{'nick'};
	$botname =~ tr/[A-Z]/[a-z]/;
	$bots[$botcounter] =~ tr/[A-Z]/[a-z]/;

	if ($botname eq $bots[$botcounter])	#if it's our bot, let user know, and stop any further AG pack requests until finished
	{
		Irssi::signal_remove("message irc notice", "ag_getmsg");
		Irssi::signal_remove("dcc get receive", "ag_opendcc");		#stops any suplicate sends (there should only ever be one)
		&ag_remtimeouts;
		$dccflag = 0;
		$downloadflag = 1;
		Irssi::print "AG | received connection for bot: " . $botname . ", #" . $packs[$packcounter]; 
		foreach my $n (@finished)		#don't redownload finished packs
		{
			if ($n eq $gdcc->{'arg'})	#if file already downloaded, emulate an already finished dcc transfer (in case file deleted) and cancel
			{
				$gdcc->{'transfd'} = $gdcc->{'size'};
				$gdcc->{'skipped'} = $gdcc->{'size'};
				ag_closedcc(@_);	
			}
			last if ($n eq $gdcc->{'arg'});
		}
	}
}

sub ag_skip
{
#	Irssi::print "AG | SKIP $msgflag $episodicflag $episode $#packs $packcounter $#terms $termcounter $#bots $botcounter"; 
	&ag_remtimeouts;	#stop any other skips
	$reqpackflag = 0;		#allow pack requests now that transfer is finished
	if($episodicflag)
	{
		@packs = ();		#delete and reset packlist
		$packcounter = 0;
		
		if ($msgflag)	#if the bot replied, then that means there were episodes, but we already have them
		{
			$episode++;
			&ag_search;
		}
		elsif ($termcounter < $#terms)	#otherwise just increment terms or bots
		{
			$episode = 1;
			$formatflag = 1;
			$termcounter++;
			$packcounter = 0;
			&ag_search;
		}
		elsif ($botcounter < $#bots)
		{
			$episode = 1;
			$formatflag = 1;
			$botcounter++;
			$termcounter = 0;
			$packcounter = 0;
			&ag_search;
		}
		else	#if last episode on last search on last bot finished, then resets counters and starts over
		{
			$episode = 1;
			$formatflag = 1;
			$botcounter = 0;
			$termcounter = 0;
			$packcounter = 0;
			Irssi::print "AG | Waiting " . $exedelay . " minutes until next search";
			Irssi::timeout_add_once($exedelay * 1000 * 60, sub { &ag_run; } , []);
			$runningflag = 0;
		}
	}
	elsif ($packcounter < $#packs)
	{
		$packcounter++;
		&ag_search;
	}
	elsif ($termcounter < $#terms)
	{
		@packs = ();		#delete last terms packlist
		$termcounter++;
		$packcounter = 0;
		&ag_search;
	}
	elsif ($botcounter < $#bots)
	{
		@packs = ();		#delete last bots packlist
		$botcounter++;
		$termcounter = 0;
		$packcounter = 0;
		&ag_search;
	}
	else	#if last pack on last search on last bot finished, then resets counters and starts over
	{
		$episode = 1;
		$formatflag = 1;
		@packs = ();		#delete last bots packlist
		$botcounter = 0;
		$termcounter = 0;
		$packcounter = 0;
		Irssi::print "AG | Waiting " . $exedelay . " minutes until next search";
		Irssi::timeout_add_once($exedelay * 1000 * 60, sub { &ag_run; } , []);
		$runningflag = 0;
	}
}

sub ag_closedcc
{
	my ($dcc) = @_;	#current pack
	my $botname = $dcc->{'nick'};	#get the bots name, and checks if it's the one we want
	$botname =~ tr/[A-Z]/[a-z]/;
	$bots[$botcounter] =~ tr/[A-Z]/[a-z]/;

	if ($botname eq $bots[$botcounter])	#checks if the is the bot
	{ 
		$reqpackflag = 0;
		if ($dccflag == 0) {Irssi::signal_add("dcc get receive", "ag_opendcc");}	#if so, reinits DCC get signal for the next pack
		$dccflag = 1;

		&ag_remtimeouts;
				
		if ($dcc->{'skipped'} == $dcc->{'size'})
		{
			ag_message("msg $bots[$botcounter] $cancelprefix");		#workaround because IRSSI doesn't actually 'get' packs if they're already downloaded, causing long stalls if left unattended.
		}
		if ($dcc->{'transfd'} == $dcc->{'size'})
		{
			Irssi::print "AG | transfer successful";
			ag_addfinished($dcc->{'arg'});
		}
		
		if($episodicflag and $dcc->{'transfd'} == $dcc->{'size'})
		{
			@packs = ();		#delete packlist
			$packcounter = 0;
			$episode++;
			Irssi::print "AG | waiting " . $nexdelay . " seconds";
			push(@totags, Irssi::timeout_add_once($nexdelay * 1000, sub { Irssi::print "AG | Getting next episode"; &ag_search; }, []));
		}
		elsif ($dcc->{'transfd'} == $dcc->{'size'})	
		{
			if ($packcounter < $#packs)
			{
				$packcounter++;
				Irssi::print "AG | Getting next pack in list in " . $nexdelay . " seconds ";
				push(@totags, Irssi::timeout_add_once($nexdelay * 1000, sub { &ag_reqpack; }, []));
			}
			elsif ($termcounter < $#terms)
			{
				@packs = ();		#delete last terms packlist
				$termcounter++;
				$packcounter = 0;
				Irssi::print "AG | Packlist finished. Searching next term in " . $nexdelay . " seconds";
				push(@totags, Irssi::timeout_add_once($nexdelay * 1000, sub { &ag_search; }, []));
			}
			elsif ($botcounter < $#bots)
			{
				@packs = ();		#delete last bots packlist
				$botcounter++;
				$termcounter = 0;
				$packcounter = 0;
				Irssi::print "AG | Search term lidt finished. Searching nect bot in " . $nexdelay . " seconds";
				push(@totags, Irssi::timeout_add_once($nexdelay * 1000, sub { &ag_search; }, []));
			}
			else	#if last pack on last search on last bot finished, then resets counters and starts over
			{
				@packs = ();
				$botcounter = 0;
				$termcounter = 0;
				$packcounter = 0;
				Irssi::print "AG | Waiting " . $exedelay . " minutes until next search";
				Irssi::timeout_add_once($exedelay * 1000 * 60, sub { &ag_run; } , []);
				$runningflag = 0;
			}
		}
		else	#if not, retry transfer
		{
			Irssi::print "AG | transfer failed";
			Irssi::print "AG | " . $dcrdelay . " seconds until retry";
			push(@totags, Irssi::timeout_add_once($dcrdelay * 1000, sub { Irssi::print "AG | retrying: " .$bots[$botcounter] . " " . $packs[$packcounter]; &ag_packrequest; }, []));
		}
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

sub ag_addfinished		#save finished downloads
{
	my $filename = $_[0];
	open(FINISHED, ">>", $cachefilename);
	print FINISHED $bots[$botcounter] . " " . $packs[$packcounter] . "\n";		#print pack to file	
	print FINISHED $filename . "\n";		#print name to file	
	close(FINISHED);	
}


sub ag_parseadd		#parses add arguments for storage
{
	my ($file, @args) = @_;
	open(FILE, ">>", $file);
	foreach my $arg (@args)
	{
		print FILE $arg . "\n";		#print to file
	}
	close(FILE);
	copy($file, "/tmp/temp");	#copy to temp file so that duplicate lines [searches/bots] can be removed
	unlink "$file";
	open(TEMP, "<", "/tmp/temp");
	open(FILE, ">", $file);
	my %hTmp;
	while (my $sLine = <TEMP>)	#remove duplicate lines
	{
		next if $sLine =~ m/^\s*$/;  #remove empty lines. Without this, still destroys empty lines except for the first one.
		$sLine=~s/^\s+//;            #strip leading/trailing whitespace
		$sLine=~s/\s+$//;
		print FILE qq{$sLine\n} unless ($hTmp{$sLine}++);
	}
	unlink "/tmp/temp";
	close(FILE);
}

sub ag_parserem		#parses remove arguments for deletion from file
{
	my ($file, @args) = @_;
	open(TEMP, ">", "/tmp/temp");
	foreach my $arg (@args)
	{
		Irssi::print "AG | removing term: " . $arg;
		print TEMP $arg . "\n";
	}
	close(TEMP);
	open(TEMP2, ">", "/tmp/temp2");
	open(FILE, "<", $file);
	my %hTmp;
	while( my $fileLine = FILE->getline() )		#get each entry already stored
	{
		open(TEMP, "<", "/tmp/temp");
		while( my $tempLine = TEMP->getline() )
		{
			if ($fileLine eq $tempLine)	#if entry in file and arguments
			{
				$hTmp{$fileLine}++;	#set flag to not copy
			}
			print TEMP2 qq{$fileLine} unless $hTmp{$fileLine};	#copy other lines to other temp file
		}
		close(TEMP);
	}
	close(TEMP2);
	copy("/tmp/temp2", $file);	#rewrite old file
	copy($file, "/tmp/temp");
	unlink "$file";
	open(TEMP, "<", "/tmp/temp");
	open(FILE, ">", $file);
	%hTmp = ();
	while (my $sLine = <TEMP>)		#remove duplicate lines
	{
		next if $sLine =~ m/^\s*$/;  #remove empty lines. Without this, still destroys empty lines except for the first one.
		$sLine=~s/^\s+//;            #strip leading/trailing whitespace
		$sLine=~s/\s+$//;
		print FILE qq{$sLine\n} unless ($hTmp{$sLine}++);
	}
	unlink "/tmp/temp";
	unlink "/tmp/temp2";
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
}

sub ag_run	#main loop
{
	if (!$initflag) {ag_server(Irssi::active_server());}
	if($runningflag == 0)
	{
		$runningflag = 1;
		if($#bots < 0 or $#terms < 0) {Irssi::print "AG | No bots or no search terms added. Halting"; &ag_stop;}
		else 
		{
			Irssi::print "AG | Search and get cycle Initiated";
			&ag_search;
		}
	}
	else {Irssi::print "AG | Another Instance is already running";}
}

sub ag_stop
{
	Irssi::signal_remove("dcc get receive", "ag_opendcc");
	Irssi::signal_remove("message irc notice", "ag_getmsg");

	foreach my $to (@totags)
	{
		Irssi::timeout_remove($to);
	}
	@totags = ();

	ag_message("msg $bots[$botcounter] $cancelprefix");

	if($runningflag == 1)
	{
		$runningflag = 0;
		Irssi::print "AG | Killed";
	}
	$msgflag = 1;
	$termisepisodicflag = 0;
	$formatflag = 1;
	$reqpackflag = 0;
	$downloadflag = 0;
	$newpackflag = 1;
	$dccflag = 0;
	@terms = ();
	@bots = ();
	@packs = ();
	@finished = ();
	$termcounter = 0;
	$botcounter = 0;	
	$packcounter = 0;
	$episode = 1;
}

sub ag_restart
{
	Irssi::print "AG | Connection lost";
	Irssi::signal_remove("dcc get receive", "ag_opendcc");
	Irssi::signal_remove("message irc notice", "ag_getmsg");

	foreach my $to (@totags)
	{
		Irssi::timeout_remove($to);
	}
	@totags = ();

	ag_message("msg $bots[$botcounter] $cancelprefix");

	if($runningflag == 1)
	{
		$runningflag = 0;
	}
	$msgflag = 1;
	$termisepisodicflag = 0;
	$formatflag = 1;
	$reqpackflag = 0;
	$downloadflag = 0;
	$newpackflag = 1;
	$dccflag = 0;
	&ag_search;
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

&ag_init;
if ($initflag) {Irssi::signal_add("server connected", "ag_initserver");}

Irssi::signal_add("server disconnected", "ag_restart");
Irssi::signal_add("dcc closed", "ag_closedcc");
Irssi::signal_add("setup changed", "ag_setsettings");

Irssi::command_bind("ag_help", "ag_help");
Irssi::command_bind("ag_run", "ag_run");
Irssi::command_bind("ag_stop", "ag_stop");
Irssi::command_bind("ag_reset", "ag_reset");
Irssi::command_bind("ag_server", "ag_server");
Irssi::command_bind("ag_add", "ag_add");
Irssi::command_bind("ag_rem", "ag_rem");
Irssi::command_bind("ag_botadd", "ag_botadd");
Irssi::command_bind("ag_botrem", "ag_botrem");
Irssi::command_bind("ag_clearcache", "ag_clearcache");

