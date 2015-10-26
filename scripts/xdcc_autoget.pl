# xdcc autogetter, to automate searching and downloading xdcc packs based on chosen search strings
# requires that you enable dcc_autoget and dcc_autoresume. Also requires File::Dir which can be installed with the command >>> sudo perl -MCPAN -e 'install "File::HomeDir"'
# made because torrents are watched by the feds, but xdcc lacks RSS feeds.
# if you encounter any problems, fix it yourself you lazy bastard (or get me to), then contact me so I can add your fix and bump that version #
# BeerWare License. Use any part you want, but buy me a beer if you ever meet me and liked this hacked together broken PoS
# Somewhat based off of DCC multiget by Kaveh Moini.
# USE: for help         : ag_help
#      to run           : ag_run
#      to halt at next  : ag_stop
#      to set the server: ag_server 
#      to add a bot     : ag_botadd BOT1 BOT2 *** BOTN
#      to remove a bot  : ag_botrem BOT1 BOT2 *** BOTN
#      to add string    : ag_add "[TEXT STRING OF TV SHOW/CHINESE CARTOON/ETC]","[ETC]",***,"[ETC]" 
#      to remove strings: ag_rem "[TEXT STRING OF TV SHOW/CHINESE CARTOON/ETC]","[ETC]",***,"[ETC]" 
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

use Irssi;
use Text::ParseWords;
use autodie; # die if problem reading or writing a file
use File::HomeDir;
use File::Copy;
use Irssi 20090331;
use vars qw($VERSION %IRSSI);

$VERSION = 1.2;
%IRSSI = (
	name => "autoget", 
	description => "XDCC Autoget, for automated searching and downloading of xdcc packs",
	license => "BeerWare Version 42",
	changed => "$VERSION",
	authors => "MarshalMeatball",
	contact => "mobilegundamseed\@hotmail.com",
);

Irssi::settings_add_int($IRSSI{'name'}, "ag_next_delay", 5);
Irssi::settings_add_int($IRSSI{'name'}, "ag_dcc_closed_retry_delay", 10);
Irssi::settings_add_int($IRSSI{'name'}, "ag_bot_delay", 30);
Irssi::settings_add_int($IRSSI{'name'}, "ag_interrun_delay", 15);
Irssi::settings_add_bool($IRSSI{'name'}, "ag_autorun", 1);
Irssi::settings_add_bool($IRSSI{'name'}, "ag_episodic", 0);
Irssi::settings_add_str($IRSSI{'name'}, "ag_xdcc_send_prefix", "xdcc send");
Irssi::settings_add_str($IRSSI{'name'}, "ag_xdcc_cancel_prefix", "xdcc cancel");
Irssi::settings_add_str($IRSSI{'name'}, "ag_find_prefix", "!find");
Irssi::settings_add_str($IRSSI{'name'}, "ag_format", "");
Irssi::settings_add_str($IRSSI{'name'}, "ag_bot_file", File::HomeDir->my_home . "/bots.txt");
Irssi::settings_add_str($IRSSI{'name'}, "ag_search_file", File::HomeDir->my_home . "/searches.txt");
Irssi::settings_add_str($IRSSI{'name'}, "ag_cache_file", File::HomeDir->my_home . "/finished.txt");

my @totags = ();	#timeout tags (need to be purged between send requests maybe)
my @msgtags = ();	#timeout tags for search results

my $nexdelay = Irssi::settings_get_int("ag_next_delay");		#delay for next pack
my $dcrdelay = Irssi::settings_get_int("ag_dcc_closed_retry_delay");	#delay if transfer closed prematurely
my $botdelay = Irssi::settings_get_int("ag_bot_delay");			#max time to wait for the bot to respond
my $exedelay = Irssi::settings_get_int("ag_interrun_delay");		#delay (in minutes) between finishing one run and starting another

my $initflag = Irssi::settings_get_bool("ag_autorun");			#flag controls whether AG starts on IRSSI boot (if in autorun), or on LOAD
my $runningflag = 0;							#flag keeps ag from running more than one instance of itself at a time
my $msgflag = 1;							#flag controls whether bot has responded to search request
my $addflag = 0;							#flag controls whether bot has sent a pack
my $episodeflag = Irssi::settings_get_bool("ag_episodic");		#flag controls whether to search episode by episode (eg instead of searching boku no pice, it'll search for boku no pico 1, then boku no pico 2, etc as long as results show up)
my $pact = 0;								#3 state flag to avoid recursive ag_reqpack calls

my $sendprefix = Irssi::settings_get_str("ag_xdcc_send_prefix");		#virtually universal xdcc send, cancel, and find prefixes
my $cancelprefix = Irssi::settings_get_str("ag_xdcc_cancel_prefix");
my $findprefix = Irssi::settings_get_str("ag_find_prefix");			#format option for episodic. Can be edited if you want a certain size, eg 720p; x264; aXXo; etc
my $format = Irssi::settings_get_str("ag_format");			#format option for episodic. Can be edited if you want a certain size, eg 720p; x264; aXXo; etc
my $botsfilename = Irssi::settings_get_str("ag_bot_file");
my $searchesfilename = Irssi::settings_get_str("ag_search_file");
my $finishedfilename = Irssi::settings_get_str("ag_cache_file");

my $dccflag = 0;	#flag so that dccs aren't mistakenly thought of belonging to AG

my @terms;		#lists of search terms, bots, and pack numbers (for current bot only)
my @bots;
my @packs;
my @finished;		#list of packs already downloaded

my $termcounter = 0;	#counters for array position
my $botcounter = 0;
my $packcounter = 0;
my $episode = 1;

my $server;		#current server

sub ag_init		#init system
{
	Irssi::print "AG | Autoget initiated";
	Irssi::print "AG | /ag_help for help";
	&ag_initserver;
}

sub ag_initserver	#init server
{
	$server = Irssi::active_server();	#keep trying to get server until it works, then continue after 5 seconds
	if ($server !~ m/^Irssi::Irc::Server=HASH/) {Irssi::timeout_add_once(1000, sub {&ag_initserver;} , []);}
	else {Irssi::timeout_add_once(5000, sub {&ag_run;} , []);}
}

sub ag_help
{
	Irssi::print "for this help    : ag_help";
	Irssi::print "to run           : ag_run";
	Irssi::print "to halt at next  : ag_stop";
	Irssi::print "to set the server: ag_server";
	Irssi::print "to add a bot     : ag_botadd BOT1 BOT2 *** BOTN";
	Irssi::print "to remove a bot  : ag_botrem BOT1 BOT2 *** BOTN";
	Irssi::print "to add string    : ag_add \"[TEXT STRING OF SEARCH]\",\"[ETC]\",***,\"[ETC]\"";
	Irssi::print "to remove strings: ag_rem \"[TEXT STRING OF SEARCH]\",\"[ETC]\",***,\"[ETC]\"";
	Irssi::print "to clear cache   : ag_clearcache";
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
	Irssi::print "ag_bot_file              : where your bot list is stored";
	Irssi::print "ag_search_file           : where your search list is stored}";
}

sub ag_server	#should only be run when you have a server, or it'll break (probably unfixable without a bunch of ugly dumb checks everywhere)
{
	$server = Irssi::active_server();
}

sub ag_getbots		#reads in bot list
{
	open(bots, "<", $botsfilename);
	@bots = <bots>;
	chomp(@bots);
	close(bots);
}

sub ag_getterms		#reads in search term list
{
	open(searches, "<", $searchesfilename);
	@terms = <searches>;
	chomp(@terms);
	close(searches);
}

sub ag_getfinished		#reads in finished packs list
{
	open(finished, "<", $finishedfilename);
	@finished = <finished>;
	chomp(@finished);
	@finished = ag_uniq(@finished);
	close(finished);
}

sub ag_clearcache		#resets cache of saved packs
{
	unlink $finishedfilename;
	open(finished, ">>", $finishedfilename);
	close(finished);
}

sub ag_search		#searches current bot for current term
{
	$msgflag = 0;
	Irssi::signal_add("message irc notice", "ag_getmsg");
	if($episodeflag)
	{
		my $ep = sprintf("%.2d", $episode);
		if ($format ne "")
		{
			$server->command("msg $bots[$botcounter] $findprefix $terms[$termcounter] $ep $format" );
			push(@msgtags, Irssi::timeout_add_once($botdelay * 1000, sub { &ag_formatlessepisodicsearch; } , []));		#retry search if no results given, but without the format
		}
		else {&ag_formatlessepisodicsearch;}

	}
	else 
	{
		$server->command("msg $bots[$botcounter] $findprefix $terms[$termcounter]");
		push(@msgtags, Irssi::timeout_add_once($botdelay * 1000, sub { &ag_skip; } , []));		#skip search if no results given
	}
}

sub ag_formatlessepisodicsearch		#redo above, but without formatting
{
	my $ep = sprintf("%.2d", $episode);
	$server->command("msg $bots[$botcounter] $findprefix $terms[$termcounter] $ep" );
	push(@msgtags, Irssi::timeout_add_once($botdelay * 1000, sub { &ag_skip; } , []));		#skip search if no results given
}

sub ag_skip
{
	if ($msgflag == 0)
	{		
		if ($episodeflag and $addflag)
		{
			$addflag = 0;
			$episode++;
			&ag_search;
		}
		elsif ($#terms != $termcounter)
		{
			
			Irssi::print "AG | No new and unfinished packs found while searching ". $terms[$termcounter] . " or bot " . $bots[$botcounter] . " unresponsive or nonexistent. Skipping to next search";
			Irssi::signal_remove("message irc notice", "ag_getmsg");
			$episode = 1;
			$termcounter++;
			&ag_search;
		}
		elsif ($#bots != $botcounter)
		{
			Irssi::print "AG | No new and unfinished packs found while searching ". $terms[$termcounter] . " or bot " . $bots[$botcounter] . " unresponsive or nonexistent. Skipping to next bot";
			Irssi::signal_remove("message irc notice", "ag_getmsg");
			$termcounter = 0;
			$episode = 1;
			$botcounter++;
			&ag_search;
		}
		else
		{
			Irssi::print "AG | No new and unfinished packs found while searching ". $terms[$termcounter] . " or bot " . $bots[$botcounter] . " unresponsive or nonexistent. End of list";
			Irssi::signal_remove("message irc notice", "ag_getmsg");
			$botcounter = 0;
			$termcounter = 0;
			$episode = 1;
			Irssi::print "AG | Waiting " . $exedelay . " minutes until next search";
			Irssi::timeout_add_once($exedelay * 1000 * 60, sub { &ag_run; } , []);
			$runningflag = 0;
		}
	}
}

sub ag_getmsg		#runs when bot sends privmsg. Avoid talking to bots to keep this from sending useless shit that breaks things
{
	my $message = @_[1];
	my $botname = @_[2];
	$botname =~ tr/[A-Z]/[a-z]/;
	$bots[$botcounter] =~ tr/[A-Z]/[a-z]/;

	foreach my $to (@msgtags)	#remove timeouts for skipping if a pack has been recieved
	{
		Irssi::timeout_remove($to);
	}
	@msgtags = ();

	if ($botname == $bots[$botcounter])
	{
		$msgflag = 1;
		&ag_parseresponse($message);
	}
}

sub ag_parseresponse	#takes a single message and finds all instances of "#[XDCC NUMBER]:" since most bots reply to !find requests like that. If a bot uses another method and this doesn't work, fix it yourself and send me the code =D
{
	my($message) = @_;
	my @temp = split(' ', $message);
	foreach my $m (@temp)
	{ 
		$addflag = 1;
		if ($m =~ m{#(\d+):})
		{
			&ag_getfinished;
			foreach my $n (@finished)		#don't redownload finished packs
			{
				if ($n eq "$bots[$botcounter] $1")
				{
					$addflag = 0;
				}
				last if ($n eq "$bots[$botcounter] $1");
			}
			if ($addflag >= 1) {push(@packs, $1);}
		}
	}
	@packs = ag_uniq(@packs);
	
	if ($pact == 0 and $#packs >= 0 and $packs[$packcounter] ne "")		#initiallizes the actual xdcc get system only once per search term/bot (pact should be >0 until the whole process is finished)
	{
		$msgflag = 1;
		$pact = 1;
		&ag_reqpack();
	}
	elsif ($#packs <= 0)
	{
		$msgflag = 0;
		push(@msgtags, Irssi::timeout_add_once($nexdelay * 1000, sub { &ag_skip(); }, []));
	}
}

sub ag_uniq		#only returns unique entries
{
	my %seen;
	grep !$seen{$_}++, @_;
}

sub ag_reqpack	#sends the xdcc send request, and retries on failure
{
	if ($dccflag == 0){Irssi::signal_add("dcc get receive", "ag_opendcc");}		#init DCC recieve init flag
	$dccflag = 1;
	$server->command("msg $bots[$botcounter] $sendprefix $packs[$packcounter]");
	push(@totags, Irssi::timeout_add_once($botdelay * 1000, sub { if ($pact < 2) { Irssi::print "AG | Connection failed"; Irssi::print "AG | retrying: " . $bots[$botcounter] . " " .$packs[$packcounter]; &ag_reqpack(); } } , []));
}

sub ag_opendcc	#runs on DCC recieve init
{
	Irssi::signal_remove("dcc get receive", "ag_opendcc");		#stops any suplicate sends (there should only ever be one)
	$dccflag = 0;

	my ($gdcc) = @_;	#current pack
	my $botname = $gdcc->{'nick'};
	$botname =~ tr/[A-Z]/[a-z]/;
	$bots[$botcounter] =~ tr/[A-Z]/[a-z]/;
	if ($botname eq $bots[$botcounter])	#if it's our bot, let user know, and stop any further AG pack requests until finished
	{
		Irssi::print "AG | received connection for bot: " . $botname . ", #" . $packs[$packcounter]; 
		$pact = 2;
	}
	else		#if not, allow this to rerun on next get
	{
		Irssi::signal_add("dcc get receive", "ag_opendcc");
		$dccflag = 1;
	}
}

sub ag_filecomp		#save finished downloads
{
	open(finished, ">>", $finishedfilename);
	print finished $bots[$botcounter] . " " . $packs[$packcounter] . "\n";		#print to file
	close(finished);	
	&ag_getfinished;
}

sub ag_closedcc	#deals with DCC closes
{
	my ($dcc) = @_;	#current pack
	my $botname = $dcc->{'nick'};	#get the bots name, and checks if it's the one we want
	$botname =~ tr/[A-Z]/[a-z]/;
	$bots[$botcounter] =~ tr/[A-Z]/[a-z]/;
	if ($botname eq $bots[$botcounter])
	{ 
		if ($dccflag == 0) {Irssi::signal_add("dcc get receive", "ag_opendcc");}	#if so, reinits DCC get signal for the next pack
		$dccflag = 1;
		foreach my $to (@totags)	#clears timeouts to defuckify everything
		{
			Irssi::timeout_remove($to);
		}
		@totags = ();
		
		if ($dcc->{'transfd'} == $dcc->{'size'}){&ag_filecomp}
		
		if($episodeflag and $dcc->{'transfd'} == $dcc->{'size'})
		{
			$episode++;
			$pact = 1;		#allow pack requests now that transfer is finished
			@packs = ();		#delete packlist
			$packcounter = 0;
			push(@totags, Irssi::timeout_add_once($nexdelay * 1000, sub { Irssi::print "AG | Getting next episode"; &ag_search(); }, []));
			Irssi::print "AG | waiting " . $nexdelay . " seconds";
			if ($dcc->{'skipped'} == $dcc->{'size'})
			{
				$server->command("msg $bots[$botcounter] $cancelprefix");		#workaround because IRSSI doesn't actually 'get' packs if they're already downloaded, causing long stalls if left unattended.
			}

		}
		elsif ($dcc->{'transfd'} == $dcc->{'size'})	#checks if the transfer actually ran to completion
		{
			Irssi::print "AG | transfer successful";	#if so, does next pack/search/bot (in that order)
			if ($dcc->{'skipped'} == $dcc->{'size'})
			{
				$server->command("msg $bots[$botcounter] $cancelprefix");		#workaround because IRSSI doesn't actually 'get' packs if they're already downloaded, causing long stalls if left unattended.
			}
			if ($packcounter < $#packs)
			{
				$pact = 1;		#allow pack requests now that transfer is finished
				$packcounter += 1;
				push(@totags, Irssi::timeout_add_once($nexdelay * 1000, sub { Irssi::print "AG | Getting next pack in list"; &ag_reqpack(); }, []));
				Irssi::print "AG | waiting " . $nexdelay . " seconds";
			}
			elsif ($termcounter < $#terms)
			{
				$pact = 0;		#allow the system to parse new responses
				@packs = ();		#delete last terms packlist
				$termcounter += 1;
				$packcounter = 0;
				push(@totags, Irssi::timeout_add_once($nexdelay * 1000, sub { Irssi::print "AG | Packlist finished. Searching next term"; &ag_search(); }, []));
				Irssi::print "AG | waiting " . $nexdelay . " seconds";
			}
			elsif ($botcounter < $#bots)
			{
				$pact = 0;		#allow the system to parse new responses
				@packs = ();		#delete last bots packlist
				$botcounter += 1;
				$termcounter = 0;
				$packcounter = 0;
				push(@totags, Irssi::timeout_add_once($nexdelay * 1000, sub { Irssi::print "AG | All searches complete. Searching next bot"; &ag_search(); }, []));
				Irssi::print "AG | waiting " . $nexdelay . " seconds";
			}
			else	#if last pack on last search on last bot finished, then resets counters and starts over
			{
				$pact = 0;
				@packs = ();		#delete last bots packlist
				$botcounter = 0;
				$termcounter = 0;
				$packcounter = 0;
				Irssi::signal_remove("message irc notice", "ag_getmsg");
				Irssi::print "AG | Waiting " . $exedelay . " minutes until next search";
				Irssi::timeout_add_once($exedelay * 1000 * 60, sub { &ag_run; } , []);
				$runningflag = 0;
			}
		}
		else	#if not, retry transfer
		{
			Irssi::print "AG | transfer failed";
			Irssi::print "AG | " . $dcrdelay . " seconds until retry";
			push(@totags, Irssi::timeout_add_once($dcrdelay * 1000, sub { Irssi::print "AG | retrying: " .$bots[$botcounter] . " " . $packs[$packcounter]; &ag_reqpack(); }, []));
		}
	}
}

sub ag_parseadd		#parses add arguments for storage
{
	my ($file, @args) = @_;
	open(file, ">>", $file);
	foreach my $arg (@args)
	{
		print file $arg . "\n";		#print to file
	}
	close(file);
	copy($file, "/tmp/temp") or die "COPY FAILED";	#copy to temp file so that duplicate lines [searches/bots] can be removed
	unlink "$file";
	open(temp, "<", "/tmp/temp");
	open(file, ">", $file);
	my %hTmp;
	while (my $sLine = <temp>)	#remove duplicate lines
	{
		next if $sLine =~ m/^\s*$/;  #remove empty lines. Without this, still destroys empty lines except for the first one.
		$sLine=~s/^\s+//;            #strip leading/trailing whitespace
		$sLine=~s/\s+$//;
		print file qq{$sLine\n} unless ($hTmp{$sLine}++);
	}
	unlink "/tmp/temp";
	close(file);
}

sub ag_parserem		#parses remove arguments for deletion from file
{
	my ($file, @args) = @_;
	open(temp, ">>", "/tmp/temp");
	foreach my $arg (@args)
	{
		Irssi::print "AG | removing term: " . $arg;
		print temp $arg . "\n";
	}
	close(temp);
	open(temp2, ">", "/tmp/temp2");
	open(file, "<", $file);
	my %hTmp;
	while( my $fileLine = file->getline() )		#get each entry already stored
	{
		open(temp, "<", "/tmp/temp");
		while( my $tempLine = temp->getline() )
		{
			if ($fileLine eq $tempLine)	#if entry in file and arguments
			{
				$hTmp{$fileLine}++;	#set flag to not copy
			}
			print temp2 qq{$fileLine} unless $hTmp{$fileLine};	#copy other lines to other temp file
		}
		close(temp);
	}
	close(temp2);
	copy("/tmp/temp2", $file) or die "COPY FAILED";	#rewrite old file
	copy($file, "/tmp/temp") or die "COPY FAILED";
	unlink "$file";
	open(temp, "<", "/tmp/temp");
	open(searches, ">", $file);
	my %hTmp;
	while (my $sLine = <temp>)		#remove duplicate lines
	{
		next if $sLine =~ m/^\s*$/;  #remove empty lines. Without this, still destroys empty lines except for the first one.
		$sLine=~s/^\s+//;            #strip leading/trailing whitespace
		$sLine=~s/\s+$//;
		print file qq{$sLine\n} unless ($hTmp{$sLine}++);
	}
	unlink "/tmp/temp";
	unlink "/tmp/temp2";
	close(file);
}

sub ag_add	#add search terms
{
	&ag_server;
	my @args = quotewords('\s+', 0, @_[0]);	#split arguments (words in brackets not seperated)
	if ($#args < 0)
	{
		Irssi::print "AG | too few arguments";
		Irssi::print "AG | usage: ag_add <search terms>";
		return;
	}
	&ag_parseadd($searchesfilename, @args);
}

sub ag_rem	#remove ssearch terms
{
	&ag_server;
	my @args = quotewords('\s+', 0, @_[0]);
	if ($#args < 0)
	{
		Irssi::print "AG | too few arguments";
		Irssi::print "AG | usage: ag_rem <search terms>";
		return;
	}
	&ag_parserem($searchesfilename, @args);
}

sub ag_botadd	#add bots
{
	&ag_server;
	my @args = quotewords('\s+', 0, @_[0]);
	if ($#args < 0)
	{
		Irssi::print "AG | too few arguments";
		Irssi::print "AG | usage: ag_botsadd <bots>";
		return;
	}
	&ag_parseadd($botsfilename, @args);
}

sub ag_botrem	#remove bots
{
	&ag_server;
	my @args = quotewords('\s+', 0, @_[0]);
	if ($#args < 0)
	{
		Irssi::print "AG | too few arguments";
		Irssi::print "AG | usage: ag_rem <search terms>";
		return;
	}
	&ag_parserem($botsfilename, @args);
}

sub ag_run	#main loop
{
	if($runningflag == 0)
	{
		$runningflag = 1;
		&ag_getbots;
		foreach my $n (@bots)
		{
			Irssi::print "AG | Bots: " . $n;
		}
		&ag_getterms;
		foreach my $n (@terms)
		{
			Irssi::print "AG | Terms: " . $n;
		}
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
	foreach my $to (@totags)
	{
		Irssi::timeout_remove($to);
	}
	@totags = ();
	$server->command("msg $bots[$botcounter] $cancelprefix");
	if($runningflag == 1)
	{
		$runningflag = 0;
		Irssi::print "AG | Killed";
	}
	Irssi::signal_remove("dcc get receive", "ag_opendcc");
	$botcounter = 0;
	$termcounter = 0;
	$packcounter = 0;
	@bots = ();
	@terms = ();
	@packs = ();
}

sub ag_reset
{
	my $nexdelay = 5;
	my $dcrdelay = 10;
	my $botdelay = 30;
	my $exedelay = 15;	
	my $initflag = 1;	
	my $sendprefix = "xdcc send";
	my $findprefix = "!find";
	my $botsfilename = "$FindBin::Bin/.irssi/scripts/bots.txt";
	my $searchesfilename = "$FindBin::Bin/.irssi/scripts/searches.txt";
	Irssi::settings_get_int("ag_next_delay");
	Irssi::settings_get_int("ag_dcc_closed_retry_delay");
	Irssi::settings_get_int("ag_bot_delay");
	Irssi::settings_get_int("ag_interrun_delay");
	Irssi::settings_get_bool("ag_autorun");
	Irssi::settings_get_str("ag_xdcc_send_prefix");
	Irssi::settings_get_str("ag_xdcc_find_prefix");
	Irssi::settings_get_str("ag_bot_file");
	Irssi::settings_get_str("ag_search_file");
	Irssi::print "AG | all settings reset to default values";
}

#sub ag_setsettings
#{
#	Irssi::settings_set_int("ag_next_delay", $nexdelay);
#	Irssi::settings_set_int("ag_dcc_closed_retry_delay", $dcrdelay);
#	Irssi::settings_set_int("ag_bot_delay", $botdelay);
#	Irssi::settings_set_int("ag_interrun_delay", $exedelay);
#	Irssi::settings_set_bool("ag_autorun", $initflag);
#	Irssi::settings_set_bool("ag_episodic", $episodeflag);
#	Irssi::settings_set_str("ag_xdcc_send_prefix", $sendprefix);
#	Irssi::settings_set_str("ag_xdcc_cancel_prefix", $cancelprefix);
#	Irssi::settings_set_str("ag_xdcc_find_prefix", $findprefix);
#	Irssi::settings_set_str("ag_format", $format);
#	Irssi::settings_set_str("ag_bot_file", $botsfilename);
#	Irssi::settings_set_str("ag_search_file", $searchesfilename);
#}

open(bots, ">>", $botsfilename);		#makes bots, searches, and finished file if they don't exist
close(bots);
open(searches, ">>", $searchesfilename);
close(searches);
open(finished, ">>", $finishedfilename);
close(finished);
if ($initflag) {&ag_init();}

Irssi::signal_add("dcc closed", "ag_closedcc");
#Irssi::signal_add("setup changed", "ag_setsettings");

Irssi::command_bind("ag_help", "ag_help");
Irssi::command_bind("ag_run", "ag_run");
Irssi::command_bind("ag_stop", "ag_stop");
Irssi::command_bind("ag_server", "ag_server");
Irssi::command_bind("ag_add", "ag_add");
Irssi::command_bind("ag_rem", "ag_rem");
Irssi::command_bind("ag_botadd", "ag_botadd");
Irssi::command_bind("ag_botrem", "ag_botrem");
Irssi::command_bind("ag_clearcache", "ag_clearcache");

