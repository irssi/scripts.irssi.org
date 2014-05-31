# Print realname of everyone who join to channels
# for irssi 0.7.99 by Timo Sirainen

use Irssi 20011207;
use strict;
use vars qw($VERSION %IRSSI); 
$VERSION = "0.8.6";
%IRSSI = (
    authors	=> "Timo \'cras\' Sirainen, Bastian Blank",
    contact	=> "tss\@iki.fi, waldi\@debian.org",
    name	=> "auto realname",
    description	=> "Print realname of everyone who join to channels",
    license	=> "GPLv2 or later",
    url		=> "http://irssi.org/",
    changed	=> "Fri, 24 Jan 2003 15:40:22 +0100"
);

# v0.8.6 changes - Juhamatti Niemelä
#  - fix join msg printing when there are multiple common channels
# v0.8.5 changes - Bastian Blank
#  - really use the introduced state variable
# v0.8.4 changes - Bastian Blank
#  - fix queue abort
# v0.8.3 changes - Bastian Blank
#  - on queue abort print any join messages
# v0.8.2 changes - Bastian Blank
#  - use channelname instead of Irssi::Irc::Channel for channelname within message on join
# v0.8.1 changes - Bastian Blank
#  - print any join messages on abort
#  - also remove any timeouts
# v0.8 changes - Bastian Blank
#  - join message includes realname
#  - add timeout
#  - don't print realname for our self
#  - change license because german law doesn't allow to give away the copyright
# v0.71 changes
#  - a bit safer now with using "redirect last"
# v0.7 changes
#  - pretty much a rewrite - shouldn't break anymore
# v0.62 changes
#  - upgraded redirection to work with latest CVS irssi - lot easier
#    to handle it this time :)
# v0.61 changes
#  - forgot to reset %chan_list..
# v0.6 changes
#  - works now properly when a nick joins to multiple channels
# v0.5 changes
#  - Use "message join" so we won't ask realname for ignored people

Irssi::theme_register([
  'join', '{channick_hilight $0} {chanhost_hilight $1} has joined {channel $2}',
  'join_realname', '{channick_hilight $0} ({hilight $1}) {chanhost_hilight $2} has joined {channel $3}',
  'join_realname_only', '{channick_hilight $0} is {hilight $1}',
]);

my $whois_queue_length_before_abort = 10; # max. whois queue length before we should abort the whois queries for next few seconds (people are probably joining behind a netsplit)
my $whois_abort_seconds = 10; # wait for 10 secs when there's been too many joins
my $debug = 0;

my %servers;

my %whois_waiting;
my %whois_queue;
my %aborted;
my %chan_list;

sub sig_connected {
  my $server = shift;
  $servers{$server->{tag}} = {
    abort_time => 0,  # if join event is received before this, abort
    waiting => 0,     # waiting reply for WHOIS request
    queue => [],      # whois queue
    nicks => {}       # nick => [ #chan1, #chan2, .. ]
  };
}

sub sig_disconnected {
  my $server = shift;
  delete $servers{$server->{tag}};
}

sub msg_join {
  my ($server, $channame, $nick, $host) = @_;
  $channame =~ s/^://;
  my $rec = $servers{$server->{tag}};

  # don't display realname for our self
  return if ($nick eq $server->{nick});

  # don't whois people who netjoin back
  return if ($server->netsplit_find($nick, $host));

  return if (time < $rec->{abort_time});
  $rec->{abort_time} = 0;

  Irssi::signal_stop();

  # check if the nick is already found from another channel
  {
    my $ret = 0;
    foreach my $channel ($server->channels()) {
      my $nickrec = $channel->nick_find($nick);
      if ($nickrec && $nickrec->{realname}) {
        # this user already has a known realname - use it.
        $channel = $server->channel_find($channame);
        $channel->printformat(MSGLEVEL_JOINS, 'join_realname', $nick, $nickrec->{realname}, $nickrec->{host}, $channel->{name});
        $channel->print("autorealname: already found: $nick", MSGLEVEL_CLIENTCRAP) if $debug;
        $ret = 1;
        last;
      }
    }

    return if ($ret);
  }

  # save channel to nick specific hash so we can later check which channels
  # it needs to print the realname

  if ($rec->{nicks}->{$nick}) {
    # don't send the WHOIS again if nick is already in queue
    push @{$rec->{nicks}->{$nick}->{chans_join}}, $channame;
    push @{$rec->{nicks}->{$nick}->{chans_realname}}, $channame;
    $rec->{nicks}->{$nick}->{state} = 0;
    my $channel = $server->channel_find($channame);
    $channel->print("autorealname: already in queue: $nick", MSGLEVEL_CLIENTCRAP) if $debug;
  }
  else {
    $rec->{nicks}->{$nick} = {};
    $rec->{nicks}->{$nick}->{chans_join} = [$channame];
    $rec->{nicks}->{$nick}->{chans_realname} = [$channame];
    $rec->{nicks}->{$nick}->{state} = 0;

    # add the nick to queue
    push @{$rec->{queue}}, $nick;

    # timeout
    $rec->{nicks}->{$nick}->{timeout} = Irssi::timeout_add(1000, \&timeout_whois, [$server, $nick]);
    my $channel = $server->channel_find($channame);
    $channel->print("autorealname: add to queue: $nick", MSGLEVEL_CLIENTCRAP) if $debug;
  }

  if (scalar @{$rec->{queue}} >= $whois_queue_length_before_abort) {
    # too many whois requests in queue, abort
    foreach $nick (@{$rec->{queue}}) {
      foreach my $channel (@{$rec->{nicks}->{$nick}->{chans_join}}) {
        my $chanrec = $server->channel_find($channel);
        my $nickrec = $chanrec->nick_find($nick);
        if ($chanrec && $nickrec) {
          $chanrec->printformat(MSGLEVEL_JOINS, 'join', $nick, $nickrec->{host}, $channel);
          $chanrec->print("autorealname: queue abort: $nick", MSGLEVEL_CLIENTCRAP) if $debug;
        }
      }
      Irssi::timeout_remove($rec->{nicks}->{$nick}->{timeout}) if (!($rec->{nicks}->{$nick}->{state} & 2));
      delete $rec->{nicks}->{$nick};
    }
    $rec->{queue} = [];
    $rec->{abort_time} = time+$whois_abort_seconds;
    return;
  }

  # waiting for WHOIS reply..
  return if $rec->{waiting};

  request_whois($server, $rec);
}

sub request_whois {
  my ($server, $rec) = @_;
  return if (scalar @{$rec->{queue}} == 0);

  my @whois_nicks = splice(@{$rec->{queue}}, 0, $server->{max_whois_in_cmd});
  my $whois_query = join(',', @whois_nicks);

  # ignore all whois replies except the first line of the WHOIS reply
  my $redir_arg = $whois_query.' '.join(' ', @whois_nicks);
  $server->redirect_event("whois", 1, $redir_arg, 0, 
			  "redir autorealname_whois_last", {
			    "event 311" => "redir autorealname_whois",
			    "event 401" => "redir autorealname_whois_unknown",
			    "redirect last" => "redir autorealname_whois_last",
			    "" => "event empty" });

  $server->send_raw("WHOIS :$whois_query");
  $rec->{waiting} = 1;
}

sub event_whois {
  my ($server, $data) = @_;
  my ($num, $nick, $user, $host, $empty, $realname) = split(/ +/, $data, 6);
  $realname =~ s/^://;
  my $rec = $servers{$server->{tag}};

  return if not $rec->{nicks}->{$nick};

  $rec->{nicks}->{$nick}->{state} |= 1;

  if (!($rec->{nicks}->{$nick}->{state} & 2)) {
    Irssi::timeout_remove($rec->{nicks}->{$nick}->{timeout});
    foreach my $channel (@{$rec->{nicks}->{$nick}->{chans_join}}) {
      my $chanrec = $server->channel_find($channel);
      my $nickrec = $chanrec->nick_find($nick);
      if ($chanrec && $nickrec) {
        $chanrec->printformat(MSGLEVEL_JOINS, 'join_realname', $nick, $realname, $nickrec->{host}, $channel);
        $chanrec->print("autorealname: got whois: $nick, state: ".$rec->{nicks}->{$nick}->{state}, MSGLEVEL_CLIENTCRAP) if $debug;
      }
    }
    $rec->{nicks}->{$nick}->{chans_join} = [];
    $rec->{nicks}->{$nick}->{chans_realname} = [];
    $rec->{nicks}->{$nick}->{state} |= 2;
  }
  else {
    foreach my $channel (@{$rec->{nicks}->{$nick}->{chans_realname}}) {
      my $chanrec = $server->channel_find($channel);
      my $nickrec = $chanrec->nick_find($nick);
      if ($chanrec && $nickrec) {
        $chanrec->printformat(MSGLEVEL_JOINS, 'join_realname_only', $nick, $realname);
        $chanrec->print("autorealname: got whois: $nick, state: ".$rec->{nicks}->{$nick}->{state}, MSGLEVEL_CLIENTCRAP) if $debug;
      }
    }
    $rec->{nicks}->{$nick}->{chans_realname} = [];
  }

  delete $rec->{nicks}->{$nick} if ($rec->{nicks}->{$nick}->{state} == 3);
}

sub event_whois_unknown {
  my ($server, $data) = @_;
  my ($temp, $nick) = split(" ", $data);
  my $rec = $servers{$server->{tag}};

  return if not $rec->{nicks}->{$nick};

  $rec->{nicks}->{$nick}->{state} |= 1;

  if (!($rec->{nicks}->{$nick}->{state} & 2)) {
    Irssi::timeout_remove($rec->{nicks}->{$nick}->{timeout});
    foreach my $channel (@{$rec->{nicks}->{$nick}->{chans_join}}) {
      my $chanrec = $server->channel_find($channel);
      my $nickrec = $chanrec->nick_find($nick);
      if ($chanrec && $nickrec) {
        $chanrec->printformat(MSGLEVEL_JOINS, 'join', $nick, $nickrec->{host}, $channel);
        $chanrec->print("autorealname: got unknown whois: $nick", MSGLEVEL_CLIENTCRAP) if $debug;
      }
    }
    $rec->{nicks}->{$nick}->{chans_join} = [];
  } else {
    foreach my $channel (@{$rec->{nicks}->{$nick}->{chans_join}}) {
      my $chanrec = $server->channel_find($channel);
      $chanrec->print("autorealname: got unknown whois (already considered): $nick", MSGLEVEL_CLIENTCRAP) if $debug;
    }
  }

  delete $rec->{nicks}->{$nick} if ($rec->{nicks}->{$nick}->{state} == 3);
}

sub event_whois_last {
  my $server = shift;
  my $rec = $servers{$server->{tag}};

  $rec->{waiting} = 0;
  request_whois($server, $rec);
}

foreach my $server (Irssi::servers()) {
  sig_connected($server);
}

sub timeout_whois {
  my $server = shift @{$_[0]};
  my $nick = shift @{$_[0]};

  my $rec = $servers{$server->{tag}};

  return if not $rec->{nicks}->{$nick};

  Irssi::timeout_remove($rec->{nicks}->{$nick}->{timeout});
  $rec->{nicks}->{$nick}->{state} |= 2;

  my @channels = @{$rec->{nicks}->{$nick}->{chans_join}};
  foreach my $channel (@channels) {
    my $chanrec = $server->channel_find($channel);
    my $nickrec = $chanrec->nick_find($nick);
    if ($nickrec && $chanrec) {
      $chanrec->printformat(MSGLEVEL_JOINS, 'join', $nick, $nickrec->{host}, $channel);
      $chanrec->print("autorealname: timeout: $nick, state: ".$rec->{nicks}->{$nick}->{state}, MSGLEVEL_CLIENTCRAP) if $debug;
    }
  }

  $rec->{nicks}->{$nick}->{chans_join} = [];
}

Irssi::signal_add( {
        'server connected' => \&sig_connected,
	'server disconnected' => \&sig_disconnected,
	'message join' => \&msg_join,
	'redir autorealname_whois' => \&event_whois,
	'redir autorealname_whois_unknown' => \&event_whois_unknown,
	'redir autorealname_whois_last' => \&event_whois_last });
