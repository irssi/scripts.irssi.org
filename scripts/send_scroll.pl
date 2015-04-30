use strict;
use warnings;
use Irssi;
use Irssi::TextUI;

# other variations on the theme: scrolling.pl scrollwarn.pl scrolled_reminder.pl antisboops.pl

our $VERSION = '0.1'; # f030fec17903eb6
our %IRSSI = (
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name	=> 'send_scroll',
    description	=> 'Scroll down on enter',
    license     => 'GNU GPLv2 or later',
);

Irssi::signal_add('key send_line' => sub {
    return unless -1 == index Irssi::parse_special('$K'), Irssi::parse_special('$[1]L');
    my $win = Irssi::active_win;
    my $view = $win->view;
    unless ($view->{bottom}) {
        Irssi::signal_stop;
        $win->command('scrollback end');
    }
});
