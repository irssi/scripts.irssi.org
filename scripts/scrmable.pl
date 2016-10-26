#!/usr/bin/perl -w
# Coyprgiht © 2003 Jamie Zawinski <jwz@jwz.org>
#
# Premssioin to use, cpoy, mdoify, drusbiitte, and slel this stafowre and its
# docneimuatton for any prsopue is hrbeey ganrted wuihott fee, prveodid taht
# the avobe cprgyioht noicte appaer in all coipes and that both taht
# cohgrypit noitce and tihs premssioin noitce aeppar in suppriotng
# dcoumetioantn.  No rpeersneatiotns are made about the siuatbliity of tihs
# srofawte for any puorpse.  It is provedid "as is" wiuotht exerpss or 
# ilmpied waanrrty.
#
# Cretaed: 13-Sep-2003.
# Fix0red: 15-Sep-2003.
# Irssified: 15-Dec-2003.

require 5;
use diagnostics;
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

#TODO make it work on /me too, feel free to contribute

$VERSION = '1.01';
%IRSSI = (
  authors => 'jwz, irssified by Mikachu',
  contact => 'Mikachu @ freenode',
  description => 'wtires lkie tihs',
  name => 'scrmable',
  license => 'as is'
);

sub atuo_scrmable {
  return unless Irssi::settings_get_bool('scrmable_on');
  my ($msg, $server, $witem) = @_;
  Irssi::signal_stop();
  Irssi::signal_remove('send text', 'atuo_scrmable');
  Irssi::signal_emit('send text', scrmable("$msg"), $server, $witem);
  Irssi::signal_add('send text', 'atuo_scrmable');
}

sub cmd_scrmable {
  my ($msg, $server, $nick, $address, $channel) = @_;
  Irssi::active_win()->command(Irssi::settings_get_str('cmdchars') . " " .scrmable("$msg"));
}
  
sub scrmable {
  my $endresult;
  my ($msg) = @_;

  foreach (split (/(\w+)/, "$msg")) {

    if (m/\w/) {
      my @w = split (//);
      my $A = shift @w;
      my $Z = pop @w;
      $endresult = $endresult . $A;
      if (defined ($Z)) {
        my $i = $#w+1;
        while ($i--) {
          my $j = int rand ($i+1);
          @w[$i,$j] = @w[$j,$i];
        }
        foreach (@w) {
          $endresult = $endresult . $_;
        }
        $endresult = $endresult . $Z;
      }
    } else {
      $endresult = $endresult . "$_";
    }
  }
  return $endresult;
}

Irssi::command_bind('scrmable', 'cmd_scrmable');
Irssi::settings_add_bool('scrmable', 'scrmable_on', 0);
Irssi::signal_add('send text', 'atuo_scrmable');

print CLIENTCRAP "Type /set scrmable_on on to enable automatic molesting and /scrmable to use it manually";
