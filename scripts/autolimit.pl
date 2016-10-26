use strict;
use Irssi 20010920.0000 ();
use vars qw($VERSION %IRSSI);
$VERSION = "1.00";
%IRSSI = (
    authors     => 'David Leadbeater',
    contact     => 'dgl@dgl.cx',
    name        => 'autolimit',
    description => 'does an autolimit for a channel, set variables in the script',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.dgl.cx/',
);

# Change these!
my $channel = "#channel";
my $offset = 5;
my $tolerence = 2;
my $time = 60;

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

Irssi::timeout_add($time * 1000, 'checklimit','');

