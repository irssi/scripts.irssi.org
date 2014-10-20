#!/usr/bin/perl -w
use strict;
use Irssi 20010120.0250 ();
use vars qw($VERSION %IRSSI);
$VERSION = "1";
%IRSSI = (
    authors     => 'David Leadbeater',
    contact     => 'dgl@dgl.cx',
    name        => 'remote',
    description => 'Lets you run commands remotely via /msg and a password',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.dgl.cx/',
);


# Usage:
# as your user /remote on (uncomment the $remote = 1 line below if you want it
# on by default)
# /msg user remote login password
# then /msg user remote command
# it will execute the command on the same server...
# so you can do mode #channel +o whoever
# but it will allow any command, yes it's dangerous if someone knows the
# password they can access just about anything your user account can....
# put a crypted password here
my $password = "pp00000000";
my($login,$remote);
# $remote = 1;

sub event{
   my($server,$text,$nick,$hostmask)=@_;
# if you're really paranoid change this....
   if($text =~ s/^remote\s+//i){
	  my $ok;
      $ok = 1 if $login eq $nick."!".$hostmask;
	  $ok = 0 if !defined $remote;
	  my($command,$options) = split(/ /,$text,2);
	  if($command eq "login"){
		 if(crypt($options,substr($password,0,2)) eq $password){
			$login = $nick."!".$hostmask;
		 }else{
			Irssi::print("Invaild login attempt from $nick ($hostmask): $text");
		 }
	  }elsif(!$ok){
		 Irssi::print("Invaild remote use from $nick ($hostmask): $text");
	  }elsif($ok){
		 Irssi::command("/".$text);
	  }
   }
}

sub remote{
   my($args) = shift;
   if($args eq "enable" or $args eq "on"){
	  $remote = 1;
   }else{
	  $remote = undef;
   }
}

Irssi::signal_add_last("message private", "event");
Irssi::command_bind("remote", "remote");

