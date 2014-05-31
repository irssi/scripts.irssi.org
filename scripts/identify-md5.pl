use Irssi;
use Digest::MD5 qw(md5_hex);
use strict;
use vars qw($VERSION %IRSSI @identify @reop);

$VERSION = '1.05';
%IRSSI = (
    authors 	=> 'Eric Jansen',
    contact 	=> 'chaos@sorcery.net',
    name 	=> 'identify-md5',
    description => 'MD5 NickServ identification script for SorceryNet',
    license 	=> 'GPL',
    modules	=> 'Digest::MD5',
    url		=> 'http://xyrion.org/irssi/',
    changed 	=> 'Sat Mar  1 13:32:30 CET 2003'
);

################################################################################
#
#  MD5 NickServ identification script for SorceryNet (irc.sorcery.net)
#
#  The script will do several things:
#  - It adds the command /identify-md5 to Irssi, which can be used to identify
#    to your current nickname or a list of nicknames given as arguments using 
#    the passwords provided below
#  - It will automatically issue this command whenever NickServ notices you 
#    that you need to identify (e.g. after a services outage)
#  - It will remember any channels ChanServ deopped you in and try to regain 
#    ops after authentication is accepted by NickServ
#
#  For more information on SorceryNets MD5 identification see:
#  http://www.sorcery.net/help/howto/MD5_identify
#
#  Put your nicknames and MD5-hashed passwords here:
#

my %nicknames = (
    lc('nick1')		=> md5_hex('password1'), 		# Plain text password 'password1'
    lc('nick2')		=> '6cb75f652a9b52798eb6cf2201057c73',	# MD5-hash of password 'password2'
    lc('nick3')		=> md5_hex('password3')
);

#
#  Please note: This file should NOT be world-readable. Although it's (quite) 
#               impossible to get the original passwords from the hashes, a
#               malicious person can identify using the hash and then change
#               your password without knowing the old password.
#
################################################################################

sub cmd_identify {

    my ($data, $server, $witem) = @_;

    # Are we connected?
    if(!$server || !$server->{'connected'}) {

	Irssi::print("Not connected to a server.");
	return;
    }

    # Did the user specify what nick(s) to identify to?
    if($data ne '') {

	# Store the list of nicknames to identify to then
	@identify = split /\s+/, $data;
    }
    else {

	# Or put our current nick on the list
	push @identify, $server->{'nick'};
    }

    # Start with some checks
    for(my $i = $#identify; $i >= 0; $i--) {

	# If we don't know the password
	if(!defined $nicknames{lc $identify[$i]}) {

	    # Send an error
	    Irssi::print("I do not know the password for ${identify[$i]}. Please add it to identify-md5.pl.");

	    # And remove the nick from the list
	    splice @identify, $i, 1;
	}
    }

    # Let's ask NickServ for a cookie if there are nicks left
    $server->command("QUOTE NickServ identify-md5") if $#identify >= 0;
}

sub event_notice {

    my ($server, $text, $nick, $address) = @_;

    # Just ignore it if we are not on SorceryNet
    return unless $server->{'real_address'} =~ /\.sorcery\.net$/;

    # Is it a notice from NickServ?
    if($nick eq 'NickServ') {

	# Is it a cookie and do we need one?
	if($text =~ /^205 S\/MD5 1\.0 (.+)$/ && $#identify >= 0) {

	    my $cookie = $1;

	    my $nickname = lc shift @identify;
	    my $password = $nicknames{$nickname};

	    # Create the hash and send it
	    my $hash = md5_hex("$nickname:$cookie:$password");
	    $server->command("QUOTE NickServ identify-md5 $nickname $hash");

	    # Suppress the notice from NickServ
	    Irssi::signal_stop();

	    # And get a new cookie if there are still nicks left to identify to
	    $server->command("QUOTE NickServ identify-md5") if $#identify >= 0;
	}

	# Is it a response?
	elsif($text =~ /^\d{3} \- (.+)$/) {

	    my $response = $1;

	    # Just print the text-part and suppress the notice
	    Irssi::print($response);

	    if($response eq 'Authentication accepted -- you are now identified.') {

		foreach my $channel (@reop) {
		    $server->command("QUOTE ChanServ $channel op $server->{nick}");
		}
		undef @reop;
	    }

	    Irssi::signal_stop();
	}

	# Do we know the password? Let's see what NickServ has to tell us then
	elsif(defined $nicknames{lc $server->{'nick'}}) {
	
	    # Identify when NickServ asks us to
	    if($text =~ /^This nick belongs to another user\./) {

		$server->command("identify-md5");
		Irssi::signal_stop();
	    }

	    # Just ignore this notice, we already identify when receiving the other one
	    elsif($text eq 'If this is your nick please try: /msg NickServ ID password') {

		Irssi::signal_stop();
	    }
	}
    }

    # If it's ChanServ saying it just deopped us, remember the channel so we can reop
    elsif($nick eq 'ChanServ' && $text =~ /^You are not allowed ops in ([^\s]+)$/) {

	push @reop, $1;

	Irssi::signal_stop();
    }
}

Irssi::command_bind('identify-md5', 'cmd_identify');
Irssi::signal_add('message irc notice', 'event_notice');
