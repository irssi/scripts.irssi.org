####
# needs:
# - Text::Aspell
# - GNU Aspell - http://aspell.net/
#
# settings:
# spell_dict - A comma or whitespace seperated list of dictionaries to use.
#              First in the list is the default.
#              Bind rotate_dict to easily cycle through the list of dictionaries.
# spell_suggestion_mode - The aspell suggestion mode.
#                         For infos on suggestion modes see the aspell manual.
#


use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Text::Aspell;

$VERSION = '1.00';
%IRSSI = (
  authors     => 'Philipp Haegi',
  contact     => 'phaegi\@mimir.ch',
  name        => 'aspell_complete',
  description => 'Adds Text::Aspell suggestions to the list of completions',
  license     => 'Public Domain',
  url         => 'http://www.mimir.ch/ph/',
  changed     => '2004-02-05',
  commands    => 'rotate_dict',
  note        => '',
);

my ($setting_spell_dict, $setting_suggestion_mode);
my @langs;

my $speller = Text::Aspell->new;
die unless $speller;


sub cmd_load() {
  $setting_spell_dict = Irssi::settings_get_str("spell_dict");
  @langs = split /[,\s]/, $setting_spell_dict;
  $speller->set_option('lang', $langs[0]);
  Irssi::print($IRSSI{'name'} . ": dictionary language: " . $langs[0]);

  $setting_suggestion_mode = Irssi::settings_get_str("spell_suggestion_mode");
  $speller->set_option('sug-mode', $setting_suggestion_mode);
  Irssi::print($IRSSI{'name'} . ": dictionary mode: " . $setting_suggestion_mode);
}


sub rotate_dict() {
  push(@langs, shift(@langs));
  $speller->set_option('lang', $langs[0]);
  Irssi::print($IRSSI{'name'} . ": dictionary language: " . $langs[0]);
}


Irssi::signal_add_last 'complete word' => sub {
  my ($complist, $window, $word, $linestart, $want_space) = @_;
  push(@$complist, $speller->suggest( $word ));
};


Irssi::signal_add_last 'setup changed' => sub {
  if ($setting_spell_dict ne Irssi::settings_get_str("spell_dict") ||
      $setting_suggestion_mode ne Irssi::settings_get_str("spell_suggestion_mode")) 
    { 
      cmd_load(); 
    } 
};


####
# Register commands
Irssi::command_bind('rotate_dict', 'rotate_dict');


###
# Settings
Irssi::settings_add_str($IRSSI{'name'}, 'spell_dict', "en_UK");
Irssi::settings_add_str($IRSSI{'name'}, 'spell_suggestion_mode', "fast");

# Engage!
cmd_load();
