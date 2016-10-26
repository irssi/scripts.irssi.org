#!/usr/bin/perl -T
# Quizgr script for irssi with "KAOS" questions enabled, modified for greek too
# copyright Athanasius Emilius Arvanitis
# arvan@kronos.eng.auth.gr
# based on quiz.pl version 0.7
# Quiz script for irssi
# (C) Simon Huggins 2001
# huggie@earth.li

# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc., 59
# Temple Place, Suite 330, Boston, MA 02111-1307  USA
#
# DONE:
#       - support for many answers (not alternate though) per question
#       - support for hellenic (aka greek)
#       - remembers the questions that were answered (stores them in
#       ./wr/used_questions)
#       - if nobody says anything for a period of time, game ends
#       - added !repeat to repeat the question
#       - it wont crash if you smile!
# TODO:
#       - known bug: sometimes it ignores some people (they cant join etc).
#	if you join #CHANNEL and the bot is on #channel forget it...
#       - fix kaos hints
#       - if we have kaos, there should be more time to answer
#       - CLEAN up the code
# 	- Do something when people quit (remove from team, readd when rejoin?)

use strict;
use vars qw($VERSION %IRSSI);
    
use Irssi 20020217.1542 (); # Version 0.8.1 or perhaps get the most up to date irssi version
$VERSION = "0.7GR02";
%IRSSI = (
authors     => "Athanasius Emilius Arvanitis based on Simon Huggins quiz 0.7",
contact     => "arvan",
name        => "Quizgr",
description => "Turns irssi into a quiz bot. Has greek language and many answers support",
license     => "GPLv2",
url         => "http://kronos.eng.auth.gr/~arvan/irssi/",
changed     => "Tue Nov 26 13:37:59 EET 2002",
);

use Irssi::Irc;
use Data::Dumper;

Irssi::settings_add_str("misc","quiz_admin","jbg");
Irssi::settings_add_str("misc","quiz_passwd","stuff");
Irssi::settings_add_str("misc","quiz_file","$ENV{HOME}/.irssi/scripts/autorun/gr_quiz_questions");
Irssi::settings_add_str("misc","used_file","$ENV{HOME}/.irssi/scripts/autorun/wr/used_questions");

Irssi::settings_add_int("misc","quiz_qlength",70);
Irssi::settings_add_int("misc","quiz_hints",7);
Irssi::settings_add_int("misc","quiz_target_score",50);
Irssi::settings_add_int("misc","quiz_leave_concealed_chars",1);

Irssi::command("set cmd_queue_speed 2010");

{
# when warnings used $s complains
my $s;
my $answerBAKforCHAOS;

sub load_questions($$) {
	my ($game,$force) = @_;
	my $tag = $game->{'tag'};
	my $channel = $game->{'channel'};

	my $server = Irssi::server_find_tag($tag);

	if (!defined $server) {
		Irssi::print("Hrm, couldn't find server for tag ($tag) in load_questions");
		return;
	}

	return if $game->{'questions'} and not $force;

	#the next must be checked

	my $file = Irssi::settings_get_str("quiz_file");
	if (open(QS, "<", $file)) { #open for QS
		@{$game->{'questions'}}=sort <QS>;
		close(QS);
		Irssi::print("Loaded questions");

		my $file2 = Irssi::settings_get_str("used_file");
		if (open(QS2, "<", $file2)) { #open for QS2
			@{$game->{'used_questions'}}=sort <QS2>;
			close(QS2);

			#from perlfaq copy paste 
			@{$game->{'intersection'}} = @{$game->{'difference'}} = ();
			%{$game->{'count'}} = ();

			my $element;
			foreach $element (@{$game->{'questions'}}, @{$game->{'used_questions'}}) { ${$game->{'count'}}{$element}++ };

			foreach $element (keys %{$game->{'count'}}) { #open foreach
				push @{ ${$game->{'count'}}{$element} > 1 ? \@{$game->{'intersection'}} : \@{$game->{'difference'}} }, $element;
				} #close foreach

			my $ts = Irssi::settings_get_int("quiz_target_score");
			my $qCounter=@{$game->{'questions'}};
			${$game->{'usedCounter'}}=@{$game->{'used_questions'}};

			my $qGOT=($qCounter - ${$game->{'usedCounter'}}); 
			my $qNEEDED=(2*($ts)+12);
			Irssi::print("${$game->{'usedCounter'}} used out of $qCounter total questions");

			if ( $qGOT >= $qNEEDED ) { 
				@{$game->{'questions'}}=@{$game->{'difference'}};
				Irssi::print("Loaded not used questions");
				return 1;#used
				}

			if ( $qGOT < $qNEEDED ) { 
				@{$game->{'used_questions'}}=();
				Irssi::print("Clearing used questions");
				return 1;#used
				}
		} #close QS2

		return 1;#questions
		} #close QS

	  else {
		$server->command("msg $channel Can't find quiz questions, sorry.");
		return;
		}



}

sub start_game($) {
	my $game = shift;
	my $tag = $game->{'tag'};
	my $channel = $game->{'channel'};
	my $server = Irssi::server_find_tag($tag);

	if (!defined $server) {
		Irssi::print("Hrm, couldn't find server for tag ($tag) in start_game");
		return;
		}

	Irssi::timeout_remove($game->{'timeouttag'});
	undef $game->{'timeouttag'};

	if (!keys %{$game->{'teams'}}) {
		$server->command("msg $channel Sorry no one joined!");
		$game->{'state'} = "over";
		game_over($game);
		return;
		}

	$game->{'state'} = "game";

	$server->command("msg $channel Game starts now. Questions last ".
		Irssi::settings_get_int("quiz_qlength").
		" seconds and there are ".
		(Irssi::settings_get_int("quiz_hints")-1).
		" hints.  First to reach ".
		Irssi::settings_get_int("quiz_target_score")." wins.");
	next_question($game);
}

sub show_scores($) {
	my $game = shift;
	my $tag = $game->{'tag'};
	my $channel = $game->{'channel'};
	my $server = Irssi::server_find_tag($tag);

	if (!defined $server) {
		Irssi::print("Hrm, couldn't find server for tag ($tag) in show_scores");
		return;
		}

	my (@redscorers,@bluescorers);

	foreach my $score (sort keys %{$game->{'scores'}}) {
		if ($score =~ /^blue/) {
			$score =~ s/^blue//;
			push @bluescorers, "$score(".
				$game->{'scores'}->{"blue".$score}.")";
		} else {
			$score =~ s/^red//;
			push @redscorers, "$score(".
				$game->{'scores'}->{"red".$score}.")";
		}
	}

	$server->command("msg $channel 12Blue: ".$game->{'bluescore'}
		."  ".join(",",@bluescorers));
	$server->command("msg $channel 4Red: ".$game->{'redscore'}
		."  ".join(",",@redscorers));
	
	my $ts = Irssi::settings_get_int("quiz_target_score");

	if ($game->{'bluescore'} >= $ts or $game->{'redscore'} >= $ts) {
		if ($game->{'bluescore'} > $game->{'redscore'}) {
			$server->command("msg $channel 12Blue team wins ".
				$game->{'bluescore'}." to ".
				$game->{'redscore'});
		} else {
			$server->command("msg $channel 4Red team wins ".
				$game->{'redscore'}." to ".
				$game->{'bluescore'});
		}
		$game->{'state'}="over";
	} elsif ($game->{'state'} ne "over") {
		$game->{'state'}="pause";
		$server->command("msg $channel Next question in 6 20 seconds.");
		if ($game->{'timeouttag'}) {
			Irssi::timeout_remove($game->{'timeouttag'});
		}
		$game->{'timeouttag'} = Irssi::timeout_add(20000,
			"next_question",$game);
		$game->{'timeout'} = time() + 20;
	}
	game_over($game);
}

sub hint($) {
	my $game = shift;
	my $tag = $game->{'tag'};
	my $channel = $game->{'channel'};
	my $server = Irssi::server_find_tag($tag);

	if (!defined $server) {
		Irssi::print("Hrm, couldn't find server for tag ($tag) in hint");
		return;
		}

	return if game_over($game);
	if ($game->{'end'} <= time()) {
		$server->command("msg $channel Time's up.  The answer is: 2  ".$game->{'answer'});
		show_scores($game);
	} else {
		$game->{'hint'}++;
		my $num = $game->{'current_answer'} =~ s/\*/*/g;
		if ($num <= Irssi::settings_get_int("quiz_leave_concealed_chars")) {
			return;
			}

		my $pos = index($game->{'current_answer'},"*");
		if ($pos >= 0) {
			#$game->{'current_answer'} =~ s/\*/substr($game->{'answer'},$pos,1)/e;
			$game->{'current_answer'} =~ s/\*/substr($answerBAKforCHAOS,$pos,1)/e;
			}

		my $hinttime = $game->{'hint'}*$game->{'hintlen'};
		if ($hinttime != int($hinttime)) {
			$hinttime = sprintf("%.2f", $hinttime);
			}
		$server->command("msg $channel 2  $hinttime second hint: 6  ".
			$game->{'current_answer'});
	} #else end
}

sub game_over($) {
	my $game = shift;
	my $tag = $game->{'tag'};
	my $channel = $game->{'channel'};
	my $server = Irssi::server_find_tag($tag);

	if (!defined $server) {
		Irssi::print("Hrm, couldn't find server for tag ($tag) in game_over");
		return;
	}

	if ($game->{'state'} eq "over") {
		Irssi::timeout_remove($game->{'timeouttag'});
		undef $game->{'timeouttag'};
		undef $game->{'state'};
		undef $game->{'teams'};
		undef $game->{'scores'};

                #save used questions
                my $file2 = Irssi::settings_get_str("used_file");
                if (open(QS2, ">", $file2)) {
                        my $line;
			@{$game->{'used_questions'}}=sort @{$game->{'used_questions'}};
                        foreach $line (@{$game->{'used_questions'}}){
                                print QS2 $line ;
                                }
                        close(QS2);
                        Irssi::print("Saved used questions");
                        }


		$server->command("msg $channel Trivia is disabled.  Use !start or !trivon to restart.");
		return 1;
	}
	return;
}

sub next_question($) {
	my $game = shift;
	my $tag = $game->{'tag'};
	my $channel = $game->{'channel'};
	my $server = Irssi::server_find_tag($tag);

	if (!defined $server) {
		Irssi::print("Hrm, couldn't find server for tag ($tag) in next_question");
		return;
	}

	#check previous text time and
	#if noone says anything for 180 seconds end game
	if (defined $game->{'time_last_text'}) {
		my $diff2=time() - $game->{'time_last_text'};
		if ( $diff2 > 180) {
			$game->{'state'}="over";
		}
	}


	my $len = Irssi::settings_get_int("quiz_qlength")/
		Irssi::settings_get_int("quiz_hints");
	if ($game->{'timeouttag'}) {
		Irssi::timeout_remove($game->{'timeouttag'});
	}
	$game->{'timeouttag'} = Irssi::timeout_add($len*1000, "hint",$game);
	my $t = time();
	$game->{'timeout'} = $t + $len;
	$game->{'end'} = Irssi::settings_get_int("quiz_qlength")+$t;
	$game->{'hint'}=0;
	$game->{'hintlen'} = $len;
	if (!@{$game->{'questions'}}) {
		load_questions($game,1);
		if (!$game->{'questions'}) {
			$server->command("msg $channel Hmmm, no questions found sorry");
			$game->{'state'}="over";
		}
		Irssi::print("Questions looped");
	}
	return if game_over($game);

	#random question
	${$game->{'randIDX'}}= @{$game->{'questions'}};
	${$game->{'randIDX'}}=rand(${$game->{'randIDX'}});
	my $q = ${$game->{'questions'}}[${$game->{'randIDX'}}];
	${$game->{'the_question'}} = $q;

	#removing it from the questions
	splice (@{$game->{'questions'}}, ${$game->{'randIDX'}}, 1);

	#see faq for splice/random may be bad
	#my $q = splice(@{$game->{'questions'}},rand(@{$game->{'questions'}}),1);
	chomp $q;
	$q =~ s///;
	#($game->{'answer'} = $q) =~ s/^(.*)\|//;

	($game->{'question'}, $game->{'answer'}) = split(/\|/, $q,2);
	$answerBAKforCHAOS = $game->{'answer'};
	if ( $game->{'answer'} =~ /\|/ ) 
		{ $server->command("msg $channel KAOS CHAOS ×ÁÏÓ!!!"); 
			$game->{'answer'} = $game->{'answer'}."|";

		}
	$server->command("msg $channel 13Question: 10 $game->{'question'} ");
	#added Á-Ùá-ù so it can hide greek too
	($game->{'current_answer'} = $game->{'answer'}) =~ s/[a-zA-Z0-9Á-Ùá-ù]/*/g;
	#$q = s/^(.*)\|.*?$/$1/;
	$server->command("msg $channel Answer:  ".$game->{'current_answer'});
	$game->{'state'}="question";
}

sub invite_join($$) {
	my ($server,$channel) = @_;
	my $game = $s->{$server->{'tag'}}->{$channel};

	$server->command("msg $channel Team Trivia thingummie v($VERSION) starts in 1 minute.  Type 4!join red or 12!join blue");
	$game->{'timeouttag'} = Irssi::timeout_add(60000,"start_game",$game);
	$game->{'timeout'} = time()+60;
}

sub secstonormal($) {
	my $seconds = shift;
	my ($m,$s);

	$s = $seconds % 60;
	$m = ($seconds - $s)/60;
	return sprintf("%02d:%02d",$m,$s);
}

sub do_pubcommand($$$$) {
	my ($command,$channel,$server,$nick) = @_;
	my $game = $s->{$server->{'tag'}}->{$channel};

	$command = lc $command;
	$command =~ s/\s*$//;

	if ($command =~ /^!bang$/) {
		$server->command("msg $channel Dumping...");
		foreach (split /\n/,Dumper($s)) {
			Irssi::print("$_");
		}
	} elsif ($command =~ /^!trivon$|^!start$|!ðÜìå$/) {
		if ($s->{$server->{'tag'}}->{$channel}) {
			if ($s->{$server->{'tag'}}->{$channel}->{'state'}) {
				$server->command("msg $nick Trivia is already on.  Use !trivoff or !stop to remove it.");
				return;
			}
			#undef $s->{$server->{'tag'}}->{$channel};
		} else {
			# create structure magically
			$game = $s->{$server->{'tag'}}->{$channel} = {};
			$game->{'tag'} = $server->{'tag'};
			$game->{'channel'} = $channel;
		}
		$game->{'teams'}={};
		$game->{'redscore'} = 0;
		$game->{'bluescore'} = 0;
		load_questions($game,0);
		$game->{'state'} = "join";
		invite_join($server,$channel);
	} elsif ($command =~ /^!trivoff$|^!stop$|!öôÜíåé$/) {
		return if !$game->{'state'};
		$game->{'state'}="over";
		game_over($game);
	} elsif ($command =~ /^!join/) {
		if ($command =~ /^!join (red|blue)$/) {
			return if !$game->{'state'};
			$game->{'teams'}->{$nick}=$1;
			if ($1 eq "blue") {
				$server->command("notice $nick You have joined the 12Blue team");
			} else {
				$server->command("notice $nick You have joined the 4Red team");
			}
		}
	} elsif ($command =~ /^!teams/) {
		return if !$game->{'state'};
		my @blue=();
		my @red=();
		foreach (sort keys %{$game->{'teams'}}) {
			push @blue, $_ if $game->{'teams'}->{$_} eq "blue";
			push @red,  $_ if $game->{'teams'}->{$_} eq "red";
		}
		$server->command("msg $channel 12Blue: ".join(",",@blue));
		$server->command("msg $channel 4Red : ".join(",",@red));
	} elsif ($command =~ /^!repeat$/) {
		return if !$game->{'state'};
		$server->command("msg $channel Question is $game->{'question'}");
	} elsif ($command =~ /^!timeleft$/) {
		if ($game->{'state'} eq "join" and $game->{'timeout'}) {
			my $diff = $game->{'timeout'} - time();
			if ($diff > 0) {
				$server->command("msg $channel Time left: ".secstonormal($diff));
			} else {
				Irssi::print("Timeleft: $diff ??");
			}
		}
	}
}

sub do_command($$$) {
	my ($command,$nick,$server) = @_;

	$command = lc $command;
	$command =~ s/\s*$//;

	if ($command =~ /^!bang$/) {
		$server->command("msg $nick BOOM!");
	} elsif ($command =~ /^admin/) {
		if ($command !~ /^admin (.*)$/) {
			$server->command("msg $nick admin needs a nick to change the admin user to!");
		} else {
			Irssi::settings_remove("quiz_admin");
			Irssi::settings_add_str("misc","quiz_admin",$1);
			$server->command("msg $nick admin user is now $1");
		}
	} else {
		#$server->command("msg $nick Unknown command '$command'");
	}
}

#check check_answer for bad { }

sub check_answer($$$$) {
	my ($server,$channel,$nick,$text) = @_;
	my $game = $s->{$server->{'tag'}}->{$channel};

	return if not exists $game->{'teams'}->{$nick};

	#if $text exist check time and remembers it for end-game
	if (defined $text) {
		$game->{'time_last_text'} = time();
		}


	$text =~ s/\s*$//;
	$text =~ s/^ //;
	$text =~ s/ $//;
	
	#from cgi input-purify / try without it and it will crash with :( 
	#dont know if it needs em all, may check it in future
	
	if ($text =~ s/([\&;\`'\\\|"*?~<>^\(\)\[\]\{\}\$\n\r])/\\$1/g)
		{ $text="abcdef";
		}
	# is the above the reason it didnt join?

	#if greek supports troubles you comment the next
	$text =~ y/ÜÝÞßúÀüýûàþ¢¶¸¹ºÚ¼¾Û¿ÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÓÔÕÖ×ØÙ/áåçéééïõõõù¶áåçééïõõùáâãäåæçèéêëìíîïðñóôõö÷øù/;

	my $answerNOtonos = lc $game->{'answer'};
	#if greek supports troubles you comment the next
	$answerNOtonos =~ y/ÜÝÞßúÀüýûàþ¢¶¸¹ºÚ¼¾Û¿ÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÓÔÕÖ×ØÙ/áåçéééïõõõù¶áåçééïõõùáâãäåæçèéêëìíîïðñóôõö÷øù/;

	if ( $answerNOtonos =~ /\|/) { 

			if ( ($answerNOtonos =~ /\|$text\|/)||($answerNOtonos =~ /^$text\|/) ) 
			{
			$answerNOtonos =~ s/$text\|//;

	 		$game->{'answer'}=$answerNOtonos; 


			$server->command("msg $channel  2Correct answer by ".
			($game->{'teams'}->{$nick} eq "blue"?"12":"4").
			 $nick.": ".$text);

			$game->{$game->{'teams'}->{$nick}."score"}++;
			$game->{'scores'}->{$game->{'teams'}->{$nick}.$nick}++;

			if ($answerNOtonos eq "") { 

        			#putting it in used
				if (@{$game->{'used_questions'}}){
        			${$game->{'usedCounter'}} = @{$game->{'used_questions'}};
				} else {my ${$game->{'usedCounter'}}=0;}

        			${$game->{'used_questions'}}[${$game->{'usedCounter'}}]=${$game->{'the_question'}};

				$game->{'state'}="won";

				$server->command("msg $channel 2  $answerBAKforCHAOS") ;
				show_scores($game);
				return;
				}

			#show_scores($game);
			}
	}


                elsif (( $answerNOtonos !~ /\|/) && (lc $text eq $answerNOtonos))  {

			$server->command("msg $channel 2Correct answer by ".
			($game->{'teams'}->{$nick} eq "blue"?"12":"4").
			$nick.": ".$game->{'answer'});
			$game->{'state'}="won";

        			#putting it in used
				if (@{$game->{'used_questions'}}){
        			${$game->{'usedCounter'}} = @{$game->{'used_questions'}};
				} else {my ${$game->{'usedCounter'}} =0;}

        			${$game->{'used_questions'}}[${$game->{'usedCounter'}}]=${$game->{'the_question'}};

			$game->{$game->{'teams'}->{$nick}."score"}++;
			$game->{'scores'}->{$game->{'teams'}->{$nick}.$nick}++;
			show_scores($game);
			return;
		}



	my $show=0;
	my @chars = split //,$text;

	for (my $i=0; $i<length($game->{'answer'}); $i++) {
		if (lc $chars[$i] eq lc substr($game->{'answer'},$i,1)) {
			$show = 1 if substr($game->{'current_answer'},$i,1)
				eq "*";
			substr($game->{'current_answer'},$i,1) =
				substr($game->{'answer'},$i,1);
		}
	}

	$server->command("msg $channel Answer: ".$game->{'current_answer'})
		if $show;
}



sub event_privmsg {
	my ($server,$data,$nick,$address) = @_;
	my ($target, $text) = split / :/,$data,2;
	my ($command);

	if ($target =~ /^#/) {
		my $game = $s->{$server->{'tag'}}->{$target};
		if ($text =~ /^!/) {
			do_pubcommand($text,$target,$server,$nick);
		} elsif ($game->{'state'} eq "question") {
			check_answer($server,$target,$nick,$text);
		}
	} else {
		if ($nick ne Irssi::settings_get_str("quiz_admin")) {
			my ($passwd);
			($passwd, $command) = split /\s/,$text,2;
			if ($passwd ne Irssi::settings_get_str("quiz_passwd")) {
				#Irssi::print("$nick tried to do $command but got the password wrong.");
				Irssi::print("$nick got the password wrong.");
			}
		} else {
			$command = $text;
		}
		do_command($command,$nick,$server);
	}
}

sub event_changed_nick {
	my ($channel,$nick,$oldnick) = @_;
	my $server = $channel->{'server'};
	my $game = $s->{$server->{'tag'}}->{$channel->{'name'}};

	return if !$game->{'state'};
	
	my $nicktxt = $nick->{'nick'};
	if ($game->{'teams'}->{$oldnick}) {
		$game->{'teams'}->{$nicktxt} = $game->{'teams'}->{$oldnick};
		delete $game->{'teams'}->{$oldnick};
		}

}


}

Irssi::signal_add_last("event privmsg", "event_privmsg");
# Irssi::signal_add_last("massjoin", "sig_massjoin");
#Irssi::signal_add_last("message nick", "on_nick"); #when /nick
#Irssi::signal_add_last("message part", "on_part");
#Irssi::signal_add_last("message join", "on_join");
#Irssi::signal_add_last("message quit", "on_quit");

# Channel::nicks(channel) Return a list of all nicks in channel.

Irssi::signal_add("nicklist changed", "event_changed_nick");
