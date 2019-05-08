#
#Irssi script to complement chess backend server
#
use strict;
use Irssi;
use Irssi::Irc;
use IO::Socket;
use vars qw($VERSION %IRSSI);

$VERSION="0.2";
%IRSSI =
(
	authors     => "kodgehopper (kodgehopper\@netscape.net)",
	contact     => "kodgehopper\@netscape.net",
	name        => "IRC-Chess",
	description => "Chess server for IRC. Allows for multiple 2-player games to be played simultaneously",
	license     => "GNU GPL",
	url         => "http://irc-chess.sourceforge.net/",
);
my $gameRunning=0;
my $SERVER='127.0.0.1';
my $PORT=1234;

sub processColors
{
	$_=$_[0];

	#replace foreground/background colors
	my @fgbg;
	my $numFgBg=(@fgbg=/(<B\w+?><b\w+?>)/g);

	for (my $j=0; $j < $numFgBg; $j++)
	{
		my $t=$fgbg[$j];
		my ($background, $foreground)=($t=~/(<B\w+?>)(<b\w+?>)/);
		my $orig=$background.$foreground;

		$foreground=~s/<bBLACK>/\\cc1/g;
		$foreground=~s/<bWHITE>/\\cc0/g;

		$background=~s/<BBLUE>/,2/g;
		$background=~s/<BYELLOW>/,7/g;

		my $result=$foreground.$background;

		s/$orig/$result/;

	}

	#replace background-only colors
	s/<BBLUE>/\\cc0,2/g;
	s/<BYELLOW>/\\cc0,7/g;

	#replace rest of colors
	s/<NORMAL>/\\co/g;

	return $_;
}#processColors

#
#message formats:
#1. simple format:
#[username]Message
#
#2. complex format:
#[user1]msg1<:=:>[user2]msg2<:=:>commonMessage
#
sub processMsgFromServer 
{
	my ($server, $msg, $nick)=@_;
	my $delimiter="<:=:>";
	$_=$msg;

	#determine the type of message from the number of delimiters
	my $numDelims=(my @list=/$delimiter/g);

	if ($numDelims==0)
	{
		#simple message
		my ($username, $message)=/^\s*\[(.+?)\](.*?)$/;

		$message=processColors($message);

		#send message to player
		$server->command("eval msg $nick $message");
	}
	else
	{
		#complex message
		my ($user1, $msg1, $user2, $msg2, $commonMessage)=/^\s*\[(.+?)\](.*?)$delimiter\[(.+?)\](.*?)$delimiter(.*)$/s;

		#split message into seperate lines
		my @commonMessageList=split(/\n/, $commonMessage);

		#send common message to both users
		Irssi::print("Sending common message to both users");
		my $numStrings;
		my @list;

		#print out blank lines since the string was split on newlines so
		#now they're lost. an extra space == blank line
		$server->command("eval msg $user1  \\co"); 
		$server->command("eval msg $user2  \\co"); 

		my $commonListSize=@commonMessageList;
		for (my $j=0; $j<$commonListSize; $j++)
		{
			$commonMessageList[$j]=processColors($commonMessageList[$j]);

			if ($commonMessageList[$j] ne '') {
				$server->command("eval msg $user1 $commonMessageList[$j]"); 
				$server->command("eval msg $user2 $commonMessageList[$j]"); 
			}
		}
		$server->command("eval msg $user1  \\co"); 
		$server->command("eval msg $user2  \\co"); 

		#send messages for each user
		my @msg1List=split(/\n/, $msg1);
		my $msg1ListSize=@msg1List;

		for (my $j=0; $j<$msg1ListSize; $j++)
		{
			$server->command("eval msg $user1 \\cb$msg1List[$j]\\co");
		}

		my @msg2List=split(/\n/, $msg2);
		my $msg2ListSize=@msg2List;

		for (my $j=0; $j<$msg2ListSize; $j++)
		{
			$server->command("eval msg $user2 \\cb$msg2List[$j]\\co");
		}
	} #else
}#processOutput

#
#process a message received from the user.
#this will be something like "game start k"
#this will have to be changed to something like
#"game start k k1", where k1 is the user.
#if the format of the message is not correct,
#return INVALID. format checking is minimal.
#basically, if the first word is "game", then
#slap on the nickname and send it to the server.
#

sub processMsgFromClient
{
	my ($server, $msg, $nick)=@_; 

	#Irssi::print("msg from client:\n$msg\n");
	$msg=lc($msg);	

	if ($msg=~/^game\b/)
	{
		$msg = $msg." $nick";
		return $msg;
	}
	else
	{
		Irssi::print("sending: msg $nick Error: Invalid Message");
		$server->command("msg $nick Error: Invalid Message");
		return "INVALID";	
	}
}#processMsgFromClient

#
#private messages received from other users eg. if they want to
#register a new game
sub sig_processPvt
{
	my($server, $msg, $nick, $address)=@_;

	my $msgToSend=processMsgFromClient($server, $msg, $nick);

	if ($msgToSend !~ /^INVALID$/)
	{
		Irssi::print("Sending message now");
		send(SOCKET,$msgToSend,0);
		Irssi::print("Waiting for message from server\n");
		my $buffer;
		recv(SOCKET,$buffer,32678,0); #read a max of 32k. 
		processMsgFromServer($server, $buffer, $nick);
	}
}#sig_processPvt

#
#function to terminate game. it basically just closes 
#the connection to the server
#
sub cmd_endGame
{
	shutdown(SOCKET,2);
	close(SOCKET);
	Irssi::print("Game ended. Socket shut down");
	$gameRunning=0;
}#cmd_endGame

sub connect_server
{
	
	Irssi::print("connecting to server");
	my $tcpProtocolNumber = getprotobyname('tcp') || 6; 

	socket(SOCKET, PF_INET(), SOCK_STREAM(), $tcpProtocolNumber)
		or return("socket: $!");

	my $internetPackedAddress = pack_sockaddr_in($PORT, inet_aton($SERVER));
	connect(SOCKET, $internetPackedAddress) or return("connect: $!");

	Irssi::print("Game is now running");
	$gameRunning=1;
	return '';
}

sub cmd_connect_server
{
	my $err = connect_server();
	if ($err ne '') {
		Irssi::print($err);
		if ($err =~ m/^connect/) {
			Irssi::print("Server: $SERVER Port: $PORT");
			Irssi::print("see: ".$IRSSI{url});
			Irssi::print("reconnect by reload the script (/run irc_chess.pl) ");
		}
	}
}

cmd_connect_server();

Irssi::signal_add("message private","sig_processPvt");
Irssi::command_bind("end_game", "cmd_endGame");
