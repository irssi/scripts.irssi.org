#
# Usage:
# * /set twitch_channels "channel1 channel2 channel3"
# * /twitch_online to see which channels are online
#
# On load:
# * refreshes online channel list every minute
# * prints changes to the (status) window
#

use strict;
use warnings;

use English qw( -no_match_vars );
use HTTP::Tiny;
use IO::Handle;
use IPC::Open3;
use Irssi;
use JSON::PP;
use POSIX ();

our $VERSION = '0.0.1';
our %IRSSI   = (
    authors     => 'leocp1',
    name        => 'twitch_notify',
    description => 'Notify when a twitch channel comes online'
        . 'Uses Twitch v5 API',
    license => 'Public Domain',
);

## no critic (ProhibitConstantPragma) since Readonly is not in core perl

# youtube-dl's Client ID
use constant CLIENTID => 'kimne78kx3ncx6brgo4mv6wki5h1ko';

# values for channel map
use constant {
    OFFLINE   => 0,
    ONLINE    => 1,
    WASONLINE => 2,
};

# How long between refreshing live channels in ms
use constant UPDATETIMEOUT => 60_000;
## use critic

our %CHANNELS;
our $READHANDLE;
our $WRITEHANDLE;
our $REFRESHTAG;
our $UPDATETAG;

## no critic (RequireArgUnpacking)
sub uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}
## use critic

sub get_chan_names {
    return uniq( map {lc}
            ( split q{ }, Irssi::settings_get_str('twitch_channels') ) );
}

sub call_api {
    my ($resource)     = @_;
    my $endpointprefix = 'https://api.twitch.tv/kraken/';
    my $jsonresp       = undef;
    use Symbol 'gensym';
    if ( not HTTP::Tiny::can_ssl() ) {
        my $pid = open3(
            my $curl_in, my $curl_out, my $curl_err = gensym,
            'curl',      '-f', '-L',
            '--request', 'GET',
            '-H', 'Accept:application/vnd.twitchtv.v5+json; charset=UTF-8',
            '-H', 'Client-ID:' . CLIENTID,
            $endpointprefix . $resource
        );
        waitpid $pid, 0;
        if ( $CHILD_ERROR == 0 ) {
            $jsonresp = do {
                local $INPUT_RECORD_SEPARATOR = undef;
                <$curl_out>;
            };
        }
    }
    else {
        my $http = HTTP::Tiny->new;
        my $resp = $http->get(
            "$endpointprefix" . $resource,
            {   headers => {
                    'Client-ID' => CLIENTID,
                    'Accept' =>
                        'application/vnd.twitchtv.v5+json; charset=UTF-8'
                }
            }
        );
        if ( $resp->{success} ) {
            $jsonresp = $resp->{content};
        }
    }
    return ($jsonresp);
}

## no critic (ProhibitConstantPragma)
sub live_channels {
    my (@names) = @_;
    my @channels = ();
    use constant MAXUSERS   => 100;
    use constant MAXSTREAMS => 25;
    while ( my @name_slice = splice @names, 0, MAXUSERS ) {
        my $users = join q{,}, @name_slice;
        my @ids = eval {
            my ($users_resp) = call_api( 'users?login=' . $users );
            map { $_->{_id} } @{ decode_json($users_resp)->{users} };
        };
        while ( my @id_slice = splice @ids, 0, MAXSTREAMS ) {
            my $streams = join q{,}, @id_slice;
            my @live_chans = eval {
                my ($streams_resp)
                    = call_api( 'streams?channel=' . $streams );
                map { $_->{channel}->{name} }
                    @{ decode_json($streams_resp)->{streams} };
            };
            push @channels, @live_chans;
        }
    }
    return @channels;
}
## use critic

sub update {
    my $pid = fork;
    if ( not defined $pid ) {
        return;
    }
    if ( $pid > 0 ) {
        Irssi::pidwait_add($pid);
        return;
    }

    my @live_chan_names = eval { live_channels( get_chan_names() ); };

    foreach (@live_chan_names) {
        say {$WRITEHANDLE} $_
            or _msg_warn("Error writing to twitch_notify pipe: $ERRNO");
    }

    say {$WRITEHANDLE} q{+}
        or _msg_warn("Error writing to twitch_notify pipe: $ERRNO");

    close $READHANDLE
        or _msg_warn("Error closing twitch_notify read pipe: $ERRNO");
    close $WRITEHANDLE
        or _msg_warn("Error closing twitch_notify write pipe: $ERRNO");
    POSIX::_exit(1);
    return;
}

sub notify {
    for my $chan ( keys %CHANNELS ) {
        if ( $CHANNELS{$chan} == ONLINE ) {
            $CHANNELS{$chan} = WASONLINE;
        }
    }
    while ( chomp( my $chan = <$READHANDLE> ) ) {
        last if $chan eq q{+};
        if ( not defined $CHANNELS{$chan} or $CHANNELS{$chan} != WASONLINE ) {
            _msg_status("https://twitch.tv/$chan is now online.");
        }
        $CHANNELS{$chan} = ONLINE;
    }

    for my $chan ( keys %CHANNELS ) {
        if ( $CHANNELS{$chan} == WASONLINE ) {
            $CHANNELS{$chan} = OFFLINE;
            _msg_status("https://twitch.tv/$chan is now offline.");
        }
    }
    return;
}

sub online {
    my @chans = get_chan_names();
    _msg('The following channels are online:');
    foreach my $chan (@chans) {
        if ( defined $CHANNELS{$chan} and $CHANNELS{$chan} == ONLINE ) {
            _msg("* https://twitch.tv/$chan");
        }
    }
    return;
}

sub _msg {
    my ($msg) = @_;
    my $win = Irssi::active_win();
    $win->print( $msg, Irssi::MSGLEVEL_CLIENTCRAP );
    return;
}

sub _msg_status {
    my ($msg) = @_;
    my $win = Irssi::window_find_name('(status)');
    $win->print( $msg, Irssi::MSGLEVEL_CLIENTCRAP );
    return;
}

sub _msg_warn {
    my ($msg) = @_;
    my $win = Irssi::active_win();
    $win->print( $msg, Irssi::MSGLEVEL_CLIENTERROR );
    return;
}

sub load {
    Irssi::settings_add_str( 'twitch_channel_notification',
        'twitch_channels', q{} );
    pipe $READHANDLE, $WRITEHANDLE;
    $WRITEHANDLE->autoflush();
    $REFRESHTAG
        = Irssi::input_add( fileno($READHANDLE), Irssi::INPUT_READ, \&notify,
        q{} );
    update();
    $UPDATETAG = Irssi::timeout_add( UPDATETIMEOUT, \&update, q{} );
    Irssi::command_bind( 'twitch_online', \&online );
    return;
}

sub UNLOAD {
    Irssi::command_unbind( 'twitch_online', \&online );
    close $READHANDLE
        or _msg_warn("Error closing twitch_notify pipe: $ERRNO");
    close $WRITEHANDLE
        or _msg_warn("Error closing twitch_notify pipe: $ERRNO");
    input_remove($REFRESHTAG);
    timeout_remove($UPDATETAG);
    return;
}

load();
1;
