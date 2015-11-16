=pod

=head1 NAME

aspell.pl

=head1 DESCRIPTION

A spellchecker based on GNU ASpell which allows you to interactively
select the correct spellings for misspelled words in your input field.

=head1 INSTALLATION

Copy into your F<~/.irssi/scripts/> directory and load with
C</SCRIPT LOAD F<filename>>.

=head1 SETUP

Settings:

    aspell_debug              0
    aspell_ignore_chan_nicks  1
    aspell_suggest_colour     '%g'
    aspell_language           'en_GB'
    aspell_irssi_dict         '~/.irssi/irssi.dict'

B<Note:> Americans may wish to change the language to en_US. This can be done
with the command C</SET aspell_language en_US> once the script is loaded.

=head1 USAGE

Bind a key to /spellcheck, and then invoke it when you have
an input-line that you wish to check.

If it is entirely correct, nothing will appear to happen. This is a good thing.
Otherwise, a small split window will appear at the top of the Irssi session
showing you the misspelled word, and a selection of 10 possible candidates.

You may select one of the by pressing the appropriate number from C<0-9>, or
skip the word entirely by hitting the C<Space> bar.

If there are more than 10 possible candidates for a word, you can cycle through
the 10-word "pages" with the C<n> (next) and C<p> (prev) keys.

Pressing Escape, or any other key, will exit the spellcheck altogether, although
it can be later restarted.

=head1 AUTHORS

Copyright E<copy> 2011 Isaac Good C<E<lt>irssi@isaacgood.comE<gt>>

Copyright E<copy> 2011 Tom Feist C<E<lt>shabble+irssi@metavore.orgE<gt>>

=head1 LICENCE

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=head1 BUGS

See README file.

=head1 TODO

See README file.

=cut


use warnings;
use strict;
use Data::Dumper;
use Irssi;
use Irssi::Irc;
use Irssi::TextUI;

use File::Spec;

# Magic. Somehow remedies:
# "Can't locate object method "nicks" via package "Irssi::Irc::Query" Bug
# Actually, that's a bunch of lies, but I'm pretty sure there is something
# it fixes. Otherwise, a bit of cargo-culting can't hurt.

{ package Irssi::Nick }

eval {
    use Text::Aspell;
};

if ($@ && $@ =~ m/Can't locate/) {
    print '%_Bugger, please insteall Text::Aspell%_'
}


our $VERSION = '1.6.1';
our %IRSSI = (
              authors     => 'Isaac Good (yitz_), Tom Feist (shabble)',
              contact     => 'irssi@isaacgood.com, shabble+irssi@metavore.org',
              name        => 'aspell',
              description => 'ASpell spellchecking system for Irssi',
              license     => 'MIT',
              updated     => "2011-10-27",
             );

# ---------------------------
#           Globals
# ---------------------------

# CONFIG SETTINGS
# ===============

# Settings cached vars
my $DEBUG;

# The colour that the suggestions are rendered in in the split windowpane.
my $suggestion_colour;

# Whether to bother spellchecking strings that match nicks in the current channel.
my $ignore_chan_nicks;

# path to local aspell irssi dictionary file.
my $irssi_dict_filepath;

# Language to use. It follows the same format of the LANG environment variable
# on most systems. It consists of the two letter ISO 639 language code and an
# optional two letter ISO 3166 country code after a dash or underscore. The
# default value is based on the value of the LC_MESSAGES locale.
my $aspell_language;


# OTHER GLOBALS
# =============

# current line, broken into hashref 'objects' storing word and positional data.
my @word_pos_array;
# index of word we're currently processing.
my $index;
my $active_word_obj;

# list of all possible suggestions for current misspelled word
my @suggestions;
# page number - we only show 10 results per page so we can select with 0-9
my $suggestion_page;

# the spellchecker object.
my $aspell;

# some window references to manage the window splitting and restoration
my $split_win_ref;
my $original_win_ref;

# keypress handling flag.
my $corrections_active;


#my $bacon = 1;

# ---------------------------
#      key constants
# ---------------------------

sub K_ESC () { 27  }
sub K_RET () { 10  }
sub K_SPC () { 32  }
sub K_0   () { 48  }
sub K_9   () { 57  }
sub K_N   () { 110 }
sub K_P   () { 112 }
sub K_I   () { 105 }

# used for printing stuff to the split window we don't want logged.
sub PRN_LEVEL () { MSGLEVEL_CLIENTCRAP | MSGLEVEL_NEVER }
sub AS_CFG    () { "aspellchecker" }

# ---------------------------
#        Teh Codez
# ---------------------------

sub check_line {
	my ($line) = @_;

    # reset everything
    $suggestion_page    = 0;
    $corrections_active = 0;
    $index              = 0;
    @word_pos_array     = ();
    @suggestions        = ();
    close_temp_split();

    # split into an array of words on whitespace, keeping track of
    # positions of each, as well as the size of whitespace.

    my $pos = 0;

    _debug('check_line processing "%s"', $line);

    while ($line =~ m/\G(\S+)(\s*)/g) {
        my ($word, $ws) = ($1, $2); # word, whitespace

        my $prefix_punct = '';
        my $suffix_punct = '';

        if ($word =~ m/^([^a-zA-Z0-9]+)/) {
            $prefix_punct = $1;
        }
        if ($word =~ m/([^a-zA-Z0-9]+)$/) {
            $suffix_punct = $1;
        }

        my $pp_len = length($prefix_punct);
        my $sp_len = length($suffix_punct);

        my $actual_len  = length($word) - ($pp_len + $sp_len);
        my $actual_word = substr($word, $pp_len, $actual_len);

        if($DEBUG and ($pp_len or $sp_len)) {
            _debug("prefix punc: %s, suffix punc: %s, actual word: %s",
                   $prefix_punct, $suffix_punct, $actual_word);
        }


        my $actual_pos  = $pos + $pp_len;

        my $obj = {
                   word         => $actual_word,
                   pos          => $actual_pos,
                   len          => $actual_len,
                   prefix_punct => $prefix_punct,
                   suffix_punct => $suffix_punct,
                  };

        push @word_pos_array, $obj;
        $pos += length ($word . $ws);
    }

    return unless @word_pos_array > 0;

    process_word($word_pos_array[0]);
}

sub process_word {
    my ($word_obj) = @_;

    my $word = $word_obj->{word};

    # That's a whole lotta tryin'!
    my $channel = $original_win_ref->{active};
    if (not defined $channel) {
        if (exists Irssi::active_win()->{active}) {
            $channel = Irssi::active_win()->{active};
        } elsif (defined Irssi::active_win()) {
            my @items = Irssi::active_win()->items;
            $channel = $items[0] if @items;
        } else {
            $channel = Irssi::parse_special('$C');
        }
    }

    if ($word =~ m/^\d+$/) {

        _debug("Skipping $word that is entirely numeric");
        spellcheck_next_word(); # aspell thinks numbers are wrong.

    } elsif (word_matches_chan_nick($channel, $word_obj)) {
        # skip to next word if it's actually a nick
        # (and the option is set) - checked for in the matches() func.
        _debug("Skipping $word that matches nick in channel");
        spellcheck_next_word();

    } elsif (not $aspell->check($word)) {

        _debug("Word '%s' is incorrect", $word);

        my $sugg_ref = get_suggestions($word);

        if (defined $sugg_ref && ref($sugg_ref) eq 'ARRAY') {
            @suggestions = @$sugg_ref;
        }

        if (scalar(@suggestions) == 0) {

            spellcheck_next_word();

        } elsif (not temp_split_active()) {

            $corrections_active = 1;
            highlight_incorrect_word($word_obj);
            _debug("Creating temp split to show candidates");
            create_temp_split();

        } else {

            print_suggestions();
        }
    } else {

        spellcheck_next_word();
    }
}

sub get_suggestions {
    my ($word) = @_;
    my @candidates = $aspell->suggest($word);
    _debug("Candidates for '$word' are %s", join(", ", @candidates));
    # if ($bacon) {
    return \@candidates;
    # } else {
    #     return undef;
    # }
}

sub word_matches_chan_nick {
    my ($channel, $word_obj) = @_;

    return 0 unless $ignore_chan_nicks;
    return 0 unless defined $channel and ref $channel;

    my @nicks;
    if (not exists ($channel->{type})) {
        return 0;
    } elsif ($channel->{type} eq 'QUERY') {

        # TODO: Maybe we need to parse ->{address} instead, but
        # it appears empty on test dumps.

        exists $channel->{name}
          and push @nicks, { nick => $channel->{name} };

        exists $channel->{visible_name}
          and push @nicks, { nick => $channel->{visible_name} };

    } elsif($channel->{type} eq 'CHANNEL') {
        @nicks = $channel->nicks();
    }

    my $nick_hash;

    $nick_hash->{$_}++ for (map { $_->{nick} } @nicks);

    _debug("Nicks: %s",  Dumper($nick_hash));

    # try various combinations of the word with its surrounding
    # punctuation.
    my $plain_word = $word_obj->{word};
    return 1 if exists $nick_hash->{$plain_word};
    my $pp_word = $word_obj->{prefix_punct} . $word_obj->{word};
    return 1 if exists $nick_hash->{$pp_word};
    my $sp_word = $word_obj->{word} . $word_obj->{suffix_punct};
    return 1 if exists $nick_hash->{$pp_word};
    my $full_word =
      $word_obj->{prefix_punct}
      . $word_obj->{word}
      . $word_obj->{suffix_punct};
    return 1 if exists $nick_hash->{$full_word};

    return 0;
}

# Read from the input line
sub cmd_spellcheck_line {
    my ($args, $server, $witem) = @_;

    if (defined $witem) {
        $original_win_ref = $witem->window;
    } else {
        $original_win_ref = Irssi::active_win;
    }

	my $inputline = _input();
    check_line($inputline);
}

sub spellcheck_finish {
    $corrections_active = 0;
    close_temp_split();

    # stick the cursor at the end of the input line?
    my $input = _input();
    my $end = length($input);
    Irssi::gui_input_set_pos($end);
}

sub sig_gui_key_pressed {
    my ($key) = @_;
    return unless $corrections_active;

    my $char = chr($key);

    if ($key == K_ESC) {
        spellcheck_finish();

    } elsif ($key >= K_0 && $key <= K_9) {
        _debug("Selecting word: $char of page: $suggestion_page");
        spellcheck_select_word($char + ($suggestion_page * 10));

    } elsif ($key == K_SPC) {
        _debug("skipping word");
        spellcheck_next_word();
    } elsif ($key == K_I) {

        my $current_word = $word_pos_array[$index];
        $aspell->add_to_personal($current_word->{word});
        $aspell->save_all_word_lists();

        _print('Saved %s to personal dictionary', $current_word->{word});

        spellcheck_next_word();

    } elsif ($key == K_N) { # next 10 results

        if ((scalar @suggestions) > (10 * ($suggestion_page + 1))) {
            $suggestion_page++;
        } else {
            $suggestion_page = 0;
        }
        print_suggestions();

    } elsif ($key == K_P) { # prev 10 results
        if ($suggestion_page > 0) {
            $suggestion_page--;
        }
        print_suggestions();

    } else {
        spellcheck_finish();
    }

    Irssi::signal_stop();
}

sub spellcheck_next_word {
    $index++;
    $suggestion_page = 0;

    if ($index >= @word_pos_array) {
        _debug("End of words");
        spellcheck_finish();
        return;
    }

    _debug("moving onto the next word: $index");
    process_word($word_pos_array[$index]);

}
sub spellcheck_select_word {
    my ($num) = @_;

    if ($num > $#suggestions) {
        _debug("$num past end of suggestions list.");
        return 0;
    }

    my $word = $suggestions[$num];
    _debug("Selected word $num: $word as correction");
    correct_input_line_word($word_pos_array[$index], $word);
    return 1;
}

sub _debug {
    my ($fmt, @args) = @_;
    return unless $DEBUG;

    $fmt = '%%RDEBUG:%%n ' . $fmt;
    my $str = sprintf($fmt, @args);
    Irssi::window_find_refnum(1)->print($str);
}

sub _print {
    my ($fmt, @args) = @_;
    my $str = sprintf($fmt, @args);
    Irssi::active_win->print('%g' . $str . '%n');
}

sub temp_split_active () {
    return defined $split_win_ref;
}

sub create_temp_split {
    #$original_win_ref = Irssi::active_win();
    Irssi::signal_add_first('window created', 'sig_win_created');
    Irssi::command('window new split');
    Irssi::signal_remove('window created', 'sig_win_created');
}

sub UNLOAD {
    _print("%%RASpell spellchecker Version %s unloading...%%n", $VERSION);
    close_temp_split();
}

sub close_temp_split {

    my $original_refnum = -1;
    my $active_refnum   = -2;

    my $active_win = Irssi::active_win();

    if (defined $active_win && ref($active_win) =~ m/^Irssi::/) {
        if (exists $active_win->{refnum}) {
            $active_refnum = $active_win->{refnum};
        }
    }

    if (defined $original_win_ref && ref($original_win_ref) =~ m/^Irssi::/) {
        if (exists $original_win_ref->{refnum}) {
            $original_refnum = $original_win_ref->{refnum};
        }
    }

    if ($original_refnum != $active_refnum && $original_refnum > 0) {
        Irssi::command("window goto $original_refnum");
    }

    if (defined($split_win_ref) && ref($split_win_ref) =~ m/^Irssi::/) {
        if (exists $split_win_ref->{refnum}) {
            my $split_refnum = $split_win_ref->{refnum};
            _debug("split_refnum is %d", $split_refnum);
            _debug("splitwin has: %s", join(", ", map { $_->{name} }
                                            $split_win_ref->items()));
            Irssi::command("window close $split_refnum");
            undef $split_win_ref;
        } else {
            _debug("refnum isn't in the split_win_ref");
        }
    } else {
        _debug("winref is undef or broken");
    }
}

sub sig_win_created {
    my ($win) = @_;
    $split_win_ref = $win;
    # printing directly from this handler causes irssi to segfault.
    Irssi::timeout_add_once(10, \&configure_split_win, {});
}

sub configure_split_win {
    $split_win_ref->command('window size 3');
    $split_win_ref->command('window name ASpell Suggestions');

    print_suggestions();
}

sub correct_input_line_word {
    my ($word_obj, $correction) = @_;
    my $input = _input();

    my $word = $word_obj->{word};
    my $pos  = $word_obj->{pos};
    my $len  = $word_obj->{len};

    # handle punctuation.
    # - Internal punctuation: "they're" "Bob's"  should be replaced if necessary
    # - external punctuation: "eg:" should not.
    # this will also have impact on the position adjustments.

    _debug("Index of incorrect word is %d", $index);
    _debug("Correcting word %s (%d) with %s", $word, $pos, $correction);


    #my $corrected_word = $prefix_punct . $correction . $suffix_punct;

    my $new_length  = length $correction;

    my $diff        = $new_length - $len;
    _debug("diff between $word and $correction is $diff");

    # record the fix in the array.
    $word_pos_array[$index] = { word => $correction, pos => $pos + $diff };
    # do the actual fixing of the input string
    substr($input, $pos, $len) = $correction;


    # now we have to go through and fix up all teh positions since
    # the correction might be a different length.

    foreach my $new_obj (@word_pos_array[$index..$#word_pos_array]) {
        #starting at $index, add the diff to each position.
        $new_obj->{pos} += $diff;
    }

    _debug("Setting input to new value: '%s'", $input);

    # put the corrected string back into the input field.
    Irssi::gui_input_set($input);

    _debug("-------------------------------------------------");
    spellcheck_next_word();
}

# move the cursor to the beginning of the word in question.
sub highlight_incorrect_word {
    my ($word_obj) = @_;
    Irssi::gui_input_set_pos($word_obj->{pos});
}

sub print_suggestions {
    my $count = scalar @suggestions;
    my $pages = int ($count / 10);
    my $bot = $suggestion_page * 10;
    my $top = $bot + 9;

    $top = $#suggestions if $top > $#suggestions;

    my @visible = @suggestions[$bot..$top];
    my $i = 0;

    @visible = map {
        '(%_' . $suggestion_colour . ($i++) . '%n) ' # bold/coloured selection num
          . $suggestion_colour . $_ . '%n' # coloured selection option
    } @visible;

    # disable timestamps to ensure a clean window.
    my $orig_ts_level = Irssi::parse_special('$timestamp_level');
    $split_win_ref->command("^set timestamp_level $orig_ts_level -CLIENTCRAP");

    # clear the window
    $split_win_ref->command("/^scrollback clear");
    my $msg = sprintf('%s [Pg %d/%d] Select a number or <SPC> to skip this '
                      . 'word. Press <i> to save this word to your personal '
                      . 'dictionary. Any other key cancels%s',
                      '%_', $suggestion_page + 1, $pages + 1, '%_');

    my $word = $word_pos_array[$index]->{word};

    $split_win_ref->print($msg, PRN_LEVEL);                   # header
    $split_win_ref->print('%_%R"' . $word . '"%n '            # erroneous word
                          .  join(" ", @visible), PRN_LEVEL); # suggestions

    # restore timestamp settings.
    $split_win_ref->command("^set timestamp_level $orig_ts_level");

}

sub sig_setup_changed {
    $DEBUG
      = Irssi::settings_get_bool('aspell_debug');
    $suggestion_colour
      = Irssi::settings_get_str('aspell_suggest_colour');
    $ignore_chan_nicks
      = Irssi::settings_get_bool('aspell_ignore_chan_nicks');



    my $old_lang = $aspell_language;

    $aspell_language
      = Irssi::settings_get_str('aspell_language');


    my $old_filepath = $irssi_dict_filepath;

    $irssi_dict_filepath
      = Irssi::settings_get_str('aspell_irssi_dict');

    _debug("Filepath: $irssi_dict_filepath");

    if ((not defined $old_filepath) or
        ($irssi_dict_filepath ne $old_filepath)) {
        reinit_aspell();
    }

    _debug("Language: $aspell_language");

    if ((not defined $old_lang) or
    ($old_lang ne $aspell_language)) {
        reinit_aspell();
    }

}

sub _input {
    return Irssi::parse_special('$L');
}

sub reinit_aspell {
    $aspell = Text::Aspell->new;
    $aspell->set_option('lang',     $aspell_language);
    $aspell->set_option('personal', $irssi_dict_filepath);
    $aspell->create_speller();
}

# sub cmd_break_cands {
#     $bacon = !$bacon;
#     _print("Bacon is now: %s", $bacon?"true":"false");
# }

sub init {
    my $default_dict_path
      = File::Spec->catfile(Irssi::get_irssi_dir,                 "irssi.dict");
    Irssi::settings_add_bool(AS_CFG, 'aspell_debug',              0);
    Irssi::settings_add_bool(AS_CFG, 'aspell_ignore_chan_nicks',  1);
    Irssi::settings_add_str(AS_CFG,  'aspell_suggest_colour',     '%g');
    Irssi::settings_add_str(AS_CFG,  'aspell_language',           'en_GB');
    Irssi::settings_add_str(AS_CFG,  'aspell_irssi_dict',   $default_dict_path);

    sig_setup_changed();

    Irssi::signal_add('setup changed' => \&sig_setup_changed);

    _print("%%RASpell spellchecker Version %s loaded%%n", $VERSION);

    $corrections_active = 0;
    $index              = 0;

    Irssi::signal_add_first('gui key pressed' => \&sig_gui_key_pressed);
    Irssi::command_bind('spellcheck'          => \&cmd_spellcheck_line);
    #Irssi::command_bind('breakon' => \&cmd_break_cands);
}

init();
