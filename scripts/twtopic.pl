use strict;
use vars qw($VERSION %IRSSI);
use Irssi;
use Irssi::Irc;
use Irssi::TextUI;

$VERSION = '1.02';
%IRSSI = (
   authors	=> 'John Engelbrecht',
   contact	=> 'jengelbr@yahoo.com',
   name	        => 'twtopic.pl',
   description	=> 'Animated Topic bar.',
   sbitems      => 'twtopic',
   license	=> 'Public Domain',
   changed	=> '2018-09-08',
   url		=> 'http://irssi.darktalker.net'."\n",
);

my $instrut = 
  ".--------------------------------------------------.\n".
  "| 1.) shell> mkdir ~/.irssi/scripts                |\n".
  "| 2.) shell> cp twtopic.pl ~/.irssi/scripts/       |\n".
  "| 3.) shell> mkdir ~/.irssi/scripts/autorun        |\n".
  "| 4.) shell> ln -s ~/.irssi/scripts/twtopic.pl \\   |\n".
  "|            ~/.irssi/scripts/autorun/twtopic.pl   |\n".
  "| 5.) /sbar topic remove topic                     |\n".
  "| 6.) /sbar topic remove topic_empty               |\n".
  "| 7.) /sbar topic add -after topicbarstart         |\n".
  "|        -priority 100 -alignment left twtopic     |\n".
  "| 9.) /toggle twtopic_instruct and last /save      |\n".
  "|--------------------------------------------------|\n".
  "|  Options:                               Default: |\n".
  "|  /set twtopic_refresh <speed>              150   |\n".
  "|  /set twtopic_size <size>                  20    |\n".
  "|  /toggle twtopic_instruct |Startup instructions  |\n".
  "\`--------------------------------------------------'";

my $timeout=0;
my $start_pos=0;
my $flipflop=0; 
my @mirc_color_arr = ("\0031","\0035","\0033","\0037","\0032","\0036","\00310","\0030","\00314","\0034","\0039","\0038","\00312","\00313","\00311","\00315","\017");


sub setup {
   my $time = Irssi::settings_get_int('twtopic_refresh');
   Irssi::timeout_remove($timeout) if ($timeout != 0);

   if ($time < 10 ) {
      print "Warning: 'twtopic_refresh' must be >= 10";
      $time=150;
      Irssi::settings_set_int('twtopic_refresh',$time);
   }
   $timeout = Irssi::timeout_add($time, 'reload' , undef);
}
 
sub show { 
   my ($item, $get_size_only) = @_;  
   my $text = get();
   $text="[".$text."]";
   $item->default_handler($get_size_only,$text, undef, 1);
}
 
sub get_topic {
   my $topic = "";
   my $name = Irssi::active_win()->{active}->{name};
   my $type = Irssi::active_win()->{active}->{type};
   $name = "Status" if($name eq "");
   if($name eq "Status") { return "Irssi website: http://www.irssi.org, Irssi IRC channel: #irssi @ irc://irc.freenode:6667, twtopic has been written by Tech Wizard"; }
   if($type eq "QUERY") {
      my $text = "You are now talking too...... ".$name;
      return $text;
      }
   my $channel = Irssi::Irc::Server->channel_find($name);
   $topic = $channel->{topic};
   foreach (@mirc_color_arr) { $topic =~ s/$_//g; }
   return $topic;
}

sub get {
   my $str=get_topic();
   $str =~ s/(\00313)+//;
   $str =~ s/(\002)+//;
   $str =~ s/(\001)+//;
   my $extra_str= "                                                                                                         ";
   my $size    = Irssi::settings_get_int('twtopic_size');
   if($str eq "") {
      my $str = "=-=-=-=-= No Topic=-=-=-=-=-=-=-";
      }
   my @str_arr = split //, $str;
   my $total = $#str_arr;
   $str=substr($extra_str,0,$size).$str.$extra_str;
   my $text = substr($str,$start_pos,$size);
   if($start_pos > $total+$size) {
      $start_pos=0;
      }
   if(!$flipflop) {
      $flipflop=1;
      return $text;
      }
   $start_pos++;
   $flipflop=0;
   return $text;
}

sub reload {
   Irssi::statusbar_items_redraw('twtopic');
}

Irssi::statusbar_item_register('twtopic', '$0', 'show');
Irssi::signal_add('setup changed', 'setup');
Irssi::settings_add_int('tech_addon', 'twtopic_refresh', 150);
Irssi::settings_add_bool('tech_addon', 'twtopic_instruct', 1);
Irssi::settings_add_int('tech_addon', 'twtopic_size',20);

setup();

if(Irssi::settings_get_bool('twtopic_instruct')) {
   print $instrut;
}

