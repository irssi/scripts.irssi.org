use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Irssi::Irc;

$VERSION = '1.0';
%IRSSI = (
    authors     => 'Taneli Kaivola',
    contact     => 'dist@sci.fi',
    name        => 'Extended events',
    description => 'Expand "event mode" and emit "event mode {channel,user,server} *"',
    license     => 'GPLv2',
    url         => 'http://scripts.irssi.de',
    changed     => 'Mon May 20 04:04:47 EEST 2002',
);

sub event_mode {
  my($server,$args,$nick,$addr)=@_;
  my($target,$modes,$modeparms)=split(" ",$args,3);
  my(@modeparm)=split(/ /,$modeparms);
  my($target_type)="other";
  my($chan);
  my($modetype)="";
  my($pos)=0;

  if($target =~ /^#/) {
    $chan=$server->channel_find($target);
    $target_type="channel";
  }

  #emit $chan $mode $param
  if($target_type eq "channel") {
    foreach my $mode (split(//,$modes)) {
      if($mode eq "+" || $mode eq "-") {
        $modetype=$mode;
      } elsif($mode =~ /[vbkeIqhdOo]/ || ($mode eq "l" && $modetype eq "+")) { # Thanks friends.pl
        Irssi::signal_emit("event mode $target_type ".$modetype.$mode,$chan,$nick,$modeparm[$pos]);
        $pos++;
      } else {
        Irssi::signal_emit("event mode $target_type ".$modetype.$mode,$chan,$nick);
      }
    }
  } else {
    # Some user/server/other? mode
    # print "Target: [$target] Modes: [$modes] Modeparms: [$modeparms]";
  }
}
Irssi::signal_add_last("event mode",\&event_mode);

# Signals you can catch after loading this script:
# "event mode channel {+o,-o,+v,-v,+b,-b,+k,+e,-e,+I,-I,+q,-q,+h,-h,+d,-d,+O,-O,+l}"
# "event mode user {}" (Maybe soon)
# "event mode server {}" (Maybe soon)
