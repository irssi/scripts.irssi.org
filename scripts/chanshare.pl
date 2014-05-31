# /CHANSHARE - display people who are in more than one channel with you
# for irssi 0.7.98
#
# /CHANSHARE [ircnets ...] [#channels ...]
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
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
# 
# Version 0.1 - Timo Sirainen tss@iki.fi
#	Initial stalker.pl 
# Version 0.2 - Chad Armstrong chad@analogself.com
#	Added multiserver support
#	Added keying by nick AND hostname. "nick (fw.corp.com)"
#	Prints to current active window now.
# Version 0.21 - Timo Sirainen tss@iki.fi
#       Removed printing to active window - if you want it, remove your
#       status window.
# Version 0.3 - Timo Sirainen tss@iki.fi
#       Supports for limiting searches only to specified ircnets and
#       channels. Some cleanups..

use Irssi;
use vars qw($VERSION %IRSSI); 
$VERSION = "0.3";
%IRSSI = (
    authors	=> "Timo \'cras\' Sirainen",
    contact	=> "tss\@iki.fi",
    name	=> "chan share",
    description	=> "/CHANSHARE - display people who are in more than one channel with you",
    license	=> "Public Domain",
    url		=> "http://irssi.org/",
    changed	=> "2002-03-04T22:47+0100",
    changes	=> "v0.3 - Timo Sirainen tss\@iki.fi: Supports for limiting searches only to specified ircnets and channels. Some cleanups.."
);

sub cmd_chanshare {
  my ($data, $server, $channel) = @_;
  my (%channicks, @show_channels, @show_ircnets);

  # get list of channels and ircnets
  @show_channels = ();
  @show_ircnets = ();
  foreach my $arg (split(" ", $data)) {
    if ($server->ischannel($arg)) {
      push @show_channels, $arg;
    } else {
      push @show_ircnets, $arg;
    }
  }

  my @checkservers = ();
  if (scalar(@show_ircnets) == 0) {
    # check from all servers
    @checkservers = Irssi::servers();
  } else {
    # check from specified ircnets
    foreach my $s (Irssi::servers()) {
      foreach my $n (@show_ircnets) {
	if ($s->{chatnet} eq $n) {
	  push @checkservers, $s;
	  last;
	}
      }
    }
  }

  foreach my $s (@checkservers) {
    my $mynick = $s->{nick};
    foreach my $channel ($s->channels()) {
      foreach my $nick ($channel->nicks()) {
	my ($user, $host) = split(/@/, $nick->{host});
	my $nickhost = $nick->{nick}." ($host)";
	my @list = ();
	next if ($nick->{nick} eq $mynick);

	@list = @{$channicks{$nickhost}} if (@{$channicks{$nickhost}});
#	Irssi::print($nickhost);
	push @list, $channel->{name};
	$channicks{$nickhost} = [@list];
      }
    }
  }

  Irssi::print("Nicks of those who share your #channels:");
  foreach my $nick (keys %channicks) {
    my @channels = @{$channicks{$nick}};
    if (@channels > 1) {
      my $chanstr = "";
      my $ok = scalar(@show_channels) == 0;
      foreach $channel (@channels) {
	if (!$ok) {
	  # check the show_channels list..
	  foreach my $c (@show_channels) {
	    if ($channel eq $c) {
	      $ok = 1;
	      last;
	    }
	  }
	}
	$chanstr .= "$channel ";
      }
      Irssi::print("$chanstr : $nick") if ($ok);
    }
  }
}

Irssi::command_bind('chanshare', 'cmd_chanshare');
