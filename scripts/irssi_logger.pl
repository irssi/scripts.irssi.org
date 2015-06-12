use warnings;
use strict;
use DBI;
use Irssi;
use Irssi::Irc;
use POSIX qw/strftime/;

use vars qw($VERSION %IRSSI);

# Requirements:
# - postgresql
# - postgresql-contrib (pg_trgm)

$VERSION = "1.0";
%IRSSI = (
    authors     => "Aaron Bieber",
    contact     => "deftly\@gmail.com",
    name        => "irssi_logger",
    description => "Logs chats to a PostgreSQL database.",
    license     => "BSD",
    url         => "https://github.com/qbit/irssi_logger",
    );

my $user = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
my $dbh;


my $sql = qq~
insert into logs (logdate, nick, log, channel) values (?, ?, ?, ?)
~;
my $search = qq~
SELECT log, similarity(log, ?) AS sml
  FROM logs
  WHERE log % ? and
  channel = ?
  ORDER BY sml DESC, log
  LIMIT 1;
~;
my $check_db = qq~
select true as exists from pg_tables where tablename = 'logs';
~;
my $create = qq~
CREATE TABLE logs (
  id serial not null,
  dateadded timestamp without time zone default now(),
  logdate timestamp without time zone default now(),
  nick text not null,
  log text not null,
  channel text not null
)
~;
my $init_pg_trgm = qq~
CREATE extension pg_trgm
~;
my $create_trgm_idx = qq~
CREATE index logs_trgm_idx on logs USING gist (log gist_trgm_ops);
~;
my $create_date_idx = qq~
CREATE index logs_date_idx on logs (logdate)
~;
my $create_chan_idx = qq~
CREATE index logs_nick_idx on logs (nick)
~;

sub db_init {
    my ($dbname, $dbuser, $dbpass) = @_;
    my $mdbh = DBI->connect("dbi:Pg:dbname=$dbname", $dbuser, $dbpass) || Irssi::print("Can't connect to postgres! " . DBI::errstr);

    my $sth = $mdbh->prepare($check_db);
    $sth->execute();
    my $row = $sth->fetchrow_hashref();

    if (! $row->{exists}) {
	Irssi::print("Creating database.");
	$mdbh->do($create) || Irssi::print("Can't create db! " . DBI::errstr);
	$mdbh->do($init_pg_trgm) || Irssi::print("Can't create extension " . DBI::errstr);
	$mdbh->do($create_trgm_idx) || Irssi::print("Can't create trgm index " . DBI::errstr);
	$mdbh->do($create_date_idx) || Irssi::print("Can't create date index " . DBI::errstr);
	$mdbh->do($create_chan_idx) || irssi::print("Can't create chan index " . DBI::errstr);
    } else {
	Irssi::print("Database already exists.");
    }
    $sth->finish();
    $mdbh->disconnect();

    return 1;
}

sub connect_db {
    my $dbname = Irssi::settings_get_str('il_dbname') || $user;
    my $dbuser = Irssi::settings_get_str('il_dbuser') || $user;
    my $dbpass = Irssi::settings_get_str('il_dbpass') || "";

    db_init($dbname, $dbuser, $dbpass);

    Irssi::print("Connecting to the database");

    return DBI->connect("dbi:Pg:dbname=$dbname", $dbuser, $dbpass) || Irssi::print("Can't connect to db!" . DBI::errstr);
}

sub write_db {
    my ($nick, $message, $target) = @_;
    my @vals;
    my $date = strftime("%Y-%m-%d %H:%M:%S", localtime);

    $dbh = connect_db() unless $dbh;

    push(@vals, $date);
    push(@vals, $nick);
    push(@vals, $message);
    push(@vals, $target);

    defined or $_ = "" for @vals;

    $dbh->do($sql, undef, @vals) || Irssi::print("Can't log to DB! " . DBI::errstr);
}

sub log_me {
    my ($server, $message, $target) = @_;
    write_db($server->{nick}, $message, $target);
}

sub log {
    my ($server, $message, $nick, $address, $target) = @_;
    write_db($nick, $message, $target)
}

Irssi::signal_add_last('message public', 'log');
Irssi::signal_add_last('message own_public', 'log_me');

Irssi::settings_add_str('irssi_logger', 'il_dbname', $user);
Irssi::settings_add_str('irssi_logger', 'il_dbuser', $user);
Irssi::settings_add_str('irssi_logger', 'il_dbpass', "");

Irssi::print("irssi_logger loaded!");
