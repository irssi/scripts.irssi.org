use strict;
use Irssi 20020101.0250 ();
use vars qw($VERSION %IRSSI);
$VERSION = "2.1";
%IRSSI = (
    authors     => "Timo Sirainen, Ian Peters, David Leadbeater, Bruno Cattáneo",
    contact	=> "tss\@iki.fi",
    name        => "Nick Color",
    description => "assign a different color for each nick",
    license	=> "Public Domain",
    url		=> "http://irssi.org/",
    changed	=> "Mon 08 Jan 21:28:53 BST 2018",
);

# Settings:
#   nickcolor_colors: List of color codes to use.
#   e.g. /set nickcolor_colors 2 3 4 5 6 7 9 10 11 12 13
#   (avoid 8, as used for hilights in the default theme).
#
#   nickcolor_enable_prefix: Enables prefix for same nick.
#
#   nickcolor_enable_truncate: Enables nick truncation.
#
#   nickcolor_prefix_text: Prefix text for succesive messages.
#   e.g. /set nickcolor_prefix_text -
#
#   nickcolor_truncate_value: Truncate nick value.
#   e.g. /set nickcolor_truncate_value -7
#   This will truncate nicknames at 7 characters and make them right aligned

my %saved_colors;
my %session_colors = {};
my %saved_nicks; # To store each channel's last nickname

sub load_colors {
  open my $color_fh, "<", "$ENV{HOME}/.irssi/saved_colors";
  while (<$color_fh>) {
    chomp;
    my($nick, $color) = split ":";
    $saved_colors{$nick} = $color;
  }
}

sub save_colors {
  open COLORS, ">", "$ENV{HOME}/.irssi/saved_colors";

  foreach my $nick (keys %saved_colors) {
    print COLORS "$nick:$saved_colors{$nick}\n";
  }

  close COLORS;
}

# If someone we've colored (either through the saved colors, or the hash
# function) changes their nick, we'd like to keep the same color associated
# with them (but only in the session_colors, ie a temporary mapping).

sub sig_nick {
  my ($server, $newnick, $nick, $address) = @_;
  my $color;

  $newnick = substr ($newnick, 1) if ($newnick =~ /^:/);

  if ($color = $saved_colors{$nick}) {
    $session_colors{$newnick} = $color;
  } elsif ($color = $session_colors{$nick}) {
    $session_colors{$newnick} = $color;
  }
}

# This gave reasonable distribution values when run across
# /usr/share/dict/words

sub simple_hash {
  my ($string) = @_;
  chomp $string;
  my @chars = split //, $string;
  my $counter;

  foreach my $char (@chars) {
    $counter += ord $char;
  }

  my @colors = split / /, Irssi::settings_get_str('nickcolor_colors');
  $counter = $colors[$counter % @colors];

  return $counter;
}

# process public (others) messages
sub sig_public {
  my ($server, $msg, $nick, $address, $target) = @_;

  my $enable_prefix = Irssi::settings_get_bool('nickcolor_enable_prefix');
  my $enable_truncate = Irssi::settings_get_bool('nickcolor_enable_truncate');
  my $prefix_text = Irssi::settings_get_str('nickcolor_prefix_text');
  my $truncate_value = Irssi::settings_get_int('nickcolor_truncate_value');

  # Reference for server/channel
  my $tagtarget = "$server->{tag}/$target";

  # Set default nick truncate value to 0 if option is disabled
  $truncate_value = 0 if (!$enable_truncate);

  # Has the user assigned this nick a color?
  my $color = $saved_colors{$nick};

  # Have -we- already assigned this nick a color?
  if (!$color) {
    $color = $session_colors{$nick};
  }

  # Let's assign this nick a color
  if (!$color) {
    $color = simple_hash $nick;
    $session_colors{$nick} = $color;
  }

  $color = sprintf "\003%02d", $color;

  # Optional: We check if it's the same nickname for current target
  if ($saved_nicks{$tagtarget} eq $nick && $enable_prefix)
  {
    # Grouped message
    Irssi::command('/^format pubmsg ' . $prefix_text . '$1');
  }
  else
  {
    # Normal message
    Irssi::command('/^format pubmsg {pubmsgnick $2 {pubnick ' . $color . '$[' . $truncate_value . ']0}}$1');

    # Save nickname for next message
    $saved_nicks{$tagtarget} = $nick;
  }

}

# process public (me) messages
sub sig_me {
  my ($server, $msg, $target) = @_;
  my $nick = $server->{nick};

  my $enable_prefix = Irssi::settings_get_bool('nickcolor_enable_prefix');
  my $enable_truncate = Irssi::settings_get_bool('nickcolor_enable_truncate');
  my $prefix_text = Irssi::settings_get_str('nickcolor_prefix_text');
  my $truncate_value = Irssi::settings_get_int('nickcolor_truncate_value');

  # Reference for server/channel
  my $tagtarget = "$server->{tag}/$target";

  # Set default nick truncate value to 0 if option is disabled
  $truncate_value = 0 if (!$enable_truncate);

  # Optional: We check if it's the same nickname for current target
  if ($saved_nicks{$tagtarget} eq $nick && $enable_prefix)
  {
    # Grouped message
    Irssi::command('/^format own_msg ' . $prefix_text . '$1');
  }
  else
  {
    # Normal message
    Irssi::command('/^format own_msg {ownmsgnick $2 {ownnick $[' . $truncate_value . ']0}}$1');

    # Save nickname for next message
    $saved_nicks{$tagtarget} = $nick;
  }

}

# process public (others) actions
sub sig_action_public {
  my ($server, $msg, $nick, $address, $target) = @_;

  my $enable_prefix = Irssi::settings_get_bool('nickcolor_enable_prefix');

  # Reference for server/channel
  my $tagtarget = "$server->{tag}/$target";

  # Empty current target nick if prefix option is enabled
  $saved_nicks{$tagtarget} = '' if ($enable_prefix);

}

# process public (me) actions
sub sig_action_me {
  my ($server, $msg, $target) = @_;
  my $nick = $server->{nick};

  my $enable_prefix = Irssi::settings_get_bool('nickcolor_enable_prefix');

  # Reference for server/channel
  my $tagtarget = "$server->{tag}/$target";

  # Empty current target nick if prefix option is enabled
  $saved_nicks{$tagtarget} = '' if ($enable_prefix);

}

sub cmd_color {
  my ($data, $server, $witem) = @_;
  my ($op, $nick, $color) = split " ", $data;

  $op = lc $op;

  if (!$op) {
    Irssi::print ("No operation given (save/set/clear/list/preview)");
  } elsif ($op eq "save") {
    save_colors;
  } elsif ($op eq "set") {
    if (!$nick) {
      Irssi::print ("Nick not given");
    } elsif (!$color) {
      Irssi::print ("Color not given");
    } elsif ($color < 2 || $color > 14) {
      Irssi::print ("Color must be between 2 and 14 inclusive");
    } else {
      $saved_colors{$nick} = $color;
    }
  } elsif ($op eq "clear") {
    if (!$nick) {
      Irssi::print ("Nick not given");
    } else {
      delete ($saved_colors{$nick});
    }
  } elsif ($op eq "list") {
    Irssi::print ("\nSaved Colors:");
    foreach my $nick (keys %saved_colors) {
      Irssi::print (chr (3) . sprintf("%02d", $saved_colors{$nick}) . "$nick" .
		    chr (3) . "1 ($saved_colors{$nick})");
    }
  } elsif ($op eq "preview") {
    Irssi::print ("\nAvailable colors:");
    foreach my $i (2..14) {
      Irssi::print (chr (3) . "$i" . "Color #$i");
    }
  }
}

load_colors;

Irssi::settings_add_str('misc', 'nickcolor_colors', '2 3 4 5 6 7 9 10 11 12 13');
Irssi::settings_add_bool('misc', 'nickcolor_enable_prefix', 0);
Irssi::settings_add_bool('misc', 'nickcolor_enable_truncate', 0);
Irssi::settings_add_str('misc', 'nickcolor_prefix_text' => '- ');
Irssi::settings_add_int('misc', 'nickcolor_truncate_value' => 0);
Irssi::command_bind('color', 'cmd_color');

Irssi::signal_add('message public', 'sig_public');
Irssi::signal_add('message own_public', 'sig_me');
Irssi::signal_add('message irc action', 'sig_action_public');
Irssi::signal_add('message irc own_action', 'sig_action_me');
Irssi::signal_add('event nick', 'sig_nick');
