# mailcheck_imap.pl

# Contains code from centericq.pl (public domain) and imapbiff (GPL) and
# hence this is also GPL'd.

use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "0.5";
%IRSSI = (
    authors     => "David \"Legooolas\" Gardner",
    contact     => "irssi\@icmfp.com",
    name        => "mailcheck_imap",
    description => "Staturbar item which indicates how many new emails you have in the specified IMAP[S] mailbox",
    license     => "GNU GPLv2",
    url         => "http://icmfp.com/irssi",
);


# TODO:
#
# - command to show status, so we can see if we are currently connected
#  - add to statusbar item to say connected/not
#
# ? get user to type in password instead of storing it in a setting...
#  - eg. /mailcheck_imap_pass <password>
#
# - settings
#  - execute arbitrary command (with /exec?) on new mail?
#   - for 'spoing' or something  ;)
#  - auto-reconnect on/off
#
#
# LATER:
# - show subject/sender/whatever of new mail (customizable)
# - multiple accounts?
# - multiple mailboxes?


# Known bugs: segfaults on exit of irssi when script loaded  :/


use Irssi;
use Irssi::TextUI;
use IO::Socket;

# TODO : avoid requiring SSL when it's not in use?
#if (Irssi::settings_get_bool('mailcheck_imap_use_ssl')) {
#	Irssi::print("Using SSL.") if $debug_msgs;
#	$port = 993;
        require IO::Socket::SSL;
#  - you need the package libio-socket-ssl-perl on Debian
#}

#
# TODO : Set up signal handling for clean shutdown...
#
#$SIG{'ALRM'} = sub { die "socket timeout" };
#$SIG{'QUIT'} = 'cleanup';
#$SIG{'HUP'}  = 'cleanup';
#$SIG{'INT'}  = 'cleanup';
#$SIG{'KILL'} = 'cleanup';
#$SIG{'TERM'} = 'cleanup';



sub draw_box ($$$$) {
  my ($title, $text, $footer, $colour) = @_;
  my $box = '';
  $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
  foreach (split(/\n/, $text)) {
    $box .= '%R|%n '.$_."\n";
  }
  $box .= '%R`--<%n'.$footer.'%R>->%n';
  $box =~ s/%.//g unless $colour;
  return $box;
}


sub show_help() {
  my $help = $IRSSI{name}." ".$VERSION."
/mailcheck_imap_help
    Display this help.
/mailcheck_imap
    Check for new mail immediately, opening the connection if required.
/mailcheck_imap_stop
    Close connection to server and stop checking for new mail.
/set mailcheck_imap
    Show all mailcheck_imap settings.
    Note: You need to set at least host, user and password.
/statusbar <name> add mailcheck_imap
    Add statusbar item for mailcheck.


Formats in theme for statusbar item:
(number of new mails in $0, total number of message in $1)
  sb_mailcheck_imap = \"{sb Mail: $0 new, $1 total}\";
  sb_mailcheck_imap_zero = \"{sb Mail: None new, $1 total}\";

Format in theme for 'new mail arrived' message in current window:
(number of new mails in $0, total number of message in $1)
      mailcheck_imap_echo = \"You have $0 new message(s)!\";

Note: You have to set at least the mailcheck_imap_host, user,
      and password settings.

IMPORTANT NOTE: As this stores the password in your irssi config
file, you should really set the mode of the file to 0600 so that
it's only readable by your user.
";
  my $text = "";
  foreach (split(/\n/, $help)) {
    $_ =~ s/^\/(.*)$/%9\/$1%9/;
    $text .= $_."\n";
  }
  print CLIENTCRAP draw_box($IRSSI{name}, $text, "Help", 1);
}


sub cmd_mailcheck_imap_help {
  show_help();
}


#
# Global variables.
#
my $handle;
my ($logged_in, $sleep);
my ($last_refresh_time, $refresh_tag);
my ($new_messages, $old_new_messages);
my ($total_messages, $old_total_messages);

$handle    = 0;
$logged_in = 0;
$old_new_messages = -1;
$old_total_messages = -1;


#
# Subroutine to update status, called every N seconds.
#
sub refresh_mailcheck_imap {

  # For now, just print a message and return  :)
  Irssi::print("update hit.") if Irssi::settings_get_bool('mailcheck_imap_debug');

  # ensure we have details for the login..
  if(!check_details()) {
    return 0;
  }

  if(!$handle) {
    if(!setup_socket()) {
      error("Couldn't setup socket to imap server!",0);
      return 0;
    }
  }
  Irssi::print("Socket is setup.") if Irssi::settings_get_bool('mailcheck_imap_debug');

  if(!$logged_in) {
    if(!login()) {
      return 0;
    }
  }
  $new_messages = check_imap("UNSEEN");
  $total_messages = check_imap("MESSAGES");

  $new_messages = 0 if (! $new_messages);
  $total_messages = 0 if (! $total_messages);

  if ($new_messages eq "-1" || $total_messages eq "-1") {
    Irssi::print("check_imap returned an error, no updates.") if Irssi::settings_get_bool('mailcheck_imap_debug');
  }

  # update statusbar if changed rather than updating every the time...
  if(($new_messages != $old_new_messages) ||
     ($total_messages != $old_total_messages)) {
    update_statusbar_item();
  }


  # TODO : This doesn't work if you get a sequence such as:
  #        check -> arrive, delete, arrive -> check
  #        as it is just done on the number of unseen messages and won't know..
  if(($new_messages > $old_new_messages) &&
     (Irssi::settings_get_bool('mailcheck_imap_echo_new_in_window'))) {
    # If set, echo to the current window...
    my $theme = Irssi::current_theme();
    my $format = $theme->format_expand("{mailcheck_imap_echo}");

    if ($format) {
      # use theme-specific look
      $format = $theme->format_expand("{mailcheck_imap_echo $new_messages $total_messages}", Irssi::EXPAND_FLAG_IGNORE_REPLACES);
    } else {
      # use the default look
      $format = "mailcheck_imap: You have ".$new_messages." new message(s).";
    }

    print CLIENTCRAP $format;
  }
  $old_new_messages = $new_messages;
  $old_total_messages = $total_messages;

  # Adding new timeout to make sure that this function will be called again
  if ($refresh_tag) {
    Irssi::timeout_remove($refresh_tag);
  }
  my $time = Irssi::settings_get_int('mailcheck_imap_interval');
  $refresh_tag = Irssi::timeout_add($time*1000, 'refresh_mailcheck_imap', undef);

  return 1;
}


#
# Subroutine to setup socket handle.
#
sub setup_socket {
	# Set an alarm in case we can not connect or get hung.  Older versions
	# the IO::Socket perl module caused errors with the alarm we set before
	# setting up the socket.  If this program dies in debug mode saying:
	# "Alarm clock", then you can probably fix it by upgrading your perl
	# IO module.
	my ($host,$port);

	$host = Irssi::settings_get_str('mailcheck_imap_host');
	$port = Irssi::settings_get_int('mailcheck_imap_port');

	# change port number if SSL enabled and original imap port unchanged
	if($port == 143 && Irssi::settings_get_bool('mailcheck_imap_use_ssl')) {
	  $port = 993;
	}

	eval {
		alarm 30;
		Irssi::print("mailcheck_imap connecting to mail server...");

		if (Irssi::settings_get_bool('mailcheck_imap_use_ssl')) {
			Irssi::print("Using ssl...") if Irssi::settings_get_bool('mailcheck_imap_debug');
			$handle = IO::Socket::SSL->new(Proto           => "tcp",
			                               SSL_verify_mode => 0x00,
                                                       PeerAddr        => $host,
			                               PeerPort        => $port,
		                               	)
			or error("Can't connect to port $port on $host: $!",0), return 0;
		} else {
			$handle = IO::Socket::INET->new(Proto    => "tcp",
			                                PeerAddr => $host,
                                                        PeerPort => $port,
		                               	)
			or error("Can't connect to port $port on $host: $!",0), return 0;
		}
		$handle->autoflush(1);    # So output gets there right away.
		Irssi::print("...done");
		receive();
		alarm 0;
	};
	if ($@) {
		alarm 0;
		if ($@ =~ /timeout/) {
			alarm();
			return 0;
		} else {
			error("$@",0);
			return 0;
		}
	}
	return 1;
}

#
# Subroutine to login to the mailbox.
#
sub login {
  my ($response,$success);
  my ($user,$password);


  $user = Irssi::settings_get_str('mailcheck_imap_user');
  $password = Irssi::settings_get_str('mailcheck_imap_password');


  $logged_in = 0;
  # Set an alarm in case we can not connect or get hung.  Older versions
  # the IO::Socket perl module caused errors with the alarm we set before
  # setting up the socket.  If this program dies in debug mode saying:
  # "Alarm clock", then you can probably fix it by upgrading your perl
  # IO module.
  eval {
    alarm 30;
    send_data("A001 LOGIN \"$user\" \"$password\"","\"$user\"");
    while (1) {
      ($success,$response) = receive();
      if (! $success) {
	return 0;
      }
      last if $response =~ /LOGIN|OK/;
    }
    if ($response =~ /fail|BAD/) {
      return 0;
    } else {
      $logged_in = 1;
    }
    alarm 0;
  };
  if ($@) {
    alarm 0;
    if ($@ =~ /timeout/) {
      alarm();
      return 0;
    } else {
      error("$@",0);
      return 0;
    }
  }
  # Success!  :D
  return 1;
}

#
# Subroutine that does check of imap mailbox.
#
sub check_imap {
  my ($type) = @_;

  #my ($type) = ("MESSAGES");

  my ($response,$success,$num_messages);
  # Set an alarm in case we can not connect or get hung.  Older versions
  # the IO::Socket perl module caused errors with the alarm we set before
  # setting up the socket.  If this program dies in debug mode saying:
  # "Alarm clock", then you can probably fix it by upgrading your perl
  # IO module.
  eval {
    alarm 30;
    send_data("A003 STATUS INBOX ($type)");
    while (1) {
      ($success,$response) = receive();
      if (! $success) {
	return "-1";
      }
      last if $response =~ /STATUS\s+.*?\s+\($type/;
    }
    ($num_messages) = $response =~ /\($type\s+(\d+)\)/;
    alarm 0;
  };
  if ($@) {
    alarm 0;
    if ($@ =~ /timeout/) {
      alarm();
      return "-1";
    } else {
      error("$@",0);
      return "-1";
    }
  }
  return $num_messages;
}


#
# Subroutine to send a line to the imap server.
# Block everything after $block.
#
sub send_data {
	my ($line,$block) = (@_);
	print $handle "$line\r\n";
	$line =~ s/(.*$block).*/$1 ----/ if ($block);
	Irssi::print("sent: $line") if Irssi::settings_get_bool('mailcheck_imap_debug');
	return 1;
}


#
# Subroutine to get a response from the imap server and print.
# that response if in debug mode.
#
sub receive {
	my ($response,$success);
	$response = "";
	$success  = 0;
	chomp($response = <$handle>);
	if ($response) {
		Irssi::print("got: $response") if Irssi::settings_get_bool('mailcheck_imap_debug');
		$success = 1;
	} else {
		Irssi::print("no response!") if Irssi::settings_get_bool('mailcheck_imap_debug');
	}
	return ($success,$response);
}

#
# Subroutine to display and error message in a text box.
#
sub error {
  my ($error,$fatal) = (@_);

  if ($fatal) {
    # TODO : Print some useful message and die?
    Irssi::print("mailcheck_imap FATAL : $error");
    return 0;
  } else {
    Irssi::print("mailcheck_imap error : $error");

    if ($refresh_tag) {
      Irssi::timeout_remove($refresh_tag)
    }
    my $time = Irssi::settings_get_int('mailcheck_imap_interval');
    $refresh_tag = Irssi::timeout_add($time*1000, 'refresh_mailcheck_imap', undef);
    $handle = 0;
    return 0;
  }	
}

#
# Subroutine to call when alarm times out.
#
sub alarm {
  Irssi::print("Alarm went off!") if Irssi::settings_get_bool('mailcheck_imap_debug');
  return 1;
}


#
# Subroutine to clean up.
#
sub cleanup {
  if ($handle) {
    send_data("A999 LOGOUT");
    $handle->close();
  }
  Irssi::print("mailcheck_imap logged out.");
}



#######################################################################
# Simply requests a statusbar item redraw.

sub update_statusbar_item {
  Irssi::statusbar_items_redraw('mailcheck_imap');
}


#######################################################################
# This is the function called by irssi to obtain the statusbar item.

sub mailcheck_imap {
  my ($item, $get_size_only) = @_;

  my $theme = Irssi::current_theme();
  my $format = $theme->format_expand("{sb_mailcheck_imap}");

  if ($format) {
    # use theme-specific look
    $format = $theme->format_expand("{sb_mailcheck_imap $new_messages $total_messages}", Irssi::EXPAND_FLAG_IGNORE_REPLACES);
  } else {
    # use the default look
    $format = "{sb Mail: ".$new_messages." new, ".$total_messages." total}";
  }

  if($new_messages == 0) {
    if(Irssi::settings_get_bool('mailcheck_imap_show_zero')) {
      $format = $theme->format_expand("{sb_mailcheck_imap_zero $new_messages $total_messages}", Irssi::EXPAND_FLAG_IGNORE_REPLACES);

      if (!$format) {
	# use the default look
	$format = "{sb Mail: None new, ".$total_messages." total}";
      }
    } else {
      $format = "";
    }
  }

  if (length($format) == 0) {
    # nothing to print, so don't print at all
    if ($get_size_only) {
      $item->{min_size} = $item->{max_size} = 0;
    }
  } else {
    $item->default_handler($get_size_only, $format, undef, 1);
  }
}


################################################################################
# Ensure that all required details are filled in:
# host, user, password
sub check_details {
  my $host = Irssi::settings_get_str('mailcheck_imap_host');
  my $user = Irssi::settings_get_str('mailcheck_imap_user');
  my $password = Irssi::settings_get_str('mailcheck_imap_password');

  if(!$host || !$user || !$password) {
    show_help();
    return 0;
  }
  return 1;
}


################################################################################
# Immediately check for new mail (updates statusbar item too)

sub cmd_mailcheck_imap {
  refresh_mailcheck_imap();
}


################################################################################
# Kill the connection and stop the refresh.
sub cmd_mailcheck_imap_stop {
  if ($refresh_tag) {
    Irssi::timeout_remove($refresh_tag);
  }
  cleanup();
}

# Also close connection on script unload?
sub sig_command_script_unload ($$$) {
  my ($script, $server, $witem) = @_;

  if($script =~ /^mailcheck_imap\.pl$/ ||
     $script =~ /^mailcheck_imap/) {
    cleanup();
  }
}

Irssi::signal_add_first('command script unload', \&sig_command_script_unload);


#######################################################################
# Adding stuff to irssi

Irssi::settings_add_int('mail', 'mailcheck_imap_interval', 120);
Irssi::settings_add_bool('mail', 'mailcheck_imap_use_ssl', 0);
Irssi::settings_add_bool('mail', 'mailcheck_imap_debug', 0);
Irssi::settings_add_bool('mail', 'mailcheck_imap_show_zero', 0);
Irssi::settings_add_bool('mail', 'mailcheck_imap_echo_new_in_window', 1);

Irssi::settings_add_str('mail', 'mailcheck_imap_host', '');
Irssi::settings_add_int('mail', 'mailcheck_imap_port', 143);
Irssi::settings_add_str('mail', 'mailcheck_imap_user', '');
Irssi::settings_add_str('mail', 'mailcheck_imap_password', '');


Irssi::statusbar_item_register('mailcheck_imap', '{sb $0-}', 'mailcheck_imap');

Irssi::command_bind('mailcheck_imap_help','cmd_mailcheck_imap_help');
Irssi::command_bind('mailcheck_imap','cmd_mailcheck_imap');
Irssi::command_bind('mailcheck_imap_stop','cmd_mailcheck_imap_stop');


#######################################################################
# Startup functions

# Check that everything is fiiiine and start checking if so
if(check_details()) {
  # All is ok, so start running it
  refresh_mailcheck_imap();
  update_statusbar_item();
}


#######################################################################
