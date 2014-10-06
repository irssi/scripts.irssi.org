use strict;
use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '1.0';
%IRSSI = (
    authors     => 'Daniel Dyla',
    contact     => 'dyladan@gmail.com',
    name        => 'nick shadow',
    description => 'This script changes the message color for certain nicks. '.
                   'Use it to hilight nicks you want to watch or darken nicks '.
                   'you want to more easily ignore',
    license     => 'Public Domain',
);

# The command syntax and much of the logic
# is taken directly from nickcolor.pl
# written by Timo Sirainen and Ian Peters


my %saved_colors;
my %session_colors = {};
my @colors = qw/2 3 4 5 6 7 9 10 11 12 13/;

sub sig_printtext {
    my ($server, $data, $nick, $address) = @_;
    my ($target, $text) = split(/ :/, $data, 2);
    if (!$saved_colors{$nick}) {return undef;};
    Irssi::signal_stop();
    Irssi::signal_remove('event privmsg', 'sig_printtext');
    Irssi::signal_emit('event privmsg', $server, $target." :".color_string($text,$saved_colors{$nick}), $nick, $address);
    Irssi::signal_add('event privmsg', 'sig_printtext');
}

sub color_string {
    my ($string, $color) = @_;
    my $newstr = "\003";
    $newstr .= sprintf("%02d", $color);
    $newstr .= $string;
    return $newstr;
}


sub load_colors {
  open COLORS, "$ENV{HOME}/.irssi/shadow_saved_colors";

  while (<COLORS>) {
    # I don't know why this is necessary only inside of irssi
    my @lines = split "\n";
    foreach my $line (@lines) {
      my($nick, $color) = split ":", $line;
      $saved_colors{$nick} = $color;
    }
  }

  close COLORS;
}

sub save_colors {
  open COLORS, ">$ENV{HOME}/.irssi/shadow_saved_colors";

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

sub cmd_shadow {
  my ($data, $server, $witem) = @_;
  my ($op, $nick, $color) = split " ", $data;

  $op = lc $op;

  if (!$op) {
    Irssi::print ("No operation given");
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
      Irssi::print (chr (3) . "$saved_colors{$nick}$nick" .
		    chr (3) . "1 ($saved_colors{$nick})");
    }
  } elsif ($op eq "preview") {
    Irssi::print ("\nAvailable colors:");
    foreach my $i (2..14) {
      Irssi::print (chr (3) . "$i" . "Color #$i");
    }
  }
}

load_colors();

Irssi::command_bind('shadow', 'cmd_shadow');

Irssi::signal_add('event nick', 'sig_nick');
Irssi::signal_add('event privmsg', 'sig_printtext');

# vim:set ts=4 sw=4 et:
