use strict;
use vars qw($VERSION %IRSSI);
use Irssi::TextUI;

$VERSION = "0.1";
%IRSSI = (
    authors     => 'Doncho N. Gunchev',
    contact     => 'mr_700@yahoo.com',
    name        => 'UNIBG-autoident',
    description => 'Automaticaly /msg ident NS yourpassword when you connect or services come back from death',
    license     => 'Public Domain',
    url         => 'http://not.available.yet/',
    changed	=> 'Sat Jan 25 02:35:40 EET 2003'
);

# UNIBG NS auto identifyer
# for irssi 0.8.1 by Doncho N. Gunchev
#
# Check /id help for help.


my $msghead='autoident:';
# list of nicks/passwords
my %passwords = ();
my $numpasswords = 0;
my $passwordspassword = '';
my $nsnick='NS';
my $nshost='NickServ@UniBG.services';
my $nsreq='This nickname is owned by someone else';
my $nsok  ='Password accepted - you are now recognized';
my $nscmd ='identify';
# 2DO
#	0. Do it!
#	1. Make it take nick, passwor and network as parameters
#	2. Make NS, CS, MS and maybe OS support
#	3. Add eggdrop support
#       4. Add encrypted passwords in config file...
#	5. Add Global support or maybe /notify NS or bouth?
#	6. Don't autoident 2 times in less than xxx seconds
#	7. Change nick if we don't have the password / ask user for it
#	   in xxx seconds before changing nicks
#	8. Add /id newpass,setpass,permpas,ghost,kill....
#	9. Add /id chanadd chandel chan....
#

sub cmd_print_help {
  Irssi::print(<<EOF, MSGLEVEL_CRAP);
$msghead
          WELL... as I'm starting to write this - no help!
          /id add nick password - add new nick with password to autoident
          /id del nick          - delete nick from autoident list
          /id list              - show nicks in autoident list
          /id show              - same as /id list
          /id help              - this one
EOF
#          /id check             - see if current nick is in autoident list
}


sub msg {
  my ($msg, $lvl) = @_;
  Irssi::print("$msghead $msg", $lvl);
}


sub event_notice {
  # $server = server record where the message came
  # $data = the raw data received from server, with NOTICEs it is:
  #         "target :text" where target is either your nick or #channel
  # $nick = the nick who sent the message
  # $host = host of the nick who sent the message
  my ($server, $data, $nick, $host) = @_;
  #04:06 -!- autoident(debug): server= Irssi::Irc::Server=HASH(0x86786cc)
  #04:06 -!- autoident(debug): data  = Mr_700 :This nickname is owned by someone else
  #04:06 -!- autoident(debug): nick  = NS
  #04:06 -!- autoident(debug): host  = NickServ@UniBG.services
  #04:06 -!- autoident(debug): target = Mr_700
  #04:06 -!- autoident(debug): text   = This nickname is owned by someone else

  # split data to target/text
  my ($target, $text) = $data =~ /^(\S*)\s:(.*)/;

  # check the sent text
  return if ($text !~ /$nsreq/) && ($text !~ /$nsok/);

  # check the sender's nick
  return if ($nick !~ /$nsnick/);

  # check the sender's host
  if ($host !~ /$nshost/) {
    msg("!!! '$nsnick' host is bad, hack attempt? !!!", MSGLEVEL_CRAP);
    msg("!!!", MSGLEVEL_CRAP);
    msg("!!!  sender: '$nick!$host'", MSGLEVEL_CRAP);
    msg("!!!  target: '$target'", MSGLEVEL_CRAP);
    msg("!!!  text  : '$text'", MSGLEVEL_CRAP);
    msg("!!!", MSGLEVEL_CRAP);
    msg("!!! '$nsnick' host is bad, hack attempt? !!!", MSGLEVEL_CRAP);
    return;
  }

  # check if sent to us directly
  return if ($target !~ /$server->{nick}/);

  if ($text =~ /$nsreq/) {
    if (exists($passwords{$server->{nick}})) {
      msg("'$nsnick!$nshost' requested identity, sending...", MSGLEVEL_CRAP);
      $server->command("MSG $nsnick $nscmd " . $passwords{$server->{nick}});
    } else {
      msg("'$nsnick!$nshost' says '$nsreq' and we have no password set for it!", MSGLEVEL_CRAP);
      msg("          use /id add " . $server->{nick} . " <password> to set it!", MSGLEVEL_CRAP);
      msg("          ... autoident has left you in /dev/random", MSGLEVEL_CRAP);
    }
  } else {
    msg("'$nsnick!$nshost' accepted identity", MSGLEVEL_CRAP);
  }
}


sub addpassword {
  my ($name, $password) = @_;

  if (exists($passwords{$name})) {
    if ($password eq $passwords{$name}) {
      msg("Nick $name already has this password for autoident", MSGLEVEL_CRAP);
    } else {
      msg("Nick $name's autoident password changed", MSGLEVEL_CRAP);
      $passwords{$name} = $password;
    }
  } else {
    $passwords{$name} = $password;
    $numpasswords++;
    msg("Nick $name added to autoident list ($numpasswords total)", MSGLEVEL_CRAP);
  }
}

sub delpassword {
  my $name = $_[0];

  if (exists($passwords{$name})) {
    delete($passwords{$name});
    $numpasswords--;
    msg("Nick $name removed from autoidentify list ($numpasswords left)", MSGLEVEL_CRAP);
  } else {
    msg("Nick $name is not in autoident list", MSGLEVEL_CRAP);
  }
}

sub init_passwords {
  # Add the passwords at startup of the script
  my $passwordsstring = Irssi::settings_get_str('autoident');
  if (length($passwordsstring) > 0) {
    my @passwords = split(/,/, $passwordsstring);

    foreach my $i (@passwords) {
      my $name = substr($i, 0, index($i, '='));
      my $password = substr($i, index($i, '=') + 1, length($i));
      addpassword($name, $password);
    }
  }
}


sub read_settings {
#  my $passwords = Irssi::settings_get_str('passwords');
}


sub update_settings_string {
  my $setting;

  foreach my $name (keys(%passwords)) {
    $setting .= $name . "=" . $passwords{$name} . ",";
  }

  Irssi::settings_set_str("autoident", $setting);
}


sub cmd_addpassword {
  my ($name, $password) = split(/ +/, $_[0]);

  if ($name eq "" || $password eq "") {
    msg("Use /id add <name> <password> to add new nick to autoident list", MSGLEVEL_CRAP);
    return;
  }
  addpassword($name, $password);
  update_settings_string();
}

sub cmd_delpassword {
  my $name = $_[0];

  if ($name eq "") {
    msg("Use /id del <name> to delete a nick from autoident list", MSGLEVEL_CRAP);
    return;
  }

  delpassword($name);
  update_settings_string();
}

sub cmd_showpasswords {
  if ($numpasswords == 0) {
    msg("No nicks defined for autoident", MSGLEVEL_CRAP);
    return;
  }
  msg("Nicks for autoident:", MSGLEVEL_CRAP);
  my $n = 1;
  foreach my $nick (keys(%passwords)) {
#    msg("$nick: " . $mailboxes{$password}, MSGLEVEL_CRAP);
    msg("$n. $nick: ***", MSGLEVEL_CRAP);
    $n++;
  }
}

sub cmd_id {
  my ($data, $server, $item) = @_;
  if ($data =~ m/^[(show)|(add)|(del)|(help)]/i ) {
    Irssi::command_runsub('id', $data, $server, $item);
  } else {
    msg("Use /id (show|add|del|help)", MSGLEVEL_CRAP);
  }
}

Irssi::command_bind('id show', 'cmd_showpasswords');
Irssi::command_bind('id list', 'cmd_showpasswords');
Irssi::command_bind('id add', 'cmd_addpassword');
Irssi::command_bind('id del', 'cmd_delpassword');
Irssi::command_bind('id help', 'cmd_print_help');
Irssi::command_bind('id', 'cmd_id');
Irssi::settings_add_str('misc', 'autoident', '');

read_settings();
init_passwords();
Irssi::signal_add('setup changed', 'read_settings');

#Irssi::signal_add('event privmsg', 'event_privmsg');
Irssi::signal_add('event notice', 'event_notice');

msg("loaded ok", MSGLEVEL_CRAP);

# EOF
