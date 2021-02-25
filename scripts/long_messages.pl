use strict;
use warnings;
use experimental 'signatures';

# long_messages script for Irssi
#
# Automatically downloads and displays long messages from matrix
#
# Requirements: curl (or another http fetch program)
#
# Warning. This script downloads random URLs from the Internet.
#
# Options
# =======
# /set long_messages_nick <template>
# * this template will be prefixed to each line from the long message,
#   for example <$0> to show the nick inside <>
#
# /set long_messages_fetch_command <command>
# * the command that is run to download the long message, by default
#   "curl -Ssf". It should print the message to standard output.
#
# /set long_messages_url_whitelist <url list>
# * if you desire to make the script a bit more safe, list the allowed
#   domains to download long messages from (space separated)
#

our $VERSION = '0.2'; # 3c12c3328a1c895
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'long_messages',
    description => 'Automatically downloads and displays long messages from matrix.',
    license     => 'ISC',
   );

use Irssi;

sub _shquote {
    "'" . ($_[0] =~ s/'/'"'"'/gr) . "'";
}

sub _awkquote {
    '"' . ($_[0] =~ s/"\\/\\$&/gr) . '"';
}

sub _in_whitelist ($url) {
    my %re = (
	"\\*" => '[^/]*?',
	"\\*\\*" => '.*?',
       );
    my $wlstr = Irssi::settings_get_str('long_messages_url_whitelist');
    $wlstr =~ s/\s*$//;
    if ($wlstr eq '*') {
	return 1;
    }
    for my $wh (split ' ', $wlstr) {
	$wh =~ s{^https?://}{};
	if ($wh !~ /\//) {
	    $wh .= '/**';
	}
	$wh = quotemeta $wh;
	$wh =~ s/(\\\*\\\*|\\\*)/$re{$1}/g;
	if ($url =~ m{^https?://$wh$}) {
	    return 1;
	}
    }
    return;
}

sub curl_long_messages ($server, $msg, $nick, $addr, $target) {
    my $item;

    if ($msg !~ m{^sent a long message: (?:.*?) < (https?://.*?) >$}) {
	return;
    }
    my $url = $1;
    unless (_in_whitelist($url)) {
	return;
    }

    if ($server->ischannel($target)) {
	$item = $server->channel_find($target);
    } else {
	$item = $server->query_find( lc $target eq lc $server->{nick} ? $nick : $target );
    }

    unless ($item) {
	return;
    }
    my $prefix = Irssi::settings_get_str('long_messages_nick');
    unless ($prefix =~ s{\$[0*]}{$nick}) {
	$prefix = $nick . $prefix;
    }

    my $command = Irssi::settings_get_str('long_messages_fetch_command');
    my $url_quoted = _shquote($url);
    unless ($command =~ s{\$[0*]}{$url_quoted}) {
	$command = "$command $url_quoted";
    }

    $item->window->command('exec - '.$command.' | awk '._shquote('{print '._awkquote($prefix).' $0}') )
}

Irssi::signal_add('ctcp action', \&curl_long_messages);
Irssi::settings_add_str('lookandfeel', 'long_messages_nick', '$0 │ ');
Irssi::settings_add_str('misc', 'long_messages_fetch_command', 'curl -Ssf $0');
Irssi::settings_add_str('misc', 'long_messages_url_whitelist', '*/_matrix/media/*/download/**');
