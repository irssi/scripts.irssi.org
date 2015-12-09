=pod

=head1 NAME

ido_switcher.pl

=head1 DESCRIPTION 

Search and select windows similar to ido-mode for emacs

=head1 INSTALLATION

This script requires that you have first installed and loaded F<uberprompt.pl>

Uberprompt can be downloaded from:

L<https://github.com/shabble/irssi-scripts/raw/master/prompt_info/uberprompt.pl>

and follow the instructions at the top of that file or its README for installation.

If uberprompt.pl is available, but not loaded, this script will make one
attempt to load it before giving up.  This eliminates the need to precisely
arrange the startup order of your scripts.

=head2 SETUP

C</bind ^G /ido_switch_start [options]>

Where C<^G> is a key of your choice.

=head2 USAGE

C<C-g> (or whatever you've set the above bind to), enters IDO window switching mode.
You can then type either a search string, or use one of the additional key-bindings
to change the behaviour of the search.  C<C-h> provides online help regarding
the possible interactive options.

=head3 EXTENDED USAGE:

It is possible to pass arguments to the C</ido_switch_start> command, which
correspond to some of the interactively settable parameters listed below.

The following options are available:

=over 4

=item C<-channels>

Search through only channels.

=item C<-queries>

Search through only queries.

=item C<-all>

search both queries and channels (Default).

=item C<-active>

Lmit search to only window items with activity.

=item C<-exact>

Enable exact-substring matching

=item C<-flex>

Enable flex-string matching

=back

I<If neither of C<-exact>, C<-flex> or C<-regex> are given, the default is the value of
C</set ido_use_flex>>

=head4 EXAMPLE

=over 2

=item C</bind ^G /ido_switch_start -channels>

=item C</bind ^F /ido_switch_start -queries -active>

=back

B<NOTE:> When entering window switching mode, the contents of your input line will
be saved and cleared, to avoid visual clutter whilst using the switching
interface.  It will be restored once you exit the mode using either C<C-g>, C<Esc>,
or C<RET>.

=head3 INTERACTIVE COMMANDS

The following key-bindings are available only once the mode has been
activated:

=over 4

=item C<C-g>

 Exit the mode without changing windows.

=item C<Esc>

Exit, as above.

=item C<C-s>

Rotate the list of window candidates forward by one item

=item C<C-r>

Rotate the list of window candidates backward by one item

=item C<C-e>

Toggle 'Active windows only' filter

=item C<C-f>

Switch between 'Flex' and 'Exact' matching.

=item C<C-d>

Select a network or server to filter candidates by

=item C<C-u>

Clear the current search string

=item C<C-q>

Cycle between showing only queries, channels, or all.

=item C<C-SPC>

Filter candidates by current search string, and then reset
the search string

=item C<RET>

Select the current head of the candidate list (the green one)

=item C<SPC>

Select the current head of the list, without exiting the
switching mode. The head is then moved one place to the right,
allowing one to cycle through channels by repeatedly pressing space.

=item C<TAB>

B<[currently in development]> displays all possible completions
at the bottom of the current window.

=item I<All other keys> (C<a-z, A-Z>, etc)

Add that character to the current search string.

=back

=head3 USAGE NOTES

=over 4

=item * 

Using C-e (show actives), followed by repeatedly pressing space will cycle
through all your currently active windows.

=item *

If you enter a search string fragment, and realise that more than one candidate
is still presented, rather than delete the whole string and modify it, you
can use C-SPC to 'lock' the current matching candidates, but allow you to
search through those matches alone.

=back

=head1 AUTHORS

Based originally on L<window_switcher.pl|http://scripts.irssi.org/scripts/window_switcher.pl> script Copyright 2007 Wouter Coekaerts
C<E<lt>coekie@irssi.orgE<gt>>.

Primary functionality Copyright 2010-2011 Tom Feist
C<E<lt>shabble+irssi@metavore.orgE<gt>>.

=head1 LICENCE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

=head1 BUGS:

=over 4

=item B<FIXED> Sometimes selecting a channel with the same name on a different
   network will take you to the wrong channel.

=back

=head1 TODO

=over 4

=item B<DONE> C-g - cancel

=item B<DONE> C-spc - narrow

=item B<DONE> flex matching (on by default, but optional)

=item TODO server/network narrowing

=item B<DONE> colourised output (via uberprompt)

=item B<DONE> C-r / C-s rotate matches

=item B<DONE> toggle queries/channels

=item B<DONE> remove inputline content, restore it afterwards.

=item TODO tab - display all possibilities in window (clean up afterwards)
how exactly will this work?

=item B<DONE> sort by recent activity/recently used windows (separate commands?)

=item B<TODO> need to be able to switch ordering of active ones (numerical, or most
recently active, priority to PMs/hilights, etc?)

=item B<DONE> should space auto-move forward to next window for easy stepping
     through sequential/active windows?

=back

=cut

use strict;
use warnings;

use Irssi;
use Irssi::TextUI;
use Data::Dumper;


our $VERSION = '2.4'; # 7c9e42560a2f4a1
our %IRSSI   =
  (
   authors     => 'Tom Feist, Wouter Coekaerts',
   contact     => 'shabble+irssi@metavore.org, shabble@#irssi/freenode',
   name        => 'ido_switcher',
   description => 'Select window[-items] using an ido-mode like search interface',
   license     => 'GPLv2 or later',
   url         => 'http://github.com/shabble/irssi-scripts/tree/master/ido-mode/',
  );



my $CMD_NAME = 'ido_switch_start';
my $CMD_OPTS = '-channels -queries -all -active -exact -flex -regex';


my $input_copy     = '';
my $input_pos_copy = 0;

my $ido_switch_active = 0;      # for intercepting keystrokes

my @window_cache   = ();
my @search_matches = ();

my $match_index = 0;
my $search_str  = '';
my $active_only = 0;
my $regex_valid  = 1;

my $mode_type = 'ALL';
my @mode_cache;
my $showing_help = 0;

my $need_clear = 0;

my $sort_ordering = "start-asc";
my $sort_active_first = 0;

# /set configurable settings
my $ido_show_count;
my $ido_use_flex;

my $DEBUG_ENABLED = 0;
sub DEBUG () { $DEBUG_ENABLED }


sub MODE_WIN () { 0 } # windows
sub MODE_NET () { 1 } # chatnets
#sub MODE_C () { 2 } # channels
#sub MODE_S () { 3 } # select server
#sub MODE_W () { 4 } # select window

my $MODE = MODE_WIN;

# check we have uberprompt loaded.

my %need_clear;

sub _print {
    my $win = Irssi::active_win;
    my $str = join('', @_);
    $need_clear = 1;
    $win->print($str, MSGLEVEL_NEVER);
    push @{ $need_clear{ $win->{_irssi} } }, $win->view->{buffer}{cur_line};
}

sub _debug_print {
    return unless DEBUG;
    my $win = Irssi::active_win;
    my $str = join('', @_);
    $win->print($str, MSGLEVEL_CLIENTCRAP);
}

sub _print_clear {
    return unless $need_clear;
    for my $win (Irssi::windows) {
	if (my $lines = delete $need_clear{ $win->{_irssi} }) {
	    my $view = $win->view;
	    my $bottom = $view->{bottom};
	    for my $line (@$lines) {
		$view->remove_line($line);
	    }
	    $win->command('^scrollback end') if $bottom && !$win->view->{bottom};
	    $view->redraw;
	}
    }
    %need_clear=();
}

# TODO: use the code from rl_history_search to put this into a disposable
#       split win.
# TODO: create formats for this.
sub display_help {

    my @message =
      ('%_IDO Window Switching Help:%_',
       '',
       '%_Ctrl-g%_   %|- cancel out of the mode without changing windows.',
       '%_Esc%_      %|- cancel out, as above.',
       '%_Ctrl-s%_   %|- rotate the list of window candidates forward by 1',
       '%_Ctrl-r%_   %|- rotate the list of window candidates backward by 1',
       '%_Ctrl-e%_   %|- Toggle \'Active windows only\' filter',
       '%_Ctrl-f%_   %|- Switch between \'Regex\', \'Flex\' and \'Exact\' matching.',
#       '%_Ctrl-d%_   %|- Select a network or server to filter candidates by',
       '%_Ctrl-u%_   %|- Clear the current search string',
       '%_Ctrl-q%_   %|- Cycle between showing only queries, channels, or all.',
       '%_Ctrl-SPC%_ %|- Filter candidates by current search string, and then reset the search string',
       '%_RET%_      %|- Select the current head of the candidate list (the %_green%n one)',
       '%_SPC%_      %|- Select the current head of the list, without exiting switching mode. The head '
	             .'is then moved one place to the right, allowing one to cycle through channels by repeatedly '
	             .'pressing space.',
       '%_TAB%_      %|- displays all possible completions at the bottom of the current window.',
       '',
       '     %_All other keys (a-z, A-Z, etc) - Add that character to the',
       '     %_current search string.',
       '',
       '%_Press Any Key to return%_',
      );

    _print($_) for @message;
    $showing_help = 1;
}

sub print_all_matches {
    my $message_header = "Windows:";
    my $win = Irssi::active_win();
    my $win_width = $win->{width} || 80;

    # TODO: needs to prefix ambig things with chatnet, or maybe order in groups
    # by chatnet with newlines.

    # Also, colourise the channel list.

    my $col_width = 1;

    for (@search_matches) {
        my $len = length($_->{num} . ':' . _format_display_tag($_) . $_->{name});
        $col_width = $len if $len > $col_width;
    }

    my $cols = int($win_width / $col_width);

    my @lines;
    my $i = 0;
    my @line;

    for my $item (@search_matches) {
	++$i;
        my $name = $item->{name};
        push @line, sprintf('%*s', -(10+$col_width), "\cD4/".$item->{num}.":\cD3/"._format_display_tag($item)."\cD4/".$name);
        if ($i == $cols) {
            push @lines, join ' ', @line;
            @line = ();
            $i = 0;
        }
    }
    # flush rest out.
    push @lines, join ' ', @line;

    _print($message_header);
    _print($_) for (@lines);
    #_print("Longtest name: $longest_name");
}

unless ("Irssi::Script::uberprompt"->can('init')) {

    print "Warning, this script requires '\%_uberprompt.pl\%_' in order to work. ";

}

sub ido_switch_init {
    #Irssi::settings_add_bool('ido_switch', 'ido_switch_debug',      0);
    Irssi::settings_add_str('ido_switch', 'ido_use_flex',           'flex');
    Irssi::settings_add_bool('ido_switch', 'ido_show_active_first', 1);
    Irssi::settings_add_int ('ido_switch', 'ido_show_count',        5);


    Irssi::command_bind($CMD_NAME, \&ido_switch_start);
    Irssi::command_set_options($CMD_NAME, $CMD_OPTS);

    Irssi::signal_add      ('setup changed'   => \&setup_changed);
    Irssi::signal_add_first('gui key pressed' => \&handle_keypress);

    setup_changed();
}

sub setup_changed {
    #$DEBUG_ENABLED     = Irssi::settings_get_bool('ido_switch_debug');
    $ido_show_count    = Irssi::settings_get_int ('ido_show_count');
    $ido_use_flex      = _flex_mode(Irssi::settings_get_str('ido_use_flex'));
    $sort_active_first = Irssi::settings_get_bool('ido_show_active_first');
}

sub ido_switch_start {

    my ($args, $server, $witem) = @_;

    # store copy of input line to restore later.
    $input_copy     = Irssi::parse_special('$L');
    $input_pos_copy = Irssi::gui_input_get_pos();

    Irssi::gui_input_set('');

    my $options = {};
    my @opts = Irssi::command_parse_options($CMD_NAME, $args);
    if (@opts and ref($opts[0]) eq 'HASH') {
        $options = $opts[0];
        #print "Options: " . Dumper($options);
    }

    # clear / initialise match variables.
    $ido_switch_active = 1;
    $search_str        = '';
    $match_index       = 0;
    @mode_cache = ();

    # configure settings from provided arguments.

    # use provided options first, or fall back to /setting.
    $ido_use_flex = _flex_mode(exists $options->{exact}
      ? 'exact'
      : exists $options->{flex}
      ? 'flex'
      : exists $options->{regex}
      ? 'regex'
      : Irssi::settings_get_str('ido_use_flex'));

    # only select active items
    $active_only = exists $options->{active};

    # what type of items to search.
    $mode_type   = exists $options->{queries}
      ? 'QUERY'
      : exists $options->{channels}
      ? 'CHANNEL'
      : 'ALL';

    _debug_print "Win cache: " . join(", ", map { $_->{name} } @window_cache);

    _update_cache();

    update_matches();
    update_window_select_prompt();
}

sub _flex_mode {
    if ($_[0] =~ /flex/i) {
	'Flex'
    } elsif ($_[0] =~ /regex/i) {
	'Regex'
    } else {
	'Exact'
    }
}

sub _update_cache {
    @window_cache = get_all_windows();
}

sub _build_win_obj {
    my ($win, $win_item) = @_;

    my @base = (
                b_pos         => -1,
                e_pos         => -1,
                hilight_field => 'name',
                active        => $win->{data_level} > 0,
                num           => $win->{refnum},
                server        => $win->{active_server},

               );

    if (defined($win_item)) {
        return (
                @base,
                name     => $win_item->{visible_name},
                type     => $win_item->{type},
                itemname => $win_item->{name},
                active   => $win_item->{data_level} > 0,
                server   => $win_item->{server},

               )
    } else {
        return (
                @base,
                name => $win->{name},
                type => 'WIN',
               );
    }
}

sub get_all_windows {
    my @ret;

    foreach my $win (Irssi::windows()) {
        my @items = $win->items();

        if ($win->{name} ne '') {
            _debug_print "Adding window: " . $win->{name};
            push @ret, { _build_win_obj($win, undef) };
        }
        if (scalar @items) {
            foreach my $item (@items) {
                _debug_print "Adding windowitem: " . $item->{visible_name};
                push @ret, { _build_win_obj($win, $item) };
            }
        } else {
            if (not grep { $_->{num} == $win->{refnum} } @ret) {
                my $item = { _build_win_obj($win, undef) };
                $item->{name} = "Unknown";
                push @ret, $item;
            }
            #_debug_print "Error occurred reading info from window: $win";
            #_debug_print Dumper($win);
        }
    }
    @ret = _sort_windows(\@ret);

    return @ret;

}

sub _sort_windows {
    my $list_ref = shift;
    my @ret = @$list_ref;

    @ret = sort { $a->{num} <=> $b->{num}  } @ret;
    if ($sort_active_first) {
        my @active   = grep {     $_->{active} } @ret;
        my @inactive = grep { not $_->{active} } @ret;

        return (@active, @inactive);
    } else {
        return @ret;
    }
}

sub ido_switch_select {
    my ($selected, $tag) = @_;
    if (!$selected) {
	_debug_print "Error, selection invalid";
	return;
    }
    _debug_print sprintf("Selecting window: %s (%d)",
                         $selected->{name}, $selected->{num});

    Irssi::command("WINDOW GOTO " . $selected->{num});

    if ($selected->{type} ne 'WIN') {
        _debug_print "Selecting window item: " . $selected->{itemname};
	my $i = 1; my $found;
	for (Irssi::active_win->items) {
	    if ($_->{name} eq $selected->{itemname}) {
		if (!defined $selected->{server} && !defined $_->{server}) {
		    $found = 1;
		    last;
		}
		if (defined $selected->{server} && defined $_->{server}
		   && $selected->{server}{tag} eq $_->{server}{tag}) {
		    $found = 1;
		    last;
		}
	    }
	    ++$i;
	}
        Irssi::command("WINDOW ITEM GOTO " . ($found ? $i : $selected->{itemname}));
    }

    update_matches();
}

sub ido_switch_exit {
    $ido_switch_active = 0;

    _print_clear();

    Irssi::gui_input_set($input_copy);
    Irssi::gui_input_set_pos($input_pos_copy);
    Irssi::signal_emit('change prompt', '', 'UP_INNER');
}

sub _order_matches {
    return @_[$match_index .. $#_,
              0            .. $match_index - 1]
}

sub update_window_select_prompt {

    # take the top $ido_show_count entries and display them.
    my $match_count  = scalar @search_matches;
    my $show_count   = $ido_show_count;
    my $match_string = '[No matches]';

    $show_count = $match_count if $match_count < $show_count;

    if ($show_count > 0) { # otherwise, default message above.
        _debug_print "Showing: $show_count matches";

        my @ordered_matches = _order_matches(@search_matches);

        my @display = @ordered_matches[0..$show_count - 1];

        # determine which items are non-unique, if any.

        my %uniq;

        foreach my $res (@display) {
            my $name = $res->{name};

            if (!exists $uniq{$name}) {
                $uniq{$name} = [];
            }
            push @{$uniq{$name}}, $res;
        }

        # and set a flag to ensure they have their network tag applied
        # to them when drawn.
        foreach my $name (keys %uniq) {
            my @values = @{$uniq{$name}};
            if (@values > 1) {
                $_->{display_net} = 1 for @values;
            }
        }

        # show the first entry in green

        my $first = shift @display;
        my $formatted_first = _format_display_entry($first, '%g');
        unshift @display, $formatted_first;

        # and array-slice-map the rest to be red.
        # or yellow, if they have unviewed activity

        @display[1..$#display]
          = map
          {
              _format_display_entry($_, $_->{active}?'%y':'%r')

          } @display[1..$#display];

        # join em all up
        $match_string = join ', ', @display;
    }

    my @indicators;

    # indicator if flex mode is being used (C-f to toggle)
    push @indicators, $ido_use_flex;
    push @indicators, 'Active' if $active_only;
    push @indicators, ucfirst(lc($mode_type));

    my $flex = sprintf(' %%b[%%n%s%%b]%%n ', join ', ', @indicators);

    my $search = '';
    $search = (sprintf '`%s\': ', $search_str) if length $search_str;
    $search = (sprintf '`%%R%s%%n\': ', $search_str) if (length $search_str && !$regex_valid);

    Irssi::signal_emit('change prompt', $flex . $search . $match_string,
                       'UP_INNER');
}



sub _format_display_entry {
    my ($obj, $colour) = @_;

    my $field     = $obj->{hilight_field};
    my $hilighted = { netname => _format_display_tag($obj).$obj->{name},
		      name => $obj->{name}, num => $obj->{num} };
    my $show_tag  = $obj->{display_net} || 0;

    if ($obj->{b_pos} >= 0 && $obj->{e_pos} > $obj->{b_pos}) {
        substr($hilighted->{$field}, $obj->{e_pos}, 0) = '%_';
        substr($hilighted->{$field}, $obj->{b_pos}, 0) = '%_';
        _debug_print "Showing $field as: " . $hilighted->{$field}
    }

    return sprintf('%s%s:%s%%n',
                   $colour,
                   $hilighted->{num},
                   $hilighted->{netname})
	if $field eq 'netname';

    return sprintf('%s%s:%s%s%%n',
                   $colour,
                   $hilighted->{num},
                   $show_tag ? _format_display_tag($obj) : '',
                   $hilighted->{name});
}

sub _format_display_tag {
    my $obj = shift;
    if (defined $obj->{server}) {
        my $server = $obj->{server};
        my $tag = $server->{tag};
        return $tag . '/' if length $tag;
    }
    return '';
}

sub _check_active {
    my ($obj) = @_;
    return 1 unless $active_only;
    return $obj->{active};
}

sub update_matches {
    my $current_match = get_window_match();

    _update_cache() unless $search_str;

    if ($mode_type ne 'ALL') {
        @mode_cache = @window_cache;
        @window_cache = grep { $_->{type} eq $mode_type } @window_cache;
    } else {
        @window_cache = @mode_cache if @mode_cache;
    }

    my $field = 'name';
    my $search_str2;
    if ($search_str =~ m:^(.*)/(.*?)$:) {
	$field = 'netname';
	$search_str2 = "$2/$1";
    }

    $regex_valid = 1;
    if ($search_str =~ m/^\d+$/) {

        @search_matches =
          grep {
              _check_active($_) and regex_match($search_str, $_, 'num')
          } @window_cache;

    } elsif ($ido_use_flex eq 'Flex') {

        @search_matches =
          grep {
              _check_active($_) and (flex_match($search_str, $_, $field) >= 0
					 || (defined $search_str2 && flex_match($search_str2, $_, $field) >= 0))
          } @window_cache;

    } elsif ($ido_use_flex eq 'Regex') {
	my $regex = do { local $@;
			 my $ret = eval { qr/$search_str/ } || qr/\Q$search_str/;
			 if ($@) { $regex_valid = 0 }
			 $ret;
		     };
	my $regex2 = defined $search_str2 ?
	    do { local $@; eval { qr/$search_str2/ } || qr/\Q$search_str2/ }
		: undef;
        @search_matches =
          grep {
              _check_active($_) and (regex_match($regex, $_, $field)
					 || (defined $regex2 && regex_match($regex2, $_, $field)))
          } @window_cache;
    } else {
        @search_matches =
          grep {
              _check_active($_) and (regex_match(qr/\Q$search_str/, $_, $field)
					 || (defined $search_str2 && regex_match(qr/\Q$search_str2/, $_, $field)))
          } @window_cache;
    }

    $match_index = 0;
    if ($current_match) {
    for my $idx (0..$#search_matches) {
	if ($search_matches[$idx]{num} == $current_match->{num}
	   && $search_matches[$idx]{type} eq $current_match->{type}) {
	    $match_index = $idx;
	    if ($current_match->{type} eq 'WIN') {
		last;
	    } elsif ($search_matches[$idx]{itemname} eq $current_match->{itemname}) {
		last;
	    }
	}
    }
    }

}

sub regex_match {
    my ($regex, $obj, $field) = @_;
    my $data = $field eq 'netname'
	? _format_display_tag($obj).$obj->{name} : $obj->{$field};
    if ($data =~ m/$regex/i) {
        $obj->{hilight_field} = $field;
        $obj->{b_pos} = $-[0];
        $obj->{e_pos} = $+[0];
        return 1;
    }
    return 0;
}

sub flex_match {
    my ($search_str, $obj, $field) = @_;

    my $pattern = $search_str;
    my $source  = $field eq 'netname'
	? _format_display_tag($obj).$obj->{name} : $obj->{$field};

    _debug_print "Flex match: $pattern / $source";

    # default to matching everything if we don't have a pattern to compare
    # against.

    return 0 unless $pattern;

    my @chars = split '', lc($pattern);
    my $ret = -1;
    my $first = 0;

    my $lc_source = lc($source);

    $obj->{hilight_field} = $field;

    foreach my $char (@chars) {
        my $pos = index($lc_source, $char, $ret);
        if ($pos > -1) {

            # store the beginning of the match
            $obj->{b_pos} = $pos unless $first;
            $first = 1;

            _debug_print("matched: $char at $pos in $source");
            $ret = $pos + 1;

        } else {

            $obj->{b_pos} = $obj->{e_pos} = -1;
            _debug_print "Flex returning: -1";

            return -1;
        }
    }

    _debug_print "Flex returning: $ret";

    #store the end of the match.
    $obj->{e_pos} = $ret;

    return $ret;
}

sub prev_match {

    $match_index++;
    if ($match_index > $#search_matches) {
        $match_index = 0;
    }

    _debug_print "index now: $match_index";
}

sub next_match {

    $match_index--;
    if ($match_index < 0) {
        $match_index = $#search_matches;
    }
    _debug_print "index now: $match_index";
}

sub get_window_match {
    return $search_matches[$match_index];
}

sub handle_keypress {
    my ($key) = @_;

    return unless $ido_switch_active;

    if ($showing_help) {
        _print_clear();
        $showing_help = 0;
        Irssi::signal_stop();
    }

    if ($key == 0) {        # C-SPC?
        _debug_print "\%_Ctrl-space\%_";

        $search_str = '';
        @window_cache = @search_matches;
        update_window_select_prompt();

        Irssi::signal_stop();
        return;
    }

    if ($key == 3) {        # C-c
        _print_clear();
        Irssi::signal_stop();
        return;
    }
    if ($key == 4) {        # C-d
#        update_network_select_prompt();
        Irssi::signal_stop();
        return;
    }

    if ($key == 5) {        # C-e
        $active_only = not $active_only;
        Irssi::signal_stop();
        update_matches();
        update_window_select_prompt();
        return;
    }

    if ($key == 6) {        # C-f

        $ido_use_flex = ($ido_use_flex eq 'Regex' ? 'Flex'
			     : $ido_use_flex eq 'Flex' ? 'Exact'
				 : 'Regex');
        _update_cache();

        update_matches();
        update_window_select_prompt();

        Irssi::signal_stop();
        return;
    }
    if ($key == 9) {        # TAB
        _debug_print "Tab complete";
	_print_clear();
        print_all_matches();
        Irssi::signal_stop();
    }

    if ($key == 10 || $key == 13) {       # enter
        _debug_print "selecting history and quitting";
        my $selected_win = get_window_match();
        ido_switch_select($selected_win);

        ido_switch_exit();
        Irssi::signal_stop();
        return;
    }
    if ($key == 11) { # Ctrl-K
        my $sel = get_window_match();
        _debug_print("deleting entry: " . $sel->{num});
        Irssi::command("window close " . $sel->{num});
        _update_cache();
        update_matches();
        update_window_select_prompt();
        Irssi::signal_stop();

    }

    if ($key == 18) {       # Ctrl-R
        _debug_print "skipping to prev match";
        #update_matches();
        next_match();

        update_window_select_prompt();
        Irssi::signal_stop(); # prevent the bind from being re-triggered.
        return;
    }

    if ($key == 17) {       # Ctrl-q
        if ($mode_type eq 'CHANNEL') {
            $mode_type = 'QUERY';
        } elsif ($mode_type eq 'QUERY') {
            $mode_type = 'ALL';
        } else { # ALL
            $mode_type = 'CHANNEL';
        }
        update_matches();
        update_window_select_prompt();
        Irssi::signal_stop();
    }

    if ($key == 19) {       # Ctrl-s
        _debug_print "skipping to next match";
        prev_match();

        #update_matches();
        update_window_select_prompt();

        Irssi::signal_stop();
        return;
    }

    if ($key == 7) {        # Ctrl-g
        _debug_print "aborting search";
        ido_switch_exit();
        Irssi::signal_stop();
        return;
    }

    if ($key == 8) {        # Ctrl-h
        display_help();
        Irssi::signal_stop();
        return;
    }

    if ($key == 21) {       # Ctrl-u
        $search_str = '';
        update_matches();
        update_window_select_prompt();

        Irssi::signal_stop();
        return;

    }

    if ($key == 127) {      # DEL

        if (length $search_str) {
            $search_str = substr($search_str, 0, -1);
            _debug_print "Deleting char, now: $search_str";
        }

        update_matches();
        update_window_select_prompt();

        Irssi::signal_stop();
        return;
    }

    # TODO: handle esc- sequences and arrow-keys?

    if ($key == 27) {       # Esc
        ido_switch_exit();
        return;
    }

    if ($key == 32) {       # space
        my $selected_win = get_window_match();
        ido_switch_select($selected_win);

        prev_match();
        update_window_select_prompt();

        Irssi::signal_stop();

        return;
    }

    if ($key > 32) {        # printable
        $search_str .= chr($key);

        update_matches();
        update_window_select_prompt();

        Irssi::signal_stop();
        return;
    }

    # ignore all other keys.
    Irssi::signal_stop();
}

ido_switch_init();

sub update_network_select_prompt {

    my @servers = map
      {
          {
              name => $_->{tag},
              type => 'SERVER',
              active => 0,
              e_pos => -1,
              b_pos => -1,
              hilight_field => 'name',
          }
      } Irssi::servers();

    my $match_count  = scalar @servers;
    my $show_count   = $ido_show_count;
    my $match_string = '(no matches) ';

    $show_count = $match_count if $match_count < $show_count;

    if ($show_count > 0) {
        _debug_print "Showing: $show_count matches";

        my @ordered_matches = _order_matches(@servers);
        my @display = @ordered_matches[0..$show_count - 1];

        # show the first entry in green

        unshift(@display, _format_display_entry(shift(@display), '%g'));

        # and array-slice-map the rest to be red (or yellow for active)
        @display[1..$#display]
          = map
          {
              _format_display_entry($_, $_->{active}?'%y':'%r')

          } @display[1..$#display];

        # join em all up
        $match_string = join ', ', @display;
    }

    my @indicators;

    # indicator if flex mode is being used (C-f to toggle)
    push @indicators, $ido_use_flex;
    push @indicators, 'Active' if $active_only;

    my $flex = sprintf(' %%k[%%n%s%%k]%%n ', join ',', @indicators);

    my $search = '';
    $search = (sprintf '`%s\': ', $search_str) if length $search_str;
    $search = (sprintf '`%%R%s%%n\': ', $search_str) if (length $search_str && !$regex_valid);

    Irssi::signal_emit('change prompt', $flex . $search . $match_string,
                       'UP_INNER');

}
