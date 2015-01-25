# KBan-Referrals
#
# A script that kickban users who post referral URLs. It can operate in paranoid mode or normal mode.
# In paranoid mode, any user posting in his message a URL that does not match a site in the whitelist will be kickbanned.
# In normal mode, the URL will be checked against a blacklist first, then the user will only get kickbanned 
# if his URL doesn't match a site in the whitelist and he meets some criterion that identifies referral URLs.
#
# Usage
#
# /kbanref is the command name of the script.
# Typing '/kbanref' will only enumerate the sub-commands of the script.
# Typing '/kbanref help' will list all the sub-commands with a short explanation for each.
#
use strict;
use warnings;

use vars qw($VERSION %IRSSI);

use Irssi qw(command_bind signal_add signal_add_first settings_add_str settings_get_str settings_set_str);

our $VERSION = '1.02';
our %IRSSI = (authors => 'Linostar',
          contact => 'lino.star@outlook.com',
          name => 'KickBan Referrals Script',
          description => 'Script for kickbanning those who post referral links in a channel',
          license => 'New BSD');

our %tickets = ();

sub kbanref {
  my ($data, $server, $witem) = @_;
  my $mode = settings_get_str('kbanreferrals_mode');
  my $chans = settings_get_str('kbanreferrals_channels');
  my $whitelist = settings_get_str('kbanreferrals_whitelist');
  my $blacklist = settings_get_str('kbanreferrals_blacklist');
  my $stripped = '';
  my $thelist;
  # mode command
  if ($data =~ m/^mode/i) {
    $data =~ s/mode\s*$/mode get/i;
    $data =~ /(mode)\s+(.+)/i;
    if ($2 eq 'get') {
      print('KBan-Referrals: current mode is set to ' . uc(settings_get_str('kbanreferrals_mode')) . '.');
    }
    elsif ($2 =~ m/normal\s*/i) {
      settings_set_str('kbanreferrals_mode', 'normal');
      print('KBan-Referrals: mode set to NORMAL. Whitelist and Blacklist will be used, along with a somewhat smart referral URL detection.');
    }
    elsif ($2 =~ m/paranoid\s*/i) {
      settings_set_str('kbanreferrals_mode', 'paranoid');
      print('KBan-Referrals: mode set to PARANOID. Every URL that does not match a website in the whitelist will trigger a kickban.');
    }
    else {
      print('KBan-Referrals: invalid mode. Available modes are NORMAL and PARANOID.');
    }
  }
  # whitelist or blacklist add command
  elsif ($data =~ m/^(black|white)list add/i) {
    $data =~ /(black|white)list add\s+(.+)/i;
    my $newlist = '';
    my $type = $1;
    my $args = $2;
    if ($type =~ m/black/i) {
      $thelist = \$blacklist;
    }
    else {
      $thelist = \$whitelist;
    }
    foreach(split(/\s+/, $args)) {
      if ($$thelist =~ m/\b$_\b/i) {
        print("KBan-Referrals: site $_ is already in the list."); 
      }
      else {
        $newlist .= ' ' . $_;
      }
    }
    if ($newlist && $newlist !~ m/^\s+$/) {
      $$thelist .= $newlist;
      print('KBan-Referrals: the following sites were added to ' . $type . 'list:');
      print($newlist);
      if ($type =~ m/black/i) {
        settings_set_str('kbanreferrals_blacklist', $$thelist);
      }
      else {
        settings_set_str('kbanreferrals_whitelist', $$thelist);
      }
    }
    else {
      print('KBan-Referrals: no new sites were added to ' . $type . 'list.');
    }
  }
  # whitelist or blacklist remove command
  elsif ($data =~ m/(black|white)list remove/i) {
    my $rmlist = '';
    $data =~ /(black|white)list remove\s+(.+)/i;
    my $type = $1;
    my $args = $2;
    if ($type =~ m/black/i) {
      $thelist = \$blacklist;
    }
    else {
      $thelist = \$whitelist;
    }
    foreach (split(/\s+/, $args)) {
      if ($$thelist !~ m/\b$_\b/i) {
        print('KBan-Referrals: site is not in ' . $type . 'list.');
      }
      else {
        $rmlist .= ' ' . $_;
        $$thelist =~ s/\b$_\b//i;
      }
    }
    $$thelist =~ s/\s{2,}/ /g;
    if ($rmlist && $rmlist !~ m/^\s+$/) {
      print('KBan-Referrals: the following sites were removed from ' . $type . 'list:');
      print($rmlist);
      if ($type =~ m/black/i) {
        settings_set_str('kbanreferrals_blacklist', $$thelist);
      }
      else {
        settings_set_str('kbanreferrals_whitelist', $$thelist);        
      }
    }
    else {
      print('KBan-Referrals: no sites were removed from ' . $type . 'list.');
    }
  }
  # whitelist or blacklist list command
  elsif ($data =~ m/(black|white)list list/i) {
    print('KBan-Referrals ' . $1 . 'list:');
    if ($1 =~ m/black/i) {
      $thelist = \$blacklist;
    }
    else {
      $thelist = \$whitelist;
    }
    foreach (split(/\s+/, $$thelist)) {
      print($_) if ($_);
    }
  }
  # whitelist or blacklist clear command
  elsif ($data =~ m/(black|white)list clear/i) {
    print('KBan-Referrals: ' . $1 . 'list is cleared.');
    if ($1 =~ m/black/i) {
      settings_set_str('kbanreferrals_blacklist', '');
    }
    else {
      settings_set_str('kbanreferrals_whitelist', '');
    }
  }
  # chan add command
  elsif ($data =~ m/^chan add/i) {
    my $newchans = '';
    $data =~ /(chan add)\s+(.+)/i;
    foreach(split(/\s+/, $2)) {
      $stripped = $_;
      $stripped =~ s/\#+//;
      if ($chans =~ m/\b$stripped\b/i) {
        print("KBan-Referrals: channel $_ is already in the list.");
      }
      elsif ($_ !~ m/^\#/) {
        $newchans .= ' #' . $_;
      }
      else {
        $newchans .= ' ' . $_;
      }
    }
    if ($newchans && $newchans !~ m/^\s+$/) {  
      settings_set_str('kbanreferrals_channels', $chans . $newchans);
      print('KBan-Referrals: the following channels were added the list:');
      print($newchans);
    }
    else {
      print('KBan-Referrals: no new channels were added to the list.');
    }
  }
  # chan remove command
  elsif ($data =~ m/^chan remove/i) {
    my $rmchans = '';
    my $ch = '';
    $data =~ /(chan remove)\s+(.+)/i;
    foreach (split(/\s+/, $2)) {
      $ch = $_;
      if ($ch !~ m/^\#/ && $chans !~ m/^\#$ch\b/i && $chans !~ m/\s\#$ch\b/i) {
        print("KBan-Referrals: channel \#$ch is not in the list.");
        next;
      }
      elsif ($ch !~ m/^\#/) {
        $rmchans .= ' #' . $ch;
        $chans =~ s/^\#$ch\b//i;
        $chans =~ s/\s\#$ch\b//i;
        next;
      }
      if ($chans !~ m/^$ch\b/i && $chans !~ m/\s$ch\b/i) {
        print("KBan-Referrals: channel $ch is not in the list.");
      }
      else {
        $rmchans .= ' ' . $ch;
        $chans =~ s/\s$ch\b//i;
        $chans =~ s/^$ch\b//i;
      }
    }
    $chans =~ s/\s{2,}/ /g; #remove extra spaces
    if ($rmchans && $rmchans !~ m/^\s+$/) {
      settings_set_str('kbanreferrals_channels', $chans);
      print('KBan-Referrals: the following channels were removed from the list:');
      print($rmchans);
    }
    else {
      print('KBan-Referrals: no channels were removed from the list.');
    }
  }
  # chan list command
  elsif ($data =~ m/^chan list/i) {
    print('KBan-Referrals Channel List:');
    foreach (split(/\s+/, $chans)) {
      print($_) if ($_);
    }
  }
  # chan clear command
  elsif ($data =~ m/^chan clear/i) {
    settings_set_str('kbanreferrals_channels', '');
    print('KBan-Referrals: channel list cleared.');
  }
  # help command
  elsif ($data =~ m/^help/i) {
    print('KBan-Referrals Command Syntax (case insensitive):');
    print('-------------------------------------------------');
    print('Change KBan-Referrals mode: /KBANREF MODE [normal|paranoid]');
    print('Add channel(s) to the list: /KBANREF CHAN ADD #channel1 [#channel2 ...]');
    print('Remove channel(s) from the list: /KBANREF CHAN REMOVE #channel1 [#channel2 ...]');
    print('List all channels: /KBANREF CHAN LIST');
    print('Clear all channels from the list: /KBANREF CHAN CLEAR');
    print('Add site(s) to blacklist or whitelist: /KBANREF BLACKLIST|WHITELIST ADD site1.com [site2.com ...]');
    print('Remove site(s) from blacklist or whitelist: /KBANREF BLACKLIST|WHITELIST REMOVE site1.com [site2.com ...]');
    print('List all sites in blacklist or whitelist: /KBANREF BLACKLIST|WHITELIST LIST');
    print('Clear blacklist or whitelist: /KBANREF BLACKLIST|WHITELIST CLEAR');
    print('Show this help message: /KBANREF HELP');
  }
  # invalid command
  else {
    print("Invalid command. Available commands are: HELP, MODE, CHAN ADD, CHAN REMOVE, CHAN LIST, CHAN CLEAR, WHITELIST ADD, WHITELIST REMOVE, WHITELIST LIST, WHITELIST CLEAR, BLACKLIST ADD, BLACKLIST REMOVE, BLACKLIST LIST, BLACKLIST CLEAR.");
  }
}

# check if message contains a url
sub contains_url {
  my ($line) = @_;
  return 1 if ($line =~ m/(http|https)(:\/\/)[a-z0-9-]+(\.[a-z0-9-])+/i);
  return 1 if ($line =~ m/(www)(\.[a-z0-9-]+){2,}/i);
  return 0;
}

# sub for carrying out ban & kick irc commands
sub kb {
  my ($server, $target, $nick, $addr) = @_;
  $addr =~ /(\S+)@(\S+)/i;
  $server->command("mode $target +b " . '*!*@' . "$2");
  $server->command("kick $target $nick " . 'Referral URLs are not allowed!');
}

# sub for carrying out ban irc commands
sub ban {
  my ($server, $target, $nick, $addr) = @_;
  $addr =~ /(\S+)@(\S+)/i;
  $server->command("mode $target +b " . '*!*@' . "$2");
}

# sub for taking kickban action against url referrals
sub kban_action {
  my ($server, $msg, $nick, $nick_addr, $target) = @_;
  my $mode = settings_get_str('kbanreferrals_mode');
  my $whitelist = settings_get_str('kbanreferrals_whitelist');
  my $blacklist = settings_get_str('kbanreferrals_blacklist');
  my $chans = settings_get_str('kbanreferrals_channels');
  # add big ticket value to users who post messages without urls so they don't get punished
  $tickets{ $nick . $target } += 10 if (exists($tickets{ $nick . $target }) && $chans =~ m/$target\b/i && !contains_url($msg));
  # otherwise, start the real investigation
  if ($chans =~ m/$target\b/i && contains_url($msg)) {
    # paranoid mode
    if ($mode eq 'paranoid') {
      my $bad = 1;
      foreach (split(/\s+/, $whitelist)) {
        if ($msg =~ m/$_/i) {
          $bad = 0;
          last;
        }
      }
      kb($server, $target, $nick, $nick_addr) if ($bad);
    }
    # normal mode
    else {
      # if it is in the blacklist, always ban and stop here
      my $stop = 0;
      foreach (split(/\s+/, $blacklist)) {
        if ($msg =~ m/$_/i) {
          kb($server, $target, $nick, $nick_addr);
          $stop = 1;
          last;
        }
      }
      if (!$stop) {
        # otherwise, if it is in the whitelist, don't ban and stop here
        foreach (split(/\s+/, $whitelist)) {
          if ($msg =~ m/$_/i) {
            $stop = 1;
            last;
          }
        }
      }
      if (!$stop) {
        # here lies the supposedly smart method to detect url referral posters
        my $culprit = 0;
        $culprit = 1 if ($msg =~ m/[\/\?&]ref=/i);
        kb($server, $target, $nick, $nick_addr) if ($culprit);
        $tickets{ $nick . $target } += 1 if (exists($tickets{ $nick . $target }) && !$culprit);
      }
    }
  }
}

# this and 'increase_ticket' are used to distinguish users who join, post a url, and leave
sub ticket_start {
  my ($server, $channel, $nick, $nick_addr) = @_;
  my $chans = settings_get_str('kbanreferrals_channels');
  if ($chans =~ m/$channel\b/i) {
    $tickets{ $nick . $channel } = 1;
  }
}

sub increase_ticket {
  my ($server, $channel, $nick, $nick_addr, $reason) = @_;
  my $chans = settings_get_str('kbanreferrals_channels');
  if (exists($tickets{ $nick . $channel }) && $chans =~ m/$channel\b/i) {
    # if the poor bastard only posted one sole message containing a url before leaving
    # then it's probably a referral url, so ban him/her
    if ($tickets{ $nick . $channel } == 2) {
      ban($server, $channel, $nick, $nick_addr);
    }
    delete $tickets{ $nick . $channel };
  }
}

settings_add_str('kbanreferrals', 'kbanreferrals_mode' => 'normal');
settings_add_str('kbanreferrals', 'kbanreferrals_channels' => '');
settings_add_str('kbanreferrals', 'kbanreferrals_blacklist' => '');
settings_add_str('kbanreferrals', 'kbanreferrals_whitelist' => 'pastebin.com');
signal_add('message public', 'kban_action');
signal_add('message join', 'ticket_start');
signal_add('message part', 'increase_ticket');
command_bind(kbanref => \&kbanref);

