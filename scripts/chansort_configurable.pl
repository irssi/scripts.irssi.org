use strict;
use warnings;
use Irssi;
use File::Spec::Functions qw(catdir catfile);

our $VERSION = '1.1';
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
# variables are available). E.g. creating the file as:
#
#     use strict;
#     use warnings;
#
#     sub {
#         rand() <=> rand()
#     }
#
# Would sort your windows in a random order. This would be somewhat
# more useful:
#
#     use strict;
#     use warnings;
#
#     my $n = -9001;
#     my %hardcoded_positioning = (
#         freenode => {
#             '#irssi'         => $n++, # 2
#             '#freenode'      => $n++, # 3
#         },
#     );
#
#     sub {
#         # Provide a default sorter with some sane defaults
#         exists($a->{chatnet}) <=> exists($b->{chatnet})
#         ||
#         # "CHANNEL" will sort before "QUERY"
#         $a->{type} cmp $b->{type}
#         ||
#         # Cluster chatnets alphabetically
#         $a->{chatnet} cmp $b->{chatnet}
#         ||
#         # Put & channels like &bitlbee before normal channels
#         ($b->{name} =~ /^&/) <=> ($a->{name} =~ /^&/)
#         ||
#         # Allow for hardcoding the positioning of channels
#         # within a network
#         ($hardcoded_positioning{$a->{chatnet}}->{$a->{name}} || 0) <=> ($hardcoded_positioning{$b->{chatnet}}->{$b->{name}} || 0)
#         ||
#         # Default to sorting alphabetically
#         $a->{name} cmp $b->{name}
#     };
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
#    sub {
#        # This sorts the status window before anything else
#        exists($a->{chatnet}) <=> exists($b->{chatnet})
#        ||
#        # "CHANNEL" will sort before "QUERY"
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
# Note that you can return "0" to just keep the existing order the
# windows are in now. We guarantee that the the sort is stable,
# i.e. if you return 0 from the comparison of $a and $b we'll leave
# the windows in the order they're already in.

my $sort_callback_file = catfile(catdir(Irssi::get_irssi_dir(), 'scripts'), 'chansort_configurable_callback.pl');
my $sort_callback = do $sort_callback_file;

sub cmd_chansort_configurable {
    my @windows;

    for my $window (Irssi::windows()) {
        my $active = $window->{active};

        push @windows => {
            # Extract these to the top-level for easy extraction
            refnum       => $window->{refnum},
            (exists $active->{server}
             # This is for everything except the (status) window
             ? (
                 name    => $active->{name},
                 type    => $active->{type},
                 chatnet => $active->{server}->{chatnet},
             )
             : ()),
            # The raw window object with all the details.
            window => $window,
        };
    }

    # Because Irssi::windows() doesn't return these in the existing
    # order they're in we first have to sort them by their existing
    # order to make sure that we have a stable sort.
    @windows = sort { $a->{refnum} <=> $b->{refnum} } @windows;

    @windows = sort {
        (
            $sort_callback
            ? ($sort_callback->())
            : (
                # Provide a default sorter with some sane defaults
                exists($a->{chatnet}) <=> exists($b->{chatnet})
                ||
                # "CHANNEL" will sort before "QUERY"
                $a->{type} cmp $b->{type}
                ||
                # Cluster chatnets alphabetically
                $a->{chatnet} cmp $b->{chatnet}
                ||
                # Put & channels like &bitlbee before normal channels
                ($b->{name} =~ /^&/) <=> ($a->{name} =~ /^&/)
                ||
                # Default to sorting alphabetically
                $a->{name} cmp $b->{name}
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
