# Copyright (C) 2019 bw1
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Irssi::TextUI;
use Time::Piece;
use Time::Seconds;
use Getopt::Long qw/GetOptionsFromString/;
use IPC::Open3;
use YAML qw/Dump DumpFile LoadFile/;
use Time::HiRes qw/sleep alarm/;

$VERSION = '0.1';
%IRSSI = (
    authors	=> 'bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'boinc',
    description	=> 'interface to boinc',
    license	=> 'gpl',
    url		=> 'https://scripts.irssi.org/',
    modules => 'Time::Piece Time::Seconds Getopt::Long IPC::Open3 YAML Time::HiRes',
    changed	=> '2019-05-29',
);

my $help = <<'END';
%9NAME%9
  boinc.pl - interface to boinc
%9SYNOPSIS%9
  /boinc {-all|-tasks|-credit|-old|-info|-update|-help|-h|-list}
  /boinc <-host hostname> [-password password] [{-enable|-disable}]
%9DESCRIPTION%9
  interface to the boinc-client (https://boinc.berkeley.edu/)

  add the statusbar item
    /STATUSBAR window ADD boinc_credit

%9OPTIONS%9
  -all      view all at once
  -tasks    view the actual tasks
  -credit   view the credits
  -old      view old tasks
  -info     print all internal data (debug)
  -update   update the statusbar item
  -help|-h  show a help message
  -list     list the configured hosts
  -host     add or modify a host entry

%9SETTINGS%9
  /set boinc_update_cycle 15
    update time in minutes of the statusbar item.
  /set boinc_command boinccmd
    command line interface of the BOINC client.
END

my ($a_host, $a_password, $a_disable, $a_enable);
my %options = (
	'all' => \&cmd_all,
	'tasks' => \&cmd_tasks,
	'credit' => \&cmd_credit,
	'old' => \&cmd_old,
	'info' => \&cmd_info,
	'update' => \&cmd_update,
	'help' => \&cmd_help,
	'h' => \&cmd_help,
	'host=s' => \$a_host,
	'password=s' => \$a_password,
	'disable' => sub {$a_disable =1},
	'enable' => sub {$a_disable =0},
	'list' => \&cmd_clist,
);

my $boinc_cmd; #='boinccmd';
my $boinc_cmd_host='--host';
my $boinc_cmd_passwd='--passwd';
my $boinc_cmd_state='--get_state';
my $boinc_cmd_old_task='--get_old_tasks';

my %section= (
	'======== Tasks ========'=> 'tasks',
	'======== Projects ========'=> 'proj',
	'======== Applications ========'=> 'app',
	'======== Application versions ========'=> 'app_ver',
	'======== Workunits ========'=> 'units',
	'======== Time stats ========'=> 'time',
	'======== end ========'=> 'end', # help the last round
);

my $arry_start ='-----------';

my ($args, $server, $witem);

my %config;
my %info;

my ($pid, %readex, $instr, $errstr);

my $total_credit;
my $expavg_credit;
my $run_tasks;

my ($time_tag, $time_cycle);

sub mytime {
	my ($tstr) = @_;
	#my $tstr='Sun May  5 18:40:48 2019';
	my $t= Time::Piece->strptime($tstr,'%a %b %d %H:%M:%S %Y');
	return $t->strftime('%Y-%m-%d %H:%M');
}

sub mydifftime {
	my ( $ts2) = @_;
	#my $tstr='Sun May  5 18:40:48 2019';
	my $t1= localtime;
	my $t2= Time::Piece->strptime($ts2,'%a %b %d %H:%M:%S %Y');
	my $td= $t2-$t1;
	return $td->hours;
}

sub read_exec {
	my ($cmd, $host, $rfunc) = @_;

	my ($in, $out, $err);
	use Symbol 'gensym'; $err = gensym;
	$pid = open3($in, $out, $err, $cmd);
	$readex{$pid}->{pid}=$pid;
	$readex{$pid}->{cmd}=$cmd;
	$readex{$pid}->{in}=$in;
	$readex{$pid}->{out}=$out;
	$readex{$pid}->{err}=$err;
	$readex{$pid}->{host}=$host;
	$readex{$pid}->{rfunc}=$rfunc;

	Irssi::pidwait_add($pid);
}

sub sig_read_exec {
	my ($pid, $status) = @_;

	if (defined $readex{$pid} ) {
		my $out =$readex{$pid}->{out};
		my $err =$readex{$pid}->{err};
		my $host =$readex{$pid}->{host};
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

		&$rfunc($host) if (defined $rfunc);
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

sub read_host_old_task {
	my ($host) = @_;
	if ( $errstr ne '') {
		$info{$host}->{error}=$errstr;
	}

	my @lines = split /\n/,$instr;
	push @lines, 'task last:';

	my $count=0;
	my $tl=[];
	my $task={};
	foreach my $l (@lines) {
		if ($l =~ m/^task (.*):$/) {
			if ( $count >0 ) {
				push @{$tl}, $task;
				$task={};
			}
			$task->{taskname}=$1;
		} else {
			if ($l =~ m/^\s+(.*?):\s*(.*)$/ ) {
				$task->{$1}=$2;
			}
		}
		$count++;
	}
	$info{$host}->{old_tasks}=$tl;
}

sub read_host_state {
	my ($host) = @_;

	my $h;
	if (!exists $info{$host}) {
		my $h={};
		$info{$host}=$h;
	} else {
		$h=$info{$host};
	}
	my $array=0;

	if ( $errstr ne '') {
		$info{$host}->{error}=$errstr;
	}
	my @lines = split /\n/,$instr;
	push @lines, '======== end ========';

	my $sec='';
	my $sec_c=0;
	my $sec_r='';

	my $arr_c=0;
	my $arr_e=0;
	my $arr_r='';

	my $par_r={};

	foreach my $line ( @lines) {
		# section
		if (exists $section{$line}) {
			if ($sec_c >0) {
				if ( $arr_c ==0) {
					$h->{$sec}=$par_r;
					$par_r={};
				} else {
					$h->{$sec}=$arr_r;
				}
			} else {
			}
			$sec=$section{$line};
			$sec_c++;
			$sec_r='';
			$arr_e=1;
		}
		# array
		if ($line =~ m/$arry_start/ || $arr_e != 0 ) {
			if ($arr_c >0) {
				push @{$arr_r}, $par_r;
				$par_r={};
			} else {
				$arr_r=[];
			}
			$arr_c++;
			if ($arr_e != 0) {
				$arr_e=0;
				$arr_c=0;
			}
		}
		# parameter
		if ($line =~ m/^\s+(.*?):\s*(.*)$/ ) {
			$par_r->{$1}=$2;
		}
	}
}

sub read_hosts {
	my ( $jobs ) = @_;
	if (!exists $readex{job}) {
		$readex{job}=$jobs;
		foreach my $host (keys %config) {
			if ($config{$host}->{disable} != 1) {
				$info{$host}={};
				my $cmd="$boinc_cmd $boinc_cmd_host $host";
				if ( defined $config{$host}->{password} ) {
					$cmd = "$cmd $boinc_cmd_passwd $config{$host}->{password}";
				}
				my $cmd1="$cmd $boinc_cmd_state";
				read_exec($cmd1, $host, \&read_host_state );
				my $cmd2="$cmd $boinc_cmd_old_task";
				read_exec($cmd2, $host, \&read_host_old_task );
			} else {
				delete $info{$host};
			}
		}
	}
}

sub calc_credit {
	$total_credit=0;
	$expavg_credit;
	$run_tasks=0;
	foreach my $host (sort keys %info) {
		my $h=$info{$host};
		my $utc=0;
		my $uec=0;
		foreach my $prj (@{$h->{proj}}) {
			$utc += $prj->{user_total_credit};
			$uec += $prj->{user_expavg_credit};
		}
		if ($utc > $total_credit) {
			$total_credit=$utc;
			$expavg_credit=$uec;
		}
		foreach my $t (@{$h->{tasks}}) {
			if ($t->{active_task_state} eq 'EXECUTING') {
				$run_tasks++;
			}
		}
	}
}

sub print_tasks {
	foreach my $host (sort keys %info) {
		Irssi::printformat(MSGLEVEL_CLIENTCRAP,'myhl',$host);
		foreach my $t ( @{$info{$host}->{tasks}} ) {
			my $s='';
			$s .= sprintf " %s  ", substr($t->{name},0,3);
			$s .= sprintf "%5.1f ", $t->{'fraction done'}*100;
			my $st='W';
			$st='%gR%N' if ($t->{active_task_state} eq 'EXECUTING');
			$st='%bD%N' if ($t->{'ready to report'} eq 'yes');
			$s .= sprintf "%s ", $st;
			$s .= mytime($t->{received})."  ";
			$s .= mytime($t->{'report deadline'})." ";
			$s .= sprintf "%8.1f", mydifftime($t->{'report deadline'});
			Irssi::print($s, MSGLEVEL_CLIENTCRAP);
		}
	}
	Irssi::print('', MSGLEVEL_CLIENTCRAP);
}

sub print_old_tasks {
	foreach my $host (sort keys %info) {
		Irssi::printformat(MSGLEVEL_CLIENTCRAP,'myhl',$host);
		foreach my $t ( @{$info{$host}->{old_tasks}} ) {
			my $s='';
			$s .= sprintf "  %-20s", $t->{taskname};
			$s .= sprintf " %3d", $t->{'exit status'};
			$s .= sprintf " %8.2fh", $t->{'elapsed time'} /60/60;
			Irssi::print($s, MSGLEVEL_CLIENTCRAP);
		}
	}
	Irssi::print('', MSGLEVEL_CLIENTCRAP);
}

sub print_credit {
	my $total_credit=0;
	my $expavg_credit;
	my $he= sprintf "%-20s %10s %10s", 'host', 'avg', 'total';
	Irssi::printformat(MSGLEVEL_CLIENTCRAP,'myhl',$he);
	foreach my $host (sort keys %info) {
		my $h=$info{$host};
		my $hec=0;
		my $htc=0;
		my $utc=0;
		my $uec=0;
		foreach my $prj (@{$h->{proj}}) {
			$hec += $prj->{host_expavg_credit};
			$htc += $prj->{host_total_credit};
			$utc += $prj->{user_total_credit};
			$uec += $prj->{user_expavg_credit};
		}
		my $sh= sprintf ' %-19s',$host;
		my $sa .= sprintf "%10.0f", $hec;
		my $st .= sprintf "%10.0f", $htc;
		Irssi::printformat(MSGLEVEL_CLIENTCRAP,'myhl', $sh, $sa, $st);
		if ($utc > $total_credit) {
			$total_credit=$utc;
			$expavg_credit=$uec;
		}
	}
	my $str= sprintf "%-20s %10.0f %10.0f",'sum', $expavg_credit, $total_credit;
	Irssi::printformat(MSGLEVEL_CLIENTCRAP,'myhl',$str);
	Irssi::print('', MSGLEVEL_CLIENTCRAP);
}

sub print_error {
	foreach my $h (keys %info) {
		if ( exists $info{$h}->{error} ) {
			Irssi::print "Error: $info{$h}->{error}", MSGLEVEL_CLIENTCRAP;
		}
	}
}

sub sb_boinc_credit {
	my ($sb_item, $get_size_only) = @_;
	my $sb = 
		sprintf "run:%d avg:%d sum:%d",
			$run_tasks, $expavg_credit, $total_credit;
	$sb_item->default_handler($get_size_only, "{sb $sb}", '', 0);
}

sub cmd {
	($args, $server, $witem)=@_;
	my ($ret, $arg) = GetOptionsFromString($args, %options);

	if (defined $a_host) {
		$config{$a_host}->{host}=$a_host;
		$config{$a_host}->{password}=$a_password 
				if (defined $a_password);
		$config{$a_host}->{disable}=$a_disable
				if (defined $a_disable);
		$a_host=undef;
		$a_password=undef;
		$a_disable=undef;
		$a_enable=undef;
	}
}

sub cmd_clist {
	my $s;
	$s =sprintf '%-20s %-20s %-2s','host','password','disable';
	Irssi::print $s, MSGLEVEL_CLIENTCRAP;
	foreach my $h (sort keys %config) {
		$s =sprintf '%-20s %-20s %2d',
				$config{$h}->{host},
				$config{$h}->{password},
				$config{$h}->{disable};
		Irssi::print $s, MSGLEVEL_CLIENTCRAP;
	}
}

sub cmd_all {
	read_hosts([
		\&print_tasks,
		\&print_credit,
		\&print_old_tasks,
		\&print_error,
	]);
}

sub cmd_tasks {
	read_hosts([
		\&print_tasks,
		\&print_error,
	]);
}

sub cmd_credit {
	read_hosts([
		\&print_credit,
		\&print_error,
	]);
}

sub cmd_old {
	read_hosts([
		\&print_old_tasks,
		\&print_error,
	]);
}

sub cmd_info {
	Irssi::print "%info", MSGLEVEL_CLIENTCRAP;
	Irssi::print Dump(\%info), MSGLEVEL_CLIENTCRAP;
}

sub cmd_update {
	read_hosts();
	$readex{job} = [
		\&calc_credit,
		'Irssi::statusbar_items_redraw("boinc_credit");',
	];
}

sub cmd_help {
	Irssi::print $help, MSGLEVEL_CLIENTCRAP;
}

sub write_config {
	my $fn=Irssi::get_irssi_dir().'/boinc.yaml';
	DumpFile( $fn, \%config);
}

sub read_config {
	my $fn=Irssi::get_irssi_dir().'/boinc.yaml';
	if (-e $fn) {
		%config = %{ LoadFile($fn) };
	}
}

sub sig_setup_changed {
	$boinc_cmd= Irssi::settings_get_str('boinc_command');
	my $new_time = Irssi::settings_get_int('boinc_update_cycle');
	if ( $time_cycle != $new_time ) {
		if ( defined $time_tag) {
			Irssi::timeout_remove($time_tag);
			$time_tag= undef;
			$time_cycle= 0;
		}
		if ($new_time !=0 ) {
			$time_tag= 
				Irssi::timeout_add($new_time*60*1000, \&cmd_update, '');
			cmd_update();
			$time_cycle= $new_time;
		}
	}
}

sub UNLOAD {
	write_config();
}

Irssi::theme_register([
	'myhl', '{hilight $0} $1 $2',
]);

Irssi::command_bind('help', sub {
		if ($_[0] =~ m/boinc/ ) {
			cmd_help();
			Irssi::signal_stop;
		}
	}
);

Irssi::signal_add('pidwait', 'sig_read_exec');
Irssi::signal_add('setup changed', 'sig_setup_changed');

Irssi::statusbar_item_register ('boinc_credit', 0, 'sb_boinc_credit');

Irssi::settings_add_int($IRSSI{'name'}, 'boinc_update_cycle', 15);
Irssi::settings_add_str($IRSSI{'name'}, 'boinc_command', 'boinccmd');

Irssi::command_bind($IRSSI{name},\&cmd);
my @opt=map {$_ =~ s/=.*$//, $_ } keys %options;
Irssi::command_set_options($IRSSI{name}, join(" ", @opt));

read_config();
sig_setup_changed();
