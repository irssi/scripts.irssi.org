use strict;
use vars qw($VERSION %IRSSI);
use Irssi;
use Irssi::Irc;
use Irssi::TextUI;
 
my $instrut =
  ".--------------------------------------------------.\n".
  "| 1.) shell> mkdir ~/.irssi/scripts                |\n".
  "| 2.) shell> cp twprompt.pl ~/.irssi/scripts/      |\n".
  "| 3.) shell> cp twprompt.pl ~/.irssi/scripts/      |\n".
  "| 4.) shell> mkdir ~/.irssi/scripts/autorun        |\n".
  "| 5.) shell> ln -s ~/.irssi/scripts/twprompt.pl \\  |\n".
  "|            ~/.irssi/scripts/autorun/twprompt.pl  |\n".
  "| 6.) /sbar prompt remove prompt                   |\n".
  "| 7.) /sbar prompt remove prompt_empty             |\n".
  "| 8.) /sbar prompt add -before input -priority 100 |\n". 
  "|           -alignment left twprompt               |\n".
  "| 9.) /toggle twprompt_instruct and last /save     |\n".
  "|--------------------------------------------------|\n".
  "|  Options:                               Default: |\n".
  "|  /set twprompt_refresh <speed>              100  |\n".
  "|  /set twprompt_color_a <string>             %%C   |\n".
  "|  /set twprompt_color_b <string>             %%c   |\n".
  "|  /toggle twprompt_instruct |Startup instructions |\n".
  "\`--------------------------------------------------'";

 
$VERSION = '1.00';
%IRSSI = (
   authors	=> 'John Engelbrecht',
   contact	=> 'jengelbr@yahoo.com',
   name	        => 'twprompt.pl',
   description	=> 'BitchX\'s CrackRock3 animated prompt bar.',
   license	=> 'Public Domain',
   changed	=> 'Wed Sep 29 02:58:28 CDT 2004',
   url		=> 'http://irssi.darktalker.net'."\n",
);

my $twprompt_file = "$ENV{HOME}/.irssi/twprompt.data";
my $num = 1;
my $jk=0;
my $timeout;

sub reload { Irssi::statusbar_items_redraw('twprompt'); }
 
sub setup {
   my $time = Irssi::settings_get_int('twprompt_refresh');
   Irssi::timeout_remove($timeout);
   $timeout = Irssi::timeout_add($time, 'reload' , undef);
}
 
sub show {
   my ($item, $get_size_only) = @_;
   my $text = get();
   $item->default_handler($get_size_only, "{prompt ".$text."}", undef, 1);
}
 
sub get {
   my $str = Irssi::active_win()->{active}->{name};
   $str = "Status" if($str eq "");
   my @chars = split //, $str;
   my $total = $#chars;
   my $text = "";
   my $col_a = Irssi::settings_get_str('twprompt_color_a');
   my $col_b = Irssi::settings_get_str('twprompt_color_b');
   for my $cx (0..$total) {
      if($cx == ($num - 1)) {
         $text.=$col_a.$chars[$cx];
      } else {
         $text.=$col_b.$chars[$cx];
         }
      }   
   if(!$jk)  {
      $jk=1;
      return $text;
      }
   if($num <= ($total + 1)) { 
      $num++; 
      } 
   else {
      $num = 1;
      }
   $jk=0;
   return $text;
}
 
Irssi::statusbar_item_register('twprompt', '$0', 'show');
Irssi::settings_add_str('tech_addon', 'twprompt_color_b',"%c");
Irssi::settings_add_str('tech_addon', 'twprompt_color_a',"%C");
Irssi::settings_remove('twprompt_instruct');
Irssi::settings_add_bool('tech_addon', 'twprompt_instruct', 1);
Irssi::settings_add_int('tech_addon', 'twprompt_refresh', 100);
Irssi::signal_add('setup changed', 'setup');
$timeout = Irssi::timeout_add(Irssi::settings_get_int('twprompt_refresh'), 'reload' , undef);

if(Irssi::settings_get_bool('twprompt_instruct')) {
   print $instrut;
   }
