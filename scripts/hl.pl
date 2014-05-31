# CopyLeft Riku Voipio 2001
# half-life bot script
use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI);

# header begins here

$VERSION = "1.2";
%IRSSI = (
        authors     => "Riku Voipio",
        contact     => "riku.voipio\@iki.fi",
        name        => "half-life",
        description => "responds to \"!hl counterstrike.server \" command on channels/msg's to query counter-strike servers",
        license     => "GPLv2",
        url         => "http://nchip.ukkosenjyly.mine.nu/irssiscripts/",
    );


$qdir="/home/nchip/qstat/";

sub cmd_hl {
        my ($server, $data, $nick, $mask, $target) =@_;
	if ($data=~/^!hl/){
		@foo=split(/\s+/,$data);
		$len=@foo;
		if ($len==1){
		    $foo[1]="turpasauna.taikatech.com";
		}
		#fixme, haxxor protection
		$word=$foo[1];
		$_=$word;
		$word=~s/[^a-zA-ZäöÄÖ0-9\.]/ /g;
		open(DAT, "$qdir"."qstat -hls ".$word."|");
		$count=0;
		foreach $line (<DAT>)
		{
			if ($count==1)
			{
				$_=$line;
				$line=~s/\s+/ /g;
				#print($line);
				$server->command("/notice ".$target." ".$line);
			}
			$count++;
		}
		close(DAT);
	}
}

Irssi::signal_add_last('message public', 'cmd_hl');
Irssi::print("Half-life info bot by nchip loaded.");


