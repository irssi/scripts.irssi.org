use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "0.5";
%IRSSI = (
    authors     => "Jari Matilainen",
    contact     => "jmn98015\@student.mdh.se",
    name        => "licq",
    description => "Licq statusbar thingy",
    license     => "Public Domain",
    url         => "http://jari.cjb.net,http://irssi.org,http://scripts.irssi.de",
);

use Irssi::TextUI;

my $result;
my $refresh_tag;
my $rdir = "$ENV{'HOME'}/.licq/users/";

sub licq {
  my ($item,$get_size_only) = @_;
  $result = 0;
  if(-e $rdir) {
  	opendir(DIR, $rdir);

  	while ( $_ = readdir(DIR) ) {
		next if(($_ eq ".") or ($_ eq ".."));

		my $filename = "$rdir" . "$_";
		if(-e $filename) {
			open(FILE, "<", $filename);
  			$_ = "";
  			$_ = <FILE> until /NewMessages/;
  			my @total = split / /, $_;
  			if(defined $total[2]) {
				$result += $total[2];
			}
		}
  	}
  }

  closedir(DIR);

  $item->default_handler($get_size_only, undef, $result, 1);
}

sub refresh_licq {
  Irssi::statusbar_items_redraw('licq');
}

sub init_licq {
	my $time = Irssi::settings_get_int('licq_refresh_time');
	$rdir = Irssi::settings_get_str('licq_path');
	Irssi::timeout_remove($refresh_tag) if ($refresh_tag);
	$refresh_tag = Irssi::timeout_add($time*1000, 'refresh_licq', undef);
}

Irssi::settings_add_int('LICQ','licq_refresh_time',10);
Irssi::settings_add_str('LICQ','licq_path',$rdir);
Irssi::statusbar_item_register('licq', '{sb ICQ: $0-}', 'licq');

init_licq();
Irssi::signal_add('setup changed','init_licq');
refresh_licq();

# EOF
