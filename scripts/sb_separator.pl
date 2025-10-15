# $Id: sb_separator.pl,v 0.1 2025/10/14 21:40 Hravnkel $
# 
# Run command '/statusbar additem -after user -alignment left -priority 1 separator' after loading sb_separator.pl.
#

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '0.1';
%IRSSI = (
   authors      => 'Björn Sundberg',
   contact      => 'bjorn@forndata.org',
   name         => 'sb_separator',
   description  => 'Displays up to three user defined separators in statusbar',
   modules      => '',
   sbitems      => 'sb_separator',
   license      => 'GNU GPL v2',
   url          => 'http://derwan.irssi.pl',
   changed      => 'Wed Oct 27 19:46:28 CEST 2004'
);

use Irssi::TextUI;

my ($separator, $separator_2, $separator_3);

sub separator {
   my ($item, $get_size_only) = @_;

   my $theme = Irssi::current_theme();
   my $separator = $theme->format_expand("{sb_separator}",
   Irssi::EXPAND_FLAG_IGNORE_EMPTY);

   my $format = sprintf('{sb %s}', $separator);
   $item->default_handler($get_size_only, $format, undef, 1);
}


sub separator_2 {
   my ($item, $get_size_only) = @_;

   my $theme = Irssi::current_theme();
   my $separator_2 = $theme->format_expand("{sb_separator_2}",
   Irssi::EXPAND_FLAG_IGNORE_EMPTY);

   my $format = sprintf('{sb %s}', $separator_2);
   $item->default_handler($get_size_only, $format, undef, 1);
}

sub separator_3 {
   my ($item, $get_size_only) = @_;

   my $theme = Irssi::current_theme();
   my $separator_3 = $theme->format_expand("{sb_separator_3}",
   Irssi::EXPAND_FLAG_IGNORE_EMPTY);

   my $format = sprintf('{sb %s}', $separator_3);
   $item->default_handler($get_size_only, $format, undef, 1);
}

Irssi::statusbar_item_register('separator', undef, 'separator');
Irssi::statusbar_item_register('separator_2', undef, 'separator_2');
Irssi::statusbar_item_register('separator_3', undef, 'separator_3');
