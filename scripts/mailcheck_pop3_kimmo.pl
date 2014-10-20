# Provides /mail command for POP3 mail checking
# for irssi 0.7.98 (tested on CVS) by Kimmo Lehto
#
# Requires Net::POP3 module
# If you don't have it, you can install it using:
#
# perl -e shell -MCPAN;
# >install Net::POP3
#

use strict;
use Irssi;
use Net::POP3;
use vars qw($VERSION %IRSSI);

$VERSION = '0.5';
%IRSSI = (
    authors     => 'Kimmo Lehto',
    contact     => 'kimmo@a-men.org' ,
    name        => 'Mailcheck-POP3',
    description => 'POP3 new mail notification and listing of mailbox contents. Use "/mail help" for instructions. Requires Net::POP3.',
    license     => 'Public Domain',
    changed	=> 'Sun Apr 7 00:10 EET 2002'
);


my (%_mailcount, %_mailchecktimer);

sub cmd_checkmail
{
	my $args = shift;
	my ($user, $pass, $host) = split(/\;/, $args);
	my ($i, $from, $subject, $head);
	my $POP3TIMEOUT = Irssi::settings_get_int("pop3_timeout");
    my $pop = Net::POP3->new( $host, Timeout => $POP3TIMEOUT );
	my $count = $pop->login($user, $pass);

	if (!$count || !$pop)
	{
		Irssi::print("Invalid POP3 user, pass or host.", MSGLEVEL_CLIENTERROR);
		if (!$_mailcount{"$user\@$host"})
		{
			Irssi::timeout_remove($_mailchecktimer{"$user\@$host"});
			delete $_mailchecktimer{"$user\@$host"};
		}
		$pop->quit();
		return undef;
	}
	if (!$_mailcount{"$user\@$host"}) { $_mailcount{"$user\@$host"} = $count; $pop->quit(); return 1; }
	if ($_mailcount{"$user\@$host"} < $count)
	{
		Irssi::print("%R>>%n New Mail for $user\@$host:"); 
		
  		for( $i = $_mailcount{"$user\@$host"} + 1; $i <= $count; $i++ ) 
		{
			foreach $head (@{$pop->top($i)})
			{
				if ($head =~ /^From:\s+(.*)$/i) { $from = $1; chomp($from);}
				elsif ($head =~ /^Subject:\s+(.*)$/i) { $subject = $1; chomp($subject);}
			}
			Irssi::print("From   : %W$from%n\nSubject: %W$subject%n");
  		}
	}
  
	$_mailcount{"$user\@$host"} = $count;
	$pop->quit();
	return 1;
}
sub start_check
{
	my ($userhost, $pass) = @_;
	my ($user, $host) = split(/\@/, $userhost);
	my $INTERVAL = Irssi::settings_get_int("pop3_interval");
	if (cmd_checkmail("$user;$pass;$host"))
	{
		$_mailchecktimer{"$user\@$host"} = Irssi::timeout_add($INTERVAL * 1000, 'cmd_checkmail', "$user;$pass;$host");
		Irssi::print("Account $user\@$host is now being monitored for new mail.");
	}
}

sub cmd_mail
{
	my $args = shift;
	my (@arg) = split(/\s+/, $args);

	if (($arg[0] eq "add") && $arg[1] && $arg[2])
	{
		if ($_mailchecktimer{$arg[1]})
		{
			Irssi::print("Account " . $arg[1] . " is already being monitored.");
		}
		else
		{
			start_check($arg[1], $arg[2]);
		}
	}
	elsif ($arg[0] eq "list")
	{
		Irssi::print("Active POP3 Accounts Being Monitored:");
		foreach (keys %_mailchecktimer)
		{
			Irssi::print(" %W-%n $_ ($_mailcount{$_} Mail message(s))");
		}
		Irssi::print("End of /mail list");
	}
	else
	{
		Irssi::print("%Wmailcheck.pl%n $VERSION - By KimmoKe\%W@%nircnet\n");
		Irssi::print("Usage:");
		Irssi::print("/mail add <user\@host> <password> - add account to be monitored.");
		Irssi::print("/mail remove <user\@host> - stop monitoring account");
		Irssi::print("/mail list - list monitored accounts");
		Irssi::print("/mail list <user\@host> - list ALL messages in mailbox");
		Irssi::print("\n%WNote:%n Passwords are kept in irssi's memory in %Wplain text%n, and the password will also remain in the command history. The POP3 authorization is currently also plain text.\n");
		Irssi::print("Check interval and POP3 login timeout are controlled with %W/set pop3_interval%n (default: 60 seconds) and %Wpop3_timeout%n (default: 30 seconds).");
	}


	
}


Irssi::settings_add_int("misc","pop3_timeout",30);
Irssi::settings_add_str("misc","pop3_interval","60");	
Irssi::command_bind('mail', 'cmd_mail');
