#
# Print hilighted messages & private messages to window named "hilight" for
# irssi 0.7.99 by Timo Sirainen
#
# Modded a tiny bit by znx to stop private messages entering the hilighted
# window (can be toggled) and to put up a timestamp.
#
# Changed a little by rummik to optionally show network name. Enable with
# `/set hilightwin_show_network on`
#

use strict;
use Irssi;
use POSIX;
use vars qw($VERSION %IRSSI);

$VERSION = "1.00";
%IRSSI = (
    authors     => "Timo \'cras\' Sirainen, Mark \'znx\' Sangster, Kimberly \'rummik\' Zick",
    contact     => "tss\@iki.fi, znxster\@gmail.com, git\@zick.kim",
    name        => "hilightwin",
    description => "Print hilighted messages to window named \"hilight\"",
    license     => "Public Domain",
    url         => "http://irssi.org/",
    changed     => "Thu Apr  6 15:30:25 EDT 2017"
);

sub is_ignored {
    my ($dest) = @_;

    my @ignore = split(' ', Irssi::settings_get_str('hilightwin_ignore_targets'));
    return 0 if (!@ignore);

    my %targets = map { $_ => 1 } @ignore;

    return 1 if exists($targets{"*"});
    return 1 if exists($targets{$dest->{target}});

    if ($dest->{server}) {
        my $tag = $dest->{server}->{tag};
        return 1 if exists($targets{$tag . "/*"});
        return 1 if exists($targets{$tag . "/" . $dest->{target}});
    }

    return 0;
}

sub sig_printtext {
    my ($dest, $text, $stripped) = @_;

    my $opt = MSGLEVEL_HILIGHT;
    my $shownetwork = Irssi::settings_get_bool('hilightwin_show_network');

    if(Irssi::settings_get_bool('hilightwin_showprivmsg')) {
        $opt = MSGLEVEL_HILIGHT|MSGLEVEL_MSGS;
    }
    
    if(
        ($dest->{level} & ($opt)) &&
        ($dest->{level} & MSGLEVEL_NOHILIGHT) == 0 &&
        (!is_ignored($dest))
    ) {
        my $window = Irssi::window_find_name('hilight');
        
        if ($dest->{level} & MSGLEVEL_PUBLIC) {
            $text = $dest->{target}.": ".$text;
            $text = $dest->{server}->{tag} . "/" . $text if ($shownetwork);
        } elsif ($shownetwork) {
            $text = $dest->{server}->{tag} . ": " . $text;
        }
        $text =~ s/%/%%/g;
        $window->print($text, MSGLEVEL_CLIENTCRAP) if ($window);
    }
}

my $window = Irssi::window_find_name('hilight');
Irssi::print("Create a window named 'hilight'") if (!$window);

Irssi::settings_add_bool('hilightwin','hilightwin_showprivmsg',1);
Irssi::settings_add_str('hilightwin', 'hilightwin_ignore_targets', '');
Irssi::settings_add_bool('hilightwin','hilightwin_show_network', 0);

Irssi::signal_add('print text', 'sig_printtext');

# vim:set ts=4 sw=4 et:
