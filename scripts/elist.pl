#!/usr/bin/perl

# (c) 2007, Ilya Cassina <icassina@gmail.com>
#
# inspired by 'xlist.pl' by Matthäus 'JonnyBG' Wander <jbg@swznet.de>

# Usage: /elist [-min <usercount>] [-max <usercount] [#]<channelmask>


use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Getopt::Long;

$VERSION = '1.0';
%IRSSI = (
    authors     => 'Ilya Cassina',
    contact     => 'icassina@gmail.com',
    name        => 'Enanched LIST',
    description => 'This script allow advanced parametrization ' .
                   'of the /list command. Accepted parameters are ' .
                   '-minusers <#users> and -maxusers <#users>. ',
    license     => 'GPLv2',
);

use Irssi qw(
    command_bind
    signal_add
);

### global variables ####
my %elist_channels = ();
my %elist_config = ();


sub elist_channels_free {
  %elist_channels = ();
}

sub elist_config_init {
  %elist_config = (
    mincount => 0,
    maxcount => 10000,
    chanmask => ""
  );
}

sub elist {
  my ($data, $server, $witem) = @_;

  ### init variables ###
  elist_config_init();
  
  #### processing arguments using Getopt ###
  Getopt::Long::config('permute', 'no_ignore_case');
  
  local(@ARGV) = split(/\s/, $data,);
  GetOptions (
    'mincount|m=i' => \$elist_config{"mincount"},
    'maxcount|M=i' => \$elist_config{"maxcount"},
  );
 
  ## setting chanmask (remaining argument) ##
  if (@ARGV . length == 0) {
    $elist_config{"chanmask"} = "";
  } else {
    # adding '#' character at the beginning if not already present! #
    if ($ARGV[0] !~/^\#.*/) {
      $elist_config{"chanmask"} = "\#". $ARGV[0];
    } else {
      $elist_config{"chanmask"} = $ARGV[0];
    }
  }

  ### sending LIST command to the server ###
  print "%K[%n".$server->{'tag'}."%K]%n %B<-->%n %m"."elist %n%B(%y"."min=%m".$elist_config{"mincount"}."%n".
                                                     ", %y"."max=%m".$elist_config{"maxcount"}."%n".
                                                     ", %y"."mask=%K'%m".$elist_config{"chanmask"}."%K'%B)";
  $server->command("LIST " . $elist_config{"chanmask"});
}


sub elist_collect {
  my ($server, $data) = @_;
          
  my (undef, $channel, $users, $topic) = split(/\s/, $data, 4);
  $topic = substr($topic, 1);
                 
  if ($users >= $elist_config{"mincount"} and $users <= $elist_config{"maxcount"}) {
    push @{$elist_channels{$users}}, [ $channel, $topic ];
  }
}

sub elist_show {
  my ($server) = @_;
  my ($printstring, $channel);

  ## keys of elist_channels are (int) users in channel ##
  foreach (reverse sort { $a <=> $b } keys %elist_channels) {
    my $user_count = $_;
    ## values are arrays of [ channel_name, topic ] ##
    foreach (@{$elist_channels{$user_count}}) {
      $printstring = "%K[%n" . $server->{'tag'} . "%K]%n " .
                      sprintf("%4d", $user_count ) .
                      " " . @{$_}[0];  ## channel name
      if (length @{$_}[1] > 0) {
        $printstring .= " %B->%n " . @{$_}[1]; ## topic
      }

      print $printstring;
    }
  }

  elist_channels_free();

  print "%K[%n".$server->{'tag'}."%K]%n %B<-->%n End of %m"."elist%n";
}

command_bind('elist', \&elist);
signal_add('event 322', \&elist_collect);
signal_add('event 323', \&elist_show);


##print "Usage: /elist [-min <usercount>] [-max <usercount] [#]<channelmask>"

# EOF #
