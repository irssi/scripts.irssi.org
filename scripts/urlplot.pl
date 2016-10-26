use strict;
#use warnings;	# Not a default module in perl 5.005

use vars qw($VERSION %IRSSI);

$VERSION = '1.2';
%IRSSI = (
	authors		=> 'bwolf',
	contact		=> 'bwolf@geekmind.org',
	name		=> 'urlplot',
	description	=> 'URL grabber with HTML generation and cmd execution',
	license		=> 'BSD',
	url		=> 'http://www.geekmind.net',
	changed		=> 'Sun Jun 16 14:00:13 CEST 2002'
);

# To read the documentation you may use one of the following commands:
#
# pod2man urlplot.pl | nroff -man | more
# pod2text urlplot.pl | more
# pod2man urlplot.pl | troff -man -Tps -t > urlplot.ps

=head1 NAME

urlplot

=head1 SYNOPSIS

All URL loggers suck. This one just sucks less.

=head1 DESCRIPTION

urlplot watches your channels for URLs and creates nice HTML logfiles of it.
Actually it parses normal text and topic changes for URLs. Internally it uses
two caches to prevent flooding and logging of duplicate URLs. As an additional
feature urlplot can create CSV datafiles. Logfiles can be created for all
channels and for separate channels. Logging can be allowed and denied on a per
channel/nick basis. A lockfile is used to protect the caches and logfiles from
accessing them by multiple irssi instances. A command allows you to send a
logged URL to your webbrowser of choice.  

The format of the CSV logfiles is as follows:
date nick channel url

=head1 GETTING STARTED

Copy urlplot.pl intoF< $HOME/.irssi/scripts> and create the necessary
directories withC< mkdir -p>F< $HOME/.irssi/urlplot/urls>. 
Look for the settingsC< url_log_basedir> andC< url_db_basedir> if you want to
change the directories urlplot will populate with files.
Follow the documentation and configure urlplot to fit your needs.

=head1 COMMANDS

=head2 /url <integer>

Executes the commandC< url_command> with an URL from the cache as its
argument. If no number has been specified it defaults to nth URL logged which
references the most recently logged URL.

=head2 /url -list

Displays a list of all logged URLs.

=head2 /url -clearcache

Clears the cache databases.

=head /url -showlog 
 
ExecutesC< url_command> withC< url_navigate> as its argument. It can be used
to display the main logfile in your favourite webbrowser.

=head1 SETTINGS

=head2 Pathnames

Please note that you can't use $HOME or any environment variables in the
settings because irssi/urlplot isn't a shell ;)

=head2 /set url_command <string>

Command to be executed to display an URL (see /url). The command string should
contain the sequence C<__URL__> which will be replaced by a certain URL.

The default is:
C< mozilla -remote "openURL(__URL__)" E<gt> /dev/null 2E<gt>&1 || \ >
C< mozilla "__URL__"& >

This will send a certain URL to mozilla or it will start mozilla if it is not
already there. The string can be anything. For example I use the following:
C< ssh host /home/user/bin/mozopenurl "'__URL__'" >/dev/null 2>&1 &>
where mozopenurl is a shell script that contains similar code as the mozilla
-remote example above.

=head2 /set url_cache_max <integer>

Specifies the maximum count of items which will be held in the persisten URL
caches. A value of zero disables automatic cache resizing (round-robbin). The
default is to keep the last 90 URLs.

=head2 /set url_log_basedir <path>

Specifies the logging base directory used to create the log files beneath it.
The default isF< $HOME/.irssi/urlplot/urls/>. You have to create directories
by yourself:C< mkdir -p>F< $HOME/.irssi/urlplot/urls>.

=head2 /set url_log_file_name <relative-filename>

Defines the filename of the full logfile.  It will be passed to I<
strftime(3)>. This can be usefull to create logfiles with a timestamp.
The file will be created relative toC< url_log_basedir>. The default 
isF< ircurls.html>.

=head2 /set url_chan_prefix <string>

Defines the filename prefix for channel logfiles. The leadingC< # >of the
channel name will be replaced by this prefix. It will be passed to
I<strftime(3)>. The file will be created relative toC< url_log_basedir>. The
default isF< chan_>.

=head2 /set url_chan_logging <bool>

Enables or disable channel logging globally.
The default isC< ON>.

=head2 /set url_log_csv_file_name <relative-filename>

Defines the filename of the full CSV logfile. It will be passed to
I<strftime(3)>. The file will be created relative toC< url_log_basedir>. The
default isF< ircurls.csv>.

=head2 /set url_log_csv_file_max_size <integer>

Defines the maximum size of the full CSV logfile. If it reaches the specified
maximum size in bytes it will be simply resized to zero. The default isC< 30*1024> 
bytes.

=head2 /set url_log_csv_separator <string>

Defines the separator used as a delimeter for the fields of the CSV files.
The default isC< |>.

=head2 /set url_csv_logging <bool>

Conditionally turns on or off CSV logging for the full logfile. The default
isC< OFF>.

=head2 /set url_csv_chan_logging <bool>

Conditionally turns on or off CSV logging of the channel logfiles. The default isC< OFF>.

=head2 /set url_time_format <string>

Specifies the time format that will be passed toI< strftime(3)> to produce an
ASCII representation of the time/date when an URL was grabbed. It will be used
in the logfiles. The default isC< %Y:%m:%d - %H:%M:%S>.

=head2 /set url_log_file_max_size <integer>

Defines the maximum size of the full logfile and the channel logfile. If it
reaches the specified maximum size in bytes it will be simply resized to zero.
The default isC< 30*1024> bytes.

=head2 /set url_log_file_autoreload_time <integer>

Intervall in seconds used for the HTML logfile header. The logfile reloads
itself every N seconds. The default isC< 90> seconds.

=head2 /set url_db_basedir <path>

Specifies the database base directory where two database files and a lockfile
will be created. The default isF< $HOME/.irssi/urlplot>. You have to create
the directory by yourself.

=head2 /set url_db_cache_a_filename <relative-filename>

Defines the filename of the index URL database. The file will be created
relative toC< url_db_basedir>. The default isF< a_cache>.

=head2 /set url_db_cache_h_filename <relative-filename>

Defines the filename of the hash URL database. The file will be created
relative toC< url_db_basedir>. The default isF< h_cache>.

=head2 /set url_db_lock_filename <relative-filename>

Defines the filename of the lockfile used to lock all logfiles and the cache
databases. It will be created relative toC< url_db_basedir>. The default 
isF< lockfile>.

=head2 /set url_policy_default <allow|deny>

Specifies the default policy that will be used to decide if logging ist
permitted for a certain nick or channel. This can be eitherC< allow> 
orC< deny>. If you set this toC< deny> you will have to allow explicitly those
channels and nicks for which logging should be permitted. In contrast if you
set it to allow, you can deny logging for certain nicks and channels.
The keysC< url_policy_chans> andC< url_policy_nicks> control the allow, deny
behaviour depending onC< url_policy_default>. The default isC< allow> which
permits logging of all channels and nicks.

=head2 /set url_policy_chans <string>

Specifies those channels for whoom logging is permitted or denied. Multiple
channels may be specified by usingC< ,>C< ;>C< :> or a space to separate the
items.

=head2 /set url_policy_nicks <string>

SeeC< url_policy_chans> and replace the word channel by nick.

=head2 /set url_navigate <string>

ExecutesC< url_command> withC< url_navigate> as its argument. It can be used
to display the main logfile in your favourite webbrowser. Because you may pass
this command at anytime to your webbrowser it will not be passed to strftime.
Thus you can only specify a static file here.

=head1 AUTHOR

Marcus Geiger <bwolf@geekmind.org>

=cut

use integer;
use Irssi;
use POSIX qw(strftime);
use Fcntl qw(:DEFAULT :flock);
use DB_File;

# Regexps
sub URL_SCHEME_REGEX()			{ '(http|ftp|https|news|irc)' }
sub URL_GUESS_REGEX()			{ '(www|ftp)' }
sub URL_BASE_REGEX()			{ '[a-z0-9_\-+\\/:?%.&!~;,=\#<>]' }

# Other
sub BACKWARD_SEEK_BYTES()		{ 130 }
sub LOG_FILE_MARKER()			{ '<!-- bottom-line -->' }

# Keys for settings
sub KEY_URL_COMMAND()			{ 'url_command' } 
sub KEY_URL_CACHE_MAX()			{ 'url_cache_max' }
sub KEY_URL_LOG_BASEDIR()		{ 'url_log_basedir' }
sub KEY_URL_LOG_FILE_NAME()		{ 'url_log_file_name' }
sub KEY_URL_CHAN_PREFIX()		{ 'url_chan_prefix' }
sub KEY_URL_CHAN_LOGGING()		{ 'url_chan_logging' }
sub KEY_URL_LOG_CSV_FILE_NAME()		{ 'url_log_csv_file_name' }
sub KEY_URL_LOG_CSV_FILE_MAX_SIZE() 	{ 'url_log_csv_file_max_size' }
sub KEY_URL_LOG_CSV_SEPARATOR()		{ 'url_log_csv_separator' }
sub KEY_URL_CSV_LOGGING()		{ 'url_csv_logging' }
sub KEY_URL_CSV_CHAN_LOGGING()		{ 'url_csv_chan_logging' }
sub KEY_URL_TIME_FORMAT()		{ 'url_time_format' }
sub KEY_URL_LOG_FILE_MAX_SIZE()		{ 'url_log_file_max_size' }
sub KEY_URL_LOG_FILE_AUTORELOAD_TIME()	{ 'url_log_file_autoreload_time' }
sub KEY_URL_DB_BASEDIR()		{ 'url_db_basedir' }
sub KEY_URL_DB_CACHE_A_FILENAME()	{ 'url_db_cache_a_filename' }
sub KEY_URL_DB_CACHE_H_FILENAME()	{ 'url_db_cache_h_filename' }
sub KEY_URL_DB_LOCK_FILENAME()		{ 'url_db_lock_filename' }
sub KEY_URL_POLICY_DEFAULT()		{ 'url_policy_default' }
sub KEY_URL_POLICY_CHANS()		{ 'url_policy_chans' }
sub KEY_URL_POLICY_NICKS()		{ 'url_policy_nicks' }
sub KEY_URL_NAVIGATE()			{ 'url_navigate' }

# Defaults
sub DEF_URL_COMMAND() { 
	'mozilla -remote "openURL(__URL__)" > /dev/null 2>&1 || mozilla "__URL__"&' }
sub DEF_URL_CACHE_MAX()			{ 90 } 
sub DEF_URL_LOG_FILE_AUTORELOAD_TIME()	{ 120 }
sub DEF_URL_TIME_FORMAT()		{ '%Y:%m:%d - %H:%M:%S' }
sub DEF_URL_DO_FILE_RESIZE()		{ '0' }
sub DEF_URL_LOG_FILE_MAX_SIZE()		{ 1024 * 30 }
sub DEF_URL_LOG_BASEDIR()		{ '.irssi/urlplot/urls/' }
sub DEF_URL_LOG_FILE_NAME()		{ 'ircurls.html' }
sub DEF_URL_CHAN_PREFIX()		{ 'chan_' }
sub DEF_URL_CHAN_LOGGING()		{ '1' }
sub DEF_URL_LOG_CSV_FILE_NAME()		{ 'ircurls.csv' }
sub DEF_URL_LOG_CSV_FILE_MAX_SIZE()	{ 1024 * 30 }
sub DEF_URL_LOG_CSV_SEPARATOR()		{ '|' }
sub DEF_URL_CSV_LOGGING()		{ '' }
sub DEF_URL_CSV_CHAN_LOGGING()		{ '' }
sub DEF_URL_DB_BASEDIR()		{ '.irssi/urlplot/' }
sub DEF_URL_DB_CACHE_A_FILENAME()	{ 'a_cache' }
sub DEF_URL_DB_CACHE_H_FILENAME()	{ 'h_cache' }
sub DEF_URL_DB_LOCK_FILENAME()		{ 'lockfile' }
sub DEF_URL_POLICY_DEFAULT()		{ 'allow' }
sub DEF_URL_POLICY_CHANS()		{ '' }
sub DEF_URL_POLICY_NICKS()		{ '' }
sub DEF_URL_NAVIGATE()			{ '.irssi/urlplot/urls/ircurls.html' }

sub print_full_log_file_template {
	my ($fh, $reload) = @_;
	print $fh <<EOT;
<?xml version="1.0" encoding="iso-8859-1"?>
	<!DOCTYPE html
		PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
		"DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
	<head>
		<title>IRC-URLs</title>
		<meta http-equiv="cache-control" content="no-cache" />
		<meta http-equiv="refresh" content="$reload;" />
		<style type="text/css">
		<!--
			.small { font-size: small; }
			.xsmall { font-size: x-small; }
		-->
		</style>
	</head>
	<body>
		<h1>IRC-URLs</h1>
		<p class="xsmall">
			Visit <a href="http://www.geekmind.net">geekmind.net</a>
		</p>
		<p>This page reloads itself every $reload seconds.</p>
		<p>
			<a name="top" />
			<a class="small" href="#bottom">Page bottom</a>
			<br />
			<br />
		</p>
		<table rules="rows" frame="void" width="100%" cellpadding="5">
			<tr align="left">
				<th><b>Date/Time</b></th>
				<th><b>Nick</b></th>
				<th><b>Channel/Nick</b></th>
				<th><b>URL</b></th>
			</tr>
EOT
}

sub print_chan_log_file_template {
	my ($fh, $reload, $channel, $full_log) = @_;
	print $fh <<EOT;
<?xml version="1.0" encoding="iso-8859-1"?>
	<!DOCTYPE html
		PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
		"DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
	<head>
		<title>IRC-URLs of $channel</title>
		<meta http-equiv="cache-control" content="no-cache" />
		<meta http-equiv="refresh" content="$reload;" />
		<style type="text/css">
		<!--
			.small { font-size: small; }
			.xsmall { font-size: x-small; }
		-->
		</style>
	</head>
	<body>
		<h1>IRC-URLs of $channel</h1>
		<p class="xsmall">
			Visit <a href="http://www.geekmind.net">geekmind.net</a>
		</p>
		<p>This page reloads itself every $reload seconds.</p>
		<p><a href="$full_log">Complete</a> listing.</p>
		<p>
			<a name="top" />
			<a class="small" href="#bottom">Page bottom</a>
			<br />
			<br />
		</p>
		<table rules="rows" frame="void" width="100%" cellpadding="5">
			<tr align="left">
				<th><b>Date/Time</b></th>
				<th><b>Nick</b></th>
				<th><b>URL</b></th>
			</tr>
EOT
}

sub LOG_FILE_TAIL () {
	return <<"EOT";

			@{[ LOG_FILE_MARKER ]}
		</table>
		<p>
			<a class="small" href="#top">Page top</a>
			<a name="bottom" />
		</p>
	</body>
</html>
EOT
}

sub print_chan_log_file_entry {
	my ($fh, $date, $nick, $channel, $url) = @_;
	print $fh <<EOURL;
			<tr>
				<td>$date</td>
				<td><em>$nick</em></td>
				<td><a href=\"$url\">$url</a></td>
			</tr>
EOURL
	print $fh LOG_FILE_TAIL;
};

sub print_full_log_file_entry {
	my ($fh, $date, $nick, $channel, $chan_log, $url) = @_;
	print $fh <<EOURL;
			<tr>
				<td>$date</td>
				<td><em>$nick</em></td>
				<td><a href="$chan_log">$channel</a></td>
				<td><a href=\"$url\">$url</a></td>
			</tr>
EOURL
	print $fh LOG_FILE_TAIL;
}

sub p_error { # Error printing (directly to the current window)
	Irssi::print("urlplot: @_");
}

sub p_normal { # Normal printing (to the msg window)
	Irssi::print("@_", MSGLEVEL_MSGS+MSGLEVEL_NOHILIGHT);
}

sub scan_url {
	my $rawtext = shift;
	return $1 if $rawtext =~ m|(@{[ URL_SCHEME_REGEX ]}://@{[ URL_BASE_REGEX ]}+)|io;
	# The URL misses a scheme, try to be smart
	if ($rawtext =~ m|@{[ URL_GUESS_REGEX ]}\.@{[ URL_BASE_REGEX ]}+|io) { 
		my $preserve = $&;
		return "http://$preserve" if $1 =~ /^www/;
		return "ftp://$preserve"  if $1 =~ /^ftp/;
	}
	return undef;
}

sub aquire_lock {
	my $db_base = Irssi::settings_get_str(KEY_URL_DB_BASEDIR)
		|| die "missing setting for @{[ KEY_URL_DB_BASEDIR ]}";
	my $lockfile = Irssi::settings_get_str(KEY_URL_DB_LOCK_FILENAME)
		|| die "missing setting for @{[ KEY_URL_DB_LOCK_FILENAME ]}";

	local *LOCK_F;
	my $fh;
	$db_base .= '/' if $db_base !~ m#/$#;
	$lockfile = "${db_base}${lockfile}";

	die "directory $db_base doesn't exist or isn't readable"
		unless -d $db_base and -r $db_base;

	sysopen(LOCK_F, $lockfile, O_RDONLY | O_CREAT)
		|| die "can't open/create lockfile $lockfile: $!";
	flock(LOCK_F, LOCK_EX | LOCK_NB)
		|| die "can't exclusively lock $lockfile: $!";
	# Can't pass back localized typeglob reference
	$fh = *LOCK_F;
	return $fh;
}

sub open_caches {
	my $db_base = Irssi::settings_get_str(KEY_URL_DB_BASEDIR)
		|| die "missing setting for @{[ KEY_URL_DB_BASEDIR ]}";
	my $dbfile_a = Irssi::settings_get_str(KEY_URL_DB_CACHE_A_FILENAME)
		|| die "missing setting for @{[ KEY_URL_DB_CACHE_A_FILENAME ]}";
	my $dbfile_h = Irssi::settings_get_str(KEY_URL_DB_CACHE_H_FILENAME)
		|| die "missing setting for @{[ KEY_URL_DB_CACHE_H_FILENAME ]}";

	my (@cache, %cache);
	$db_base .= '/' if $db_base !~ m#/$#;
	$dbfile_a = "${db_base}${dbfile_a}";
	$dbfile_h = "${db_base}${dbfile_h}";

	die "directory $db_base doesn't exist or isn't readable"
		unless -d $db_base and -r $db_base;

	tie @cache, 'DB_File', $dbfile_a, O_RDWR | O_CREAT, 0666, $DB_RECNO
		or die "can't tie urlcache db $dbfile_a: $!";
	tie %cache, 'DB_File', $dbfile_h, O_RDWR | O_CREAT, 0666
		or die "can't tie urlcache db $dbfile_h: $!";
	return \(@cache, %cache);
}

sub create_chan_template {
	my ($full_log, $file, $channel) = @_;
	my $reload = Irssi::settings_get_int(KEY_URL_LOG_FILE_AUTORELOAD_TIME);
	local *FH;
	open(FH, ">", $file) 
		|| die "can't create logfile $file: $!";
	print_chan_log_file_template(\*FH, $reload, $channel, $full_log);
	print FH LOG_FILE_TAIL;
	close(FH);
}

sub create_full_template {
	my $file = shift;
	my $reload = Irssi::settings_get_int(KEY_URL_LOG_FILE_AUTORELOAD_TIME);
	local *FH;
	open(FH, ">", $file) 
		|| die "can't create logfile $file: $!";
	print_full_log_file_template(\*FH, $reload);
	print FH LOG_FILE_TAIL;
	close(FH);
}

sub create_csv_file {
	my $file = shift;
	open(FH, ">", $file) 
		|| die "can't create $file: $!";
	close FH;
}

sub log_csv {
	my $csv_log = shift;
	my $sep = Irssi::settings_get_str(KEY_URL_LOG_CSV_SEPARATOR);
	my $fields = join $sep, @_;
	local *FH;
	open(FH, ">>", $csv_log) 
		|| die "can't open $csv_log: $!";
	print FH "$fields\n";
	close FH;
}

sub position_log_file {
	my $file = shift;
	my ($fh, $pos, $buf, @lines, $off, $got_it);
	local *FH;
	my $hint = "Conside manual removal of this file";
	sysopen(FH, $file, O_RDWR) 
		|| die "can't open $file: $!";
	$pos = sysseek(FH, 0, 2) 
		|| die "can't seek to EOF in $file. ${hint}: $!";
	$pos -= BACKWARD_SEEK_BYTES;
	sysseek(FH, $pos, 0) 
		|| die "can't seek backwards to $pos in $file. ${hint}: $!";
	sysread(FH, $buf, 2048)
		|| die "can't read rest of $file. ${hint}: $!";
	$off = 0;
	@lines = split /\n/, $buf;
	for (@lines) {
		$off += length;
		$off += 1;
		chomp;
		next if /^$/;
		if (/@{[ LOG_FILE_MARKER ]}/io) {
			$got_it = 1;
			$off -= length;
			$off -= 1;
			last;
		}
	}
	die "Can't locate @{[ LOG_FILE_MARKER ]} in $file. ${hint}" 
		unless $got_it;
	$pos += $off;
	sysseek(FH, $pos, 0)
		|| die "Can't seek to $pos in $file. ${hint}: $!";
	# Can't pass back localized typeglob reference
	$fh = *FH;
	return $fh;
}

sub log_url {
	my ($nick, $channel, $url) = @_;
	my $log_base =  Irssi::settings_get_str(KEY_URL_LOG_BASEDIR)
		|| die "missing setting for @{[ KEY_URL_LOG_BASEDIR ]}";
	my $fullfile = Irssi::settings_get_str(KEY_URL_LOG_FILE_NAME)
		|| die "missing setting for @{[ KEY_URL_LOG_FILE_NAME ]}";
	my $csvfile = Irssi::settings_get_str(KEY_URL_LOG_CSV_FILE_NAME)
		|| die "missing setting for @{[ KEY_URL_LOG_CSV_FILE_NAME ]}";
	my $csv_max = Irssi::settings_get_int(KEY_URL_LOG_CSV_FILE_MAX_SIZE);
	my $csv_logging = Irssi::settings_get_bool(KEY_URL_CSV_LOGGING);
	my $csv_chan_logging = Irssi::settings_get_bool(KEY_URL_CSV_CHAN_LOGGING);
	my $time_fmt = Irssi::settings_get_str(KEY_URL_TIME_FORMAT)
		|| die "missing setting for @{[ KEY_URL_TIME_FORMAT ]}";
	my $max = Irssi::settings_get_int(KEY_URL_LOG_FILE_MAX_SIZE);
	my $chan_prefix = Irssi::settings_get_str(KEY_URL_CHAN_PREFIX)
		|| die "missing setting for @{[ KEY_URL_CHAN_PREFIX ]}";
	my $chan_logging = Irssi::settings_get_bool(KEY_URL_CHAN_LOGGING);

	my @curr_time = localtime(time());
	$log_base .= '/' if $log_base !~ m#/$#;

	die "directory $log_base doesn't exist or isn't readable"
		unless -d $log_base and -r $log_base;

	# Make channel filename
	my $tmp = POSIX::strftime($chan_prefix, @curr_time);
	my $chan_fname = lc $channel;
	$chan_fname =~ s/^#/$tmp/;
	my $chan_log = "${log_base}${chan_fname}.html";

	# Make full filename
	$tmp = POSIX::strftime($fullfile, @curr_time);
	my $full_fname = $tmp;
	my $full_log = $log_base . $tmp;

	# Replace spaces in date string to show up as '&#160;' to prevent line
	# breaks.
	my $date = POSIX::strftime($time_fmt, @curr_time);
	my $html_date = $date;
	$html_date =~ s/ /\&#160;/g;

	my $fh;

	# Channel logging
	if ($chan_logging) {
		create_chan_template $full_fname, $chan_log, $channel 
			if not -r $chan_log or ($max > 0 and (stat($chan_log))[7] > $max);
		$fh = undef;
		$fh = position_log_file $chan_log;
		print_chan_log_file_entry($fh, $html_date, $nick, $channel, $url);
		close $fh;
	}

	# Full logging
	create_full_template $full_log
		if not -r $full_log or ($max > 0 and (stat($full_log))[7] > $max);
	$fh = undef;
	$fh = position_log_file $full_log;
	print_full_log_file_entry($fh, $html_date, $nick, $channel,
		"${chan_fname}.html", $url);
	close $fh;

	# CSV logging
	if ($csv_logging) {
		$tmp = POSIX::strftime($csvfile, @curr_time);
		my $log = $log_base . $tmp;
		create_csv_file $log 
			if not -r $log or ($csv_max > 0 and (stat($log))[7] > $max);
		log_csv($log, $date, $nick, $channel, $url);	
	}

	# CSV channel logging
	if ($csv_chan_logging) {
		my $log = "${log_base}${chan_fname}.csv";
		create_csv_file $log 
			if not -r $log or ($csv_max > 0 and (stat($log))[7] > $max);
		log_csv($log, $date, $nick, $channel, $url);
	}
}

sub mk_home($) {
	my $arg = shift;
	return "$ENV{HOME}/$arg";
}

sub logging_permited {
	my ($nick, $chan_or_nick) = @_;
	my $default_policy = Irssi::settings_get_str(KEY_URL_POLICY_DEFAULT)
		|| die "missing setting for @{[ KEY_URL_POLICY_DEFAULT ]}";
	my $chans = Irssi::settings_get_str(KEY_URL_POLICY_CHANS);
	my $nicks = Irssi::settings_get_str(KEY_URL_POLICY_NICKS);
	my @policy_chans = split /[,;: ]/, $chans; 
	my @policy_nicks = split /[,;: ]/, $nicks;
	my $permit;

	if ($default_policy eq 'deny') {
		# logging must be explicitly permited
		$permit = 0;
		for (@policy_chans) {
			return 1 if $_ eq $chan_or_nick;
		}
		for (@policy_nicks) {
			return 1 if $_ eq $nick;
		}
	} elsif ($default_policy eq 'allow') {
		# logging must be explicitly denied
		$permit = 1; 
		for (@policy_chans) {
			return 0 if $_ eq $chan_or_nick;
		}
		for (@policy_nicks) {
			return 0 if $_ eq $nick;
		}
	} else {
		p_error("setting @{[ KEY_URL_POLICY_DEFAULT ]} can be either " .
			"'allow' or 'deny'");
		return undef;
	}
	return $permit;
}

sub do_locked {
	my $f = shift or die "missing function argument " . caller;
	my $lockf;
	eval { $lockf = aquire_lock };
	if ($@) {
		p_error("$@");
		return;
	}
	eval { $f->(@_) };
	p_error("$@") if $@;
	eval { close $lockf };
}

sub do_with_caches {
	my $f = shift or die "missing function argument " . caller;
	my ($cache_a, $cache_h) = ();
	eval { ($cache_a, $cache_h) = open_caches };
	if ($@) {
		p_error("$@");
		eval { untie %$cache_h } if defined $cache_h;
		eval { untie @$cache_a } if defined $cache_a;
		return;
	}
	eval { $f->($cache_a, $cache_h, @_) };
	p_error("$@") if $@;
	eval { untie %$cache_h };
	eval { untie @$cache_a };
}

sub url_msg_log {
	my ($cache_a, $cache_h, $nick, $chan_or_nick, $url) = @_;
	my ($cache_size, $tmp);
	my $max_cache = Irssi::settings_get_int(KEY_URL_CACHE_MAX);

	unless (exists $cache_h->{$url}) {
		$cache_size = scalar(@$cache_a) + 1;
		$cache_h->{$url} = '1';
		# push the URL to the end of the file seems to work better on
		# some systems in contrast to unshift.
		push @$cache_a, $url;
		if ($max_cache > 0 && $cache_size > $max_cache) {
			$tmp = shift @$cache_a;
			delete $cache_h->{$tmp};
		}
		log_url($nick, $chan_or_nick, $url);
	} 
}

sub url_topic {
	my ($server, $channel, $topic, $nick, $hostmask) = @_;
	url_message($server, $topic, $nick, $hostmask, $channel);
}

sub url_message {
	my ($server, $rawtext, $nick, $hostmask, $channel) = @_;
	my ($url, $permit, $chan_or_nick);

	if (defined($url = scan_url($rawtext))) {
		$chan_or_nick = defined $channel ? $channel : $server->{nick};
		if (defined($permit = logging_permited($nick, $chan_or_nick)) && $permit) {
			do_locked(\&do_with_caches, \&url_msg_log, $nick, $chan_or_nick, $url); 
		}
	}
}

sub url_cmd_show {
	my ($cache_a, $cache_h) = @_;
	my $n = 0;
	p_normal("urlplot: total of " . scalar(@$cache_a) . " URLs");
	foreach my $url (@$cache_a) {
		 p_normal(sprintf("%02d - %s", $n++, $url));
	}
}

sub url_cmd_clearcaches {
	my ($cache_a, $cache_h) = @_;
	@$cache_a = ();
	%$cache_h = ();
}

sub url_cmd_real_navigate {
	my ($url) = @_;
	die 'no URLs captured so far' unless $url;
	my $url_cmd = Irssi::settings_get_str(KEY_URL_COMMAND)
		|| die "missing setting for @{[ KEY_URL_COMMAND ]}";
	unless ($url_cmd =~ s/__URL__/$url/g) {
		die "setting url_cmd doesn't contain an URL placeholder '__URL__'";
	}
	system($url_cmd);
}

sub url_cmd_navigate {
	my ($cache_a, $cache_h, $n) = @_;
	my ($len, $url) = scalar @$cache_a;
	unless (defined $n) {
		$n = $len > 0 ? $len - 1 : $len;
	}
	die "no such URL; I've only $len" unless $n < $len;
	$url = $cache_a->[$n];
	die 'no URLs captured so far' unless $url;
	url_cmd_real_navigate $url;
}

sub url_command {
	my ($data, $server, $witem) = @_;
	$_ = $data;
	if (/^-list/) {
		do_locked(\&do_with_caches, \&url_cmd_show);
	} elsif (/^-clearcache/) {
		do_locked(\&do_with_caches, \&url_cmd_clearcaches);
	} elsif (/^-showlog/) {
		my $nav_url = Irssi::settings_get_str(KEY_URL_NAVIGATE)
			|| die "missing setting for @{[ KEY_URL_NAVIGATE ]}";
		url_cmd_real_navigate $nav_url;
	} else {
		my $n;
		if (/^(\d+)/) {
			$n = $1;
			if ($n < 0) {
				p_error("argument must be a positive integer");
				return;
			}
		} elsif (/^$/) {
			$n = undef;
		} else {
			p_error("usage for /url [-list|-showlog|-clearcache|<digit>]");
			return;
		}
		do_locked(\&do_with_caches, \&url_cmd_navigate, $n);
	}
}

Irssi::signal_add_last('message public', 'url_message');
Irssi::signal_add_last('message private', 'url_message');
Irssi::signal_add_last('message topic', 'url_topic');
Irssi::command_bind('url', 'url_command');

Irssi::settings_add_str('misc', KEY_URL_COMMAND, DEF_URL_COMMAND);
Irssi::settings_add_int('misc', KEY_URL_CACHE_MAX, DEF_URL_CACHE_MAX);
Irssi::settings_add_str('misc', KEY_URL_LOG_BASEDIR, mk_home(DEF_URL_LOG_BASEDIR));
Irssi::settings_add_str('misc', KEY_URL_LOG_FILE_NAME, DEF_URL_LOG_FILE_NAME);
Irssi::settings_add_str('misc', KEY_URL_CHAN_PREFIX, DEF_URL_CHAN_PREFIX);
Irssi::settings_add_bool('misc', KEY_URL_CHAN_LOGGING, DEF_URL_CHAN_LOGGING);
Irssi::settings_add_str('misc', KEY_URL_LOG_CSV_FILE_NAME, DEF_URL_LOG_CSV_FILE_NAME);
Irssi::settings_add_int('misc', KEY_URL_LOG_CSV_FILE_MAX_SIZE, DEF_URL_LOG_CSV_FILE_MAX_SIZE);
Irssi::settings_add_str('misc', KEY_URL_LOG_CSV_SEPARATOR, DEF_URL_LOG_CSV_SEPARATOR);
Irssi::settings_add_bool('misc', KEY_URL_CSV_LOGGING, DEF_URL_CSV_LOGGING);
Irssi::settings_add_bool('misc', KEY_URL_CSV_CHAN_LOGGING, DEF_URL_CSV_CHAN_LOGGING);
Irssi::settings_add_str('misc', KEY_URL_TIME_FORMAT, DEF_URL_TIME_FORMAT);
Irssi::settings_add_int('misc', KEY_URL_LOG_FILE_MAX_SIZE, DEF_URL_LOG_FILE_MAX_SIZE);
Irssi::settings_add_int('misc', KEY_URL_LOG_FILE_AUTORELOAD_TIME, 
				DEF_URL_LOG_FILE_AUTORELOAD_TIME);
Irssi::settings_add_str('misc', KEY_URL_DB_BASEDIR, mk_home(DEF_URL_DB_BASEDIR));
Irssi::settings_add_str('misc', KEY_URL_DB_CACHE_A_FILENAME, DEF_URL_DB_CACHE_A_FILENAME);
Irssi::settings_add_str('misc', KEY_URL_DB_CACHE_H_FILENAME, DEF_URL_DB_CACHE_H_FILENAME);
Irssi::settings_add_str('misc', KEY_URL_DB_LOCK_FILENAME, DEF_URL_DB_LOCK_FILENAME);

Irssi::settings_add_str('misc', KEY_URL_POLICY_DEFAULT, DEF_URL_POLICY_DEFAULT);
Irssi::settings_add_str('misc', KEY_URL_POLICY_CHANS, DEF_URL_POLICY_CHANS);
Irssi::settings_add_str('misc', KEY_URL_POLICY_NICKS, DEF_URL_POLICY_NICKS);
Irssi::settings_add_str('misc', KEY_URL_NAVIGATE, 'file://' . mk_home(DEF_URL_NAVIGATE));

#
# $Log$
#
