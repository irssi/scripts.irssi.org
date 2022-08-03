use strict;
use warnings;
use Irssi;

my $VERSION = '1.00';
my %IRSSI = (
    authors => 'Mason Loring Bliss',
    contact => 'mason@blisses.org',
    name => 'Graze',
    description => 'Follow set order in seeing active channels.',
    license => 'CC0'
);

Irssi::settings_add_str("graze", "graze_priority", "oftc libera magnet efnet");

sub graze
{
    my ($command, $message) = split /\s/, shift, 2;
    $command //= "";
    $message //= "";

    if ($command eq "next") {
        my %by_refnum;
        for (Irssi::windows()) {
            $by_refnum{$$_{refnum}}{data_level} = $$_{data_level};
            if ($by_refnum{$$_{refnum}}{data_level} > 2) {
                $by_refnum{$$_{refnum}}{data_level}
                  += ($$_{hilight_color} eq '' ? 1 : 0);
            }
            $by_refnum{$$_{refnum}}{chatnet} = $$_{active_server}{chatnet};
            $by_refnum{$$_{refnum}}{window} = $_;
        }

        my @windowkeys;
        for (sort {$a <=> $b} keys %by_refnum) {
            push @windowkeys, $_;
        }

        my @priorities = split(/ /, Irssi::settings_get_str('graze_priority'));

        # Find a priority highlight.
        my $found = 0;
        for (@windowkeys) {
            if ($by_refnum{$_}{data_level} == 4) {
                $by_refnum{$_}{window}->set_active;
                $found = 1;
                last;
            }
        }
        
        # Find a non-priority highlight.
        if (! $found) {
            for (@windowkeys) {
                if ($by_refnum{$_}{data_level} == 3) {
                    $by_refnum{$_}{window}->set_active;
                    $found = 1;
                    last;
                }
            }
        }

        # Find an active window in a preferred network.
        if (! $found) {
            PREFERRED: for (@windowkeys) {
                if ($by_refnum{$_}{data_level} == 2) {
                    for my $priority (@priorities) {
                          if ($by_refnum{$_}{chatnet} eq $priority) {
                              $by_refnum{$_}{window}->set_active;
                              $found = 1;
                              last PREFERRED;
                          }
                    }
                }
            }
        }

        # Find an active window.
        if (! $found) {
            for (@windowkeys) {
                if ($by_refnum{$_}{data_level} == 2) {
                    $by_refnum{$_}{window}->set_active;
                    $found = 1;
                    last;
                }
            }
        }

    } elsif ($command eq "prioritize") {
        my %prio;
        for (split(/ /, Irssi::settings_get_str('graze_priority'))) {
            $prio{$_} = 1;
        }
        $prio{$message} = 1;
        Irssi::settings_set_str("graze_priority", join(' ', keys %prio));
        print "priorities:  ${\Irssi::settings_get_str('graze_priority')}";

    } elsif ($command eq "deprioritize") {
        my %prio;
        for (split(/ /, Irssi::settings_get_str('graze_priority'))) {
            $prio{$_} = 1;
        }
        delete $prio{$message};
        Irssi::settings_set_str("graze_priority", join(' ', keys %prio));
        print "priorities:  ${\Irssi::settings_get_str('graze_priority')}";

    } else {
        help("graze");
        return;
    }
}

sub help
{
    if ($_[0] =~ /^graze\b/i) {
        print "-" x 60;
        print "graze next";
        print "    move to next interesting window";
        print "graze prioritize foo";
        print "    add chatnet foo to priority chatnet list";
        print "graze deprioritize foo";
        print "    remove chatnet foo from priority chatnet list";
        print "(Active channels in priority chatnets will show up first.)";
        print "";
        print "priorities:  ${\Irssi::settings_get_str('graze_priority')}";
    }
}

Irssi::command_bind "graze" => \&graze;
Irssi::command_bind "graze next" => \&graze;
Irssi::command_bind "graze prioritize" => \&graze;
Irssi::command_bind "graze deprioritize" => \&graze;
Irssi::command_bind "help" => \&help;
