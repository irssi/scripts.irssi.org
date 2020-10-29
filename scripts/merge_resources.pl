use strict;
use warnings;

use Irssi;
use Irssi::UI;

our $VERSION = '1.1'; # b76da1ea52ee366
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'merge_resources',
    description => 'Merge queries with multiple resources of the same person.',
    license     => 'GNU GPLv2 or later',
   );

# Usage
# =====
# Once loaded, this script will put all queries from one jid into
# the same window no matter which resource is used.

# Options
# =======
# /set autoclose_resource_query <time>
# * time : after how much time inactive resources should be closed
#   (0 = never)

# Commands
# ========
# /requery
# * in an existing query, change to the currently active resource. also good to
#   /bind meta-x /requery

my $autoclose_timer;

# irssi/src/fe-common/core/fe-windows.h :(
use constant DATA_LEVEL_MSG => 2;

sub _strip {
    return unless defined $_[0];
    $_[0] =~ s/\@.*?\K(?:\/[^\/]*)?$//
}

sub _req {
    my ($x, $y) = @_;
    ("$x/" eq substr $y, 0, 1+ length $x ||
     $x eq $y)
}

sub sig_silent_window_item_changed {
    Irssi::signal_stop;
}

sub sig_query_created {
    my ($query, $automatic) = @_;

    return if $query->window;

    my $name = $query->{name};
    return unless _strip($name);
    return unless $query->{server};
    return if $query->{server}->channel_find($name);

    my @queries = grep {
        $_->window && _req($name, $_->{name})
    } $query->{server}->queries;

    return unless @queries;
    $queries[0]->window->item_add($query, 1);
    Irssi::signal_add_last('window item changed', 'sig_silent_window_item_changed');
    $query->set_active;
    Irssi::signal_remove('window item changed', 'sig_silent_window_item_changed');

    $query->window->set_active
        unless $automatic;
    return;
}

sub sig_autoclose_timer {
    my $time = time;
    my $close = Irssi::settings_get_time('autoclose_resource_query') / 1000;
    for my $win (Irssi::windows) {
        _strip(my $name = $win->{active}{name});
        for my $i ($win->items) {
            next if $i->{_irssi} eq $win->{active}{_irssi};
            next unless $i->{data_level} < DATA_LEVEL_MSG;
            next unless $i->{type} eq 'QUERY';
            next unless _req($name, $i->{name});
            next unless $time - $i->{last_unread_msg} > $close;
            $i->command('unquery');
        }
    }
}

sub init {
    if (Irssi::settings_get_time('autoclose_resource_query')) {
        $autoclose_timer = Irssi::timeout_add(5000, 'sig_autoclose_timer', undef)
            unless $autoclose_timer;
    } else {
        Irssi::timeout_remove($autoclose_timer)
                if $autoclose_timer;
        $autoclose_timer = undef;
    }
}

sub sig_setup_changed {
    init();
}

sub _raise_query {
    my ($query) = @_;
    return unless $query;

    my $window = $query->window;
    return unless $window;

    my $name = $query->{name};
    return unless _strip($name);
    return unless $query->{server};
    return if $query->{server}->channel_find($name);

    for my $i ($window->items) {
        return unless $i->{type} eq 'QUERY' &&
            _req($name, $i->{name});
    }
    $query->set_active;
}

sub sig_message_private {
    my ($server, $message, $nick, $addr, $target) = @_;
    my $qname = defined $target && $nick eq $server->{nick} ? $target : $nick;

    my $query = $server->query_find($qname);
    _raise_query($query);
}

sub sig_message_xmpp_action {
    my ($server, $message, $nick, $addr, $is_query) = @_;
    if ($is_query) {
        _raise_query($server->query_find($nick));
    }
}

sub cmd_requery {
    my ($data, $server, $query) = @_;
    $data =~ s/\s*$//;

    if ($server && $data) {
        $server->command("QUERY $data");
        return;
    }

    return unless $query;
    return unless $query->{type} eq 'QUERY';

    my $name = $query->{name};
    return unless _strip($name);
    return unless $query->{server};
    return if $query->{server}->channel_find($name);

    $query->{server}->command("QUERY $name");
}

Irssi::signal_add_first('query created', 'sig_query_created');
Irssi::signal_add_first('message private', 'sig_message_private');
Irssi::signal_register({'message xmpp action' => [qw[iobject string string string int]]});
Irssi::signal_add_first('message xmpp action', 'sig_message_xmpp_action');
Irssi::signal_add('setup changed', 'sig_setup_changed');
Irssi::settings_add_time('merge_resources', 'autoclose_resource_query', 0);
Irssi::command_bind('requery', 'cmd_requery');

init();
