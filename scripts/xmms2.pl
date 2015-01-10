# XMMS/InfoPipe script for the Irssi client. You need a few things
# installed before this script will work...
#    1) Irssi,          http://irssi.org/
#    2) XMMS,           http://www.xmms.org/
#    3) InfoPipe,       http://www.beastwithin.org
#                       /users/wwwwolf/code/xmms/infopipe.html
#
# xmms2.pl is a version of xmms.pl slightly modified by Sir Robin,
# sir@robsku.cjb.net / http://robsku.cjb.net/
#
# The script now outputs by default to the active window, instead of
# status window. Also removed percentage meter as it didn't work. Only
# two lines were modified and the original lines still exist, just
# commented out.
#
# If you have trouble installing any of these, consult the READMEs that
# come with the software, thank you.
#
# Fixed a few vital things adviced by kodgehopper at netscape dot net.
# Very appreciated as I had no chance of testing a few of these things
# myself. I hope everything works as it should now.
#
# Visit http://scripts.irssi.de/
#
# simon at blueshell dot dk
use Irssi;
use vars qw($VERSION %IRSSI);
use strict;

$VERSION = '1.1.3+1';
%IRSSI = (
  authors     => 'simon',
  contact     => 'simon\@blueshell.dk',
  name        => 'XMMS-InfoPipe Script',
  description => 'Returns XMMS-InfoPipe data',
  license     => 'Public Domain',
  url         => 'http://irssi.dk/',
  changed     => 'Mon Nov 27 18:00:00 CET 2006',
  commands    => '/np',
  note        => 'Make sure InfoPipe is configured!'
);

sub cmd_xmms {
  my ($args, $server, $target) = @_;
  $args =~ s/\s+$//; #fix unneeded whitespaces after output dest.

  my (@t, $t, $ttotal, @pos, $pos, $postotal, $title);
  open xmms, "<", '/tmp/xmms-info' || die; # if nothing happens, it probably
                                      # failed here!

  while(<xmms>) {
    if(/^Time: (.*)$/) {
      @t = split(/:/, $1);
      $t = $1;
      $t =~ s/^([0-9]*):([0-9]{2})$/\1m\2s/; # convert to nice format
      $ttotal = $t[0] + $t[1]*60;
    }
    if(/^Position: (.*)$/) { 
      @pos = split(/:/, $1);
      $postotal = $pos[0] + $pos[1]*60;
    }
    if(/^Title: (.*)$/) { $title = $1; }
  }
  close xmms;

  if(!$ttotal || !$postotal) {
    Irssi::print "An error occurred. Check if XMMS is running and your";
    Irssi::print "InfoPipe module is running properly. If not, read how";
    Irssi::print "to get these up and running by reading the script source";
    die;
  }

  $pos = sprintf("%.0f", $postotal / $ttotal * 100); # calc. position
# my $output = "np: $title ($pos% of $t)";
  my $output = "np: $title ($t)";
  $output =~ s/[\r\n]/ /g; # remove newline characters
  if(!$server || !$server->{connected}) { # are we even connected?
    Irssi::print $output;
    return
  }
  if($args) { $server->command("msg $args $output"); }
  else { Irssi::active_win()->command('say ' . $output); }
# else { Irssi::print $output; }
}

Irssi::command_bind('np', 'cmd_xmms');
