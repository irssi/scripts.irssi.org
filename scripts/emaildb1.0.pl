#!/usr/bin/perl
# Please note that some MySQL experience is required to use this script.
# 
# You must have the appropriate tools installed for MySQL and Perl to "talk"
# to each other... specifically perl dbi and DBD::mysql
# 
# You must set up the following table in your mysql database:
#
# +----------+-------------+------+-----+---------+-------+
# | Field    | Type        | Null | Key | Default | Extra |
# +----------+-------------+------+-----+---------+-------+
# | nickname | varchar(40) | YES  |     | NULL    |       |
# | email    | varchar(40) | YES  |     | NULL    |       |
# | birthday | varchar(40) | YES  |     | NULL    |       |
# +----------+-------------+------+-----+---------+-------+
#
# I suggest you set up a separate user in the mysql database to use this script
# with only permission to SELECT from this database.
# </paranoia>
#
# In the script you must replace the following variables with your information:
#
#    $d = database name
#    $u = user login for database
#    $p = user password
#
# if you choose to make this accessible by users on a user-list only, create
# a text file called "users" in your home .irssi directory, add the nicknames 
# of users you wish to give access in this format:
#
# PrincessLeia2
# R2D2
# Time
#
# AND uncomment the 3 sections indicatated in the script
#
# I never created an interface to add new nicknames, email, and birthday, 
# so you will need to manually insert this information into the database
# 
# This script allows a user to search the database by using the command ~search nickname 
# (in channel, or in pm) it will respond with a private message. It will match full and
# partial nicknames while it does it's search (if you search for 't' it will give you 
# results of any nicknames with a 't' i nthem)
# 
# Personally, I run this in an ircbot, as the owner of this script cannot use
# the ~search command themselves
#
# 
# ... That's about it, enjoy!
# 

use strict;
use Irssi;
use DBI;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
    authors => 'PrincessLeia2',
    contact => 'lyz\@princessleia.com ',
    name => 'emaildb',
    description => 'a script for accessing an email mysql database through irc',
    license => 'GNU GPL v2 or later',
    url => 'http://www.princessleia.com/'
);


# uncomment the following commented (and replace '/home/user' with your home directory) lines for user restricted access.
#
# open ( LIST, "</home/lyz/.irssi/users" ) or die "can't open users:$!\n";
#  chomp( @user = <LIST> );
#         close LIST;

my $d = ('database');
my $u = ('user');
my $p = ('password');


sub event_privmsg {
my ($server, $data, $nick, $mask, $target) =@_;
my ($target, $text) = $data =~ /^(\S*)\s:(.*)/;
  if ($text =~ /^~search */i ) {

# Uncomment the following commented lines for user restricted access
#    foreach $person (@user) {
#      if ($nick =~ /^$person$/i) {

		my ($nickname) = $text =~ /^~search (.*)/;

        my $dbh = DBI->connect("DBI:mysql:$d","$u","$p")
                or die "Couldn't connect to database: " . DBI->errstr;
        my $sth = $dbh->prepare("SELECT * FROM 13th where nickname like \"\%$nickname\%\";")
                or die "Cant prepare statement: $dbh->errstr\n";
        my $rv = $sth->execute
                or die "cant execute the query: $sth->errstr\n";
if ($rv >= 1) {
  my @row;
  while ( @row = $sth->fetchrow_array(  ) ) {
	my $n = "$row[0]\n";
 	my $e = "$row[1]\n";
 	my $b = "$row[2]\n";
                $server->command ( "msg $nick Nickname : $n" );
                $server->command ( "msg $nick Email : $e" );
                $server->command ( "msg $nick Birthday : $b" );
}
}
else    {
           $server->command ( "msg $nick Sorry, No Results Match Your Query\n" );
	}

# Uncomment the following commented lines for user restricted access
#}
#}

}
}

Irssi::signal_add('event privmsg', 'event_privmsg');
