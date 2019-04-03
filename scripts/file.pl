use strict;
use vars qw($VERSION %IRSSI);
use Getopt::Long qw/GetOptionsFromString/;

my $help = <<EOF;
Usage: (all on one line)
/file [-raw] [-command]
      [-msg [target]] [-notice [target]] 
      [-prefix "text"] [-postfix "text"]
      filename

-raw: output contents of file as raw irc data
-command: run contents of file as irssi commands
-msg: send as messages to active window (default) or target
-notice: send as notices to active window or target

-prefix: add "text" in front of output
-postfix: add "text" after output

-echo print contents of file to active window
EOF

$VERSION = 1.1;
%IRSSI = (
   authors     => "David Leadbeater",
   name        => "file.pl",
   description => "A command to output content of files in various ways",
   license     => "GNU GPLv2 or later",
   url         => "http://irssi.dgl.cx/"
);

Irssi::command_bind('file', sub {
   my $data = shift;

   if($data eq 'help') {
      print $help;
      return;
   }
   
   my($type, $target, $prefix, $postfix, $echo);

   $type    = 'msg';
   $target  = '*';
   $prefix  = '';
   $postfix = '';

   my ($raw,$command,$msg,$notice,$filename);

   my ($ret, $args) = GetOptionsFromString($data,
         'raw' => \$raw,
         'command' => \$command,
         'msg:s' => \$msg,
         'notice:s' => \$notice,
         'prefix=s' => \$prefix,
         'postfix=s' => \$postfix,
         'echo' => \$echo,
      );
   $filename = $$args[-1];
   $type ='raw' if (defined $raw);
   $type ='command' if (defined $command);
   $type ='echo' if (defined $echo);
   if (defined $notice) {
      $type ='notice';
      if ($notice ne '') {
         $target = $notice;
      }
   }
   if (defined $msg) {
      $type ='msg';
      if ($msg ne '') {
         $target = $msg;
      }
   }

   # or do borrowed from one of juerd's scripts (needs 5.6 though)
   open(FILE, "<", $filename) or do {
      print "Error opening '$filename': $!";
      return;
   };

   while(<FILE>) {
      chomp;

      if($type eq 'raw') {
         Irssi::active_server->send_raw($prefix . $_ . $postfix);
      }elsif($type eq 'command') {
         Irssi::active_win->command($prefix . $_ . $postfix);
      }elsif($type eq 'echo') {
         Irssi::active_win->print($prefix . $_ . $postfix);
      }else{
         Irssi::active_win->command("$type $target $prefix$_$postfix");
      }
   }

   close FILE;

} );

# little known way to get -options to tab complete :)
Irssi::command_set_options('file','raw command prefix postfix msg notice echo');

# vim:set ts=3 sw=3 expandtab:
