# Print hilighted messages with MSGLEVEL_PUBLIC  to active window 
# for irssi 0.7.99 by Pawe³ 'Styx' Chuchma³a based on hilightwin.pl by Timo Sirainen
use Irssi;
use vars qw($VERSION %IRSSI); 
$VERSION = "0.1";
%IRSSI = (
        authors         => "Pawe³ \'Styx\' Chuchma³a",
	contact         => "styx\@irc.pl",
	name            => "showhilight",
	description     => "Show hilight messages in active window",
	license         => "GNU GPLv2",
	changed         => "Fri Jun 28 11:09:42 CET 2002"
						
);

sub sig_printtext {
  my ($dest, $text, $stripped) = @_;

  my $window = Irssi::active_win();

  if (($dest->{level} & MSGLEVEL_HILIGHT) && ($dest->{level} & MSGLEVEL_PUBLIC) && 
       ($window->{refnum} != $dest->{window}->{refnum}) && ($dest->{level} & MSGLEVEL_NOHILIGHT) == 0) {

    $text = $dest->{target}.":%K[".Irssi::settings_get_str(hilight_color).$dest->{window}->{refnum}."%K]:".$text;

    $window->print($text, MSGLEVEL_CLIENTCRAP);
  }
}

Irssi::signal_add('print text', 'sig_printtext');
