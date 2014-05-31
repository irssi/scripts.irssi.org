use Irssi;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '0.0.2';
%IRSSI = (
	authors     => 'Koenraad Heijlen',
	contact     => 'vipie@ulyssis.org',
	name        => 'word_scramble',
	description => 'A script that scrambles all the letters in a word except the first and last.', 
	license     => 'GNU GPL version 2',
	url         => 'http://vipie.studentenweb.org/dev/irssi/wordscramble',
	changed     => '2003-09-15'
);

#--------------------------------------------------------------------
# Changelog
#--------------------------------------------------------------------
#
# word_scramble.pl 0.0.2 (2003-09-17)- Koenraad Heijlen
# 	- fixed the four letter word bug
# 	- fixed the non alphanummeric characters bug
# 	- some improvement in returning \n
#
# word_scramble.pl 0.0.1 (2003-09-15) - Koenraad Heijlen
# 	- first draft
# 
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# Public Variables
#--------------------------------------------------------------------
my %myHELP = ();


#--------------------------------------------------------------------
# Help function
#--------------------------------------------------------------------
sub cmd_help { 
	my ($about) = @_;

	%myHELP = (
		ws => "
ws - wordscramble 

scrambles the text you type, and outputs it in the current (active) channel
or query.
",
);

	if ( $about =~ /(ws)/i ) { 
		Irssi::print($myHELP{$1});
	} 
}

#--------------------------------------------------------------------
# scrambles one word
#--------------------------------------------------------------------
sub scrambleWord {
	# 0 : first
	# length : last-1
	# length+1 : last
	#substr EXPR,OFFSET,LENGTH,REPLACEMENT
	my $l = 0;
	my $r = 0; 
	my $out = "";
	my $word = shift;
	chomp($word);

	if (length($word) <= 3) {
		return $word;
	}
	my $l = length($word)-2;
	$l = $l;
	$out = substr($word,0,1);
	while ($l != 1) {
		$r = int(rand()*$l+1);

		if ($r == 0) {
			next;
		}
		#$r == $l is no marginalcase.

		$out .= substr($word,$r,1);
		substr($word,$r,1,substr($word,$l,1));
		$l--;
	}
	$out .= substr($word,$l,1);
	$out .= substr($word,length($word)-1,1);
	return $out;
}

#--------------------------------------------------------------------
# scrambles line
#--------------------------------------------------------------------
sub scrambleLine{
	my $line = shift;
	my $outline = "";
	my $word = "";
	my $i=0;
	my @splitLine;
	
	#we leave the \n at the end, less interference.
	#chomp($line);
	@splitLine=split(/(\W)/,$line);
	
	# every other item in the array is the split string
	for ($i=0; $i<= $#splitLine;$i++) {
		$outline .= scrambleWord($splitLine[$i]);
		$i++;
		if ($i <= $#splitLine) {
			$outline .= $splitLine[$i]; 
		}
	}
	return $outline;
}

#--------------------------------------------------------------------
# Defintion of /ws
#--------------------------------------------------------------------
sub cmd_ws {
	my ($args, $server, $witem) = @_;

	if (!$server || !$server->{connected}) {
		Irssi::print("Not connected to server");
		return;
	}

	my $scrambledLine = scrambleLine($args);
	if ($witem && ($witem->{type} eq "CHANNEL" ||
			$witem->{type} eq "QUERY")) {
		# there's query/channel active in window
		$witem->command("MSG ".$witem->{name}." $scrambledLine");
	} else {
		Irssi::print("Nick not given, and no active channel/query in window");
	}
}

#--------------------------------------------------------------------
# Irssi::Settings / Irssi::command_bind
#--------------------------------------------------------------------

Irssi::command_bind("ws", "cmd_ws", "Scramble Line");
Irssi::command_bind("help","cmd_help", "Irssi commands");

#--------------------------------------------------------------------
# This text is printed at Load time.
#--------------------------------------------------------------------

#nothing

#- end
