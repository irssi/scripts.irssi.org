# $Id: hostname.pl,v 1.8 2002/07/04 13:18:02 jylefort Exp $

use strict;
use Irssi 20020121.2020 ();
use vars qw($VERSION %IRSSI);
$VERSION = "1.01";
%IRSSI = (
	  authors     => 'Jean-Yves Lefort',
	  contact     => 'jylefort\@brutele.be, decadix on IRCNet',
	  name        => 'hostname',
	  description => 'Adds a /HOSTNAME command; it will list all IP addresses on all interfaces found on your machine, resolve them, and allow you to choose one easily',
	  license     => 'BSD',
	  url         => 'http://void.adminz.be/irssi.shtml',
	  changed     => '$Date: 2002/07/04 13:18:02 $ ',
);

# description:
#
#	hostname.pl will add a /HOSTNAME command similar to the one that can
#	be found in BitchX.
#
#	/HOSTNAME will list all IP addresses of your system, and resolve them.
#	/HOSTNAME <index> will switch to the selected IP address.
#
#	The IP addresses are collected by running ifconfig and parsing
#	the output. It has been tested on the following systems:
#
#		FreeBSD 4.4-RELEASE
#		FreeBSD 4.5-RELEASE
#		NetBSD 1.5.2
#		Linux 2.4.16
#		IRIX 6.5
#		OSF/1 4.0
#		SunOS 5.8
#
#	It will probably work on any recent version of the following systems:
#
#		FreeBSD
#		NetBSD
#		OpenBSD
#		Linux
#		IRIX
#		OSF/1 / Tru64
#		SunOS / Solaris
#
#	It may or may not work on other systems / versions, but it will not
#	work on the following pieces of crap:
#
#		M$-DO$ all versions
#		Windoze all versions
#			
#	You'll also need to have the module Socket6.pm installed, the address
#	resolution needs it; on FreeBSD it can be installed easily by typing
#	cd /usr/ports/net/p5-Socket6 && make install
#
# /format's:
#
#	hostname
#
#		$0	index number
#		$1	IP address
#		$2	hostname
#
# new theme abstracts:
#
#	Insert the following in the abstracts section of your theme file:
#
#		index = "[$*]";
#		ip = "%g$*%n";
#		hostname = "{comment $*}";
#
# usage:
#
#	/HOSTNAME [<index>]
#
#	Without arguments, display the list of IP addresses and resolve them.
#
#	With a numerical argument, set the hostname setting to the IP
#	address matching that index in the list.
#
# acknowledgements:
#
#	The following people have sent the ifconfig output of their system:
#	darix, plett, zur
#
# changes:
#
#	2002-07-04	release 1.01
#			* command_bind uses a reference instead of a string
#
#	2002-04-25	release 1.00
#			* increased version number
#
#	2002-02-02	release 0.02
#			* reads ifconfig output one line at a time
#			* excluded too many IP addresses in result: fixed
#			* much '2' today ;)
#
#	2002-02-01	initial release

use Socket;
use Socket6;

my %addresses;

sub hostname {
  my ($args, $server, $item) = @_;

  get_addresses();
  if ($args) {
    set_address($args);
  } else {
    print_addresses();
  }
}

sub get_addresses {
  Irssi::print("Resolving IP addresses...");
  %addresses = ();
  open(IFCONFIG, "-|", "ifconfig");
  while (<IFCONFIG>) {
    $addresses{$2} = resolve($2)
      if (/(inet addr:|inet6 addr: |inet |inet6 )([0-9a-f.:]*)/
	  && ! ($2 =~ /^(127\.0\.0\.1|::1|fe80:.*)$/));
  }
  close(IFCONFIG);
}

sub print_addresses {
  my $i = 0;
  Irssi::printformat(MSGLEVEL_CRAP, "hostname", ++$i, $_, $addresses{$_})
      foreach (keys %addresses);
}

sub set_address {
  my ($index, $i) = (shift, 0);
  foreach (keys %addresses) {
    if (++$i == $index) {
      Irssi::print("Hostname set to $_");
      Irssi::command("^SET HOSTNAME $_");
      return;
    }
  }
  Irssi::print("Hostname #$index not found", MSGLEVEL_CLIENTERROR);
}

sub resolve {
  my $ip = shift;
  my @res = getaddrinfo($ip, 0, AF_UNSPEC, SOCK_STREAM);
  my ($name, $port) = getnameinfo($res[3]);
  return $name;
}

Irssi::theme_register(['hostname',
		       '{index $0} {ip $[20]1} {hostname $[39]2}']);

Irssi::command_bind("hostname", \&hostname);
