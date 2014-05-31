###########################################################################
#
# CopyLeft Veli Mankinen 2002
# HL-log/rcon bot irssi script.
#
#####################
#
# USAGE:
#
# 1. copy the script to ~/.irssi/scripts/
# 2. Edit the variables below.
# 3. load the script: /script load hlbot
# 4. Join to the channel you want this script to work on.
# 5. Make sure all the users have ops in the channel (security reasons)
# 6. say in channel: .rcon logadress <ip> <port>
#    Where ip is the ip of the machine where this script is running and
#    the port is the $listen_port you have set below
# 7. say in channel: .rcon log on
# 
# The script should now start flooding the channel about things hapening in
# the channel. Ofcourse you can and I think you should add those
# log -commands to your hl server.cfg.
#
# You can turn the flooding of by saying: ".log off" and turn it back on
# with: ".log off". ".status" tells you whether the log is on or off.
# Please note that the logfile is allways on. If you don't want to gather
# the log in a file then you should put "/dev/null" to the $logfile below.
# 
#
# NOTE: There probably are few stupid things in this script and that is
#       just because I don't have a clue about making irssi script.
#
##


use Socket;
use Sys::Hostname;
use IO::Handle;

use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI);

##########################[ USER VARIABLES ]########################### 

my $listen_port  = 10001;              # Port to listen to
my $logfile      = "logi";             # Logfile

my $hlserver     = "123.123.123.123";  # Ip of your half life server
my $hlport       = "28000";            # Port of your half life server
my $rcon_pass    = "password";         # Rcon password of your half life server

my $channel      = "#mychan";          # Channel where you want this to work

#######################################################################
##############[ YOU DON'T NEED TO TOUCH BELOW THIS LINE ]##############
#######################################################################

$VERSION = "1.0";
%IRSSI = (
	authors => "Veli Mankinen",
	contact => "veli\@piipiip.net",
	name => "HL-log/rcon -bot",
	description => "Floods the channel about things that are hapening in your hl -server. Also enables you to send rcon commands to the server from channel.",
	license => "GPLv2",
	url => "http://piipiip.net/",
);

#####################

my $serv_iaddr = inet_aton($hlserver)    || die "unknown host: $hlserver\n";
my $serv_paddr = sockaddr_in($hlport, $serv_iaddr); 
my $challenge = "";
my $rcon_msg = "";
my $log_on = 1;

#####################

sub run_bot {	
	my $server = Irssi::active_server();
	
	($hispaddr = recv(S, $msg, 1000, 0)) or print "$!\n";
	($port, $hisiaddr) = sockaddr_in($hispaddr);
	$host = inet_ntoa($hisiaddr); 

	$msg =~ s/\n.$//s;
	$msg =~ s/\n..$//s;
	
	print LOG "$host : $msg\n";

	# Received logline
	if ($msg =~ s/^ÿÿÿÿlog L \d\d\/\d\d\/\d{4} - \d\d:\d\d:\d\d: //) {
		# We don't want to see these
		if ($log_on eq 0 ||
			$msg =~ /^Server cvar/ || 
			$msg =~ /^\[META\]/ ||
			$msg =~ /^Log file/ || 
			$msg =~ /^\[ADMIN\]/) 
			{ return; }
		
		# FORMAT THE LINE
		# Don't show the rcon password.
		$msg =~ s/^(Rcon: "rcon \d* )[^ ]*( .*)/$1*****$2/;
		
		# Print the logline
		if ($msg =~ /^"/) {
			$server->command("/action $channel $msg");
		} else {
			$server->send_raw("PRIVMSG $channel :*log* $msg");
		}
	} 

	# Received challenge rcon reply..
	elsif ($msg =~ /^ÿÿÿÿchallenge rcon (\d+)$/ && $rcon_msg) {
		$challenge = $1;
		$data = "ÿÿÿÿrcon $challenge $rcon_pass $rcon_msg";
		defined(send(S, $data, 0, $serv_paddr)) or
			$server->command("/notice $channel Error sending rcon: $!");
	}

	# Received rcon reply
	elsif ($msg =~ s/ÿÿÿÿl//) {
		# Some rcon replies have this annoying log entry in the beginning.
		$msg =~ s/L \d\d\/\d\d\/\d{4} - \d\d:\d\d:\d\d: //g;
		
		# FORMAT THE LINE
		
		# Multiline rcon responses
		if ($msg =~ /\n/s) {
			@rows = split /\n/, $msg;
			foreach $row (@rows) {
				# We don't want to see these
				if ($row =~ /^[\t \n]*$/ ||
					$row =~ /^[ADMIN] Load/ ||
					$row =~ /^[ADMIN] WARNING/ ||
					$row =~ /^[ADMIN] Plugins loaded/) 
					{ next; }

				$server->command("/notice $channel $row");
			}
			
		# Single line rcon responses
		} else {
			$server->command("/notice $channel $msg");
		}
	}
	
}

############################

sub msg_command {
	my ($server, $data, $nick, $mask, $target) = @_;
	
	# Is this the right channel?
	unless ($target =~ /$channel/i) { return; }
	
	# Does the user have ops?
	my $CHAN = $server->channel_find($channel);
	my $NICK = $CHAN->nick_find($nick);
	if (! $NICK->{op}) { return; }
		
	# Rcon command.
	if ($data =~ /^\.rcon (.+)/) {
		$rcon_msg = $1;
		
        defined(send(S, "ÿÿÿÿchallenge rcon", 0, $serv_paddr)) or
			$server->command("/notice $channel Error asking challenge: $!");
	} 

	# log on
	elsif ($data =~ /^\.log on$/) {
		$log_on = 1;
		$server->command("/notice $channel Logging now ON");
	}
	
	# log off
	elsif ($data =~ /^\.log off$/) {
		$log_on = 0;
		$server->command("/notice $channel Logging now OFF");
	}
	
	# help
	elsif ($data =~ /^\.help$/) {
		$server->command("/notice $channel Commands: .rcon <rcon command>, " .
			".log <on/off>, .status");
	}

	# status
	elsif ($data =~ /^\.status$/) {
		my $log_status = "";
		if ($log_on eq 1) { $log_status = "on"; }
		else { $log_status = "off"; }
		$server->command("/notice $channel Log: $log_status");
	}
	
}

#########[ MAIN ]###########

# Open the logfile.
open LOG, ">>$logfile" or die "Cannot open logfile!\n";
LOG->autoflush(1);

# Start listening the socket for udp messages.
my $iaddr = gethostbyname(hostname());
my $proto = getprotobyname('udp');
my $paddr = sockaddr_in($listen_port, $iaddr);
socket(S, PF_INET, SOCK_DGRAM, $proto)   || die "socket: $!\n";
bind(S, $paddr)                          || die "bind: $!\n";
$| = 1;

# Set input and signals etc. irssi related stuff.
Irssi::input_add(fileno(S), INPUT_READ, "run_bot", "");
Irssi::signal_add_last('message public', 'msg_command');


