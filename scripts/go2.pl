use strict;
use vars qw($VERSION %IRSSI);
use Irssi;
use Irssi::TextUI;

$VERSION = '1.0';
%IRSSI = (
    authors     => 'cxreg',
    contact     => 'cxreg@pobox.com',
    name        => 'go2',
    description => 'Switch to the window with the given name or item',
    license     => 'Public Domain',
    url         => 'http://genericorp.net/~count/irssi/go',
    changed     => '2008-02-22',
);

# Tab complete (0.8.12+)
sub signal_complete_go {
    my ( $complist, $window, $word, $linestart, $want_space ) = @_;

    # This is cargo culted but I think it's right
    my $k = Irssi::parse_special('$k');
    return unless ( $linestart =~ /^\Q${k}\Ego/i );

    # call the go command
    $window->command("go $word");

    # we've come back from the go command and cleaned up the command line,
    # remove previous input and finish up
    @$complist = ();
    Irssi::gui_input_set('');
    Irssi::signal_stop();
}

# Only do this in irssi 0.8.12 or better since input mangling didn't exist until then
if ( Irssi::version >= 20070804 ) {
    Irssi::signal_add_first( 'complete word', 'signal_complete_go' );
}

sub cmd_go2 {
    my ($window, $suggestion, @matches);
    my $buf = '';

    # get a complete list of current windows
    my @all_windows = Irssi::windows();

    # Parse passed in argument
    if ( length $_[0] ) {
        $buf = shift;

        # this messes up a quick jump to any channel or window named "help",
        # so maybe this should be an option
        if ( $buf eq 'help' ) {
            _help();
            return;
        }

        @matches = _match( $buf, @all_windows );

        my @non_cur = grep { !$_->{active_win} } @matches;
        if ( @matches and !@non_cur ) {
            # The only match is the current window, bail out
            return;
        }

        # First look for an (non-current) exact match
        my @exact_matches = grep { $_->{exact} } @non_cur;
        if ( @exact_matches == 1 ) {
            $exact_matches[0]->{window}->set_active;
            return;
        }

        # Then look for any single (non-current) match
        if ( @non_cur == 1 ) {
            $non_cur[0]->{window}->set_active;
            return;
        }

        # If there's only 2 matches, we now know neither is current
        # so just pick one.  This is ok because the next call would
        # "toggle" to the other.  More than 2, though, and we'd end up
        # ignoring windows
        if ( @matches == 2 ) {
            $matches[0]->{window}->set_active;
            return;
        }

        # Otherwise, fall through to normal prompt
        $suggestion = $matches[0];
    }

    while (1) {
        # display the current input and suggestion
        _draw_suggestion( $buf, $suggestion );

        # read input one character at a time
        my $chr = getc;

        # break out on Enter
        if ( $chr =~ /[\r\n]/ ) {
            $window = $suggestion;
            last;
        }

        # Esc means "stop trying"
        elsif ( ord($chr) == 27 ) {
            last;
        }

        # Tab to cycle through suggestions
        elsif ( ord($chr) == 9 ) {
            if(@matches) {
                # get matches if we don't have any yet
                push @matches, grep { $_ } shift @matches;
            } else {
                # otherwise switch to the next one
                @matches = _match( $buf, @all_windows );
            }

            $suggestion = $matches[0];
        }

        # ^U means wipe out the input.  we might want to actually read this
        # from the user's keybinding (for erase_line or maybe erase_to_beg_of_line)
        # instead of assuming ^U
        elsif ( ord($chr) == 21 ) {
            $buf = '';
            @matches = _match( $buf, @all_windows );
            $suggestion = undef;
        }

        # handle backspace and delete
        elsif ( ord($chr) == 127 or ord($chr) == 8 ) {
            # remove the last char
            $buf = substr( $buf, 0, length($buf) - 1 );

            # get suggestions again
            if ( @matches = _match( $buf, @all_windows ) ) {
                $suggestion = $buf ? $matches[0] : undef;
            } else {
                $suggestion = undef;
            }
        }

        # regular input
        else {
            # create a temporary new buffer
            my $tmp = $buf . $chr;

            if ( @matches = _match($tmp, @all_windows) ) {
                # if the new character results in a match, keep it
                $buf = $tmp;
                $suggestion = $buf ? $matches[0] : undef;
            } else {
                # vbell on mistype
                print STDOUT "\a";
            }
        }
    }

    # go to the selected window if there is one
    if ($window) {
        $window->{window}->set_active;
    }

    # refresh the screen to get the regular prompt back if needed
    Irssi::command('redraw')
}

Irssi::command_bind('go', 'cmd_go2', 'go2.pl');

sub _draw_suggestion {
    my ( $b, $s ) = @_;

    # $b might have a space and a second token which is a tag, remove it
    # since that's getting displayed separately anyway
    my $tag;
    if ( $b =~ s/ (.*)// ) {
        $tag = $1;
    }

    my $pre = '';
    my $post = '';
    if ($s) {
        # No input, entire thing is a suggestion
        if ( !$b ) {
            $pre = '#' . $s->{window}->{refnum} . ' ';
            $post = $s->{string};
        }
        # Matched window number
        elsif ( $s->{match_obj} eq 'number' and $s->{string} =~ /\Q$b\E/i ) {
            $pre = '#' . $`;
            $post = $' . ' ' . ( $s->{window}->{active}->{name} || $s->{window}->{name} );
        }
        # Matched 'tag' (network or server)
        elsif ( $s->{match_obj} eq 'tag' and $s->{string} =~ /\Q$b\E/i ) {
            $pre = '#' . $s->{window}->{refnum} . ' ' .
                ( $s->{window}->{active}->{name} || $s->{window}->{name} ) . " ($`";
            $post = "$')";
        }
        # Matched window or item name
        elsif ( $s->{string} =~ /\Q$b\E/i ) {
            $pre = '#' . $s->{window}->{refnum} . ' ' . $`;
            $post = $';
        }

        # special case 'tag'.  maybe this should be moved up into the case blocks
        unless ( $s->{match_obj} eq 'tag' ) {
            my $window_tag = $s->{window}->{active_server}->{tag};
            if ( $window_tag ) {
                if ( $tag ) {
                    if ( $window_tag =~ /^\Q$tag\E/i ) {
                        $post .= " ([/i]${tag}[i]$')"
                    } else {
                        print "BUG! Window had tag '$window_tag' and should have matched '$tag' but didn't!";
                    }
                } else {
                    $post .= " ($window_tag)";
                }
            }
        }
    }

    # ANSI escapes
    my $inv    = "\x{1b}[7m";
    my $no_inv = "\x{1b}[0m";

    # Fix up inverse for pre and post text
    if($pre) {
        $pre = "[i]${pre}[/i]";
        $pre =~ s/\[i\]/$inv/ig;
        $pre =~ s/\[\/i\]/$no_inv/ig;
    }
    if($post) {
        $post = "[i]${post}[/i]";
        $post =~ s/\[i\]/$inv/ig;
        $post =~ s/\[\/i\]/$no_inv/ig;
    }

    # FIXME - there has to be a "right way" to do this.
    # it looks like the fe-text/gui-readline.c and gui-entry.c
    # (and other gui-*) are not XS wrapped for whatever reason.
    print STDOUT "\r" . ' 'x40 . "\rGoto: ";

    print STDOUT $pre if $pre;   # before
    print STDOUT $b;             # the matched string
    print STDOUT $post if $post; # after
}

sub _match {
    my ( $name, @wins ) = @_;
    my @matches;

    # $name might have a space and a second token which is a tag, remove it
    # and try to match the window tag
    my $tag;
    if ( $name =~ s/ (.*)// ) {
        $tag = $1;
    }

    my $awr = Irssi::active_win()->{refnum};
    for (@wins) {
        # Only add each window once, and prefer item, name, number, then tag
        my @c;

        # items
        if (
                length $_->{active}->{name}
                and (
                    (
                        @c = $_->{active}->{name} =~ /(^(#)?)?\Q$name\E($)?/i
                        and (
                            # Match the network token if one was entered
                            !$tag
                            or (
                                defined $_->{active_server}->{tag}
                                and $_->{active_server}->{tag} =~ /^\Q$tag\E/i
                            )
                        )
                    )
                    # If we have an item name but no input, use the item name as the match string
                    or !length($name)
                )
        ) {
            push @matches, {
                string        => $_->{active}->{name},
                window        => $_,
                match_obj     => 'item',
                anchored      => ( defined $c[0] and !defined $c[1] ),
                near_anchored => ( defined $c[0] and defined $c[1] ),
                exact         => ( defined $c[0] and !defined $c[1] and defined $c[2] ),
                active_win    => ( $awr == $_->{refnum} ),
                # ignore non-chat activity
                activity      => ( $_->{data_level} > 1 ? $_->{data_level} : 0 ),
            };
            next;
        }

        # window names
        if (
                length $_->{name}
                and (
                    (
                        @c = $_->{name} =~ /(^(#)?)?\Q$name\E($)?/i
                        and (
                            # Match the network token if one was entered
                            !$tag
                            or (
                                defined $_->{active_server}->{tag}
                                and $_->{active_server}->{tag} =~ /^\Q$tag\E/i
                            )
                        )
                    )
                    # If we have an window name but no input, use the window name as the match string
                    or !length($name)
                )
        ) {
            push @matches, {
                string        => $_->{name},
                window        => $_,
                match_obj     => 'name',
                anchored      => ( defined $c[0] and !defined $c[1] ),
                # this is not really so useful for names, but it doesn't really hurt either
                near_anchored => ( defined $c[0] and defined $c[1] ),
                exact         => ( defined $c[0] and !defined $c[1] and defined $c[2] ),
                active_win    => ( $awr == $_->{refnum} ),
                # ignore non-chat activity
                activity      => ( $_->{data_level} > 1 ? $_->{data_level} : 0 ),
            };
            next;
        }

        # window numbers
        if (
                defined $_->{refnum}
                and @c = $_->{refnum} =~ /(^)?\Q$name\E($)?/i
                and (
                    # Match the network token if one was entered
                    !$tag
                    or (
                        defined $_->{active_server}->{tag}
                        and $_->{active_server}->{tag} =~ /^\Q$tag\E/i
                    )
                )
        ) {
            push @matches, {
                string     => $_->{refnum},
                window     => $_,
                match_obj  => 'number',
                anchored   => defined $c[0],
                exact      => ( defined $c[0] and defined $c[1] ),
                active_win => ( $awr == $_->{refnum} ),
                # ignore non-chat activity
                activity   => ( $_->{data_level} > 1 ? $_->{data_level} : 0 ),
            };
            next;
        }

        # network names
        if (
                defined $_->{active_server}->{tag}
                and @c = $_->{active_server}->{tag} =~ /(^)?\Q$name\E($)?/i

                # This doesn't seem to make a lot of sense but it makes for a
                # weird user experience without it, particularly on tab
                # cycling
                and (
                    !$tag
                    or $_->{active_server}->{tag} =~ /^\Q$tag\E/i
                )
        ) {
            # don't add by tag if we've already got
            push @matches, {
                string     => $_->{active_server}->{tag},
                window     => $_,
                match_obj  => 'tag',
                anchored   => defined $c[0],
                exact      => ( defined $c[0] and defined $c[1] ),
                active_win => ( $awr == $_->{refnum} ),
                # ignore non-chat activity
                activity   => ( $_->{data_level} > 1 ? $_->{data_level} : 0 ),
            };
            next;
        }
    }

    # Try to sort intelligently.  Without input, order by window number.  Otherwise,
    # put exact matches in front, then anchored matches, then alpha sort.  However,
    # try not to suggest the currently selected window as the first choice.  In addition,
    # we'll give preference to active windows.
    #
    # Here is a chart of the currently implemented sorting behavior:
    #
    #  * exact match (items, names, and numbers)
    #    - activity level
    #       - items, then names, then numbers
    #
    #  * anchored (items, names, and numbers)
    #    - activity level
    #       - items, then names, then numbers
    #
    #  * near-anchored (without leading #) (items and names)
    #    - activity level
    #       - items, then names
    #
    #  * exact for networks
    #    - activity level
    #
    #  * anchored for networks
    #    - activity level
    #
    #  * activity level
    #
    #  * alphabetical
    #
    @matches = sort {
        my $which;
        if ( !length($name) ) {
            # no input, sort by number with preference to active windows
            $which =
                $b->{activity} <=> $a->{activity} ||
                $a->{window}->{refnum} <=> $b->{window}->{refnum};
        } else {
            COMPARE: for my $objects ( [ 'item', 'name', 'number' ], [ 'tag' ] ) {
                my $i;
                my %object_rank = map { $_ => ++$i } @$objects;
                for my $match ( 'exact', 'anchored', 'near_anchored' ) {

                    # Make sure at least one is one of the desired match objects
                    my $a_mo = grep { $_ eq $a->{match_obj} } @$objects;
                    my $b_mo = grep { $_ eq $b->{match_obj} } @$objects;
                    next unless $a_mo || $b_mo;

                    # Make sure at least one is the current match type
                    next unless $a->{$match} || $b->{$match};

                    last COMPARE if $which =
                        # if only one is a preferred match object
                        $b_mo <=> $a_mo ||

                        # if only one is the current match type
                        $b->{$match} <=> $a->{$match} ||

                        # Since both are the same level of match, bump up more active windows
                        $b->{activity} <=> $a->{activity} ||

                        # Same activity, order by object ranking (lower is better)
                        $object_rank{$a->{match_obj}} <=> $object_rank{$b->{match_obj}};
                }
            }
            # If we couldn't differentiate by now, bump current window to the bottom,
            # sort by activity, and then alphabetically
            $which =
                $a->{active_win} <=> $b->{active_win} ||
                $b->{activity} <=> $a->{activity} ||
                $a->{string} cmp $b->{string}
                unless $which;

        }
        $which;
    } @matches;

    return @matches;
}

sub _help {
    print<<HELP;
Go - jump directly to the correct destination

Usage:
    /go [destination]

    The argument is optional, and if it is not provided or is ambiguous, you will be
    sent to a prompt where you type in a few numbers or letters of the window name,
    item (channel, nickname), window number, or connected network.  Once you have input
    that matches one or more possible destinations, Go will print in inverse text what
    it thinks you are looking for.  If there are multiple, the tab key will cycle through
    them.  Press enter when you see the correct window to switch to it.

    If you are using irssi 0.8.12 or better, you can tab complete from the input line
    without having to press enter first.

    If your destination has a second word (/go foo bar), then the second word (eg 'bar')
    is assumed to be the network name, which is useful for disambiguation.  This works
    both with input to /go and for text typed at the Goto: prompt.

    You may find it useful to bind this action to a keystroke to expedite movement, which
    will forego any argument and take you directly to the prompt:

        /bind meta-w /go
HELP
}
