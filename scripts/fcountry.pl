# Print the country name in /WHOIS replies
# /FCOUNTRY <URI|IP> prints where a URI or IP is hosted.
# Installation: Add $whois_fcountry somewhere in your /FORMAT whois line

###### 
# Copyright (c) 2008 Stefan Jakobs
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
#####################################################################

use strict;
use Irssi 20021028;
use IP::Country::Fast;
use Geography::Countries;

use vars qw($VERSION %IRSSI);
$VERSION = "1.0.0";
%IRSSI = (
	authors         => "Stefan Jakobs",
	contact         => "stefan\.jakobs\@rus\.uni-stuttgart\.de",
	name            => "fast_country",
	description     => "Print the country name in /WHOIS replies",
	license         => "GPLv2",
	changed         => "Son May 11 20:20: CET 2008",
	modules		=> "IP::Country::Fast Geography::Countries",
	commands	=> "fcountry"
);

my $last_country = "";
my $short_country = "";
my $reg = IP::Country::Fast->new();

sub show_help() {
  my $help = $IRSSI{name} ." " .$VERSION ."
Add \$whois_fcountry somewhere in your \'/FORMAT whois\' line

/fcountry <URI|IP>
    prints were the specified URI or IP is hosted
/fcountry help
    prints this message
";
  my $text = '';
  foreach (split(/\n/, $help)) {
    $_ =~ s/^\/(.*)$/%9\/$1%9/;
    $text .= $_."\n";
  }
  print CLIENTCRAP "\n" .$text;
}

sub sig_whois {
  my ($server, $data, $nick, $host) = @_;
  my ($me, $nick, $user, $host) = split(" ", $data);
  
  $short_country = $reg->inet_atocc($host); 
  if ($short_country) { $last_country = country $short_country; }
  else { $last_country = ""; }
}

sub expando_whois_country {
  if (!$short_country) { 
    return ">unknown<";
  } else {
    return $last_country ."\(" .$short_country ."\)";
  }
}

sub cmd_country {
  my $url_ip = lc shift;
  if ($url_ip eq 'help') {
    show_help();
  } elsif ($url_ip eq "") {
    Irssi::print("USAGE: /FCOUNTRY <URL|IP>");
  } else {
    my $short = $reg->inet_atocc($url_ip);
    if (!$short) {
      Irssi::print("Unknown country origin: $url_ip");
    } else {
      my $name = country $short;
      if (!$name) { Irssi::print("$url_ip is hosted in $short"); }
      else { Irssi::print("$url_ip is hosted in $name \($short\)"); }
    }
  } 
}

Irssi::command_bind('fcountry', \&cmd_country);
Irssi::signal_add_first('event 311', \&sig_whois);
Irssi::expando_create('whois_fcountry', \&expando_whois_country, 
		      { 'event 311' => 'None' } );
print CLIENTCRAP "%B>>%n ".$IRSSI{name}." ".$VERSION." loaded: \'/fcountry help\' for help"
