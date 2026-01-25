# WARNING
# WARNING This script now uses the standard "minute hour ..." format.
# WARNING
#
# Short help/usage:
# /jobadd minute hour day_of_month month day_of_week command
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
# /jobadd 45 17 * * * /echo This will be executed at 17:45
# /jobadd -5 45 17 * * * /echo The same as above but only 5 times
# /jobadd 5 * * * * /echo Execute this every hour 5 minutes after the hour
# /jobadd 0 */6 * * * /echo Execute at 0:0, 6:0, 12:0, 18:0
# /jobadd */30,45 * * * * /echo Execute every hour at 00, 30, 45 minute
# /jobadd 1-15/5 * * * * /echo at 1,6,11
#
# The servertag in -server usually is name from /ircnet, but
# should work with servers not in any ircnet (hmm probably)
#
# The format was taken from crontab(5).
# The only differences are:


# 1) day of week is 0..6. 0 is Sunday, 1 is Monday, 6 is Saturday.
#	7 is illegal value while in crontab it's the same as 0 (i.e. Sunday).
#	I might change this, depends on demand.
# 2) you can't use names in month and day of week. You must use numbers
# Type 'man 5 crontab' to know more about allowed values etc.
#
# TODO:
#	- add full (or almost full) cron functionality
#	- probably more efficient checking for job in timeout
#	- input data validation
#	? should we remember if the server was given with -server
#
# Changelog:
#	1.0 (2026.01.10)
#	Automatically convert "hour minute" format into the correct "minute hour" format
#	Add version string in cron.save so the conversion only happens once
#	Make backup copy cron.save.backup file of "hour minute" formatted file
#	/jobadd now requires "minute hour" format
#	Columns for /jobs for easier readability
#
#	0.13 (2025.08.16)
#	Bugfix: Fix time drifting bug.
#
#	0.12 (2014.11.12)
#	Automatically load jobs when loaded
#
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

$VERSION = "1.0";
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
my $timeout_tag;
sub start_next_timeout {
	my $seconds = (gmtime(time()))[0];
	my $delay_ms = (60 - $seconds) * 1000;
	$delay_ms = 1000 if $delay_ms <= 0;
	$timeout_tag = Irssi::timeout_add_once($delay_ms, sub {
		sig_timeout();
		start_next_timeout();
	}, undef);
}
my $savefile = Irssi::get_irssi_dir() . "/cron.save";

# First arg - current hour or minute.
# Second arg - hour or minute specifications.
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
			next;
		}
		return 1 if ($h eq '*' or $h == $current); # '*' or exact hour
	}
	return 0;
}

sub is_file_converted {
	my $file = shift;

	return 0 unless (-f $file);

	open(my $in, '<', $file) or return 0;
	my $first_line = <$in>;
	close($in);

	return ($first_line && $first_line =~ /^# cron file version/);
}

# Change format from "hour minute" into "minute hour"
sub update_cron_save_file {
	my $file = Irssi::get_irssi_dir() . "/cron.save";
	my $backup_file = $file . ".backup";

	return unless (-f $file);

	open(my $in, '<', $file) or do {
		Irssi::print("cron.pl: Could not open file '$file' for reading: $!");
		return;
	};
	my @lines = <$in>;
	close($in);

	# Create backup
	open(my $backup, '>', $backup_file) or do {
		Irssi::print("cron.pl: Could not create backup file '$backup_file': $!");
		return;
	};
	print $backup @lines;
	close($backup);
	Irssi::print("cron.pl: Created update backup: $backup_file");

	# Write new file
	open(my $out, '>', $file) or do {
		Irssi::print("cron.pl: Could not open file '$file' for writing: $!");
		return;
	};

	# Add comment at top of file so this does not run again.
	print $out "# cron file version 1.0\n";

	foreach my $line (@lines) {
		chomp $line;

		# Skip empty lines and existing comments
		if ($line =~ /^\s*$/ || $line =~ /^#/) {
			next;
		}

	# Parse and update the line
	# Swap the first two time fields after "-server"

	# Lines with empty server tag (two spaces after -server)
	# Format: -server  <hour> <minute> <dom> <month> <dow> <command>
	if ($line =~ /^(-server)(\s{2,})(\S+)(\s+)(\S+)(\s+)(\S+)(\s+)(\S+)(\s+)(\S+)(\s+)(.*)$/) {
		my $server_tag = $1;	 # -server
		my $spaces1 = $2;		 # spaces after -server (2 or more)
		my $hour = $3;			 # hour field (old format)
		my $spaces2 = $4;		 # spaces between hour and minute
		my $minute = $5;		 # minute field (old format)
		my $spaces3 = $6;		 # spaces between minute and dom
		my $dom = $7;			 # day of month
		my $spaces4 = $8;		 # spaces between dom and month
		my $month = $9;		     # month
		my $spaces5 = $10;		 # spaces between month and dow
		my $dow = $11;			 # day of week
		my $spaces6 = $12;		 # spaces between dow and command
		my $command = $13;		 # command

		# Swap hour and minute
		print $out "$server_tag$spaces1$minute$spaces2$hour$spaces3$dom$spaces4$month$spaces5$dow$spaces6$command\n";
		#print "Converted: $hour $minute -> $minute $hour\n";
		next;
	}

	# Lines with server name
	# Format: -server <servername> <hour> <minute> <dom> <month> <dow> <command>
	if ($line =~ /^((-?\d+\s+)?(-disabled\s+)?-server\s+)(\S+)(\s+)(\S+)(\s+)(\S+)(\s+)(\S+)(\s+)(\S+)(\s+)(\S+)(\s+)(.*)$/) {
		my $prefix = $1;		  # optional -<number> and/or -disabled and -server
		my $server_name = $4;	  # server tag
		my $spaces1 = $5;		  # spaces after server name
		my $hour = $6;			  # hour field (old format)
		my $spaces2 = $7;		  # spaces between hour and minute
		my $minute = $8;		  # minute field (old format)
		my $spaces3 = $9;		  # spaces between minute and dom
		my $dom = $10;			  # day of month
		my $spaces4 = $11;		  # spaces between dom and month
		my $month = $12;		  # month
		my $spaces5 = $13;		  # spaces between month and dow
		my $dow = $14;			  # day of week
		my $spaces6 = $15;		  # spaces between dow and command
		my $command = $16;		  # command

		# Swap hour and minute
		print $out "$prefix$server_name$spaces1$minute$spaces2$hour$spaces3$dom$spaces4$month$spaces5$dow$spaces6$command\n";
		#print "Converted: $hour $minute -> $minute $hour\n";
		next;
	}
		print $out "$line\n";
	}

	close($out);
	Irssi::print("cron.pl: Updated cron.save file");
}

sub sig_timeout {
	my $ctime = time();
	my ($cminute, $chour, $cdom, $cmonth, $cdow) = (localtime($ctime))[1,2,3,4,6];
	$cmonth += 1;
	foreach my $job (@jobs) {
		next if ($job->{'disabled'});
		next if ($job->{'repeats'} == 0);
		next if (not time_matches($cminute, $job->{'minute'}));
		next if (not time_matches($chour, $job->{'hour'}));
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

	# Calculate maximum widths for each column
	my %max_len = (
		server => 6,	# "Server"
		minute => 6,	# "Minute"
		hour => 4,	    # "Hour"
		dom => 3,	    # "DoM"
		month => 5,	    # "Month"
		dow => 3,	    # "DoW"
	);

	# First pass to calculate widths
	foreach my $job (@jobs) {
		next if (!$verbose && $job->{'repeats'} == 0);

		# Check if server field contains a time value (no server was specified)
		if ($job->{'server'} =~ /^[\d\*,\-\/]+$/) {
			# This job has no server specified, fields are shifted
			$max_len{server} = length("") if length("") > $max_len{server};
			$max_len{minute} = length($job->{'server'}) if length($job->{'server'}) > $max_len{minute};
			$max_len{hour} = length($job->{'minute'}) if length($job->{'minute'}) > $max_len{hour};
			$max_len{dom} = length($job->{'hour'}) if length($job->{'hour'}) > $max_len{dom};
			$max_len{month} = length($job->{'dom'}) if length($job->{'dom'}) > $max_len{month};
			$max_len{dow} = length($job->{'month'}) if length($job->{'month'}) > $max_len{dow};
		} else {
			# Normal job with server specified
			$max_len{server} = length($job->{'server'}) if length($job->{'server'}) > $max_len{server};
			$max_len{minute} = length($job->{'minute'}) if length($job->{'minute'}) > $max_len{minute};
			$max_len{hour} = length($job->{'hour'}) if length($job->{'hour'}) > $max_len{hour};
			$max_len{dom} = length($job->{'dom'}) if length($job->{'dom'}) > $max_len{dom};
			$max_len{month} = length($job->{'month'}) if length($job->{'month'}) > $max_len{month};
			$max_len{dow} = length($job->{'dow'}) if length($job->{'dow'}) > $max_len{dow};
		}
	}

	# Add padding
	foreach my $key (keys %max_len) {
		$max_len{$key} += 2;
	}

	Irssi::print("Current Jobs:");

	# Header
	my $header = sprintf("%-4s %-8s %-9s %-*s %-*s %-*s %-*s %-*s %-*s %s",
		"Job#", "Repeats", "Disabled",
		$max_len{server}, "Server",
		$max_len{minute}, "Minute",
		$max_len{hour}, "Hour",
		$max_len{dom}, "DoM",
		$max_len{month}, "Month",
		$max_len{dow}, "DoW",
		"Command");
	Irssi::print($header);
	Irssi::print("-" x length($header));

	# Data rows
	foreach my $i (0 .. $#jobs) {
		my $job = $jobs[$i];
		next if (!$verbose && $job->{'repeats'} == 0);

		my $repeats = $job->{'repeats'};
		my $repeats_str = ($repeats == -1) ? "*" : $repeats;
		my $disabled_str = $job->{'disabled'} ? "Yes" : "No";

		my ($server_str, $minute_str, $hour_str, $dom_str, $month_str, $dow_str, $command_str);

		# Check if server field contains a time value (no server was specified)
		# Better way to write this?
		if ($job->{'server'} =~ /^[\d\*,\-\/]+$/) {
			# This job has no server specified, fields are shifted
			# The server field actually contains the minute
			# The minute field contains the hour
			# The hour field contains the day of month
			# The dom field contains the month
			# The month field contains the day of week
			# The dow field contains part of the command
			# The command field contains the rest of the command

			$server_str = "";  				  # No server specified
			$minute_str = $job->{'server'};   # Actually the minute
			$hour_str = $job->{'minute'};	  # Actually the hour
			$dom_str = $job->{'hour'};		  # Actually the day of month
			$month_str = $job->{'dom'};		  # Actually the month
			$dow_str = $job->{'month'};		  # Actually the day of week

			# Combine dow (which has part of command) with actual command
			$command_str = $job->{'dow'} . " " . $job->{'commands'};
		} else {
			# Normal job with server specified
			$server_str = $job->{'server'};
			$minute_str = $job->{'minute'};
			$hour_str = $job->{'hour'};
			$dom_str = $job->{'dom'};
			$month_str = $job->{'month'};
			$dow_str = $job->{'dow'};
			$command_str = $job->{'commands'};
		}

		my $row = sprintf("%-4s %-8s %-9s %-*s %-*s %-*s %-*s %-*s %-*s %s",
			"$i)",
			$repeats_str,
			$disabled_str,
			$max_len{server}, $server_str,
			$max_len{minute}, $minute_str,
			$max_len{hour}, $hour_str,
			$max_len{dom}, $dom_str,
			$max_len{month}, $month_str,
			$max_len{dow}, $dow_str,
			$command_str);
		Irssi::print($row);
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

# /jobadd [-X] [-disabled] [-server servertag] minute hour day_of_month month day_of_week command
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
	my ($minute, $hour, $dom, $month, $dow, $commands) = split(' ', $data, 6);

	push (@jobs, { 'minute' => $minute, 'hour' => $hour, 'dom' => $dom,
		'month' => $month, 'dow' => $dow,
		'server' => $server, 'commands' => $commands,
		'disabled' => $disabled, 'repeats' => $repeats } );
	Irssi::print("Job added");
}

sub cmd_jobssave {
	# Read existing comments/headers if file exists
	my @existing_comments = ();
	if (-f $savefile) {
		open(my $in, '<', $savefile) or do {
			Irssi::print("Could not read existing file '$savefile': $!");
			return;
		};
		while (my $line = <$in>) {
			chomp $line;
			# Save comment lines
			if ($line =~ /^#/) {
				push @existing_comments, $line;
			} else {
				# Stop at first non-comment line
				last;
			}
		}
		close $in;
	}

	# Open file for writing
	if (not open (FILE, ">", $savefile)) {
		Irssi::print("Could not open file '$savefile' for writing: $!");
		return;
	}

	# Write preserved comments (if any) or the standard header
	if (@existing_comments) {
		foreach my $comment (@existing_comments) {
			print FILE "$comment\n";
		}
	} else {
		# Write default header if no existing comments
		print FILE "# cron file version 1.0\n";
	}

	# Write jobs
	foreach (0 .. $#jobs) {
		next if ($jobs[$_]->{'repeats'} == 0); # don't save finished jobs
		print FILE
			($jobs[$_]->{'repeats'}>0 ? "-$jobs[$_]->{'repeats'} " : "")
			. ($jobs[$_]{'disabled'}?"-disabled ":"")
			. "-server $jobs[$_]{server} "
			. "$jobs[$_]{minute} $jobs[$_]{hour} $jobs[$_]{dom} "
			. "$jobs[$_]{month} $jobs[$_]{dow} "
			. "$jobs[$_]{commands}\n";
	}
	close FILE;
	Irssi::print("Jobs saved");
}

sub cmd_jobsload {
	# Check if file needs to be updated
	if (-f $savefile && !is_file_converted($savefile)) {
		Irssi::print("cron.pl: File not converted, attempting update...");
		update_cron_save_file();
	}

	if (not open (FILE, q{<}, $savefile)) {
		Irssi::print("Could not open file '$savefile': $!");
		return;
	}
	@jobs = ();

	# Skip the update comment if present
	while (<FILE>) {
		chomp;
		next if /^# cron file version/; # Skip the conversion comment
		cmd_jobadd($_, undef, undef);
	}

	close FILE;
	Irssi::print("Jobs loaded");
}

cmd_jobsload();
start_next_timeout();

Irssi::command_bind('jobs', 'cmd_jobs', 'Cron');
Irssi::command_bind('jobadd', 'cmd_jobadd', 'Cron');
Irssi::command_bind('jobdel', 'cmd_jobdel', 'Cron');
Irssi::command_bind('jobdisable', 'cmd_jobdisable', 'Cron');
Irssi::command_bind('jobenable', 'cmd_jobenable', 'Cron');
Irssi::command_bind('jobssave', 'cmd_jobssave', 'Cron');
Irssi::command_bind('jobsload', 'cmd_jobsload', 'Cron');

# vim:noexpandtab:ts=4
