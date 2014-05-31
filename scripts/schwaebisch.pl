#!/usr/bin/perl
#
#  Schwaebisch (irssi) 1.0.0
#
#  (c) 2000-2003 by Robert Scheck <irssi@robert-scheck.de>
#
#  Schwaebisch (irssi) is adapted from "schwob", a swabian translator 
#  by Jens Schweikhardt <schweikh@noc.dfn.de>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc.,
#  59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#


use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "1.0.0";
%IRSSI = (
    authors     => "Robert Scheck",
    contact     => "irssi\@robert-scheck.de",
    name        => "Schwaebisch",
    description => "/schwäbisch - translates your messages from german to swabian",
    license     => "GNU GPL v2",
    url         => "http://ftp.robert-scheck.de/linux/irssi/scripts/",
    modules     => "",
    changed     => "$VERSION",
    commands    => "schwäbisch"
);

use Irssi 20020324;

sub schwaebisch ($)
{
  my ($text) = @_;

  # Komplette Wortersetzungen:
  $text =~ s/\b([Dd])a\b([^ß])/$1o$2/g;
  $text =~ s/\bdann\b/no/g;
  $text =~ s/\bEs\b/S/g;
  $text =~ s/\bes\b/s/g;
  $text =~ s/\beine([sm])\b/oi$1/g;
  $text =~ s/\bEine([sm])\b/Oi$1/g;
  $text =~ s/\b([DdMmSs])eine?\b/$1ei/g;
  $text =~ s/\b([DdMmSs])eins\b/$1eis/g;
  $text =~ s/\b([DdMmSs])einer\b/$1einr/g;
  $text =~ s/\beine\b/a/g;
  $text =~ s/\bEine\b/A/g;
  $text =~ s/\beiner\b/oinr/g;
  $text =~ s/\bEiner\b/Oinr/g;
  $text =~ s/\b([Ee])inen\b/$1n/g;        # einen -> en
  $text =~ s/\b([Dd])as/$1es/g;           # das -> des
  $text =~ s/\b[Ii]ch\b/I/g;              # ich -> i
  $text =~ s/\b([Nn])icht\b/$1ed/g;       # nicht -> ned
  $text =~ s/\b([Ss])ie\b/$1e/g;          # sie -> se
  $text =~ s/\bwir\b/mir/g;
  $text =~ s/\bWir\b/Mir/g;
  $text =~ s/\b(he)?([Rr])unter/$2a/g;
  $text =~ s/\b([Hh])at\b/$1ott/g;
  $text =~ s/\b([Hh])aben\b/$1enn/g;
  $text =~ s/\b([Hh])abe\b/$1ann/g;
  $text =~ s/\b([Gg])ehen\b/$1anga/g;
  $text =~ s/\b([Kk])ann\b/$1a/g;
  $text =~ s/\b([Kk])önnen\b/$1enna/g;
  $text =~ s/\b([Ww])ollen\b/$1ella/g;
  $text =~ s/\b([Ss])ollten\b/$1oddad/g;
  $text =~ s/\b([Ss])ollt?e?\b/$1odd/g;
  $text =~ s/\bdiese?r?\b/sell/g;
  $text =~ s/\bDiese?r?\b/Sell/g;
  $text =~ s/\b([Aa])uch\b/$1o/g;        # auch -> ao
  $text =~ s/\b([Nn])och\b/$1o/g;        # noch -> no
  $text =~ s/\b([Ss])ind\b/$1end/g;      # sind -> send
  $text =~ s/\b([Ss])chon\b/$1cho/g;     # schon -> scho
  $text =~ s/\b([Mm])an\b/$1r/g;         # man -> mr
  $text =~ s/\b([Dd])ie\b/$1/g;          # die -> d
  $text =~ s/\b([Dd])a?rauf\b/$1ruff/g;  # darauf -> druff
  $text =~ s/\bviele?s?\b/en Haufa/g;
  $text =~ s/\bViele?s?\b/En Haufa/g;
  $text =~ s/\bAuto|Daimler\b/Heilix Blechle/g;
  $text =~ s/Marmelade|Konfitüre/Xälz/g;
  $text =~ s/\b2\b/zwoi/g;
  $text =~ s/\b5\b/fempf/g;
  $text =~ s/\b15\b/fuffzehn/g;
  $text =~ s/\b50\b/fuffzig/g;

  # Am Wortanfang und Großgeschriebenes:
  $text =~ s/\bAuf/Uff/g;
  $text =~ s/\bauf/uff/g;
  $text =~ s/\bEin/Oi/g;
  $text =~ s/\bein/oi/g;
  $text =~ s/\bMal/Mol/g;
  $text =~ s/\bUm/Om/g;
  $text =~ s/\bunge/og/g;
  $text =~ s/\bUnge/Og/g;
  $text =~ s/\bunver/ovr/g;
  $text =~ s/\bUnver/Ovr/g;
  $text =~ s/\bUn/On/g;
  $text =~ s/\bun/on/g;
  $text =~ s/\bUnd/Ond/g;
  $text =~ s/\bin(s?)/en$1/g;            # in -> en,   ins -> ens
  $text =~ s/\bIn(s?)/En$1/g;            # In -> En,   Ins -> Ens
  $text =~ s/\bim/em/g;
  $text =~ s/\bIm/Em/g;
  $text =~ s/\b([Kk])ein/$1oin/g;
  $text =~ s/\b([Nn])ein/$1oi/g;
  $text =~ s/\b([Zz])usa/$1a/g;          # zusammen -> zamma

  # Am Wortende:
  $text =~ s/\Ben\b/a/g;                 # latschen -> latscha
  $text =~ s/\Bel\b/l/g;                 # Sessel -> Sessl
  $text =~ s/([^h])er\b/$1r/g;           # der -> dr
  $text =~ s/([h])es\b/$1s/g;            # manches -> manchs
  $text =~ s/\Bau\b/ao/g;                # lau -> lao
  $text =~ s/([lt])ein\b/$1oi/g;         # Stein -> Stoi

  # Beliebige Position:
  $text =~ s/([Ff])rag/$1rog/g;
  $text =~ s/teil/doil/g;
  $text =~ s/Teil/Doil/g;
  $text =~ s/([Hh])eim/$1oim/g;
  $text =~ s/steht/stoht/g;
  $text =~ s/um/om/g;
  $text =~ s/imm/emm/g;                  # schlimm -> schlemm
  $text =~ s/mal/mol/g;
  $text =~ s/zwei/zwoi/g;
  $text =~ s/ck/gg/g;
  $text =~ s/([Ee])u/$1i/g;
  $text =~ s/([Vv])er/$1r/g;
  $text =~ s/([Gg])e([aflmnrs])/$1$2/g;  # angenommen -> angnommen
  $text =~ s/([Ss])t/$1chd/g;            # st -> schd
  $text =~ s/([Ss])p/$1chb/g;            # sp -> schb
  $text =~ s/tio/zio/g;                  # Information -> Informazion
  $text =~ s/\?/, ha?/g;
  $text =~ s/!!/, Sagg Zemend!/g;
  $text =~ s/!/, haidanai!/g;

  # Spezielles:
  $text =~ tr/TtPpÖöÜü/DdBbEeIi/;        # Globale Transformationen zum Schluss

  # Was nach 'tr' stehen muss:
  $text =~ s/ung/ong/g;
  $text =~ s/und/ond/g;
  $text =~ s/ind/end/g;

  return $text;
}

sub cmd_schwaebisch ($$$)
{
  my ($arg, $server, $witem) = @_;
  if ($witem && ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY'))
  {
    $witem->command('MSG '.$witem->{name}.' '.schwaebisch($arg));
  }
  else
  {
    print CLIENTCRAP "%B>>%n ".schwaebisch($arg);
  }
}

Irssi::command_bind('schwäbisch', \&cmd_schwaebisch);
