use strict;
use vars qw($VERSION %IRSSI);

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

-echo abuses a bug in the script and is useful for testing
EOF

$VERSION = 1.0;
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
   
   my($type, $target, $prefix, $postfix);

   $type    = 'msg';
   $target  = '*';
   $prefix  = '';
   $postfix = '';

   while($data =~ s/^-([^ ]+) //g) {
      last if $data eq '-';

      if($1 eq 'msg' || $1 eq 'notice') {
         $type = $1;
         next unless $data =~ / /; # >1 params left
         $data =~ s/^([^ ]+) //;
         next unless $1;
         $target = $1;
      }elsif($1 eq 'prefix') {
         $data =~ s/^(?:\"([^"]+)\"|([^ ]+)) //;
         $prefix = $1 || $2 . ' ';
      }elsif($1 eq 'postfix') {
         $data =~ s/^(?:\"([^"]+)\"|([^ ]+)) //;
         $postfix = ' ' . $1 || $2;
      }else{ # Other options are automatic
         $type = $1;
      }
   }

   # or do borrowed from one of juerd's scripts (needs 5.6 though)
   open(FILE, "<", $data) or do {
      print "Error opening '$data': $!";
      return;
   };

   while(<FILE>) {
      chomp;

      if($type eq 'raw') {
         Irssi::active_server->send_raw($prefix . $_ . $postfix);
      }elsif($type eq 'command') {
         Irssi::active_win->command($prefix . $_ . $postfix);
      }else{
         Irssi::active_win->command("$type $target $prefix$_$postfix");
      }
   }

   close FILE;

} );

# little known way to get -options to tab complete :)
Irssi::command_set_options('file','raw command prefix postfix msg notice');

