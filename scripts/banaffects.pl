use strict;
use Irssi;
use Irssi::Irc;

use vars qw($VERSION %IRSSI);
$VERSION = "1.1";
%IRSSI = (
    authors     => 'Valentin Batz, Nico R. Wohlgemuth',
    contact     => 'senneth@irssi.org, nico@lifeisabug.com',
    name        => 'banaffects_sd',
    description => 'Shows affected nicks by a ban on a new ban ' .
                   'and defends yourself because IRC is serious.',
    url         => 'http://nico.lifeisabug.com/irssi/scripts/',
    licence     => 'GPLv2',
    version     => $VERSION,
);

Irssi::theme_register([
   'ban_affects' => 'Ban {hilight $0} set by {hilight $1} affects: {hilight $2-}',
   'ban_affects_sd', 'Ban affects {hilight you}; taking care of {hilight $0}...'
]);

sub ban_new() {
   my ($chan, $ban) = @_;
   return unless $chan;
   my $server = $chan->{server};
   my $banmask = $ban->{ban};
   my $banuser = $ban->{setby};
   my $ownnick = $server->{nick};
   my $channel = $chan->{name};
   my $window = $server->window_find_item($channel);
   my $selfdefense = 0;
   my @matches;
   foreach my $nick ( sort ( $chan->nicks() ) ) {
      if (Irssi::mask_match_address( $banmask, $nick->{nick}, $nick->{host} )) {
         push (@matches, $nick->{nick});
         $selfdefense = 1 if ($nick->{nick} eq $ownnick);
      }
   }
   my $nicks = join(", ", @matches);
   $window->printformat(MSGLEVEL_CRAP, 'ban_affects', $banmask, $banuser, $nicks) if ($nicks ne '');

   if ($selfdefense && $banuser ne $ownnick && $chan->{chanop}) {
      my $newbanmask = $chan->ban_get_mask($banuser, 0);
      my $kickreason = "IRC is serious!";
      $window->printformat(MSGLEVEL_CRAP, 'ban_affects_sd', $banuser);
      $server->send_raw_now("KICK $channel $banuser :$kickreason");
      $server->send_raw_now("MODE $channel -b+b $banmask $newbanmask");
   }
}

Irssi::signal_add('ban new', \&ban_new);

sub test_ban() {
   my ($arg, $server, $witem) = @_;
   return unless (defined $witem && $witem->{type} eq 'CHANNEL');
   my $chan = $server->channel_find($witem->{name});
   my @matches;
   foreach my $nick ( sort ( $chan->nicks() ) ) {
      if (Irssi::mask_match_address( $arg, $nick->{nick}, $nick->{host} )) {
         push (@matches, $nick->{nick});
      }
   }
   my $nicks = join(", ", @matches);
   $witem->printformat(MSGLEVEL_CRAP, 'ban_affects', $arg, $nicks) if ($nicks ne '');
}

Irssi::command_bind('banaffects', \&test_ban);
