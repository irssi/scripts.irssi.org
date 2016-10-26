use strict;
use Irssi 20020300;
use 5.6.0;
use Socket;
use POSIX;

use vars qw($VERSION %IRSSI %HELP);
$HELP{sms} = "
SMS <handle or phone number> <text>

Sends sms to handle from addressbook (see HELP addsms and listsms)
or phone number.
";
$HELP{addsms} = "
ADDSMS <handle> <phone number>

Adds 'handle' with phone 'phone number' to addressbook,
or change phone number of existing handle.
";
$HELP{delsms} = "
DELSMS <handle or number from listsms>

Deletes entry from addressbook.
";
$HELP{listsms} = "
LISTSMS [handle match]

Lists addressbook.
";
$VERSION = "1.5b";
%IRSSI = (
        authors         => "Maciek \'fahren\' Freudenheim",
        contact         => "fahren\@bochnia.pl",
        name            => "SMS",
        description     => "/ADDSMS, /DELSMS, /LISTSMS and /SMS - phone address-book with smssender, for now supports only Polish operators",
        license         => "GNU GPLv2 or later",
        changed         => "Fri Jan 10 03:54:07 CET 2003"
);

Irssi::theme_register([
	'sms_sending', '>> Sending SMS to %_$0%_ /$1/',
	'sms_sent', '>> Message to %_$0%_ has been sent.',
	'sms_esent', '>> Message $1/$2 to %_$0%_ has been sent.',
	'sms_notsent', '>> Message to %_$0%_ has %_NOT%_ been sent.',
	'sms_enotsent', '>> Message $1/$2 to %_$0%_ has %_NOT%_ been sent.',
	'sms_stat', '>> Total of %_$0%_ entries: %_$1%_ from PLUS, %_$2%_ from ERA, %_$3%_ from IDEA.',
	'sms_listline', '[%W$[!-2]0%n]%| $[9]1%_:%_ $2 /$[-4]3/',
]);

# Chanelog:
## version 1.5b
# $ENV{HOME}/.irssi -> Irssi::get_irssi_dir
## version 1.5
# - added new prefixes
## version 1.4
# - sorting /smslist
# - do not lowercasing handles
## version 1.3
# - fixed smsfork(), ifork()
# - added help
## version 1.2d
# - ... more ERA() fixes
## version 1.2c
# - added parsing of 'request cannot be processed at this time' in IDEA()
# - added [act/total] in ERA() split messages
## version 1.2b
# - more fixes in ERA() messages spliting
## version 1.2
# - fixed long message spliting in ERA()
## version 1.1
# - fixed IDEA()
# - inf. ifork() loop fixed (found by Lam)
# - fixed regex matching in /delsms, /listsms and /sms
# - changed kill() to POSIX::_exit()
## version 1.0
# - forking before sending SMS

my $smssender = getlogin || getpwuid($<) || "anonymous";
my $smsfile = Irssi::get_irssi_dir . "/smslist";
my (@smslist, $fh, %ftag);

sub cmd_sms {
	my ($target, $text) = split(/ +/, $_[0], 2);
	my $window = Irssi::active_win();
	my $phone;

	if ($text eq "") {
		Irssi::print("Usage: /SMS <handle or phone number> <text>");	
		return;
	}

	if (isnumber($target)) {
		if ($phone = corrnum($target)) {
			my $net = smsnet($phone);
			$window->printformat(MSGLEVEL_CLIENTNOTICE, 'sms_sending', smsnum($phone), $net);
			&$net($phone, $text) unless &smsfork;
		} else {
			Irssi::print("%R>>%n Wrong number.");
		}
	} else {
		my $i = 0;
		my $handle = lc($target);
		my $all = $handle eq "*"? 1 : 0;
		for my $sms (@smslist) {
			next unless ($all || lc($sms->{handle}) eq $handle);
			$i++;
			my $net = smsnet($sms->{phone});
			$window->printformat(MSGLEVEL_CLIENTNOTICE, 'sms_sending', $sms->{handle}, $net);
			&$net($sms->{phone}, $text) unless &smsfork;
		}
		Irssi::print("%R>>%n Can't find %_$target%_ in address book.") unless $i;
	}
}

sub cmd_addsms {
	my ($handle, $num) = split(/ +/, $_[0], 2);
	my $phone;
	
	unless ($phone = corrnum($num)) {
		Irssi::print("Usage: /ADDSMS <handle> <phone number>");
		return;
	}

	for my $sms (@smslist) {
		if (lc($sms->{handle}) eq lc($handle)) {
			Irssi::print(">> Changing phone number for %_$handle%_ /to $phone/");
			$sms->{phone} = $phone;
			&savesms;
			return;
		}
	}
	my $sms = {};
	$sms->{handle} = $handle;
	$sms->{phone}  = $phone;
	Irssi::print(">> Adding %_$handle%_ with num %_$phone%_.");
	push @smslist, $sms;
	&savesms;
}

sub cmd_delsms {
	my $handle = shift;

	if ($handle eq "") {
		Irssi::print("Usage: /DELSMS <handle or number from listsms>");
		return;
	}
	
	my @num;
	$handle = lc($handle);
	
	if ($handle =~ /^[0-9]+$/) {
		push @num, $handle - 1;
	} else {
		my $all = $handle eq "*"? 1 : 0;
		@smslist = sort { lc($a->{handle}) cmp lc($b->{handle}) } @smslist;
		for (my $i = 0; $i < @smslist; $i++) {
			push @num, $i if ($all || lc($smslist[$i]->{handle}) eq $handle);
		}
	}
	for my $n (reverse(@num)) {
		if (my($sms) = splice(@smslist, $n, 1)) {
			Irssi::print(">> Deleted %_$sms->{handle}%_.");
		}
	}
	
	&savesms;
}

sub cmd_listsms {
	my $match = shift || "*";
	my $window = Irssi::active_win();
	
	if (@smslist == 0) {
		Irssi::print("%R>>%n Your SMSLIST is empty.");
		return;
	}
	my $all = $match eq "*"? 1 : 0;
	@smslist = sort { lc($a->{handle}) cmp lc($b->{handle}) } @smslist;
	my $i = 1;
	for my $sms (@smslist) {
		next unless $all || $sms->{handle} =~ /\Q$match\E/i;
		$window->printformat(MSGLEVEL_CLIENTNOTICE, 'sms_listline', $i++, $sms->{handle}, $sms->{phone}, smsnet($sms->{phone}));
	}
	&smsstat if $match eq "*";
}

sub smsstat {
	my ($plus, $era, $idea) = (0, 0, 0);
	
	for my $sms (@smslist) {
		for ($sms->{phone}) {
			/^6(0[1,3,5,7,9]|91)/ and $plus++;
			/^6(0[0,2,4,6,8]|92)/ and $era++;
			/^50/ and $idea++;
		}
	}
	Irssi::active_win()->printformat(MSGLEVEL_CLIENTNOTICE, 'sms_stat', scalar(@smslist), $plus, $era, $idea);
}

sub savesms {
	local *fp;
	open (fp, ">", $smsfile) or die "Couldn't open $smsfile for writing";
	for my $sms (@smslist) {
		print(fp "$sms->{handle} $sms->{phone}\n");
	}
	close(fp);
}

sub loadsms {
	@smslist = ();
	return unless (-e $smsfile);
	local *fp;
	open(fp, "<", $smsfile);
	local $/ = "\n";
	while (<fp>) {
		chop;
		my $sms = {};
		($sms->{handle}, $sms->{phone}) = split(/ /);
		push(@smslist, $sms);
	}
	close(fp);
	Irssi::print("Loaded address book:");
	&smsstat;
}

sub isnumber {
	return ($_[0] =~ /^([+]|[0-9])[0-9]{6,}$/);
}

sub corrnum {
	my $num = shift;

	return 0 unless isnumber($num);
	
	if ($num =~ /^\+/) {
		return 0 unless $num =~ s/^(\+48)//g;
	}
	$num =~ s/^(48)//;

	return $num;
}

sub smsnum {
	my $num = shift;
	for my $sms (@smslist) {
		if ($sms->{phone} eq $num) {
			return $sms->{handle}
		}
	}
	return $num;
}

sub smsnet {
	for (@_) {
		/^6(0[13579]|9[135])/ and return "PLUS";
		/^6(0[02468]|9[24])/ and return "ERA";
		/^50/ and return "IDEA";
	}
	return "UNKNOWN";
}

sub urlencode {
	my $ret = shift;
	$ret =~ s/([^a-zA-Z0-9])/sprintf("%%%.2x", ord($1));/eg;
	return $ret;
}

sub smsfork {
	my ($rh, $wh);
	pipe($rh, $wh);
	my $pid = fork();
	unless (defined $pid) {
		Irssi::print("%R>>%n Failed to fork() :/ -  $!");
		close $rh; close $wh;
		return 1;
	} elsif ($pid) { 	# parent
		close $wh;
		$ftag{$rh} = Irssi::input_add(fileno($rh), INPUT_READ, \&ifork, $rh);
		Irssi::pidwait_add($pid);
	} else { 		# child
		close $rh;
		$fh = $wh;
	}
	return $pid;
}

sub smskill {
	print($fh "finished\n");
	close $fh;
	POSIX::_exit(1);
}

sub ifork {
	my $rh= shift;
	my $ret = 0;
	while (<$rh>) {
		/^sent (.+)/ and Irssi::active_win()->printformat(MSGLEVEL_CLIENTNOTICE, 'sms_sent', smsnum($1)), last;
		/^esent ([0-9]+)\s([0-9]+)\s([0-9]+)$/ and Irssi::active_win()->printformat(MSGLEVEL_CLIENTNOTICE, 'sms_esent', smsnum($1), $2, $3), last;
		/^notsent (.+)/ and Irssi::active_win()->printformat(MSGLEVEL_CLIENTNOTICE, 'sms_notsent', smsnum($1)), last; 
		/^enotsent ([0-9]+)\s([0-9]+)\s([0-9]+)$/ and Irssi::active_win()->printformat(MSGLEVEL_CLIENTNOTICE, 'sms_enotsent', smsnum($1), $2, $3), last; 
		/^info (.+)/ and Irssi::print("$1"), last;
		/^finished$/ and $ret = 1, last;
	}	
	return unless $ret;
	Irssi::input_remove($ftag{$rh});
	delete $ftag{$rh};
	close $rh;
}

sub sconnect {
	my $target = shift;
	my ($proto, $iaddr, $saddr);
	
	$proto = getprotobyname('tcp');
	$iaddr = inet_aton($target);
	socket(SOCK, PF_INET, SOCK_STREAM, $proto) || return 0;
	local $SIG{ALRM} = sub {
		print($fh "info %R>>%n connect() to $target timeouted :/\n");	
		close SOCK;
		return 0;	
	};
	alarm 10;
	unless (connect(SOCK, sockaddr_in(80, $iaddr))) {
		print($fh "info %R>>%n Couldn't connect to $target: $!\n");
		close SOCK;
		return 0;
	}
	alarm 0;
	my $old = select(SOCK); $| = 1; select($old);
	return 1;
}

sub PLUS {
	my ($phone, $text) = @_;
	&smskill unless sconnect("sms.plusgsm.pl");
	my $tosend = "tprefix=" . substr($phone, 0, 3) . "&numer=" . substr($phone, 3) . "&odkogo=$smssender&tekst=" . urlencode($text) . "&dzien=dzisiaj&godz=&min=";
	print SOCK "POST /sms/sendsms.php HTTP/1.0\n";
	print SOCK "Host: www.text.plusgsm.pl:80\n";
	print SOCK "Accept: */*\n";
	print SOCK "Content-type: application/x-www-form-urlencoded\n";
	print SOCK "Content-length: " . length($tosend) . "\n\n";
	print SOCK "$tosend\r\n";
	while (<SOCK>) {
		/wiadomo¶æ zosta³a wys³ana/ and print($fh "sent $phone\n"), last;
		/nie zosta³ wys³any/ and print($fh "notsent $phone\n"), last; 
	}
	close SOCK;
	&smskill;
}

sub ERA {
	my ($phone, $cutme) = @_;
	my $ml = 126 - length($smssender);
	my $cl = length($cutme);
	my $total = int($cl / $ml) + (($cl%$ml)? 1 : 0);
	if ($total > 1) {
		$ml -= (4 + length($total) * 2);
		$total = int($cl / $ml) + (($cl%$ml)? 1 : 0);
		printf($fh "info >> Spliting SMS to $total messages.\n");
	}
	my $act = 0;
	while ($cutme =~ s/.{1,$ml}//) {
		my ($cookie, $code, $tosend, $text);
		&smskill unless sconnect("boa.eragsm.pl");
		$act++;
		$text = "<$act/$total> " if $total > 1;
		$text .= $&;
		print SOCK "POST /sms/sendsms.asp?sms=1 HTTP/1.0\n";
		print SOCK "Host: boa.eragsm.com.pl:80\n";
		print SOCK "Accept: */*\n\r\n";
		while (<SOCK>) {
			$cookie = $1 if /Set\-Cookie\:\ ([^\;]+?)\;/;
			$code = $1 if /name\=\"Code\"\ value\=\"(.+?)\"/;
		}
		close SOCK;
		$tosend = "numer=$phone&bookopen=&message=" . urlencode($text) . "&podpis=$smssender&kontakt=&Nadaj=Nadaj&code=$code&Kasuj=Kasuj&Telefony=Telefony";
		&smskill unless sconnect("boa.eragsm.pl");
		print SOCK "POST /sms/sendsms.asp HTTP/1.0\n";
		print SOCK "Host: boa.eragsm.com.pl:80\n";
		print SOCK "Accept: */*\n";
		print SOCK "Cookie: $cookie\n";
		print SOCK "Referer: http://boa.eragsm.com.pl/sms/sendsms.asp\n";
		print SOCK "Content-type: application/x-www-form-urlencoded\n";
		print SOCK "Content-length: " . length($tosend) . "\n\n";
		print SOCK "$tosend\r\n";
		if ($total > 1) {
			while (<SOCK>) {
				/nie zosta³a wys³ana!/ and print($fh "enotsent $phone $act $total\n"), last;
				/zosta³a wys³ana/ and print($fh "esent $phone $act $total\n"), last;
			}	
		} else {
			while (<SOCK>) {
				/nie zosta³a wys³ana!/ and print($fh "notsent $phone\n"), last;
				/zosta³a wys³ana/ and print($fh "sent $phone\n"), last;
			}
		}
		close SOCK;
	}
	&smskill;
}

sub IDEA {
	my ($phone, $text) = @_;
	my ($sec, $min, $hour, $day, $mon, $year) = (localtime)[0,1,2,3,4,5];
	$year += 1900;
	$mon += 1;
	&smskill unless sconnect("sms.idea.pl");
        my $tosend = "LANGUAGE=pl&NETWORK=smsc1&DELIVERY_TIME=0&SENDER=$smssender&RECIPIENT=$phone&VALIDITY_PERIOD=24&DELIVERY_DATE=$day&DELIVERY_MONTH=$mon&DELIVERY_YEAR=$year&DELIVERY_HOUR=$hour&DELIVERY_MIN=$min&NOTIFICATION_FLAG=false&NOTIFICATION_ADDRESS=&SHORT_MESSAGE=" . urlencode($text) . "&SUBMIT=Wyslij";
	print SOCK "POST /sendsms.asp HTTP/1.0\n";
	print SOCK "Host: sms.idea.pl:80\n";
	print SOCK "Accept: */*\n";
	print SOCK "Content-type: application/x-www-form-urlencoded\n";
	print SOCK "Content-length: " . length($tosend) . "\n\n";
	print SOCK "$tosend\r\n";
	while (<SOCK>) {
		/SMS nie zostanie/ and print($fh "notsent $phone\n"), last;
		/doby zosta³ wyczerpany/ and print($fh "notsent $phone\n"), last;
		/zosta³a wys³ana/ and print($fh "sent $phone\n"), last;
		/request cannot be processed/ and print($fh "notsent $phone\n"), last;
	}
	close SOCK;
	&smskill;
}

sub UNKNOWN {
	print($fh "info %R>>%n Sorry, sms.pl supports only polish operators :/\n");
	&smskill;
}

&loadsms;

Irssi::command_bind("sms", "cmd_sms");
Irssi::command_bind("addsms", "cmd_addsms");
Irssi::command_bind("smsadd", "cmd_addsms");
Irssi::command_bind("smsdel", "cmd_delsms");
Irssi::command_bind("delsms", "cmd_delsms");
Irssi::command_bind("listsms", "cmd_listsms");
Irssi::command_bind("smslist", "cmd_listsms");
Irssi::command_bind("smsstat", "smsstat");
