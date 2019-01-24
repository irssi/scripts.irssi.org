# vim:ft=perl:et:sw=2:ts=2:
use strict;
use Irssi;

our $VERSION = '0.02';
our %IRSSI = (
  authors     => q{Magnus Woldrich},
  contact     => q{m@japh.se},
  name        => q{ignore_join_blob},
  description => q{Ignore the blob of text displayed when (re)joining a channel},
  license     => q{MIT},
);

## ignores this:
# > Topic for #ubuntu: hi
# > Topic set by DalekSec
# > Home page for #ubuntu: https://www.ubuntu.com
# > Channel #ubuntu created Sun Nov 26 07:42:41 2006
#
# These lines have the CRAP MSGLEVEL (because they are crap) but they don't
# respond to an /ignore * CRAP:
# https://github.com/irssi/irssi/issues/992
# https://github.com/trapd00r/irssi/commit/87f38a20beda81e409a72efd323f5db45d824927

sub sig_print_text {
  my ($dest, $string, $stripped) = @_;

  if($dest->{level} & MSGLEVEL_CRAP) {
    if($stripped =~ m/Topic (for|set)|Channel [#]\S+ created|Home page for [#]\S+/) {
      Irssi::signal_stop();
    }
  }
}

Irssi::signal_add_first('print text', \&sig_print_text);
