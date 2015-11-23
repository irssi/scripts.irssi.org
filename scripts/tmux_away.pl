use Irssi;
use strict;
use FileHandle;

use vars qw($VERSION %IRSSI);

$VERSION = "2.1"; # e8934ed1ce04461
%IRSSI = (
    authors     => 'cdidier',
    name        => 'tmux_away',
    description => 'set (un)away if tmux session is attached/detached',
    license     => 'GPL v2',
    url         => 'http://cybione.org',
);

# tmux_away irssi module
#
# Written by Colin Didier <cdidier@cybione.org> and heavily based on
# screen_away irssi module version 0.9.7.1 written by Andreas 'ads' Scherbaum
# <ads@ufp.de>.
#
# Updated by John C. Vernaleo <john@netpurgatory.com> to handle tmux with
# named sessions and other code cleanup and forked as version 2.0.
#
# usage:
#
# put this script into your autorun directory and/or load it with
#  /SCRIPT LOAD <name>
#
# there are 5 settings available:
#
# /set tmux_away_active ON/OFF/TOGGLE
# /set tmux_away_repeat <integer>
# /set tmux_away_grace <integer>
# /set tmux_away_message <string>
# /set tmux_away_window <string>
# /set tmux_away_nick <string>
#
# active means that you will be only set away/unaway, if this
#   flag is set, default is ON
# repeat is the number of seconds, after the script will check the
#   tmux session status again, default is 5 seconds
# grace is the number of seconds, to wait additionally, before
#   setting you away, default is disabled (0)
# message is the away message sent to the server, default: not here ...
# window is a window number or name, if set, the script will switch
#   to this window, if it sets you away, default is '1'
# nick is the new nick, if the script goes away
#   will only be used it not empty


# variables
my $timer_name = undef;
my $away_status = 0;
my %old_nicks = ();
my %away = ();

# Register formats
Irssi::theme_register(
[
 'tmux_away_crap',
 '{line_start}{hilight ' . $IRSSI{'name'} . ':} $0'
]);

# try to find out if we are running in a tmux session
# (see if $ENV{TMUX} is set)
if (!defined($ENV{TMUX})) {
  # just return, we will never be called again
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'tmux_away_crap',
    "no tmux session!");
  return;
}

my @args_env = split(',', $ENV{TMUX});
my $tmux_socket = $args_env[0];

# register config variables
Irssi::settings_add_bool('misc', $IRSSI{'name'} . '_active', 1);
Irssi::settings_add_int('misc', $IRSSI{'name'} . '_repeat', 5);
Irssi::settings_add_int('misc', $IRSSI{'name'} . '_grace', 0);
Irssi::settings_add_str('misc', $IRSSI{'name'} . '_message', "not here...");
Irssi::settings_add_str('misc', $IRSSI{'name'} . '_window', "1");
Irssi::settings_add_str('misc', $IRSSI{'name'} . '_nick', "");


# check, set or reset the away status
sub tmux_away {
    my ($immediate) = @_;
  my ($status, @res);

  # only run, if activated
  if (Irssi::settings_get_bool($IRSSI{'name'} . '_active') != 1) {
    $away_status = 0;
  } else {
    if ($away_status == 0) {
      # display init message at first time
	my $grace = Irssi::settings_get_int($IRSSI{'name'} . '_grace');
	$grace = ", $grace seconds grace" if $grace;
      Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'tmux_away_crap',
        "activating $IRSSI{'name'} (interval: " . Irssi::settings_get_int($IRSSI{'name'} . '_repeat') . " seconds$grace)");
      $away_status = 2;
    }

    # get actual tmux session status
    chomp(@res = `tmux -S '$tmux_socket' lsc 2>&1`);
    chomp(my $tmux_session = `tmux -S '$tmux_socket' display -p '#S' 2>/dev/null`);
    if ($res[0] =~ /^server not found/ || $? >> 8) {
      die "error getting tmux session status.";
    }
    $status = 1; # away, assumes the session is detached
    foreach (@res) {
      my @args_st = split(' ');
      if ($args_st[1] eq $tmux_session) {
        $status = 2; # unaway
      }
    }

    # unaway -> away
    if ($status == 1 and $away_status != 1) {
	if (my $grace = Irssi::settings_get_int($IRSSI{'name'} . '_grace')) {
	    if (!$immediate) {
		Irssi::timeout_add_once($grace * 1000, 'tmux_away', '1');
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'tmux_away_crap',
				   "(in grace for away: $grace seconds)");
		return 1;
	    }
	}
      if (length(Irssi::settings_get_str($IRSSI{'name'} . '_window')) > 0) {
        # if length of window is greater then 0, make this window active
        Irssi::command('window goto ' . Irssi::settings_get_str($IRSSI{'name'} . '_window'));
      }
      Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'tmux_away_crap', "Set away");
      my $message = Irssi::settings_get_str($IRSSI{'name'} . '_message');
      if (length($message) == 0) {
        # we have to set a message or we wouldnt go away
        $message = "not here ...";
      }
      foreach (Irssi::servers()) {
        if (!$_->{usermode_away}) {
	  # user isn't yet away
	  $away{$_->{'tag'}} = 0;
	  $_->command("^AWAY " . ($_->{chat_type} ne 'SILC' ? "-one " : "") . "$message");
	  if ($_->{chat_type} ne 'XMPP' and length(Irssi::settings_get_str($IRSSI{'name'} . '_nick')) > 0) {
            # only change if actual nick isn't already the away nick
            if (Irssi::settings_get_str($IRSSI{'name'} . '_nick') ne $_->{nick}) {
              # keep old nick
              $old_nicks{$_->{'tag'}} = $_->{nick};
              # set new nick
              $_->command("NICK " . Irssi::settings_get_str($IRSSI{'name'} . '_nick'));
            }
          }
        } else {
          # user is already away, remember this
          $away{$_->{'tag'}} = 1;
        }
      }
      $away_status = $status;

    # away -> unaway
    } elsif ($status == 2 and $away_status != 2) {
	if (my $grace = Irssi::settings_get_int($IRSSI{'name'} . '_grace')) {
	    if (!$immediate) {
		Irssi::timeout_add_once($grace * 1000, 'tmux_away', '1');
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'tmux_away_crap',
				   "(in grace for unaway: $grace seconds)");
		return 1;
	    }
	}
      # unset away
      Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'tmux_away_crap', "Reset away");
      foreach (Irssi::servers()) {
        if ($away{$_->{'tag'}} == 1) {
          # user was already away, don't reset away
          $away{$_->{'tag'}} = 0;
          next;
        }
        $_->command("^AWAY" . (($_->{chat_type} ne 'SILC') ? " -one" : "")) if ($_->{usermode_away});
        if ($_->{chat_type} ne 'XMPP' and defined($old_nicks{$_->{'tag'}}) and length($old_nicks{$_->{'tag'}}) > 0) {
          # set old nick
          $_->command("NICK " . $old_nicks{$_->{'tag'}});
          $old_nicks{$_->{'tag'}} = "";
        }
      }
      $away_status = $status;
    } elsif ($immediate) {
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'tmux_away_crap',
				   "in grace aborted");
    }
  }
  # but everytimes install a new timer
  register_tmux_away_timer();
  return 0;
}

# remove old timer and install a new one
sub register_tmux_away_timer {
  # add new timer with new timeout (maybe the timeout has been changed)
  Irssi::timeout_add_once(Irssi::settings_get_int($IRSSI{'name'} . '_repeat') * 1000, 'tmux_away', '');
}

# init process
tmux_away();
