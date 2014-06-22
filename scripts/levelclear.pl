use strict;
use warnings;

use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.1";
%IRSSI = (
    authors     => 'Nico R. Wohlgemuth',
    contact     => 'nico@lifeisabug.com',
    name        => 'levelclear',
    description => 'Similar to crapbuster.pl but uses irssis internal scrollback levelclear functionality and is able to clear the previous window automatically after having switched to a new one when levelclear_autoclear is set to true.',
    license     => 'WTFPL',
    url         => 'http://scripts.irssi.org/',
    changed     => '2014-06-15 17:07:00'
);

Irssi::settings_add_str('levelclear', 'levelclear_levels', 'CLIENTCRAP,CLIENTERROR,CLIENTNOTICE,CRAP,JOINS,KICKS,MODES,NICKS,PARTS,QUITS,TOPICS');
Irssi::settings_add_bool('levelclear', 'levelclear_autoclear', 0);

my $levelclearcmd = 'SCROLLBACK LEVELCLEAR -level ' . Irssi::settings_get_str('levelclear_levels');

sub levelclear {
      Irssi::command($levelclearcmd);
}

Irssi::signal_add(
   'window changed' => sub {
      my (undef, $oldwin) = @_;
      if (Irssi::settings_get_bool('levelclear_autoclear') && $oldwin) {
         $oldwin->command($levelclearcmd) if ($oldwin->{name} ne '(status)');
      }
   }
);

Irssi::command_bind('levelclear', 'levelclear');
