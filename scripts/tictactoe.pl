use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Text::ParseWords;

$VERSION = '0.01';
%IRSSI = (
    authors	=> 'bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'tictactoe',
    description	=> 'tic-tac-toe game',
    license	=> 'LGPLv3',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2019-06-07',
    modules => 'Text::ParseWords',
    commands=> 'tictactoe',
);

my $help = << "END";
%9Name%n
  $IRSSI{name}
%9Version%n
  $VERSION
%9description%n
  $IRSSI{description}

  start the game:
    /tictactoe game
    nick: !game
  print the board
    /tictactoe board
    nick: !board
  drop a stone
    /tictactoe b0
    nick: !b0
END

my ($server, $nick, $target, $witem, $type);

# 0= free, 1= stone player1, 2= stone player2
my @board= (
	[0,1,2],
	[0,2,0],
	[0,0,0],
);
my $step_counter=3;

# 0= free, 1= i, 2= you, 3=whatever
my @gray= (
	# over
	[[1,1,1],[3,3,3],[3,3,3], 0,0, -1],
	[[3,3,3],[1,1,1],[3,3,3], 0,0, -1],
	[[1,3,3],[3,1,3],[3,3,1], 0,0, -1],

	[[2,2,2],[3,3,3],[3,3,3], 0,0, -2],
	[[3,3,3],[2,2,2],[3,3,3], 0,0, -2],
	[[2,3,3],[3,2,3],[3,3,2], 0,0, -2],
	# last
	[[1,1,0],[3,3,3],[3,3,3], 0,2, 1],
	[[0,1,1],[3,3,3],[3,3,3], 0,0, 1],
	[[1,0,1],[3,3,3],[3,3,3], 0,1, 1],

	[[3,3,3],[1,1,0],[3,3,3], 1,2, 1],
	[[3,3,3],[0,1,1],[3,3,3], 1,0, 1],
	[[3,3,3],[1,0,1],[3,3,3], 1,1, 1],

	[[1,3,3],[3,1,3],[3,3,0], 2,2, 1],
	[[1,3,3],[3,0,3],[3,3,1], 1,1, 1],
	# no 3
	[[2,2,0],[3,3,3],[3,3,3], 0,2, 0],
	[[0,2,2],[3,3,3],[3,3,3], 0,0, 0],
	[[2,0,2],[3,3,3],[3,3,3], 0,1, 0],

	[[3,3,3],[2,2,0],[3,3,3], 1,2, 0],
	[[3,3,3],[0,2,2],[3,3,3], 1,0, 0],
	[[3,3,3],[2,0,2],[3,3,3], 1,1, 0],

	[[2,3,3],[3,2,3],[3,3,0], 2,2, 0],
	[[2,3,3],[3,0,3],[3,3,2], 1,1, 0],
	#
	[[2,0,0],[0,2,0],[3,0,1], 0,2, 0],
	[[2,0,3],[0,2,0],[0,0,1], 2,0, 0],
	# d3
	[[2,0,0],[3,3,0],[3,3,2], 0,1, 0],
	[[2,0,0],[3,2,3],[3,0,3], 0,1, 0],
	[[2,3,3],[0,2,0],[0,3,3], 1,0, 0],
	[[0,2,0],[2,3,3],[0,3,3], 0,0, 0],
	[[0,2,0],[0,3,3],[2,3,3], 0,0, 0],
	[[0,0,2],[2,3,3],[0,3,3], 0,0, 0],
	# M
	[[3,3,3],[3,0,3],[3,3,3], 1,1, 0],
	# M2
	[[3,3,3],[3,2,3],[3,3,0], 2,2, 0],
);

# game state
# 0 off
# 10 player[0] turn
# 20 player[1] turn
# 30 vs computer
my $state=0;
# player
my @player=();

sub rotate {
	my ($r) =@_;
	my @ca;
	for(my $c=0; $c <3; $c++) {
		push @ca,$board[$c][0];
	}
	push @ca,$board[2][1];
	for(my $c=2; $c >-1; $c--) {
		push @ca,$board[$c][2];
	}
	push @ca,$board[0][1];

	for(my $c=0; $c <$r*2; $c++) {
		push @ca, shift(@ca);
	}

	for(my $c=0; $c <3; $c++) {
		$board[$c][0]= shift(@ca);
	}
	$board[2][1]= shift(@ca);
	for(my $c=2; $c >-1; $c--) {
		$board[$c][2]= shift(@ca);
	}
	$board[0][1]= shift(@ca);
}

sub compute {
	my ($max)= @_;
	my $res;
	my $mc=0;
	foreach my $s (@gray) {
		for(my $r=0; $r<4; $r++) {
			my $ok=1;
			for(my $x=0; $x <3; $x++) {
				for(my $y=0; $y <3; $y++) {
					if ($s->[$x][$y] !=3) {
						if ($s->[$x][$y] != $board[$x][$y]) {
							$ok=0;
							last;
						}
					}
				}
				last if ($ok==0);
			}
			if ($ok == 1) {
				if (!defined $res) {
					$res =$s->[5];
					if ($s->[5] >=0) {
						$board[$s->[3]][$s->[4]]=1;
						$step_counter++;
					}
				}
			}
			rotate(1);
		}
		last if (defined $res);
		$mc++;
		last if (defined($max) && $mc > $max);
	}
	return $res;
}

# step_in('a1',2);
sub step_in {
	my ($st,$player) = @_;

	return 1 if (length($st) != 2);
	my $y = ord(lc(substr($st,0,1))) -97;
	return 2 if ($y <0 || $y >2);
	my $x = substr($st,1,1);
	return 3 if ($x <0 || $x >2);
	return 4 if ($board[$x][$y] !=0);
	$board[$x][$y]= $player;
	$step_counter++;
	return 0;
}

sub sc_clear {
	for(my $x=0; $x <3; $x++) {
		for(my $y=0; $y <3; $y++) {
			$board[$x][$y]=0;
		}
	}
	$step_counter=0;
}

# return state
# 0 normal step
# 1 last step by computer
# -1 computer win
# -2 computer lost
# -5 draw
sub sc_compute {
	my $st=0;
	my $max;
	if ($player[1]->{difficult} eq 'e') {
		$max=5;
	}
	if ($player[1]->{difficult} eq 'n') {
		$max=5+8;
	}
	if ($player[1]->{difficult} eq 'i') {
		$max=5+8+10;
	}
	if ($player[1]->{difficult} eq 'a') {
		$max=5+8+10+6;
	}
	if ($player[1]->{difficult} eq 'x') {
		$max=undef;
	}
	my $res=compute($max);
	if (!defined $res) {
		my $r= random();
		if ($r) {
			$st=-5;
		}
	} else {
		if ($res <0 || $res ==1) {
			$st=$res;
		}
	}
	if ($step_counter == 9 && $st == 0) {
		$st= -5;
	}
	return $st;
}

sub sc_check {
	my $r= compute(5);
	if (!defined $r && $step_counter == 9) {
		$r= -5;
	}
	return $r;
}

sub random {
	my $r = int(rand()*10)+1;
	my $c;
	while ($r >0 ) {
		$c=0;
		for(my $x=0; $x <3; $x++) {
			for(my $y=0; $y <3; $y++) {
				if ($board[$x][$y]==0) {
					$r--;
				} else {
					$c++;
				}
				if ($r <=0) {
					$board[$x][$y]=1;
					$step_counter++;
					last;
				}
			}
			last if ($r <=0);
		}
		last if ( $c >=8);
	}
	return ($c >=8);
}

sub def_player {
	my ($num)= @_;
	if (defined $witem) {
		$player[$num]->{type}='L';
	}
	if (defined $type) {
		$player[$num]->{type}=$type;
	}
	if (defined $server) {
		$player[$num]->{server}=$server->{tag};
	}
	if (defined $target) {
		$player[$num]->{target}=$target;
	}
}

sub board {
	my $str= "   %9abc%n\n";
	my %c = (
		0=>' ',
		1=>$player[1]->{stone},
		2=>$player[0]->{stone},
	);
	for(my $x=0; $x<3; $x++) {
		my $r="%9 $x%n ";
		for(my $y=0; $y<3; $y++) {
			$r .= $c{$board[$x][$y]};
		}
		$str .= $r."\n";
	}
	$str .= "\n";
	return $str;
}

sub cmd {
	my ($args, $server, $wi)=@_;
	my @args = grep { $_ ne ''}  quotewords('\s+', 0, $args);
	$witem= $wi;
	$type= 'L';
	subcmd(@args);
	$type= undef;
	$witem= undef;
}

sub cmd_help {
	my ($args, $server, $witem)=@_;
	$args=~ s/\s+//g;
	if ($IRSSI{name} eq $args) {
		Irssi::print($help, MSGLEVEL_CLIENTCRAP);
		Irssi::signal_stop();
	}
}

sub subcmd {
	my (@args) =@_;
	my $a= $args[0];
	if ($a eq 'help' || $a eq '') {
		out($help);
	}
	if ($a eq 'board') {
		out(board(),1);
	}
	# init
	if ($state==0 && $a eq 'game') {
		$state=1;
		$player[0]->{nick}=$nick;
		def_player(0);
		if ($type eq 'L') {
			$a='c';
		} else {
			out('%9tictactoe%n vs %gc%nomputer or vs %gh%numan?');
		}
	}
	if ($state==1 && $player[0]->{nick} eq $nick &&  $a =~ m/^c/) {
		$state=2;
		$player[1]->{computer}=1;
		out('difficulty: %ge%nasy, %gn%novice, %gi%nntermediate, '.
			'%ga%ndvanced, e%gx%npert?');
		#   e asy
		#   n ovice
		#   i ntermediate
		#   a dvanced
		# e x pert
	}
	if ($state==2 && $player[0]->{nick} eq $nick &&  $a =~ m/^([eniax])/) {
		$state=3;
		$a='';
		$player[1]->{difficult}=$1;
		out('%gX%n or %gO%n?');
	}
	# game start vs computer
	if ($state==3 && $player[0]->{nick} eq $nick &&  $a =~ m/^[xo]$/i) {
		$state=30;
		sc_clear();
		$player[0]->{win}=0;
		$player[0]->{draw}=0;
		$player[1]->{win}=0;
		if (lc($a) eq 'x') {
			$player[0]->{stone}='X';
			$player[1]->{stone}='O';
		} else {
			$player[0]->{stone}='O';
			$player[1]->{stone}='X';
			# compute
			sc_compute();
		}
		out(board(),1);
	}
	# play vs computer
	if ($state==30 && $player[0]->{nick} eq $nick &&  $a =~ m/^[abc][012]$/i) {
		$state=30;
		if (step_in($a,2) == 0) {
			my $r=sc_compute();
			if ( $r==0 || $r==1 || $r==-5 ) {
				out(board(),1);
			}
			if ( $r== -5 ) {
				$state=31;
				$player[0]->{draw}++;
				out("draw");
			}
			if ( $r== 1 || $r== -1 ) {
				$state=31;
				$player[1]->{win}++;
				out("computer win");
			}
			if ( $r== -2 ) {
				$state=31;
				$player[0]->{win}++;
				out("you win");
			}
			if ($state==31) {
				out("play a gain? (%gy%nes or %gn%no)");
			}
		}
	}
	if ($state==31 && $player[0]->{nick} eq $nick &&  $a =~ m/^[yn]/i) {
		if ( $a=~ m/^n/i) {
			my $s="%9computer%n:$player[1]->{win} %9draw%n:$player[0]->{draw} ";
			$s .= "%9";
			if ( $player[0]->{nick} eq '' ) {
				$s .= "you";
			} else {
				$s .=$player[0]->{nick};
			}
			$s .="%n:$player[0]->{win}";
			out($s);
			@player=();
			$state=0;
		} else {
			# game
			$state=30;
			sc_clear();
			my $s= $player[0]->{stone};
			$player[0]->{stone}= $player[1]->{stone};
			$player[1]->{stone}= $s;
			if ($player[1]->{stone} eq 'X') {
				sc_compute();
			}
			out(board(),1);
		}
	}
	# init vs human
	if ($state==1 && $player[0]->{nick} eq $nick &&  $a =~ m/^h/) {
		$state=5;
		out("player 2 ? (".mynick().": !%gg%name)",1);
	}
	if ($state==5 && $player[0]->{nick} ne $nick &&  $a =~ m/^g/) {
		$player[1]->{nick}=$nick;
		my $r =int(rand(10)) % 2;
		sc_clear();
		$player[0]->{win}=0;
		$player[0]->{draw}=0;
		$player[1]->{win}=0;
		out(board(),1);
		if ($r == 0) {
			$player[0]->{stone}='X';
			$player[1]->{stone}='O';
			$state=10;
			out("your turn", 0, $player[0]->{nick});
		} else {
			$player[0]->{stone}='O';
			$player[1]->{stone}='X';
			$state=20;
			out("your turn", 0, $player[1]->{nick});
		}
	}
	# play vs human
	if ($state==10 && $player[0]->{nick} eq $nick &&  $a =~ m/^[abc][012]$/) {
		if (step_in($a,2) == 0) {
			my $r= sc_check();
			if (!defined $r) {
				$state=20;
				out(board(),1);
				out("your turn", 0, $player[1]->{nick});
			} else {
				$state=11;
				human_end($r);
			}
		}
	}
	if ($state==20 && $player[1]->{nick} eq $nick &&  $a =~ m/^[abc][012]$/) {
		if (step_in($a,1) == 0) {
			my $r= sc_check();
			if (!defined $r) {
				$state=10;
				out(board(),1);
				out("your turn", 0, $player[0]->{nick});
			} else {
				$state=11;
				human_end($r);
			}
		}
	}
	# play again vs human
	if ($state==11 &&
			($player[1]->{nick} eq $nick || $player[0]->{nick} eq $nick)
				 &&  $a =~ m/^[yn]/) {
		if ($a =~ m/^y/i) {
			sc_clear();
			my $s= $player[0]->{stone};
			$player[0]->{stone}= $player[1]->{stone};
			$player[1]->{stone}= $s;
			out(board(),1);
			if ($player[1]->{stone} eq 'X') {
				$state=20;
				out("your turn", 0, $player[1]->{nick});
			} else {
				$state=10;
				out("your turn", 0, $player[0]->{nick});
			}
		} else {
			$state=0;
			my $s="%9";
			if ( $player[1]->{nick} eq '' ) {
				$s .= "you";
			} else {
				$s .=$player[1]->{nick};
			}
			$s .= "%n:$player[1]->{win} %9draw%n:$player[0]->{draw} ";
			$s .= "%9";
			if ( $player[0]->{nick} eq '' ) {
				$s .= "you";
			} else {
				$s .=$player[0]->{nick};
			}
			$s .="%n:$player[0]->{win}";
			out($s);
			@player=();
		}
	}
}

sub human_end {
	my ($result)= @_;
	out(board(),1);
	if ($result == -5) {
		out("draw",1);
		$player[0]->{draw}++
	}
	if ($result == -1) {
		out("$player[1]->{nick} win",1);
		$player[1]->{win}++
	}
	if ($result == -2) {
		out("$player[0]->{nick} win",1);
		$player[0]->{win}++
	}
	out("play again (%gy%nes or %gn%no)",1);
}

sub to_irc_color {
	my ($str)= @_;
	$str =~ s/%9/\x{3}2/g;
	$str =~ s/%g/\x{3}3/g;
	$str =~ s/%n/\x{3}/g;
	$str =~ s/%%/%/g;
	return $str;
}

sub out {
	my ($str, $neutral, $ni ) =@_;
	my @l =split /\n/,$str;
	$nick= $ni if (defined $ni);
	foreach my $r (@l) {
		if ($player[0]->{type} eq 'C') {
			my $s= $player[0]->{server};
			my $t= $player[0]->{target};
			if ( $neutral== 1) {
				Irssi::command("/msg -$s $t ".to_irc_color($r));
			} else {
				Irssi::command("msg -$s $t $nick: ".to_irc_color($r));
			}
		} elsif ($player[0]->{type} eq 'Q') {
			my $s= $player[0]->{server};
			my $t= $player[0]->{target};
			if ( $neutral== 1) {
				Irssi::command("/msg -$s $t ".to_irc_color($r));
			} else {
				Irssi::command("msg -$s $t $nick: ".to_irc_color($r));
			}
		} elsif (defined $witem) {
			$witem->print($r, MSGLEVEL_CLIENTCRAP);
		} else {
			Irssi::print($r, MSGLEVEL_CLIENTCRAP);
		}
	}
}

sub mynick {
	my $n;
	if (defined $server) {
		$n= $server->{nick};
	}
	if (defined $witem) {
		my $s= $witem->{server};
		$n= $s->{nick};
	}
	return $n;
}

sub sig_message_public {
	my ($se, $msg, $ni, $address, $ta)= @_;
	$type='C';
	$server=$se;
	$nick=$ni;
	$target=$ta;
	my @args = grep { $_ ne ''}  quotewords('\s+', 0, $msg);
	my $to =shift @args;
	if ($to =~ m/^\Q$se->{nick}\E[:]?$/ ) {
		if( $args[0] =~ m/^!(.*)$/ ) {
			$args[0] = $1;
			subcmd(@args);
		}
	}
	$type=undef;
	$server=undef;
	$nick=undef;
	$target=undef;
}

sub sig_message_private {
	my ($se, $msg, $ni, $address, $ta)= @_;
	$type='Q';
	$server=$se;
	$nick=$ni;
	$target=$ni;
	my @args = grep { $_ ne ''}  quotewords('\s+', 0, $msg);
	if ( $args[0] =~ m/^!(.*)$/ ) {
		$args[0] = $1;
		subcmd(@args);
	}
	$type=undef;
	$server=undef;
	$nick=undef;
	$target=undef;
}

sub sig_message_own_private {
	my ($se, $msg, $ta, $orig_target)= @_;
	$server=$se;
	$type='Q';
	$nick=$se->{nick};
	$target=$ta;
	my @args = grep { $_ ne ''}  quotewords('\s+', 0, $msg);
	if ( $args[0] =~ m/^!(.*)$/ ) {
		$args[0] = $1;
		subcmd(@args);
	}
	$type=undef;
	$server=undef;
	$nick=undef;
	$target=undef;
}

sub sig_message_own_public {
	my ($se, $msg, $ta)= @_;
	$server=$se;
	$type='C';
	$nick=$se->{nick};
	$target=$ta;
	my @args = grep { $_ ne ''}  quotewords('\s+', 0, $msg);
	if ( $args[0] =~ m/^!(.*)$/ ) {
		$args[0] = $1;
		subcmd(@args);
	}
	$type=undef;
	$server=undef;
	$nick=undef;
	$target=undef;
}

Irssi::signal_add("message own_public", \&sig_message_own_public);
Irssi::signal_add("message own_private", \&sig_message_own_private);
Irssi::signal_add("message public", \&sig_message_public);
Irssi::signal_add("message private", \&sig_message_private);

Irssi::command_bind($IRSSI{name}, \&cmd);
Irssi::command_bind('help', \&cmd_help);

