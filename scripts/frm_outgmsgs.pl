use strict;
use warnings;
use Scalar::Util qw(looks_like_number);

use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = '1.1';
%IRSSI = (
	authors     => 'Pablo Martín Báez Echevarría',
	contact     => 'pab_24n@outlook.com',
	name        => 'frm_outgmsgs',
	description => 'define a permanent text formatting (bold, underline, etc.) for outgoing messages',
	license     => 'Public Domain',
	url         => 'http://reirssi.wordpress.com',
	changed     => '14:20:15, Oct 16th, 2014 UYT',
);

#
# USAGE
# =====
# copy the script to ~/.irssi/scripts/
#
# In irssi:
#          /run frm_outgmsgs
#
#
# OPTIONS
# =======
# settings can be resetted to defaults with /set -default
#
#
# /set outgmsgs_use_formatting <ON|OFF>
# * enables the text formatting for outgoing messages
#   you may want to create a key-binding (e.g. /bind ^F /^toggle outgmsgs_use_formatting)
#   to send an unformatted line in a fast way (just type ctrl-F and start writing... then 
#   again type ctrl-F to return to send formatted msgs)
#
# /set outgmsgs_strip_codes <ON|OFF>
# * if turned ON, removes any other text formatting apart from the one which is defined by the script
#   in order to avoid undesired effects, it is strongly recommended to set this to ON if
#   outgmsgs_use_formatting is enabled
#
# ----------
#
# /set outgmsgs_use_bold <ON|OFF>
# * enables bold
#
# /set outgmsgs_use_italics <ON|OFF>
# * enables italics
#
# /set outgmsgs_use_underline <ON|OFF>
# * enables underline
#
# /set outgmsgs_use_color <ON|OFF>
# * enables color
#
# all this group settings are only taken into account if outgmsgs_use_formatting is ON
#
# ----------
#
# /set outgmsgs_foreground_color <0|1|2|...|15>
# * defines foreground color
#
# /set outgmsgs_background_color <0|1|2|...|15>
# * defines background color
#
# the last two settings only make sense if outgmsgs_use_color is ON
# if they are setted to any other value that doesn't belong to mIRC color range [0..15], they will be ignored
#
#
# COMMANDS
# ========
# /mirccolors
# * displays a list with the mIRC colors in the status window to help the user to choose colors
#

Irssi::settings_add_bool('frm_outgmsgs', 'outgmsgs_use_formatting', 0);
Irssi::settings_add_bool('frm_outgmsgs', 'outgmsgs_strip_codes', 0);


Irssi::settings_add_bool('frm_outgmsgs', 'outgmsgs_use_bold', 0);
Irssi::settings_add_bool('frm_outgmsgs', 'outgmsgs_use_italics', 0);
Irssi::settings_add_bool('frm_outgmsgs', 'outgmsgs_use_underline', 0);
Irssi::settings_add_bool('frm_outgmsgs', 'outgmsgs_use_color', 0);

Irssi::settings_add_str('frm_outgmsgs', 'outgmsgs_foreground_color', '');
Irssi::settings_add_str('frm_outgmsgs', 'outgmsgs_background_color', '');

sub cmd_colors {
  my $str = "\x02mIRC colors:\x0f ";
  $str .= sprintf "\x03,%02d%02d",$_,$_ for 0..15;
  print $str;
   
}

sub is_mIRC_color {
  my ( $num ) = @_;
  return (looks_like_number($num)) ? ((0 <= $num) && ($num <= 15)) : 0;
}
           
sub event_outgoing_msg {
 
  my ($message, $server, $witem) = @_;
   
  my $use_formatting = Irssi::settings_get_bool("outgmsgs_use_formatting");
  my $strip_codes    = Irssi::settings_get_bool("outgmsgs_strip_codes");  
  
  $message = Irssi::strip_codes($message) if ($strip_codes);
  if (!$use_formatting) {
    Irssi::signal_continue($message, $server, $witem);
    return;
  }

  my $prefix = "";

  my $use_bold      = Irssi::settings_get_bool("outgmsgs_use_bold");
  my $use_italics   = Irssi::settings_get_bool("outgmsgs_use_italics");
  my $use_underline = Irssi::settings_get_bool("outgmsgs_use_underline");
  my $use_color     = Irssi::settings_get_bool("outgmsgs_use_color");

  my $fg_color = Irssi::settings_get_str("outgmsgs_foreground_color");
  my $bg_color = Irssi::settings_get_str("outgmsgs_background_color");

  $prefix .= "\x02" if ($use_bold);
  $prefix .= "\x1d" if ($use_italics);
  $prefix .= "\x1f" if ($use_underline);
  
  my $valid_fg_color = ($fg_color ne "") && is_mIRC_color($fg_color);
  my $valid_bg_color = ($bg_color ne "") && is_mIRC_color($bg_color);
  
  if( $use_color && ($valid_fg_color || $valid_bg_color) ) {
    $fg_color = ($valid_fg_color) ? sprintf "%02d", $fg_color : "";
    $bg_color = ($valid_bg_color) ? sprintf "%02d", $bg_color : "";
    $prefix .= "\x03".$fg_color;
    $prefix .= ",$bg_color" if ($valid_bg_color);
  }
   
  Irssi::signal_continue($prefix.$message, $server, $witem);
 
}
 
Irssi::signal_add("send text", \&event_outgoing_msg);
Irssi::command_bind("mirccolors", \&cmd_colors); 
