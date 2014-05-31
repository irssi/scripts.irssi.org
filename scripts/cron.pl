#
# Short help/usage: 
# /jobadd hour minute day_of_month month day_of_week command
# Possibile switches for jobadd: 
#	-disabled
#	-server <tag>
#	-<number>
# /jobs [-v]
# /jobdel [-finished] | job_number
# /jobdisable job_number
# /jobenable job_number
# /jobssave
# /jobsload
# 
# Examples of usage:
# /jobadd 17 45 * * * /echo This will be executed at 17:45
# /jobadd -5 17 45 * * * /echo The same as above but only 5 times
# /jobadd * 05 * * * /echo Execute this every hour 5 minutes after the hour
# /jobadd */6 0 * * * /echo Execute at 0:0, 6:0, 12:0, 18:0
# /jobadd * */30,45 * * * /echo Execute every hour at 00, 30, 45 minute
# /jobadd * 1-15/5 * * * /echo at 1,6,11
#
# The servertag in -server usually is name from /ircnet, but 
# should work with servers not in any ircnet (hmm probably)
# 
# The format was taken from crontab(5). 
# The only differences are:
# 1) hour field is before minute field (why the hell minute is first in
# 	crontab?). But this could be changed in final version.
# 2) day of week is 0..6. 0 is Sunday, 1 is Monday, 6 is Saturday. 
# 	7 is illegal value while in crontab it's the same as 0 (i.e. Sunday).
# 	I might change this, depends on demand.
# 3) you can't use names in month and day of week. You must use numbers
# Type 'man 5 crontab' to know more about allowed values etc.
#
# TODO:
# 	- add full (or almost full) cron functionality
# 	- probably more efficient checking for job in timeout
# 	- imput data validation
# 	? should we remember if the server was given with -server
#
# Changelog:
#	0.11 (2004.12.12)
#	Job are executed exactly at the time (+- 1s), not up to 59s late
#
#	0.10 (2003.03.25):
#	Added -<number> to execute job only <number> times. Initial patch from
#		Marian Schubert (M dot Schubert at sh dot cvut dot cz)
#	
#	0.9:
#	Bugfix: according to crontab(5) when both DoM and DoW are restricted
#		it's enough to only one of fields to match
#
# 	0.8:
# 	Added -disabled to /jobadd
# 	Added jobs loading and saving to file
#
#	0.7:
#	Bugfixes. Should work now ;)
#
#	0.6:
#	Added month, day of month, day of week
# 
# 	0.5:
# 	Initial testing release
#

use Irssi;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "0.11";
%IRSSI = (
    authors	=> 'Piotr Krukowiecki',
    contact	=> 'piotr \at/ krukowiecki /dot\ net',
    name	=> 'cron aka jobs',
    description	=> 'cron implementation, allows to execute commands at given interval/time',
    license	=> 'GNU GPLv2',
    changed	=> '2004.12.12',
    url	=> 'http://www.krukowiecki.net/code/irssi/'
);

my @jobs = ();
my $seconds = (gmtime(time()))[0];
my $timeout_tag;
my $stop_timeout_tag;
if ($seconds > 0) {
	$stop_timeout_tag = Irssi::timeout_add((60-$seconds)*1000, 
		sub { 
			Irssi::timeout_remove($stop_timeout_tag);
			$timeout_tag = Irssi::timeout_add(60000, 'sig_timeout', undef);
		}, undef);
} else { 
	$timeout_tag = Irssi::timeout_add(60000, 'sig_timeout', undef);
}
my $savefile = Irssi::get_irssi_dir() . "/cron.save";

# First arg - current hour or minute.
# Second arg - hour or minute specyfications.
sub time_matches($$) {
	my ($current, $spec) = @_;
	foreach my $h (split(/,/, $spec)) {
		if ($h =~ /(.*)\/(\d+)/) { # */number or number-number/number
			my $step = $2;
			if ($1 eq '*') { # */number
				return 1 if ($current % $step == 0);
				next;
			}
			if ($1 =~ /(\d+)-(\d+)/) { # number-number/number
				my ($from, $to) = ($1, $2);
				next if ($current < $from or $current > $to);	# not in range
				my $current = $current;
				if ($from > 0) { # shift time
					$to -= $from;
					$current -= $from;
					$from = 0;					
				}
				return 1 if ($current % $step == 0);
				next;
			}
			next;
		}
		if ($h =~ /(\d+)-(\d+)/) { # number-number
			return 1 if ($current >= $1 and $current <= $2);
			next
		}
		return 1 if ($h eq '*' or $h == $current); # '*' or exact hour
	}
	return 0;
}

sub sig_timeout {
	my $ctime = time();
	my ($cminute, $chour, $cdom, $cmonth, $cdow) = (localtime($ctime))[1,2,3,4,6];
	$cmonth += 1;
	foreach my $job (@jobs) {
		next if ($job->{'disabled'});
		next if ($job->{'repeats'} == 0);
		next if (not time_matches($chour, $job->{'hour'}));	
		next if (not time_matches($cminute, $job->{'minute'}));	
		next if (not time_matches($cmonth, $job->{'month'}));
		if ($job->{'dom'} ne '*' and $job->{'dow'} ne '*') {
			next if (not (time_matches($cdom,  $job->{'dom'}) or 
				time_matches($cdow, $job->{'dow'})));
		} else {
			next if (not time_matches($cdom, $job->{'dom'}));
			next if (not time_matches($cdow, $job->{'dow'}));
		}
		
		my $server = Irssi::server_find_tag($job->{'server'});
		if (!$server) {
			Irssi::print("cron.pl: could not find server '$job->{server}'");
			next;
		}
		$server->command($job->{'commands'});
		if ($job->{'repeats'} > 0) {
		    $job->{'repeats'} -= 1;
		}
	}
}

sub cmd_jobs {
	my ($data, $server, $channel) = @_;
	my $verbose = ($data eq '-v');
	Irssi::print("Current Jobs:");
	foreach (0 .. $#jobs) {
		my $repeats = $jobs[$_]{'repeats'};
		my $msg = "$_) ";
		if (!$verbose) {
			next if ($repeats == 0);
			$msg .= "-$repeats " if ($repeats != -1);
		} else {
			$msg .= "-$repeats " if ($repeats != -1);
		}

		$msg .= ($jobs[$_]{'disabled'}?"-disabled ":"")
			."-server $jobs[$_]{server} "
			."$jobs[$_]{hour} $jobs[$_]{minute} $jobs[$_]{dom} "
			."$jobs[$_]{month} $jobs[$_]{dow} "
			."$jobs[$_]{commands}";
		Irssi::print($msg); 
	}
	Irssi::print("End of List");
}

# /jobdel job_number
sub cmd_jobdel {
	my ($data, $server, $channel) = @_;
	if ($data eq "-finished") {
	    foreach (reverse(0 .. $#jobs)) {
			if ($jobs[$_]{'repeats'} == 0) {
			    splice(@jobs, $_, 1);
			    Irssi::print("Removed Job #$_");
			}
	    }
	    return;
    } elsif ($data !~ /\d+/ or $data < 0 or $data > $#jobs) {
		Irssi::print("Bad Job Number");
		return;
	}
	splice(@jobs, $data, 1);
	Irssi::print("Removed Job #$data");
}

# /jobdisable job_number
sub cmd_jobdisable {
	my ($data, $server, $channel) = @_;
	if ($data < 0 || $data > $#jobs) {
		Irssi::print("Bad Job Number");
		return;
	}
	$jobs[$data]{'disabled'} = 1;
	Irssi::print("Disabled job number $data");
}
# /jobenable job_number
sub cmd_jobenable {
	my ($data, $server, $channel) = @_;
	if ($data < 0 || $data > $#jobs) {
		Irssi::print("Bad Job Number");
		return;
	}
	$jobs[$data]{'disabled'} = 0;
	Irssi::print("Enabled job number $data");
}

# /jobadd [-X] [-disabled] [-server servertag] hour minute day_of_month month day_of_week command
sub cmd_jobadd {
	my ($data, $server, $channel) = @_;

	$server = $server->{tag};
	my $disabled = 0;
	my $repeats = -1;
	while ($data =~ /^\s*-/) { 
		if ($data =~ s/^\s*-disabled\s+//) { 
			$disabled = 1;
			next;
		}
		if ($data =~ s/^\s*-(\d+)\s+//) {
			$repeats = $1;
			next;
		}
		my $comm;
		($comm, $server, $data) = split(' ', $data, 3);
		if ($comm ne '-server') {
			Irssi::print("Bad switch: '$comm'");
			return;
		}
	}
	my ($hour, $minute, $dom, $month, $dow, $commands) = split(' ', $data, 6);
	
	push (@jobs, { 'hour' => $hour, 'minute' => $minute, 'dom' => $dom,
		'month' => $month, 'dow' => $dow,
		'server' => $server, 'commands' => $commands,
		'disabled' => $disabled, 'repeats' => $repeats } );
	Irssi::print("Job added");
}

sub cmd_jobssave {
	if (not open (FILE, "> $savefile")) {
		Irssi::print("Could not open file '$savefile': $!");
		return;
	}
	foreach (0 .. $#jobs) {
		next if ($jobs[$_]->{'repeats'} == 0); # don't save finished jobs
		print FILE 
			($jobs[$_]->{'repeats'}>0 ? "-$jobs[$_]->{'repeats'} " : "")
			. ($jobs[$_]{'disabled'}?"-disabled ":"")
			."-server $jobs[$_]{server} "
			."$jobs[$_]{hour} $jobs[$_]{minute} $jobs[$_]{dom} "
			."$jobs[$_]{month} $jobs[$_]{dow} "
			."$jobs[$_]{commands}\n";
	}
	close FILE;
	Irssi::print("Jobs saved");
}

sub cmd_jobsload {
	if (not open (FILE, "$savefile")) {
		Irssi::print("Could not open file '$savefile': $!");
		return;
	}
	@jobs = ();
	
	while (<FILE>) {
		chomp;
		cmd_jobadd($_, undef, undef);
	}
	
	close FILE;
	Irssi::print("Jobs loaded");
}

Irssi::command_bind('jobs', 'cmd_jobs', 'Cron');
Irssi::command_bind('jobadd', 'cmd_jobadd', 'Cron');
Irssi::command_bind('jobdel', 'cmd_jobdel', 'Cron');
Irssi::command_bind('jobdisable', 'cmd_jobdisable', 'Cron');
Irssi::command_bind('jobenable', 'cmd_jobenable', 'Cron');
Irssi::command_bind('jobssave', 'cmd_jobssave', 'Cron');
Irssi::command_bind('jobsload', 'cmd_jobsload', 'Cron');

# vim:noexpandtab:ts=4
