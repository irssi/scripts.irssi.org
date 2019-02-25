#!/usr/bin/perl -w
use strict;
use Irssi 20010120.0250 ();
use vars qw($VERSION %IRSSI);
$VERSION = "1.1";
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
# set password with /remote passwd <password>
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
   } elsif (index($args, 'password') != -1) {
	  cmd_passwd($args);
   }else{
	  $remote = undef;
   }
}

sub cmd_passwd {
   my ($args)= @_;
   my @arg= split(/\s+/, $args);
   my @chars= map {chr($_)} (0x41 .. 0x5a, 0x61 .. 0x7a, 0x30 .. 0x39, 0x2e);
   my $len= scalar(@chars);
   my $salt= '';
   foreach (1..2) {
	  $salt .= $chars[int(rand($len))];
   }
   Irssi::settings_set_str($IRSSI{name}.'_password', crypt($arg[1],$salt));
}

sub sig_setup_changed {
   $password = Irssi::settings_get_str($IRSSI{name}.'_password');
   if (length($password) != 13) {
	  $password = "pp00000000";
   }
}

Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_password','pp00000000');

Irssi::signal_add('setup changed','sig_setup_changed');
Irssi::signal_add_last("message private", "event");
Irssi::command_bind("remote", "remote");
Irssi::command_bind("remote password", "remote");

sig_setup_changed();

# vim:set sw=3 ts=4:
