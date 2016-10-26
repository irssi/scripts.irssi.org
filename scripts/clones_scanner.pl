use strict;
use warnings;

{ package Irssi::Nick }
# just in case, to avoid Irssi::Nick warnings ( see http://bugs.irssi.org/index.php?do=details&task_id=242 )

use Irssi;
use vars qw($VERSION %IRSSI);

# Thanks to:
# -noi_esportista!#Girona@chathispano for his suggestions about how this script should work.
# -dg!#irssi@freenode (David Leadbeater) for the several code style issues that he pointed out and that helped me to improve my Perl.

$VERSION = '1.6';
%IRSSI = (
	authors     => 'Pablo Martín Báez Echevarría',
	contact     => 'pab_24n@outlook.com',
	name        => 'clones_scanner',
	description => 'when a nick joins #channel, notifies you if there is (or there has been) someone in #channel with the same hostname',
	license     => 'Public Domain',
	url         => 'http://reirssi.wordpress.com',
	changed     => '22:30:25, Dec 20th, 2014 UYT',
);

#
# USAGE
# =====
# Copy the script to ~/.irssi/scripts/
#
# In irssi:
#          /run clones_scanner
#
#
# OPTIONS
# =======
# Settings can be resetted to defaults with /set -default
#
# /set clones_scanner_maxtime <time>
# * This is the maximum time in which the script remembers that a specific hostname 
#   left a channel because of a PART, QUIT or KICK event (default is 900secs = 15mins).
#   For example, suppose it is 1 hour. If someone with mask type nick1!*@host left #channel 
#   at 11:00 and then comes back at 12:01 with mask type nick2!*@host, you will not be 
#   notified that 'nick2' was seen earlier in #channel as 'nick1'. 
#   It must be a time type, that is a series of integers with optional unit specifiers.
#   Valid specifiers are:
#
#   d[ays]
#   h[ours]
#   m[inutes]
#   s[econds]
#   mil[liseconds] | ms[econds]
#
#   Any unambiguous part of a specifier can be used, as shown by the strings in braces in 
#   the above list. Multiple specifiers can be combined, with or without spaces between them.
#
#   Examples:
#
#   /set clones_scanner_maxtime 1hour30mins
#   /set clones_scanner_maxtime 2h
#   /set clones_scanner_maxtime 3h 10secs
#
#   There must not be a space between the number and the unit specifier.
#
#
# COMMANDS
# ========
# /clones_scanner_size
# * Displays how many entries the data structure where the hosts are stored has, and how much 
#   memory is used for that purpose.
#
#   WARNING: This feature requires Devel::Size module. It seems that when installing Devel::Size
#            some tests started to fail since Perl 5.19.3 so if you're using the latest Perl release 
#            (Perl 5.20.1) you'll have to wait for someone to fix Devel::Size for recent Perl versions.
#            See more about this issue at: https://rt.cpan.org/Public/Bug/Display.html?id=95493
#            Remeber that you can find out Perl version with
#            $ perl -v
#            in a terminal or alternatively executing /script exec print $^V in irssi.
#


Irssi::settings_add_time('clones_scanner', 'clones_scanner_maxtime', 900);

# global variables
my $have_devel_size = eval { require Devel::Size };
my %hosts_hash  = ();
my $old_maxtime_msecs;
my $old_maxtime_str;
my $total_entries = 0;

##########

sub add_entry {
  my ( $network, $channel, $address, $nick ) = @_;
  
  (my $host = $address) =~ s/^[^@]+@//;

  if (defined $hosts_hash{$network}{$channel}{$host}) {
    my $old_tag = $hosts_hash{$network}{$channel}{$host}[2];
    Irssi::timeout_remove( $old_tag );
    $total_entries--;
  }
  
  my $time = Irssi::settings_get_time("clones_scanner_maxtime");
  my @data = ( $network, $channel, $host );
  my $tag  = Irssi::timeout_add_once($time, "remove_entry", \@data);

  my $entry = [$nick, time(), $tag];
  $hosts_hash{$network}{$channel}{$host} = $entry;
  $total_entries++;
  
}

sub str_time {
  my ( $secs ) = @_;
  
  my $d = int($secs/3600/24);
  my $h = int($secs/3600%24);
  my $m = int($secs/60%60);
  my $s = int($secs%60);
  
  my $d_str = ($d == 1) ? "day": "days";
  my $h_str = ($h == 1) ? "hour": "hours";
  my $m_str = ($m == 1) ? "minute": "minutes";
  my $s_str = ($s == 1) ? "second": "seconds";
  
  my $raw_str = $d.$d_str.", ".$h.$h_str.", ".$m.$m_str.", ".$s.$s_str;
  
  (my $str_res = $raw_str) =~ s/\b0\w+(?:,\s)?//g;
  ($str_res    = $str_res) =~ s/,\s$//;
  ($str_res    = $str_res) =~ s/(\d)([dhms])/$1 $2/g; 
  
  return $str_res eq "" ? "less than 1 second" : $str_res;
}

sub remove_entry {
  my ( $ref_data ) = @_;
  
  my $network = @{$ref_data}[0];
  my $chan    = @{$ref_data}[1];
  my $host    = @{$ref_data}[2];
  
  delete $hosts_hash{$network}{$chan}{$host};
  $total_entries--;
  delete $hosts_hash{$network}{$chan} if (!keys %{$hosts_hash{$network}{$chan}});
  delete $hosts_hash{$network} if (!keys %{$hosts_hash{$network}});
}

sub update_hash {
  my ( $nw_maxtime ) = @_;
  my $remainder;
  my $ni;
  my $se;
  my $tg;
  my $nw_tg;

  foreach my $network (keys %hosts_hash) {
    foreach my $channel (keys %{$hosts_hash{$network}}) {
      foreach my $host (keys %{$hosts_hash{$network}{$channel}}) {
        $ni = @{$hosts_hash{$network}{$channel}{$host}}[0];
        $se = @{$hosts_hash{$network}{$channel}{$host}}[1];
        $tg = @{$hosts_hash{$network}{$channel}{$host}}[2];
        Irssi::timeout_remove( $tg );
        $remainder = $nw_maxtime - (time() - $se);
        if( $remainder > 0 ) {
          my @data = ( $network, $channel, $host );
          $nw_tg   = Irssi::timeout_add_once( $remainder*1000, "remove_entry", \@data);
          $hosts_hash{$network}{$channel}{$host} = [$ni, $se, $nw_tg];
        } else {
          delete $hosts_hash{$network}{$channel}{$host};
          $total_entries--;
        }
      }
      delete $hosts_hash{$network}{$channel} if (!keys %{$hosts_hash{$network}{$channel}});
    }
    delete $hosts_hash{$network} if (!keys %{$hosts_hash{$network}});
  }
  
}

sub setup_changed {
  my $new_maxtime_msecs = Irssi::settings_get_time("clones_scanner_maxtime");
  if($new_maxtime_msecs < 10) {
    Irssi::print("Invalid timestamp (must be >= 10 msecs)", MSGLEVEL_CLIENTERROR);
    Irssi::settings_set_time("clones_scanner_maxtime", $old_maxtime_str);
    $new_maxtime_msecs = Irssi::settings_get_time("clones_scanner_maxtime");
  }
  update_hash(int($new_maxtime_msecs/1000)) if ($new_maxtime_msecs != $old_maxtime_msecs);
}

##########

sub part_method {
  my ($server, $channel, $nick, $address, $reason) = @_;

  add_entry($server->{tag}, $channel, $address, $nick);
}

sub quit_method {
  my ($server, $nick, $address, $reason) = @_;

  foreach($server->channels()) {
    if ($_->nick_find($nick)) {
      add_entry($server->{tag}, $_->{name}, $address, $nick);
    }
  }
}

sub kick_method {
  my ($server, $channel, $nick, $kicker, $address, $reason) = @_;
  
  Irssi::signal_stop();
  my $kicked_address = $server->channel_find($channel)->nick_find($nick)->{host};
  Irssi::signal_continue(@_);
  add_entry($server->{tag}, $channel, $kicked_address, $nick);
}

##########

sub join_method {
  my ($server, $channel, $nick, $address) = @_;
  
  Irssi::signal_continue(@_);
  
  my $servtag  =  $server->{tag};
  (my $host    = $address) =~ s/^[^@]+@//;
  my $chan_rec = $server->channel_find($channel);

  # ==== find clones ====
  my $ni_host;
  my $str_clones = "";
  my @clones;
  foreach my $ni ($chan_rec->nicks()) {
    ($ni_host = "$ni->{host}") =~ s/^[^@]+@//;
    if ( ($ni->{nick} ne $nick)&&($ni_host eq $host) ) {
      $str_clones .= "$ni->{nick}".", ";
      push @clones, $ni->{nick};
    }
  }
  if( $str_clones ne "") {
    ($str_clones = $str_clones) =~ s/,\s$//;
    $chan_rec->printformat(Irssi::MSGLEVEL_JOINS, "clones_scanner_clones", $nick, $str_clones);
  }
  
  # ==== search in %hosts_hash ====
  my $exists_nick_in_hash = (defined $hosts_hash{$servtag})&&(defined $hosts_hash{$servtag}{$channel})
  &&(defined $hosts_hash{$servtag}{$channel}{$host});
  
  if ($exists_nick_in_hash) {
    my @alias = @{ $hosts_hash{$servtag}{$channel}{$host} };
    if ( ($nick ne $alias[0]) && (!(grep {$_ eq $alias[0]} @clones)) ) {
      my $time = Irssi::settings_get_time("clones_scanner_maxtime");
      $chan_rec->printformat( Irssi::MSGLEVEL_JOINS, "clones_scanner_track_nick", $nick, str_time(int($time/1000)), 
      $alias[0], str_time(time()-$alias[1]));
    }
  }

}

##########

Irssi::theme_register([
    "clones_scanner_clones", 'Clones of {nick $0}: $1',
    "clones_scanner_track_nick", '=> {nick $0} was seen during the last $1 as {nick $2} ($3 ago)',
]);

##########


if ($have_devel_size) {
  
  Irssi::command_bind('clones_scanner_size' , sub {
    my $bytes = Devel::Size::total_size(\%hosts_hash);
    print "Number of entries in \%hosts_hash: ", $total_entries;
    print "Size in bytes: ", $bytes;
    print int($bytes/1024/1024)."MB ".int($bytes/1024%1024)."kB ".int($bytes%1024)."B of data";
  });

} else {

  print "Missing Devel::Size module. The command `/clones_scanner_size` will not be available.";

}

Irssi::signal_add_first('message part', \&part_method); 
Irssi::signal_add_first('message quit', \&quit_method);
Irssi::signal_add_first('message kick', \&kick_method);

Irssi::signal_add_last('message join', \&join_method);

Irssi::signal_add_last('setup changed', \&setup_changed);

Irssi::signal_add_first('send command', 
sub { 
 $old_maxtime_msecs = Irssi::settings_get_time("clones_scanner_maxtime");
 $old_maxtime_str   = Irssi::settings_get_str("clones_scanner_maxtime");
});
