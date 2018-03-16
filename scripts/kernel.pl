# Fetches the version(s) of the latest Linux kernel(s).

# /kernel

use strict;
use Irssi;
use LWP::Simple;

use vars qw($VERSION %IRSSI);

$VERSION = '0.10';
%IRSSI = (
    authors     => 'Johan "Ion" Kiviniemi',
    contact     => 'ion at hassers.org',
    name        => 'Kernel',
    description => 'Fetches the version(s) of the latest Linux kernel(s).',
    license     => 'Public Domain',
    url         => 'http://scripts.irssi.org/',
    changed     => '2018-03-11',
);

sub wget {
	my $con =get("https://www.kernel.org/finger_banner");
	return $con;
}

sub get_version {
    my @version;
    if (my $finger = wget()) {
        # The magic of the regexps :)
        @version = $finger =~ /:\s*(\S+)\s*$/gm;
        # Modify this to do whatever you want.
        Irssi::print("@version");
    }
}

Irssi::command_bind('kernel_version', 'get_version');
