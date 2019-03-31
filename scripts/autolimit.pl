use strict;
use Irssi 20010920.0000 ();
use vars qw($VERSION %IRSSI);
$VERSION = "1.01";
%IRSSI = (
    authors     => 'David Leadbeater',
    contact     => 'dgl@dgl.cx',
    name        => 'autolimit',
    description => 'does an autolimit for a channel',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.dgl.cx/',
);

my $sname=$IRSSI{name};
my $channel;
my $offset;
my $tolerence;
my $time;
my $timeouttag;

sub sig_setup_changed {
   $channel=Irssi::settings_get_str($sname.'_channel');
   $offset=Irssi::settings_get_int($sname.'_offset');
   $tolerence=Irssi::settings_get_int($sname.'_tolerence');
   $time=Irssi::settings_get_int($sname.'_time');
   if (defined $timeouttag) {
      Irssi::timeout_remove($timeouttag);
   }
   $timeouttag = Irssi::timeout_add($time * 1000, 'checklimit','');
}

sub checklimit {
   my $c = Irssi::channel_find($channel);
   return unless ref $c;
   return unless $c->{chanop};
   my $users = scalar @{[$c->nicks]};
   
   if(($c->{limit} <= ($users+$offset-$tolerence)) || 
		 ($c->{limit} > ($users+$offset+$tolerence))) {
	  $c->{server}->send_raw("MODE $channel +l " . ($users+$offset));
   }
}

Irssi::signal_add('setup changed', \&sig_setup_changed);

Irssi::settings_add_str($sname, $sname.'_channel', "#channel");
Irssi::settings_add_int($sname, $sname.'_offset', 5);
Irssi::settings_add_int($sname, $sname.'_tolerence', 2);
Irssi::settings_add_int($sname, $sname.'_time', 60);

sig_setup_changed();

# vim:set ts=3 sw=3 expandtab:
