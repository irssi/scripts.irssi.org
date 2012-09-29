# based on jpq.pl by Maximilian 'sdx23' Voit (max.voit@gmx.net)

use Irssi;
use Irssi::TextUI;
use POSIX qw(strftime);
use vars qw($VERSION %IRSSI); 

$VERSION = "1.2";
%IRSSI = (
    authors     => "Maximilian \'sdx23\' Voit, Nico R. Wohlgemuth",
    contact     => "nico\@lifeisabug.com",
    name        => "jpqnmwin",
    description => "Print join-, part-, quit-, nick- and mode-messages".
                   " to a window named \"jpqnm\"",
    license     => "GPLv2",
    url         => "http://irssi.org/",
    changed     => "2012-09-29"
);

my $lasttext = '';
my $lastjoiner = '';
my $lastjoin = '';

sub sig_printtext {
    my ($dest, $text, $stripped) = @_;

    if (($dest->{level} & MSGLEVEL_JOINS) ||
        ($dest->{level} & MSGLEVEL_PARTS) ||
        ($dest->{level} & MSGLEVEL_QUITS) ||
        ($dest->{level} & MSGLEVEL_NICKS) || 
        ($dest->{level} & MSGLEVEL_MODES) ||
        ($dest->{level} & MSGLEVEL_KICKS)) {

      my $window = Irssi::window_find_name('jpqnm');
      return if(!$window);

      if ($dest->{level} & MSGLEVEL_JOINS) {

         $text =~ /(.+) has joined/;
         $joiner = $1;

         if (($joiner eq $lastjoiner) && ($text ne $lastjoin)) {

            my $ljoin = $window->view()->get_bookmark('ljoin');
               $window->view()->remove_line($ljoin) if defined $ljoin;
            
            $text =~ /has joined(.+)/;
            $text = $lastjoin.','.$1;
         }
         else {
            $lastjoiner = $joiner;
         }
         $lastjoin = $text;
      }

      my $tag = $dest->{server}->{tag};  
      my $ts = strftime(
          Irssi::settings_get_str('timestamp_format')." ",
          localtime
      );
      
      my $text = $ts . $tag . ": " . $text;

      if($text ne $lastext) {
          $window->print($text, MSGLEVEL_NEVER);
          $window->view()->set_bookmark_bottom('ljoin') if ($dest->{level} & MSGLEVEL_JOINS);
      }
   
      $lastext = $text;

      if (Irssi::settings_get_bool("jpqnmwin_stop_signal")) {
         if (!($dest->{level} & MSGLEVEL_KICKS)) {
            Irssi::signal_stop();
         }
      }
    }
}

my $window = Irssi::window_find_name('jpqnm');
Irssi::print("Create a window named 'jpqnm'") if(!$window);

Irssi::signal_add('print text', 'sig_printtext');

Irssi::settings_add_bool("jpqnmwin", "jpqnmwin_stop_signal", 1);

# vim:set ts=4 sw=4 et:
