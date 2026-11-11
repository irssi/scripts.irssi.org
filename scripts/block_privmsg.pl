use strict;
use warnings;
use Irssi;
use Irssi::Irc;

our $VERSION = '1.2';
our %IRSSI = (
    authors     => "Rolle Laukkarinen",
    contact     => 'rolle@dude.fi',
    url         => 'https://github.com/rollecode/irssi-block-privmsg',
    changed     => '2026-11-11',
    name        => 'block_privmsg',
    description => 'Blocks all private messages at raw protocol level (before irssiproxy relay)',
    license     => 'Public Domain',
);

# Nicks, or nick!user@host masks where * and ? work. A full mask keeps a nick thief out.
Irssi::settings_add_str('block_privmsg', 'block_privmsg_whitelist', '');
Irssi::settings_add_str('block_privmsg', 'block_privmsg_exempt_servers', 'BitlBee');

sub mask_matches {
    my ($pattern, $mask) = @_;
    my $re = quotemeta(lc($pattern));
    $re =~ s/\\\*/.*/g;
    $re =~ s/\\\?/./g;
    return lc($mask) =~ /^$re$/;
}

sub is_whitelisted {
    my ($nick, $mask) = @_;
    my $whitelist_str = Irssi::settings_get_str('block_privmsg_whitelist');
    my @allowed = split(/\s+/, $whitelist_str);
    foreach my $allowed (@allowed) {
        if ($allowed =~ /!/) {
            return 1 if mask_matches($allowed, $mask);
        } elsif (lc($nick) eq lc($allowed)) {
            return 1;
        }
    }
    return 0;
}

sub is_exempt_server {
    my ($server) = @_;
    my $exempt_str = Irssi::settings_get_str('block_privmsg_exempt_servers');
    my @exempt = split(/\s+/, $exempt_str);
    my $tag = lc($server->{tag});
    foreach my $s (@exempt) {
        return 1 if lc($s) eq $tag;
    }
    return 0;
}

# Intercept at the rawest level - before proxy sees it
sub server_incoming {
    my ($server, $data) = @_;

    return if is_exempt_server($server);

    # Parse the raw IRC line
    # Format: :nick!user@host PRIVMSG target :message
    if ($data =~ /^:(([^!]+)![^\s]+) PRIVMSG ([^\s]+) :/) {
        my $mask = $1;
        my $nick = $2;
        my $target = $3;

        # If target is not a channel, it's a private message
        if ($target !~ /^[#&+!]/) {
            unless (is_whitelisted($nick, $mask)) {
                Irssi::signal_stop();
                return;
            }
        }
    }
}

# Hook at absolute lowest level with highest priority
Irssi::signal_add_first('server incoming', 'server_incoming');

Irssi::print("block_privmsg v1.2 loaded - blocking at raw server level");
Irssi::print('Whitelist: /set block_privmsg_whitelist nick1 nick2!user@host');
Irssi::print("Exempt servers: /set block_privmsg_exempt_servers BitlBee");
