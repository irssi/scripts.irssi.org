# dice / A RP Dice Simulator
#
# What is this?
#
# I often Dungeon Master on our Neverwinternights Servers called "Bund der
# alten Reiche" (eng. "Alliance of the old realms") at bundderaltenreiche.de
# (German Site) Often idling in our Channel I thought it might be Fun to have 
# a script to dice. Since I found nothing for irssi I wrote this little piece
# of script. The script assumes, that if a 'd' for english dice is given it 
# should print the output in english. On the other hand if a 'w' for german 
# "Würfel" is given it prints the output in german. 
#
# Usage.
#
# Anyone on the Channel kann ask "!dice" to toss the dice for him. He just has
# to say what dice he want to use. The notation should be well known from
# RP :-) Thus
# 
# Write: !dice: <quantity of dice>d[or w for german users]<sides on dice>
#
# Here are some examples
# 
# !dice: 2d20
# !dice: 3d6
#
# OK, I think you got it already :-)
#
# Write: !dice version 
# For Version Information
#
# Write: !dice help
# For Information about how to use it

use strict;
use vars qw($VERSION %IRSSI);

use Irssi qw(command_bind signal_add);
use IO::File;
$VERSION = '0.00.04';
%IRSSI = (
	authors			=> 'Marcel Kossin',
	contact			=> 'mkossin@enumerator.org',
	name			=> 'dice',
	description		=> 'A Dice Simulator for Roleplaying in Channels or just for fun.',
	license			=> 'GNU GPL Version 2 or later',
	url			=> 'http://www.enumerator.org/component/option,com_docman/task,view_category/Itemid,34/subcat,7/'	
);

sub own_question {
	my ($server, $msg, $nick, $address, $target) = @_;
	question($server, $msg, $nick, $target);
}

sub public_question {
	my ($server, $msg, $nick, $address, $target) = @_;
	question($server, $msg, $nick, $target);
}

sub question($server, $msg, $nick, $target) {
	my ($server, $msg, $nick, $target) = @_;
	$_ = $msg;
	
	if (!/^!dice/i) { return 0; }

	if (/^!dice:.+[d|w]\d+/i) {
		my $value;
		my $rnd;
		my $forloop;
		my $sides;
		my $lang;
		my @dice  = split(/ /,$_,2);
		my @dices = split(/[d|w|D|W]/,$dice[1],2);
		if ($_ = /^.*[w|W].*/i) {
			$lang = "DE";
		} else {
			$lang = "EN";
		}					
		SWITCH: {
			if ($lang eq "DE") {
				$server->command('msg '.$target.' '.$nick.' würfelt mit dem '.$dice[1].'..... ');
				last SWITCH; 
			}
			if ($lang eq "EN") {
				$server->command('msg '.$target.' '.$nick.' tosses with the '.$dice[1].'..... ');
				last SWITCH; 
			}					
		}		
		if($dices[1] > 1) {
			if($dices[1] < 100) {			
				if($dices[0] < 11) {		
					if($dices[0] < 1) {
						$dices[0] = 1;
					}
					for($forloop = 1; $forloop <= $dices[0]; $forloop++) {
						$rnd = int(rand($dices[1]-1));
						if($rnd == 0){
							$rnd = $dices[1];
						}
						$value = $value + $rnd;
						SWITCH: {
							if ($lang eq "DE") {
								$server->command('msg '.$target.' '.$nick.' würfelt beim '.$forloop.'. Wurf eine '.$rnd);	
								last SWITCH; 
							}
							if ($lang eq "EN") {
								$server->command('msg '.$target.' '.$nick.' tosses at his '.$forloop.'. try  a '.$rnd);	
								last SWITCH; 
							}					
						}						
			   	}
					SWITCH: {
						if ($lang eq "DE") {
							$server->command('msg '.$target.' '.$nick.' ist fertig mit Würfeln. Sein Ergebnis lautet: '.$value);	
							last SWITCH; 
						}
						if ($lang eq "EN") {
							$server->command('msg '.$target.' '.$nick.' finished. His result reads: '.$value);	
							last SWITCH; 
						}					
					}						
				} else {
					SWITCH: {
						if ($lang eq "DE") {
							$server->command('msg '.$target.' '.$nick.' meint wohl in d'.$dices[1].'´s baden zu müssen... Mal im Ernst versuch es mit weniger Würfeln!' );	
							last SWITCH; 
						}
						if ($lang eq "EN") {
							$server->command('msg '.$target.' '.$nick.' seems to wanna take a bath in d'.$dices[1].'´s... Seriously! Try less dice' );	
							last SWITCH; 
						}					
					}					
				}
			} else {
				SWITCH: {
					if ($lang eq "DE") {
						$server->command('msg '.$target.' '.$nick.' baut uns bald einen riiiiiesigen d'.$dices[1].'... Mal im Ernst versuch es mit weniger Augen!' );	
						last SWITCH; 
					}
					if ($lang eq "EN") {
						$server->command('msg '.$target.' '.$nick.' soon will build us a biiiiiiiiiig d'.$dices[1].'... Seriously! Try less sides' );	
						last SWITCH; 
					}					
				}				
			}
		} else {
			if($dices[1] == "0") {
				SWITCH: {
					if ($lang eq "DE") {
						$server->command('msg '.$target.' '.$nick.' ist dumm wie Knäckebrot... Oder hat jemand schonmal einen Würfel ohne Seiten gesehen?' );	
						last SWITCH; 
					}
					if ($lang eq "EN") {
						$server->command('msg '.$target.' '.$nick.' is chuckleheaded... Or has anybody ever seen a dice without sides?' );	
						last SWITCH; 
					}					
				}				
			}
			if($dices[1] == "1") {		
				SWITCH: {
					if ($lang eq "DE") {
						$server->command('msg '.$target.' '.$nick.' ist dumm wie Dosenthunfisch... Oder hat jemand schonmal einen Würfel mit einer Seite gesehen?' );	
						last SWITCH; 
					}
					if ($lang eq "EN") {
						$server->command('msg '.$target.' '.$nick.' plays possum... Or has anybody ever seen a dice with only one side?' );	
						last SWITCH; 
					}					
				}				
			}				
		}		
		return 0;
	} elsif (/^!dice: version$/i){
		$server->command('msg '.$target.' dice Version: '.$VERSION.' by mkossin');
		return 0;
	} elsif (/^!dice: help$/i){
		$server->command('msg '.$target.' '.$nick.' Please explain which dice you want to toss: "!dice: <quantity of dice>d<sides on dice>" e. g. "!dice: 2d20"');
		return 0;
	} elsif (/^!dice: hilfe$/i){
		$server->command('msg '.$target.' '.$nick.' Sag mir welchen Würfel du werfen möchtest: "!dice: <Anzahl der Würfel>w<Augen des Würfels>" z. B. "!dice: 2w20"');
		return 0;						
	} else {
		if(!/^!dice.*:/i){ 
			$server->command('msg '.$target.' '.$nick.' "!dice: help"  - gives you the english help');
			$server->command('msg '.$target.' '.$nick.' "!dice: hilfe" - zeigt die Deutsche Hilfe an');
			return 0;
		}
	}
}

signal_add("message public", "public_question");
signal_add("message own_public", "own_question");
