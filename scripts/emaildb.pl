#!/usr/bin/perl
# Please note that some MySQL experience is required to use this script.
# 
# You must have the appropriate tools installed for MySQL and Perl to "talk"
# to each other... specifically perl dbi and DBD::mysql
# 
# You must set up the following table `13th` in your mysql database:
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
# change the settings in irssi (see /set emaildb).
#
# if you choose to make this accessible by users on a user-list only, create
# a text file called "emaildb_users" in your home .irssi directory, add the nicknames 
# of users you wish to give access in this format:
#
# PrincessLeia2
# R2D2
# Time
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
# the ~nick command themselves
#
# 
# ... That's about it, enjoy!
# 

use strict;
use Irssi;
use DBI;
use vars qw($VERSION %IRSSI);

$VERSION = "1.2";
%IRSSI = (
    authors => 'PrincessLeia2',
    contact => 'lyz\@princessleia.com ',
    name => 'emaildb',
    description => 'a script for accessing an email mysql database through irc',
    license => 'GNU GPL v2 or later',
    url => 'http://www.princessleia.com/'
);

my $LIST;
my @user;
my $filename = Irssi::get_irssi_dir().'/emaildb_users';
if (! -e $filename) {
  my $fa;
  open $fa, '>', $filename;
  close $fa;
}
open ( $LIST, '<', $filename ) or die "can't open users:$!\n";
chomp( @user = <$LIST> );
close $LIST;

if (1 > @user) {
  Irssi::print("%RWarning:%n no users defined (see: $filename)",MSGLEVEL_CLIENTNOTICE);
}

# database
my $d;
# user
my $u;
# password
my $p;

sub event_privmsg {
my ($server, $data, $nick, $mask, $target) =@_;
my ($ta, $text) = $data =~ /^(\S*)\s:(.*)/;
  if ($text =~ /^~search */i ) {
    foreach my $person (@user) {
      if ($nick =~ /^$person$/i) {
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
        } else {
          $server->command ( "msg $nick Sorry, No Results Match Your Query\n" );
        }
      }
    }
  }
}

sub event_setup_changed {
  $d=Irssi::settings_get_str($IRSSI{name}.'_database');
  $u=Irssi::settings_get_str($IRSSI{name}.'_user');
  $p=Irssi::settings_get_str($IRSSI{name}.'_password');
}

Irssi::signal_add('event privmsg', 'event_privmsg');
Irssi::signal_add('setup changed','event_setup_changed');

Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_database', 'database');
Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_user', 'user');
Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_password', 'password');

event_setup_changed();

# vim:set ts=4 sw=2 expandtab:
