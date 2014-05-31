use Irssi;
use Irssi::Irc;

use vars qw($VERSION %IRSSI);
$VERSION = "0.2";
%IRSSI = ( 
           authors         => "Csaba Nagy",
	   contact         => "lordpyre\@negerno.hu",
	   name            => "listen",
	   description     => "A simple mp3 display script that will display what mp3 you are playing in which software (mpg123, xmms, mp3blaster, etc) to your active channel or to a query window.",
	   license         => "GNU GPLv2 or later",
	   changed         => "Tue Nov 26 19:55:04 CET 2002"
);

# Usage: 1, load the script
# 	 2, personalize the settings
# 	 	- listen_use_action -> if "on" the script will issue an action 
# 	 		to let otherones know what you are listening to
# 	 		if "off" it will use a simple msg
# 	 	- listen_prefix -> the output of the script will look like:
# 	 		'/me $listen_prefix $listen_tagorder' if the
# 	 		mp3file has idtags. otherwise the output will be:
# 	 		'/me $listen_prefix $mp3filename'
# 	 	- listen_tagorder -> the perfect order of the tags? ;)
# 	 		for example: '%ARTIST (%ALBUM) - %TITLE (%PLAYER)'
# 	 		you can specify: %TITLE, %ALBUM, %ARTIST, %GENRE,
# 	 				 %COMMENT, %PLAYER
# 	 3, use /listen
# 	 4, have phun =)
#
# Programs needed:
# 	- lsof - ftp://vic.cc.purdue.edu/pub/tools/unix/lsof
# 	- id3 - http://frantica.lly.org/~rcw/id3/
# LordPyre


# list of supported mp3 players
# if you would like to use the script with other players, just type these
# name into the list below... it will probably work :)
@mp3players=("mpg123", "mpg321", "xmms", "mp3blaster", "alsaplayer");

################## PLZ DON'T CHANGE ANYTHING BELOW THIS LINE ##################
# or do it on your own risk!! 

sub default_values {
	$mp3player="nope";
	$mp3file="nope";
	%idtag=("Title",  "Unknown Title",
		"Album",  "Unknown Album",
		"Artist", "Unknown Artist",
		"Genre",  "Unknown Genre",
		"Comment","No Comment");
}

sub getmp3filename {
	open(CSOCS,$_[0]);
	GECMO: while (<CSOCS>) {
		chop;
		(@line) = split(/\s/,$_);
		# we check wheter the mp3file returned by lsof has been opened
		# with a known mp3player or not
		HMM: foreach $w (@mp3players) {
			# if yes we save it, and leave
			if ($w =~ /^$line[0]/) {
				$mp3player=$w;
				last HMM;
				}
			}
		# if we have found one player 'turned on', we don't have to
		# check the other results of lsof, so we can leave
		if ($mp3player ne "nope") {
			$mp3file=$line[$#line];
			last GECMO;
			}
		}
	close(CSOCS);
}

sub getmp3proces {
	# most of the players put the file into the memory at first,
	# let's try to catch it there, first
	getmp3filename("/usr/sbin/lsof -d mem | grep -i .mp3|");
	# if we didn't find anything there, we check the fds for mp3s
	if ($mp3player eq "nope") {
		getmp3filename("/usr/sbin/lsof -d 1-15 | grep -i .mp3|");
	}
	
	# hmm are we listening to anything?
	if ($mp3player eq "nope") {
		Irssi::print("Hmm are you listening to anything? (possibly not supported mp3player)");
		return 0;
	}
	
	# the only problem can happen to us, if the string we got from lsof
	# isn't a real mp3file (this may happen for example if there are \x20
	# chars in the filename). so let's check it!
	if (!(-e $mp3file && -r $mp3file)) { 
		Irssi::print("Damn! Nonexistent filename. (maybe spaces in it?)");
		return 0;
	}
	return 1;
}

sub getmp3idtags {
	# getting the idtags from file
	open(ID3GECMO, "/usr/bin/id3 -R -l \"$mp3file\" |");
	while (<ID3GECMO>) {
		chop;
		foreach $kulcs (keys %idtag) {
			if ($_=~ /^$kulcs/) {
		        	s/^$kulcs://; s/\s*$//;	s/^\s*//;
				if ($_)	{ $idtag{$kulcs}=$_; }
				}
			}
		}
	close(ID3GECMO);
}

sub do_listen {

	#setting up variables
	my ($data, $server, $witem) = @_;
	default_values();
	if (!getmp3proces()) { return };
	getmp3idtags();

	# if there's no usable idtag in the mp3 we use the filename
	if (($idtag{"Artist"} eq "Unknow Artist") && ($idtag{"Title"} eq "Unknown Title")) { 
		$outtext=$mp3filename;
	} else {
		# if the file is tagged we parse over the tagorder
		$outtext=Irssi::settings_get_str("listen_tagorder");
		foreach $w (keys %idtag) {
			$outtext=~s/%$w/$idtag{$w}/i;
			}
		$outtext=~s/%player/$mp3player/i;
	}
	
	$prefix=Irssi::settings_get_str("listen_prefix");
	
	if (Irssi::settings_get_bool("listen_use_action")) {
		$outtext="ME ".$prefix." ".$outtext;
	} else {
		$outtext="MSG ".$witem->{name}." ".$prefix." ".$outtext;
		}
	# let's write the result to everyone
        if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {
        	$witem->command($outtext);
		}
}

# setting irssi enviroments
Irssi::command_bind("listen", "do_listen");
Irssi::settings_add_bool("listen","listen_use_action",1);
Irssi::settings_add_str("listen","listen_prefix","is listening to");
Irssi::settings_add_str("listen","listen_tagorder","%ARTIST (%ALBUM) - %TITLE (%PLAYER)");

print CLIENTCRAP "%B>>%n ".$IRSSI{name}." v".$VERSION." loaded... (command: /listen)";
