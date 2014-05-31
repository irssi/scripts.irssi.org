### operit.pl (c) 2002, 2003 Petr Baudis <pasky@ucw.cz>
#
## Perform certain action (invite/op/...) on request authenticated by the
## IRC operator status.
#
## See http://pasky.ji.cz/~pasky/dev/irssi/ for the latest version.
#
## Thanks to:
## mofo <mick@mofo.nl>			(patches)
## Garion <garion@dnsspam.nl>		(ideas)
## Borys <borys@irc.pl>			(ideas)
## devastor <devastor@idiosynkrasia.net>(bug reports)
## babar <babar@magicnet.org>		(delay patch)
#
## $Id: operit.pl,v 1.14 2003/09/06 12:27:11 pasky Exp pasky $
#
# $Log: operit.pl,v $
# Revision 1.14  2003/09/06 12:27:11  pasky
# Okay, so while I'm at it updated other instance of my email addy, copyright, bunch of grammar fixes and documented the operit_public_delay variable.
#
# Revision 1.13  2003/09/06 12:25:09  pasky
# Updated my email addy.
#
# Revision 1.12  2003/09/06 12:23:50  pasky
# Added support for randomly delayed operit - if operit is public, the delay is zero to five seconds by default - this helps greatly if there is a lot of operit-enabled clients on a channel. Patch by Babar <babar@magicnet.org> and me.
#
# Revision 1.11  2003/03/20 08:58:18  pasky
# Match whole channel, not random part, when checking for deny_channels and deny_hosts. So you can deny operits at #iraq but still allow them at #iraqlive ;-). Thanks to viha for cooperation during testing.
#
# Revision 1.10  2002/11/29 16:51:46  pasky
# Don't play with channels we aren't on. Fixes occassional 'can't call method command on undefined value'; thanks to devastor for a report.
#
# Revision 1.9  2002/10/19 13:12:34  pasky
# Introduced operit_allow_public (by default on), which toggles accepting of public (on-channel) operit requests. Idea by Borys.
#
# Revision 1.8  2002/10/13 12:33:13  pasky
# We don't care about /^operit [^!#&]/ anymore. Thanks fly to Garion for suggestion.
#
# Revision 1.7  2002/10/07 14:16:58  pasky
# Added operit_show_requests bool setting (by default 1, that is same behaviour as now).
#
# Revision 1.6  2002/09/01 12:27:08  pasky
# Erm, compilation fixes.
#
# Revision 1.5  2002/09/01 12:24:24  pasky
# Allow specification of more channels separated by a comma in requests. Changed default value of operit_hosts_deny to something harmless. Patch by mofo <mick@mofo.nl>.
#
# Revision 1.4  2002/03/13 13:17:36  pasky
# remove one debug message accidentally left there
#
# Revision 1.3  2002/03/12 18:02:37  pasky
# invait actually works now
#
# Revision 1.2  2002/02/05 17:47:13  pasky
# fixed many things :^). now it basically works how it should...
#
# Revision 1.1  2002/02/05 16:47:09  pasky
# Initial revision
#
#
###

### Inspired by Operit-2.01b+enge script for ircII+ clients by
## - Viha   (Viha@Theblah.Org)
#  - Karzan (Kari@Theblah.Org)
#
## Credits also go to:
#  - LuckyS  (lucky@binet.lv)              [bug  reports]
#  - Fusion  (fusion@nuts.edu)             [bug  reports]
#  - RA^v^EN (raven@sky.siol.org)          [bug  reports]
#  - tumble  (tumble@openface.ca)          [beta testing]
#  - koopal  (andre@nl.uu.net)             [script ideas]
#  - pt      (primetime@wnol.net)          [script ideas]
#  - delta   (delta@rus.uni-stuttgart.de)  [script ideas]
#  - pht     (svobodam@irc.vsp.cz)         [bug  reports]
#  - enge    (engerim@magicnet.org)        [modifications]
#
### The most recent version can always be found at
#           http://www.vip.fi/~viha/irc/
###

use strict;

use vars qw ($VERSION %IRSSI $rcsid);

$rcsid = '$Id: operit.pl,v 1.14 2003/09/06 12:27:11 pasky Exp pasky $';
($VERSION) = '$Revision: 1.14 $' =~ / (\d+\.\d+) /;
%IRSSI = (
          name        => 'operit',
          authors     => 'Petr Baudis',
          contact     => 'pasky@ucw.cz',
          url         => 'http://pasky.ji.cz/~pasky/dev/irssi/',
          license     => 'BSD',
          description => 'Perform certain action (invite/op/...) on request authenticated by the IRC operator status.'
         );


use Irssi 20021117; # timeout_add_once
use Irssi::Irc;


my $queue = 0;   # already queued an operit? (when?)
my $disp = 0;    # already displayed kind notice about already queued operit?
my $cmd = "";    # command issued
my $target = ""; # who issued the command
my $chan = "";   # object of the command

my $coperit = 0;
my $cinvait = 0;
my $cdamode = 0;
my $mpublic = 0;


sub event_privmsg {
  my ($server, $data, $nick, $address) = @_;
  my ($msgtarget, $text) = split(/ :/, $data, 2);

  return if (Irssi::settings_get_bool("operit_deny"));

  if ($text =~ s/^(invait|operit|damode)( .*)?$/$2/i) {
    if (uc($msgtarget) eq uc($server->{nick})) {
      $mpublic = 0;
    } else {
      return unless (Irssi::settings_get_bool("operit_allow_public"));
      $mpublic = 1;
    }

    if (time - $queue < 10) {
      Irssi::print "Operit currently deactivated or queued. Request ignored."
	if (time - $disp > 20);
      $disp = time;
      return;
    }

    $cmd = $1; $target = $nick; $queue = 0; $disp = 0;

#    if ($msgtarget eq $N or $cmd eq 'invait') {
    if (1) {
      ($_, $chan) = split /\s+/, $text; # oh.. oh well :)
      my $a = 0;

      $chan = $msgtarget if (not $chan and $msgtarget ne $server->{nick});
      return unless ($chan =~ /^[#!&]/);

      foreach (split /\s+/, Irssi::settings_get_str("operit_chans")) {
        s/\./\\./;
	s/\*/.*/g;
	if ($chan =~ /^$_$/i) {
	  $a++;
	}
      }

      unless ($a) {
	Irssi::print "Unauthorized $cmd $chan by $target (not in operit_chans)" if (Irssi::settings_get_bool("operit_show_requests"));
	return;
      }
      
      foreach (split /\s+/, Irssi::settings_get_str("operit_chans_deny")) {
        s/\./\\./;
	s/\*/.*/g;
	if ($chan =~ /^$_$/i) {
	  Irssi::print "Unauthorized $cmd $chan by $target (in operit_chans_deny)" if (Irssi::settings_get_bool("operit_show_requests"));
	  return;
	}
      }
      
      foreach (split /^\s+$/, Irssi::settings_get_str("operit_hosts_deny")) {
        s/\./\\./;
	s/\*/.*/g;
	if ($address =~ /$_/i) {
	  Irssi::print "Unauthorized $cmd $chan by $target <$address> (in operit_hosts_deny)" if (Irssi::settings_get_bool("operit_show_requests"));
	  return;
	}
      }

      $queue = time;
      
      $server->redirect_event("userhost", 1, $target, 0, 'redir userhost_operit_error',
			      {"event 302" => "redir userhost_operit"});

      $server->command("USERHOST $target");
    }
  }
}

sub event_userhost_error {
  Irssi::print "Operit userhost on $target failed, aborting the action...";

  $queue = $disp = 0;
}


sub event_userhost_operit {
  my ($server, $data) = @_;
  my ($mynick, $reply) = split(/ +/, $data);
  my ($nick, $user, $host) = $reply =~ /^:(.*)=.(.*)@(.*)/;
  
  unless ($nick =~ s/\*$//) {
    Irssi::print "$target requested UNAUTHORIZED $cmd on channel $chan" if (Irssi::settings_get_bool("operit_show_requests"));
    return;
  }
  
  Irssi::print "$target requested $cmd on channel $chan" if (Irssi::settings_get_bool("operit_show_requests"));

  foreach my $chansplit (split(/\,/, $chan)) {
    my $channel = $server->channel_find($chansplit);

    next unless ($channel);

    if (lc($cmd) eq "operit") {
      if ($mpublic) {
	my $precision = 10; # Delay precision (10 = 1/10s)
	my $rdelay = int(rand(Irssi::settings_get_str("operit_public_delay") * $precision)) * 1000 / $precision;

	Irssi::print "Waiting " . ($rdelay / 1000) . " seconds before executing PUBLIC $cmd for $target on $chan";
	Irssi::timeout_add_once($rdelay + 11, sub { # XXX why + 10 ? --pasky
			my ($target, $channel) = @{$_[0]};
			my ($tgrec) = $channel->nick_find($target);
        		$channel->command("op $target") unless ($tgrec and $tgrec->{'op'});
		}, [ $target, $channel ]);
      } else {
        $channel->command("op $target");
      }
      $coperit++;
      
    } elsif (lc($cmd) eq "invait") {
      $server->command("invite $target $chansplit");
      $cinvait++;
    
    } elsif (lc($cmd) eq "damode") {
      $server->command("notice $target mode for $chansplit is +$channel->{mode}");
      $cdamode++;
    }
  }

  $queue = $disp = 0;
}


sub event_ctcp {
  my ($server, $data, $nick, $address, $target) = @_;

  return if (Irssi::settings_get_bool("operit_deny"));

  if ($data =~ /^operit/i) {
    Irssi::print "$nick requested operit thru CTCP... no way!" if (Irssi::settings_get_bool("operit_show_requests"));
    $server->command("NOTICE $nick ssshht!");
    Irssi::signal_stop();
  }
}


sub cmd_operit {
  my ($data, $server, $channel) = @_;
  
  if ($data =~ /^(usage|help)/i) {

    foreach (split /\n/, <<USAGEE
Operit:

Local commands

operit usage      - This help.
operit help       - This help.
operit status     - Display statistical information.

Remote commands

operit #chan      - Op the person in question on #chan.     (req. *)
invait #chan      - Invait the person in question to #chan. (req. *)
damode #chan      - Give the person in question the modes of #chan. (req. *)

Variables

operit_chans      - The channelmask operit/invait is permitted on. (* is *)
operit_chans_deny - The channel(s) operit/invait is not permitted on. (* is *)
operit_hosts_deny - The user\@host(s) operit/invait is not permitted from. (* is *)
operit_deny       - Toogle this ON if you don't actually want invait/operit to function.
operit_show_requests
                  - Toogle this OFF if you don't want to see messages about operit requests.
operit_allow_public
                  - Toogle this OFF if you don't want requests written on channels to be proceeded.
operit_public_delay
		  - Set this to 0 if you don't want random delay between request and action.
USAGEE
	) {
      Irssi::print $_;
    }
    
  } elsif ($data =~ /^status/i) {
    my $ctotal = $coperit + $cinvait + $cdamode;

    Irssi::print "Operit $VERSION Status:";
    Irssi::print "The last person to request $cmd was $target [$chan].";
    Irssi::print "This session has served $coperit op-requests, $cinvait invite-requests and $cdamode mode-requests.";
    Irssi::print "Making a total of $ctotal succesful requests.";
    
  } else {
    Irssi::print "Excuse moi, sir? I guess that you want /operit usage ..?";
  }
}


Irssi::command_bind("operit", "cmd_operit");
Irssi::signal_add("redir userhost_operit", "event_userhost_operit");
Irssi::signal_add("redir userhost_operit_error", "event_userhost_error");
Irssi::signal_add("default ctcp msg", "event_ctcp");
Irssi::signal_add("event privmsg", "event_privmsg");


Irssi::settings_add_str("operit", "operit_chans", "#* !*");
Irssi::settings_add_str("operit", "operit_chans_deny", "#ircophackers");
Irssi::settings_add_str("operit", "operit_hosts_deny", "*!*@*.lamehost1 *lamehost2");
Irssi::settings_add_bool("operit", "operit_deny", 0);
Irssi::settings_add_bool("operit", "operit_show_requests", 1);
Irssi::settings_add_bool("operit", "operit_allow_public", 1);
Irssi::settings_add_str("operit", "operit_public_delay", 5);


Irssi::print("Operit $VERSION loaded... see command 'operit usage'");
