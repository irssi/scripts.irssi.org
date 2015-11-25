#
# Add the statusbar item to its own statusbar with
# /statusbar sb_timezones enable
# /statusbar sb_timezones add -alignment left barstart
# /statusbar sb_timezones add -after barstart timezones
# /statusbar sb_timezones add -alignment right barend
#
# or add it to an existing one with
# /statusbar window add timezones (window is an exaple, see /statusbar and /help statusbar for comprehensive help)

use strict;
use warnings;
use Irssi::TextUI;
use DateTime;
use Carp qw/croak/;

use vars qw($VERSION %IRSSI);

$VERSION = "0.2";
%IRSSI = (
    authors     => "Jari Matilainen",
    contact     => 'vague!#irssi@freenode on irc',
    name        => "timezones",
    description => "timezones displayer",
    license     => "Public Domain",
    url         => "http://gplus.to/vague",
    changed     => "Tue 24 November 16:00:00 CET 2015",
);

my $refresh_tag;

sub timezones {
  my ($item,$get_size_only) = @_;
  my ($datetime) = Irssi::settings_get_str("timezones_clock_format");
  my ($div) = Irssi::settings_get_str("timezones_divider");
  my (@timezones) = split ' ', Irssi::settings_get_str("timezones");

  my $result = "";

  for my $tz (@timezones) {
    if(length($result)) { $result .= $div; }

    my ($nick, $timezone) = split /:/, $tz;
    my $now;

    eval {
      $now = DateTime->now(time_zone => $timezone) or croak $!;
    };

    if($@) {
      $result .= $nick . ": INVALID";
    }
    else {
      $result .= $nick . ": " . $now->strftime($datetime);
    }
  }

  $item->default_handler($get_size_only, "", $result, 0);
}

sub refresh_timezones {
  Irssi::statusbar_items_redraw('timezones');
}

sub init_timezones {
  Irssi::timeout_remove($refresh_tag) if ($refresh_tag);
  $refresh_tag = Irssi::timeout_add(1000, \&refresh_timezones, undef);
}

Irssi::statusbar_item_register('timezones', '{sb $0-}', 'timezones');
Irssi::settings_add_str('timezones', 'timezones_clock_format', '%H:%M:%S');
Irssi::settings_add_str('timezones', 'timezones_divider', ' ');
Irssi::settings_add_str('timezones', 'timezones', 'Mike:GMT Sergey:EST');
Irssi::signal_add('setup changed', \&init_timezones);

init_timezones();
refresh_timezones();
