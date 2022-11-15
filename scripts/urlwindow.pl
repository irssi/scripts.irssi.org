#
# Logs all urls from #channels and /msgs in a separate window called "urls"
#

use Irssi;
use POSIX;
use vars qw($VERSION %IRSSI);
use strict;

$VERSION = "1.3";
%IRSSI = (
    authors     => "zdleaf",
    contact     => 'zdleaf@zinc.london',
    name        => "urlwindow",
    description => "Log all urls from #channels and /msgs in a separate window",
    license     => "Public Domain",
    url         => "http://irssi.org/",
);

sub sig_printtext {
    my ($dest, $text, $stripped) = @_;

    if((($dest->{level} & (MSGLEVEL_PUBLIC)) || ($dest->{level} & (MSGLEVEL_MSGS)))
    && ($text =~
        qr#((?:(https?|gopher|ftp)://[^\s<>"]+|www\.[-a-z0-9.]+)[^\s.,;<">\):])# ))
	{
        my $window = Irssi::window_find_name('urls');

        if ($dest->{level} & MSGLEVEL_PUBLIC) {
            $text = $dest->{target}.": ".$text;
        }

        $text = strftime(
            Irssi::settings_get_str('timestamp_format')." ",
            localtime
        ).$text;
        $window->print($text, MSGLEVEL_NEVER) if ($window);
    }
}

my $window = Irssi::window_find_name('urls');

if (!$window) {
	$window = Irssi::Windowitem::window_create('urls', 1);
	$window->set_name('urls');
	}

Irssi::signal_add('print text', 'sig_printtext');
