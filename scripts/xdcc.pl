#!/usr/bin/perl -w

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";

%IRSSI = (
  authors     => 'Julie LaLa',
  contact     => 'ryz@asdf.us',
  name        => 'xdcc.pl',
  description => 'Run an XDCC file server from irssi.',
  license     => 'Jollo LNT license',
  url         => 'http://asdf.us/xdcc/',
  changed     => 'Tue Jan 21 09:57:55 EST 2015',
);

my @files;
my @queue;
my @channels;

my $queue_max = 99;
my $bother_delay = 9999;

my $irssidir = Irssi::get_irssi_dir();
my $dcc_upload_path = Irssi::settings_get_str('dcc_upload_path');
my $sending = 0;
my $disabled = 0;
my $timeout = undef;
my $current_dcc = undef;
my $stats = {
  files_sent => 0,
  files => {},
  users => {},
};

my $help_local = <<EOF;

Usage:
/XDCC [-add <filename> <description>] [-del <id>] [-list] [-stats] [-help]

-add:     Add a file to our XDCC server
-del:     Remove a file from the offerings
-list:    Display the XDCC list (default)
-reset:   Reset the file list and the queue
-stats:   Statistics for this session
-enable:  Enable/disable the XDCC server
-trust:   Trust ops from a channel to upload files.
-help:    Display this help.

Examples:
/xdcc -add sally.gif Jollo in his native habitat :)
/xdcc -add jollo.mp3 Distant cry of the Jollo, 5:43 am
/xdcc -del 1

For client commands, type:
/ctcp <nickname> XDCC help

Requests are queued, only one file will be sent at a time.
Filenames must not contain spaces.
EOF

my $help_remote = <<EOF;
[%_XDCC%_] v$VERSION
/ctcp %nick XDCC %_list%_
/ctcp %nick XDCC %_get%_ 1
/ctcp %nick XDCC %_batch%_ 2-4       # request multiple files
/ctcp %nick XDCC %_remove%_ 3        # remove yourself from queue
/ctcp %nick XDCC %_cancel%_          # cancel the current transfer
/ctcp %nick XDCC %_queue%_
/ctcp %nick XDCC %_stats%_
/ctcp %nick XDCC %_help%_
/ctcp %nick XDCC %_about%_
EOF

my $help_control = <<EOF;
 
To upload a file, %_/dcc send %nick filename%_
/ctcp %nick XDCC %_describe%_ 5      # Set the description for a file
/ctcp %nick XDCC %_delete%_ 5        # Delete something you uploaded.
EOF

my $help_about = <<EOF;
[%_XDCC%_] xdcc.pl plugin for irssi
[%_XDCC%_] more info: $IRSSI{url}
EOF

Irssi::theme_register([
  'xdcc_sending_file',   '[%_XDCC%_] Sending the file [$0] %_$2%_ to %_$1%_',
  'xdcc_no_files',       '[%_XDCC%_] No files offered',
  'xdcc_print_file',     '[%_XDCC%_] [%_$0%_] %_$1%_ ... %_$2%_',
  'xdcc_queue_empty',    '[%_XDCC%_] The queue is currently empty',
  'xdcc_hr',             '[%_XDCC%_] ----',
  'xdcc_print_queue',    '[%_XDCC%_] $0. $1 - [$2] $3',
  'xdcc_file_not_found', '[%_XDCC%_] File does not exist',
  'xdcc_added_file',     '[%_XDCC%_] Added [$0] $1',
  'xdcc_removed_file',   '[%_XDCC%_] Removed [$0] $1',
  'xdcc_reset',          '[%_XDCC%_] Reset!',
  'xdcc_log',            '[%_XDCC%_] $0',
  'xdcc_stats',          '[%_XDCC%_] $0 ... %_$1%_',
  'xdcc_autoget_tip',    '[%_XDCC%_] Tip: in irssi, type %_/set dcc_autoget ON%_',

  'xdcc_help', '$0',
  'xdcc_version', $help_about,
  'loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 version $1 by $2.'
]);

my $messages = {
  'queue_is_full'      => "[%_XDCC%_] The queue is currently full.",
  'queue_is_empty'     => "[%_XDCC%_] The queue is currently empty.",
  'not_in_queue'       => "[%_XDCC%_] Didn't find you in the queue.",
  'no_files_offered'   => "[%_XDCC%_] Sorry, there's no warez today",
  'file_not_found'     => "[%_XDCC%_] File not found",
  'illegal_index'      => "[%_XDCC%_] Bad index for batch request.",
  'specify_number'     => "[%_XDCC%_] Please specify a number from 1-%d.",
  'specify_range'      => "[%_XDCC%_] Please specify a range from 1-%d.",

  'file_entry'         => '[%_XDCC%_] [%d] %s ... %s',
  'file_count'         => '[%_XDCC%_] %d file%s',
  'file_help_get'      => '[%_XDCC%_] Type %_/ctcp %nick xdcc get N%_ to request a file',

  'in_queue'           => '[%_XDCC%_] You are #%d in queue. Requested [%d] %s',
  'enqueued_count'     => '[%_XDCC%_] Added %d files to queue',
  'queue_length'       => '[%_XDCC%_] %d request%s in queue',
  'sending_file'       => '[%_XDCC%_] Sending you [%d] %s ...!',
  'file_help_send'     => '[%_XDCC%_] Type %_/dcc get %nick%_ to accept the file',

  'xdcc_added_file'    => '[%_XDCC%_] Added file [%_%d%_] %s',
  'xdcc_deleted_file'  => '[%_XDCC%_] Deleted file [%_%d%_] %s',
  'xdcc_described'     => '[%_XDCC%_] Updated description for [%_%d%_] %s',

  'xdcc_final_warning' => '[%_XDCC%_] This is your last warning!',
  'xdcc_inactive'      => '[%_XDCC%_] The DCC transfer has been cancelled for inactivity.',
  'xdcc_removed'       => '[%_XDCC%_] Your request has been removed.',
  'xdcc_file_removed'  => '[%_XDCC%_] The file you requested [%d] has been removed.',
  'xdcc_autoget_tip'   => '[%_XDCC%_] Tip: in irssi, type %_/set dcc_autoget ON%_',
  'xdcc_cancelled'     => '[%_XDCC%_] File transfer cancelled',

  'xdcc_stats'         => '[%_XDCC%_] %s ... %_%s%_',
  'xdcc_log'           => "[%_XDCC%_] %s",
  'xdcc_hr'            => "[%_XDCC%_] ----",
  'xdcc_help'          => $help_remote,
  'xdcc_help_control'  => $help_control,
  'xdcc_about'         => $help_about,
  'xdcc_version'       => "[%_XDCC%_] v$VERSION",
};

# Public XDCC request API
sub ctcp_reply {
  my ($server, $data, $nick, $address, $target) = @_;

  my ($ctcp, $cmd, $index, $desc) = split (" ", lc($data), 4);

  if ($disabled || $ctcp ne "xdcc") { return; }
     if ($cmd eq "get")      { xdcc_enqueue($server, $nick, $index) }
  elsif ($cmd eq "send")     { xdcc_enqueue($server, $nick, $index) }
  elsif ($cmd eq "batch")    { xdcc_batch($server, $nick, $index) }
  elsif ($cmd eq "info")     { xdcc_info_remote($server, $nick, $index) }
  elsif ($cmd eq "remove")   { xdcc_remove($server, $nick, $index) }
  elsif ($cmd eq "delete")   { xdcc_delete($server, $nick, $index) }
  elsif ($cmd eq "cancel")   { xdcc_cancel($server, $nick) }
  elsif ($cmd eq "queue")    { xdcc_queue($server, $nick) }
  elsif ($cmd eq "list")     { xdcc_list($server, $nick) }
  elsif ($cmd eq "stats")    { xdcc_stats_remote($server, $nick) }
  elsif ($cmd eq "describe") { xdcc_describe($server, $nick, $index, $desc) }
  elsif ($cmd eq "version")  { xdcc_message($server, $nick, 'xdcc_version') }
  elsif ($cmd eq "help")     { xdcc_help($server, $nick) }
  elsif ($cmd eq "about")    { xdcc_message($server, $nick, 'xdcc_about') }
  else                       { xdcc_list($server, $nick) }

  Irssi::signal_stop();
}
sub xdcc_message {
  my ($server, $nick, $msgname, @params) = @_;
  my (@msgs) = split (/\n/, $messages->{$msgname});
  for my $msg (@msgs) {
    $msg =~ s/%_/\x02/g;
    $msg =~ s/%-/\x03/g;
    $msg =~ s/%nick/$server->{nick}/g;
    $msg = sprintf $msg, @params;
    $server->send_message( $nick, $msg, 1 );
  }
}
sub xdcc_help {
  my ($server, $nick) = @_;
  xdcc_message($server, $nick, 'xdcc_help');
  if (xdcc_is_trusted($server, $nick)) {
    xdcc_message($server, $nick, 'xdcc_help_control');
  }
}
sub xdcc_enqueue {
  my ($server, $nick, $index, $quiet) = @_;
  my $id = int $index;
  $id -= 1;

  my $request = {
    server => $server,
    nick => $nick,
    id => $id
  };

  if (scalar @files == 0) {
    xdcc_message( $server, $nick, 'no_files_offered' );
    return;
  }
  if ($index < 0 || $index > scalar @files) {
    xdcc_message( $server, $nick, 'file_not_found' );
    xdcc_message( $server, $nick, 'specify_range', scalar @files );
    return;
  }
  if (! $sending && @queue == 0) {
    xdcc_send($request);
    return;
  }
  elsif (@queue > $queue_max) {
    xdcc_message( $server, $nick, 'queue_is_full' );
    return;
  }
  push(@queue, $request);
  if (! $quiet) { xdcc_queue($server, $nick); }
}
sub xdcc_batch {
  my ($server, $nick, $index) = @_;
  if (scalar @files == 0) {
    xdcc_message( $server, $nick, 'no_files_offered' );
    return;
  }
  if ($index !~ /-/) {
    xdcc_message( $server, $nick, 'illegal_index' );
    xdcc_message( $server, $nick, 'specify_range', scalar @files );
    return;
  }
  my ($from, $to) = split(/-/, $index, 2);
  $from = int $from;
  $to = int $to;
  if ($from >= $to || $from < 1 || $to < 1 || $from > @files || $to > @files) {
    xdcc_message( $server, $nick, 'illegal_index' );
    xdcc_message( $server, $nick, 'specify_range', scalar @files );
    return;
  }
  for (my $i = $from; $i <= $to; $i++) {
    xdcc_enqueue($server, $nick, $i, 1);
  }
  xdcc_message($server, $nick, 'enqueued_count', $to-$from);
  xdcc_message($server, $nick, 'xdcc_autoget_tip');
}
sub xdcc_remove {
  my ($server, $nick, $index) = @_;
  my $id = int $index;
  $id -= 1;

  my $removed;
  for (my $n = @queue; $n >= 0; --$n) {
    if ($queue[$n]->{nick} eq $nick && ($id == -1 || $queue[$n]->{id} == $id)) {
      $removed = splice(@queue, $n, 1);
    }
  }
  if ($removed) {
    xdcc_message( $server, $nick, 'xdcc_removed' );
  }
  else {
    xdcc_message( $server, $nick, 'not_in_queue' );
  }
}
sub xdcc_cancel {
  my ($server, $nick) = @_;
  if ($current_dcc && $current_dcc->{nick} eq $nick) {
    xdcc_message( $server, $nick, 'xdcc_cancelled' );
    $current_dcc->destroy();
  }
}
sub xdcc_delete {
  my ($server, $nick, $index, $desc) = @_;
  my $id = int $index;
  $id -= 1;
  if (xdcc_is_trusted($server, $nick)) {
    my $file = xdcc_del($index);
    if ($file) {
      xdcc_message( $server, $nick, 'xdcc_deleted_file', $file->{id}+1, $file->{fn} );
    }
  }
}
sub xdcc_describe {
  my ($server, $nick, $index, $desc) = @_;
  my $id = int $index;
  $id -= 1;
  if (xdcc_is_trusted($server, $nick)) {
    my $file = $files[$id];
    $file->{desc} = $desc;
    xdcc_message( $server, $nick, 'xdcc_described', $file->{id}+1, $file->{'fn'} );
  }
}
sub xdcc_info_remote {
  my ($server, $nick, $index) = @_;
  my $info = xdcc_get_info($index);
  if (! $info) { return; }
  xdcc_message( $server, $nick, 'xdcc_stats', '   #', $info->{id} );
  xdcc_message( $server, $nick, 'xdcc_stats', 'name', $info->{name} );
  xdcc_message( $server, $nick, 'xdcc_stats', 'nick', $info->{nick} );
  xdcc_message( $server, $nick, 'xdcc_stats', 'date', $info->{date} );
  xdcc_message( $server, $nick, 'xdcc_stats', 'size', $info->{size} );
  xdcc_message( $server, $nick, 'xdcc_stats', 'desc', $info->{desc} );
}
sub xdcc_info {
  my ($index) = @_;
  my $info = xdcc_get_info($index);
  if (! $info) { return; }
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_stats', '   #', $info->{id} );
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_stats', 'name', $info->{name} );
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_stats', 'nick', $info->{nick} );
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_stats', 'date', $info->{date} );
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_stats', 'size', $info->{size} );
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_stats', 'desc', $info->{desc} );
}
sub xdcc_get_info {
  my ($index) = @_;
  my $id = int $index;
  return if ($id < 1 || $id > scalar @files);
  $id -= 1;
  my $file = $files[$id];

  my @stats = stat($file->{path});
  my $size = int $stats[7];
  my $date = $stats[9];

  my ($m,$h,$d,$n,$y) = (localtime $date)[1..5];
  my @months = qw[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec];
  my $ymd = sprintf "%d-%s-%d %d:%02d", $d, $months[$n], 1900+$y, $h, $m;

  my $bytes;
  if ($size < 1024) { $bytes = $size + " b." }
  elsif ($size < 1024*1024) { $bytes = int($size/1024) + " kb." }
  elsif ($size < 1024*1024*1024) { $bytes = sprintf("%0.1d",int((10*$size)/(1024*1024))) + " kb." }

  return {
    id => $id+1,
    name => $file->{fn},
    nick => $file->{nick},
    date => $ymd,
    size => $bytes,
    desc => $file->{desc},
  }
}
sub xdcc_list {
  my ($server, $nick) = @_;
  if (scalar @files == 0) {
    xdcc_message( $server, $nick, 'no_files_offered' );
    return;
  }
  my ($msg, $file);
  for (my $n = 0; $n < @files ; ++$n) {
    xdcc_message( $server, $nick, 'file_entry', $n+1, $files[$n]->{fn}, $files[$n]->{desc} );
  }
  # xdcc_message( $server, $nick, 'file_count', scalar @files, scalar @files == 1 ? "" : "s" );
  xdcc_message( $server, $nick, 'file_help_get');
}
sub xdcc_queue {
  my ($server, $nick) = @_;
  if (scalar @queue == 0) {
    xdcc_message( $server, $nick, 'queue_is_empty' );
    return
  }
  my $msg;
  for (my $n = 0; $n < @queue; ++$n) {
    if ($queue[$n]->{nick} eq $nick) {
      xdcc_message( $server, $nick, 'in_queue', $n+1, $queue[$n]->{id}+1, $files[$queue[$n]->{id}]->{fn} )
      # break
    }
  }
  xdcc_message( $server, $nick, 'queue_length', scalar @queue, scalar @queue == 1 ? "" : "s" )
}
sub xdcc_stats_remote {
  my ($server, $nick) = @_;
  xdcc_message( $server, $nick, 'xdcc_stats', "xdcc.pl version", $VERSION);

  if (xdcc_is_trusted($server, $nick)) {
    my @channel_names = map { $_->{'name'} } @channels;
    xdcc_message( $server, $nick, 'xdcc_stats', 'trusted channels', join(' ', @channel_names));
  }
  xdcc_message( $server, $nick, 'xdcc_stats', "files sent", $stats->{files_sent});
  xdcc_message( $server, $nick, 'xdcc_hr');

  xdcc_message( $server, $nick, 'xdcc_log', 'top files');
  map  { xdcc_message( $server, $nick, 'xdcc_stats', $_->[0], $_->[1]) }
  sort { $b->[1] <=> $a->[1] }
  map  { [$_, $stats->{files}->{$_}] }
  keys %{ $stats->{files} };
  xdcc_message( $server, $nick, 'xdcc_hr');

  xdcc_message( $server, $nick, 'xdcc_log', 'top users');
  map  { xdcc_message( $server, $nick, 'xdcc_stats', $_->[0], $_->[1]) }
  sort { $b->[1] <=> $a->[1] }
  map  { [$_, $stats->{users}->{$_}] }
  keys %{ $stats->{users} };
  xdcc_message( $server, $nick, 'xdcc_hr');
}
sub xdcc_advance {
  if ($timeout) { Irssi::timeout_remove($timeout) }
  undef $timeout;
  undef $current_dcc;
  if (@queue == 0) { return; }
  my $request = shift @queue;
  xdcc_send($request);
}
sub xdcc_send {
  my ($request) = @_;
  my $server = $request->{server};
  my $nick = $request->{nick};
  my $id = $request->{id};
  my $file = $files[$id];
  my $path = $file->{path};
  my $fn = $file->{fn};
  xdcc_message( $server, $nick, 'sending_file', $id+1, $fn );
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_sending_file', $id, $nick, $fn);
  $server->command("/DCC send $nick $path");
  $sending = 1;
  $stats->{files_sent}++;
  $stats->{users}->{$nick} ||= 0;
  $stats->{users}->{$nick}++;
  $stats->{files}->{$fn} ||= 0;
  $stats->{files}->{$fn}++;
}

# XDCC command control
sub xdcc_report {
  if (scalar @files == 0) {
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_no_files');
  }
  else {
    for (my $n = 0; $n < @files ; ++$n) {
      Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_print_file', $n+1, $files[$n]->{fn}, $files[$n]->{desc});
    }
  }
  if (scalar @queue == 0) {
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_queue_empty');
  }
  else {
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_hr');
    for (my $n = 0; $n < @files ; ++$n) {
      Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_print_queue', $n+1, $queue[$n]->{nick}, $queue[$n]->{id}, $files[$queue[$n]->{id}-1]->{fn});
    }
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_hr');
  }
}
sub xdcc_stats {
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_stats', "xdcc.pl version", $VERSION);

  my @channel_names = map { $_->{'name'} } @channels;
  if (scalar @channel_names) {
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_stats', 'trusted channels', join(' ', @channel_names));
  }
  else {
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_stats', 'trusted channels', 'none');
  }
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_stats', "files sent", $stats->{files_sent});
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_hr');

  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_log', 'top files');
  map  { Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_stats', $_->[0], $_->[1]) }
  sort { $b->[1] <=> $a->[1] }
  map  { [$_, $stats->{files}->{$_}] }
  keys %{ $stats->{files} };
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_hr');

  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_log', 'top users');
  map  { Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_stats', $_->[0], $_->[1]) }
  sort { $b->[1] <=> $a->[1] }
  map  { [$_, $stats->{users}->{$_}] }
  keys %{ $stats->{users} };
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_hr');
}
sub xdcc_add {
  my ($path, $desc, $nick) = @_;
  if ($path !~ /^[\/~]/) {
    $path = $dcc_upload_path . "/" . $path;
  }
  if ($path =~ /^[~]/) {
    $path =~ s/^~//;
    $path = $ENV{"HOME"} . $path;
  }
  if (! -e $path) {
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_file_not_found');
    return 0;
  }

  my $fn = $path;
  $fn =~ s|^.*\/||;

  my $id = scalar @files;

  my $file = {
    id => $id,
    fn => $fn,
    path => $path,
    desc => $desc,
    nick => $nick,
  };

  push(@files, $file);

  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_added_file', $id+1, $fn);

  return $file;
}
sub xdcc_del {
  my ($id) = @_;
  $id = (int $id) - 1;
  if ($id < 0 || $id > scalar @files) {
    xdcc_log( 'No file with index $id' );
    return 0;
  }
  my $file = $files[$id];
  my $req;

  splice(@files, $id, 1);

  for (my $n = $#queue; $n >= 0; --$n) {
    if ($queue[$n]->{id} == $id) {
      $req = $queue[$n];
      splice(@queue, $n, 1);
      xdcc_message( $req->{server}, $req->{nick}, 'xdcc_file_removed', $n );
    }
    elsif ($queue[$n]->{id} > $id) {
      --$queue[$n]->{id};
    }
  }

  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_removed_file', $id+1, $file->{fn});
  return $file;
}
sub xdcc_reset {
  @files = ();
  @queue = ();
  if ($current_dcc) { $current_dcc->destroy() }
  $sending = 0;
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_reset');
}
sub xdcc_log {
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_log', $_[0]);
}

# Trust ops from certain channels
sub xdcc_trust {
  my ($channel_name) = @_;
  my $channel = Irssi::channel_find($channel_name);
  if ($channel) {
    for my $c (@channels) {
      if ($c->{'name'} eq $channel->{'name'}) {
        xdcc_log("Already trusting ops on $channel_name");
        return;
      }
    }
    xdcc_log("Trusting ops on $channel_name");
    # Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_autoget_tip');
    push(@channels, $channel);
  }
  else {
    xdcc_log("Couldn't find channel $channel_name (join it?)");
  }
}
sub xdcc_distrust {
  my ($channel_name) = @_;
  for (my $i = $#channels; $i >= 0; $i--) {
    if ($channels[$i]->{name} == $channel_name) {
      my $channel = $channels[$i];
      splice(@channels, $i, 1);
      xdcc_log("Stopped trusting $channel_name");
      return
    }
  }
  xdcc_log("Couldn't find channel $channel_name");
}
sub xdcc_is_trusted {
  my ($server, $nick) = @_;
  my $user;
  for my $channel (@channels) {
    if ($channel->{server}->{'name'} ne $server->{'name'}) {
      next;
    }
    $user = $channel->nick_find($nick);
    if ($user && $user->{op}) {
      return 1;
    }
  }
  return 0;
}

sub xdcc {
  my ($data, $server) = @_;
  my ($cmd, $fn, $desc) = split (" ", $data, 3);

  $cmd = lc($cmd);
  $cmd =~ s/^-//;

     if ($cmd eq "add")      { xdcc_add($fn, $desc, $server->{nick}) }
  elsif ($cmd eq "del")      { xdcc_del($fn) }
  elsif ($cmd eq "info")     { xdcc_info($fn) }
  elsif ($cmd eq "list")     { xdcc_report() }
  elsif ($cmd eq "reset")    { xdcc_reset() }
  elsif ($cmd eq "stats")    { xdcc_stats() }
  elsif ($cmd eq "enable")   { $disabled = 0 }
  elsif ($cmd eq "disable")  { $disabled = 1 }
  elsif ($cmd eq "trust")    { xdcc_trust($fn) }
  elsif ($cmd eq "distrust") { xdcc_distrust($fn) }
  elsif ($cmd eq "help")     { Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_help', $help_local) }
  elsif ($cmd eq "version")  { xdcc_version() }
   else                      { xdcc_report() }
}

# DCC management
sub dcc_created {
  my ($dcc) = @_;
  # Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_log', 'dcc created');
  if (lc $dcc->{'type'} eq "send") {
    if ($timeout) { Irssi::timeout_remove($timeout) }
    $timeout = Irssi::timeout_add_once($bother_delay, \&xdcc_bother, { dcc => $dcc, times => 1 });
    # xdcc_log("sending file..");
    $current_dcc = $dcc;
  }
  elsif (lc $dcc->{'type'} eq "get" && scalar @channels) {
    if (xdcc_is_trusted($dcc->{'server'}, $dcc->{'nick'})) {
      # all is well...
    }
    else {
      $dcc->destroy();
    }
  }
}
sub xdcc_bother {
  my ($data) = @_;
  my $dcc = $data->{dcc};
  my $times = $data->{times};
  if ($times == 3) {
    xdcc_message($dcc->{server}, $dcc->{nick}, 'xdcc_final_warning');
  }
  if ($times <= 3) {
    xdcc_message($dcc->{server}, $dcc->{nick}, 'file_help_send');
    $data->{times}++;
    $timeout = Irssi::timeout_add_once($bother_delay, \&xdcc_bother, $data);
  }
  else {
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_log', 'Send to ' . $dcc->{nick} . ' timed out.');
    xdcc_message($dcc->{server}, $dcc->{nick}, 'xdcc_inactive');
    xdcc_message($dcc->{server}, $dcc->{nick}, 'xdcc_autoget_tip');
    $dcc->destroy();
    return
  }
}
sub dcc_destroyed {
  # Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_log', 'dcc destroyed');
  my ($dcc) = @_;
  if (lc $dcc->{'type'} eq "send") {
    $sending = 0;
    xdcc_advance();
  }
  elsif (lc $dcc->{'type'} eq "get" && xdcc_is_trusted($dcc->{'server'}, $dcc->{'nick'})) {
    my $file = xdcc_add($dcc->{'arg'}, "uploaded by $dcc->{'nick'}", $dcc->{'nick'});
    if ($file) {
      xdcc_message($dcc->{server}, $dcc->{nick}, 'xdcc_added_file', $file->{'id'}+1, $file->{'fn'});
    }
  }
}
sub dcc_connected {
#  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_log', 'dcc connected');
  my ($dcc) = @_;
  if (lc $dcc->{'type'} eq "send" && $timeout) {
    Irssi::timeout_remove($timeout);
    undef $timeout;
  }
}
sub dcc_rejecting {
#  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_log', 'dcc rejecting');
}
sub dcc_closed {
#  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'xdcc_log', 'dcc closed');
}

# listen for xdcc end/cancel/close
Irssi::signal_add('dcc created',      'dcc_created');
Irssi::signal_add('dcc destroyed',    'dcc_destroyed');
Irssi::signal_add('dcc connected',    'dcc_connected');
Irssi::signal_add('dcc rejecting',    'dcc_rejecting');
Irssi::signal_add('dcc closed',       'dcc_closed');
Irssi::signal_add('default ctcp msg', 'ctcp_reply');
Irssi::command_bind('xdcc', 'xdcc');
Irssi::command_set_options('xdcc','add del list stats enable disable reset trust distrust help version');
Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
