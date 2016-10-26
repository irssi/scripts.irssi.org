# This is not a well written script, but it works. I hope.
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = '0.1';
%IRSSI = (
  authors	=> 'optical',
  contact	=> 'optical@linux.nu',
  name		=> 'SETI@home info',
  description	=> 'Tell ppl how far you\'ve gotten with you SETI\@home workunit.',
  license	=> 'GPL',
  url		=> 'http://optical.kapitalet.org/seti/',
  changed	=> 'Sat Jul 13 12:03:42 CEST 2002',
  commands	=> '/seti <#channel>|<nick>',
  note		=> 'Make sure you set the seti_state_sah with /set'
);

sub seti_info {

  my $WHERES_SETI_STATE_SAH = Irssi::settings_get_str('seti_state_sah');

  my ($data, $server, $witem) = @_;

  my $line;
  open(INFO, "<", $WHERES_SETI_STATE_SAH);
  for(my $tmp = 0; $tmp < 5; $tmp++) {
    $line = <INFO>;
  }
  close(INFO);
  my $proc = substr($line, 7, 4)/100;
  my $output = "progress of this SETI\@home workunit: $proc%";

  if($data)
  {
    $server->command("MSG $data $output");
  }
  elsif($witem && ($witem->{type} == "QUERY" ||
		   $witem->{type} == "CHANNEL"))
  {
    $witem->command("MSG ".$witem->{name}." $output");
  }
  else
  {
    Irssi::print("$output");
  }
}

Irssi::command_bind('seti', 'seti_info');
Irssi::settings_add_str('misc', 'seti_state_sah', '~/setiathome-3.03.i386-pc-linux-gnu-gnulibc2.1/state.sah');
