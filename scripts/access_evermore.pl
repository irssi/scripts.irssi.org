#  access_evermore.pl 
#    The script connects you to the textadventure 'The Lands of Evermore'.
#    See http://www.evermore.de/access_evermore.pl for more detail and a short 
#    introduction on how to play, or scroll to the bottom of the script
#
#  Originally developed by Jonas Kramer 2006
#  Comments added by Wolfgang Lohmann   2007
#  Name thanks to Randolf (Randi) Schultz, Ayam3d


#!/usr/bin/perl -w

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "20070110";
%IRSSI = (
	authors					=>	"Jonas Kramer",
	contact					=>	"jonas.kramer\@gmx.net",
	name					=>	"access_evermore.pl",
	description   	        =>	"IRSSI Mud Plugin, lets you play the textadventure Evermore within Irssi.",
	license					=>	"GPL",
	changed					=>	"$VERSION"
);

use Irssi;
use Net::Telnet;

our $windowName = "<Evermore>";
our $telnet = new Net::Telnet(Timeout => 10);

our $window = Irssi::Windowitem::window_create($windowName, 1);
$window->set_name($windowName);

$telnet->open("evermore.de");

Irssi::timeout_add(500, \&output, undef);
Irssi::signal_add("send command", \&sendcmd);

sub output {
	while(my $line = $telnet->getline(Timeout => 0, Errmode => "return")) {
		chomp($line);
		$window->print($line);
	}
}

sub sendcmd {
	$window->set_name($windowName);
	my $thisWindow = Irssi::active_win;
	if($thisWindow->{name} eq $windowName) {
		$telnet->print($_[0]);
		&output;
	}
}

=pod
access_evermore.pl - Playing Mud The Lands of Evermore with IRSSI
                     For more Info, check http://www.evermore.de/access_evermore.pl

Here comes a short intro:

Installing
 * copy it into ~/.irssi/scripts/
 * In rare cases, the Telnet-modul is missing: 
   in that case enter   perl -MCPAN -e 'install "Net::Telnet"' 
 * start irssi: irrsi
 * enter /script load access_evermore.pl, often /load access_evermore.pl does it.
   switch to the newly opened window (e.g. Alt+2), follow instructions on 
   the screen. Note: Character generation is somewhat irritating within 
   this plugin, though possible. You might use telnet mud.evermore.org 
   or a real client for that, if you're really confused in the menu.
 * it might be that the Telnet-modul is missing, 
   in that case enter: perl -MCPAN -e 'install "Net::Telnet"' 

Known Bugs/Issues:
   Evermore Introduction Dialog screens consist of an explanation and 
   explain the choices (assigned to numbers). As lines are send to IRSSI 
   only when telnet sends an End-of-Line, the plugin does not show the 
   Menu prompt, which asks for the choice you made.You will miss things 
   like 'Please press Enter to continue', 'Your choice (1,2,3, or Enter):',
   but this is something you should get on with.

Playing
   First of all, similar to IRC, you have commands and messages. There are two 
   modes:
   a) commands are unescaped, messages are sent using special commands (standard),
   b) commands are escaped, everything else is a message.

   Commands are used to control your avatar, messages are to communicate with 
   other players or non-player characters.

   You do not see your avatar. Instead, you look through its eyes. 
   The text received describes what your avatar is seeing (better think: 
   'what you are seeing').

   Your starting point is a room. Rooms correspond to channels, thus, channel 
   hopping is explicitely desired.To get a rough description of the room, type:

   [<Evermore>] look (or 'l' for short. We omit the Evermore-prompt from now.)

   The output will be like this (in case you chose to be human, attention >80chars/line):

17:58 -!- Irssi:           The place infront of Jaris' chapel of Mind and the royal university
17:58 -!- Irssi:           of Palanthas.
17:58 -!- Irssi:     |  |    Restricted by a big building to the south with a large portal to
17:58 -!- Irssi: -P--P--P- enter it, a small chapel to the east and some stores to the north
17:58 -!- Irssi:   \ | /|  and west side, an idyllic place spreads out in front of you. A white
17:58 -!- Irssi:    \|/ |  statue is standing in the middle of this place and southeastwards a
17:58 -!- Irssi: -I--@--I  very large white building can be seen between the houses. To the
17:58 -!- Irssi:    /|\    northeast and northwest you see the Queen Tamira Road, one of the
17:58 -!- Irssi:   / | \   main roads in Palanthas, as a possibility to leave this place.
17:58 -!- Irssi:  I  I  P-     There is a portal leading south.
17:58 -!- Irssi:           You can see eight exits: east, west, north, south, northwest,
17:58 -!- Irssi:               northeast, southwest and southeast.
17:58 -!- Irssi: Cassandro the apprentice Mage.

Left beside the description, you have a mini-map, but ignore it for now. 
First comes a summary, then the description, followed by a list of exits. 
From each room, you can access one or more other rooms using exits, typing 
'west' (or 'w') and similar to choose this direction. Last line gives those 
players and non-player characters ( NPCs, or bots one would say in IRC), 
who are standing right beside you. In this case, it is Cassandro. (Typing 
'who' gives a list of all (visible) players currently online.)
You can investigate things in more detail, e.g.

examine chapel (short: x chapel):

18:05 -!- Irssi: > It's only a small chapel built to sanctify Jaris. Like most of the buildings in
18:05 -!- Irssi: Palanthas it is white and its roof is covered with red bricks. A belfry raises
18:05 -!- Irssi: high up on the eastern side of the building. In front of the entrance you can
18:05 -!- Irssi: see two small trees, birches, as usual here.

The detail is dependend on how much the coder has invested (every player can 
become coder).
Your character can communicate and express feelings, e.g. 'say Hi' 
(short: ' ' Hi' (a quote)), and 'bow deep cass':

18:08 -!- Irssi: > You say in Erinn: hi
18:08 -!- Irssi: > [Announce:Logout] Mansor leaves this world.
18:09 -!- Irssi: > You bow deeply to Cassandro.

Erinn is your native tongue in this case.The computer takes care, that 
commands for feelings are adapted. E.g. Cassandro sees:

18:08 -!- Irssi: Al-ethly says in Erinn: hi
18:08 -!- Irssi: [Announce:Logout] Mansor leaves this world.
18:09 -!- Irssi: Al-ethly bows deeply to you.

Note, a third player would see:

18:09 -!- Irssi: Al-ethly bows deeply to Cassandro.

You might try 'lol', 'rotfl'. ('help soul' shows even more)
Messages said can be heard only by players beside you. If you want to send 
a question on the game or chat globally, you use the command

chat Hi, I am new!

, resulting in

18:15 -!- Irssi: > [Newbie:Al-ethly] Hi, I am new!

Note the brackets to mark it as a message on a channel (which can be switched 
off, btw.).

Maybe it is time now to set colour on to improve presentation of different 
information. Note, if you have black background, you also need to type set 
colour scheme black. This gives a different colour, if you see messages on 
a channel or some living around.

The next things you should do is to list your inventory with 'inventory', 
and 'examine <everthing>' you find.

You are able to carry a lot more, and you are carrying:
Weapons:
* A steel mace
Armours:
* A cloak
Miscellaneous:
* A bag
* A sheet labeled: type 'read sheet'
* A torch
* A pair of flintstones

If you 'read sheet', you get 100 experience points (besides of some 
information). You can see them with 'score stats':

> -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
Al-ethly the novice Priest
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Name         : Al-ethly       Race         : human
Profession   : Priest         Gender       : male
Guild        : Priest         Alignment    : neutral (0)
Experience   : 100

Level        : 2
Quests       : 0%             Prizes       : 0%
Monster      : 0%             Level of Exp : 1

Money        : no coins
Strength     : 19             Believer of  : None
Intelligence : 22             Height       : 6' 1"
Dexterity    : 18             Weight       : 252 lb
Constitution : 22             Vision       : normal vision
Charisma     : 19             Wimpy        : 150 Life Points threshold

First Login  : You entered this world on Monday, the fifteenth of July
               in the first year of the fire rat (Twenty-third year of
               the second age of Evermore)

Login Time   : 45 minutes 18 seconds.
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

As you might see in the score table, levels are formed not only from
Experience points received by killing innocent rabbits, but also by
* Monster points, identifying how many different monsters you have found 
  already,
* Prizes, which are given sparsely for deep examining areas and doing things 
  not necessarily necessary to reach a goal, and
* 1 Quests, adventures of different sizes.

This allows to level up to a certain points, without being forced only to 
kill or only to quest.

Besides, in Evermore, player killing is forbidden, as we have a socially 
and friendly atmosphere.

Before we give some commands in a list, we shortly show, how fighting is 
done here. Let's assume, you have managed to find the newbie area, which 
is usually sort of a park (depending on your starting town, see 'help races', 
and check the small town maps on this site.). First, 'wear all' and 'wield 
all', then 'look':

> You wear your cloak.
> You wield a mace in your left hand.

\|/ |
 O  O   The municipal park.
  \ |      This seems to be the town park around you. You see nothing but
   \|   well-trimmed bushes, the path you're walking on and the usual park
    @   animals which quickly hide themselves.
    |   You can see three exits: north, northwest and south.
    |
    P-
A rat.
A squirrel.
Two doves.

Use 'estimate rat' to see, whether you have a real chance to win a fight:

> You look at the rat very closely.
It seems to be neutral.
It is around 0' 4" large and weighs less than 1 lb.
It is of race Rat.
It may be very much worse at attacking.
A rat's defense seems to be much worse.
A rat's constitution is much worse.
A rat's strength and dexterity are much worse.
It is in a very good condition.

Ok, it looks as we might have a chance. Note, that in the beginning, the 
avatar is weak, and has not developed powerful skills yet, not to speak 
of the poor weapons. Therefore, the rat might have a real chance, if you 
try to 'kill rat':

> You turn to attack a rat!
> You punch a rat's head with your right hand.
You miss a rat with your mace.
You kick a rat's torso with your left foot.
You punch a rat's abdomen with your right hand.
You crush a rat's torso with your mace.
The rat gets a large bruise on its torso.
You miss a rat with your right foot.
The rat misses you with its front right foot.
The rat misses you with its back left foot.
The rat misses you with its front left foot.
You have 239 [240] Life Points and 240 [240] Mind Points.
You crush a rat's front right leg with your mace.
You punch a rat's front right leg with your right hand.
You kick a rat's front right foot with your left foot.
You miss a rat with your right hand.
You crush a rat's front left foot with your mace.
You miss a rat with your right foot.
You punch a rat's torso with your right hand.
The rat gets a large bruise on its torso.
You crush a rat's front right leg with your mace.
Suddenly, the rat goes slack and doesn't move anymore.
You killed a rat.
You have 240 [240] Life Points and 240 [240] Mind Points.
[Announce:Login] Gloin enters this world.
[Announce:Login] Kortha (new player) enters this world.
[Announce:Login] Kortha begins his real life.

While the fight is going on, the messages are thrown on the screen, and 
soon you will develop a sense for action... especially, when you see your
life points going down. You relax faster, if you eat and drink. Now, 
'examine corpse':

This is the dead body of a rat.
It contains:
* 2 copper coins.

and 'get all from corpse':

You take 2 copper coins from the corpse of a rat.
The corpse of a rat rots completely away.

(Yes, it is possible to define aliases). Sometimes your get furs, or 
nothing.Furs you can sell, to buy you a beer and have a chat with some friends.

Ok, this should suffice for the very first steps. Do not hesitate to ask on 
the global channel, if you have questions, using 'chat How can I do this and
that...'. However, hints for quests, of course, are not topic of such channels..
Finally, here some of the most interesting commands for the beginning:
 - help, help basics, help professions, help score,help trader:
     Help system, sort of man pages, with lots of information about how to 
     play and how certain things work.
 - score, score skills, score health, score equipment, score colour, ... 
     Several kinds of information. Note, that the skills are just the basic 
     set. You will learn more depending on race, profession and level. Skills 
     increase by doing.
 - inventory, i
     shows your inventory ( you might try 'read sheet', 'wear all')
 - n,s,w, enter, etc. 
     Move around to different rooms.
 - who, say 'msg', tell Cassandro 'msg', chat 'msg'
     shows available players, says something to the room, long distance-tell, 
     global chat-channel message
 - finger 'name' 
     gives some extra information about some player
 - alias 'shortcut' 'long version' 
     defines a shortcut to be used instead of a long version. Note, never 
     use s,n, or other direction names, or you wont be able to walk around.
 - me 'some emote', : 'some emote' 
     adds the emote string to your name, but remember, we have the soul, 
     which is better!
The interesting thing is, that every place can define new actions, thus, you 
can find much more commands than already given in the 'help' section.

Problems playing
 * It is too dark to see anything. 
   - You probably have normal (daylight) vision, and an oil lamp in your 
     inventory. 'light lamp' might help.
 * It is much too bright to see anything. 
   - You probably have infra (night) vision, and probably a blindfold in your
     inventory. 'wear blindfold' should help
 * Nobody reacts on my 'say'ing! 
   - Probably, you stand alone (check with 'look'). To talk globally, 
     use 'chat msg'. Others might be away or idle, check with 'who'. Some 
     might even work besides, in the MUD or in RL.
 * Do not know how to 'cha' right now. 
   - Maybe you mistyped the command?
 * Could not find any help for you....
   - maybe you have mistyped the keyword or try plural/singular form.
=cut
    
