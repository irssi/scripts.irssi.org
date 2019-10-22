use strict;
use warnings;
use Irssi;

our $VERSION = '0.1';
our %IRSSI = (
    authors     => 'Christoffer Holmberg',
    contact     => 'skug+irssiscripts@skug.fi',
    name        => 'replace_bridge_nick.pl',
    description => 'Strips the nick of an irc bridge bot and replaces it with whatever was inside <>',
    license     => 'Public Domain',
    url         => 'http://scripts.irssi.org & https://github.com/mskug/scrips.irssi.org/blob/master/scripts/replace_bridge_nick.pl',
);

# HOWTO:
#
#   /script load replace_discord_bridge_nick.pl
#   /set bridge_botnick botnick
#

sub msg_strip_bridge_nick {
    my ($tdest, $data, $stripped) = @_;
    my $server = $tdest->{server};
    my $bridge_nick = Irssi::settings_get_str('bridge_botnick');
    return unless $server;

    if ( $stripped =~ /^.?.?.?\Q$bridge_nick\E.?.?\<[^>]+\>/s ){
        $stripped =~ /(^.?.?.?\Q$bridge_nick\E.?.?)(\<([^>]+)\>)/s;
        my ($a,$b,$c) = ($1,$2,$3);

        # Substitute bridge nick for <nick>
        s/\Q$bridge_nick\E/$c/ for $data, $stripped;
        s/\Q$b\E// for $data, $stripped;

        Irssi::signal_continue($tdest, $data, $stripped);
    }
}

Irssi::settings_add_str('bridge','bridge_botnick','D2I');
Irssi::signal_add_first( 'print text', 'msg_strip_bridge_nick' );
