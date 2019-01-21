# vim:ft=perl:et:
use strict;
use Irssi;

our $VERSION = '0.01';
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
    # TODO: get rid of the
    # > Irssi: Join to ... line.
    $stripped =~ m/ > / and Irssi::signal_stop();
  }
}

Irssi::signal_add_first('print text', \&sig_print_text);
