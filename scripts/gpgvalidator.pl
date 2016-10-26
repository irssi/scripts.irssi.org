#                              _ _     _       _             
#   __ _ _ __   __ ___   ____ _| (_) __| | __ _| |_ ___  _ __ 
#  / _` | '_ \ / _` \ \ / / _` | | |/ _` |/ _` | __/ _ \| '__|
# | (_| | |_) | (_| |\ V / (_| | | | (_| | (_| | || (_) | |   
#  \__, | .__/ \__, | \_/ \__,_|_|_|\__,_|\__,_|\__\___/|_|   
#  |___/|_|    |___/ 
#
#				for irssi - VERSION 0.1.2
#
# this is a nice irssi's script coded by pallotron
# based on a lovely implementation writed by valvoline for xchat client
# 
# valv`0 (valvoline@vrlteam.org / valvoline@freaknet.org)
# pallotron (pallotron@freaknet.org)
# 
# original idea & implementation  by: valv'0
#
# valv`0 thanx goes to:
# asbesto, pallotron, quest, iron - for the development support
# hellbreak, cmcsynth, hio, mircalla - for the moral support
# 
# it allows you to do gpg trusting of your friends using gnupg and irc
# capabilities. in order to use it, you have to load the script into irssi
# (read man pages or go to irssi.org do know how do this). others users must
# have loaded this script or another compatible script.
#
# FAKE--
# PARANOIA!++ o/
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# USAGE:
# If you want to trust a your friend you must do this:
# 1) simply type /validate <your_friend_nick>
# 2) accept DCC Send (a chunck file containing gpg sign)
# 3) type /verify <your_friend_nick>:)
#
# To permit your trusting by other users you must do:
# 1) type /setpass <your_gpg_passphrase>
# 2) enjoy!
# Now your irssi is listening for ctcp messages
#
# WARING!!!!!!!
# this isn't a *FULL SECURE* script, better improvements must follow *SOON*!
#
# pallotron 23/09/2002 - pallotron@freaknet.org - www.freaknet.org
 
use Irssi;
use Irssi qw(command_bind active_server);

use strict;

use vars qw($VERSION %IRSSI);

my $PASS = "NULL";
my $VALIDATEDIR = "~/";

$VERSION = "0.1.2";
%IRSSI = (
	authors=> 'original idea by valvoline, irssi porting by pallotron',
	contact=> 'pallotron@freaknet.org',
	name=> 'gpgvalidator v. 0.1.2',
	description=> 'Have gpg-based trusting features in your irssi client!',
	license=> 'GPL v2',
	url=> 'http://www.freaknet.org/~pallotron',
);

Irssi::print("Loading irssi pallotron's porting of valvoline gpgvalidator 0.1.2");

# create a new irssi command called /PASSPHRASE
# USAGE:
# /PASSPHRASE <your_GPG_pass>
Irssi::command_bind('setpass','setpass');

# create a new irssi command called /VERIFY
# no particolare USAGE FORMAT
# just call it with /VERIFY
# it will verify the last <NICK>.asc file
# download by the latest ctcp VALIDATE request
Irssi::command_bind('verify','sub_verify');

# send a ctcp VALIDATE request to a friend we want to trust
#
# USAGE: /validate <nick>
Irssi::command_bind('validate','send_ctcp_request');

# hook sub_validate function to signal 'ctcp msg'.
# when your client receives /ctcp msg <your_nick> VALIDATE
# it will performs some controls and then send, via DCC, a randomic 
# generated chunck file (yournick.asc) containing your gpg signature
# to $nick (the user who had request validating)
Irssi::signal_add('ctcp msg','ctcp_send_chunck_file');

Irssi::command_bind('about','about');
Irssi::command_bind('greets','greets');
Irssi::command_bind('manual','manual');
Irssi::command_bind('erasepass','erasepass');

sub send_ctcp_request {
    my $line = shift;
    if(!($line)) {
    	Irssi::print("validate - wrong parameters:\nusage:    validate <nick>");
	return 0;
    }
    active_server->command("/ctcp $line VALIDATE");
    return 0;
}

sub erasepass {
    $PASS="";
    Irssi::print("gpgvalidator - pass forgotten");
    return 0;
}

sub ctcp_send_chunck_file {
    my ( $infos, $cmd, $nick, $host, $target) = @_;

    my $test = $target;

    $test =~ tr/\W/_/;
    $test =~ tr/`/_/;
    $test =~ tr/{/_/;
    $test =~ tr/}/_/;
    $test =~ tr/|/_/;
    $test =~ tr/\\/_/;
    
    if ( $cmd =~ /^VALIDATE/) {
        if ( $PASS =~ /NULL/i ) {
	    Irssi::print("requested GPG-VALIDATE from $nick, but no passphrase in cache!\nplz, set a passphrase with /passphrase <your_gpg_pass>");
	    return 1;
	} else {
	    Irssi::print("requested GPG-VALIDATE from $nick\n");
            my $result = `openssl rand -out $VALIDATEDIR/$test 1024`;
            $result = `echo "$PASS" | gpg --batch --yes --status-fd 1 --passphrase-fd 0 --output $VALIDATEDIR/$test.asc --clearsign $VALIDATEDIR/$test | grep "[GNUPG:]"`;
    	    if (( my $i = index($result,"GOOD_PASSPHRASE")) > -1) {
                active_server->command("/DCC send $nick $VALIDATEDIR/$test.asc");
                $result = `echo "$result" | grep "SIG_CREATED"`;
                Irssi::print("\n$result\n");
	    }
	    if (( my $i = index($result,"BAD_PASSPHRASE")) > -1) {
                $result = `echo "$result" | grep "BAS_PASSPHRASE"`;
                Irssi::print("$result\nBAD passphrase - cannot unlock your secret keyring - please set a passprase with /passphrase <yourpass>\n");
            }   
	}
	return 0;
    }
}	    

# this take the passphrase
# OH MY GOD! THESE ARE VERY STUPID ROWS...
# expecially from security side... :)
sub setpass {
    my $line = shift;
    if(!($line)) {
    	Irssi::print("setpass - wrong paramaters:\nusage:   setpass <yourpass>");
	return 0;
    }
    $PASS = $line;
    # can i do better of this? ;p
    Irssi::print("gpgvalidator - pass set correctly");
    return 0;
}

# this verify che <nick>.asc signed file trusting if the user
# is in your keyring
#
# usage /verify <nick>
# 
sub sub_verify {

    my $result = "";
    my $test = shift;

    if(!($test)) {
    	Irssi::print("verify wrong parameters:\nusage:   verifi <nick>");
	return 0;
    }
    
    $test =~ tr/\W/_/;
    $test =~ tr/`/_/;
    $test =~ tr/{/_/;
    $test =~ tr/}/_/;
    $test =~ tr/|/_/;
    $test =~ tr/\\/_/;
    
    $result = `gpg --batch --status-fd 1 --verify $VALIDATEDIR/$test.asc  2>/dev/null | grep "[GNUPG:]"`;
    if (( my $i = index($result,"GOODSIG")) > -1) {
        $result = `echo "$result" | grep "GOODSIG"`;
        Irssi::print("good signature! - user trusted - $result\n");
    }
    else {
        Irssi::print("bad signature! - user UNtrusted\n$result\n");
    }
    return 0;
}

sub about {
        Irssi::print("\n-------------------------------------------------------\nGPG validator v0.1.2 for irssi coded in perl by pallotron\n-------------------------------------------------------\n(c) 2002 - valvoline / VRL Team - valvoline\@vrlteam.org\nported to irssi by pallotron\@freaknet.org\n-------------------------------------------------------\nthis's a simple script to validate users under irc, \nusing gpg. there're NO optimization, and the code was\nwritten in 10mins!. i'm not a perl-programmer, so...\n...fill free to make mods to the code, but, leave the\noriginal credits at the same place (=\n\ntype /greets to see greets!\n\ntype /manual to see user-manual\n");
    return 1;
}

sub greets {
        Irssi::print("\n-------------------------------------------------------\ngreets fly out to the following:\nasbesto, pallotron, iron, quest - for beta testing support.\nhellbreak, cmcsynth, hio, mirc4ll4 - for moral and economic support (ehehe).\ns0ftpj staff - for the besta coding support ever made.\n\nall the other, that i've forgotten...sorry! :(\n\n-------------------------------------------------------\n");
        return 1;
}

sub manual {
        Irssi::print("\n-------------------------------------------------------\n\nmanual\n\nsetpass <pass> - to cache your password for the current session.\nerasepass - to forgot current password.\nvalidate <nick> - to request a validator-chunck to nick.\nverify <nick> - to verify the received validator-chunck of nick.\n\nbe sure, to have the DCC workin' correctly\n\n-------------------------------------------------------\n");
        return 1;
}


