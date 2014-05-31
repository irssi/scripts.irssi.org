# Nickmix - Perturbates given nick (or just a word) in certain way.
#
# $Id: nickmix.pl,v 1.2 2002/02/09 22:13:12 pasky Exp pasky $


use strict;

use vars qw ($VERSION %IRSSI $rcsid);

$rcsid = '$Id: nickmix.pl,v 1.2 2002/02/09 22:13:12 pasky Exp pasky $';
($VERSION) = '$Revision: 1.2 $' =~ / (\d+\.\d+) /;
%IRSSI = (
          name        => 'nickmix',
          authors     => 'Petr Baudis',
          contact     => 'pasky@ji.cz',
          url         => 'http://pasky.ji.cz/~pasky/dev/irssi/',
          license     => 'GPLv2, not later',
          description => 'Perturbates given nick (or just a word) in certain way.'
         );


use Irssi;
use Irssi::Irc;


sub cmd_nickmix {
  my ($data) = @_;
  my %letters; # letters hash - value is count of letters
  my $vstr; # vowels string
  my $str; # resulting string

  # First load the whole thing into letters hash
  map { $letters{$_}++; } split(//, $data);

  # Now take the (most of/all) vowels away and compose string from them
  foreach (qw(a e i o u y)) {
    my $c = int rand($letters{$_} * 4 + 1);

    $c = $letters{$_} if ($c > $letters{$_});
    $letters{$_} -= $c;

    for (; $c; $c--) {
      # Either add or prepend
      if (rand(2) < 1) {
	$vstr .= $_;
      } else {
	$vstr = $_ . $vstr;
      }
    }
  }

  # Position of the $vstr..
  my $vpos = int rand (3);

  $str = $vstr if (not $vpos);

  # Now take the rest and do the same ;)
  foreach (keys %letters) { for (; $letters{$_}; $letters{$_}--) {
    # Either add or prepend
    if (rand(2) < 1) {
      $str .= $_;
    } else {
      $str = $_ . $str;
    }
  } }

  if ($vpos == 1) { $str .= $vstr; } elsif ($vpos == 2) { $str = $vstr . $str; }

  Irssi::print "$data -> $str";
}

Irssi::command_bind("nickmix", "cmd_nickmix");

Irssi::print("Nickmix $VERSION loaded...");
