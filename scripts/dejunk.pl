use strict;
use warnings;

use Irssi;
use Irssi::Irc;

use Data::Dumper;

our $VERSION = '1.0';
our %IRSSI = (
    authors     => 'Joost Vunderink (Garion)',
    contact     => 'joost@vunderink.net',
    name        => 'Dejunk',
    description => 'Prevents all kinds of junk from showing up',
    license     => 'Public Domain',
    url         => 'http://www.garion.org/irssi/',
    changed     => '29 September 2012 10:15:10',
);

my ($STATUS_ACTIVE, $STATUS_INACTIVE, $STATUS_UNKNOWN) = (1, 2, 3);
my $activity_filename = 'dejunk.activity.data';

# $activity{$tag}{$nickuserhost_mask} = {
#     last_msg => time(),
# }
my %activity;

sub cmd_dejunk {
    my ($args, $server, $item) = @_;
    if ($args =~ m/^(help)|(status)|(save)/i ) {
        Irssi::command_runsub ('dejunk', $args, $server, $item);
        return;
    }
    message("Use /dejunk help for help.");
}

sub cmd_dejunk_help {
    message("Dejunk is a script that prevents some clutter from showing up.");
    message("In large and/or busy channels, joins, parts, nickchanges and quits can take up a large part of the activity. ".
        "Using dejunk, all these events on large channels are hidden if the user doing ".
        "them has not said anything for a while.");
    message("This way, you only see such activity when it matters.");
    message("");
    message("Commands:");
    message("/dejunk save - Force saving of data immediately.");
    message("");
    message("Settings:");
    message("dejunk_joinpart_enabled - Hide all non-relevant joins, parts, quits and nickchanges.");
    message("dejunk_joinpart_idle_time - The amount of minutes of inactivity after which a user will be hidden.");
    message("dejunk_joinpart_min_size - Activity on channels with fewer users than this is not hidden.");
    message("dejunk_joinpart_show_unknown - If it's unknown whether the user has been active recently, ".
        "show them if this setting is true. ".
        "This is only relevant if the script has just been loaded for the first time.");
    message("dejunk_debug - set to ON to see debug messages.");
}

sub cmd_dejunk_status {
    report_status();
}

sub cmd_dejunk_save {
    message("Saving dejunk data.");
    save_data();
}

sub event_join {
    my ($server, $channel, $nick, $host) = @_;

    # Don't handle my own JOINs.
    return if ($nick eq $server->{nick});

    return if channel_size_below_joinpart_minimum($server, $channel);

    my $status = get_client_status($server->{tag}, $host, $nick);
    my $show_unknown = Irssi::settings_get_bool('dejunk_joinpart_show_unknown');

    debug(sprintf("JOIN: channel=$channel nick=$nick host=$host tag=%s", $server->{tag}));

    if ($status == $STATUS_ACTIVE) {
        debug("Showing: active client");
        return;
    }
    elsif ($status == $STATUS_UNKNOWN && $show_unknown) {
        debug("Showing: unknown client and dejunk_joinpart_show_unknown is true");
        return;
    }

    debug("Hiding: Is idle client.");
    Irssi::signal_stop();
}

sub event_part {
    my ($server, $channel, $nick, $host) = @_;

    # Don't handle my own JOINs.
    return if ($nick eq $server->{nick});

    return if channel_size_below_joinpart_minimum($server, $channel);
    
    my $status = get_client_status($server->{tag}, $host, $nick);
    my $show_unknown = Irssi::settings_get_bool('dejunk_joinpart_show_unknown');
    
    debug("PART: nick=$nick host=$host channel=$channel tag=%s", $server->{tag});

    if ($status == $STATUS_ACTIVE) {
        debug("Showing: active client");
        return;
    }
    elsif ($status == $STATUS_UNKNOWN && $show_unknown) {
        debug("Showing: unknown client and dejunk_joinpart_show_unknown is true");
        return;
    }

    debug("Hiding: Is idle client.");
    Irssi::signal_stop();
}

sub event_quit {
    my ($server, $nick, $host) = @_;

    # Don't handle my own QUITs.
    return if ($nick eq $server->{nick});

    my $channel = get_smallest_channel($server, $nick);
    if (!$channel) {
        warning("QUIT: Could not get smallest channel for nick '%s' on network '%s'!",
            $nick, $server->{tag});
        return;
    }
    return if channel_size_below_joinpart_minimum($server, $channel);

    debug("QUIT: nick=$nick host=$host tag=%s", $server->{tag});

    my $status = get_client_status($server->{tag}, $host, $nick);
    my $show_unknown = Irssi::settings_get_bool('dejunk_joinpart_show_unknown');

    if ($status == $STATUS_ACTIVE) {
        debug("Showing: active client");
        return;
    }
    elsif ($status == $STATUS_UNKNOWN && $show_unknown) {
        debug("Showing: unknown client and dejunk_joinpart_show_unknown is true");
        return;
    }

    debug("Hiding: Is idle client.");
    Irssi::signal_stop();
}

sub event_nick {
    my ($server, $newnick, $oldnick, $hostmask) = @_;
    debug("NICK: old=$oldnick new=$newnick host=$hostmask tag=%s", $server->{tag});

    my $nuh_mask = "$oldnick!$hostmask";
    if (exists $activity{$server->{tag}}{$nuh_mask}) {
        debug("Old client $oldnick was active; adding 'now' for $newnick");
        $activity{$server->{tag}}{$nuh_mask} = {
            last_msg => time(),
        }
    }

    my $channel = get_smallest_channel($server, $newnick);
    if (!$channel) {
        warning("NICK: Could not get smallest channel for nick '%s' on network '%s'!",
            $newnick, $server->{tag});
        return;
    }
    return if channel_size_below_joinpart_minimum($server, $channel);
    
    my $status = get_client_status($server->{tag}, $hostmask, $oldnick);
    my $show_unknown = Irssi::settings_get_bool('dejunk_joinpart_show_unknown');

    if ($status == $STATUS_ACTIVE) {
        debug("Showing: active client");
        return;
    }
    elsif ($status == $STATUS_UNKNOWN && $show_unknown) {
        debug("Showing: unknown client and dejunk_joinpart_show_unknown is true");
        return;
    }

    debug("Hiding: Is idle client.");
    Irssi::signal_stop();
}

sub event_public {
    my ($server, $data, $nick, $hostmask, $channel) = @_;

    # Don't handle my own messages.
    return if ($nick eq $server->{nick});

    debug("MSG: nick=$nick hostmask=$hostmask tag=%s channel=$channel", $server->{tag});
    my $nuh_mask = "$nick!$hostmask";
    $activity{$server->{tag}}{$nuh_mask} = {
        last_msg => time(),
    }
}

sub is_active_client {
    my ($tag, $host, $nick) = @_;

    my $status = get_client_status($tag, $host, $nick);

    if ($status == $STATUS_ACTIVE) {
        return 1;
    }

    return;
}

sub get_client_status {
    my ($tag, $host, $nick) = @_;

    my $nuh_mask = "$nick!$host";
    if (exists $activity{$tag}{$nuh_mask}) {
        my $d = $activity{$tag}{$nuh_mask};
        if (time() - $d->{last_msg} < 60 * Irssi::settings_get_int('dejunk_joinpart_idle_time')) {
            return $STATUS_ACTIVE;
        }
        else {
            return $STATUS_INACTIVE;
        }
    }

    return $STATUS_UNKNOWN;
}

sub channel_size_below_joinpart_minimum {
    my ($server, $channel) = @_;
    my $chan_obj = $server->channel_find($channel);
    if (!$chan_obj) {
        warning("Minsize check: could not find channel '%s' on network '%s'!",
            $channel, $server->{tag});
        return 1;
    }
    my @nicks = $chan_obj->nicks();
    if (scalar @nicks < Irssi::settings_get_int('dejunk_joinpart_min_size')) {
        return 1;
    }
    return 0;
}

sub get_smallest_channel {
    my ($server, $nick) = @_;

    my $count = 999999999;
    my $found_channel;
    for my $channel ($server->channels()) {
        if ($channel->nick_find($nick)) {
            my @nicks = $channel->nicks();
            if (scalar @nicks < $count) {
                $count = scalar @nicks;
                $found_channel = $channel;
            }
        }
    }

    return $found_channel->{name};
}

sub load_data {
    load_activity_data();
}

sub load_activity_data {
    my $fn = Irssi::get_irssi_dir() . '/' . $activity_filename;
    
    if (!-r $fn) {
        return;
    }

    open my $fh, '<', $fn;
    if (!$fh) {
        error("Could not read dejunk activity data from $fn: $!");
        return;
    }
    $/ = undef;
    my $file_contents = <$fh>;
    eval {
        my $data = eval $file_contents;
        %activity = %$data;
    };
    if ($@) {
        error("Error loading activity data from $fn: $@");
    }
    else {
        message("Activity data loaded from $activity_filename");
    }
    close $fh;
}

sub save_data {
    save_activity_data();
}

sub save_activity_data {
    clean_activity_data();
    my $fn = Irssi::get_irssi_dir() . '/' . $activity_filename;
    open my $fh, '>', $fn;
    if (!$fh) {
        error("Could not write dejunk activity data to $fn: $!");
        return;
    }
    $Data::Dumper::Indent = 1;
    $Data::Dumper::Purity = 1;
    $Data::Dumper::Sortkeys = 1;
    $Data::Dumper::Terse = 1;
    print $fh Dumper \%activity;
    close $fh;
}

sub clean_activity_data {
    my $threshold_time = time() - 10 * Irssi::settings_get_int('dejunk_joinpart_idle_time');
    # Go through all clients and remove the ones that haven't performed any action
    # in the past 10 * joinpart_idle_time seconds.
    # The factor 10 is here to make sure that if the user increases joinpart_idle_time
    # (by no more than a factor 10), we will still have enough data available for the
    # script to work properly.
    for my $tag (keys %activity) {
        for my $nuh_mask (keys %{ $activity{$tag} }) {
            if ($activity{$tag}{$nuh_mask}{last_msg} < $threshold_time) {
                debug("Deleting old data for $tag:$nuh_mask");
                delete $activity{$tag}{$nuh_mask};
            }
        }
    }
}

sub report_status {
    message("Status report:");
    if (Irssi::settings_get_bool('dejunk_joinpart_enabled')) {
        message("Join/part hiding enabled.");
        my @tags = keys %activity;
        my $num_hosts = 0;
        for my $tag (@tags) {
            $num_hosts += scalar keys %{ $activity{$tag} };
        }
        message(sprintf "Joins, parts, nickchanges, and quits are only shown for clients that have been active ".
            "in the past %d minutes (setting 'dejunk_joinpart_idle_time').", (Irssi::settings_get_int('dejunk_joinpart_idle_time')));
        message(sprintf "Joins, parts, nickchanges, and quits are always shown for channels with fewer than %d clients ".
            "(setting 'dejunk_joinpart_min_size').",
            Irssi::settings_get_int('dejunk_joinpart_min_size'));
        message(sprintf "Currently, there is activity data on %d hostmask(s) in %d tag(s).", $num_hosts, scalar @tags);
    }
    else {
        message("Join/part hiding disabled.");
    }
}

sub UNLOAD {
    message("Dejunk is being unloaded - saving data.");
    save_data();
}

sub debug {
    if (Irssi::settings_get_bool('dejunk_debug')) {
        _log('debug', @_);
    }
}

sub error {
    _log('error', @_);
}

sub warning {
    _log('warning', @_);
}

sub message {
    _log('message', @_);
}

sub _log {
    my ($level, $fmt, @args) = @_;
    my $str = sprintf($fmt, @args);
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, "dejunk_$level", $str);
}

Irssi::command_bind('dejunk',        'cmd_dejunk');
Irssi::command_bind('dejunk help',   'cmd_dejunk_help');
Irssi::command_bind('dejunk status', 'cmd_dejunk_status');
Irssi::command_bind('dejunk save',   'cmd_dejunk_save');

Irssi::settings_add_bool('dejunk', 'dejunk_joinpart_enabled', 1);
Irssi::settings_add_int( 'dejunk', 'dejunk_joinpart_min_size', 40);
Irssi::settings_add_int( 'dejunk', 'dejunk_joinpart_idle_time', 15);
Irssi::settings_add_bool('dejunk', 'dejunk_joinpart_show_unknown', 1);
Irssi::settings_add_bool('dejunk', 'dejunk_debug', 0);

Irssi::signal_add({
    'server connected'              => \&event_connected,
    'server disconnected'           => \&event_disconnected,
    'message join'                  => \&event_join,
    'message part'                  => \&event_part,
    'message quit'                  => \&event_quit,
    'message nick'                  => \&event_nick,
});
Irssi::signal_add_last('message public', \&event_public);

Irssi::theme_register(
    [
     'dejunk_error',
     '{line_start}{hilight Dejunk:} [%RERROR%n] $0',

     'dejunk_warning',
     '{line_start}{hilight Dejunk:} [%YWARN%n] $0',

     'dejunk_message',
     '{line_start}{hilight Dejunk:} $0',

     'dejunk_debug',
     '{line_start}{hilight Dejunk:} [DEBUG] $0',
    ],
);

load_data();
report_status();
message("Type /dejunk help for help.");
