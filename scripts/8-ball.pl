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
use warnings;
use vars qw($VERSION %IRSSI);

use Irssi qw(command_bind signal_add);
use IO::File;
$VERSION = '0.22';
%IRSSI = (
	authors		=> 'Patrik Akerfeldt',
	contact		=> 'patrik.akerfeldt@gmail.com',
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
sub question {
	my ($server, $msg, $nick, $target) = @_;
	$_ = $msg;
	if (!/^8-ball/i) { return 0; }

	if (/^8-ball:.+\?$/i) {
		# From: "The 8-Ball Answers", http://8ball.ofb.net/answers.html
		my @answers = (
				'Signs point to yes.',
				'Yes.',
				'Reply hazy, try again.',
				'Without a doubt.',
				'My sources say no.',
				'As I see it, yes.',
				'You may rely on it.',
				'Concentrate and ask again.',
				'Outlook not so good.',
				'It is decidedly so.',
				'Better not tell you now.',
				'Very doubtful.',
				'Yes - definitely.',
				'It is certain.',
				'Cannot predict now.',
				'Most likely.',
				'Ask again later.',
				'My reply is no.',
				'Outlook good.',
				'Don\'t count on it.'
		);

		$server->command('msg '.$target.' '.$nick.'8-ball says: '.$answers[rand @answers]);
	  
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
