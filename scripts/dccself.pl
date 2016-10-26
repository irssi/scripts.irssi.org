use strict;
use vars qw/%IRSSI/;
use Irssi qw(command_bind active_server);

%IRSSI = (
	authors     => "David Leadbeater",
	contact     => "dgl\@dgl.cx",
	name        => "dccself",
	description => "/dccself ip port, starts a dcc chat with yourself on that 
	                host/port, best used with /set dcc_autochat_masks.",
	license     => "GPL",
);

# I tried using Juerd's style for this script - seems to make it easier to read
# :)

command_bind('dccself', sub { 
   my $data = shift;
	my($ip,$port) = split / |:/, $data, 2;

   return unless ref active_server;
   my $nick = active_server->{nick};
   $ip = dcc_ip($ip);
   active_server->command("ctcp $nick DCC CHAT CHAT $ip $port");
} );

sub dcc_ip {
   my $ip = shift;
   # This could block!
   $ip = sprintf("%d.%d.%d.%d", unpack('C4',(gethostbyname($ip))[4])) 
       unless $ip =~ /\d$/;

   my @a = split /\./, $ip, 4;
   # Thanks to perlguy/grifferz/AndrewR
   return $a[0]*0x1000000 + $a[1]*0x10000 + $a[2]*0x100 + $a[3];
}

