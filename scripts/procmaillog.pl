use strict;
use Irssi;

use Encode qw(decode);
use IO::Handle;
use Log::Procmail;
use MIME::Words qw(decode_mimewords);
use Time::HiRes qw(usleep);

our $VERSION = '2.02';
our %IRSSI = (
    authors     => 'Cyprien Debu',
    contact     => 'frey@notk.org',
    name        => 'procmaillog',
    description => 'Gets new mails from procmail.log file',
    license     => 'Public Domain',
    url         => '',
    changed     => '06-2014'
);

my $sn = $IRSSI{name};

Irssi::settings_add_level $sn, $sn.'_default_level', 'MSGS';
Irssi::settings_add_int   $sn, $sn.'_folder_pad', 15;
Irssi::settings_add_str   $sn, $sn.'_folders_color', '4,^error$';
Irssi::settings_add_str   $sn, $sn.'_folders_level', '';
Irssi::settings_add_str   $sn, $sn.'_folders_silent', 'spam';
Irssi::settings_add_str   $sn, $sn.'_logfile', '~/.procmail.log';
Irssi::settings_add_int   $sn, $sn.'_max_length', 90;
Irssi::settings_add_str   $sn, $sn.'_split_chars', ',;';
Irssi::settings_add_str   $sn, $sn.'_window', '(status)';

Irssi::theme_register([
    $sn.'_mail', '$0',
    $sn.'_crap', '{line_start}{hilight '.$sn.':} $0'
]);

sub print_help
{
  print( <<EOF

This script reads your procmail.log file and prints it in the form:
| folder-name | subject

Many options are available, see /set ${sn}:
- default_level: default level of printed messages
- folder_pad: padding added to the folder name if length(folder name) < folder_pad
- folders_color: semicolon-separated list of pairs of <color, regex>: the folders that match the regex will be colorized following the codes listed here: http://irssi.org/documentation/formats (mIRC colors)
  Example: 5,foo;8,bar -> colorize foo in red and bar in yellow
- folders_level: same behaviour as folders_color but with levels instead of color numbers. NOTICES,foo will print folders matching foo with a NOTICES level
- folders_silent: regex, folders you don't want to print
- logfile: path to your procmail.log (default: ~/.procmail.log)
- max_length: max length of the line
- split_chars: ,; by default, split characters used in folders_color and folders_level strings
  Change them if you use these characters in your folders names
- window: the target window name

Available subcommands: help, start, stop.

The script may fail at first launch if it doesn't find your procmail.log file, just set the option and do /${sn} start.
EOF
  );
}

my $child;

sub print_crap
{
  Irssi::printformat MSGLEVEL_CLIENTCRAP, $sn.'_crap', $_
    foreach @_;
}

sub print_error
{
  print_crap "\x034Error:\x03 ".shift, @_;
}

# Utility function to parse folders_color and folders_level options.
sub parse_option
{
  my $setting = shift;
  my ($s2, $s1) = split '', Irssi::settings_get_str($sn.'_split_chars');
  my %hash;

  foreach (split $s1, Irssi::settings_get_str($setting)) {
    my ($key, $rx) = split $s2;
    $hash{$key} = $rx if $rx;
  }

  return %hash;
}

sub colorize_folder
{
  my $folder = shift;
  my $border = "\x03";
  my %folders = parse_option $sn.'_folders_color';

  foreach (keys %folders) {
    return $border.$_.$folder.$border if ($folder =~ /$folders{$_}/);
  }

  $border = "\x02";
  return $border.$folder.$border;
}

sub format_folder
{
  my $folder = shift;
  my $folder_pad = Irssi::settings_get_int $sn.'_folder_pad';
  my $pad = $folder_pad - length $folder;
  my $padding = $pad > 0 ? ' ' x $pad : '';
  return colorize_folder($folder).$padding;
}

# Used in format_subject
sub decode_mime
{
  my $str = shift;
  my $decoded;

  foreach (decode_mimewords $str) {
    $decoded .= decode $_->[1] || 'US-ASCII',  $_->[0];
  }

  return $decoded;
}

sub format_subject
{
  my $str = shift;

  if (index($str, '=?') == -1)
  { # If no MIME encoding, choose between utf8 and latin-1
    my $utf8 = 0;

    foreach (split '', $str) {
      $utf8 = 1 if (ord == 0xc2 or ord == 0xc3);
    }

    $str = decode('ISO-8859-1', $str) unless $utf8;

    return $str;
  }

  my $tmp = substr $str, rindex($str, '=?');

  if (index($tmp, '?=') == -1)
  {
    if (not $tmp =~ /=\?[a-z0-9_-]+\?[bq]\?/i)
    { # Encoding pattern not complete
      $str = substr $str, 0, rindex($str, '=?');
    }
    elsif (my ($c) = ($tmp =~ /=\?\S+\?([bq])\?/i))
    { # Encoding complete, lacks '?=' or just '='
      if ($c =~ /q/i and index($str, '=', length($str)-2) != -1)
      { # Remove trailing '=' (beginning of new special character)
        $str = substr $str, 0, index($str, '=', length($str)-2)
      }
      $str .= ($str =~ /\?$/) ? '=' : '?=';
    }
  }

  eval { $str = decode_mime $str };

  if ($@) {
    chomp $@;
    print_error "Error while decoding subject: $@";
    $str = "\x034(error)\x03 " . $str;
  }

  return $str;
}

# Get the print level from folder name
sub get_level
{
  my $folder = shift;

  my $level = Irssi::settings_get_level $sn.'_default_level';
  return $level unless $folder;

  my %levels = parse_option $sn.'_folders_level';

  foreach (keys %levels) {
    $level = Irssi::level2bits $_ if ($folder =~ /$levels{$_}/);
  }

  return $level;
}

# Find the right window, build and print the line
sub printfmt
{
  my ($raw_folder, $raw_subject) = @_;

  my $level   = get_level      $raw_folder;
  my $folder  = format_folder  $raw_folder;
  my $subject = format_subject $raw_subject;

  my $line = "| $folder | $subject";
  my $max_length = Irssi::settings_get_int $sn.'_max_length';
  $line = substr($line, 0, $max_length) if ($max_length > 0);

  my $win_name = Irssi::settings_get_str $sn.'_window';
  my $window = Irssi::window_find_item $win_name;

  unless ($window) {
    print_error "Could not find window '$win_name'. Stopping.", "Please set ${sn}_window.";
    do_stop();
    return;
  }

  $window->printformat($level, $sn.'_mail', $line);
}

# Main loop
sub read_log
{
  my $args = shift;
  my ($log, $tagref) = @$args;

  my $rec = $log->next;

  unless ($rec) {
    if (defined $child) {
      # If $child is still running, we just got called too early
      # (the record is not fully written)
      return if (system("kill -0 $child &>/dev/null") == 0);

      # Our child was killed by something external
      print_error "Child killed. Stopping.";
      undef $child;
    }
    # Child killed, close the pipe
    Irssi::input_remove $$tagref;
    return;
  }

  my $folders_silent = Irssi::settings_get_str $sn.'_folders_silent';

  # We can get several mails in a row
  # Double braces to use next in a do-while loop
  do {{
    unless (ref $rec) {
      # If $rec is not a ref it is an error string
      printfmt "error", $rec;
      next;
    }
    next if ($folders_silent and $rec->folder =~ /$folders_silent/);
    printfmt $rec->folder, $rec->subject;
  }} while ($rec = $log->next);
}

sub do_start
{
  my $filename = Irssi::settings_get_str $sn.'_logfile';
  my ($logfile, @rest) = glob $filename;

  if ($#rest != -1) {
    print_crap "I found several files with the given filename ($filename).",
        "I will use $logfile.";
  }

  unless (-f $logfile and -r $logfile) {
    print_error "Could not find $filename, or file not readable.",
        "See /set ${sn}_logfile.";
    return;
  }

  my $log = Log::Procmail->new;
  my $wh = IO::Handle->new;

  pipe $log->fh, $wh;

  $log->errors(1);

  $log->fh->blocking(0);
  $wh->autoflush(1);

  $child = fork;

  if (not defined $child) {
    print_error "Can't fork. Aborting.";
    return;
  }

  if ($child > 0) { # parent
    Irssi::pidwait_add $child;
    my $tag;
    my @args = ($log, \$tag);
    $tag = Irssi::input_add fileno($log->fh), Irssi::INPUT_READ, \&read_log, \@args;
    return $logfile;
  } else { # child
    open STDOUT, '>&', $wh;
    open STDERR, '>&', $wh;
    exec qw(tail -fn0), $logfile;
  }
}

sub do_stop
{
  qx(kill $child);
  undef $child;
}

sub cmd_start
{
  if (defined $child) {
    print_crap "Already started, restarting...";
    do_stop();
    Irssi::timeout_add_once 200, \&cmd_start, undef;
    return;
  }

  my $win_name = Irssi::settings_get_str $sn.'_window';
  my $window = Irssi::window_find_item $win_name;

  unless ($window) {
    print_error "Could not find window '$win_name'. Aborting.", "Please set ${sn}_window.";
    return;
  }

  if (my $file = do_start) {
    print_crap "Started on window '$win_name' and file '$file'.";
  }
}

sub cmd_stop
{
  unless (defined $child) {
    print_crap "Not running.";
    return;
  }

  do_stop();
  print_crap "Stopped.";
}

sub UNLOAD
{
  do_stop() if $child;
}

# Subcommands handler
Irssi::command_bind $sn, sub {
  my ($data, $server, $item) = @_;
  $data =~ s/\s+$//g;
  Irssi::command_runsub $sn, $data, $server, $item;
};

# Subcommands
Irssi::command_bind "$sn help",  \&print_help;
Irssi::command_bind "$sn start", \&cmd_start;
Irssi::command_bind "$sn stop",  \&cmd_stop;

# Help command handler
Irssi::command_bind 'help', sub {
  $_[0] =~ s/\s+$//g;
  return unless $_[0] eq $sn;
  print_help;
  Irssi::signal_stop;
};

# Timeout here to print our message after the loading notice
Irssi::timeout_add_once 200, \&cmd_start, undef;

