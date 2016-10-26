# Some code taken from `nickserv.pl' for convenience.
# Credits Sami Haahtinen / ZaNaGa
#

# Don't forget to create the necessary chatnets in your irssi config file.
# 
# Example:
# ....
# {
#   address = "irc.undernet.org";
#   chatnet = "Undernet";
#   port = "6668";
#   autoconnect = no;
#  }
# .....
#
# 
# Then connect with the server like this:
# /server undernet (or set autoconnect to yes)

# Make sure you fill in *all* necessary information without typos.
#
# Files you need to edit after first run:
# x.users     -> For your x user/pw information.
# x.channels  -> Channels to join after authing. (optional)
#
# Use /xrehash to reload if you edit the files.
#
# Var:
# my (%masks) -> See help there.

# Tested with X versions
# Undernet P10 Channel Services II Release 1.1pl7
# 

#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
# COPYING (included with this distribution) or the GNU General Public
# License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#

use Irssi;
use Irssi::Irc;

use strict;

use vars qw($VERSION %IRSSI);

$VERSION = '1.02';

%IRSSI = (
    authors     => 'Toshio R. Spoor',
    contact     => 't.spoor@gmail.com',
    name        => 'xauth',
    description => 'Undernet X Service Authentication Program',
    license     => 'GNU GPLv2 or later',
    changed     => '$Date: 2004/12/17 08:39:47 $'
);

my (%CONFIG) = (
    autostart	=> '',
    autojoin	=> '',
    hiddenhost	=> ''
);

Irssi::theme_register([
  xauth_rehash    => '{comment $0} %KRehashing configuration files and settings%n',
  xauth_autostart => '{comment $0} %KAuto-Start :%n $1',
  xauth_autojoin  => '{comment $0} %KAuto-Join  :%n $1',
  xauth_hiddenhost=> '{comment $0} %KHiddenhost :%n $1',
  xauth_auth      => '{comment $0} %KAuthorising%n $1 %Kwith%n $2 %Kon%n $3',
  xauth_load      => '{comment $0} %KScript %nv$1 %Kloaded ...%n',
  xauth_nocon     => '{comment $0} %KNot connected to server%n',
  xauth_noconn    => '{comment $0} %KThere does not exist a connection to $1%n',
  xauth_success   => '{comment $0} %KLogged in successfully on %n$1',
  xauth_failed    => '{comment $0} %KFailed to login on %n$1 ($2)',
  xauth_already   => '{comment $0} %KI am already logged in on%n $1',
  xauth_nouser    => '{comment $0} $1 %Kdoes not know who %n$2 %Kis on %n$3',
  xauth_nohost    => '{comment $0} %KNo hostmask found for %n$1%K, to fix this edit this script, see masks',
  xauth_noentry   => '{comment $0} %KI did not find an entry for %n$1 %Kcheck%n $2',
  xauth_missing   => '{comment $0} %KI am missing username, password or authentication host login information%n',
  xauth_join      => '{comment $0} %KJoined on%n $1%K : %n$2-'
]);

my ($usage) = qq!X-Authentication v$VERSION by Toshio Spoor

Usage:
/auth <chatnet>

Settings:
/set xauth                      Shows current settings
/toggle xauth_autostart         Toggle Auto Start
/toggle xauth_autojoin          Toggle Auto Join
/toggle xauth_hiddenhost        Toggle Hiddenhost (ircu u2.10.11+)

Rehashing settings and user/channel file:
/xrehash                        Run this after any changes
                                made to settings/files
                                
/save                           Make settings permanent
!;

# The `masks' hash is very important:
# Here we fill in the masks we need to authenticate with. 
#
# <chatnet> = <host> <authhost>
#
# You can find this very easily:
# /msg x login
#
# 08:49 -!- Irssi: Starting query in Undernet with x
# 08:49 <Foo> login
# 08:49 -X(channels@undernet.org)- To use LOGIN, you must /msg X@services.undernet.org
#
# Keep the chatnet lowercase

my (%masks) = (       
       undernet    => [ 'cservice@undernet.org', 'X@channels.undernet.org' ],
       worldirc    => [ 'cservice@worldirc.org','X@channels.worldirc.org' ]
);

# 0 = None
# 1 = Normal
# 2 = More

my ($verbose) = 1;

# Don't touch these, unless the signature changes.
#
my ($success) = "AUTHENTICATION SUCCESSFUL";
my ($already) = "Sorry, You are already authenticated";
my ($failed)  = "AUTHENTICATION FAILED";
my ($remind)  = "Remember: Nobody from CService will ever ask you for your password, do NOT give";
my ($nouser)  = "I don't know who";

# Global Vars, don't change these.
# 
my ($x_passfile) = Irssi::get_irssi_dir() ."/x.users";
my ($x_chanfile) = Irssi::get_irssi_dir() ."/x.channels";

my (@users) = (); 
my (@chans) = ();

# Core Code
#
# 

sub putlog() {

        my ($window) = Irssi::active_win();
	Irssi::print("[$IRSSI{'name'}] @_", MSGLEVEL_CLIENTNOTICE);
	
}

sub haltdef() {

        Irssi::signal_stop();

}

sub conn($) {

        my ($server) = @_;

        if (!$server || !$server->{connected}) {
                return 0;
        } else {
        	return 1;
        }

}

sub join_channels($) {
	
        my ($chatnet)  = @_;
        my (@channels) = ();
        my ($server)   = Irssi::server_find_tag($chatnet);
        
        if (!$server) {
        	Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_nocon", "$IRSSI{'name'}");
        	return;
        }
                         
        foreach (@chans) {
        	
                my ($channel, $ircnet) = split(/:/);
                
                if (lc($chatnet) eq lc($ircnet)) {                
                	# If we do it like this, the status window stays active.
                	push (@channels, $channel);
                	$server->send_raw("JOIN #$channel");
                }
        }
        
        if ($verbose) {
        	if (@channels) {
        		Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_join", "$IRSSI{'name'}", $chatnet, @channels);
	        }
	}
}

sub mask_check($) {
	
	my ($address) = @_;
	
	foreach my $key (keys %masks) {
		if (lc($masks{$key}->[0]) eq lc($address)) {
			return $key;
			last;
		}
        }
	
	return 0;
	
}


sub event_notice() {

        my ($server, $args, $nick, $nickad) = @_;
               
	return unless (&mask_check($nickad));
	
        my ($cnet) = $server->{'tag'};
        my ($version) = $server->{'version'};
        
        my ($target, $data) = $args =~ /^(\S*)\s+:(.*)$/;
        
        $_ = $data;

        if (/^$already/i) { 
                Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_already", "$IRSSI{'name'}", $cnet);
                &haltdef();
        }

        if (/^$success/i) {         
                Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_success", "$IRSSI{'name'}", $cnet);
                
                if (($version) && ($CONFIG{'hiddenhost'})) {
                	
        		my($app,$hi,$lo) = $version =~ /^(..).(..).(..)/;
        		$app =~ s/\D//g;
        		
        		if (($app >= 2) && ($lo >= 11)) {
        			&putlog("Found ircu $version, setting umode +x") if ($verbose > 1);
        			$server->command("mode $target +x");
        		}
        	}
        	
                if ($CONFIG{'autojoin'}) {
                	&join_channels($cnet);
                }
                &haltdef();
        }

        if (/^$failed/i) {
                if (/\((.*?)\)/) { $args = $1 };
                Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_failed", "$IRSSI{'name'}", $cnet, $args);
                &haltdef();
        }
        
        if (/^$remind/i) {
                &haltdef();
        }
        
        if (/^$nouser/i) {
        	if (/who\s(.*?)\s/) { $args = $1 };
        	Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_nouser", "$IRSSI{'name'}", "$nick", $args, $cnet);
        	&haltdef();
        }
}

sub cmd_auth() {

        my ($data, $server, $witem) = @_;
        my ($username, $ircnet, $password, $xlogin, $xmask, $chatnet, $found);

        if ($data) {
                $chatnet = $data;
        } else {
                &putlog("$usage");
                return;
        }
        
        if (! &conn($server)) { 
                Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_nocon", "$IRSSI{'name'}");
                return;
        }

        my ($authserver) = Irssi::server_find_tag($chatnet);

        if (! $authserver) {
                Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_noconn", "$IRSSI{'name'}", $chatnet);
                return;
        }

        foreach (@users) {

                ($username, $ircnet, $password) = split(/:/);

                if (lc($ircnet) eq lc($chatnet)) {
                        $xmask  = $masks{lc($ircnet)}->[0];
                        $xlogin = $masks{lc($ircnet)}->[1];
                        
                        if ((!$xmask) || (!$xlogin)) {
                        	Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_nohost", "$IRSSI{'name'}", $chatnet);
                        	return;
                        }
                        
                        $found=1;
                        last;
                }
        }

        if (! $found ) {
                Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_noentry", "$IRSSI{'name'}", $chatnet, qq/"$x_passfile"/);
                return;
        }

        if (($username) && ($password) && ($xlogin)) {
                Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_auth", "$IRSSI{'name'}", $username, $xlogin, $chatnet);
                $authserver->send_raw("PRIVMSG $xlogin :login $username $password");
        } else {
                Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_missing", "$IRSSI{'name'}");
        }
}

# Code taken from nickserv.pl

sub read_users() {
        my $count = 0;
                
        # Lets reset @users so we can call this as a function.
        @users = ();            
                        
        if (!(open XUSERS, "<", $x_passfile)) {
                &create_users;
        };
       	&putlog("Running checks on the userfile.") if ($verbose > 1);
        # first we test the file with mask 066 (we don't actually care if the
        # file is executable by others.. what could they do with it =)

        # Well, according to my calculations umask 066 should be 54, go figure.
        
        my $mode = (stat($x_passfile))[2];
        if ($mode & 54) {
                &putlog("your password file should be mode 0600. Go fix it!");
                &putlog("use command: chmod 0600 $x_passfile");
        }
        
        # and then we read the userfile.
        # apparently Irssi resets $/, so we set it here.

        local $/ = "\n";
        while( my $line = <XUSERS>) {
                if( $line !~ /^(#|\s*$)/ ) { 
                        my ($nick, $ircnet, $password) = 
				$line =~ /^\s*(\S+)\s+(\S+)\s+(.*?)$/;
                        push @users, "$nick:$ircnet:$password";
                        $count++;
                }
        }
       	&putlog("Found $count accounts") if ($verbose > 1);
        close XUSERS;
}

sub create_users() {

        &putlog("Creating basic userfile in $x_passfile. Edit File.");
        
        if(!(open XUSERS, ">", $x_passfile)) {
               &putlog("Unable to create file $x_passfile");
        }

        print XUSERS "# username and IrcNet Tag are case insensitive\n";
        print XUSERS "#\n";
        print XUSERS "# username      IrcNet Tag      Password\n";
        print XUSERS "# --------      ----------      --------\n";

        close XUSERS;
        chmod 0600, $x_passfile;
}

sub create_chans() {
        &putlog("Creating basic channelfile in $x_chanfile. Edit File.");
        if(!(open NICKCHANS, ">", $x_chanfile)) {
                &putlog("Unable to create file $x_chanfile");
        }

        print NICKCHANS "# This file should contain a list of all channels\n";
        print NICKCHANS "# which you don't want to join until after you've\n";
        print NICKCHANS "# successfully identified with x.  This is\n";
        print NICKCHANS "# useful if you have a hidden host (+x).\n";
        print NICKCHANS "# Enter Channel without `#'\n";
        print NICKCHANS "#\n";
        print NICKCHANS "# Channel       IrcNet Tag\n";
        print NICKCHANS "# --------      ----------\n";

        close NICKCHANS;
        chmod 0600, $x_chanfile;
}

sub read_chans() {
        my $count = 0;

        # Lets reset @users so we can call this as a function.
        @chans = ();

        if (!(open NICKCHANS, "<", $x_chanfile)) {
                create_chans;
        };
       	&putlog("Running checks on the channelfile.") if ($verbose > 1);
        # first we test the file with mask 066 (we don't actually care if the
        # file is executable by others.. what could they do with it =)
        
        # Well, according to my calculations umask 066 should be 54, go figure.

        my $mode = (stat($x_chanfile))[2];
        if ($mode & 54) {
                &putlog("your channels file should be mode 0600. Go fix it!");
                &putlog("use command: chmod 0600 $x_chanfile");
        }
        
        # and then we read the channelfile.
        # apparently Irssi resets $/, so we set it here.

        local $/ = "\n";
        while( my $line = <NICKCHANS>) {
                if( $line !~ /^(#|\s*$)/ ) { 
                        my ($channel, $ircnet) = 
                                $line =~ /\s*(\S+)\s+(\S+)/;
                        push @chans, "$channel:$ircnet";
                        $count++;
                }
        }
       	&putlog("Found $count channels") if ($verbose > 1);
        close NICKCHANS;
}

# End code from nickserv.pl

sub event_connect() {

	$CONFIG{'autostart'}  = Irssi::settings_get_bool('xauth_autostart');

	return unless ($CONFIG{'autostart'});
	
        my ($server) = @_;
        my ($cnet) = $server->{'tag'};
        my ($found);
        
        foreach my $key (keys %masks) {
        	if (lc($key) eq lc($cnet)) {
        		$found=1;
        		last;
        	}
	}

	return unless($found);

        $server->command("auth $cnet");

}

sub x_rehash() {
	
	Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_rehash", "$IRSSI{'name'}") if (($verbose) && (@_));
	
	&read_users();
	&read_chans();
	&get_set(@_);
	
}

sub init_set() {

	Irssi::settings_add_bool('misc', 'xauth_autostart', '0');
	Irssi::settings_add_bool('misc', 'xauth_autojoin',  '1');
	Irssi::settings_add_bool('misc', 'xauth_hiddenhost','0');	
		
}

sub onoff($) {
	
	my ($value) = @_;
	
	if ($value) {
		return "On";
	} else {
		return "Off";
	}	
	
}

sub get_set() {
	
	$CONFIG{'autostart'}  = Irssi::settings_get_bool('xauth_autostart');
	$CONFIG{'autojoin'}   = Irssi::settings_get_bool('xauth_autojoin');
	$CONFIG{'hiddenhost'} = Irssi::settings_get_bool('xauth_hiddenhost');
	
	Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_autostart", "$IRSSI{'name'}", &onoff("$CONFIG{'autostart'}"))   if (($verbose) && (@_));
	Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_autojoin",  "$IRSSI{'name'}", &onoff("$CONFIG{'autojoin'}"))    if (($verbose) && (@_));
	Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_hiddenhost", "$IRSSI{'name'}", &onoff("$CONFIG{'hiddenhost'}")) if (($verbose) && (@_));
	
}

sub init() {

	&init_set();
	&x_rehash();

	
}

sub x_help() {
	
	&putlog("$usage");
	
}


# Main
#
#

&init();

Irssi::command_bind("auth", "cmd_auth");
Irssi::command_bind("xrehash", "x_rehash");
Irssi::command_bind("xhelp", "x_help");

Irssi::signal_add("event notice", "event_notice");
Irssi::signal_add("event connected", "event_connect");

Irssi::printformat(MSGLEVEL_CLIENTNOTICE, "xauth_load", "$IRSSI{'name'}", $VERSION);
