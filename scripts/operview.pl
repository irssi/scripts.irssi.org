# Operview - reformats some server notices, which may come i.e. from &clients
# or &servers. Also reformat some incoming server numerics from advanced
# commands like STATS.
# 
# Note that whole this script is VERY ircnet-specific!
# 
# Provided variables:
# 
# mangle_stats_output   - turn the mangling of /stats output on/off
# mangle_server_notices - turn the mangling of server notices on/off
# ignore_server_kills   - we won't display nickname collissions
# show_kills_path       - we will display kill's path
# 
# $Id: operview.pl,v 1.11 2002/03/30 21:16:06 pasky Exp pasky $
#


use strict;
use Irssi;
use Irssi::Irc;
use Irssi::TextUI;

use vars qw ($VERSION %IRSSI $rcsid);

$rcsid = '$Id: operview.pl,v 1.11 2002/03/30 21:16:06 pasky Exp pasky $';
($VERSION) = '$Revision: 1.11 $' =~ / (\d+\.\d+) /;
%IRSSI = (
          name        => 'operview',
          authors     => 'Petr Baudis',
          contact     => 'pasky@ji.cz',
          url         => 'http://pasky.ji.cz/~pasky/dev/irssi/',
          license     => 'GPLv2, not later',
          description => 'Reformats some server notices, which may come i.e. from &clients or &servers at IRCnet. You can turn the script on/off bytoggling variable mangle_server_notices.'
         );

my $mangle_stats_output;
my $mangle_server_notices;
my $ignore_server_kills;
my $show_kills_path;

my @lastkill = ('','','');
my @curclientcount = (0,0);

Irssi::theme_register([
  client_connect => '{servernotice $0}Connect    : {nick $[9]1} :: {nickhost $2%R@%n$3} {comment $4} :: $5-',
  client_exit    => '{servernotice $0}Disconnect : {nick $[9]1} :: {nickhost $2%R@%n$3} :: $4-',
  client_nick    => '{servernotice $0}{nick $[9]1} -> {nick $[9]2} :: {nickhost $3%R@%n$4}',
  kills_kill     => '{servernotice $0}Received %gKILL%n {nick $[9]1} ({server $2}) :: $3', # TODO: parse the path? subject to change
  kills_operkill => '{servernotice $0}Received %gKILL%n {nick $[9]1} (%R$2%n) :: $3',
  kills_collide  => '{servernotice $0}Nick %gCOLLISION%n {nick $[9]1} :: $2',
  servers_server => '{servernotice $0}Received %gSERVER%n {server $1} from {server $2} :: %G$3%w {comment $5} $6-',
  servers_squit  => '{servernotice $0}Received %gSQUIT %n {server $1} from {server $2} :: %R$3-%w',
  servers_sserver=> '{servernotice $0}Sending  %gSERVER%n {server $1} :: %G$2%w {comment $4} $5-',
  servers_ssquit => '{servernotice $0}Sending  %gSQUIT %n {server $1} :: %R$2-%w',

# TODO: Header ?               sendq         smsgs  skbs          rmsgs  rkbs      age
  stats_l        => '$[!9]0 :: $[!7]3 %g<s%n $[!5]4 $[!5]5 %gr>%n $[!5]6 $[!5]7 :: $[!6]8 :: {nickhost $1%R@%n$2}',
# TODO: Header ?                     pingf         connf         maxlinks      sendq         local limit               global limit
  stats_y        => '$0 :: $[!4]1 :: %gpf%n $[!4]2 %gcf%n $[!4]3 %gml%n $[!4]4 %gsq%n $[!8]5 %gll%n $[!-2]6%K.%n$[!2]7 %ggl%n $[!-2]8%K.%n$[!2]9',
# TODO: Header ?           haddr   hname      passwd    port     class
  stats_i        => '$0 :: $[!20]1 $[!22]3 :: $[!6]2 :: %gp%n $4 %gc%n $5',
# TODO: Header ?           port         class (N/A)     host                    reason
  stats_k        => '$0 :: %gp%n $[!4]4 %gc%n $[!2]5 :: {nickhost $3%R@%n$1} :: $2',
# TODO: Header ?           port/masklvl class           sname host                    passw
  stats_c        => '$0 :: %gp%n $[!4]5 %gc%n $[!2]6 :: $4 :: {nickhost $1%R@%n$2} :: $3',
  stats_n        => '$0 :: %gm%n $[!4]5 %gc%n $[!2]6 :: $4 :: {nickhost $1%R@%n$2} :: $3',
  
# I wasn't able to discover how to get this working for statusbars. So THIS IS
# NO-OP! Seek for its second incarnation hardcoded somewhere below.

  sb_kill        => '{sb $0%R@%n$1}',
  sb_operkill    => '{sb $0%R<%n$1}',
  sb_collision   => '{sb $0%R!%n}',
  sb_sclientcount=> '{sb $0%c/%n$1%cs%n}',
]);


sub event_server_notice {
  my ($server, $data, $nick, $address) = @_;
  my ($target, $text) = $data =~ /^(\S*)\s+:(.*)$/;
  my (@text) = split(/ /, $text);

  $show_kills_path = Irssi::settings_get_bool("show_kills_path");
  $ignore_server_kills = Irssi::settings_get_bool("ignore_server_kills");
  $mangle_server_notices = Irssi::settings_get_bool("mangle_server_notices");
  return unless ($mangle_server_notices);

  return if ($address or $nick !~ /\./);

  if ($target eq '&CLIENTS') {
    
    if ($text =~ /^Client connecting/) {
      my (@fa) = ($text[2], $text[4], $text[6], $text[7], join(" ", splice(@text, 9)));

      $fa[3] =~ s/^\[(.*)\]$/$1/;
      
      $server->printformat($target, MSGLEVEL_SNOTES, "client_connect",
	$nick, @fa);
      Irssi::signal_stop();

    } elsif ($text =~ /^Client exiting/) {
      my (@fa) = ($text[2], $text[4], $text[6], join(" ", splice(@text, 8)));

      $server->printformat($target, MSGLEVEL_SNOTES, "client_exit",
	$nick, @fa);
      Irssi::signal_stop();

    } elsif ($text =~ /^Nick change/) {
      my (@fa) = ($text[2], $text[4], $text[6], $text[8]);

      $server->printformat($target, MSGLEVEL_SNOTES, "client_nick",
	$nick, @fa);
      Irssi::signal_stop();
    }

  } elsif ($target eq '&KILLS') {

    if ($text =~ /^Received KILL/) {
      my (@fa) = ($text[4], $text[6], join(" ", splice(@text, 9 - $show_kills_path)));

      $fa[0] =~ s/\.$//;
      
      if ($fa[1] =~ /\./) {
        $server->printformat($target, MSGLEVEL_SNOTES, "kills_kill",
                             $nick, @fa) unless ($ignore_server_kills);
        @lastkill = ($fa[0], $fa[1], 's');
      } else {
        $server->printformat($target, MSGLEVEL_SNOTES+MSGLEVEL_HILIGHT, "kills_operkill",
                             $nick, @fa);
        @lastkill = ($fa[0], $fa[1], 'o');
      }
      refresh_kills();
      Irssi::signal_stop();

    } elsif ($text =~ /^Nick collision on/) {
      my (@fa) = ($text[3], join(" ", splice(@text, 4)));

      $server->printformat($target, MSGLEVEL_SNOTES, "kills_collide",
			   $nick, @fa);
      @lastkill = ($fa[0], '', 'c');

      refresh_kills();
      Irssi::signal_stop();
    }

  } elsif ($target eq '&NOTICES') {
    if ($text =~ /^Local increase from/) {
      @curclientcount = ($text[5], $text[8]);
      refresh_sclientcount();
    }

  } elsif ($target eq '&SERVERS') {

    if ($text =~ /^Received SERVER/) {
      my ($sname) = join(" ", splice(@text, 5));
      my (@fa) = ($text[2], $text[4],
                  $sname =~ /^\((\d+)\s+(\[(.+?)\])?\s*(.*)\)$/);

      $server->printformat($target, MSGLEVEL_SNOTES, "servers_server",
	$nick, @fa);
      Irssi::signal_stop();

    } elsif ($text =~ /^Received SQUIT/) {
      my (@fa) = ($text[2], $text[4], join(" ", splice(@text, 5)));
     
      $fa[2] =~ s/^\((.*)\)$/$1/;
      
      $server->printformat($target, MSGLEVEL_SNOTES, "servers_squit",
	$nick, @fa);
      Irssi::signal_stop();

    } elsif ($text =~ /^Sending SERVER/) {
      my ($sname) = join(" ", splice(@text, 3));
      my (@fa) = ($text[2], $sname =~ /^\((\d+)\s+(\[(.+?)\])?\s*(.*)\)$/);

      $server->printformat($target, MSGLEVEL_SNOTES, "servers_sserver",
	$nick, @fa);
      Irssi::signal_stop();

    } elsif ($text =~ /^Sending SQUIT/) {
      my (@fa) = ($text[2], join(" ", splice(@text, 3)));
     
      $fa[1] =~ s/^\((.*)\)$/$1/;
      
      $server->printformat($target, MSGLEVEL_SNOTES, "servers_ssquit",
	$nick, @fa);
      Irssi::signal_stop();
    }

  }
}


sub event_stats_numeric {
  my ($server, $data, $srvname) = @_;
  my ($target, $text) = $data =~ /^(\S*)\s+(.*)$/;
  my (@text) = split(/ /, $text);
  my ($num) = Irssi::signal_get_emitted() =~ /^event (\d+)$/;

  $mangle_stats_output = Irssi::settings_get_bool("mangle_stats_output");
  unless ($mangle_stats_output) {
    Irssi::print $text, MSGLEVEL_CRAP;
    return;
  }

  unless ($num) {
    Irssi::print "[OperView] Internal error - emitted signal '".Irssi::signal_get_emitted()."' is not numerics event.";
    return;
  }

#  Irssi::print "[$num][] $data -> $target , $text";

  if ($num == 211) {
# STATS L
#:irc.cis.vutbr.cz 211 `asdf irc.cis.vutbr.cz[0.0.0.0@.3333] 0 92727331 1888902 168822985 3078358 :3201373
#:irc.cis.vutbr.cz 211 `asdf irc.felk.cvut.cz[ircd@147.32.80.79] 6038 4876 52 268097 6375 :1427
#:irc.cis.vutbr.cz 211 `asdf [unknown@66.135.66.250] 0 0 0 0 0 :0
#:irc.cis.vutbr.cz 211 `asdf `asdf[~a@pasky.ji.cz] 478 2057 162 13 0 :324
#:irc.cis.vutbr.cz 211 `asdf [@66.135.66.250] 0 10 0 11 0 :81
#:irc.cis.vutbr.cz 211 `asdf `asdf[@62.44.12.54] 517 129 10 4 0 :87
    my (@fa) = $text =~ /^(.*?)?\[([^[]*?)?@(.*?)\] (\d+) (\d+) (\d+) (\d+) (\d+) :(\d+)$/;

    unless ($fa[2]) {
      Irssi::print $text, MSGLEVEL_CRAP;
    } else {
      $server->printformat($target, MSGLEVEL_CRAP, "stats_l", @fa);
    }
    Irssi::signal_stop();
    
  } elsif ($num == 218) {
# STATS Y
#:irc.cis.vutbr.cz 218 `asdf Y 0 120 600 1 384084 0.0 0.0
#:irc.cis.vutbr.cz 218 `asdf Y 10 300 0 1 500000 1.1 1.1
#:irc.cis.vutbr.cz 218 `asdf Y 12 300 0 10 700000 10.10 10.10
#:irc.cis.vutbr.cz 218 `asdf Y 1 300 0 400 700000 10.3 10.3
    my (@fa) = $text =~ /^(.) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+)\.(\d+) :?(\d+)\.(\d+)$/;

    unless ($fa[0]) {
      Irssi::print $text, MSGLEVEL_CRAP;
    } else {
      $server->printformat($target, MSGLEVEL_CRAP, "stats_y", @fa);
    }
    Irssi::signal_stop();
    
  } elsif ($num == 215) {
# STATS I
#:irc.cis.vutbr.cz 215 `asdf I pilsedu.cz <NULL> pilsedu.cz 0 12
#:irc.cis.vutbr.cz 215 `asdf I x.opf.slu.cz <NULL> x.opf.slu.cz 0 9
#:irc.cis.vutbr.cz 215 `asdf I 64.44.4.128/29 <NULL> <NULL> 0 1
    my (@fa) = $text =~ /^(.) (\S+) (\S+) (\S+) (\d+) :?(\d+)$/;

    unless ($fa[0]) {
      Irssi::print $text, MSGLEVEL_CRAP;
    } else {
      $server->printformat($target, MSGLEVEL_CRAP, "stats_i", @fa);
    }

    Irssi::signal_stop();

  } elsif ($num == 216) {
# STATS K
#:irc.cis.vutbr.cz 216 `asdf K *@*.*.*.*.*.*.*.*.* Access_denied,please_fix_your_domain_name * 0 -1
#:irc.cis.vutbr.cz 216 `asdf K 195.116.4.* Access_denied,reason-use_servers_in_Poland * 0 -1
#:irc.cis.vutbr.cz 216 `asdf K korak.isternet.sk abuse - expire 01.08.2003 16.26 * 0 -1
#:irc.cis.vutbr.cz 216 `asdf K 193.84.192.0/24 compromissed network - expire 05.04.2002 22.37 * 0 -1
    my (@fa) = $text =~ /^(.) (\S+) (.+) (\S+) (\d+) :?([-0-9]+)$/;

    unless ($fa[0]) {
      Irssi::print $text, MSGLEVEL_CRAP;
    } else {
      $server->printformat($target, MSGLEVEL_CRAP, "stats_k", @fa);
    }

    Irssi::signal_stop();

  } elsif ($num == 213) {
# STATS C
#:irc.cis.vutbr.cz 213 `asdf c *@129.143.67.242 * *.de 6666 6
#:irc.cis.vutbr.cz 213 `asdf c *@141.24.101.9 * *.de 6667 6
#:irc.cis.vutbr.cz 213 `asdf c *@131.174.124.200 * *.sci.kun.nl 6667 6
#:irc.cis.vutbr.cz 213 `asdf c *@130.240.16.47 * *.se 6667 6
#:irc.cis.vutbr.cz 213 `asdf c *@147.32.80.79 * irc.felk.cvut.cz 6664 6
#:irc.cis.vutbr.cz 213 `asdf c *@195.146.134.62 * *.sk 0 2
#:irc.cis.vutbr.cz 213 `asdf c *@195.168.1.141 * *.sk 0 2
    my (@fa) = $text =~ /^(.) (\S+)@(\S+) (\S+) (\S+) ([.0-9]+) :?([-0-9]+)$/;

    unless ($fa[0]) {
      Irssi::print $text, MSGLEVEL_CRAP;
    } else {
      $server->printformat($target, MSGLEVEL_CRAP, "stats_c", @fa);
    }

    Irssi::signal_stop();

  } elsif ($num == 214) {
# (STATS N)
#:irc.cis.vutbr.cz 214 `asdf N *@129.143.67.242 * *.de 0 6
#:irc.cis.vutbr.cz 214 `asdf N *@141.24.101.9 * *.de 3 6
#:irc.cis.vutbr.cz 214 `asdf N *@131.174.124.200 * *.sci.kun.nl 3 6
#:irc.cis.vutbr.cz 214 `asdf N *@130.240.16.47 * *.se 3 6
#:irc.cis.vutbr.cz 214 `asdf N *@147.32.80.79 * irc.felk.cvut.cz 0 6
#:irc.cis.vutbr.cz 214 `asdf N *@195.146.134.62 * *.sk 3 2
#:irc.cis.vutbr.cz 214 `asdf N *@195.168.1.141 * *.sk 3 2
    my (@fa) = $text =~ /^(.) (\S+)@(\S+) (\S+) (\S+) (\d+) :?(\d+)$/;

    unless ($fa[0]) {
      Irssi::print $text, MSGLEVEL_CRAP;
    } else {
      $server->printformat($target, MSGLEVEL_CRAP, "stats_n", @fa);
    }

    Irssi::signal_stop();
=brm
  } elsif ($num == 250) {

#TRACE
#:irc.cis.vutbr.cz 204 `asdf Oper 12 pasky[~pasky@pasky.ji.cz]
#:irc.cis.vutbr.cz 206 `asdf Serv 6 46S 95580C irc.felk.cvut.cz[ircd@147.32.80.79] *!*@irc.cis.vutbr.cz VFz
#:irc.cis.vutbr.cz 205 `asdf User 1 `asdf[~a@pasky.ji.cz]
#:irc.cis.vutbr.cz 262 `asdf irc.cis.vutbr.cz 2.10.3p3.addpl2.hemp. :End of TRACE
#
#STATS O
#:irc.cis.vutbr.cz 243 `asdf O revisor@*.ssakhk.cz * erixon 0 10
#:irc.cis.vutbr.cz 243 `asdf O cf@candyflip.junkie.cz * cf 0 12
#:irc.cis.vutbr.cz 243 `asdf O *@pilsedu.cz * jv 0 12
#:irc.cis.vutbr.cz 243 `asdf O *@62.44.12.54 * pasky 0 12
#:irc.cis.vutbr.cz 243 `asdf O *@bsd.xcem.com * Krash 0 10
#:irc.cis.vutbr.cz 243 `asdf O spike@*.pantexcom.com * Krash 0 10
#:irc.cis.vutbr.cz 243 `asdf O fantomas@*.fantomas.sk * filozof 0 10
#:irc.cis.vutbr.cz 243 `asdf O *@147.229.1.11 * StiX 0 10
#:irc.cis.vutbr.cz 243 `asdf O *@160.216.0.0/16 * StiX 0 10
#:irc.cis.vutbr.cz 219 `asdf O :End of STATS report

# STATS H
#:irc.cis.vutbr.cz 250 `asdf D *.fr.ircnet.net <NULL> * 0 0
#:irc.cis.vutbr.cz 250 `asdf D *.belnet.be <NULL> * 0 0
#:irc.cis.vutbr.cz 244 `asdf H * <NULL> irc.felk.cvut.cz 0 -1
#:irc.cis.vutbr.cz 244 `asdf H * <NULL> *.de 0 -1
#:irc.cis.vutbr.cz 244 `asdf H * <NULL> *.sci.kun.nl 0 -1
#:irc.cis.vutbr.cz 244 `asdf H * <NULL> *.fi 0 -1
#:irc.cis.vutbr.cz 244 `asdf H * <NULL> *.se 0 -1
#:irc.cis.vutbr.cz 244 `asdf H * <NULL> *.sk 0 -1
#:irc.cis.vutbr.cz 244 `asdf H * <NULL> irc.uhk.cz 0 -1
#:irc.cis.vutbr.cz 219 `asdf H :End of STATS report
    my (@fa) = $text =~ /^(.) (\S+)@(\S+) (\S+) (\S+) (\d+) :?(\d+)$/;

    Irssi::print $text unless ($fa[0]);
    
    $server->printformat($target, MSGLEVEL_CRAP, "stats_n",
			 @fa);
    Irssi::signal_stop();
=cut
  }
}




#
### Statusbar stuff
#


sub sclientcount {
  my ($item, $get_size_only) = @_;
  my $f = '{sb '.$curclientcount[0].'%c/%n'.$curclientcount[1].'%cs%n}';

  $item->default_handler($get_size_only, $f, undef, 1);
}

sub kills {
  my ($item, $get_size_only) = @_;
  my $theme = Irssi::current_theme();
  my $f = '{sb %n}';

  if ($lastkill[2] eq 's') {
# Thanks to cras and darix for helping with following:
# FIXME: Return value of following is for some reason "Perl script".
#    $f = Irssi::active_win()->format_get_text("Irssi::Script::operview", Irssi::active_server(), undef, 'sb_kill', @lastkill);

    $f = '{sb '.$lastkill[0].'%c@%n'.$lastkill[1].'}';
  } elsif ($lastkill[2] eq 'o') {
    $f = '{sb '.$lastkill[0].'%c<%n'.$lastkill[1].'}';
  } elsif ($lastkill[2] eq 'c') {
    $f = '{sb '.$lastkill[0].'%c!%n}';
  }

  $item->default_handler($get_size_only, $f, undef, 1);
}


sub refresh_sclientcount {
  Irssi::statusbar_items_redraw('sclientcount');
}

sub refresh_kills {
  Irssi::statusbar_items_redraw('kills');
}


Irssi::signal_add("event notice", "event_server_notice");
Irssi::signal_add("event 211", "event_stats_numeric");
Irssi::signal_add("event 213", "event_stats_numeric");
Irssi::signal_add("event 214", "event_stats_numeric");
Irssi::signal_add("event 215", "event_stats_numeric");
Irssi::signal_add("event 216", "event_stats_numeric");
Irssi::signal_add("event 218", "event_stats_numeric");
#Irssi::signal_add("event 243", "event_stats_numeric");
#Irssi::signal_add("event 244", "event_stats_numeric");
#Irssi::signal_add("event 250", "event_stats_numeric");

Irssi::settings_add_bool("lookandfeel", "mangle_stats_output", 0);
Irssi::settings_add_bool("lookandfeel", "mangle_server_notices", 1);
Irssi::settings_add_bool("lookandfeel", "ignore_server_kills", 0);
Irssi::settings_add_bool("lookandfeel", "show_kills_path", 0);

Irssi::statusbar_item_register("sclientcount", '$0', 'sclientcount');
Irssi::statusbar_item_register("kills", '$0', 'kills');
Irssi::statusbars_recreate_items();

Irssi::print("OperView $VERSION loaded...");
