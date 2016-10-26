#!/usr/bin/perl
use Irssi;
use DBI;
use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "0.1";
%IRSSI = (
    authors     => "Jesper Lindh",
    contact     => "rakblad\@midgard.liu.se",
    name        => "IRC Completion with mysql-database",
    description => "Adds words from IRC to your tab-completion list",
    license     => "Public Domain",
    url         => "http://midgard.liu.se/~n02jesli/perl/",
    changed     => "2004-03-12"
);
my ($dsn) = "DBI:mysql:yourdatabase:databashostname";
my ($user_name) = "yourusername";
my ($password) = "yourpassword";
my ($dbh, $sth);
my (@ary);
my $query;
my $connect = 1;
$dbh = DBI->connect ($dsn, $user_name, $password, { RaiseError => 1 });

sub wordsearch
{
	my $sw = shift;
	my @retar;
	my $i = 0;
	$query = qq{ select word from words where word like "$sw%" order by prio desc };
	$sth = $dbh->prepare ( $query );
	$sth->execute();
	while (@ary = $sth->fetchrow_array ())
	{
        	$retar[$i++] = join ("", @ary), "\n";
	}
	$sth->finish();
	return @retar;
};
sub wordfind
{
	my $sw = shift;
	my $ret;
	$query = qq{ select word from words where word = "$sw" };
        $sth = $dbh->prepare ( $query );
        $sth->execute();
        @ary = $sth->fetchrow_array;
        $ret = join ("", @ary), "\n";
        $sth->finish();
	return $ret;
};

sub wordupdate
{
	my $sw = shift;
	$query = qq { update words set prio = prio + 1 where word = "$sw" };
        $sth = $dbh->prepare ( $query );
        $sth->execute();
        $sth->finish();
};
sub delword
{
	my $sw = shift;
	$query = qq { delete from words where word = "$sw" };
        $sth = $dbh->prepare ( $query );
        $sth->execute();
        $sth->finish();
};
sub addword
{
	my $sw = shift;
	$query = qq { insert into words values ('$sw', 1) };
        $sth = $dbh->prepare ( $query );
        $sth->execute();
        $sth->finish();
};
sub word_complete
{
	my ($complist, $window, $word, $linestart, $want_space) = @_;
        $word =~ s/([^a-zA-Z0-9åäöÅÄÖ])//g;
	@$complist = wordsearch($word);	
};
sub word_message
{
        my ($server, $message) = @_;
        foreach my $word (split(' ', $message))
        {
		$word =~ s/([^a-zA-Z0-9åäöÅÄÖ])//g;
		if (length($word) >= 4)
		{
			my $fword = wordfind($word);
			if ($fword)
			{
				wordupdate($word);
			}
			else
			{
				addword($word);
			};
		};
        };
};
sub cmd_delword
{
	my $dword = shift;
	delword($dword);
	print "Deleted $dword from database!";
};
sub cmd_sql_disconnect
{
	$dbh->disconnect();
	print "Disconnected from sql-server";
	$connect = 0;
};
sub cmd_sql_connect
{
	if ($connect != 0)
	{
		print "Connecting to sql-server";
		$dbh = DBI->connect ($dsn, $user_name, $password, { RaiseError => 1 });
	}
	else
	{
		print "Already connected";
	};
};
		
foreach my $cword ("message own_public", "message own_private")
{
        Irssi::signal_add($cword, "word_message");
};
Irssi::signal_add_last('complete word', 'word_complete');
Irssi::command_bind("delword", "cmd_delword");
Irssi::command_bind("sql_disconnect", "cmd_sql_disconnect");
Irssi::command_bind("sql_connect", "cmd_sql_connect");

