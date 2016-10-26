use Irssi;
use 5.6.0;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "0.2.1";
%IRSSI = (
    authors => 'Grigori Goronzy',
    contact => 'greg@chown.ath.cx',
    name => 'antiplenk',
    description => 'notices users who "plenk"',
    license => 'BSD',
    url => 'http://chown.ath.cx/~greg/antiplenk/',
    changed => 'Mi 12 Feb 2003 07:00:05 CET',
);

Irssi::settings_add_str($IRSSI{'name'}, "plenk_channels", "#foobar|#barfoo");
Irssi::settings_add_bool($IRSSI{'name'}, "plenk_spam", "1");
Irssi::settings_add_int($IRSSI{'name'}, "plenk_allowed", "10");
Irssi::signal_add_last('message public', 'plenk');
my %times;

Irssi::print "antiplenk $VERSION loaded";

sub plenk {
my ($server, $msg, $nick, $address, $channel) = @_;
my $spam = Irssi::settings_get_bool("plenk_spam");
my $allowed = Irssi::settings_get_int("plenk_allowed");

# channel in list?
if(!($channel =~ Irssi::settings_get_str("plenk_channels"))) { return 0 }

# check..
while($msg =~ /[[:alnum:]]+ (\.|\,|\?|\!|\: |\; )(\!|\1|\?|\ß|\.|\ |$)/g) {
 # increment
 $times{$nick}++;
 # "debug"
  if($spam) { Irssi::print "antiplenk: $nick plenked on $channel for the $times{$nick}" .
  ($times{$nick} == 1 ? "st" : $times{$nick} == 2 ? "nd" : $times{$nick} == 3 ? "rd" : "th") .
  " time" }
 # too often?
 if($times{$nick} > $allowed ) { 
  $server->command("msg $nick antiplenk: you 'plenked' more than $allowed times! please stop this at once!");
  Irssi::print "antiplenk: $nick got a notice";
  $times{$nick} = 0; }
 }
}
