# compress log files when they're rotated
# for irssi 0.7.99 by Timo Sirainen
use Irssi;
use vars qw($VERSION %IRSSI); 
$VERSION = "0.01";
%IRSSI = (
    authors	=> "Timo \'cras\' Sirainen",
    contact	=> "tss\@iki.fi", 
    name	=> "logcompress",
    description	=> "compress logfiles then they\'re rotated",
    license	=> "Public Domain",
    url		=> "http://irssi.org/",
    changed	=> "2002-03-04T22:47+0100"
);


my $compressor = "bzip2 -9";

sub sig_rotate {
        Irssi::command("exec - $compressor ".$_[0]->{real_fname});
}

Irssi::signal_add('log rotated', 'sig_rotate');
