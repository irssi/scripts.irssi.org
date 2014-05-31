#
# nickignore.pl
#
# ignore minimal changes in nicks (case, special characters)
#
# can also ignore more complex/drastic changes via variable
# 'nickignore_pattern' (use like '/set nickignore_pattern (away|afk)')

use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI); 
use strict;


$VERSION = "0.03";
%IRSSI = (
    authors     => "Kalle 'rpr' Marjola",
    contact	=> "marjola\@iki.fi", 
    name        => "ignore (minimal) nick changes",
    description => "Ignores any nick changes when only the case or special characters are modified, like 'rpr -> Rpr' or 'rpr_ -> rpr', with optional pattern for more complicated ignores",
    license	=> "Public Domain",
    url		=> "http://iki.fi/rpr/irssi/nickignore.pl",
    changed	=> "26.8.2003"
);

sub event_nick {
    my ($server, $newnick, $nick, $address) = @_;

    # (debug) Irssi::print("new: $newnick old: $nick");
    $newnick = substr($newnick, 1) if ($newnick =~ /^:/);
    
    # remove any special characters from nicks
    $newnick =~ s/[^a-zA-Z]//g;
    $nick =~ s/[^a-zA-Z]//g;

    # if the user has specific other patterns to be used, use it
    my $extra_pattern = Irssi::settings_get_str('nickignore_pattern');
    if ($extra_pattern) {
	$newnick =~ s/$extra_pattern//g;
	$nick =~ s/$extra_pattern//g;
    }

    # compare if they are identical (excluding case)
    Irssi::signal_stop() if ($newnick =~ m/^$nick$/i);
}

Irssi::signal_add('event nick', 'event_nick');

Irssi::settings_add_str  ('misc', 'nickignore_pattern', '');
