# $Id: awaylogcnt.pl,v 0.2 2004/10/27 19:46 derwan Exp $
# 
# Run command '/statusbar window add -after user -priority 1 awaylogcnt' after loading awaylogcnt.pl.
#

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '0.2';
%IRSSI = (
   authors      => 'Marcin Rozycki',
   contact      => 'derwan@irssi.pl',
   name         => 'awalogcnt',
   description  => 'Displays in statusbar number of messages in awaylog',
   modules      => '',
   license      => 'GNU GPL v2',
   url          => 'http://derwan.irssi.pl',
   changed      => 'Wed Oct 27 19:46:28 CEST 2004'
);

use Irssi::TextUI;

our $cnt = 0;
our $fname = undef();


Irssi::signal_add( 'log started' => sub {
   my $logfile = Irssi::settings_get_str( 'awaylog_file' );
   return unless ( $_[0]->{fname} eq $logfile );
   ($fname, $cnt) = ($logfile, 0);
   Irssi::statusbar_items_redraw('awaylogcnt');
});

Irssi::signal_add( 'log stopped' => sub {
   return unless ( $_[0]->{fname} eq $fname );
   ($cnt, $fname) = (0, undef);
   Irssi::statusbar_items_redraw('awaylogcnt');
});
		
Irssi::signal_add( 'log written' => sub {
   return unless ( $_[0]->{fname} eq $fname );
   $cnt++;
   Irssi::statusbar_items_redraw('awaylogcnt');
});

sub awaylogcnt ($$) {
   my ($sbitem, $get_size_only) = @_;
   unless ( $cnt )
   {
      $sbitem->{min_size} = $sbitem->{max_size} = 0 if ( ref $sbitem );
      return;
   }
   my $format = sprintf('{sb \%%yawaylog\%%n %d}', $cnt);
   $sbitem->default_handler($get_size_only, $format, undef, 1);
}

Irssi::statusbar_item_register('awaylogcnt', undef, 'awaylogcnt');
