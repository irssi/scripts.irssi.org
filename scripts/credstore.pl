#store fingerprints of know users so can verify
#/credstore
use Irssi;
use warnings;
use strict;
use vars qw($VERSION %IRSSI $DBFILE $DEBUG $OPT $FING);

$VERSION = "1.3";
%IRSSI = (
    authors     => "Benedetto",
    contact     => "dettox\@gmail.com",
    name        => "credstore",
    description => "store fingerprints of know users so can verify",
    license     => "GPLv3+",
    url         => "http://irssi.org/",
    changed	=> "Thu Jan 20 13:07:49 GMT 2014",
);

$DBFILE = Irssi::get_irssi_dir() . "/credstore.txt";
$OPT = "help";
$FING = "";

sub show_help() {
	my $help="CREDSTORE $VERSION
/CREDSTORE add <nickname> [add nickname fingerprint]
/CREDSTORE del <nickname> [del nickname fingerprint]
/CREDSTORE verify <nickname> [verify nickname fingerprint]
/CREDSTORE [display this help]
";
	Irssi::print("$help",MSGLEVEL_CLIENTCRAP);
}

sub redir_init {
    # set up event to handler mappings
    Irssi::signal_add
    ({
    	'redir credstore_whois_user'       => 'event_whois_user',
    	'redir credstore_whois_server'       => 'event_whois_server',
	'redir credstore_whois_end'        => 'event_whois_end',
	'redir credstore_whois_nosuchnick' => 'event_whois_nosuchnick',
	'redir credstore_whois_timeout'    => 'event_whois_timeout',
	'redir credstore_whois_various'    => 'event_whois_various',
	'redir credstore_whois_idle'    => 'event_whois_idle',
	'redir credstore_whois_channels'    => 'event_whois_channels',
	'redir credstore_whois_modes'    => 'event_whois_modes',
	'redir credstore_whois_usermode'    => 'event_whois_usermode',
	'redir credstore_whois_usermode326'    => 'event_whois_usermode326',
	'redir credstore_whois_realhost'    => 'event_whois_realhost',
	'redir credstore_whois_realhost327'    => 'event_whois_realhost327',
	'redir credstore_whois_realhost338'    => 'event_whois_realhost338',
	});
}

sub request_whois {
    my ($server, $nick) = @_;
        $server->redirect_event
	(
		'whois', 1, $nick, 0,             # command, remote, arg, timeout
	        'redir credstore_whois_timeout', # error handler
	        {
	        'event 311' => 'redir credstore_whois_user', # event mappings
	        'event 312' => 'redir credstore_whois_server',
	        'event 317' => 'redir credstore_whois_idle',
	        'event 318' => 'redir credstore_whois_end',
	        'event 319' => 'redir credstore_whois_channels',
	        'event 327' => 'redir credstore_whois_realhost327',
	        'event 338' => 'redir credstore_whois_realhost338',
	        'event 378' => 'redir credstore_whois_realhost',
	        'event 326' => 'redir credstore_whois_usermode326',
	        'event 377' => 'redir credstore_whois_usermode',
	        'event 379' => 'redir credstore_whois_modes',
		'event 401' => 'redir credstore_whois_nosuchnick',
		'event 275' => 'redir credstore_whois_various',
		'event 276' => 'redir credstore_whois_various',
		'event 671' => 'redir credstore_whois_various',
	        ''          => 'event empty',
	        }
        );

	Irssi::print("CREDSTORE Sending Command: WHOIS $nick", MSGLEVEL_CLIENTCRAP);
        $server->send_raw("whois $nick");
}

sub event_whois_user {
	my ($num, $nick, $user, $host, $empty, $realname) = ( split / +/, $_[1], 6 );
	Irssi::print("CREDSTORE WHOIS: $nick!$user\@$host $empty $realname", MSGLEVEL_CLIENTCRAP);
}

sub event_whois_various {
	my $data = $_[1];
	my $fingerp = get_fingerprint($data);
	if ( defined $fingerp && $fingerp ne "" ) {
		$FING = $data;
	}
    
	Irssi::print("CREDSTORE WHOIS: $data", MSGLEVEL_CLIENTCRAP);
}

sub event_whois_server {
	my ($empty, $nick, $whoserver, $desc) = ( split / +/, $_[1], 4 );
	Irssi::print("CREDSTORE WHOIS: $whoserver $desc", MSGLEVEL_CLIENTCRAP);
}

sub event_whois_idle {
	my ($empty, $nick, $sec, $signon, $rest) = ( split / +/, $_[1], 5 );
	my $days = int($sec/3600/24);
	my $hours = int(($sec%(3600*24))/3600);
	my $min = int(($sec%3600)/60);
	my $secs = int($sec%60);
	my $logint = gmtime($signon);
	Irssi::print("CREDSTORE WHOIS: $days days $hours hours $min mins $secs secs [signon: $logint]", MSGLEVEL_CLIENTCRAP);
}

sub event_whois_channels {
	my ($empty, $nick, $chans) = ( split / +/, $_[1], 3 );
	Irssi::print("CREDSTORE WHOIS: $chans", MSGLEVEL_CLIENTCRAP);
}

sub event_whois_realhost {
	my ($empty, $nick, $txt_real, $txt_hostname, $hostname) = ( split / +/, $_[1], 5 );
	Irssi::print("CREDSTORE WHOIS: $txt_real $txt_hostname $hostname", MSGLEVEL_CLIENTCRAP);
}

sub event_whois_realhost327 {
	my ($empty, $nick, $hostname, $ip, $text) = ( split / +/, $_[1], 5 );
	Irssi::print("CREDSTORE WHOIS: $hostname $ip $text", MSGLEVEL_CLIENTCRAP);
}

sub event_whois_realhost338 {
	my ($empty, $nick, $arg1, $arg2, $arg3) = ( split / +/, $_[1], 5 );
	if ( defined $arg1 && defined $arg2 ) {
		Irssi::print("CREDSTORE WHOIS: $nick $arg1 $arg2", MSGLEVEL_CLIENTCRAP);
	} elsif ( defined $arg2 && defined $arg3 ) {
		Irssi::print("CREDSTORE WHOIS: $nick $arg1 $arg2", MSGLEVEL_CLIENTCRAP);
	}
}

sub event_whois_usermode {
	my ($empty, $txt_user, $nick, $usermode) = ( split / +/, $_[1], 4 );
	Irssi::print("CREDSTORE WHOIS: $txt_user $usermode", MSGLEVEL_CLIENTCRAP);
}

sub event_whois_usermode326 {
	my ($empty, $nick, $usermode) = ( split / +/, $_[1], 3 );
	Irssi::print("CREDSTORE WHOIS: $usermode", MSGLEVEL_CLIENTCRAP);
}

sub event_whois_modes {
	my ($empty, $nick, $modes) = ( split / +/, $_[1], 3 );
	Irssi::print("CREDSTORE WHOIS: $modes", MSGLEVEL_CLIENTCRAP);
}

sub event_whois_end {
	my ($server, $data) = @_;
	my ($nick) = ( split / +/, $data, 3 )[1];
	my $fingerp = get_fingerprint($FING);

	if ( $OPT eq 'add' ) {
		if ( defined $fingerp && $fingerp ne "" ) {
			add_to_db($nick,$fingerp);
		} else { 
			Irssi::print("CREDSTORE Error: No Whois Fingerprint for $nick",MSGLEVEL_CLIENTCRAP);
		}
	} elsif ( $OPT eq 'verify' ) {
			my $fingerp2 = read_from_db($nick);
			if ( defined $fingerp && $fingerp ne "" ) {
				if ( lc($fingerp) ne lc($fingerp2) ) {
					Irssi::print("CREDSTORE Error: Differents Fingerprints for $nick",MSGLEVEL_CLIENTCRAP);
					Irssi::print("CREDSTORE  DB:$fingerp2\nCREDSTORE NEW:$fingerp",MSGLEVEL_CLIENTCRAP);
				} else { 
					Irssi::print("CREDSTORE $nick Fingerprint is OK",MSGLEVEL_CLIENTCRAP);
				}
			} else { 
				Irssi::print("CREDSTORE Error: No Whois Fingerprint for $nick",MSGLEVEL_CLIENTCRAP);
			}
	}
}

sub event_whois_nosuchnick {
    my ($server, $data) = @_;
    my $nick = ( split / +/, $data, 4)[1];
    Irssi::active_win->print("CREDSTORE WHOIS Error: no such nick $nick - aborting.",MSGLEVEL_CLIENTCRAP);
}

sub event_whois_timeout {
    my ($server, $data) = @_;
    Irssi::print("CREDSTORE WHOIS whois_timeout", MSGLEVEL_CLIENTCRAP);
}

sub dbfile_check {
	if ( ! -w $DBFILE ) {
		open FH,">",$DBFILE or croak $!;
		print FH "";
		if(!close(FH)) {
			Irssi::print("CREDSTORE Error on $DBFILE",MSGLEVEL_CLIENTCRAP);
		}
	}
}

#add nick,fingerprint to DB
sub add_to_db {
	my ($nick,$fingerp) = @_;
	if ( -w $DBFILE ) {
		open FH,">>",$DBFILE or croak $!;
		print FH "$nick\t$fingerp\n";
		if(!close(FH)) {
			Irssi::print("CREDSTORE Error on $DBFILE",MSGLEVEL_CLIENTCRAP);
		}
		Irssi::print("CREDSTORE $nick($fingerp)",MSGLEVEL_CLIENTCRAP);
	} else {
		Irssi::print("CREDSTORE Error on $DBFILE",MSGLEVEL_CLIENTCRAP);
	}
}

#del nick,fingerprint from DB
sub del_from_db {
	my ($nick) = @_;
	my $nick2; my $fingerp;
	my $filetmp = "$DBFILE.tmp";
	if ( -w $DBFILE && ! -w $filetmp ) {
		open FHR,"<",$DBFILE or croak $!;
		open FHW,">",$filetmp or croak $!;
		while (<FHR>) {
			my @line = split(/\t/, $_);
			($nick2,$fingerp) = @line;
			if ( $nick ne $nick2 ) {
				print FHW "$nick2\t$fingerp";
			}
		}
		if(!close(FHR)) {
			Irssi::print("CREDSTORE Error on $DBFILE",MSGLEVEL_CLIENTCRAP);
		}
		if(!close(FHW)) {
			Irssi::print("CREDSTORE Error on $DBFILE",MSGLEVEL_CLIENTCRAP);
		}
		unlink($DBFILE);
		rename($filetmp,$DBFILE);
		Irssi::print("CREDSTORE $nick removed from DB",MSGLEVEL_CLIENTCRAP);
	} else {
		Irssi::print("CREDSTORE Error on $DBFILE",MSGLEVEL_CLIENTCRAP);
	}
}

#read nick,fingerprint from DB
sub read_from_db {
	my ($nick) = @_;
	my $nick2; my $fingerp;
	
	if ( -w $DBFILE ) {
		open FH,"<",$DBFILE or croak $!;
		while (<FH>) {
			my @line = split(/\t/, $_);
			($nick2,$fingerp) = @line;
			if ( defined $DEBUG ) {
				Irssi::print("$nick2  ...  $fingerp\n",MSGLEVEL_CLIENTCRAP);
			}
			if ( $nick eq $nick2 ) {
				$_ = $fingerp;
				$fingerp =~ s/\n//g;
				return $fingerp;
			} else {
				$fingerp = "";
			}
		}
		if(!close(FH)) {
			Irssi::print("CREDSTORE Error on $DBFILE",MSGLEVEL_CLIENTCRAP);
		}
	} else {
		Irssi::print("CREDSTORE Error on $DBFILE",MSGLEVEL_CLIENTCRAP);
	}
	return $fingerp;
}

#get fingerprint from input
sub get_fingerprint {
	my ($output) = @_;
	my $fingerp;

	$_ = $output;
	while ( $output =~ s/.*\s(\w{40}).*/$1/ ) {
		$fingerp = $1;
	}
	return $fingerp;
}

#add fingerprint for nick
sub add_nickname {
	my ($nick,$server) = @_;
	my $exfingerp = read_from_db($nick);
	if ( defined $exfingerp && $exfingerp ne "" ) {
		Irssi::print("CREDSTORE Error: $nick just Exist",MSGLEVEL_CLIENTCRAP);
		return;
	}
	Irssi::print("CREDSTORE Adding $nick ... ",MSGLEVEL_CLIENTCRAP);
	request_whois($server,$nick);
}

#del nick from db
sub del_nickname {
	my ($nick) = @_;
	Irssi::print("CREDSTORE Deleting $nick ...",MSGLEVEL_CLIENTCRAP);
	del_from_db($nick);
}

#verify nick, fingerprint
sub verify_nickname {
	my ($nick,$server) = @_;
	Irssi::print("CREDSTORE Verify $nick ...",MSGLEVEL_CLIENTCRAP);

	my ($fingerp) = read_from_db($nick);
	if ( defined $fingerp && $fingerp ne "" ) {
		request_whois($server,$nick);
	} else { 
		Irssi::print("CREDSTORE Error: $nick not in DB",MSGLEVEL_CLIENTCRAP);
	}
}

sub cmd_credstore {
	my ($data, $server, $witem) = @_;
	my $cmd; my $nick; my $conn = 0;
	( $cmd, $nick ) = split(/ /, $data);
	
	if (!$server || !$server->{connected}) {
		$conn = 1;
		Irssi::print("CREDSTORE Warning: not connected",MSGLEVEL_CLIENTCRAP);
	}
	
	if ( defined $cmd && defined $nick) {
		$OPT = $cmd;
		if ($cmd eq 'add' && !$conn) {
			add_nickname($nick,$server);
		} elsif ($cmd eq 'del' && !$conn) {
			del_nickname($nick);
		} elsif ($cmd eq 'verify' && !$conn) {
			verify_nickname($nick,$server);
		} else {
			show_help();
		}
	} else {
		show_help();
	}
	return(0);
}
#signal handler
redir_init();
#DB file exist and is writable
dbfile_check();

Irssi::command_bind('credstore', 'cmd_credstore');
