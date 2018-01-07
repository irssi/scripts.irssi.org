use strict;
use warnings;

use Irssi;
use Irssi::Irc;

use Data::Dumper;

#use Devel::NYTProf;

our $VERSION = '1.2';
our %IRSSI = (
    authors     => 'Joost Vunderink (Garion)',
    contact     => 'joost@vunderink.net',
    name        => 'Dejunk',
    description => 'Prevents all kinds of junk from showing up',
    license     => 'Public Domain',
    url         => 'http://www.garion.org/irssi/',
    changed     => '2018-01-07',
);

my ($STATUS_ACTIVE, $STATUS_INACTIVE, $STATUS_UNKNOWN) = (1, 2, 3);
my $activity_filename = 'dejunk.activity.data';

# $activity{$tag}{$nickuserhost_mask} = {
#     last_msg => time(),
# }
my %activity;

# $ignorlist{$server/$channel}
my %ignorlist;

# marker for the refresh
my $time_tag_ignorlist;
my $time_tag_clean;

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
    message("In large and/or busy channels, joins, parts, nickchanges and");
    message("quits can take up a large part of the activity. ");
    message("Using dejunk, all these events on large channels are hidden");
    message("if the user doing them has not said anything for a while.");
    message("This way, you only see such activity when it matters.");
    message("");
    message("Dejunk will save its data when it unloads, so when you upgrade");
    message("it, or restart irssi quickly, it will remember ");
    message("which nicks were active recently on which networks.");
    message("");
    message("Commands:");
    message(" /dejunk status");
    message("   Show which activity dejunk has seen recently.");
    message(" /dejunk save");
    message("   Force saving of data immediately.");
    message("   Should not be needed at all.");
    message("");
    message("Settings:");
    message(" dejunk_joinpart_enabled");
    message("   Hide all non-relevant joins, parts, quits and nickchanges.");
    message(" dejunk_joinpart_idle_time");
    message("   The amount of minutes of inactivity after which a user");
    message("   will be hidden.");
    message(" dejunk_joinpart_min_size");
    message("   Activity on channels with fewer users than this");
    message("   is not hidden.");
    message(" dejunk_joinpart_show_unknown");
    message("   If it's unknown whether the user has been active recently, ");
    message("   show them if this setting is true. This is only relevant");
    message("   if the script has just been loaded for the first time.");
    message(" dejunk_debug");
    message("   set to ON to see debug messages.");
    message("dejunk_update_ignorlist_time");
    message("   set the update time in seconds for the ignorlist");
    message("dejunk_clean_data_time");
    message("   set the repeat time in seconds for the shrinking function");
    message("   clean_activity_data");
    message("");
    message("You can see the current values of all dejunk settings via");
    message("the following command:");
    message("    /set dejunk");
    message("You can change a setting via commands like this one:");
    message("    /set dejunk_joinpart_min_size 100");
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

    return if is_ignor_channel($server,$channel);

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

    return if is_ignor_channel($server,$channel);
    
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

    return if is_ignor_nick($server,$nick);

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

    return if is_ignor_nick($server,$newnick);
    
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

sub get_channel_str {
    my $channel=$_[0];
    my $cn=$channel->{'server'}->{'tag'}."/".$channel->{'name'};
    #print $cn;
    return $cn;
}
sub list_channels {
    my @cl = Irssi::channels;
    foreach (@cl) {
        my @nicks= $_->nicks();
        my $cn=get_channel_str($_);
        #print $cn," ",$#nicks," ",$_->{"_irssi"};

        if (!exists($ignorlist{$cn})) {
            $ignorlist{$cn}=0;
        }
        if ($#nicks > Irssi::settings_get_int('dejunk_joinpart_min_size')) {
            $ignorlist{$cn}=1;
        }
    }
}

sub is_ignor_channel {
    (my $server, my $channel)=@_;
    my $cn=$server->{"tag"}."/".$channel;
    my $ci=1;
    if (exists($ignorlist{$cn})) {
        if ($ignorlist{$cn} >0) {
            $ci=0;
        }
    }
    #print "is_ignor_channel: ",$cn," ",$ci;
    return $ci;
}

sub is_ignor_nick {
    (my $server, my $nick)=@_;
    my $res=1;
    foreach my $channel ($server->channels()) {
        if ($channel->nick_find($nick)) {
            my $cn=get_channel_str($channel);
            if (exists($ignorlist{$cn})) {
                if ($ignorlist{$cn} >0) {
                    $res=0;
                }
            }
        }
    }
    #print "is_ignor_nick: $server->{'tag'} $nick $res";
    return $res;
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
    local $/;
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
#    DB::finish_profile();
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

sub setup_change {
    if ($time_tag_ignorlist) {
        Irssi::timeout_remove($time_tag_ignorlist)
    }
    $time_tag_ignorlist=
        Irssi::timeout_add(Irssi::settings_get_int('dejunk_update_ignorlist_time')
            *1000,'list_channels',0);

    if ($time_tag_clean) {
        Irssi::timeout_remove($time_tag_clean)
    }
    $time_tag_clean=
        Irssi::timeout_add(Irssi::settings_get_int('dejunk_clean_data_time')
            *1000,'clean_activity_data',0);
}

Irssi::command_bind('dejunk',        'cmd_dejunk');
Irssi::command_bind('dejunk help',   'cmd_dejunk_help');
Irssi::command_bind('dejunk status', 'cmd_dejunk_status');
Irssi::command_bind('dejunk save',   'cmd_dejunk_save');

Irssi::settings_add_bool('dejunk', 'dejunk_joinpart_enabled', 1);
Irssi::settings_add_int( 'dejunk', 'dejunk_joinpart_min_size', 40);
Irssi::settings_add_int( 'dejunk', 'dejunk_joinpart_idle_time', 15);
Irssi::settings_add_int( 'dejunk', 'dejunk_update_ignorlist_time', 60);
Irssi::settings_add_int( 'dejunk', 'dejunk_clean_data_time', 60*10);
Irssi::settings_add_bool('dejunk', 'dejunk_joinpart_show_unknown', 1);
Irssi::settings_add_bool('dejunk', 'dejunk_debug', 0);

Irssi::signal_add({
    #'server connected'              => \&event_connected,
    #'server disconnected'           => \&event_disconnected,
    'message join'                  => \&event_join,
    'message part'                  => \&event_part,
    'message quit'                  => \&event_quit,
    'message nick'                  => \&event_nick,
});
Irssi::signal_add_last('message public', \&event_public);
Irssi::signal_add('setup changed', 'setup_change');

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

setup_change();
list_channels();

load_data();
report_status();
message("Type /dejunk help for help.");
