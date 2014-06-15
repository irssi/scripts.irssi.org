use strict;
use warnings;

use Irssi;

our $VERSION = "1.0";
our %IRSSI = (
    authors     => 'Nico R. Wohlgemuth',
    contact     => 'nico@lifeisabug.com',
    name        => 'levelclear',
    description => 'Similar to crapbuster.pl but uses irssis internal scrollback levelclear functionality and is able to clear the previous window automatically after having switched to a new one when levelclear_autoclear is set to true.',
    license     => 'WTFPL',
    url         => 'http://scripts.irssi.org/',
    changed     => '2014-06-15 12:59:00'
);

Irssi::settings_add_str('levelclear', 'levelclear_levels', 'CLIENTCRAP,CLIENTERROR,CLIENTNOTICE,CRAP,JOINS,KICKS,MODES,NICKS,PARTS,QUITS,TOPICS,SNOTES');
Irssi::settings_add_bool('levelclear', 'levelclear_autoclear', 0);
my $level = Irssi::settings_get_str('levelclear_levels');
my $autoclear = Irssi::settings_get_bool('levelclear_autoclear');
my $levelclearcmd = 'SCROLLBACK LEVELCLEAR -level ' . $level;

sub levelclear {
      Irssi::command($levelclearcmd);
}

Irssi::signal_add(
   'window changed' => sub {
      my (undef, $oldwin) = @_;
      if ($autoclear && $oldwin) {
         $oldwin->command($levelclearcmd) if ($oldwin->{name} ne '(status)');
      }
   }
);

Irssi::signal_add(
   'setup changed' => sub {
      $level = Irssi::settings_get_str('levelclear_levels');
      $autoclear = Irssi::settings_get_bool('levelclear_autoclear');
   }
);

Irssi::command_bind('levelclear', 'levelclear');
