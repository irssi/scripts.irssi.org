# Mrtg-compatible any statistic loader
#  /SET status_min_in - The minimum load to show
#  /SET status_min_in - The minimum load to show
#  /SET status_refresh - How often the loadavg is refreshed
#
#  takes output from mrtg compatible scripts, 
#  see the mrtg-contrib and mrtgutils package for scripts to load
#
#  this one requires /usr/bin/mrtg-ip-acct from mrtgutils package
#
#  TODO ; add support for more than one stat at the same time
#  TODO : negative amounts?
  
use Irssi 20011113;
use Irssi::TextUI;

use strict;
use 5.6.0;

use vars qw($VERSION %IRSSI);
    
# header begins here

$VERSION = "1.0";
%IRSSI = (
	authors     => "Riku Voipio",
	contact     => "riku.voipio\@iki.fi",
	name        => "bandwidth",
	description => "shows bandwidth usage in statusbar",
        license     => "GPLv2",
        url         => "http://nchip.ukkosenjyly.mine.nu/irssiscripts/",
    );

my ($refresh, $last_refresh, $refresh_tag) = (10);
my ($last_in, $last_out) = (0.0,0.0);
my ($min_in, $min_out) = (1.0,1.0);
my ($cur_in, $cur_out, $first_run) = (0.0,0.0,1);
my $command =  '/usr/bin/mrtg-ip-acct';


sub get_stats 
{
  my ($old_in, $old_out) = ($last_in, $last_out);

  my @localstats;
  if (open my $fh, "$command|") 
  {
     @localstats = <$fh>;
    close $fh;
  } else {
    Irssi::print("Failed to execute $command: $!", MSGLEVEL_CLIENTERROR);
  }
  
  for(@localstats[0..1]) {
    return unless defined;
    return unless /^\d+$/;
  }
  $last_in=$localstats[0];
  $last_out=$localstats[1];

  if ($old_out==0){return;}

  $cur_out=($last_out-$old_out) / ($refresh*1024);
  $cur_in=($last_in-$old_in) / ($refresh*1024);
}

sub stats {
  my ($item, $get_size_only) = @_;
  #get_stats();
  
  $min_out = Irssi::settings_get_int('stats_min_out');
  $min_in = Irssi::settings_get_int('stats_min_in');
  $min_in = 0 if $min_in < 0;
  $min_out = 0 if $min_out < 0;
  
  
  if ($cur_in < $min_in and $cur_out <$min_out){
	  #dont print
    if ($get_size_only) {
      $item->{min_size} = $item->{max_size} = 0;
    }
  } else { 
      $item->default_handler($get_size_only, undef, sprintf("i:%.2f o:%.2f",$cur_in, $cur_out ), 1 );
  }
}

sub refresh_stats {
  get_stats();
  Irssi::statusbar_items_redraw('stats');
}

sub read_settings {
  $refresh = Irssi::settings_get_int('stats_refresh');
  $command = Irssi::settings_get_str('stats_commandline');
  $refresh = 1 if $refresh < 1;
  return if $refresh == $last_refresh;
  $last_refresh = $refresh;

  Irssi::timeout_remove($refresh_tag) if $refresh_tag;
  $refresh_tag = Irssi::timeout_add($refresh*1000, 'refresh_stats', undef);
}

Irssi::settings_add_int('misc', 'stats_min_in', $min_in);
Irssi::settings_add_int('misc', 'stats_min_out', $min_out);
Irssi::settings_add_int('misc', 'stats_refresh', $refresh);
Irssi::settings_add_str('misc', 'stats_commandline', $command);

Irssi::statusbar_item_register('stats', '{sb S: $0-}', 'stats');
Irssi::statusbars_recreate_items();

read_settings();
Irssi::signal_add('setup changed', 'read_settings');


