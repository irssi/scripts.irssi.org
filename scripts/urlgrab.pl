#!/usr/bin/perl -w
use Irssi 20010120.0250 ();
$VERSION = "0.2";
%IRSSI = (
    authors     => 'David Leadbeater',
    contact     => 'dgl@dgl.cx',
    name        => 'urlgrab',
    description => 'Captures urls said in channel and private messages and saves them to a file, also adds a /url command which loads the last said url into mozilla.',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.dgl.yi.org/',
);

use strict;
my $lasturl;

# Change the file path below if needed
my $file = "$ENV{HOME}/.urllog";

sub url_public{
   my($server,$text,$nick,$hostmask,$channel)=@_;
   my $url = find_url($text);
   url_log($nick, $channel, $url) if defined $url;
}

sub url_private{
   my($server,$text,$nick,$hostmask)=@_;
   my $url = find_url($text);
   url_log($nick, $server->{nick}, $url) if defined $url;
}

sub url_cmd{
   if(!$lasturl){
	  Irssi::print("No url captured yet");
	  return;
   }
   system("netscape-remote -remote 'openURL($lasturl)' &>/dev/null");
}

sub find_url {
   my $text = shift;
   if($text =~ /((ftp|http):\/\/[a-zA-Z0-9\/\\\:\?\%\.\&\;=#\-\_\!\+\~]*)/i){
	  return $1;
   }elsif($text =~ /(www\.[a-zA-Z0-9\/\\\:\?\%\.\&\;=#\-\_\!\+\~]*)/i){
	  return "http://".$1;
   }
   return undef;
}

sub url_log{
   my($where,$channel,$url) = @_;
   return if lc $url eq lc $lasturl; # a tiny bit of protection from spam/flood
   $lasturl = $url;
   open(URLLOG, ">>$file") or return;
   print URLLOG time." $where $channel $lasturl\n";
   close(URLLOG);
}

Irssi::signal_add_last("message public", "url_public");
Irssi::signal_add_last("message private", "url_private");
Irssi::command_bind("url", "url_cmd");

