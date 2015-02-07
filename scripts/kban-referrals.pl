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

our $VERSION = '1.03';
our %IRSSI = (authors => 'Linostar',
          contact => 'linostar@sdf.org',
          name => 'KickBan Referrals Script',
          description => 'Script for kickbanning those who post referral links in a channel',
          commands => 'kbanref',
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
  my $subcommand = '';
  my ($command, @args) = split(/\s+/, $data);
  $command = lc($command);
  $_ = lc for @args; #apply lc to all elements in @args
  $subcommand = $args[0] if ($args[0]);
  # mode command
  if ($command eq 'mode') {
    $subcommand = 'get' unless ($subcommand);
    if ($subcommand eq 'get') {
      print('KBan-Referrals: current mode is set to ' . uc(settings_get_str('kbanreferrals_mode')) . '.');
    }
    elsif ($subcommand eq 'normal') {
      settings_set_str('kbanreferrals_mode', 'normal');
      print('KBan-Referrals: mode set to NORMAL. Whitelist and Blacklist will be used, along with a somewhat smart referral URL detection.');
    }
    elsif ($subcommand eq 'paranoid') {
      settings_set_str('kbanreferrals_mode', 'paranoid');
      print('KBan-Referrals: mode set to PARANOID. Every URL that does not match a website in the whitelist will trigger a kickban.');
    }
    else {
      print('KBan-Referrals: invalid mode. Available modes are NORMAL and PARANOID.');
    }
  }
  # whitelist or blacklist add command
  elsif ($command =~ m/^(white|black)list$/ && $subcommand eq 'add') {
    my $newlist = '';
    my $type = substr($command, 0, 5);
    if ($type eq 'black') {
      $thelist = \$blacklist;
    }
    else {
      $thelist = \$whitelist;
    }
    my @list_arr = split(/\s+/, lc($$thelist));
    splice(@args, 0, 1);
    foreach (@args) {
      if ($_ ~~ @list_arr) {
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
      if ($type eq 'black') {
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
  elsif ($command =~ m/^(white|black)list$/ && $subcommand eq 'remove') {
    my $rmlist = '';
    my $type = substr($command, 0, 5);
    if ($type eq 'black') {
      $thelist = \$blacklist;
    }
    else {
      $thelist = \$whitelist;
    }
    my @list_arr = split(/\s+/, lc($$thelist));
    splice(@args, 0, 1);
    foreach (@args) {
      unless ($_ ~~ @list_arr) {
        print("KBan-Referrals: site $_ is not in " . $type . 'list.');
      }
      else {
        $rmlist .= ' ' . $_;
        $$thelist =~ s/(\s|^)$_(\s|$)/ /i;
      }
    }
    $$thelist =~ s/\s{2,}/ /g;
    if ($rmlist && $rmlist !~ m/^\s+$/) {
      print('KBan-Referrals: the following sites were removed from ' . $type . 'list:');
      print($rmlist);
      if ($type eq 'black') {
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
  elsif ($command =~ m/^(white|black)list$/ && $subcommand eq 'list') {
    print('KBan-Referrals ' . $1 . 'list:');
    if ($1 eq 'black') {
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
  elsif ($command =~ m/^(white|black)list$/ && $subcommand eq 'clear') {
    print('KBan-Referrals: ' . $1 . 'list is cleared.');
    if ($1 eq 'black') {
      settings_set_str('kbanreferrals_blacklist', '');
    }
    else {
      settings_set_str('kbanreferrals_whitelist', '');
    }
  }
  # chan add command
  elsif ($command eq 'chan' && $subcommand eq 'add') {
    my $newchans = '';
    my $ch = '';
    my @chans_arr = split(/\s+/, lc($chans));
    splice(@args, 0, 1);
    foreach(@args) {
      $ch = (substr($_, 0, 1) eq '#') ? $_ : '#' . $_;
      if ($ch ~~ @chans_arr) {
        print("KBan-Referrals: channel $ch is already in the list.");
      }
      else {
        $newchans .= ' ' . $ch;
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
  elsif ($command eq 'chan' && $subcommand eq 'remove') {
    my $rmchans = '';
    my $ch = '';
    my @chans_arr = split(/\s+/, lc($chans));
    splice(@args, 0, 1);
    foreach (@args) {
      $ch = (substr($_, 0, 1) eq '#') ? $_ : '#' . $_;
      unless ($ch ~~ @chans_arr) {
        print("KBan-Referrals: channel $ch is not in the list.");
        next;
      }
      else {
        $rmchans .= ' ' . $ch;
        $chans =~ s/(\s|^)($ch)(\s|$)/ /i;
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
  elsif ($command eq 'chan' && $subcommand eq 'list') {
    print('KBan-Referrals Channel List:');
    foreach (split(/\s+/, $chans)) {
      print($_) if ($_);
    }
  }
  # chan clear command
  elsif ($command eq 'chan' && $subcommand eq 'clear') {
    settings_set_str('kbanreferrals_channels', '');
    print('KBan-Referrals: channel list cleared.');
  }
  # help command
  elsif ($command eq 'help') {
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
  my @chans_arr = split(/\s+/, lc($chans));
  $mode = 'normal' unless ($mode eq 'paranoid');
  # add a high ticket value to users who post messages without urls so they don't get punished
  $tickets{ $nick . $target } += 10 if (exists($tickets{ $nick . $target }) && $target ~~ @chans_arr && !contains_url($msg));
  # otherwise, start the real investigation
  if ($target ~~ @chans_arr && contains_url($msg)) {
    # paranoid mode
    if ($mode =~ m/^paranoid$/i) {
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
    elsif ($mode =~ m/^normal$/i) {
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
  my @chans_arr = split(/\s+/, lc($chans));
  if ($channel ~~ @chans_arr) {
    $tickets{ $nick . $channel } = 1;
  }
}

sub increase_ticket {
  my ($server, $channel, $nick, $nick_addr, $reason) = @_;
  my $chans = settings_get_str('kbanreferrals_channels');
  my @chans_arr = split(/\s+/, lc($chans));
  if (exists($tickets{ $nick . $channel }) && $channel ~~ @chans_arr) {
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

