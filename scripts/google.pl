# - Google.pl
use Irssi;
use Getopt::Long qw/GetOptionsFromString/;
use IPC::Open3;
use JSON::PP;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '2.01';
%IRSSI = (
    authors     => 'bw1',
    contact     => 'bw1@aol.at',
    name        => 'google',
    description => 'This script queries google.com with googler and returns the results.',
    license     => 'Public Domain',
    url		=> 'https://scripts.irssi.org/',
    modules => '',
    commands=> 'google',
    selfcheckcmd=> 'google -check',
);

my $help = << "END";
%9Name%9
  $IRSSI{name}
%9Version%9
  $VERSION
%9Usage%9
  /google [-N|-news] [-x|-exact] [-c|-tld TLD] [-l|-lang LANG]
            [-n|-count N] [-s|-start] <KEYWORD>
  /google {-h|-help}
  /google {-p|-say N}
  /google -check
%9Description%9
  $IRSSI{description}
  first author: Oddbjørn Kvalsund
%9Arguments%9
  -N|-news      show results from news section
  -x|-exact     disable automatic spelling correction
  -c|-tld       country-specific search with top-level domain
  -l|-lang      display in language LANG
  -n|-count     show N results (default 10)
  -s|-start     start at the Nth result
  -h|-help      show this help message
  -p|-say       say the N url in channel
  -check        self check
%9See also%9
  https://github.com/jarun/googler
END

my ($copt, $tld, $lang, $count, $start, $chelp, $say, $check);
my %options = (
	'N'=> sub {$copt .= '--news '},
	'news'=> sub {$copt .= '--news '},
	'x'=> sub {$copt .= '--exact '},
	'exact'=> sub {$copt .= '--exact '},
	'c=s'=> \$tld,
	'tld=s'=> \$tld,
	'l=s'=> \$lang,
	'lang=s'=> \$lang,
	'n=o' => \$count,
	'count=o' => \$count,
	's=o' => \$start,
	'start=o' => \$start,
	'h' => \$chelp,
	'help' => \$chelp,
	'p=o' => \$say,
	'say=o' => \$say,
	'check' => \$check,
);

## Usage:
## /google [-p, prints to current window] [-<number>, number of searchresults returned] search-criteria1 search-criteria2 ...
##
## History:
## - Sun May 19 2002
##   Version 0.1 - Initial release
## - 2019-08-04
##   Version 2.0 - Change to googler
## - 2021-01-26
##   Version 2.01 - self check
## -------------------------------

my (%readex, $instr, $errstr, @res);

sub read_exec {
	my ($cmd, $rfunc) = @_;

	my ($in, $out, $err);
	use Symbol 'gensym'; $err = gensym;
	my $pid = open3($in, $out, $err, $cmd);
	$readex{$pid}->{pid}=$pid;
	$readex{$pid}->{cmd}=$cmd;
	$readex{$pid}->{in}=$in;
	$readex{$pid}->{out}=$out;
	$readex{$pid}->{err}=$err;
	$readex{$pid}->{rfunc}=$rfunc;

	Irssi::pidwait_add($pid);
}

sub sig_read_exec {
	my ($pid, $status) = @_;

	if (defined $readex{$pid} ) {
		my $out =$readex{$pid}->{out};
		my $err =$readex{$pid}->{err};
		my $rfunc =$readex{$pid}->{rfunc};

		delete $readex{$pid};

		my $old = select $out;
		local $/;
		$instr = <$out>;
		select $old;

		my $old = select $err;
		local $/;
		$errstr = <$err>;
		$errstr =~ s/[\n\r]//g;
		select $old;

		&$rfunc() if (defined $rfunc);
		if ( scalar(keys(%readex)) == 1 &&
				exists $readex{job}) {
			foreach my $j ( @{$readex{job}} ) {
				if ( ref( $j) eq 'CODE' ) {
					&$j();
				} else {
					eval( $j );
				}
			}
			delete $readex{job};
		}
		Irssi::signal_stop();
	}
}

sub cmd {
	my ($args, $server, $witem)=@_;
	Getopt::Long::Configure('no_ignore_case');
	my ($ret, $arg) = GetOptionsFromString($args, %options);
	if ($ret) {
		if (defined $chelp) {
			cmd_help($IRSSI{name}, $server, $witem);
		} elsif (defined $say) {
			if ($say >0 && $say <= scalar(@res)) {
				Irssi::active_win()->command("say $res[$say-1]->{url}");
			}
		} else {
			my $cmd="googler --json ";
			$cmd .="--tld $tld " if (defined $tld);
			$cmd .="--lang $lang " if (defined $lang);
			$cmd .="--count $count " if (defined $count);
			$cmd .="--start $start " if (defined $start);
			$cmd .="irssi " if (defined $check);
			$cmd .="$copt " if (defined $copt);
			$cmd .=join(" ",@{$arg});
			Irssi::print(">$cmd<", MSGLEVEL_CLIENTCRAP);
			read_exec($cmd ,\&print_all);
		}
	}
	$copt=undef;
	$tld=undef;
	$lang=undef;
	$count=undef;
	$start=undef;
	$chelp=undef;
	$say=undef;
}

sub self_check {
	my @r =@_;
	my $s="ok";
	$check=undef;
	Irssi::print("Selfcheck: results: ".scalar @r);
	Irssi::print("Selfcheck: url: ".$r[0]->{url});
	Irssi::print("Selfcheck: title: ".$r[0]->{title});
	if ( scalar(@r) < 6 ) {
		$s="Error: results (".scalar @r.")";
	} elsif ( $r[0]->{url} !~ m/^http/ ) {
		$s="Error: url (".$r[0]->{url}.")";
	} elsif ( length($r[0]->{title}) < 4) {
		$s="Error: title (".$r[0]->{title}.")";
	}
	Irssi::print("Selfcheck: $s");
	my $schs_version = $Irssi::Script::selfcheckhelperscript::VERSION;
	Irssi::command("selfcheckhelperscript $s") if ( defined $schs_version );
}

sub print_all {
	if( length($errstr) <1 ) {
		@res= @{decode_json($instr)};
		self_check(@res) if (defined $check);
		Irssi::print("/---- google ----", MSGLEVEL_CLIENTCRAP);
		my $c=1;
		foreach my $r (@res) {
			my $s= sprintf("| %3d ",$c) . $r->{title};
			Irssi::print($s, MSGLEVEL_CLIENTCRAP);
			$s="|     ". $r->{url};
			Irssi::print($s, MSGLEVEL_CLIENTCRAP);
			$c++;
		}
		Irssi::print('\---- google ----', MSGLEVEL_CLIENTCRAP);
	} else {
		Irssi::print($errstr, MSGLEVEL_CLIENTCRAP);
	}
}

sub cmd_help {
	my ($args, $server, $witem)=@_;
	$args=~ s/\s+//g;
	if ($IRSSI{name} eq $args) {
		Irssi::print($help, MSGLEVEL_CLIENTCRAP);
		Irssi::signal_stop();
	}
}

$ENV{PYTHONIOENCODING}='utf8';
Irssi::signal_add('pidwait', 'sig_read_exec');

Irssi::command_bind('google', 'cmd');
my @opt=map {$_ =~ s/=.*$//, $_ } keys %options;
Irssi::command_set_options($IRSSI{name}, join(" ", @opt));
Irssi::command_bind('help', \&cmd_help);
