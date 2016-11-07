use strict;
use warnings;
use Irssi;
use File::Spec::Functions qw(catdir catfile);

our $VERSION = '1.2';
our %IRSSI = (
    authors     => 'Ævar Arnfjörð Bjarmason',
    contact     => 'avarab@gmail.com',
    name        => 'chansort_configurable',
    description => "Sort channels & query windows in a configurable way, based on Peder Stray's chansort.pl",
    license     => 'GPL',
    url         => 'http://scripts.irssi.org & https://github.com/avar/dotfiles/blob/master/.irssi/scripts/chansort_configurable.pl',
);

# HOWTO:
#
#   /load chansort_configurable.pl
#   /set chansort_configurable_autosort ON
#
# This is a plugin that allows you to sort your windows in any
# arbitrary way using a callback you provide. I originally forked this
# from chansort.pl on https://scripts.irssi.org which is a similar
# plugin that just sorts the windows in a pre-determined order.
#
# By default this plugin will sort things in a pre-determined order,
# but you can create a
# ~/.irssi/scripts/chansort_configurable_callback.pl file with a
# subroutine that we'll call inside sort() (so the $a and $b sort
# variables are available).
#
# The values of $a and $b are going to be hashes like:
#
#    {
#        refnum  => Int,    # e.g. 1, 50, ...
#        type    => Str,    # e.g. "SERVER", "CHANNEL"
#        chatnet => Str,    # e.g. "freenode", "oftc", ...
#        name    => Str,    # e.g. "(status)", "#irssi", "", ...
#        window  => Object, # The Irssi::Window object
#    }
#
# The "window" object contains the refnum/type/chatnet/name data
# somewhere, but we've extracted it for convenience since depending on
# the state & type of the window the values can be anywhere in
# window.active.*, window.active.server.*, window.active_server.* or
# window.*
#
# Note that you can return "0" to just keep the existing order the
# windows are in now. We guarantee that the the sort is stable,
# i.e. if you return 0 from the comparison of $a and $b we'll leave
# the windows in the order they're already in. In other words, the
# window objects passed to your sort() routine will be pre-sorted in
# "refnum" order.
#
# Below we have examples of how you might create the
# ~/.irssi/scripts/chansort_configurable_callback.pl
# file. E.g. creating it as:
#
#    use strict;
#    use warnings;
#
#    sub {
#        rand() <=> rand()
#    };
#
# Would sort your windows in a random order. This would be somewhat
# more useful:
#
#    use strict;
#    use warnings;
#
#    my $n = -9001;
#    my %hardcoded_positioning = (
#        freenode => {
#            '#irssi'         => $n++, # 2
#            '#freenode'      => $n++, # 3
#        },
#    );
#
#    sub {
#        # We sort the "(status) window first before anything else
#        ($b->{name} eq "(status)") <=> ($a->{name} eq "(status)")
#        ||
#        # We want "CHANNEL" at the beginning and "QUERY" at the end
#        # regardless of chatnet.
#        $a->{type} cmp $b->{type}
#        ||
#        # Cluster chatnets alphabetically
#        $a->{chatnet} cmp $b->{chatnet}
#        ||
#        # Put & channels like &bitlbee before normal channels
#        ($b->{name} =~ /^&/) <=> ($a->{name} =~ /^&/)
#        ||
#        # Allow for hardcoding the positioning of channels
#        # within a network
#        ($hardcoded_positioning{$a->{chatnet}}->{$a->{name}} || 0) <=> ($hardcoded_positioning{$b->{chatnet}}->{$b->{name}} || 0)
#        ||
#        # Default to sorting alphabetically
#        $a->{name} cmp $b->{name}
#    };
#
# The above sorter will sort channels before queries, and networks
# alphabetically, but will make the #irssi channel be the first
# channel on the freenode network.
#
# I actually prefer to have my CHANNEL windows sorted in a particular
# order, but have the QUERY windows accumulate at the end of the list
# so I can page backwards through the window list through my most
# recent QUERY chats, so this is a modification of the above that does
# that:
#
#    use strict;
#    use warnings;
#
#    # See above for how this might be defined.
#    my %hardcoded_positioning;
#
#    sub {
#        # We sort the "(status) window first before anything else
#        ($b->{name} eq "(status)") <=> ($a->{name} eq "(status)")
#        ||
#        # We want "CHANNEL" at the beginning and "QUERY" at the end
#        # regardless of chatnet.
#        $a->{type} cmp $b->{type}
#        ||
#        # For the rest of this I want channels to be ordered by chatnet
#        # and have hardcoded positions or an alphabetical sort, but for
#        # QUERY I don't want any further sorting, I just want a stable
#        # sort, this is so I can page back from the back of the list to
#        # find my most recent queries.
#        (
#            ($a->{type} eq 'CHANNEL' and $b->{type} eq 'CHANNEL')
#            ?
#            (
#                # Cluster chatnets alphabetically
#                $a->{chatnet} cmp $b->{chatnet}
#                ||
#                # Put & channels like &bitlbee before normal channels
#                ($b->{name} =~ /^&/) <=> ($a->{name} =~ /^&/)
#                ||
#                # Allow for hardcoding the positioning of channels
#                # within a network
#                ($hardcoded_positioning{$a->{chatnet}}->{$a->{name}} || 0) <=> ($hardcoded_positioning{$b->{chatnet}}->{$b->{name}} || 0)
#                ||
#                # Default to sorting alphabetically
#                $a->{name} cmp $b->{name}
#            )
#            : 0
#        )
#    };
#
# The last example here is the default sorter you'll get if you don't
# create your own by creating the
# ~/.irssi/scripts/chansort_configurable_callback.pl file. Obviously
# the use of %hardcoded_positioning here is a no-op, but you could
# copy the example to your own file and fill it up to hardcode the
# sorting of certain channels.
my $sort_callback_file = catfile(catdir(Irssi::get_irssi_dir(), 'scripts'), 'chansort_configurable_callback.pl');
my $sort_callback = do $sort_callback_file;

sub cmd_chansort_configurable {
    my @windows;

    for my $window (Irssi::windows()) {
        my $active = $window->{active};
        my $active_server = $window->{active_server};

        push @windows => {
            # We extract some values to the top-level for ease of use,
            # i.e. you don't have to go and unpack values from
            # window.active.*, window.active.server.*,
            # window.active_server.* or window.* which are often
            # logically the same sort of thing, e.g. the name of the
            # window.
            refnum => $window->{refnum},

            # We have a window.active for windows that are not
            # type=SERVER and *connected* to a server, but if we're
            # disconnected or have some otherwise disowned window we
            # might also not have window.active, but will have
            # window.active_server.
            (
                type => ($active->{type} || $active_server->{type}),

                # Sometimes window.active.server.chatnet won't be
                # there, but window.active_server.chatnet is always
                # there, and these seem to be a reference to the same
                # object.
                chatnet => ($active_server->{chatnet}),

                # If we have a window.active.name it'll be
                # e.g. "#irssi", but otherwise we'll have
                # e.g. window.name as "(status)" or just "".
                name => ($active->{name} || $window->{name}),
            ),

            # The raw window object with all the details.
            window => $window,
        };
    }

    # Because Irssi::windows() doesn't return these in the existing
    # order they're in we first have to sort them by their existing
    # order to make sure that we have a stable sort.
    @windows = sort { $a->{refnum} <=> $b->{refnum} } @windows;

    @windows = sort {
        # Dummy lexical just so I can copy/paste the default sort
        # example here and it'll compile.
        my %hardcoded_positioning;
        (
            $sort_callback
            ? ($sort_callback->())
            : (
                # We sort the "(status) window first before anything
                # else
                ($b->{name} eq "(status)") <=> ($a->{name} eq "(status)")
                ||
                # We want "CHANNEL" at the beginning and "QUERY" at
                # the end regardless of chatnet.
                $a->{type} cmp $b->{type}
                ||
                # For the rest of this I want channels to be ordered
                # by chatnet and have hardcoded positions or an
                # alphabetical sort, but for QUERY I don't want any
                # further sorting, I just want a stable sort, this is
                # so I can page back from the back of the list to find
                # my most recent queries.
                (
                    ($a->{type} eq 'CHANNEL' and $b->{type} eq 'CHANNEL')
                    ?
                    (
                        # Cluster chatnets alphabetically
                        $a->{chatnet} cmp $b->{chatnet}
                        ||
                        # Put & channels like &bitlbee before normal
                        # channels
                        ($b->{name} =~ /^&/) <=> ($a->{name} =~ /^&/)
                        ||
                        # Allow for hardcoding the positioning of
                        # channels within a network
                        ($hardcoded_positioning{$a->{chatnet}}->{$a->{name}} || 0) <=> ($hardcoded_positioning{$b->{chatnet}}->{$b->{name}} || 0)
                        ||
                        # Default to sorting alphabetically
                        $a->{name} cmp $b->{name}
                    )
                    : 0
                )
            )
        )
    } @windows;

    my $i = 0;
    for my $window (@windows) {
        $i++;
        $window->{window}->command("WINDOW MOVE $i");
    }

    return;
}

sub sig_chansort_configurable_trigger {
    return unless Irssi::settings_get_bool('chansort_configurable_autosort');
    cmd_chansort_configurable();
}

Irssi::command_bind('chansort_configurable', 'cmd_chansort_configurable');
Irssi::settings_add_bool('chansort_configurable', 'chansort_configurable_autosort', 0);
Irssi::signal_add_last('window item name changed', 'sig_chansort_configurable_trigger');
Irssi::signal_add_last('channel created', 'sig_chansort_configurable_trigger');
Irssi::signal_add_last('query created', 'sig_chansort_configurable_trigger');
