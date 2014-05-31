#8-ball / decision ball
#
#What is this?
#
#The 8-ball (Eight-ball) is a decision ball which i bought
#in a gadget shop when i was in London. I then came up with 
#the idea to make an irc-version of this one :)
#There are 16 possible answers that the ball may give you.
#
#
#usage   
#
#Anyone in the same channel as the one who runs this script may
#write "8-ball: question ?" without quotes and where question is
#a question to ask the 8-ball. 
#An answer is given randomly. The possible answers are the exact
#same answers that the real 8-ball gives.
#
#Write "8-ball" without quotes to have the the ball tell you
#how money questions it've got totally.
#
#Write "8-ball version" without quotes to have him tell what
#his version is.
#
#
use strict;
use vars qw($VERSION %IRSSI);

use Irssi qw(command_bind signal_add);
use IO::File;
$VERSION = '0.20';
%IRSSI = (
	authors		=> 'Patrik Jansson',
	contact		=> 'gein@knivby.nu',
	name		=> '8-ball',
	description	=> 'Dont like to take decisions? Have the 8-ball do it for you instead.',
	license		=> 'GPL',
);

sub own_question {
	my ($server, $msg, $target) = @_;
	question($server, $msg, "", $target);
}

sub public_question {
	my ($server, $msg, $nick, $address, $target) = @_;
	question($server, $msg, $nick.": ", $target);
}
sub question($server, $msg, $nick, $target) {
	my ($server, $msg, $nick, $target) = @_;
	$_ = $msg;
	if (!/^8-ball/i) { return 0; }

	if (/^8-ball:.+\?$/i) {
		my $ia = int(rand(16));
		my $answer = "";
		SWITCH: {
		 if ($ia==0) { $answer = "Yes"; last SWITCH; }
		 if ($ia==1) { $answer = "No"; last SWITCH; }
 		 if ($ia==2) { $answer = "Outlook so so"; last SWITCH; }
		 if ($ia==3) { $answer = "Absolutely"; last SWITCH; }
		 if ($ia==4) { $answer = "My sources say no"; last SWITCH; }
	 	 if ($ia==5) { $answer = "Yes definitely"; last SWITCH; }
		 if ($ia==6) { $answer = "Very doubtful"; last SWITCH; }
	 	 if ($ia==7) { $answer = "Most likely"; last SWITCH; }
		 if ($ia==8) { $answer = "Forget about it"; last SWITCH; }
		 if ($ia==9) { $answer = "Are you kidding?"; last SWITCH; }
		 if ($ia==10) { $answer = "Go for it"; last SWITCH; }
		 if ($ia==11) { $answer = "Not now"; last SWITCH; }
		 if ($ia==12) { $answer = "Looking good"; last SWITCH; }
		 if ($ia==13) { $answer = "Who knows"; last SWITCH; }
		 if ($ia==14) { $answer = "A definite yes"; last SWITCH; }
		 if ($ia==15) { $answer = "You will have to wait"; last SWITCH; }
		 if ($ia==16) { $answer = "Yes, in due time"; last SWITCH; }
       		 if ($ia==17) { $answer = "I have my doubts"; last SWITCH; }
		}
		$server->command('msg '.$target.' '.$nick.'8-ball says: '.$answer);
	  
                my ($fh, $count);
                $fh = new IO::File;
                $count = 0;
                if ($fh->open("< .8-ball")){
                        $count = <$fh>;
                        $fh->close;
                }
                $count++;
		$fh = new IO::File;
                if ($fh->open("> .8-ball")){
                        print $fh $count;
                        $fh->close;
                }else{
                        print "Couldn't open file for output. The value $count couldn't be written.";
                	return 1;
		}
		return 0;
	} elsif (/^8-ball$/i) {
             
		my ($fh, $count);
                $fh = new IO::File;
                $count = 0;
                if ($fh->open("< .8-ball")){
                        $count = <$fh>;
                        $server->command('msg '.$target.' 8-ball says: I\'ve got '.$count.' questions so far.');
			$fh->close;
                }else{
                        print "Couldn't open file for input";
			return 1;
                }
		return 0;

	} elsif (/^8-ball version$/i){
		$server->command('msg '.$target.' My version is: '.$VERSION);
		return 0;
	} else {
		if(!/^8-ball says/i){ 
			$server->command('msg '.$target.' '.$nick.'A question please.');
			return 0;
		}
	}

}

signal_add("message public", "public_question");
signal_add("message own_public", "own_question");
