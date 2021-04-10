use strict;
use warnings;
use Irssi;
use IO::Compress::Gzip qw(gzip $GzipError);
use vars qw($VERSION %IRSSI);

$VERSION = "0.03";
%IRSSI = (
    authors	=> 'vague',
    contact	=> 'vague!#irssi@fgreenode',
    name	=> "logcompress_perl",
    description	=> "compress logfiles then they're rotated, modified from original logcompress.pl to use perl modules instead",
    license	=> "Public Domain",
    url		=> "http://irssi.org/",
    changed	=> "2017-01-07T12:00+0100"
);

sub sig_rotate {
    my $input = $_[0]->{real_fname};
    gzip $input => "$input.gz" or Irssi::print("gzip failed: $GzipError", MSGLEVEL_CLIENTERROR);
    unlink $input if -e "$input.gz";
}

Irssi::signal_add('log rotated', 'sig_rotate');
