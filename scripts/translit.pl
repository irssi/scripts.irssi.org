use strict;
use vars qw(%IRSSI);

use Irssi;
%IRSSI = (
  authors     => 'dreg',
  contact     => 'dreg@fine.lv',
  name        => 'translit',
  description => 'translitiratar',
  license     => 'GPL',
);

my $stripped_out = 0;

sub translit_out {
  if(Irssi::settings_get_bool('translit') && !$stripped_out) {
    my $emitted_signal = Irssi::signal_get_emitted();
    my ($msg, $dummy1, $dummy2) = @_;

    $dummy1 =~ s/à/a/g;
    $dummy1 =~ s/á/b/g;
    $dummy1 =~ s/â/v/g;
    $dummy1 =~ s/ã/g/g;
    $dummy1 =~ s/ä/d/g;
    $dummy1 =~ s/å/e/g;
    $dummy1 =~ s/¸/jo/g;
    $dummy1 =~ s/æ/zh/g;
    $dummy1 =~ s/ç/z/g;
    $dummy1 =~ s/è/i/g;
    $dummy1 =~ s/é/j/g;
    $dummy1 =~ s/ê/k/g;
    $dummy1 =~ s/ë/l/g;
    $dummy1 =~ s/ì/m/g;
    $dummy1 =~ s/í/n/g;
    $dummy1 =~ s/î/o/g;
    $dummy1 =~ s/ï/p/g;
    $dummy1 =~ s/ğ/r/g;
    $dummy1 =~ s/ñ/s/g;
    $dummy1 =~ s/ò/t/g;
    $dummy1 =~ s/ó/u/g;
    $dummy1 =~ s/ô/f/g;
    $dummy1 =~ s/õ/h/g;
    $dummy1 =~ s/ö/c/g;
    $dummy1 =~ s/÷/ch/g;
    $dummy1 =~ s/ø/sh/g;
    $dummy1 =~ s/ù/sch/g;
    $dummy1 =~ s/ú/`/g;
    $dummy1 =~ s/û/y/g;
    $dummy1 =~ s/ü/`/g;
    $dummy1 =~ s/ı/e/g;
    $dummy1 =~ s/ş/ju/g;
    $dummy1 =~ s/ÿ/ja/g;

    $dummy1 =~ s/À/A/g;
    $dummy1 =~ s/Á/B/g;
    $dummy1 =~ s/Â/V/g;
    $dummy1 =~ s/Ã/G/g;
    $dummy1 =~ s/Ä/D/g;
    $dummy1 =~ s/Å/E/g;
    $dummy1 =~ s/¨/JO/g;
    $dummy1 =~ s/Æ/ZH/g;
    $dummy1 =~ s/Ç/Z/g;
    $dummy1 =~ s/È/I/g;
    $dummy1 =~ s/É/J/g;
    $dummy1 =~ s/Ê/K/g;
    $dummy1 =~ s/Ë/L/g;
    $dummy1 =~ s/Ì/M/g;
    $dummy1 =~ s/Í/N/g;
    $dummy1 =~ s/Î/O/g;
    $dummy1 =~ s/Ï/P/g;
    $dummy1 =~ s/Ğ/R/g;
    $dummy1 =~ s/Ñ/S/g;
    $dummy1 =~ s/Ò/T/g;
    $dummy1 =~ s/Ó/U/g;
    $dummy1 =~ s/Ô/F/g;
    $dummy1 =~ s/Õ/H/g;
    $dummy1 =~ s/Ö/C/g;
    $dummy1 =~ s/×/CH/g;
    $dummy1 =~ s/Ø/SH/g;
    $dummy1 =~ s/Ù/SCH/g;
    $dummy1 =~ s/Ú/`/g;
    $dummy1 =~ s/Û/Y/g;
    $dummy1 =~ s/Ü/`/g;
    $dummy1 =~ s/İ/E/g;
    $dummy1 =~ s/Ş/JU/g;
    $dummy1 =~ s/ß/JA/g;

    $stripped_out=1;

    Irssi::signal_emit("$emitted_signal", $msg, $dummy1, $dummy2 );
    Irssi::signal_stop();
    $stripped_out=0;
  }
}

Irssi::settings_add_bool('lookandfeel', 'translit', 1);

#output filters:
#Irssi::signal_add_first('send command', 'translit_out');
Irssi::signal_add_first('message own_public', 'translit_out');
Irssi::signal_add_first('message own_private', 'translit_out');

