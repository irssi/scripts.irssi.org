################################################################################
# $Id: dau.pl 273 2008-02-03 15:27:25Z heidinger $
################################################################################
#
# dau.pl - write like an idiot
#
################################################################################
# Author
################################################################################
#
# Clemens Heidinger <heidinger@dau.pl>
#
################################################################################
# Changelog
################################################################################
#
# dau.pl has a built-in changelog (--changelog switch)
#
################################################################################
# Credits
################################################################################
#
# - Robert Hennig: For the original dau shell script. Out of this script,
#   merged with some other small Perl and shell scripts and aliases arised the
#   first version of dau.pl for irssi.
#
################################################################################
# Documentation
################################################################################
#
# dau.pl has a built-in documentation (--help switch)
#
################################################################################
# License
################################################################################
#
# Licensed under the BSD license
#
################################################################################
# Website
################################################################################
#
# http://dau.pl/
#
# Additional information, DAU.pm, the dauomat and the dauproxy
#
################################################################################

use 5.6.0;
use File::Basename;
use File::Path;
use IPC::Open3;
use Irssi 20021107.0841;
use Irssi::TextUI;
use locale;
use POSIX;
use re 'eval';
use strict;
use Tie::File;
use vars qw($VERSION %IRSSI);

$VERSION = '2.4.3';
#$VERSION = '2.4.3 SVN ($LastChangedRevision: 273 $)';
%IRSSI = (
          authors     => 'Clemens Heidinger',
          changed     => '$LastChangedDate: 2008-02-03 16:27:25 +0100 (Sun, 03 Feb 2008) $',
          commands    => 'dau',
          contact     => 'heidinger@dau.pl',
          description => 'write like an idiot',
          license     => 'BSD',
          modules     => 'File::Basename File::Path IPC::Open3 POSIX Tie::File',
          name        => 'DAU',
          sbitems     => 'daumode',
          url         => 'http://dau.pl/',
);

################################################################################
# Register commands
################################################################################

Irssi::command_bind('dau', \&command_dau);

################################################################################
# Register settings
# setting changed/added => change/add it here
################################################################################

# boolean
Irssi::settings_add_bool('misc', 'dau_away_quote_reason', 1);
Irssi::settings_add_bool('misc', 'dau_away_reminder', 0);
Irssi::settings_add_bool('misc', 'dau_babble_verbose', 1);
Irssi::settings_add_bool('misc', 'dau_color_choose_colors_randomly', 1);
Irssi::settings_add_bool('misc', 'dau_cowsay_print_cow', 0);
Irssi::settings_add_bool('misc', 'dau_figlet_print_font', 0);
Irssi::settings_add_bool('misc', 'dau_silence', 0);
Irssi::settings_add_bool('misc', 'dau_statusbar_daumode_hide_when_off', 0);
Irssi::settings_add_bool('misc', 'dau_tab_completion', 1);

# Integer
Irssi::settings_add_int('misc', 'dau_babble_history_size', 10);
Irssi::settings_add_int('misc', 'dau_babble_verbose_minimum_lines', 2);
Irssi::settings_add_int('misc', 'dau_cool_maximum_line', 2);
Irssi::settings_add_int('misc', 'dau_cool_probability_eol', 20);
Irssi::settings_add_int('misc', 'dau_cool_probability_word', 20);
Irssi::settings_add_int('misc', 'dau_remote_babble_interval_accuracy', 90);

# String
Irssi::settings_add_str('misc', 'dau_away_away_text', '$N is away now: [ $reason ]. Away since: $Z. I am currently not available at $T @ $chatnet (sry 4 amsg)!');
Irssi::settings_add_str('misc', 'dau_away_back_text', '$N is back: [ $reason ]. Away time: [ $time ]. I am available again at $T @ $chatnet (sry 4 amsg)!');
Irssi::settings_add_str('misc', 'dau_away_options',
                                                   "--parse_special --bracket -left '!---?[' -right ']?---!' --color -split capitals -random off -codes 'light red; yellow',"  .
                                                   "--parse_special --bracket -left '--==||{{' -right '}}||==--' --color -split capitals -random off -codes 'light red; light cyan'," .
                                                   "--parse_special --bracket -left '--==||[[' -right ']]||==--' --color -split capitals -random off -codes 'yellow; light green'"
);
Irssi::settings_add_str('misc', 'dau_away_reminder_interval', '1 hour');
Irssi::settings_add_str('misc', 'dau_away_reminder_text', '$N is still away: [ $reason ]. Away time: [ $time ] (sry 4 amsg)');
Irssi::settings_add_str('misc', 'dau_babble_options_line_by_line', '--nothing');
Irssi::settings_add_str('misc', 'dau_babble_options_preprocessing', '');
Irssi::settings_add_str('misc', 'dau_color_codes', 'blue; green; red; magenta; yellow; cyan');
Irssi::settings_add_str('misc', 'dau_cool_eol_style', 'random');
Irssi::settings_add_str('misc', 'dau_cowsay_cowlist', '');
Irssi::settings_add_str('misc', 'dau_cowsay_cowpath', &def_dau_cowsay_cowpath);
Irssi::settings_add_str('misc', 'dau_cowsay_cowpolicy', 'allow');
Irssi::settings_add_str('misc', 'dau_cowsay_cowsay_path', &def_dau_cowsay_cowsay_path);
Irssi::settings_add_str('misc', 'dau_cowsay_cowthink_path', &def_dau_cowsay_cowthink_path);
Irssi::settings_add_str('misc', 'dau_daumode_channels', '');
Irssi::settings_add_str('misc', 'dau_delimiter_string', ' ');
Irssi::settings_add_str('misc', 'dau_figlet_fontlist', 'mnemonic,term,ivrit');
Irssi::settings_add_str('misc', 'dau_figlet_fontpath', &def_dau_figlet_fontpath);
Irssi::settings_add_str('misc', 'dau_figlet_fontpolicy', 'allow');
Irssi::settings_add_str('misc', 'dau_figlet_path', &def_dau_figlet_path);
Irssi::settings_add_str('misc', 'dau_files_away', '.away');
Irssi::settings_add_str('misc', 'dau_files_babble_messages', 'babble_messages');
Irssi::settings_add_str('misc', 'dau_files_cool_suffixes', 'cool_suffixes');
Irssi::settings_add_str('misc', 'dau_files_root_directory', "$ENV{HOME}/.dau");
Irssi::settings_add_str('misc', 'dau_files_substitute', 'substitute.pl');
Irssi::settings_add_str('misc', 'dau_language', 'en');
Irssi::settings_add_str('misc', 'dau_moron_eol_style', 'random');
Irssi::settings_add_str('misc', 'dau_parse_special_list_delimiter', ' ');
Irssi::settings_add_str('misc', 'dau_random_options',
                                                      '--substitute --boxes --uppercase,' .
                                                      "--substitute --color -split capitals -random off -codes 'light red; yellow'," .
                                                      "--substitute --color -split capitals -random off -codes 'light red; light cyan'," .
                                                      "--substitute --color -split capitals -random off -codes 'yellow; light green'," .
                                                      '--substitute --color --uppercase,' .
                                                      '--substitute --cool,' .
                                                      '--substitute --delimiter,' .
                                                      '--substitute --dots --moron,' .
                                                      '--substitute --leet,' .
                                                      '--substitute --mix,' .
                                                      '--substitute --mixedcase --bracket,' .
                                                      '--substitute --moron --stutter --uppercase,' .
                                                      '--substitute --moron -omega on,' .
                                                      '--substitute --moron,' .
                                                      '--substitute --uppercase --underline,' .
                                                      '--substitute --words --mixedcase'
);
Irssi::settings_add_str('misc', 'dau_remote_babble_channellist', '');
Irssi::settings_add_str('misc', 'dau_remote_babble_channelpolicy', 'deny');
Irssi::settings_add_str('misc', 'dau_remote_babble_interval', '1 hour');
Irssi::settings_add_str('misc', 'dau_remote_channellist', '');
Irssi::settings_add_str('misc', 'dau_remote_channelpolicy', 'deny');
Irssi::settings_add_str('misc', 'dau_remote_deop_reply', 'you are on my shitlist now @ $nick');
Irssi::settings_add_str('misc', 'dau_remote_devoice_reply', 'you are on my shitlist now @ $nick');
Irssi::settings_add_str('misc', 'dau_remote_op_reply', 'thx 4 op @ $nick');
Irssi::settings_add_str('misc', 'dau_remote_permissions', '000000');
Irssi::settings_add_str('misc', 'dau_remote_question_regexp', '%%%DISABLED%%%');
Irssi::settings_add_str('misc', 'dau_remote_question_reply', 'EDIT_THIS_ONE');
Irssi::settings_add_str('misc', 'dau_remote_voice_reply', 'thx 4 voice @ $nick');
Irssi::settings_add_str('misc', 'dau_standard_messages', 'hi @ all');
Irssi::settings_add_str('misc', 'dau_standard_options', '--random');
Irssi::settings_add_str('misc', 'dau_words_range', '1-4');

################################################################################
# Register signals
# (Note that most signals are set dynamical in the subroutine signal_handling)
################################################################################

Irssi::signal_add_last('setup changed', \&signal_setup_changed);
Irssi::signal_add_last('window changed' => sub { Irssi::statusbar_items_redraw('daumode') });
Irssi::signal_add_last('window item changed' => sub { Irssi::statusbar_items_redraw('daumode') });

################################################################################
# Register statusbar items
################################################################################

Irssi::statusbar_item_register('daumode', '', 'statusbar_daumode');

################################################################################
# Global variables
################################################################################

# Timer used by --away

our %away_timer;

# babble

our %babble;

# --command -in

our $command_in;

# The command to use for the output (MSG f.e.)

our $command_out;

# '--command -out' used?

our $command_out_activated;

# Counter for the subroutines entered

our $counter_subroutines;

# Counter for the switches
# --me --moron: --me would be 0, --moron 1

our $counter_switches;

# daumode

our %daumode;

# daumode activated?

our $daumode_activated;

# Help text

our %help;
$help{options} = <<END;
%9--away%9
    Toggle away mode

    %9-channels%9 %U'#channel1/network1, #channel2/network2, ...'%U:
        Say away message in all those %Uchannels%U

    %9-interval%9 %Utime%U:
        Remind channel now and then that you're away

    %9-reminder%9 %Uon|off%U:
        Turn reminder on or off

%9--babble%9
    Babble a message.

    %9-at%9 %Unicks%U:
        Comma separated list of nicks to babble at.
        \$nick1, \$nick2 and so forth of the babble line will be replaced
        by those nicks.

    %9-cancel%9 %Uon|off%U:
        Cancel active babble

    %9-filter%9 %Uregular expression%U:
        Only let through if the babble matches the %Uregular expression%U

    %9-history_size%9 %Un%U:
        Set the size of the history for this one babble to %Un%U

%9--boxes%9
    Put words in boxes

%9--bracket%9
    Bracket the text

    %9-left%9 %Ustring%U:
        Left bracket

    %9-right%9 %Ustring%U:
        Right bracket

%9--changelog%9
    Print the changelog

%9--chars%9
    Only one character each line

%9--color%9
    Write in colors

    %9-codes%9 %Ucodes%U:
        Overrides setting dau_color_codes

    %9-random%9 %Uon|off%U:
        Choose color randomly from setting dau_color_codes resp.
        %9--color -codes%9 or take one by one in the exact order given.

    %9-split%9
        %Ucapitals%U:   Split by capitals
        %Uchars%U:      Every character another color
        %Ulines%U:      Every line another color
        %Uparagraph%U:  The whole paragraph in one color
        %Urchars%U:     Some characters one color
        %Uwords%U:      Every word another color

%9--command%9
    %9-in%9 %Ucommand%U:
        Feed dau.pl with the output (the public message)
        that %Ucommand%U produces

    %9-out%9 %Ucommand%U:
        %Utopic%U for example will set a dauified topic

%9--cool%9
    Be \$cool[tm]!!!!11one

    %9-eol_style%9 %Ustring%U:
        Override setting dau_cool_eol_style

    %9-max%9 %Un%U:
        \$Trademarke[tm] only %Un%U words per line tops

    %9-prob_eol%9 %U0-100%U:
        Probability that "!!!11one" or something like that will be put at EOL.
        Set it to 100 and every line will be.
        Set it to 0 and no line will be.

    %9-prob_word%9 %U0-100%U:
        Probability that a word will be \$trademarked[tm].
        Set it to 100 and every word will be.
        Set it to 0 and no word will be.

%9--cowsay%9
    Use cowsay to write

    %9-arguments%9 %Uarguments%U:
        Pass any option to cowsay, f.e. %U'-b'%U or %U'-e XX'%U.
        Look in the cowsay manualpage for details.

    %9-cow%9 %Ucow%U:
        The cow to use

    %9-think%9 %Uon|off%U:
        Thinking instead of speaking

%9--create_files%9
    Create files and directories of all dau_files_* settings

%9--daumode%9
    Toggle daumode.
    Works on a per channel basis!

    %9-modes_in%9 %Umodes%U:
        All incoming messages will be dauified and the
        specified modes are used by dau.pl.

    %9-modes_out%9 %Umodes%U:
        All outgoing messages will be dauified and the
        specified modes are used by dau.pl.

    %9-perm%9 %U[01][01]%U:
        Dauify incoming/outgoing messages?

%9--delimiter%9
    Insert a delimiter-string after each character

    %9-string%9 %Ustring%U:
        Override setting dau_delimiter_string. If this string
        contains whitespace, you should quote the string with
        single quotes.

%9--dots%9
    Put dots... after words...

%9--figlet%9
    Use figlet to write

    %9-font%9 %Ufont%U:
        The font to use

%9--help%9
    Print help

    %9-setting%9 %Usetting%U:
        More information about a specific setting

%9--leet%9
    Write in leet speech

%9--long_help%9
    Long help, i.e. examples, more about some features, ...

%9--me%9
    Send a CTCP ACTION instead of a PRIVMSG

%9--mix%9
    Mix all the characters in a word except for the first and last

%9--mixedcase%9
    Write in mixed case

%9--moron%9
    Write in uppercase, mix in some typos, perform some
    substitutions on the text, ... Just write like a
    moron

    %9-eol_style%9 %Ustring%U:
        Override setting dau_moron_eol_style

    %9-level%9 %Un%U:
        %Un%U gives the level of stupidity applied to text,
        the higher the stupider.
        %U0%U is the minimum, %U1%U currently only implemented for dau_language = de.

    %9-omega%9 %Uon|off%U:
        The fantastic omega mode

    %9-typo%9 %Uon|off%U:
        Mix in random typos

    %9-uppercase%9 %Uon|off%U:
        Uppercase text

%9--nothing%9
    Do nothing

%9--parse_special%9
    Parse for special metasequences and substitute them.

    %9-irssi_variables%9 %Uon|off%U:
        Parse irssi special variables like \$N

    %9-list_delimiter%9 %Ustring%U:
        Set the list delimiter used for \@nicks and \@opnicks to %Ustring%U.

    The special metasequences are:

    - \\n:
      real newline
    - \$nick1 .. \$nickN:
      N different randomly selected nicks
    - \@nicks:
      All nicks in channel
    - \$opnick1 .. \$opnickN:
      N different randomly selected opnicks
    - \@opnicks:
      All nicks in channel with operator status
    - \$?{ code }:
      the (perl)code will be evaluated and the last expression
      returned will replace that metasequence
    - irssis special variables like \$C for the current
      channel and \$N for your current nick

    Quoting:

    - \\\$: literal \$
    - \\\\: literal \\

%9--random%9
    Let dau.pl choose the options randomly. Get these options from the setting
    dau_random_options.

    %9-verbose%9 %Uon|off%U:
        Print what options --random has chosen

%9--reverse%9
    Reverse the input string

%9--stutter%9
    Stutter a bit

%9--substitute%9
    Apply own substitutions from file

%9--underline%9
    Underline text

%9--uppercase%9
    Write in upper case

%9--words%9
    Only a few words each line
END

# Containing irssi's 'cmdchars'

our $k = Irssi::parse_special('$k');

# Remember your nick mode

our %nick_mode;

# All the options

our %option;

# print() the message or not?

our $print_message;

# Queue holding the switches

our %queue;

# Remember the last switches used by --random so that they don't repeat

our $random_last;

# Signals

our %signal = (
    'complete word'     => 0,
    'daumode in'        => 0,
    'event 404'         => 0,
    'event privmsg'     => 0,
    'nick mode changed' => 0,
    'send text'         => 0,
);

# All switches that may be given at commandline

our %switches = (

    # These switches may be combined

    combo  => {
                boxes     => { 'sub'  => \&switch_boxes },
                bracket   => {
                              'sub' => \&switch_bracket,
                               left  => { '*' => 1 },
                               right => { '*' => 1 },
                             },
                chars     => { 'sub' => \&switch_chars },
                color     => {
                              'sub'   => \&switch_color,
                              codes   => { '*' => 1 },
                              random  => {
                                           off => 1,
                                           on  => 1,
                                          },
                              'split' => {
                                          capitals  => 1,
                                          chars     => 1,
                                          lines     => 1,
                                          paragraph => 1,
                                          rchars    => 1,
                                          words     => 1,
                                         },
                             },
                command   => {
                              'sub' => \&switch_command,
                               in   => { '*' => 1 },
                               out  => { '*' => 1 },
                               },
                cool      => {
                              'sub'      => \&switch_cool,
                               eol_style => {
                                             suffixes          => 1,
                                             exclamation_marks => 1,
                                             random            => 1,
                                            },
                               max       => { '*' => 1 },
                               prob_eol  => { '*' => 1 },
                               prob_word => { '*' => 1 },
                             },
                cowsay    => {
                              'sub'       => \&switch_cowsay,
                               arguments  => { '*' => 1 },
                               think      => {
                                              off => 1,
                                              on  => 1,
                                             },
                             },
                delimiter => {
                              'sub'    => \&switch_delimiter,
                               string  => { '*' => 1 },
                             },
                dots      => { 'sub' => \&switch_dots },
                figlet    => { 'sub' => \&switch_figlet },
                me        => { 'sub' => \&switch_me },
                mix       => { 'sub' => \&switch_mix },
                moron     => {
                              'sub'      => \&switch_moron,
                               eol_style => {
                                             nothing => 1,
                                             random  => 1,
                                            },
                               level     => { '*' => 1 },
                               omega     => {
                                             off => 1,
                                             on  => 1,
                                            },
                               typo      => {
                                             off => 1,
                                             on  => 1,
                                            },
                               uppercase => {
                                             off => 1,
                                             on  => 1,
                                            },
                             },
                leet          => { 'sub' => \&switch_leet },
                mixedcase     => { 'sub' => \&switch_mixedcase },
                nothing       => { 'sub' => \&switch_nothing },
                parse_special => {
                                  'sub' => \&switch_parse_special,
                                  irssi_variables => {
                                                      off => 1,
                                                      on  => 1,
                                                     },
                                  list_delimiter  => { '*' => 1 },
                                 },
                'reverse'     => { 'sub' => \&switch_reverse },
                stutter       => { 'sub' => \&switch_stutter },
                substitute    => { 'sub' => \&switch_substitute },
                underline     => { 'sub' => \&switch_underline },
                uppercase     => { 'sub' => \&switch_uppercase },
                words         => { 'sub' => \&switch_words },
               },

    # The following switches must not be combined

    nocombo => {
                away         => {
                                 'sub' => \&switch_away,
                                 channels => { '*' => 1 },
                                 interval => { '*' => 1 },
                                 reminder => {
                                              on  => 1,
                                              off => 1,
                                             },
                                },
                babble       => {
                                 'sub'        => \&switch_babble,
                                 at           => { '*' => 1 },
                                 cancel       => {
                                                  on  => 1,
                                                  off => 1,
                                                 },
                                 filter       => { '*' => 1 },
                                 history_size => { '*' => 1 },
                                },
                changelog    => { 'sub' => \&switch_changelog },
                create_files => { 'sub' => \&switch_create_files },
                daumode      => {
                                 'sub'      => \&switch_daumode,
                                  modes_in  => { '*' => 1 },
                                  modes_out => { '*' => 1 },
                                  perm      => {
                                                '00' => 1,
                                                '01' => 1,
                                                '10' => 1,
                                                '11' => 1,
                                               },
                                },
                help         => {
                                 'sub'     => \&switch_help,

                                 # setting changed/added => change/add it here

                                 setting => {
                                             # boolean
                                             dau_away_quote_reason               => 1,
                                             dau_away_reminder                   => 1,
                                             dau_babble_verbose                  => 1,
                                             dau_color_choose_colors_randomly    => 1,
                                             dau_cowsay_print_cow                => 1,
                                             dau_figlet_print_font               => 1,
                                             dau_silence                         => 1,
                                             dau_statusbar_daumode_hide_when_off => 1,
                                             dau_tab_completion                  => 1,

                                             # Integer
                                             dau_babble_history_size             => 1,
                                             dau_babble_verbose_minimum_lines    => 1,
                                             dau_cool_maximum_line               => 1,
                                             dau_cool_probability_eol            => 1,
                                             dau_cool_probability_word           => 1,
                                             dau_remote_babble_interval_accuracy => 1,

                                             # String
                                             dau_away_away_text                  => 1,
                                             dau_away_back_text                  => 1,
                                             dau_away_options                    => 1,
                                             dau_away_reminder_interval          => 1,
                                             dau_away_reminder_text              => 1,
                                             dau_babble_options_line_by_line     => 1,
                                             dau_babble_options_preprocessing    => 1,
                                             dau_color_codes                     => 1,
                                             dau_cool_eol_style                  => 1,
                                             dau_cowsay_cowlist                  => 1,
                                             dau_cowsay_cowpath                  => 1,
                                             dau_cowsay_cowpolicy                => 1,
                                             dau_cowsay_cowsay_path              => 1,
                                             dau_cowsay_cowthink_path            => 1,
                                             dau_daumode_channels                => 1,
                                             dau_delimiter_string                => 1,
                                             dau_figlet_fontlist                 => 1,
                                             dau_figlet_fontpath                 => 1,
                                             dau_figlet_fontpolicy               => 1,
                                             dau_figlet_path                     => 1,
                                             dau_files_away                      => 1,
                                             dau_files_babble_messages           => 1,
                                             dau_files_cool_suffixes             => 1,
                                             dau_files_root_directory            => 1,
                                             dau_files_substitute                => 1,
                                             dau_language                        => 1,
                                             dau_moron_eol_style                 => 1,
                                             dau_parse_special_list_delimiter    => 1,
                                             dau_random_options                  => 1,
                                             dau_remote_babble_channellist       => 1,
                                             dau_remote_babble_channelpolicy     => 1,
                                             dau_remote_babble_interval          => 1,
                                             dau_remote_channellist              => 1,
                                             dau_remote_channelpolicy            => 1,
                                             dau_remote_deop_reply               => 1,
                                             dau_remote_devoice_reply            => 1,
                                             dau_remote_op_reply                 => 1,
                                             dau_remote_permissions              => 1,
                                             dau_remote_question_regexp          => 1,
                                             dau_remote_question_reply           => 1,
                                             dau_remote_voice_reply              => 1,
                                             dau_standard_messages               => 1,
                                             dau_standard_options                => 1,
                                             dau_words_range                     => 1,
                                            },
                                },
                long_help => { 'sub'    => \&switch_long_help },
                random    => { 'sub'    => \&switch_random,
                                verbose => {
                                            off => 1,
                                            on  => 1,
                                           },
                             },
               },
);

################################################################################
# Code run once at start
################################################################################

print CLIENTCRAP "dau.pl $VERSION loaded. For help type %9${k}dau --help%9 or %9${k}dau --long_help%9";

signal_setup_changed();
build_nick_mode_struct();
signal_handling();

################################################################################
# Subroutines (commands)
################################################################################

sub command_dau {
	my ($data, $server, $witem) = @_;
	my $output;

	$output = parse_text($data, $witem);

	unless (defined($server) && $server && $server->{connected}) {
		$print_message = 1;
	}
	unless ((defined($witem) && $witem &&
	       ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY')))
	{
		$print_message = 1;
	}

	if ($daumode_activated) {

		if (defined($witem) && $witem &&
		   ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY'))
		{
			my $modes_set = 0;

			# daumode set with parameters (modes_in)

			if ($queue{0}{daumode}{modes_in}) {
				$daumode{channels_in}{$server->{tag}}{$witem->{name}} = 1;
				$daumode{channels_in_modes}{$server->{tag}}{$witem->{name}} =
				$queue{0}{daumode}{modes_in};
				$modes_set = 1;
			}

			# daumode set with parameters (modes_out)

			if ($queue{0}{daumode}{modes_out}) {
				$daumode{channels_out}{$server->{tag}}{$witem->{name}} = 1;
				$daumode{channels_out_modes}{$server->{tag}}{$witem->{name}} =
				$queue{0}{daumode}{modes_out};
				$modes_set = 1;
			}

			# daumode set without parameters

			if (!$daumode{channels_in}{$server->{tag}}{$witem->{name}} &&
			    !$daumode{channels_out}{$server->{tag}}{$witem->{name}} &&
			    !$modes_set)
			{
				$daumode{channels_in}{$server->{tag}}{$witem->{name}} = 1;
				$daumode{channels_out}{$server->{tag}}{$witem->{name}} = 1;
				$daumode{channels_in_modes}{$server->{tag}}{$witem->{name}} = '';
				$daumode{channels_out_modes}{$server->{tag}}{$witem->{name}} = '';
			}

			# daumode unset

			elsif (($daumode{channels_in}{$server->{tag}}{$witem->{name}}  ||
			        $daumode{channels_out}{$server->{tag}}{$witem->{name}}) &&
			        !$modes_set)
			{
				$daumode{channels_in}{$server->{tag}}{$witem->{name}} = 0;
				$daumode{channels_out}{$server->{tag}}{$witem->{name}} = 0;
				$daumode{channels_in_modes}{$server->{tag}}{$witem->{name}} = '';
				$daumode{channels_out_modes}{$server->{tag}}{$witem->{name}} = '';
			}


			# the perm-option overrides everything

			# perm: 00

			if ($queue{0}{daumode}{perm} eq '00') {
				$daumode{channels_in}{$server->{tag}}{$witem->{name}} = 0;
				$daumode{channels_out}{$server->{tag}}{$witem->{name}} = 0;
				$daumode{channels_in_modes}{$server->{tag}}{$witem->{name}} = '';
				$daumode{channels_out_modes}{$server->{tag}}{$witem->{name}} = '';
			}

			# perm: 01

			if ($queue{0}{daumode}{perm} eq '01') {
				$daumode{channels_in}{$server->{tag}}{$witem->{name}} = 0;
				$daumode{channels_out}{$server->{tag}}{$witem->{name}} = 1;
				$daumode{channels_in_modes}{$server->{tag}}{$witem->{name}} = '';
			}

			# perm: 10

			if ($queue{0}{daumode}{perm} eq '10') {
				$daumode{channels_in}{$server->{tag}}{$witem->{name}} = 1;
				$daumode{channels_out}{$server->{tag}}{$witem->{name}} = 0;
				$daumode{channels_out_modes}{$server->{tag}}{$witem->{name}} = '';
			}

			# perm: 11

			if ($queue{0}{daumode}{perm} eq '11') {
				$daumode{channels_in}{$server->{tag}}{$witem->{name}} = 1;
				$daumode{channels_out}{$server->{tag}}{$witem->{name}} = 1;
			}

			Irssi::statusbar_items_redraw('daumode');
		}

		# Signal handling (for daumode and signal 'send text')

		signal_handling();

		return;
	}

	# MSG (or CTCP ACTION) $output to active channel/query-window

	{
		no strict 'refs';

		$output = $output || '';
		output_text($witem, $witem->{name}, $output);
	}
}

################################################################################
# Subroutines (switches, must not be combined)
################################################################################

sub switch_away {
	my ($reason, $channel_rec, $reminder, $interval) = @_;
	my $output;
	my $time;
	my $status = 'away';

	################################################################################
	################################################################################
	# Get and handle options
	################################################################################
	################################################################################

	################################################################################
	# "/dau --away -interval <interval>" resp. dau_away_reminder_interval setting
	################################################################################

	# If called from command line, i.e. not by the
	# "/dau --away -channels '<channels>'" workaround, $interval will be defined
	# here
	if (!defined($interval)) {
		$interval = time_parse(return_option('away', 'interval', $option{dau_away_reminder_interval}));
	}
	if ($interval < 10 || $interval > 1000000000) {
		print_err('Invalid value for away timer!');
		return;
	}

	################################################################################
	# setting dau_away_options
	################################################################################

	my $options = return_random_list_item($option{dau_away_options});

	################################################################################
	# "/dau --away -reminder <on|off>" resp. dau_away_reminder setting
	################################################################################

	# If called from command line, i.e. not by "/dau --away -channels '<channels>'"
	# workaround, $reminder will be defined here
	if (!defined($reminder)) {
		$reminder = return_option('away', 'reminder', $option{dau_away_reminder});
	}

	# on -> 1, off -> 0
	if ($reminder eq 'on' || $reminder == 1) {
		$reminder = 1;
	} else {
		$reminder = 0;
	}

	################################################################################
	# "/dau --away -channels '<channels>'"
	################################################################################

	# Go through all channels and for each call this subroutine again with
	# $reminder and $interval as additional parameter as those otherwise would be
	# lost. Sad world.

	my $channels = return_option('away', 'channels');
	# If not deleted, the program may loop here.
	undef($queue{0}{away}{channels});
	while ($channels =~ m{([^/]+)/([^,]+),?\s*}g) {
		my $channel = $1;
		my $network = $2;

		my $server_rec  = Irssi::server_find_tag($network);
		my $channel_rec = $server_rec->channel_find($channel);

		if (defined($channel_rec) && $channel_rec &&
		       ($channel_rec->{type} eq 'CHANNEL' || $channel_rec->{type} eq 'QUERY'))
		{
			switch_away($reason, $channel_rec, $reminder, $interval);
		}

	}
	# "/dau --away -channels '<channels>'" first run => exit
	return if ($channels);

	################################################################################
	# Now we are clear (from -channels)...
	################################################################################

	# Normal "/dau --away" (i.e. no -channels), but called from non
	# channel/query window => exit
	unless (defined($channel_rec) && $channel_rec &&
	       ($channel_rec->{type} eq 'CHANNEL' || $channel_rec->{type} eq 'QUERY'))
	{
		return;
	}

	my $channel = $channel_rec->{name};
	my $network = $channel_rec->{server}->{tag};
	my $id      = "$channel/$network";

	################################################################################
	# Open file
	################################################################################

	my $file = "$option{dau_files_root_directory}/$option{dau_files_away}";
	my @file;
	unless (tie(@file, 'Tie::File', $file)) {
		print_err("Cannot tie $file!");
		return;
	}

	################################################################################
	# Go through/edit file
	################################################################################

	# Format:
	# channel | network | time | options | reminder | interval | reason
	my $i = 0;
	foreach my $line (@file) {
		if ($line =~ m{^\Q$channel\E\x02\Q$network\E\x02(\d+)\x02([^\x02]*)\x02(?:\d)\x02(?:\d+)\x02(.*)}) {
			$time = $1;
			$options = $2;
			$reason = $3;
			$status = 'back';
			last;
		}
		$i++;
	}

	if ($status eq 'away' && $reason eq '') {
		print_out('Please set reason for your being away!');
		return;
	}

	if ($status eq 'away') {
		push(@file, "$channel\x02$network\x02" . time . "\x02$options\x02$reminder\x02$interval\x02$reason");
		$output = $option{dau_away_away_text};
	}

	if ($status eq 'back') {
		splice(@file, $i, 1);
		$output = $option{dau_away_back_text};
	}

	################################################################################
	# Special variables
	################################################################################

	# $time

	if ($status eq 'back') {
		my $difference = time_diff_verbose(time, $time);
		$output =~ s/\$time/$difference/g;
	}

	# $reason

	if ($option{dau_away_quote_reason}) {
		$reason =~ s/\\/\\\\/g;
		$reason =~ s/\$/\\\$/g;
	}
	$output =~ s/\$reason/$reason/g;

	################################################################################
	# Write changes back to file
	################################################################################

	untie(@file);

	################################################################################
	# The reminder timer
	################################################################################

	if ($status eq 'away' && $reminder) {
		$away_timer{$id} = Irssi::timeout_add($interval, \&timer_away_reminder, $id);
	} else {
		Irssi::timeout_remove($away_timer{$id});
	}

	################################################################################
	# Print message to channel
	################################################################################

	$output = parse_text("$options $output", $channel_rec);
	output_text($channel_rec, $channel_rec->{name}, $output);

	return;
}

sub switch_babble {
	my ($data, $channel) = @_;
	my $text;

	# Cancel babble?

	if (lc(return_option('babble', 'cancel')) eq 'on') {
		if (defined($babble{timer_writing})) {
			Irssi::timeout_remove($babble{timer_writing});
			undef($babble{timer_writing});

			if ($babble{remote}) {
				timer_remote_babble_reset();
			}

			print_out("Babble cancelled.");
		}
		return;
	}

	# Filters

	my @filter = ();
	my $option_babble_at           = return_option('babble', 'at');
	my $option_babble_filter       = return_option('babble', 'filter');
	my $option_babble_history_size = return_option('babble', 'history_size', $option{dau_babble_history_size});

	if ($option_babble_filter) {
		push(@filter, $option_babble_filter);
	}

	# If something is babbling right now, exit

	if (defined($babble{timer_writing})) {
		print_err("You are already babbling something!");
		return;
	}

	# get text from file

	if ($option_babble_at) {
		my @nicks;
		foreach my $nick (split(/\s*,\s*/, $option_babble_at)) {
			push(@nicks, $nick);
		}
		if (@nicks > 0) {
			for (my $i = 1; $i <= $#nicks + 1; $i++) {
				push(@filter, '\$nick' . $i);
			}
		}

		$text = &babble_get_text($channel, \@filter, \@nicks, $option_babble_history_size);
	} else {
		$text = &babble_get_text($channel, \@filter, undef, $option_babble_history_size);
	}

	# babble only in channels

	unless (defined($channel) && $channel && $channel->{type} eq 'CHANNEL') {
		print_out('%9--babble%9 will only work in channel windows!');
		return;
	}

	# Start the babbling

	babble_start($channel, $text, 0);

	return;
}

sub switch_changelog {
	my $output;
	$print_message = 1;

	$output = &fix(<<"	END");
	CHANGELOG

	2002-05-05    release 0.1.0
	              initial release

	2002-05-06    release 0.1.1
	              maintenance release

	2002-05-11    release 0.2.0
	              new feature: %9--delimiter%9

	2002-05-12    release 0.3.0
	              new feature: %9--mixedcase%9

	2002-05-17    release 0.4.0
	              %9--delimiter%9 revised

	2002-05-20    release 0.4.1
	              some nice new substitutions for %9--moron%9

	2002-05-24    release 0.5.0
	              new settings for %9--figlet%9

	2002-06-15    release 0.6.0
	              new settings for %9--figlet%9

	2002-06-16    release 0.6.1
	              maintenance release

	2002-06-16    release 0.6.2
	              maintenance release

	2002-06-17    release 0.7.0
	              new stuff for %9--moron%9

	2002-06-19    release 0.8.0
	              new feature: %9--dots%9

	2002-06-23    release 0.9.0
	              new "reply to question" remote feature

	2002-06-23    release 0.9.1
	              maintenance release

	2002-06-29    release 0.9.2
	              maintenance release

	2002-07-23    release 0.9.3
	              maintenance release

	2002-07-28    release 1.0.0
	              - Tabcompletion for the switches
	              - new feature: %9--changelog%9
	              - new feature: %9--help%9
	              - new feature: %9--leet%9
	              - new feature: %9--reverse%9

	2002-07-28    release 1.0.1
	              maintenance release

	2002-09-01    release 1.0.2
	              maintenance release

	2002-09-03    release 1.0.3
	              new switch for %9--figlet%9: %9-font%9

	2002-09-03    release 1.0.4
	              maintenance release

	2002-09-03    release 1.0.5
	              maintenance release

	2002-09-09    release 1.1.0
	              You can combine switches now!

	2002-11-22    release 1.2.0
	              - new setting: %9dau_moron_eol_style%9
	              - new setting: %9dau_standard_messages%9
	              - new setting: %9dau_standard_options%9
	              - new remote features: Say something on (de)op/(de)voice
	              - new switch for %9--delimiter%9: %9-string%9
	              - new switch for %9--moron%9: %9-eol_style%9
	              - new feature: %9--color%9
	              - new feature: %9--daumode%9
	              - new feature: %9--random%9
	              - new feature: %9--stutter%9
	              - new feature: %9--uppercase%9
	              - new statusbar item: %9daumode%9

	2002-11-27    release 1.2.1
	              maintenance release

	2002-12-15    release 1.2.2
	              maintenance release

	2003-01-12    release 1.3.0
	              - new setting: %9dau_files_root_directory%9
	              - %9--moron%9: randomly transpose letters with letters
	                next to them at the keyboard
	              - new switch for %9--moron%9: %9-uppercase%9
	              - new feature: %9--create_files%9

	2003-01-17    release 1.4.0
	              - %9--color%9 revised
	              - new remote feature: babble

	2003-01-18    release 1.4.1
	              maintenance release

	2003-01-20    release 1.4.2
	              new setting: %9dau_statusbar_daumode_hide_when_off%9

	2003-02-01    release 1.4.3
	              maintenance release

	2003-02-09    release 1.4.4
	              maintenance release

	2003-02-16    release 1.4.5
	              maintenance release

	2003-03-16    release 1.4.6
	              maintenance release

	2003-05-01    release 1.5.0
	              - new setting: %9dau_tab_completion%9
	              - new feature: %9--bracket%9

	2003-06-13    release 1.5.1
	              new feature: %9--underline%9

	2003-07-16    release 1.5.2
	              new feature: %9--boxes%9

	2003-08-16    release 1.5.3
	              maintenance release

	2003-09-14    release 1.5.4
	              maintenance release

	2003-11-16    release 1.6.0
	              - Incoming messages can be dauified now!
	              - daumode statusbar item revised

	2004-03-25    release 1.7.0
	              - new setting: %9dau_babble_options_line_by_line%9
	              - new setting: %9dau_files_babble_messages%9
	              - new switch for %9--color%9: %9-split paragraph%9
	              - new switch for %9--command%9: %9-in%9
	              - new switch for %9--moron%9: %9-omega%9
	              - new feature: %9--cowsay%9
	              - new feature: %9--mix%9 (by Martin Kihlgren <zond\@troja.ath.cx>)

	2004-04-01    release 1.7.1
	              - new setting: %9dau_remote_babble_channellist%9
	              - new setting: %9dau_remote_babble_channelpolicy%9
	              - new setting: %9dau_remote_babble_interval_accuracy%9

	2004-04-02    release 1.7.2
	              maintenance release

	2004-04-05    release 1.7.3
	              maintenance release

	2004-05-01    release 1.8.0
	              - new feature: %9--babble%9
	              - %9--help%9 revised

	2004-06-24    release 1.8.1
	              - new setting: %9dau_babble_verbose%9
	              - new setting: %9dau_babble_verbose_minimum_lines%9

	2004-07-10    release 1.8.2
	              maintenance release

	2004-07-25    release 1.8.3
	              maintenance release

	2004-09-14    release 1.8.4
	              maintenance release

	2004-10-18    release 1.8.5
	              maintenance release

	2004-11-07    release 1.8.6
	              maintenance release

	2005-01-28    release 1.9.0
	              - new setting: %9dau_cowsay_cowthink_path%9
	              - new switch for %9--cowsay%9: %9-arguments%9
	              - new switch for %9--cowsay%9: %9-think%9

	2005-06-05    release 2.0.0
	              - new setting: %9dau_color_choose_colors_randomly%9
	              - new setting: %9dau_color_codes%9
	              - new setting: %9dau_language%9
	              - new setting: %9dau_remote_question_regexp%9
	              - new switch for %9--bracket%9: %9-left%9
	              - new switch for %9--bracket%9: %9-right%9
	              - new switch for %9--color%9: %9-codes%9
	              - new switch for %9--color%9: %9-random%9
	              - new switch for %9--color%9: %9-split capitals%9
	              - new feature: %9--away%9
	              - new feature: %9--cool%9
	              - new feature: %9--long_help%9
	              - new feature: %9--parse_special%9

	2005-07-01    release 2.1.0
	              - new switch for %9--babble%9: %9-at%9
	              - %9--color%9: Support for background colors
	              - %9--color -codes%9: You may use now the color names
	                instead of the numeric color codes

	2005-07-24    release 2.1.1
	              maintenance release

	2005-08-02    release 2.1.2
	              maintenance release

	2005-11-01    release 2.1.3
	              maintenance release

	2006-03-11    release 2.1.4
	              maintenance release

	2006-05-21    release 2.1.5
	              new switch for %9--babble%9: %9-filter%9

	2006-10-25    release 2.1.6
	              new switch for %9--babble%9: %9-cancel%9

	2006-11-25    release 2.2.0
	              new feature: %9--substitute%9

	2007-03-07    release 2.3.0
	              - new setting: %9dau_daumode_channels%9
	              - new switch for %9--moron%9: %9-level%9
	              - new switch for %9--moron%9: %9-typo%9
	              - new switch for %9--random%9: %9-verbose%9

	2007-03-08    release 2.3.1
	              maintenance release

	2007-03-11    release 2.3.2
	              maintenance release

	2007-03-18    release 2.3.3
	              maintenance release

	2007-06-02    release 2.4.0
	              - new setting: %9dau_babble_history_size%9
	              - new switch for %9--babble%9: %9-history_size%9

	2007-06-26    release 2.4.1
	              maintenance release

	2007-10-11    release 2.4.2
	              maintenance release

	2008-02-03    release 2.4.3
	              maintenance release
	END

	return $output;
}

sub switch_create_files {

	# create directory dau_files_root_directory if not found

	if (-f $option{dau_files_root_directory}) {
		print_err("$option{dau_files_root_directory} is a _file_ => aborting");
		return;
	}
	if (-d $option{dau_files_root_directory}) {
		print_out('directory dau_files_root_directory already exists - no need to create it');
	} else {
		if (mkpath([$option{dau_files_root_directory}])) {
			print_out("creating directory $option{dau_files_root_directory}/");
		} else {
			print_err("failed creating directory $option{dau_files_root_directory}/");
		}
	}

	# create file dau_files_substitute if not found

	my $file1 = "$option{dau_files_root_directory}/$option{dau_files_substitute}";

	if (-e $file1) {

		print_out("file $file1 already exists - no need to create it");

	} else {

		if (open(FH1, "> $file1")) {

			print FH1 &fix(<<'			END');
			# dau.pl - http://dau.pl/
			#
			# This is the file --moron will use for your own substitutions.
			# You can use any perlcode in here.
			# $_ contains the text you can work with.
			# $_ has to contain the data to be returned to dau.pl at the end.
			END

			print_out("$file1 created. you should edit it now!");

		} else {

			print_err("cannot write $file1: $!");

		}

		if (!close(FH1)) {
			print_err("cannot close $file1: $!");
		}
	}

	# create file dau_files_babble_messages if not found

	my $file2 = "$option{dau_files_root_directory}/$option{dau_files_babble_messages}";

	if (-e $file2) {

		print_out("file $file2 already exists - no need to create it");

	} else {

		if (open(FH1, "> $file2")) {

			print FH1 &fix(<<'			END');
			END

			print_out("$file2 created. you should edit it now!");

		} else {

			print_err("cannot write $file2: $!");

		}

		if (!close(FH1)) {
			print_err("cannot close $file2: $!");
		}
	}

	# create file dau_files_cool_suffixes if not found

	my $file3 = "$option{dau_files_root_directory}/$option{dau_files_cool_suffixes}";

	if (-e $file3) {

		print_out("file $file3 already exists - no need to create it");

	} else {

		if (open(FH1, "> $file3")) {

			print FH1 &fix(<<'			END');
			END

			print_out("$file3 created. you should edit it now!");

		} else {

			print_err("cannot write $file3: $!");

		}

		if (!close(FH1)) {
			print_err("cannot close $file3: $!");
		}
	}

	return;
}

sub switch_daumode {
	$daumode_activated = 1;
}

sub switch_help {
	my $output;
	my $option_setting = return_option('help', 'setting');
	$print_message = 1;

	if ($option_setting eq '') {
		$output = &fix(<<"		END");
		%9OPTIONS%9

		$help{options}
		END
	}

	# setting changed/added => change/add them below

	# boolean

	elsif ($option_setting eq 'dau_away_quote_reason') {
		$output = &fix(<<"		END");
		%9dau_away_quote_reason%9 %Ubool

		If turned on, %9--parse_special%9 will not be able to replace
		variables which probably aren't one anyway.
		END
	}
	elsif ($option_setting eq 'dau_away_reminder') {
		$output = &fix(<<"		END");
		%9dau_away_reminder%9 %Ubool

		Turn the reminder message of %9--away%9 on or off.
		END
	}
	elsif ($option_setting eq 'dau_babble_verbose') {
		$output = &fix(<<"		END");
		%9dau_babble_verbose%9 %Ubool

		Before babbling print a message how many lines will be babbled and
		when finished a notification message.
		END
	}
	elsif ($option_setting eq 'dau_color_choose_colors_randomly') {
		$output = &fix(<<"		END");
		%9dau_color_choose_colors_randomly%9 %Ubool

		Choose colors randomly from setting dau_color_codes resp.
		%9--color -codes%9 or take one by one in the exact order given.
		END
	}
	elsif ($option_setting eq 'dau_cowsay_print_cow') {
		$output = &fix(<<"		END");
		%9dau_cowsay_print_cow%9 %Ubool

		Print a message which cow will be used.
		END
	}
	elsif ($option_setting eq 'dau_figlet_print_font') {
		$output = &fix(<<"		END");
		%9dau_figlet_print_font%9 %Ubool

		Print a message which font will be used.
		END
	}
	elsif ($option_setting eq 'dau_silence') {
		$output = &fix(<<"		END");
		%9dau_silence%9 %Ubool

		Don't print any information message. This does not include
		error messages.
		END
	}
	elsif ($option_setting eq 'dau_statusbar_daumode_hide_when_off') {
		$output = &fix(<<"		END");
		%9dau_statusbar_daumode_hide_when_off%9 %Ubool

		Hide statusbar item when daumode is turned off.
		END
	}
	elsif ($option_setting eq 'dau_tab_completion') {
		$output = &fix(<<"		END");
		%9dau_tab_completion%9 %Ubool

		Perhaps someone wants to disable TAB completion for the
		${k}dau-command because he/she doesn't like it or wants
		to give the CPU a break (don't know whether it has much
		influence)
		END
	}

	# Integer

	elsif ($option_setting eq 'dau_babble_history_size') {
		$output = &fix(<<"		END");
		%9dau_babble_history_size%9 %Uinteger

		Number of lines to store in the babble history.
		dau.pl will babble no line the history is holding.
		END
	}
	elsif ($option_setting eq 'dau_babble_verbose_minimum_lines') {
		$output = &fix(<<"		END");
		%9dau_babble_verbose_minimum_lines%9 %Uinteger

		Minimum lines necessary to produce the output of the verbose
		information.
		END
	}
	elsif ($option_setting eq 'dau_cool_maximum_line') {
		$output = &fix(<<"		END");
		%9dau_cool_maximum_line%9 %Uinteger

		Trademarke[tm] or do \$this only %Un%U words per line tops.
		END
	}
	elsif ($option_setting eq 'dau_cool_probability_eol') {
		$output = &fix(<<"		END");
		%9dau_cool_probability_eol%9 %Uinteger

		Probability that "!!!11one" or something like that will be put at EOL.
		Set it to 100 and every line will be.
		Set it to 0 and no line will be.
		END
	}
	elsif ($option_setting eq 'dau_cool_probability_word') {
		$output = &fix(<<"		END");
		%9dau_cool_probability_word%9 %Uinteger

		Probability that a word will be trademarked[tm].
		Set it to 100 and every word will be.
		Set it to 0 and no word will be.
		END
	}
	elsif ($option_setting eq 'dau_remote_babble_interval_accuracy') {
		$output = &fix(<<"		END");
		%9dau_remote_babble_interval_accuracy%9 %Uinteger

		Value expressed as a percentage how accurate the timer of
		the babble feature should be.

		Legal values: 1-100

		%U100%U would result in a very accurate timer.
		END
	}

	# String

	elsif ($option_setting eq 'dau_away_away_text') {
		$output = &fix(<<"		END");
		%9dau_away_away_text%9 %Ustring

		The text to say when using %9--away%9.

		Special Variables:

		\$reason: Your away reason.
		END
	}
	elsif ($option_setting eq 'dau_away_back_text') {
		$output = &fix(<<"		END");
		%9dau_away_back_text%9 %Ustring

		The text to say when you return.

		Special Variables:

		\$reason: Your away reason.
		\$time:   The time you've been away.
		END
	}
	elsif ($option_setting eq 'dau_away_reminder_interval') {
		$output = &fix(<<"		END");
		%9dau_away_reminder_interval%9 %Ustring

		Remind the channel that you're away! Repeat the message
		in the given interval.
		END
	}
	elsif ($option_setting eq 'dau_away_reminder_text') {
		$output = &fix(<<"		END");
		%9dau_away_reminder_text%9 %Ustring

		The text to say when you remind the channel that you're away.

		Special Variables:

		\$reason: Your away reason.
		\$time:   The time you've been away.
		END
	}
	elsif ($option_setting eq 'dau_away_options') {
		$output = &fix(<<"		END");
		%9dau_away_options%9 %Ustring

		Options %9--away%9 will use.
		END
	}
	elsif ($option_setting eq 'dau_babble_options_line_by_line') {
		$output = &fix(<<"		END");
		%9dau_babble_options_line_by_line%9 %Ustring

		One single babble may contain several lines. The options
		specified in this setting are used for every line.
		END
	}
	elsif ($option_setting eq 'dau_babble_options_preprocessing') {
		$output = &fix(<<"		END");
		%9dau_babble_options_preprocessing%9 %Ustring

		The options specified in this setting are applied to the
		whole babble before anything else. Later, the options of
		the setting %9dau_babble_options_line_by_line%9 are
		applied to every line of the babble.
		END
	}
	elsif ($option_setting eq 'dau_color_codes') {
		$output = &fix(<<"		END");
		%9dau_color_codes%9 %Ustring

		Specify the color codes to use, seperated by semicolons.
		Example: %Ugreen; red; blue%U. You may use the color code (one
		or two digits) or the color names. So either
		%U2%U or %Ublue%U is ok. You can set a background color too:
		%Ured,green%U and you will write with red on a green
		background.
		For a complete list of the color codes and names look at
		formats.txt in the irssi documentation.
		END
	}
	elsif ($option_setting eq 'dau_cool_eol_style') {
		$output = &fix(<<"		END");
		%9dau_cool_eol_style%9 %Ustring

		%Uexclamation_marks%U: !!!11one
		%Urandom%U:            Choose one style randomly
		%Usuffixes%U:          Suffixes from file
		END
	}
	elsif ($option_setting eq 'dau_cowsay_cowlist') {
		$output = &fix(<<"		END");
		%9dau_cowsay_cowlist%9 %Ustring

		Comma separated list of cows. Checkout
		%9${k}dau --help -setting dau_cowsay_cowpolicy%9
		to see what this setting is good for.
		END
	}
	elsif ($option_setting eq 'dau_cowsay_cowpath') {
		$output = &fix(<<"		END");
		%9dau_cowsay_cowpath%9 %Ustring

		Path to the cowsay-cows (*.cow).
		END
	}
	elsif ($option_setting eq 'dau_cowsay_cowpolicy') {
		$output = &fix(<<"		END");
		%9dau_cowsay_cowpolicy%9 %Ustring

		Specifies the policy used to handle the cows in
		dau_cowsay_cowpath. If set to %Uallow%U, all cows available
		will be used by the command. You can exclude some cows by
		setting dau_cowsay_cowlist. If set to %Udeny%U, no cows but
		the ones listed in dau_cowsay_cowlist will be used by the
		command. Useful if you have many annoying cows in your
		cowpath and you want to permit only a few of them.
		END
	}
	elsif ($option_setting eq 'dau_cowsay_cowsay_path') {
		$output = &fix(<<"		END");
		%9dau_cowsay_cowsay_path%9 %Ustring

		Should point to the cowsay executable.
		END
	}
	elsif ($option_setting eq 'dau_cowsay_cowthink_path') {
		$output = &fix(<<"		END");
		%9dau_cowsay_cowthink_path%9 %Ustring

		Should point to the cowthink executable.
		END
	}
	elsif ($option_setting eq 'dau_daumode_channels') {
		$output = &fix(<<"		END");
		%9dau_daumode_channels%9 %U<channel>/<network>:<switches>, ...%U

		Automatically enable the daumode for some channels.
		%U#foo/bar:-modes_out '--substitute'%U would automatically
		set the daumode on #foo in network bar to modify outgoing
		messages with --substitute.
		END
	}
	elsif ($option_setting eq 'dau_delimiter_string') {
		$output = &fix(<<"		END");
		%9dau_delimiter_string%9 %Ustring

		Tell %9--delimiter%9 which delimiter to use.
		END
	}
	elsif ($option_setting eq 'dau_figlet_fontlist') {
		$output = &fix(<<"		END");
		%9dau_figlet_fontlist%9 %Ustring

		Comma separated list of fonts. Checkout
		%9${k}dau --help -setting dau_figlet_fontpolicy%9
		to see what this setting is good for. Use the program
		`showfigfonts` shipped with figlet to find these fonts.
		END
	}
	elsif ($option_setting eq 'dau_figlet_fontpath') {
		$output = &fix(<<"		END");
		%9dau_figlet_fontpath%9 %Ustring

		Path to the figlet-fonts (*.flf).
		END
	}
	elsif ($option_setting eq 'dau_figlet_fontpolicy') {
		$output = &fix(<<"		END");
		%9dau_figlet_fontpolicy%9 %Ustring

		Specifies the policy used to handle the fonts in
		dau_figlet_fontpath. If set to %Uallow%U, all fonts available
		will be used by the command. You can exclude some fonts by
		setting dau_figlet_fontlist. If set to %Udeny%U, no fonts but
		the ones listed in dau_figlet_fontlist will be used by the
		command. Useful if you have many annoying fonts in your
		fontpath and you want to permit only a few of them.
		END
	}
	elsif ($option_setting eq 'dau_figlet_path') {
		$output = &fix(<<"		END");
		%9dau_figlet_path%9 %Ustring

		Should point to the figlet executable.
		END
	}
	elsif ($option_setting eq 'dau_files_away') {
		$output = &fix(<<"		END");
		%9dau_files_away%9 %Ustring

		The file with the away messages.
		_Must_ be in dau_files_root_directory.
		END
	}
	elsif ($option_setting eq 'dau_files_babble_messages') {
		$output = &fix(<<"		END");
		%9dau_files_babble_messages%9 %Ustring

		The file with the babble messages.
		_Must_ be in dau_files_root_directory.
		%9${k}dau --create_files%9 will create it.

		Format of the file: Newline separated plain text.
		The text will be sent through %9--parse_special%9 as well.
		END
	}
	elsif ($option_setting eq 'dau_files_cool_suffixes') {
		$output = &fix(<<"		END");
		%9dau_files_cool_suffixes%9 %Ustring

		%9--cool%9 takes randomly one line out of this file
		and puts it at the end of the line.
		This file _must_ be in dau_files_root_directory.
		%9${k}dau --create_files%9 will create it.

		Format of the file: Newline separated plain text.
		END
	}
	elsif ($option_setting eq 'dau_files_root_directory') {
		$output = &fix(<<"		END");
		%9dau_files_root_directory%9 %Ustring

		Directory in which all files for dau.pl will be stored.
		%9${k}dau --create_files%9 will create it.
		END
	}
	elsif ($option_setting eq 'dau_files_substitute') {
		$output = &fix(<<"		END");
		%9dau_files_substitute%9 %Ustring

		Your own substitutions file. _Must_ be in
		dau_files_root_directory.
		%9${k}dau --create_files%9 will create it.
		END
	}
	elsif ($option_setting eq 'dau_language') {
		$output = &fix(<<"		END");
		%9dau_language%9 %Ustring

		%Ude%U: If you are writing in german
		%Uen%U: If you are writing in english
		END
	}
	elsif ($option_setting eq 'dau_moron_eol_style') {
		$output = &fix(<<"		END");
		%9dau_moron_eol_style%9 %Ustring

		What to do at End Of Line?

		%Urandom%U:
		    - !!!??!!!!!????!??????????!!!1
		    - =
		      ?
		    - ?¿?
		%Unothing%U: do nothing
		END
	}
	elsif ($option_setting eq 'dau_parse_special_list_delimiter') {
		$output = &fix(<<"		END");
		%9dau_parse_special_list_delimiter%9 %Ustring

		Set the list delimiter used for \@nicks and \@opnicks to %Ustring%U.
		END
	}
	elsif ($option_setting eq 'dau_random_options') {
		$output = &fix(<<"		END");
		%9dau_random_options%9 %Ustring

		Comma separated list of options %9--random%9 will use. It will
		take randomly one item of the list. If you set it f.e. to
		%U--uppercase --color,--mixedcase%U,
		the probability of printing a colored, uppercased string hello
		will be 50% as well as the probabilty of printing a mixedcased
		string hello when typing %9${k}dau --random hello%9.
		END
	}
	elsif ($option_setting eq 'dau_remote_babble_channellist') {
		$output = &fix(<<"		END");
		%9dau_remote_babble_channellist%9 %Ustring

		Comma separated list of channels. You'll have to specify the
		ircnet too.
		Format: #channel1/IRCNet,#channel2/EFnet
		END
	}
	elsif ($option_setting eq 'dau_remote_babble_channelpolicy') {
		$output = &fix(<<"		END");
		%9dau_remote_babble_channelpolicy%9 %Ustring

		Using the default policy %Udeny%U the script won't do anything
		except in the channels listed in dau_remote_babble_channellist.
		Using the policy %Uallow%U the script will babble in all
		channels but the ones listed in dau_remote_babble_channellist.
		END
	}
	elsif ($option_setting eq 'dau_remote_babble_interval') {
		$output = &fix(<<"		END");
		%9dau_remote_babble_interval%9 %Ustring

		dau.pl will babble text in the given interval.
		END
	}
	elsif ($option_setting eq 'dau_remote_channellist') {
		$output = &fix(<<"		END");
		%9dau_remote_channellist%9 %Ustring

		Comma separated list of channels. You'll have to specify the
		ircnet too.
		Format: #channel1/IRCNet,#channel2/EFnet
		END
	}
	elsif ($option_setting eq 'dau_remote_channelpolicy') {
		$output = &fix(<<"		END");
		%9dau_remote_channelpolicy%9 %Ustring

		Using the default policy %Udeny%U the script won't do anything
		except in the channels listed in dau_remote_channellist. Using
		the policy %Uallow%U the script will reply to all channels but
		the ones listed in dau_remote_channellist.
		END
	}
	elsif ($option_setting eq 'dau_remote_deop_reply') {
		$output = &fix(<<"		END");
		%9dau_remote_deop_reply%9 %Ustring

		Comma separated list of messages (it will take randomly one
		item of the list) sent to channel if someone deops you (mode
		change -o).
		The string given will be processed by the same subroutine
		parsing the %9${k}dau%9 command.

		Special Variables:

		\$nick: contains the nick of the one who changed the mode
		END
	}
	elsif ($option_setting eq 'dau_remote_devoice_reply') {
		$output = &fix(<<"		END");
		%9dau_remote_devoice_reply%9 %Ustring

		Comma separated list of messages (it will take randomly one
		item of the list) sent to channel if someone devoices you (mode
		change -v).
		The string given will be processed by the same subroutine
		parsing the %9${k}dau%9 command.

		Special Variables:

		\$nick: contains the nick of the one who changed the mode
		END
	}
	elsif ($option_setting eq 'dau_remote_op_reply') {
		$output = &fix(<<"		END");
		%9dau_remote_op_reply%9 %Ustring

		Comma separated list of messages (it will take randomly one
		item of the list) sent to channel if someone ops you (mode
		change +o).
		The string given will be processed by the same subroutine
		parsing the %9${k}dau%9 command.

		Special Variables:

		\$nick: contains the nick of the one who changed the mode
		END
	}
	elsif ($option_setting eq 'dau_remote_permissions') {
		$output = &fix(<<"		END");
		%9dau_remote_permissions%9 %U[01][01][01][01][01][01]

		Permit or forbid the remote features.

		First Bit:
		    Reply to question

		Second Bit:
		    If someone gives you voice in a channel, thank him!

		Third Bit:
		    If someone gives you op in a channel, thank him!

		Fourth Bit:
		    If devoiced, print message

		Fifth Bit:
		    If deopped, print message

		Sixth Bit:
		    Babble text in certain intervals
		END
	}
	elsif ($option_setting eq 'dau_remote_question_regexp') {
		$output = &fix(<<"		END");
		%9dau_remote_question_regexp%9 %Ustring

		If someone says something matching that regular expression,
		act accordingly.
		The regexp will be sent through %9--parse_special%9.
		Because of that you will have to escape some characters, f.e.
		\\s to \\\\s for whitespace.
		END
	}
	elsif ($option_setting eq 'dau_remote_question_reply') {
		$output = &fix(<<"		END");
		%9dau_remote_question_reply%9 %Ustring

		Comma separated list of reply strings for the question of
		setting dau_remote_question_regexp (it will randomly choose one
		item of the list).
		The string given will be processed by the same subroutine
		parsing the %9${k}dau%9 command.

		Special Variables:

		\$nick: contains the nick of the one who sent the message to which
		       dau.pl reacts
		END
	}
	elsif ($option_setting eq 'dau_remote_voice_reply') {
		$output = &fix(<<"		END");
		%9dau_remote_voice_reply%9 %Ustring

		Comma separated list of messages (it will take randomly one
		item of the list) sent to channel if someone voices you (mode
		change +v).
		The string given will be processed by the same subroutine
		parsing the %9${k}dau%9 command.

		Special Variables:

		\$nick: contains the nick of the one who changed the mode
		END
	}
	elsif ($option_setting eq 'dau_standard_messages') {
		$output = &fix(<<"		END");
		%9dau_standard_messages%9 %Ustring

		Comma separated list of strings %9${k}dau%9 will use if the user
		omits the text on the commandline.
		END
	}
	elsif ($option_setting eq 'dau_standard_options') {
		$output = &fix(<<"		END");
		%9dau_standard_options%9 %Ustring

		Options %9${k}dau%9 will use if the user omits them on the commandline.
		END
	}
	elsif ($option_setting eq 'dau_words_range') {
		$output = &fix(<<"		END");
		%9dau_words_range%9 %Ui-j

		Setup the range howmany words the command should write per line.
		1 <= i <= j <= 9; i, j element { 1, ... , 9 }. If i == j the command
		will write i words to the active window.  Else it takes a random
		number k (element { i, ... , j }) and writes k words per
		line.
		END
	}

	return $output;
}

sub switch_long_help {
	my $output;
	$print_message = 1;

	$output = &fix(<<"	END");
	%9SYNOPSIS%9

	%9${k}dau [%Uoptions%U] [%Utext%U%9]

	%9DESCRIPTION%9

	dau? What does that mean? It's a german acronym for %9d%9ümmster
	%9a%9nzunehmender %9u%9ser. In english: stupidest imaginable user.

	With dau.pl every person can write like an idiot on the IRC!

	%9OPTIONS%9

	$help{options}
	%9EXAMPLES%9

	%9${k}dau --uppercase --mixedcase %Ufoo bar baz%9
	    Will write %Ufoo bar baz%U in mixed case.
	    %Ufoo bar baz%U is sent _first_ to %9--uppercase%9, _then_ to
	    %9--mixedcase%9.
	    The order in which you put the options on the commandline is
	    important!
	    You can see what output a command produces without sending it to
	    the active channel/query by sending it to a non-channel/query
	    window.

	%9${k}dau --color --figlet %Ufoo bar baz%9
	    %9--color%9 is the first to be run and thus color codes will
	    be inserted.
	    The string will look like %U\\00302f\\00303o[...]%U when leaving
	    %9--color%9.
	    %9--figlet%9 uses then that string as its input.
	    So you'll have finally an output like
	    %U02f03o[...]%U in the figlet letters.
	    You'll probably want to use %9--figlet --color%9 instead.

	%9SPECIAL FEATURES%9

	%9Combine the options%9
	    You can combine most of the options! So you can write colored
	    leet messages f.e.. Look in the EXAMPLES section above.

	%9Babble%9
	    dau.pl will babble text for you. It can do this on its own
	    in certain intervals or forced by the user using %9--babble%9.

	    Related settings:

	    %9dau_babble_options_line_by_line%9
	    %9dau_files_babble_messages%9
	    %9dau_files_root_directory%9
	    %9dau_remote_babble_channellist%9
	    %9dau_remote_babble_channelpolicy%9
	    %9dau_remote_babble_interval%9
	    %9dau_remote_babble_interval_accuracy%9
	    %9dau_remote_permissions%9

	    Related switches:

	    %9--babble%9
	    %9--create_files%9

	%9Daumode%9
	    Dauify incoming and/or outgoing messages.

	    There is a statusbar item available displaying the current
	    status of the daumode. Add it with
	    %9/statusbar <bar> add [-alignment <left|right>] daumode%9
	    You may customize the look of the statusbar item in the
	    theme file:

	    sb_daumode = "{sb daumode I: \$0 (\$1) O: \$2 (\$3)}";

	    # \$0: will incoming messages be dauified?
	    # \$1: modes for incoming messages
	    # \$2: will outgoing messages be dauified?
	    # \$3: modes for outgoing messages

	%9Remote features%9
	    Don't worry, dau.pl won't do anything automatically unless you
	    unlock these features!

	    %9Babble%9
	        dau.pl will babble text for you in certain intervals.

	    %9Reply to a question%9
	        Answer a question as a moron would.

	        Related settings:

	        %9dau_remote_channellist%9
	        %9dau_remote_channelpolicy%9
	        %9dau_remote_permissions%9
	        %9dau_remote_question_regexp%9
	        %9dau_remote_question_reply%9

	    %9Say something on (de)op/(de)voice%9
	        Related settings:

	        %9dau_remote_channellist%9
	        %9dau_remote_channelpolicy%9
	        %9dau_remote_deop_reply%9
	        %9dau_remote_devoice_reply%9
	        %9dau_remote_op_reply%9
	        %9dau_remote_permissions%9
	        %9dau_remote_voice_reply%9

	%9TAB Completion%9
	    There is a really clever TAB Completion included! Since
	    commands can get very long you definitely want to use it.
	    It will only complete syntactically correct commands so the
	    TAB Completion isn't only a time saver, it's a control
	    instance too. You'll be suprised to see that it even completes
	    the figlet fonts and cows for cowsay that are available on
	    your system.

	%9Website%9
	    $IRSSI{url}:
	    Additional information, DAU.pm, the dauomat and the dauproxy.
	END

	return $output;
}

sub switch_random {
	my ($data, $channel_rec) = @_;
	my $output;
	my (@options, $opt, $text);

	# Push each item of dau_random_options in the @options array.

	while ($option{dau_random_options} =~ /\s*([^,]+)\s*,?/g) {
		my $item = $1;
		push @options, $item;
	}

	# More than one item in @options. Choose one randomly but exclude
	# the last item chosen.

	if (@options > 1) {
		@options = grep { $_ ne $random_last } @options;
		$opt = @options[rand(@options)];
		$random_last = $opt;
	}

	# Exact one item in @options - take that

	elsif (@options == 1) {
		$opt = $options[0];
		$random_last = $opt;
	}


	# No item in @options - call switch_moron()

	else {
		$opt = '--moron';
	}

	# dauify it!

	unless (lc(return_option('random', 'verbose')) eq 'off') {
		print_out("%9--random%9 has chosen %9$opt%9", $channel_rec);
	}
	$text .= $opt . ' ' . $data;
	$output = parse_text($text, $channel_rec);

	return $output;
}

################################################################################
# Subroutines (switches, may be combined)
################################################################################

sub switch_boxes {
	my $data = shift;

	# handling punctuation marks:
	# they will be put in their own box later

	$data =~ s%(\w+)([,.?!;:]+)%
	           $1 . ' ' . join(' ', split(//, $2))
	          %egx;

	# separate words (by whitespace) and put them in a box

	$data =~ s/(\s*)(\S+)(\s*)/$1\[$2\]$3/g;

	return $data;
}

sub switch_bracket {
	my $data = shift;
	my $output;

	my $option_left  = return_option('bracket', 'left');
	my $option_right = return_option('bracket', 'right');

	my %brackets = (
                        '(('   => '))',
                        '-=('  => ')=-',
                        '-=['  => ']=-',
                        '-={'  => '}=-',
                        '-=|(' => ')|=-',
                        '-=|[' => ']|=-',
                        '-=|{' => '}|=-',
                        '.:>'  => '<:.',
                       );

	foreach (keys %brackets) {
		for my $times (2 .. 3) {
			my $pre  = $_;
			my $post = $brackets{$_};
			$pre  =~ s/(.)/$1 x $times/eg;
			$post =~ s/(.)/$1 x $times/eg;

			$brackets{$pre} = $post;
		}
	}

	$brackets{'!---?['} = ']?---!';
	$brackets{'(qp=>'}  = '<=qp)';
	$brackets{'----->'} = '<-----';

	my ($left, $right);
	if ($option_left && $option_right) {
		$left  = $option_left;
		$right = $option_right;
	} else {
		$left  = (keys(%brackets))[int(rand(keys(%brackets)))];
		$right = $brackets{$left};
	}

	$output = "$left $data $right";

	return $output;
}

sub switch_chars {
	my $data = shift;
	my $output;

	foreach my $char (split //, $data) {
		$output .= "$char\n";
	}
	return $output;
}

sub switch_command {
	my ($data, $channel_rec) = @_;

	# -out <command>

	$command_out = return_option('command', 'out');
	$command_out_activated = 1;

	# -in <command>

	$command_in = '';
	my $option_command_in = return_option('command', 'in');

	if ($option_command_in) {
		return unless (defined($channel_rec) && $channel_rec);

		# Deactivate daumode for a brief moment
		$signal{'send text'} = 0;
		Irssi::signal_remove('send text', 'signal_send_text');

		# Capture the output
		Irssi::signal_add_first('command msg', 'signal_command_msg');
		$channel_rec->command("$option_command_in $data");
		Irssi::signal_remove('command msg', 'signal_command_msg');

		# Reactivate daumode
		signal_handling();

		return $command_in;
	}

	return $data;
}

sub switch_color {
	my $data = shift;
	my (@all_colors, @colors, $output, $split);

	################################################################################
	# Hack to support UTF-8
	################################################################################

	if (Irssi::settings_get_str('term_charset') =~ /utf-?8/i) {
		eval {
			require Encode;
			$data = Encode::decode("utf-8", $data);
		};
	}

	################################################################################
	# Get options
	################################################################################

	my $option_color_split  = return_option('color', 'split', 'words');
	my $option_color_codes  = return_option('color', 'codes', $option{dau_color_codes});
	my $option_color_random = return_option('color', 'random', $option{dau_color_choose_colors_randomly});
	if ($option_color_random eq 'on' || $option_color_random == 1) {
		$option_color_random = 1;
	} else {
		$option_color_random = 0;
	}

	################################################################################
	# color name -> color code
	################################################################################

	$option_color_codes =~ s/\blight green\b/09/gi;
	$option_color_codes =~ s/\bgreen\b/03/gi;
	$option_color_codes =~ s/\blight red\b/04/gi;
	$option_color_codes =~ s/\bred\b/05/gi;
	$option_color_codes =~ s/\blight cyan\b/11/gi;
	$option_color_codes =~ s/\bcyan\b/10/gi;
	$option_color_codes =~ s/\blight blue\b/12/gi;
	$option_color_codes =~ s/\bblue\b/02/gi;
	$option_color_codes =~ s/\blight magenta\b/13/gi;
	$option_color_codes =~ s/\bmagenta\b/06/gi;
	$option_color_codes =~ s/\blight grey\b/15/gi;
	$option_color_codes =~ s/\bgrey\b/14/gi;

	$option_color_codes =~ s/\bwhite\b/00/gi;
	$option_color_codes =~ s/\bblack\b/01/gi;
	$option_color_codes =~ s/\borange\b/07/gi;
	$option_color_codes =~ s/\byellow\b/08/gi;

	################################################################################
	# Produce @all_colors
	################################################################################

	# <color code>5 shall be a colored 5

	$option_color_codes =~ s/(\d+)/sprintf('%02d', $1)/eg;

	# Fill @all_colors and do error checking

	my @all_colors = split(/\s*;\s*/, $option_color_codes);
	foreach my $code (@all_colors) {
		if ($code !~ /^\d+(,\d+)?$/) {
			print_err("Incorrect color code '$code'!");
			return $data;
		}
	}
	if (@all_colors == 0) {
		print_err('No color code found.');
		return $data;
	}
	@colors = @all_colors;

	################################################################################
	# "-split capitals"
	################################################################################

	if ($option_color_split eq 'capitals') {
		$output = $data;
		my ($color1, $color2);
		if ($option_color_random) {
			$color1 = $colors[rand(@colors)];
			@colors = grep { $_ ne $color1 } @colors unless (@colors == 1);
			$color2 = $colors[rand(@colors)];
		} else {
			if (@colors == 1) {
				$color1 = $color2 = $colors[0];
			} else {
				$color1 = $colors[0];
				$color2 = $colors[1];
			}
		}

		$output =~ s/([[:upper:][:punct:]]+|\b\S)/\003${color1}${1}\003${color2}/g;

		# Remove needless color codes
		$output =~ s/\003(?:$color1|$color2)( *)\003(?:$color1|$color2)/$1/g;
		$output =~ s/\003(?:$color1|$color2)$//;
	}

	################################################################################
	# Not "-split capitals"
	################################################################################

	else {
		if ($option_color_split eq 'chars') {
			$split = '';
		} elsif ($option_color_split eq 'lines') {
			$split = "\n";
		} elsif ($option_color_split eq 'words') {
			$split = '\s+';
		} elsif ($option_color_split eq 'rchars') {
			$split = '.' x rand(10);
		} elsif ($option_color_split eq 'paragraph') {
			$split = "\n";
		} else {
			$split = '\s+';
		}

		my $i = 0;
		my $background = 0;
		my $color;
		for (split /($split)/, $data) {
			if (/^\s*$/) {
				$output .= $_;
				next;
			}
			if ($option_color_random) {
				$color = $colors[rand(@colors)];

				$output .= "\017" if ($background && $color !~ /,/);
				$output .= "\003" . $color . $_;

				if ($color =~ /,/) {
					$background = 1;
				} else {
					$background = 0;
				}

				if ($option_color_split eq 'paragraph') {
					@colors = ($color);
				} else {
					@colors = grep { $_ ne $color } @all_colors unless (@all_colors == 1);
				}
			} else {
				$color = $colors[($i++ % ($#colors + 1))];

				if ($option_color_split eq 'paragraph') {
					$color = $colors[0];
				}

				$output .= "\017" if ($background && $color !~ /,/);
				$output .= "\003" . $color . $_;

				if ($color =~ /,/) {
					$background = 1;
				} else {
					$background = 0;
				}
			}
		}
	}

	return $output;
}

sub switch_cool {
	my ($data, $channel) = @_;
	my $output;

	################################################################################
	# Get the options
	################################################################################

	my $option_eol_style = return_option('cool', 'eol_style', $option{dau_cool_eol_style});

	my $option_max = return_option('cool', 'max', $option{dau_cool_maximum_line});
	if (!defined($option_max) || int($option_max) < 0) {
		$option_max = INT_MAX;
	}

	my $option_prob_eol = return_option('cool', 'prob_eol', $option{dau_cool_probability_eol});
	if (!defined($option_prob_eol) || int($option_prob_eol) < 0 || int($option_prob_eol) > 100) {
		$option_prob_eol = 20;
	}

	my $option_prob_word = return_option('cool', 'prob_word', $option{dau_cool_probability_word});
	if (!defined($option_prob_word) || int($option_prob_word) < 0 || int($option_prob_word) > 100) {
		$option_prob_word = 20;
	}

	################################################################################
	# Insert the trademarks and dollar signs
	################################################################################

	my $max = $option_max;
	foreach my $line (split /(\n)/, $data) {
		foreach my $word (split /(\s)/, $line) {
			if ($max > 0 && (rand(100) <= $option_prob_word) && $word =~ /^(\w+)([[:punct:]])?$/) {
				$word = "${1}[tm]${2}";
				$max--;
			}
			if ($max > 0 && (rand(100) <= $option_prob_word) && $word =~ /^(\w+(?:\[tm\])?)([[:punct:]])?$/) {
				$word = "\$${1}${2}";
				$max--;
			}
			$output .= $word;
		}
		$max = $option_max;
	}

	################################################################################
	# Reversed smileys
	################################################################################

	my $hat = '[(<]';
	my $eyes = '[:;%]';
	my $nose = '[-]';
	my $mouth = '[)(><\[\]{}|]';

	$output =~ s{($hat?$eyes$nose?$mouth+)}{
	             # Supposed to be read from the right to the left.
	             # Therefore reverse all parenthesis characters:

	             my $tr = $1;
	             $tr =~ tr/()<>[]\{\}/)(><][\}\{/;

	             # Reverse the rest

	             reverse($tr);
	            }egox;

	################################################################################
	# EOL modifications
	################################################################################

	my $style = $option_eol_style;
	if ($option_eol_style eq 'random') {
		if (int(rand(2)) && $output !~ /[?!]$/) {
			$style = 'exclamation_marks';
		} else {
			$style = 'suffixes';
		}
	}

	# If there is no suffixes file, go for the exclamation marks

	my $file = "$option{dau_files_root_directory}/$option{dau_files_cool_suffixes}";
	unless (-e $file && -r $file && !(-z $file)) {
		$style = 'exclamation_marks';
	}

	# Skip EOL modifications?

	if (int(rand(100)) > $option_prob_eol) {
		$style = 'none';
	}

	# Style determined. Act accordingly:

	if ($style eq 'exclamation_marks') {
		my @eol;
		if ($option{dau_language} eq 'de') {
			@eol = ("eins", "shifteins", "elf", "hundertelf", "tausendeinhundertundelf");
			for (1 .. 5) {
				push(@eol, "eins");
				push(@eol, "elf");
			}
		} else {
			@eol = ("one", "shiftone", "eleven");
			for (1 .. 5) {
				push(@eol, "one");
				push(@eol, "eleven");
			}
		}

		$output =~ s/\s*([,.?!])*\s*$//;
		$output .= '!' x (3 + int(rand(3)));
		$output .= '1' x (3 + int(rand(3)));
		$output .= $eol[rand(@eol)] x (1 + int(rand(1)));
		$output .= $eol[rand(@eol)] x (int(rand(2)));
	} elsif ($style eq 'suffixes') {
		my $suffix;
		if (-e $file && -r $file) {
			$/ = "\n";
			@ARGV = ($file);
			srand;
			rand($.) < 1 && ($suffix = switch_parse_special($_, $channel)) while <>;
		}
		$output =~ s/\s*$//;

		if ($output =~ /^\s*$/) {
			$output = $suffix;
		} else {
			$output .= " " . $suffix;
		}
	}

	return $output;
}

sub switch_cowsay {
	my $data = shift;
	my ($binarypath, $output, @cows, %cow, $cow, @cache1, @cache2);
	my $skip = 1;
	my $think = return_option('cowsay', 'think');

	my $executable_name;
	if ($think eq 'on') {
		$binarypath = $option{dau_cowsay_cowthink_path};
		$executable_name = 'cowthink';
	} else {
		$binarypath = $option{dau_cowsay_cowsay_path};
		$executable_name = 'cowsay';
	}

	if (-e $binarypath && !(-f $binarypath)) {
		print_err("dau_cowsay_${executable_name}_path has to point to the $executable_name executable.");
		return;
	} elsif (!(-e $binarypath)) {
		print_err("$executable_name not found. Install it and set dau_cowsay_${executable_name}_path.");
		return;
	}

	if (return_option('cowsay', 'cow')) {
		$cow = return_option('cowsay', 'cow');
	} else {
		while ($option{dau_cowsay_cowlist} =~ /\s*([^,\s]+)\s*,?/g) {
			$cow{$1} = 1;
		}
		foreach my $cow (keys %{ $switches{combo}{cowsay}{cow} }) {
			if (lc($option{dau_cowsay_cowpolicy}) eq 'allow') {
				push(@cows, $cow)
					unless ($cow{$cow});
			} elsif (lc($option{dau_cowsay_cowpolicy}) eq 'deny') {
				push(@cows, $cow)
					if ($cow{$cow});
			} else {
				print_err('Invalid value for dau_cowsay_cowpolicy');
				return;
			}
		}
		if (@cows == 0) {
			print_err('Cannot find any cowsay cow.');
			return;
		}
		$cow = $cows[rand(@cows)];
	}

	# Run cowsay or cowthink

	local(*HIS_IN, *HIS_OUT, *HIS_ERR);
	my @arguments;
	my $option_arguments = return_option('cowsay', 'arguments');
	if ($option_arguments) {
		@arguments = split(/ /, $option_arguments);
	}
	my $childpid = open3(*HIS_IN, *HIS_OUT, *HIS_ERR, $binarypath, '-f', $cow, @arguments);

	print HIS_IN $data or return;
	close(HIS_IN) or return;

	my @errlines = <HIS_ERR>;
	my @outlines = <HIS_OUT>;
	close(HIS_ERR) or return;
	close(HIS_OUT) or return;

	waitpid($childpid, 0);
	if ($?) {
		print_err("That child exited with wait status of $?");
	}

	# Error during execution? Print errors and return

	unless (@errlines == 0) {
		print_err('Error during execution of cowsay');
		foreach my $line (@errlines) {
			print_err($line);
		}
		return;
	}

	if ($option{dau_cowsay_print_cow}) {
		print_out("Using cowsay cow $cow");
	}

	foreach (@outlines) {
		chomp;
		if (/^\s*$/ && $skip) {
			next;
		} else {
			$skip = 0;
		}
		push(@cache1, $_);
	}
	$skip = 1;
	foreach (reverse @cache1) {
		chomp;
		if (/^\s*$/ && $skip) {
			next;
		} else {
			$skip = 0;
		}
		push(@cache2, $_);
	}
	foreach (reverse @cache2) {
		$output .= "$_\n";
	}

	return $output;
}

sub switch_delimiter {
	my $data = shift;
	my $output;
	my $option_delimiter_string = return_option('delimiter', 'string', $option{dau_delimiter_string});

	foreach my $char (split //, $data) {
		$output .= $char . $option_delimiter_string;
	}
	return $output;
}

sub switch_dots {
	my $data = shift;

	$data =~ s/[.]*\s+/
	           if (rand(10) < 3) {
	               (rand(10) >= 5 ? ' ' : '')
	               .
	               ('...' . '.' x rand(5))
	               .
	               (rand(10) >= 5 ? ' ' : '')
	           } else { ' ' }
	          /egox;
	rand(10) >= 5 ? $data .= ' ' : 0;
	$data .= ('...' . '.' x rand(10));

	return $data;
}

sub switch_figlet {
	my $data = shift;
	my $skip = 1;
	my ($output, @fonts, %font, $font, @cache1, @cache2);

	if (-e $option{dau_figlet_path} && !(-f $option{dau_figlet_path})) {
		print_err('dau_figlet_path has to point to the figlet executable.');
		return;
	} elsif (!(-e $option{dau_figlet_path})) {
		print_err('figlet not found. Install it and set dau_figlet_path.');
		return;
	}

	if (return_option('figlet', 'font')) {
		$font = return_option('figlet', 'font');
	} else {
		while ($option{dau_figlet_fontlist} =~ /\s*([^,\s]+)\s*,?/g) {
			$font{$1} = 1;
		}
		foreach my $font (keys %{ $switches{combo}{figlet}{font} }) {
			if (lc($option{dau_figlet_fontpolicy}) eq 'allow') {
				push(@fonts, $font)
					unless ($font{$font});
			} elsif (lc($option{dau_figlet_fontpolicy}) eq 'deny') {
				push(@fonts, $font)
					if ($font{$font});
			} else {
				print_err('Invalid value for dau_figlet_fontpolicy.');
				return;
			}
		}
		if (@fonts == 0) {
			print_err('Cannot find figlet fonts.');
			return;
		}
		$font = $fonts[rand(@fonts)];
	}

	# Run figlet

	local(*HIS_IN, *HIS_OUT, *HIS_ERR);

	my $childpid = open3(*HIS_IN, *HIS_OUT, *HIS_ERR, $option{dau_figlet_path}, '-f', $font);

	print HIS_IN $data or return;
	close(HIS_IN) or return;

	my @errlines = <HIS_ERR>;
	my @outlines = <HIS_OUT>;
	close(HIS_ERR) or return;
	close(HIS_OUT) or return;

	waitpid($childpid, 0);
	if ($?) {
		print_err("That child exited with wait status of $?");
	}

	# Error during execution? Print errors and return

	unless (@errlines == 0) {
		print_err('Error during execution of figlet');
		foreach my $line (@errlines) {
			print_err($line);
		}
		return;
	}

	if ($option{dau_figlet_print_font}) {
		print_out("Using figlet font $font");
	}

	foreach (@outlines) {
		chomp;
		if (/^\s*$/ && $skip) {
			next;
		} else {
			$skip = 0;
		}
		push(@cache1, $_);
	}
	$skip = 1;
	foreach (reverse @cache1) {
		chomp;
		if (/^\s*$/ && $skip) {
			next;
		} else {
			$skip = 0;
		}
		push(@cache2, $_);
	}
	foreach (reverse @cache2) {
		$output .= "$_\n";
	}

	return $output;
}

sub switch_leet {
	my $data = shift;

	$_ = $data;

	s'fucker'f@#$er'gi;
	s/hacker/h4x0r/gi;
	s/sucker/sux0r/gi;
	s/fear/ph34r/gi;

	s/\b(\w+)ude\b/${1}00d/gi;
	s/\b(\w+)um\b/${1}00m/gi;
	s/\b(\w{3,})er\b/${1}0r/gi;
	s/\bdo\b/d00/gi;
	s/\bthe\b/d4/gi;
	s/\byou\b/j00/gi;

	tr/lLzZeEaAsSgGtTbBqQoOiIcC/11223344556677889900||((/;
	s/(\w)/rand(100) < 50 ? "\u$1" : "\l$1"/ge;

	return $_;
}

sub switch_me {
	my $data = shift;

	$command_out = 'ACTION';

	return $data;
}

# &switch_mix by Martin Kihlgren <zond@troja.ath.cx>
# slightly modified by myself

sub switch_mix {
	my $data = shift;
	my $output;

	while ($data =~ s/(\s*)([^\w]*)([\w]+)([^\w]*)(\s+[^\w]*\w+[^\w]*\s*)*/$5/) {
		my $prespace = $1;
		my $prechars = $2;
		my $w = $3;
		my $postchars = $4;
		$output = $output . $prespace . $prechars . substr($w,0,1);
		my $middle = substr($w,1,length($w) - 2);
		while ($middle =~ s/(.)(.*)/$2/) {
			if (rand() > 0.1) {
				$middle = $middle . $1;
			} else {
				$output = $output . $1;
			}
		}
		if (length($w) > 1) {
			$output = $output . substr($w, length($w) - 1, 1);
		}
		$output = $output . $postchars;
	}

	return $output;
}

sub switch_mixedcase {
	my $data = shift;

	$data =~ s/([[:alpha:]])/rand(100) < 50 ? uc($1) : lc($1)/ge;

	return $data;
}

sub switch_moron {
	my ($data, $channel_rec) = @_;
	my $output;
	my $option_eol_style = return_option('moron', 'eol_style', $option{dau_moron_eol_style});
	my $option_language  = $option{dau_language};

	################################################################################
	# -omega on
	################################################################################

	my $omega;

	if (return_option('moron', 'omega') eq 'on') {
		my @words = qw(omfg lol wtf);

		foreach (split / (?=\w+\b)/, $data) {
			if (rand(100) < 20) {
				$omega .= ' ' . $words[rand(@words)] . " $_";
			} else {
				$omega .= ' ' . $_;
			}
		}

		$omega =~ s/\s*,\s+\@/ @/g;
		$omega =~ s/^\s+//;
	}

	$_ = $omega || $data;

	################################################################################
	# 'nick: text' -> 'text @ nick'
	################################################################################

	my $old_list_delimiter = $option{dau_parse_special_list_delimiter};
	$option{dau_parse_special_list_delimiter} = ' ';
	my @nicks = split(/ /, switch_parse_special('@nicks', $channel_rec));
	$option{dau_parse_special_list_delimiter} = $old_list_delimiter;
	@nicks = map { quotemeta($_) } @nicks;

	{
		local $" = '|';
		eval { # Catch strange error
			s/^(@nicks): (.+)/$2 @ $1/;
		};
	}

	################################################################################
	# Preparations for "EOL modifications" later
	################################################################################

	# Remove puntuation marks at EOL and ensure there is a single space at EOL.
	# This is necessary because the EOL-styles 'new' and 'classic' put them at
	# EOL. If EOL-style is set to 'nothing' don't do this.

	s/\s*([,;.:?!])*\s*$// unless ($option_eol_style eq 'nothing');
	my $lastchar = $1;

	# Only whitespace? Remove it.

	s/^\s+$//;

	################################################################################
	# Substitutions for every language
	################################################################################

	tr/'/`/;

	# Dauify smileys

	{
		# Use of uninitialized value in concatenation (.) or string at...
		# (the optional dash ($1) in the regular expressions).
		# Thus turn off warnings

		no warnings;

		if ($option{dau_language} eq 'de') {
			if (int(rand(2))) {
				s/:(-)?\)/^^/go;
			} else {
				s/:(-)?\)/':' . $1 . ')))' . (')' x rand(10)) . ('9' x rand(4))/ego;
			}

			s/;(-)?\)/';' . $1 . ')))' . (')' x rand(10)) . ('9' x rand(4))/ego;
			s/:(-)?\(/':' . $1 . '(((' . ('(' x rand(10)) . ('8' x rand(4))/ego;
			s#(^|\s):(-)?/(\s|$)#$1 . ':' . $2 . '///' . ('/' x rand(10)) . ('7' x rand(4)) . $3#ego;
		} else {
			if (int(rand(2))) {
				s/:(-)?\)/^^/go;
			} else {
				s/:(-)?\)/':' . $1 . ')))' . (')' x rand(10)) . ('0' x rand(4))/ego;
			}

			s/;(-)?\)/';' . $1 . ')))' . (')' x rand(10)) . ('0' x rand(4))/ego;
			s/:(-)?\(/':' . $1 . '(((' . ('(' x rand(10)) . ('9' x rand(4))/ego;
		}
	}

	################################################################################
	# English text
	################################################################################

	if ($option_language eq 'en') {
		s/\bthe\b/teh/go;
	}

	################################################################################
	# German text
	################################################################################

	if ($option_language eq 'de') {

		# '*GG*' -> 'ÜGGÜ'
		{
			my @a = ('*', 'Ü');
			my $a = $a[int(rand(@a))];
			s/\*g\*/$a . 'ggg' . ('g' x rand(10)) . $a/egio;
		}

		# verbs

		s/\b(f)reuen\b/$1roien/gio;
		s/\b(f)reue\b/$1roie/gio;
		s/\b(f)reust\b/$1roist/gio;
		s/\b(f)reut\b/$1roit/gio;

		s/\b(f)unktionieren\b/$1unzen/gio;
		s/\b(f)unktioniere\b/$1unze/gio;
		s/\b(f)unktionierst\b/$1unzt/gio;
		s/\b(f)unktioniert\b/$1unzt/gio;

		s/\b(h)olen\b/$1ohlen/gio;
		s/\b(h)ole\b/$1ohle/gio;
		s/\b(h)olst\b/$1ohlst/gio;
		s/\b(h)olt\b/$1ohlt/gio;

		s/\b(k)onfigurieren\b/$1 eq 'k' ? 'confen' : 'Confen'/egio;
		s/\b(k)onfiguriere\b/$1 eq 'k' ? 'confe' : 'Confe'/egio;
		s/\b(k)onfigurierst\b/$1 eq 'k' ? 'confst' : 'Confst'/egio;
		s/\b(k)onfiguriert\b/$1 eq 'k' ? 'conft' : 'Conft'/egio;

		s/\b(l)achen\b/$1ölen/gio;
		s/\b(l)ache\b/$1öle/gio;
		s/\b(l)achst\b/$1ölst/gio;
		s/\b(l)acht\b/$1ölt/gio;

		s/\b(m)achen\b/$1 eq 'm' ? 'tun' : 'Tun'/egio;
		s/\b(m)ache\b/$1 eq 'm' ? 'tu' : 'Tu'/egio;
		s/\b(m)achst\b/$1 eq 'm' ? 'tust' : 'Tust'/egio;

		s/\b(n)erven\b/$1erfen/gio;
		s/\b(n)erve\b/$1erfe/gio;
		s/\b(n)ervst\b/$1erfst/gio;
		s/\b(n)ervt\b/$1erft/gio;

		s/\b(p)rojizieren\b/$1rojezieren/gio;
		s/\b(p)rojiziere\b/$1rojeziere/gio;
		s/\b(p)rojizierst\b/$1rojezierst/gio;
		s/\b(p)rojiziert\b/$1rojeziert/gio;

		s/\b(r)egistrieren\b/$1egestrieren/gio;
		s/\b(r)egistriere\b/$1egestriere/gio;
		s/\b(r)egistrierst\b/$1egestrierst/gio;
		s/\b(r)egistriert\b/$1egestriert/gio;

		s/\b(s)pazieren\b/$1patzieren/gio;
		s/\b(s)paziere\b/$1patziere/gio;
		s/\b(s)pazierst\b/$1patzierst/gio;
		s/\b(s)paziert\b/$1patziert/gio;

		# other

		s/\bdanke\b/
		  if (int(rand(2)) == 0) {
		      'thx'
		  } else {
		      'danks'
		  }
		 /ego;
		s/\bDanke\b/
		  if (int(rand(2)) == 0) {
		      'Thx'
		  } else {
		      'Danks'
		  }
		 /ego;

		s/\blol\b/
		  if (int(rand(2)) == 0) {
		      'löl'
		  } else {
		      'löllens'
		  }
		 /ego;
		s/\bLOL\b/
		  if (int(rand(2)) == 0) {
		      'LÖL'
		  } else {
		      'LÖLLENS'
		  }
		 /ego;

		s/\br(?:ü|ue)ckgrat\b/
		  if (int(rand(3)) == 0) {
		      'rückgrad'
		  } elsif (int(rand(3)) == 1) {
		      'rückrad'
		  } else {
		      'rückrat'
		  }
		 /ego;
		s/\bR(?:ü|ue)ckgrat\b/
		  if (int(rand(3)) == 0) {
		      'Rückgrad'
		  } elsif (int(rand(3)) == 1) {
		      'Rückrad'
		  } else {
		      'Rückrat'
		  }
		 /ego;

		s/\b(i)st er\b/$1ssa/gio;
		s/\bist\b/int(rand(2)) ? 'is' : 'iss'/ego;
		s/\bIst\b/int(rand(2)) ? 'Is' : 'Iss'/ego;

		s/\b(d)a(?:ss|ß) du\b/$1asu/gio;
		s/\b(d)a(?:ss|ß)\b/$1as/gio;

		s/\b(s)ag mal\b/$1amma/gio;
		s/\b(n)ochmal\b/$1omma/gio;
		s/(m)al\b/$1a/gio;

		s/\b(u)nd nun\b/$1nnu/gio;
		s/\b(n)un\b/$1u/gio;

		s/\b(s)oll denn\b/$1olln/gio;
		s/\b(d)enn\b/$1en/gio;

		s/\b(s)o eine\b/$1onne/gio;
		s/\b(e)ine\b/$1 eq 'e' ? 'ne' : 'Ne'/egio;

		s/\bkein problem\b/NP/gio;
		s/\b(p)roblem\b/$1rob/gio;
		s/\b(p)robleme\b/$1robs/gio;

		s/\b(a)ber\b/$1bba/gio;
		s/\b(a)chso\b/$1xo/gio;
		s/\b(a)dresse\b/$1ddresse/gio;
		s/\b(a)ggressiv\b/$1gressiv/gio;
		s/\b([[:alpha:]]{2,})st du\b/${1}su/gio;
		s/\b(a)nf(?:ä|ae)nger\b/$1 eq 'a' ? 'n00b' : 'N00b'/egio;
		s/\b(a)sozial\b/$1ssozial/gio;
		s/\b(a)u(?:ss|ß)er\b/$1user/gio;
		s/\b(a)utor/$1uthor/gio;
		s/\b(b)asta\b/$1 eq 'b' ? 'pasta' : 'Pasta'/egio;
		s/\b(b)illard\b/$1illiard/gio;
		s/\b(b)i(?:ss|ß)chen\b/$1ischen/gio;
		s/\b(b)ist\b/$1is/gio;
		s/\b(b)itte\b/$1 eq 'b' ? 'plz' : 'Plz'/egio;
		s/\b(b)lo(?:ss|ß)\b/$1los/gio;
		s/\b(b)(?:ox|(?:ü|ue)chse)\b/$1yxe/gio;
		s/\b(b)rillant\b/$1rilliant/gio;
		s/\b(c)hannel\b/$1 eq 'c' ? 'kanal' : 'Kanal'/egio;
		s/\b(c)hat\b/$1hatt/gio;
		s/\b(c)ool\b/$1 eq 'c' ? 'kewl' : 'Kewl'/egio;
		s/\b(d)(?:ä|ae)mlich\b/$1ähmlich/gio;
		s/\b(d)etailliert\b/$1etailiert/gio;
		s/\b(d)ilettantisch\b/$1illetantisch/gio;
		s/\b(d)irekt\b/$1ireckt/gio;
		s/\b(d)iskussion\b/$1isskusion/gio;
		s/\b(d)istribution/$1ystrubution/gio;
		s/\b(e)igentlich\b/$1igendlich/gio;
		s/\b(e)inzige\b/$1inzigste/gio;
		s/\b(e)nd/$1nt/gio;
		s/\b(e)ntschuldigung\b/$1 eq 'e' ? 'sry' : 'Sry'/egio;
		s/\b(f)ilm\b/$1 eq 'f' ? 'movie' : 'Movie'/egio;
		s/\b(f)lachbettscanner\b/$1lachbrettscanner/gio;
		s/\b(f)reu\b/$1roi/gio;
		s/\b(g)alerie\b/$1allerie/gio;
		s/\b(g)ay\b/$1hey/gio;
		s/\b(g)ebaren\b/$1ebahren/gio;
		s/\b(g)elatine\b/$1elantine/gio;
		s/\b(g)eratewohl\b/$1eradewohl/gio;
		s/\b(g)ibt es\b/$1ibbet/gio;
		s/\bgra([dt])/$1 eq 'd' ? 'grat' : 'grad'/ego;
		s/\bGra([dt])/$1 eq 'd' ? 'Grat' : 'Grad'/ego;
		s/\b(h)(?:ä|ae)ltst\b/$1älst/gio;
		s/\b(h)(?:ä|ae)sslich/$1äslich/gio;
		s/\b(h)aneb(?:ü|ue)chen\b/$1ahneb$2chen/gio;
		s/\b(i)mmobilie/$1mobilie/gio;
		s/\b(i)nteressant\b/$1nterressant/gio;
		s/\b(i)ntolerant\b/$1ntollerant/gio;
		s/\b(i)rgend/$1rgent/gio;
		s/\b(j)a\b/$1oh/gio;
		s/\b(j)etzt\b/$1ez/gio;
		s/\b(k)affee\b/$1affe/gio;
		s/\b(k)aputt\b/$1aput/gio;
		s/\b(k)arussell\b/$1arussel/gio;
		s/\b(k)iste\b/$1 eq 'k' ? 'byxe' : 'Byxe'/egio;
		s/\b(k)lempner\b/$1lemptner/gio;
		s/\b(k)r(?:ä|ae)nker\b/$1ranker/gio;
		s/\b(k)rise\b/$1riese/gio;
		s/\b(l)etal\b/$1ethal/gio;
		s/\b(l)eute\b/$1 eq 'l' ? 'ppl' : 'Ppl'/egio;
		s/\b(l)ibyen\b/$1ybien/gio;
		s/\b(l)izenz\b/$1izens/gio;
		s/\b(l)oser\b/$1ooser/gio;
		s/\b(l)ustig/$1ölig/gio;
		s/\b(m)aschine\b/$1aschiene/gio;
		s/\b(m)illennium\b/$1illenium/gio;
		s/\b(m)iserabel\b/$1ieserabel/gio;
		s/\b(m)it dem\b/$1im/gio;
		s/\b(m)orgendlich\b/$1orgentlich/gio;
		s/\b(n)(?:ä|ae)mlich\b/$1ähmlich/gio;
		s/\b(n)ein\b/$1eh/gio;
		s/\bnett\b/n1/gio;
		s/\b(n)ewbie\b/$100b/gio;
		s/\bnicht\b/int(rand(2)) ? 'net' : 'ned'/ego;
		s/\bNicht\b/int(rand(2)) ? 'Net' : 'Ned'/ego;
		s/\b(n)iveau/$1iwo/gio;
		s/\bok(?:ay)?\b/K/gio;
		s/\b(o)riginal\b/$1rginal/gio;
		s/\b(p)aket\b/$1acket/gio;
		s/\b(p)l(?:ö|oe)tzlich\b/$1lözlich/gio;
		s/\b(p)ogrom\b/$1rogrom/gio;
		s/\b(p)rogramm\b/$1roggie/gio;
		s/\b(p)rogramme\b/$1roggies/gio;
		s/\b(p)sychiater\b/$1sychater/gio;
		s/\b(p)ubert(?:ä|ae)t\b/$1upertät/gio;
		s/\b(q)uarz\b/$1uartz/gio;
		s/\b(q)uery\b/$1uerry/gio;
		s/\b(r)eferenz\b/$1efferenz/gio;
		s/\b(r)eparatur\b/$1eperatur/gio;
		s/\b(r)eply\b/$1eplay/gio;
		s/\b(r)essource\b/$1esource/gio;
		s/\b(r)(o)(t?fl)\b/$1 . ($2 eq 'o' ? 'ö' : 'Ö') . $3/egio;
		s/\b(r)(o)(t?fl)(o)(l)\b/$1 . ($2 eq 'o' ? 'ö' : 'Ö') . $3 . ($4 eq 'o' ? 'ö' : 'Ö') . $5/egio;
		s/\b(s)atellit\b/$1attelit/gio;
		s/\b(s)cherz\b/$1chertz/gio;
		s/\bsei([dt])\b/$1 eq 'd' ? 'seit' : 'seid'/ego;
		s/\bSei([dt])\b/$1 eq 'd' ? 'Seit' : 'Seid'/ego;
		s/\b(s)elig\b/$1eelig/gio;
		s/\b(s)eparat\b/$1eperat/gio;
		s/\b(s)eriosit(?:ä|ae)t\b/$1erösität/gio;
		s/\b(s)onst\b/$1onnst/gio;
		s/\b(s)orry\b/$1ry/gio;
		s/\b(s)pelunke\b/$1ilunke/gio;
		s/\b(s)piel\b/$1 eq 's' ? 'game' : 'Game'/egio;
		s/\b(s)tabil\b/$1tabiel/gio;
		s/\b(s)tandard\b/$1tandart/gio;
		s/\b(s)tegreif\b/$1tehgreif/gio;
		s/\b(s)ympathisch\b/$1ymphatisch/gio;
		s/\b(s)yntax\b/$1ynthax/gio;
		s/\b(t)era/$1erra/gio;
		s/\b(t)oler/$1oller/gio;
		s/\bto([td])/$1 eq 't' ? 'tod' : 'tot'/ego;
		s/\bTo([td])/$1 eq 't' ? 'Tod' : 'Tot'/ego;
		s/\b(u)ngef(?:ä|ae)hr\b/$1ngefär/gio;
		s/\bviel gl(?:ü|ue)ck\b/GL/gio;
		s/\b(v)ielleicht\b/$1ileicht/gio;
		s/\b(v)oraus/$1orraus/gio;
		s/\b(w)(?:ä|ae)re\b/$1ähre/gio;
		s/\bwa(h)?r/$1 eq 'h' ? 'war' : 'wahr'/ego;
		s/\bWa(h)?r/$1 eq 'h' ? 'War' : 'Wahr'/ego;
		s/\b(w)as du\b/$1asu/gio;
		s/\b(w)eil du\b/$1eilu/gio;
		s/\bweis(s)?/$1 eq 's' ? 'weis' : 'weiss'/ego;
		s/\bWeis(s)?/$1 eq 's' ? 'Weis' : 'Weiss'/ego;
		s/\b(w)enn du\b/$1ennu/gio;
		s/\b(w)ider/$1ieder/gio;
		s/\b(w)ieso\b/$1iso/gio;
		s/\b(z)iemlich\b/$1iehmlich/gio;
		s/\b(z)umindest\b/$1umindestens/gio;

		tr/üÜ/yY/;
		s/ei(?:ss?|ß)e?/ice/go;
		s/eife?/ive/go;

		if(return_option('moron', 'level') >= 1) {
			s/\b(u)nd\b/$1nt/gio;
			s/\b(h)at\b/$1att/gio;
			s/\b(n)ur\b/$1uhr/gio;
			s/\b(v)er(\w+)/$1 eq 'V' ? "Fa$2" : "fa$2"/egio;
			s/\b([[:alpha:]]+[b-np-tv-z])er\b/${1}a/go;
			s/\b([[:alpha:]]+)ck/${1}q/go;

			s/\b([fv])(?=[[:alpha:]]{2,})/
			  if (rand(10) <= 4) {
			      if ($1 eq 'f') {
			          'v'
			      }
			      else {
			          'f'
			      }
			  } else {
			      $1
			  }
			 /egox;
			s/\b([FV])(?=[[:alpha:]]{2,})/
			  if (rand(10) <= 4) {
			      if ($1 eq 'F') {
			          'V'
			      }
			      else {
			          'F'
			      }
			  } else {
			      $1
			  }
			  /egox;
			s#\b([[:alpha:]]{2,})([td])\b#
			  my $begin = $1;
			  my $end   = $2;
			  if (rand(10) <= 4) {
			      if ($end eq 't' && $begin !~ /t$/) {
			          "${begin}d"
			      } elsif ($end eq 'd' && $begin !~ /d$/) {
			          "${begin}t"
			      } else {
			          "${begin}${end}"
			      }
			  } else {
			      "${begin}${end}"
			  }
			 #egox;
			s/\b([[:alpha:]]{2,})ie/
			  if (rand(10) <= 4) {
			      "$1i"
			  } else {
			      "$1ie"
			  }
			 /egox;
		}
	}

	$data = $_;

	################################################################################
	# Swap characters with characters near at the keyboard
	################################################################################

	my %mark;
	my %chars;
	if ($option{dau_language} eq 'de') {
		%chars = (
		          'a' => [ 's' ],
		          'b' => [ 'v', 'n' ],
		          'c' => [ 'x', 'v' ],
		          'd' => [ 's', 'f' ],
		          'e' => [ 'w', 'r' ],
		          'f' => [ 'd', 'g' ],
		          'g' => [ 'f', 'h' ],
		          'h' => [ 'g', 'j' ],
		          'i' => [ 'u', 'o' ],
		          'j' => [ 'h', 'k' ],
		          'k' => [ 'j', 'l' ],
		          'l' => [ 'k', 'ö' ],
		          'm' => [ 'n' ],
		          'n' => [ 'b', 'm' ],
		          'o' => [ 'i', 'p' ],
		          'p' => [ 'o', 'ü' ],
		          'q' => [ 'w' ],
		          'r' => [ 'e', 't' ],
		          's' => [ 'a', 'd' ],
		          't' => [ 'r', 'z' ],
		          'u' => [ 'z', 'i' ],
		          'v' => [ 'c', 'b' ],
		          'w' => [ 'q', 'e' ],
		          'x' => [ 'y', 'c' ],
		          'y' => [ 'x' ],
		          'z' => [ 't', 'u' ],
		         );
	} else {
		%chars = (
		          'a' => [ 's' ],
		          'b' => [ 'v', 'n' ],
		          'c' => [ 'x', 'v' ],
		          'd' => [ 's', 'f' ],
		          'e' => [ 'w', 'r' ],
		          'f' => [ 'd', 'g' ],
		          'g' => [ 'f', 'h' ],
		          'h' => [ 'g', 'j' ],
		          'i' => [ 'u', 'o' ],
		          'j' => [ 'h', 'k' ],
		          'k' => [ 'j', 'l' ],
		          'l' => [ 'k', 'ö' ],
		          'm' => [ 'n' ],
		          'n' => [ 'b', 'm' ],
		          'o' => [ 'i', 'p' ],
		          'p' => [ 'o', 'ü' ],
		          'q' => [ 'w' ],
		          'r' => [ 'e', 't' ],
		          's' => [ 'a', 'd' ],
		          't' => [ 'r', 'z' ],
		          'u' => [ 'z', 'i' ],
		          'v' => [ 'c', 'b' ],
		          'w' => [ 'q', 'e' ],
		          'x' => [ 'y', 'c' ],
		          'y' => [ 't', 'u' ],
		          'z' => [ 'x' ],
		         );
	}

	# Do not replace one character twice
	# Therefore every replace-position will be marked

	unless (lc(return_option('moron', 'typo')) eq 'off') {
		for (0 .. length($data)) {
			$mark{$_} = 0;
		}

		for (0 .. rand(length($data))/20) {
			my $pos = int(rand(length($data)));
			pos $data = $pos;
			unless ($mark{$pos} == 1)  {
				no locale;
				if ($data =~ /\G([A-Za-z])/g) {
					my $matched = $1;
					my $replacement;
					if ($matched eq lc($matched)) {
						$replacement = $chars{$matched}[int(rand(@{ $chars{$matched} }))];
					} else {
						$replacement = uc($chars{$matched}[int(rand(@{ $chars{$matched} }))]);
					}
					if ($replacement !~ /^\s*$/) {
						substr($data, $pos, 1, $replacement);
						$mark{$pos} = 1;
					}
				}
			}
		}
	}

	################################################################################
	# Mix in some typos (swapping characters)
	################################################################################

	unless (lc(return_option('moron', 'typo')) eq 'off') {
		foreach my $word (split /([\s\n])/, $data) {
			if ((rand(100) <= 20) && length($word) > 1) {
				my $position_swap = int(rand(length($word)));
				if ($position_swap == 0) {
					$position_swap = 1;
				} elsif ($position_swap == length($word)) {
					$position_swap = length($word) - 1;
				}
				if (substr($word, $position_swap - 1, 1) eq uc(substr($word, $position_swap - 1, 1)) &&
				    substr($word, $position_swap, 1)     eq lc(substr($word, $position_swap, 1)))
				{
					(substr($word, $position_swap, 1), substr($word, $position_swap - 1, 1)) =
					(lc(substr($word, $position_swap - 1, 1)), uc(substr($word, $position_swap, 1)));
				} else {
					(substr($word, $position_swap, 1), substr($word, $position_swap - 1, 1)) =
					(substr($word, $position_swap - 1, 1), substr($word, $position_swap, 1));
				}
			}
			$output .= $word;
		}
	} else {
		$output = $_;
	}

	################################################################################
	# plenk
	################################################################################

	$output =~ s/(\w+)([,;.:?!]+)(\s+|$)/
	           if (rand(10) <= 8 || $3 eq '') {
	               "$1 $2$3"
	           } else {
	               "$1$2"
	           }
	          /egox;

	################################################################################
	# default behaviour: uppercase text
	################################################################################

	$output = uc($output) unless (return_option('moron', 'uppercase') eq 'off');

	################################################################################
	# do something at EOL
	################################################################################

	if ($option_eol_style ne 'nothing') {
		my $random = int(rand(100));

		$output .= ' ' unless ($output =~ /^\s*$/);

		# !!!!!!??????????!!!!!!!!!!11111

		if ($random <= 70 || $lastchar eq '!') {
			my @punct = qw(? !);
			$output .= $punct[rand(@punct)] x int(rand(5))
				for (1..15);

			if ($lastchar eq '?') {
				$output .= '?' x (int(rand(4))+1);
			} elsif ($lastchar eq '!') {
				$output .= '!' x (int(rand(4))+1);
			}

			if ($output =~ /\?$/) {
				if ($option{dau_language} eq 'de') {
					$output .= "ß" x int(rand(10));
				} else {
					$output .= "/" x int(rand(10));
				}
			} elsif ($output =~ /!$/) {
				$output .= "1" x int(rand(10));
			}
		}

		# ?¿?

		elsif ($random <= 85) {
			$output .= '?¿?';
		}

		# "=\n?"

		else {
			$output .= "=\n?";
		}
	}

	return $output;
}

sub switch_nothing {
	my $data = shift;

	return $data;
}

sub switch_parse_special {
	my ($text, $channel) = @_;

	local $" = return_option('parse_special', 'list_delimiter', $option{dau_parse_special_list_delimiter});

	# Build nick array with every nick in channel and
	# opnick array with every op in the channel

	my @nicks   = ();
	my @opnicks = ();
	if (defined($channel) && $channel && $channel->{type} eq 'CHANNEL') {
		foreach my $nick ($channel->nicks()) {
			next if ($channel->{server}->{nick} eq $nick->{nick});
			push(@nicks, $nick->{nick});
			push(@opnicks, $nick->{nick}) if ($nick->{op});
		}
	}
	@nicks   = sort { lc($a) cmp lc($b) } @nicks;
	@opnicks = sort { lc($a) cmp lc($b) } @opnicks;

	# Substitution: \n to a real newline

	$text =~ s/(?<![\\])\\n/\n/g;

	# Substitution: @nicks to all nicks of channel

	$text =~ s/(?<![\\])\@nicks/@nicks/gc;

	# Substitution: @opnicks to all nicks of channel

	$text =~ s/(?<![\\])\@opnicks/@opnicks/gc;

	# Substitution: $nick1..$nickn

	while ($text =~ /(?<![\\])\$nick(\d+)/g) {
		my $substitution = $nicks[rand(@nicks)];
		$text =~ s/(?<![\\])\$nick$1([^\d]|$)/${substitution}$1/g;
		@nicks = grep { $_ ne $substitution } @nicks;
		last if (@nicks == 0);
	}

	# Substitution: $opnick1..$opnickn

	while ($text =~ /(?<![\\])\$opnick(\d+)/g) {
		my $substitution = $opnicks[rand(@opnicks)];
		$text =~ s/(?<![\\])\$opnick$1([^\d]|$)/${substitution}$1/g;
		@opnicks = grep { $_ ne $substitution } @opnicks;
		last if (@opnicks == 0);
	}

	# Substitution: $?{ code }

	my $np; # (nested pattern)
	$np = qr{
		  {
	          (?:
	             (?> [^{}]+ ) # Non-capture group w/o backtracking
	           |
	             (??{ $np })  # Group with matching parens
	          )*
		  }
	        }x;

	while ($text =~ /(?<![\\])\$\?($np)/g) {
		{
			no strict;
			my $replacement = eval $1;
			if ($@) {
				print_err('Invalid code used in construct $?{ code }. Details:');
				print_err($@);
				return;
			} else {
				chomp($replacement);
				$text =~ s/(?<![\\])\$\?($np)/$replacement/;
			}
		}
	}

	# Substitution: irssi's special variables

	if ((defined($channel) && $channel &&
	    ($channel->{type} eq 'CHANNEL' || $channel->{type} eq 'QUERY')) &&
	    !(lc(return_option('parse_special', 'irssi_variables')) eq 'off'))
	{
		$text = $channel->parse_special($text);
	}

	return $text;
}

sub switch_reverse {
	my $data = shift;

	$data = reverse($data);

	return $data;
}

sub switch_stutter {
	my $data = shift;
	my $output;
	my @words = qw(eeeh oeeeh aeeeh);

	foreach (split / (?=\w+\b)/, $data) {
		if (rand(100) < 20) {
			$output .= ' ' . $words[rand(@words)] . ", $_";
		} else {
			$output .= ' ' . $_;
		}
	}

	$output =~ s/\s*,\s+\@/ @/g;

	for (1 .. rand(length($output)/5)) {
		pos $output = rand(length($output));
		$output =~ s/\G ([[:alpha:]]+)\b/ $1, $1/;
	}
	for (1 .. rand(length($output)/10)) {
		pos $output = rand(length($output));
		$output =~ s/\G([[:alpha:]])/$1 . ($1 x rand(3))/e;
	}

	$output =~ s/^\s+//;

	return $output;
}

sub switch_substitute {
	$_ = shift;

	my $file = "$option{dau_files_root_directory}/$option{dau_files_substitute}";

	if (-e $file && -r $file) {
		my $return = do $file;

		if ($@) {
			print_err("parsing $file failed: $@");
		}
		unless (defined($return)) {
			print_err("'do $file' failed");
		}
	}

	return $_;
}

sub switch_underline {
	my $data = shift;

	$data = "\037$data\037";

	return $data;
}

sub switch_uppercase {
	my $data = shift;

	$data = uc($data);

	return $data;
}

sub switch_words {
	my $data = shift;
	my $output;
	my @numbers;

	if ($option{dau_words_range} =~ /^([1-9])-([1-9])$/) {
		my $x = $1;
		my $y = $2;
		unless ($x <= $y) {
			print_err('Invalid value for setting dau_words_range.');
			return;
		}
		if ($x == $y) {
			push(@numbers, $x);
		} elsif ($x < $y) {
			for (my $i = $x; $i <= $y; $i++) {
				push(@numbers, $i);
			}
		}
	} else {
		print_err('Invalid value for dau_words_range.');
		return;
	}
	my $random = $numbers[rand(@numbers)];
	while ($data =~ /((?:.*?(?:\s+|$)){1,$random})/g) {
		$output .= "$1\n"
			unless (length($1) == 0);
		$random = $numbers[rand(@numbers)];
	}

	$output =~ s/\s*$//;

	return $output;
}

################################################################################
# Subroutines (signals)
################################################################################

sub signal_channel_destroyed {
	my ($channel) = @_;

	my $channel_name = $channel->{name};
	my $network_name = $channel->{server}->{tag};

	$daumode{channels_in}{$network_name}{$channel_name} = 0;
	$daumode{channels_out}{$network_name}{$channel_name} = 0;
	$daumode{channels_in_modes}{$network_name}{$channel_name} = '';
	$daumode{channels_out_modes}{$network_name}{$channel_name} = '';
}

sub signal_channel_joined {
	my ($channel) = @_;

	# Resume babbles

	if (defined($babble{timer_writing})) {
		if ($babble{channel}->{name} eq $channel->{name} &&
		    $babble{channel}->{server}->{tag} eq $channel->{server}->{tag})
		{
			$channel->print('%9dau.pl:%9 Continuing babble...');
			timer_babble_writing();
		}
	}

	# Automatically set daumode

	daumode_channels();
}

sub signal_command_msg {
	my ($args, $server, $witem) = @_;

	$args =~ /^(?:-\S+\s)?(?:\S*)\s(.*)/;
	my $data = $1;

	$command_in .= "$data\n";

	Irssi::signal_stop();
}

sub signal_complete_word {
	my ($list, $window, $word, $linestart, $want_space) = @_;

	# Parsing the commandline for dau.pl is relatively complicated.
	# TAB completion depends on commandline parsing in dau.pl.
	# Script autors looking for a simple example for irssi's
	# TAB completion are wrong here.

	my $server  = Irssi::active_server();
	my $channel = $window->{active};
	my @switches_combo   = map { $_ = "--$_" } keys %{ $switches{combo} };
	my @switches_nocombo = map { $_ = "--$_" } keys %{ $switches{nocombo} };
	my @nicks = ();

	# Only complete when the commandline starts with '${k}dau'.
	# If not, let irssi do the work

	return unless ($linestart =~ /^\Q${k}\Edau/i);

	# Remove everything syntactically correct thing of $linestart.
	# If there is anything else but whitespace at the end of
	# commandline parsing, we have an syntax error.
	# If we have a syntax error, complete only nicks.

	$linestart =~ s/^\Q${k}\Edau ?//i;

	# Generate list of nicks in current channel for later use

	if (defined($channel->{type}) && $channel->{type} eq 'CHANNEL') {
		foreach my $nick ($channel->nicks()) {
			if ($nick->{nick} =~ /^\Q$word\E/i &&
			    $window->{active_server}->{nick} ne $nick->{nick})
			{
				push(@nicks, $nick->{nick});
			}
		}
	}

	# Variables

	my $combo = 0;                # Boolean: True if last switch was one of keys %{ $switches{combo} }
	my $syntax_error = 0;         # Boolean: True if syntax error found
	my $counter = 0;              # Integer: Counts first level options
	my $first_level_option = '';  # String:  Last first level option
	my $second_level_option = ''; # String:  Last second level option
	my $third_level_option = 0;   # Boolean: True if found a third level option

	# Parsing commandline now. Set variables accordingly.

	OUTER: while ($linestart =~ /^--(\w+) ?/g) {

		$second_level_option = '';
		$third_level_option  = 0;

		# Found a first level option (combo)

		if (ref($switches{combo}{$1}{'sub'})) {
			$first_level_option = $1;
			$combo = 1;
		}

		# Found a first level option (nocombo)

		elsif (ref($switches{nocombo}{$1}{'sub'}) && $counter == 0) {
			$first_level_option = $1;
			$combo = 0;
		}

		# Not a first level option => Syntax error

		else {
			$syntax_error = 1;
			last OUTER;
		}

		# Syntactically correct => remove it

		$linestart =~ s/^--\w+ ?//;

		# Checkout if there are Second- or third level options

		INNER: while ($linestart =~ /^-(\w+)(?: ('.*?(?<![\\])'|\S+))? ?/g) {

			my $second_level = $1;
			my $third_level  = $2 || '';

			$third_level =~ s/^'//;
			$third_level =~ s/'$//;
			$third_level =~ s/\\'/'/g;

			# Do the same for combo and nocombo-options. They have to be
			# handled separately anyway.

			# combo...

			if ($combo) {

				# Found a second level option

				if ($switches{combo}{$first_level_option}{$second_level}) {
					$second_level_option = $second_level;
				}

				# Not a second level option => Syntax error

				else {
					$syntax_error = 1;
					last OUTER;
				}

				# Syntactically correct => remove it

				$linestart =~ s/^-\w+//;

				# Found something in the regexp of the INNER-while-loop-condition,
				# which is perhaps a third level option

				if ($third_level) {

					# Found a third level option

					if ($switches{combo}{$first_level_option}{$second_level_option}{$third_level} ||
                                            $switches{combo}{$first_level_option}{$second_level_option}{'*'})
					{
						$third_level_option = 1;

						# Syntactically correct => remove it

						$linestart =~ s/^(?: ('.*?(?<![\\])'|\S+))? ?//;
					}

					# Not a third level option => Syntax error

					else {
						$syntax_error = 1;
						last OUTER;
					}

				# Nothing found which comes into question for a third level option.
				# The commandline has to be empty now (remember: everything
				# syntactically correct has been removed) or we have a syntax error.

				} else {

					# Empty! Later we will complete to third level options

					if ($linestart =~ /^\s*$/) {
						$third_level_option = 0;
					}

					# Not empty => Syntax error

					else {
						$syntax_error = 1;
						last OUTER;
					}
				}

			# nocombo...

			} else {

				# Found a second level option

				if ($switches{nocombo}{$first_level_option}{$second_level}) {
					$second_level_option = $second_level;
				}

				# Not a second level option => Syntax error

				else {
					$syntax_error = 1;
					last OUTER;
				}

				# Syntactically correct => remove it

				$linestart =~ s/^-\w+//;

				# Found something in the regexp of the INNER while loop condition,
				# which is perhaps a third level option

				if ($third_level) {

					# Found a third level option

					if ($switches{nocombo}{$first_level_option}{$second_level_option}{$third_level} ||
                                            $switches{nocombo}{$first_level_option}{$second_level_option}{'*'})
					{
						$third_level_option = 1;

						# Syntactically correct => remove it

						$linestart =~ s/^(?: ('.*?(?<![\\])'|\S+))? ?//;
					}

					# Not a third level option => Syntax error

					else {
						$syntax_error = 1;
						last OUTER;
					}

				# Nothing found which comes into question for a third level option.
				# The commandline has to be empty now (remember: everything
				# syntactically correct has been removed) or we have a syntax error.

				} else {

					# Empty! Later we will complete to third level options

					if ($linestart =~ /^\s*$/) {
						$third_level_option = 0;
					}

					# Not empty => Syntax error

					else {
						$syntax_error = 1;
						last OUTER;
					}
				}
			}
		}
	} continue {
		$counter++;
	}

	# End of commandline-parsing.
	# Everything syntactically correct removed.
	# If commandline is not empty now, we have a syntax error.

	if ($linestart !~ /^\s*$/) {
		$syntax_error = 1;
	}

	# Do the TAB completion

	@$list = ();

	if ($syntax_error) {
		foreach my $x (sort @nicks) {
			if($x =~ /^$word/i) {
				push(@$list, $x);
			}
		}
	}
	elsif ($counter == 0) {
		foreach my $x ((sort(@switches_combo, @switches_nocombo), sort(@nicks))) {
			if($x =~ /^$word/i) {
				push(@$list, $x);
			}
		}
	}
	elsif (($combo && $first_level_option && $second_level_option && $third_level_option) ||
	       ($combo && $first_level_option && !$second_level_option && !$third_level_option))
	{
		my @switches_second_level = grep !/^-sub$/, map { $_ = "-$_" }
					    keys %{ $switches{combo}{$first_level_option} };

		foreach my $x ((sort(@switches_second_level), sort(@switches_combo), sort(@nicks))) {
			if($x =~ /^$word/i) {
				push(@$list, $x);
			}
		}
	}
	elsif ((!$combo && $counter == 1 && $first_level_option && $second_level_option && $third_level_option) ||
	       (!$combo && $counter == 1 && $first_level_option && !$second_level_option && !$third_level_option))
	{
		my @switches_second_level = grep !/^-sub$/, map { $_ = "-$_" }
					    keys %{ $switches{nocombo}{$first_level_option} };

		foreach my $x (sort(@switches_second_level)) {
			if($x =~ /^$word/i) {
				push(@$list, $x);
			}
		}
	}
	elsif ($combo && $first_level_option && $second_level_option && !$third_level_option) {
		my @switches_third_level = grep !/^\*$/,
					   keys %{ $switches{combo}{$first_level_option}{$second_level_option} };

		foreach my $x (sort(@switches_third_level)) {
			if($x =~ /^$word/i) {
				push(@$list, $x);
			}
		}
	}
	elsif (!$combo && $counter == 1 && $first_level_option && $second_level_option && !$third_level_option) {
		my @switches_third_level = grep !/^\*$/,
					   keys %{ $switches{nocombo}{$first_level_option}{$second_level_option} };

		foreach my $x ((sort(@switches_third_level), sort(@nicks))) {
			if($x =~ /^$word/i) {
				push(@$list, $x);
			}
		}
	}

	Irssi::signal_stop();
}

sub signal_event_404 {
	my ($server, $message, $network_name) = @_;

	if ($message =~ /^(?:\S+) (\S+) :Cannot send to channel$/) {
		my $channel_name = $1;

		if ($server->{tag} eq $babble{channel}->{server}->{tag} &&
		    $babble{channel}->{name} eq $channel_name &&
		    defined($babble{timer_writing}))
		{
			Irssi::timeout_remove($babble{timer_writing});
			undef($babble{timer_writing});
			print_out("%9dau.pl:%9 Could not send message to $babble{channel}->{name}/$babble{channel}->{server}->{tag}. Cancelling babble.");
			return;
		}
	}

	if ($message =~ /^(?:\S+) (\S+) :(.*)/) {
		Irssi::print("$1 $2");
	} else {
		Irssi::print($message);
	}
}

sub signal_event_privmsg {
	my ($server, $data, $nick, $hostmask) = @_;
	my ($channel_name, $text) = split / :/, $data, 2;
	my $channel_rec = $server->channel_find($channel_name);
	$channel_name   = lc($channel_name);
	my $server_name = lc($server->{tag});
	my %lookup;

	while ($option{dau_remote_channellist} =~ /\s*([^\/]+)\/([^,]+)\s*,?/g) {
		my $channel = $1;
		$channel    = lc($channel);
		my $ircnet  = $2;
		$ircnet     = lc($ircnet);
		$lookup{$ircnet}{$channel} = 1;
	}
	if (lc($option{dau_remote_channelpolicy}) eq 'allow') {
		return if ($lookup{$server_name}{$channel_name});
	} elsif (lc($option{dau_remote_channelpolicy}) eq 'deny') {
		return unless ($lookup{$server_name}{$channel_name});
	} else {
		return;
	}

	# Remove formatting so dau.pl can reply to a colored, underlined, ...
	# question

	$text =~ s/\003\d?\d?(?:,\d?\d?)?|\002|\006|\007|\016|\01f|\037//g;

	my $regexp = switch_parse_special($option{dau_remote_question_regexp}, $channel_rec);
	if ($text =~ /$regexp/) {
		my $reply = return_random_list_item($option{dau_remote_question_reply});
		$reply =~ s/(?<![\\])\$nick/$nick/g;
		$reply = parse_text($reply, $channel_rec);

		output_text($server, $channel_name, $reply);
	}
}

sub signal_nick_mode_changed {
	my ($channel, $nick, $setby, $mode, $type) = @_;
	my ($reply, %lookup);
	my $channel_name = lc($channel->{name});
	my $network_name  = lc($channel->{server}->{tag});
	my $op = $nick_mode{$network_name}{$channel_name}{op};       # mode before nick change
	my $voice = $nick_mode{$network_name}{$channel_name}{voice}; # mode before nick change

	return if ($channel->{server}->{nick} ne $nick->{nick});
	if ($nick->{nick} eq $setby || $setby eq 'irc.psychoid.net') {
		build_nick_mode_struct();
		return;
	}

	# Only act in channels where the user wants dau.pl to act

	while ($option{dau_remote_channellist} =~ /\s*([^\/]+)\/([^,]+)\s*,?/g) {
		my $channel = $1;
		$channel    = lc($channel);
		my $ircnet  = $2;
		$ircnet     = lc($ircnet);
		$lookup{$ircnet}{$channel} = 1;
	}
	if (lc($option{dau_remote_channelpolicy}) eq 'allow') {
		if ($lookup{$network_name}{$channel_name}) {
			build_nick_mode_struct();
			return;
		}
	} elsif (lc($option{dau_remote_channelpolicy}) eq 'deny') {
		unless ($lookup{$network_name}{$channel_name}) {
			build_nick_mode_struct();
			return;
		}
	} else {
		build_nick_mode_struct();
		return;
	}

	# Now we are in the right channel

	if ($option{dau_remote_permissions} =~ /^[01]1[01][01][01][01]$/) {
		if ($mode eq '+' && $type eq '+' && (!$voice && !$op)) {
			$reply = return_random_list_item($option{dau_remote_voice_reply});
			$reply =~ s/(?<![\\])\$nick/$setby/g;
			$reply = parse_text($reply, $channel);
		}
	}
	if ($option{dau_remote_permissions} =~ /^[01][01]1[01][01][01]$/) {
		if ($mode eq '@' && $type eq '+' && !$op) {
			$reply = return_random_list_item($option{dau_remote_op_reply});
			$reply =~ s/(?<![\\])\$nick/$setby/g;
			$reply = parse_text($reply, $channel);
		}
	}
	if ($option{dau_remote_permissions} =~ /^[01][01][01]1[01][01]$/) {
		if ($mode eq '+' && $type eq '-' && ($voice && !$op)) {
			$reply = return_random_list_item($option{dau_remote_devoice_reply});
			$reply =~ s/(?<![\\])\$nick/$setby/g;
			$reply = parse_text($reply, $channel);
		}
	}
	if ($option{dau_remote_permissions} =~ /^[01][01][01][01]1[01]$/) {
		if ($mode eq '@' && $type eq '-' && $op) {
			$reply = return_random_list_item($option{dau_remote_deop_reply});
			$reply =~ s/(?<![\\])\$nick/$setby/g;
			$reply = parse_text($reply, $channel);
		}
	}

	# rebuild nick mode struct and print out the reply

	build_nick_mode_struct();
	output_text($channel, $channel->{name}, $reply);
}

sub signal_send_text {
	my ($data, $server, $witem) = @_;
	my $output;

	return unless (defined($server) && $server && $server->{connected});
	return unless (defined($witem) && $witem &&
	              ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY'));

	if ($daumode{channels_out}{$server->{tag}}{$witem->{name}} == 1) {
		if ($daumode{channels_out_modes}{$server->{tag}}{$witem->{name}} eq '') {
			$output = parse_text($daumode{channels_out_modes}{$server->{tag}}{$witem->{name}} . $data, $witem);
		} else {
			$output = parse_text($daumode{channels_out_modes}{$server->{tag}}{$witem->{name}} . ' ' . $data, $witem);
		}

		output_text($witem, $witem->{name}, $output);

		Irssi::signal_stop();
	}
}

sub signal_setup_changed {
	set_settings();

	# setting changed/added => change/add it here

	# setting cmdchars

	$k = Irssi::parse_special('$k');

	# babble history

	if (defined($babble{history}) && ref($babble{history}) eq 'ARRAY') {
		my @history;
		my $i = 1;
		foreach (@{ $babble{history} } ) {
			if ($i++ <= $option{dau_babble_history_size}) {
				push(@history, $_);
			}
		}
		@{ $babble{history} } = @history;
	}

	# setting dau_cowsay_cowpath

	cowsay_cowlist($option{dau_cowsay_cowpath});

	# setting dau_figlet_fontpath

	figlet_fontlist($option{dau_figlet_fontpath});

	# setting dau_daumode_channels

	daumode_channels();

	# setting dau_statusbar_daumode_hide_when_off

	Irssi::statusbar_items_redraw('daumode');

	# timer for the babble feature

	timer_remote_babble_reset();

	# signal handling

	signal_handling();
}

sub signals_daumode_in {
	my ($server, $data, $nick, $hostmask, $target) = @_;
	my $channel_rec = $server->channel_find($target);
	my $i_channel = $daumode{channels_in}{$server->{tag}}{$target};
	my $i_modes   = $daumode{channels_in_modes}{$server->{tag}}{$target};
	my $modified_msg;

	return unless (defined($server) && $server && $server->{connected});

	# Not one of the channels where daumode for incoming messages is turned on.
	# In those channels print out the message as it is and leave the subroutine

	if (!$i_channel) {
		return;
	}

	# Evil Hack?
	# I had to dauify every incoming messages. Using &signal_continue was
	# not possible because --words f.e. generates output over multiple lines. So I
	# had to create multiple messages using &signal_emit. Those just created
	# messages shouldn't be dauified again when entering this subroutine. I
	# couldn't prevent irssi from entering this subroutine again after
	# dauifying the text so the messages had to be 'marked'. Marked
	# messages will not be dauified again. I think \x02 at the beginning of the
	# message is ok for that.

	if ($data =~ s/^\x02//) {
		Irssi::signal_continue($server, $data, $nick, $hostmask, $target);
	} else {
		if ($i_modes ne '') {
			$modified_msg = parse_text($i_modes . ' ' . $data, $channel_rec);
		} else {
			$modified_msg = parse_text($data, $channel_rec);
		}

		if ($modified_msg =~ /\n/) {
			for my $line (split /\n/, $modified_msg) {
				Irssi::signal_emit(Irssi::signal_get_emitted(), $server, "\x02$line", $nick, $hostmask, $target);
				Irssi::signal_stop();
			}
		} else {
			Irssi::signal_emit(Irssi::signal_get_emitted(), $server, "\x02$modified_msg", $nick, $hostmask, $target);
			Irssi::signal_stop();
		}
	}
}

################################################################################
# Subroutines (statusbar)
################################################################################

sub statusbar_daumode {
	my ($item, $get_size_only) = @_;
	my ($status_in, $status_out, $modes_in, $modes_out);
	my $server = Irssi::active_server();
	my $witem  = Irssi::active_win()->{active};
	my $theme  = Irssi::current_theme();
	my $format = $theme->format_expand('{sb_daumode}');

	if ($witem && ref($witem) &&
	    $server && ref($server) &&
	   ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY'))
	{
		if (defined($daumode{channels_in}{$server->{tag}}{$witem->{name}}) &&
		    $daumode{channels_in}{$server->{tag}}{$witem->{name}} == 1)
		{
			$status_in = 'ON';
		} else {
			$status_in = 'OFF';
		}

		if (defined($daumode{channels_out}{$server->{tag}}{$witem->{name}}) &&
		    $daumode{channels_out}{$server->{tag}}{$witem->{name}} == 1)
		{
			$status_out = 'ON';
		} else {
			$status_out = 'OFF';
		}

		# Hide statusbaritem if setting dau_statusbar_daumode_hide_when_off
		# is turned on and daumode is turned off

		if ($status_in eq 'OFF' && $status_out eq 'OFF' && $option{dau_statusbar_daumode_hide_when_off}) {
			$item->{min_size} = $item->{max_size} = 0;
			return;
		}

		if ($status_in eq 'ON') {
			$modes_in = $daumode{channels_in_modes}{$server->{tag}}{$witem->{name}} || $option{dau_standard_options};
		} else {
			$modes_in = '';
		}
		if ($status_out eq 'ON') {
			$modes_out = $daumode{channels_out_modes}{$server->{tag}}{$witem->{name}} || $option{dau_standard_options};
		} else {
			$modes_out = '';
		}

		if ($format) {
			$format = $theme->format_expand("{sb_daumode $status_out $modes_out $status_in $modes_in}");
		} else {
			if ($status_in eq 'OFF' && $status_out eq 'OFF') {
				$format = $theme->format_expand("{sb daumode: <- $status_in | -> $status_out}");
			}
			elsif ($status_in eq 'OFF' && $status_out eq 'ON') {
				$format = $theme->format_expand("{sb daumode: <- $status_in | -> $status_out ($modes_out)}");
			}
			elsif ($status_in eq 'ON' && $status_out eq 'OFF') {
				$format = $theme->format_expand("{sb daumode: <- $status_in ($modes_in) | -> $status_out}");
			}
			elsif ($status_in eq 'ON' && $status_out eq 'ON') {
				$format = $theme->format_expand("{sb daumode: <- $status_in ($modes_in) | -> $status_out ($modes_out)}");
			}
		}
	} else {
		$item->{min_size} = $item->{max_size} = 0;
		return;
	}

	$item->default_handler($get_size_only, $format, '', 1);
}

################################################################################
# Subroutines (timer)
################################################################################

# for the babble remote feature

sub timer_away_reminder {
	my $id = shift;
	$id =~ m{^([^/]+)/(.+)};
	my $channel = $1;
	my $network = $2;

	my $server_rec  = Irssi::server_find_tag($network);

	unless (defined($server_rec) && $server_rec) {
		return;
	}

	my $channel_rec = $server_rec->channel_find($channel);

	unless (defined($channel_rec) && $channel_rec &&
	       ($channel_rec->{type} eq 'CHANNEL' || $channel_rec->{type} eq 'QUERY'))
	{
		return;
	}

	################################################################################
	# Open file
	################################################################################

	my $file = "$option{dau_files_root_directory}/$option{dau_files_away}";
	my @file;
	unless (tie(@file, 'Tie::File', $file)) {
		print_err("Cannot tie $file!");
		return;
	}

	################################################################################
	# Go through file
	################################################################################

	# Format:
	# channel | network | time | options | reminder | interval | reason

	my ($time, $options, $reminder, $interval, $reason);
	foreach my $line (@file) {
		if ($line =~ m{^$channel\x02$network\x02(\d+)\x02([^\x02]*)\x02(\d)\x02(\d+)\x02(.*)}) {
			$time = $1;
			$options = $2;
			$reminder = $3;
			$interval = $4;
			$reason = $5;
			last;
		}
	}

	################################################################################
	# Special variables
	################################################################################

	my $output = $option{dau_away_reminder_text};

	# $time

	my $difference = time_diff_verbose(time, $time);
	$output =~ s/\$time/$difference/g;

	# $reason

	if ($option{dau_away_quote_reason}) {
		$reason =~ s/\\/\\\\/g;
		$reason =~ s/\$/\\\$/g;
	}
	$output =~ s/\$reason/$reason/g;

	################################################################################
	# Write text to channels. Write changes back to file
	################################################################################

	untie(@file);

	$output = parse_text("$options $output", $channel_rec);

	output_text($channel_rec, $channel_rec->{name}, $output);
}

# all babbles: the writing to the channel

sub timer_babble_writing {

	# check if we are still on the channel

	my $onChannel = 0;
	foreach my $server (Irssi::servers()) {
		if ($server->{tag} eq $babble{channel}->{server}->{tag}) {
			foreach my $channel ($server->channels()) {
				if ($babble{channel}->{name} eq $channel->{name})  {
					if ($babble{channel} != $channel) {
						$babble{channel} = $channel;
					}
					$onChannel = 1;
				}
			}
		}
	}
	if (!$onChannel) {
		Irssi::timeout_remove($babble{timer_writing});
		print_out("%9dau.pl:%9 You are not on $babble{channel}->{name}/$babble{channel}->{server}->{tag}. Stalling babble.");
		return;
	}

	# restore the variables

	$command_out           = $babble{command_out_history}{$babble{counter}};
	$command_out_activated = $babble{command_out_history_switch}{$babble{counter}};

	# then output text

	output_text($babble{channel}, $babble{channel}->{name}, $babble{line});

	# And go to the "managing" subroutine...

	timer_babble_writing_reset();
}

# all babbles: the timer for the next writing

sub timer_babble_writing_reset {
	my $interval = 0;

	# Remove used writing timer, if existent (at the first run we don't have any timer)

	Irssi::timeout_remove($babble{timer_writing}) if (defined($babble{timer_writing}));

	# At each run of this managing subroutine remove one line of text

	$babble{text} =~ s/^(.*?)\n//;
	$babble{line} = $1;

	if ($babble{line} =~ s/^BABBLE_INTERVAL=(\d+)\x02//) {
		$interval = $1;
		$babble{line} = parse_text("$option{dau_babble_options_line_by_line} $babble{line}");
		my $counter = $babble{counter} + 1;
		$babble{command_out_history}{$counter} = $command_out;
		$babble{command_out_history_switch}{$counter} = $command_out_activated;
	}

	# If there is still some text left, add a new timer for the next line

	if (length($babble{text}) != 0 || length($babble{line}) != 0) {

		if ($babble{counter}++ == 0) {
			if ($option{dau_babble_verbose} && $babble{numberoflines} >= $option{dau_babble_verbose_minimum_lines}) {
				$babble{channel}->print("%9dau.pl:%9 Babbling $babble{numberoflines} line" . ($babble{numberoflines} > 1 ? 's' : '') . ' now:');
			}
			$interval = 50;
		}

		if ($interval < 10) {
			# Calculate the writing breaks
			# The longer the next line is the longer the break will be

			$interval = 1000 + rand(2000) +
				       50 * length($babble{line}) +
				       rand(25 * length($babble{line}));

			# Some characters need more time to write

			while ($babble{line} =~ /[^a-z ]/gio) {
				$interval += (75 + rand(25));
			}

			$interval = int($interval);
		}

		# Set timer

		$babble{timer_writing} = Irssi::timeout_add($interval, \&timer_babble_writing, '');
	}

	# No text left?

	else {
		if ($option{dau_babble_verbose} && $babble{numberoflines} >= $option{dau_babble_verbose_minimum_lines}) {
			$babble{channel}->print('%9dau.pl:%9 Finished babbling.');
		}

		# remove the timer

		undef($babble{timer_writing});

		if ($babble{remote}) {
			timer_remote_babble_reset();
		}
	}
}

# remote babble: initialize

sub timer_remote_babble {
	my $text;

	# Push all channels where it's ok to babble text in @channels

	my %lookup;
	while ($option{dau_remote_babble_channellist} =~ /\s*([^\/]+)\/([^,]+)\s*,?/g) {
		my $channel = $1;
		$channel    = lc($channel);
		my $ircnet  = $2;
		$ircnet     = lc($ircnet);
		$lookup{$ircnet}{$channel} = 1;
	}

	my @channels;
	foreach my $server (Irssi::servers()) {
		my $server_name = lc($server->{tag});

		foreach my $channel ($server->channels()) {
			my $channel_name = lc($channel->{name});

			if (lc($option{dau_remote_babble_channelpolicy}) eq 'allow' &&
			    !$lookup{$server_name}{$channel_name})
			{
				push(@channels, $channel);
			}
			elsif (lc($option{dau_remote_babble_channelpolicy}) eq 'deny' &&
			       $lookup{$server_name}{$channel_name})
			{
				push(@channels, $channel);
			}
		}
	}

	# No channels found => return

	return if (@channels == 0);

	# Choose one of the @channels

	my $channel = $channels[rand(@channels)];

	# If something is babbling right now, stop

	if (defined($babble{timer_writing})) {
		return;
	}

	# else get text from file

	else {
		my @filter = ();
		$text = &babble_get_text($channel, \@filter, undef, $option{dau_babble_history_size});
	}

	# Stop the timer for the big breaks.

	Irssi::timeout_remove($babble{timer_remote}) if (defined($babble{timer_remote}));

	# Start the writing.

	babble_start($channel, $text, 1);
}

# remote babble: reset

sub timer_remote_babble_reset {
	Irssi::timeout_remove($babble{timer_remote}) if (defined($babble{timer_remote}));

	# Do not set the timer, if the permission-bit is not set

	return unless ($option{dau_remote_permissions} =~ /^[01][01][01][01][01]1$/);

	# Calculate interval

	my $interval = babble_set_interval($option{dau_remote_babble_interval}, $option{dau_remote_babble_interval_accuracy});

	# Set timer

	if ($interval != 0) {
		$babble{timer_remote} = Irssi::timeout_add($interval, \&timer_remote_babble, '');
	}
}

################################################################################
# Helper subroutines
################################################################################

sub babble_get_text {
	my ($channel, $filter, $nicks, $history_size) = @_;
	my $output;

	# Return a random line from the dau_files_babble_messages file

	my ($text, @file, @filterindex);
	my $file = "$option{dau_files_root_directory}/$option{dau_files_babble_messages}";

	if (-e $file && -r $file) {
		unless (tie(@file, 'Tie::File', $file)) {
			print_err("Cannot tie $file!");
			return;
		}
	} else {
		print_err("Couldn't access babble file '$file'!");
		return;
	}

	my @nicks_channel   = ();
	my @opnicks_channel = ();
	if (defined($channel) && $channel && $channel->{type} eq 'CHANNEL') {
		foreach my $nick ($channel->nicks()) {
			next if ($channel->{server}->{nick} eq $nick->{nick});
			push(@nicks_channel, $nick->{nick});
			push(@opnicks_channel, $nick->{nick}) if ($nick->{op});
		}
	}

	my @compiled_patterns_filter;
	eval { # possible user input here
		@compiled_patterns_filter = map { qr/$_/i } @$filter;
	};
	if ($@) {
		print_err("The %9-filter%9 you gave wasn't a valid regular expression.");
		print_err($@);
		return;
	}
	my $compiled_pattern_nicks = qr/(?<![\\])\$nick(\d+)/;
	my $compiled_pattern_ops   = qr/(?<![\\])\$opnick(\d+)/;

	my $i = 0;
	foreach my $line (@file) {
		my $add = 1;

		# Every filter has to match

		FILTER: foreach my $filter (@compiled_patterns_filter) {
			if ($line !~ /$filter/) {
				$add = 0;
				last FILTER;
			}
		}

		# Check against history

		if ($add) {
			my $i = 1;
			foreach (@{ $babble{history} }) {
				if ($i++ <= $history_size) {
					if ($line eq $_) {
						$add = 0;
					}
				}
			}
		}

		# Don't babble at non-existent nicks

		if ($add) {
			my $minimum_number_nicks = 0;
			while ($line =~ /$compiled_pattern_nicks/g) {
				if ($1 > $minimum_number_nicks) {
					$minimum_number_nicks = $1;
				}
			}
			if (defined($nicks) && @$nicks > 0) {
				if (scalar(@$nicks) < $minimum_number_nicks) {
					$add = 0;
				}
			} else {
				if (scalar(@nicks_channel) < $minimum_number_nicks) {
					$add = 0;
				}
			}
		}

		# Don't babble at non-existent channel operators

		if ($add) {
			if ($line =~ /$compiled_pattern_ops/) {
				my $minimum_number_ops = 0;
				while ($line =~ /$compiled_pattern_ops/g) {
					if ($1 > $minimum_number_ops) {
						$minimum_number_ops = $1;
					}
				}
				if (defined($nicks) && @$nicks > 0) {
					if (scalar(@$nicks) < $minimum_number_ops) {
						$add = 0;
					}
				} else {
					if (scalar(@opnicks_channel) < $minimum_number_ops) {
						$add = 0;
					}
				}
			}
		}

		# Add the line as it passed all the tests

		if ($add) {
			push(@filterindex, $i);
		}
		$i++;
	}
	$text = $file[$filterindex[int(rand(@filterindex))]];

	if (@filterindex == 0) {
		print_err("Babble failed. Possible reasons: a) Too restrictive %9-filter%9 in place b) No matching lines in the babble file c) babble history holding that babble d) Not enough people in the channel");
		return;
	}

	if (!$text) {
		print_err("No text to babble.");
		return;
	}

	# Put babble in global history and shorten it, if necessary

	@{ $babble{history} } = ($text, @{ $babble{history} });
	if (scalar(@{ $babble{history} }) > $option{dau_babble_history_size}) {
		pop(@{ $babble{history} });
	}

	# dauify $text and return the dauified $output

	my $options = $option{dau_babble_options_line_by_line};

	# We have to keep track of the command history. --me and the --command
	# switch change the variables $command_out and $command_out_activated.
	# Because they are reset after every run of parse_text() they have to be kept
	# in a struct so that the writing timers later can do their job correctly.

	my $counter = 1;
	$babble{command_out_history} = ();
	$babble{command_out_history_switch} = ();

	# parse for special characters and substitute them

	if (defined($nicks)) {
		if (@$nicks > 0) {
			for (my $i = 1; $i <= @$nicks; $i++) {
				$text =~ s/(?<![\\])\$nick$i/@$nicks[$i - 1]/g;
			}
		}
		$text = switch_parse_special($text, $channel);
	} else {
		$text = switch_parse_special($text, $channel);
	}

	# Preprocessing options

	if ($option{dau_babble_options_preprocessing} !~ /^\s*$/) {
		$text = parse_text("$option{dau_babble_options_preprocessing} \x02$text");
		$text =~ s/^\x02//;
	}

	# Process $text line by line

	$text =~ s/\\n/\n/g;
	$text =~ s/\n$//;
	while ($text =~ /(.*?)(\n|$)/g) {
		my $line = $1;

		# Exit while loop when finished

		last if ($2 ne "\n" && $1 eq "");

		# Dauify text

		my $newtext = parse_text("$options $line") . "\n";

		$output .= $newtext;

		# The parsed text ($newtext) can contain more than one line.
		# All $newtext lines have the same command.
		# The command (MSG, ACTION, ...) has to be remembered.

		while ($newtext =~ /\n/g) {
			$babble{command_out_history}{$counter} = $command_out;
			$babble{command_out_history_switch}{$counter} = $command_out_activated;
			$counter++;
		}
	}

	# Lines are separated by newline characters. Maybe there are to many of
	# them at the end of the string (probably produced by --figlet, --cowsay, ...).
	# That's disturbing the number of lines calculation later.

	$output =~ s/\n{2,}$/\n/;

	# $output contains now the text to be babbled.  It will be split by
	# newlines by the babble subroutines and each line will be babbled with
	# the correct commands restored.

	return $output;
}

sub babble_interval {
	return "BABBLE_INTERVAL=" . babble_set_interval(@_) . "\x02";
}

sub babble_set_interval {
	my ($time, $accuracy) = @_;

	my $interval = time_parse($time);

	my $addend;
	if ($accuracy == 100) {
		$addend = 0;
	} elsif ($accuracy > 0 && $accuracy < 100) {
		$addend = rand($interval - ($interval * ($accuracy / 100)));
	} else {
		print_err('Invalid accuracy value');
		return;
	}

	if (int(rand(2))) {
		$interval = $interval + $addend;
	} else {
		$interval = $interval - $addend;
	}

	$interval = int($interval);

	if ($interval < 10 || $interval > 1000000000) {
		print_err('Invalid interval value');
		return 0;
	}

	return $interval;
}

sub babble_start {
	my ($channel_rec, $text, $remote) = @_;

	# These are some global variables for the writing timer

	$babble{channel}        = $channel_rec;
	$babble{counter}        = 0;
	$babble{text}           = "$text\n";
	$babble{numberoflines}  = 0;
	$babble{numberoflines}++ while ($babble{text} =~ /\n/g);
	$babble{numberoflines} -= 1;
	$babble{remote}         = $remote;

	Irssi::timeout_remove($babble{timer_writing}) if (defined($babble{timer_writing}));

	timer_babble_writing_reset();
}

sub build_nick_mode_struct {
	undef(%nick_mode);

	foreach my $server (Irssi::servers()) {
		my $network_name = lc($server->{tag});

		foreach my $channel ($server->channels()) {
			my $channel_name = lc($channel->{name});
			my $op = $channel->{ownnick}{op};
			my $voice = $channel->{ownnick}{voice};

			$nick_mode{$network_name}{$channel_name}{op} = $op;
			$nick_mode{$network_name}{$channel_name}{voice} = $voice;
		}
	}
}

sub daumode_channels {
	my @items;
	my $item;
	while ($option{dau_daumode_channels} =~ /([^,]+)/g) {
		my $match = $1;
		if ($match =~ s/\\$//) {
			$item .= "$match,";
		} else {
			$item .= $match;
			$item =~ s/^\s*//;
			$item =~ s/\s*$//;
			push @items, $item unless ($item =~ /^\s*$/);
			$item = "";
		}
	}

	foreach my $server (Irssi::servers()) {
		my $network_name = $server->{tag};
		foreach my $channel ($server->channels()) {
			my $channel_name = $channel->{name};
			foreach my $daumode (@items) {
				$daumode =~ m#^([^/]+)/([^:]+):(.*)#;
				my $item_channel  = $1;
				my $item_network  = $2;
				my $item_switches = $3;

				if (lc($item_channel) eq lc($channel_name) &&
				    lc($item_network) eq lc($network_name))
				{
					unless ($daumode{channels_in}{$network_name}{$channel_name} ||
					        $daumode{channels_out}{$network_name}{$channel_name})
					{
						$channel->print("%9dau.pl%9: Activating daumode according to setting dau_daumode_channels");
					}
					$channel->command("dau --daumode $item_switches");
				}
			}
		}
	}
}

sub def_dau_cowsay_cowpath {
	my $cowsay = $ENV{COWPATH} || '/usr/share/cowsay/cows';
	chomp($cowsay);
	return $cowsay;
}

sub def_dau_cowsay_cowsay_path {
	my $cowsay = `which cowsay`;
	chomp($cowsay);
	return $cowsay;
}

sub def_dau_cowsay_cowthink_path {
	my $cowthink = `which cowthink`;
	chomp($cowthink);
	return $cowthink;
}

sub def_dau_figlet_fontpath {
	my $figlet = `figlet -I2`;
	chomp($figlet);
	return $figlet;
}

sub def_dau_figlet_path {
	my $figlet = `which figlet`;
	chomp($figlet);
	return $figlet;
}

sub cowsay_cowlist {
	my $cowsay_cowpath = shift;

	# clear cowlist

	%{ $switches{combo}{cowsay}{cow} } = ();

	# generate new list

	while (<$cowsay_cowpath/*.cow>) {
		my $cow = (fileparse($_, qr/\.[^.]*/))[0];
		$switches{combo}{cowsay}{cow}{$cow} = 1;
	}
}

sub figlet_fontlist {
	my $figlet_fontpath = shift;

	# clear fontlist

	%{ $switches{combo}{figlet}{font} } = ();

	# generate new list

	while (<$figlet_fontpath/*.flf>) {
		my $font = (fileparse($_, qr/\..*/))[0];
		$switches{combo}{figlet}{font}{$font} = 1;
	}
}

sub fix {
	my $string = shift;
	$string =~ s/^\t+//gm;
	return $string;
}

sub output_text {
	my ($thing, $target, $text) = @_;

	foreach my $line (split /\n/, $text) {

		# prevent "-!- Irssi: Not enough parameters given"
		$line = ' ' if ($line eq '');

		# --command -out <command>?

		if ($command_out_activated) {
			if (defined($thing) && $thing) {
				$thing->command("$command_out $line");
			} else {
				my $server = Irssi::active_server();

				if (defined($server) && $server && $server->{connected}) {
					$server->command("$command_out $line");
				} else {
					print CLIENTCRAP $line;
				}
			}
		}

		# Not a channel/query window, --help, --changelog, ...

		elsif ($print_message) {
			print CLIENTCRAP $line;
		}

		# MSG or ACTION to channel or query

		elsif ($command_out eq 'ACTION' || $command_out eq 'MSG') {
			$thing->command("$command_out $target $line");
		}

		# weird things happened...

		else {
			print CLIENTCRAP $line;
		}
	}
}

sub parse_text {
	my ($data, $channel_rec) = @_;
	my $output;

	$command_out_activated = 0;
	$command_out           = 'MSG';
	$counter_switches      = 0;
	$daumode_activated     = 0;
	$print_message         = 0;
	%queue                 = ();

	OUTER: while ($data =~ /^--(\w+) ?/g) {

		my $first_level_option  = $1;

		# If its the first time we are in the OUTER loop, check
		# if the first level option is one of the few options,
		# which must not be combined.

		if (ref($switches{nocombo}{$first_level_option}{'sub'}) && $counter_switches == 0) {

			$data =~ s/^--\w+ ?//;

			# found a first level option

			$queue{$counter_switches}{$first_level_option} = { };

			# Check for second level options and third level options.
			# Get all of them and put theme in the
			# $queue hash

			while ($data =~ /^-(\w+) ('.*?(?<![\\])'|\S+) ?/g) {

				my $second_level_option = $1;
				my $third_level_option  = $2;

				$third_level_option =~ s/^'//;
				$third_level_option =~ s/'$//;
				$third_level_option =~ s/\\'/'/g;

				# If $switches{nocombo}{$first_level_option}{$second_level_option}{'*'}:
				# The user can give any third_level_option on the commandline

				my $any_option =
				$switches{nocombo}{$first_level_option}{$second_level_option}{'*'} ? 1 : 0;

				if ($switches{nocombo}{$first_level_option}{$second_level_option}{$third_level_option} ||
				    $any_option)
				{
					$queue{$counter_switches}{$first_level_option}{$second_level_option} = $third_level_option;
				}

				$data =~ s/^-(\w+) ('.*?(?<![\\])'|\S+) ?//;
			}

			# initialize some values

			foreach my $second_level_option (keys(%{ $switches{nocombo}{$first_level_option} })) {
				if (!defined($queue{'0'}{$first_level_option}{$second_level_option})) {
					$queue{'0'}{$first_level_option}{$second_level_option} = '';
				}
			}

			# All done. Run the subroutine

			$output = &{ $switches{nocombo}{$first_level_option}{'sub'} }($data, $channel_rec);

			return $output;
		}

		# Check for all those options that can be combined.

		elsif (ref($switches{combo}{$first_level_option}{'sub'})) {

			$data =~ s/^--\w+ ?//;

			# found a first level option

			$queue{$counter_switches}{$first_level_option} = { };

			# Check for second level options and
			# third level options. Get all of them and put them
			# in the $queue hash

			while ($data =~ /^-(\w+) ('.*?(?<![\\])'|\S+) ?/g) {

				my $second_level_option = $1;
				my $third_level_option  = $2;

				$third_level_option =~ s/^'//;
				$third_level_option =~ s/'$//;
				$third_level_option =~ s/\\'/'/g;

				# If $switches{combo}{$first_level_option}{$second_level_option}{'*'}:
				# The user can give any third_level_option on the commandline

				my $any_option =
				$switches{combo}{$first_level_option}{$second_level_option}{'*'} ? 1 : 0;

				# known option => Put it in the hash

				if ($switches{combo}{$first_level_option}{$second_level_option}{$third_level_option}
			            || $any_option)
				{
					$queue{$counter_switches}{$first_level_option}{$second_level_option} = $third_level_option;
					$data =~ s/^-(\w+) ('.*?(?<![\\])'|\S+) ?//;
				} else {
					last OUTER;
				}
			}

			# increase counter

			$counter_switches++;
		}

		else {
			last OUTER;
		}
	}

	# initialize some values

	for (my $i = 0; $i < $counter_switches; $i++) {
		foreach my $first_level (keys(%{ $queue{$i} })) {
			if (ref($switches{combo}{$first_level})) {
				foreach my $second_level (keys(%{ $switches{combo}{$first_level} })) {
					if (!defined($queue{$i}{$first_level}{$second_level})) {
						$queue{$i}{$first_level}{$second_level} = '';
					}
				}
			}
		}
	}

	# text to subroutines

	$output = $data;

	# If theres no text left over, take one item of dau_random_messages

	if ($output eq '') {
		$output = return_random_list_item($option{dau_standard_messages});
	}

	# No options? Get options from setting dau_standard_options and run
	# parse_text() again

	if (keys(%queue) == 0) {

		if (!$counter_subroutines) {
			print_out("No options given, hence using the value of the setting %9dau_standard_options%9 and that is %9$option{dau_standard_options}%9", $channel_rec);
			$counter_subroutines++;
			$output = parse_text("$option{dau_standard_options} $output", $channel_rec);
		} else {
			print_err('Invalid value for setting dau_standard_options. ' .
			          'Will use %9--moron%9 instead!');
			$output =~ s/^\Q$option{dau_standard_options}\E //;
			$output = parse_text("--moron $output", $channel_rec);
		}

	} else {

		$counter_switches = 0;

		for (keys(%queue)) {
			my ($first_level_option) = keys %{ $queue{$counter_switches} };
			$output = &{ $switches{combo}{$first_level_option}{'sub'} }($output, $channel_rec);
			$counter_switches++;
		}
	}

	# reset subcounter

	$counter_subroutines = 0;

	# return text

	return $output;
}

sub print_err {
	my $text = shift;

	foreach my $line (split /\n/, $text) {
		print CLIENTCRAP "%Rdau.pl error%n: $line";
	}
}

sub print_out {
	my ($text, $channel_rec) = @_;

	if ($option{dau_silence}) {
		return;
	}

	foreach my $line (split /\n/, $text) {
		my $message = "%9dau.pl%9: $line";
		if (defined($channel_rec) && $channel_rec) {
			$channel_rec->print($message);
		} else {
			print CLIENTCRAP $message;
		}
	}
}

# return_option('firstlevel', 'secondlevel'):
#
# If "--firstlevel -secondlevel value" given on the commandline, return 'value'.
#
# return_option('firstlevel', 'secondlevel', 'default value'):
#
# If "--firstlevel -secondlevel value" not given on the commandline, return
# 'default value'.
sub return_option {
	if (@_ == 2) {
		return $queue{$counter_switches}{$_[0]}{$_[1]};
	} elsif (@_ == 3) {
		if (length($queue{$counter_switches}{$_[0]}{$_[1]}) > 0) {
			return $queue{$counter_switches}{$_[0]}{$_[1]};
		} else {
			return $_[2];
		}
	} else {
		return 0;
	}
}

sub return_random_list_item {
	my $arg = shift;
	my @strings;

	my $item;
	while ($arg =~ /([^,]+)/g) {
		my $match = $1;
		if ($match =~ s/\\$//) {
			$item .= "$match,";
		} else {
			$item .= $match;
			$item =~ s/^\s*//;
			$item =~ s/\s*$//;
			push @strings, $item;
			$item = "";
		}
	}

	if (@strings == 0) {
		return;
	} else {
		return $strings[rand(@strings)];
	}
}

sub set_settings {
	# setting changed/added => change/add it here

	# boolean
	$option{dau_away_quote_reason}               = Irssi::settings_get_bool('dau_away_quote_reason');
	$option{dau_away_reminder}                   = Irssi::settings_get_bool('dau_away_reminder');
	$option{dau_babble_verbose}                  = Irssi::settings_get_bool('dau_babble_verbose');
	$option{dau_color_choose_colors_randomly}    = Irssi::settings_get_bool('dau_color_choose_colors_randomly');
	$option{dau_cowsay_print_cow}                = Irssi::settings_get_bool('dau_cowsay_print_cow');
	$option{dau_figlet_print_font}               = Irssi::settings_get_bool('dau_figlet_print_font');
	$option{dau_silence}                         = Irssi::settings_get_bool('dau_silence');
	$option{dau_statusbar_daumode_hide_when_off} = Irssi::settings_get_bool('dau_statusbar_daumode_hide_when_off');
	$option{dau_tab_completion}                  = Irssi::settings_get_bool('dau_tab_completion');

	# Integer
	$option{dau_babble_history_size}             = Irssi::settings_get_int('dau_babble_history_size');
	$option{dau_babble_verbose_minimum_lines}    = Irssi::settings_get_int('dau_babble_verbose_minimum_lines');
	$option{dau_cool_maximum_line}               = Irssi::settings_get_int('dau_cool_maximum_line');
	$option{dau_cool_probability_eol}            = Irssi::settings_get_int('dau_cool_probability_eol');
	$option{dau_cool_probability_word}           = Irssi::settings_get_int('dau_cool_probability_word');
	$option{dau_remote_babble_interval_accuracy} = Irssi::settings_get_int('dau_remote_babble_interval_accuracy');

	# String
	$option{dau_away_away_text}                  = Irssi::settings_get_str('dau_away_away_text');
	$option{dau_away_back_text}                  = Irssi::settings_get_str('dau_away_back_text');
	$option{dau_away_options}                    = Irssi::settings_get_str('dau_away_options');
	$option{dau_away_reminder_interval}          = Irssi::settings_get_str('dau_away_reminder_interval');
	$option{dau_away_reminder_text}              = Irssi::settings_get_str('dau_away_reminder_text');
	$option{dau_babble_options_line_by_line}     = Irssi::settings_get_str('dau_babble_options_line_by_line');
	$option{dau_babble_options_preprocessing}    = Irssi::settings_get_str('dau_babble_options_preprocessing');
	$option{dau_color_codes}                     = Irssi::settings_get_str('dau_color_codes');
	$option{dau_cool_eol_style}                  = Irssi::settings_get_str('dau_cool_eol_style');
	$option{dau_cowsay_cowlist}                  = Irssi::settings_get_str('dau_cowsay_cowlist');
	$option{dau_cowsay_cowpath}                  = Irssi::settings_get_str('dau_cowsay_cowpath');
	$option{dau_cowsay_cowpolicy}                = Irssi::settings_get_str('dau_cowsay_cowpolicy');
	$option{dau_cowsay_cowsay_path}              = Irssi::settings_get_str('dau_cowsay_cowsay_path');
	$option{dau_cowsay_cowthink_path}            = Irssi::settings_get_str('dau_cowsay_cowthink_path');
	$option{dau_daumode_channels}                = Irssi::settings_get_str('dau_daumode_channels');
	$option{dau_delimiter_string}                = Irssi::settings_get_str('dau_delimiter_string');
	$option{dau_figlet_fontlist}                 = Irssi::settings_get_str('dau_figlet_fontlist');
	$option{dau_figlet_fontpath}                 = Irssi::settings_get_str('dau_figlet_fontpath');
	$option{dau_figlet_fontpolicy}               = Irssi::settings_get_str('dau_figlet_fontpolicy');
	$option{dau_figlet_path}                     = Irssi::settings_get_str('dau_figlet_path');
	$option{dau_files_away}                      = Irssi::settings_get_str('dau_files_away');
	$option{dau_files_babble_messages}           = Irssi::settings_get_str('dau_files_babble_messages');
	$option{dau_files_cool_suffixes}             = Irssi::settings_get_str('dau_files_cool_suffixes');
	$option{dau_files_root_directory}            = Irssi::settings_get_str('dau_files_root_directory');
	$option{dau_files_substitute}                = Irssi::settings_get_str('dau_files_substitute');
	$option{dau_language}                        = Irssi::settings_get_str('dau_language');
	$option{dau_moron_eol_style}                 = Irssi::settings_get_str('dau_moron_eol_style');
	$option{dau_parse_special_list_delimiter}    = Irssi::settings_get_str('dau_parse_special_list_delimiter');
	$option{dau_random_options}                  = Irssi::settings_get_str('dau_random_options');
	$option{dau_remote_babble_channellist}       = Irssi::settings_get_str('dau_remote_babble_channellist');
	$option{dau_remote_babble_channelpolicy}     = Irssi::settings_get_str('dau_remote_babble_channelpolicy');
	$option{dau_remote_babble_interval}          = Irssi::settings_get_str('dau_remote_babble_interval');
	$option{dau_remote_channellist}              = Irssi::settings_get_str('dau_remote_channellist');
	$option{dau_remote_channelpolicy}            = Irssi::settings_get_str('dau_remote_channelpolicy');
	$option{dau_remote_deop_reply}               = Irssi::settings_get_str('dau_remote_deop_reply');
	$option{dau_remote_devoice_reply}            = Irssi::settings_get_str('dau_remote_devoice_reply');
	$option{dau_remote_op_reply}                 = Irssi::settings_get_str('dau_remote_op_reply');
	$option{dau_remote_permissions}              = Irssi::settings_get_str('dau_remote_permissions');
	$option{dau_remote_question_regexp}          = Irssi::settings_get_str('dau_remote_question_regexp');
	$option{dau_remote_question_reply}           = Irssi::settings_get_str('dau_remote_question_reply');
	$option{dau_remote_voice_reply}              = Irssi::settings_get_str('dau_remote_voice_reply');
	$option{dau_standard_messages}               = Irssi::settings_get_str('dau_standard_messages');
	$option{dau_standard_options}                = Irssi::settings_get_str('dau_standard_options');
	$option{dau_words_range}                     = Irssi::settings_get_str('dau_words_range');
}

sub signal_handling {
	# complete word

	if ($option{dau_tab_completion}) {
		if ($signal{'complete word'} != 1) {
			Irssi::signal_add_last('complete word', 'signal_complete_word');
		}
		$signal{'complete word'} = 1;
	} else {
		if ($signal{'complete word'} != 0) {
			Irssi::signal_remove('complete word', 'signal_complete_word');
		}
		$signal{'complete word'} = 0;
	}

	# event privmsg

	if ($option{dau_remote_permissions} =~ /^1[01][01][01][01][01]$/) {
		if ($signal{'event privmsg'} != 1) {
			Irssi::signal_add_last('event privmsg', 'signal_event_privmsg');
		}
		$signal{'event privmsg'} = 1;
	} else {
		if ($signal{'event privmsg'} != 0) {
			Irssi::signal_remove('event privmsg', 'signal_event_privmsg');
		}
		$signal{'event privmsg'} = 0;
	}

	# nick mode changed

	if ($option{dau_remote_permissions} =~ /^[01]1[01][01][01][01]$/ ||
	    $option{dau_remote_permissions} =~ /^[01][01]1[01][01][01]$/ ||
	    $option{dau_remote_permissions} =~ /^[01][01][01]1[01][01]$/ ||
	    $option{dau_remote_permissions} =~ /^[01][01][01][01]1[01]$/)
	{
		if ($signal{'nick mode changed'} != 1) {
			Irssi::signal_add_last('channel joined', 'build_nick_mode_struct');
			Irssi::signal_add_last('nick mode changed', 'signal_nick_mode_changed');
		}
		$signal{'nick mode changed'} = 1;
	} else {
		if ($signal{'nick mode changed'} != 0) {
			Irssi::signal_remove('channel joined', 'build_nick_mode_struct');
			Irssi::signal_remove('nick mode changed', 'signal_nick_mode_changed');
		}
		$signal{'nick mode changed'} = 0;
	}

	# daumode: outgoing messages

	my $daumode_out = 0;

	foreach my $server (keys %{ $daumode{channels_out} }) {
		foreach my $channel (keys %{ $daumode{channels_out}{$server} }) {
			if ($daumode{channels_out}{$server}{$channel} == 1) {
				$daumode_out = 1;
			}
		}
	}

	if ($daumode_out) {
		if ($signal{'send text'} != 1) {
			Irssi::signal_add_first('send text', 'signal_send_text');
		}
		$signal{'send text'} = 1;
	} else {
		if ($signal{'send text'} != 0) {
			Irssi::signal_remove('send text', 'signal_send_text');
		}
		$signal{'send text'} = 0;
	}

	# daumode: incoming messages

	my $daumode_in = 0;

	foreach my $server (keys %{ $daumode{channels_in} }) {
		foreach my $channel (keys %{ $daumode{channels_in}{$server} }) {
			if ($daumode{channels_in}{$server}{$channel} == 1) {
				$daumode_in = 1;
			}
		}
	}

	if ($daumode_in) {
		if ($signal{'daumode in'} != 1) {
			Irssi::signal_add_last('message public', 'signals_daumode_in');
			Irssi::signal_add_last('message irc action', 'signals_daumode_in');
		}
		$signal{'daumode in'} = 1;
	} else {
		if ($signal{'daumode in'} != 0) {
			Irssi::signal_remove('message public', 'signals_daumode_in');
			Irssi::signal_remove('message irc action', 'signals_daumode_in');
		}
		$signal{'daumode in'} = 0;
	}

	# continuing babbles, setting daumode

	if ($signal{'channel joined'} != 1) {
		Irssi::signal_add_last('channel joined', 'signal_channel_joined');
		Irssi::signal_add_last('channel destroyed', 'signal_channel_destroyed');
		$signal{'channel joined'} = 1;
	}

	# Cancel babble when message could not be sent to channel

	if ($signal{'event 404'} != 1) {
		Irssi::signal_add_last('event 404', 'signal_event_404');
		$signal{'event 404'} = 1;
	}
}

sub time_diff_verbose {
	my ($sub1, $sub2) = @_;

	my $difference = $sub1 - $sub2;
	$difference *= (-1) if ($difference < 0);
	my $seconds = $difference % 60;
	$difference = ($difference - $seconds) / 60;
	my $minutes = $difference % 60;
	$difference = ($difference - $minutes) / 60;
	my $hours   = $difference % 24;
	$difference = ($difference - $hours) / 24;
	my $days    = $difference % 7;
	my $weeks   = ($difference - $days) / 7;

	my $time;
	$time  = "$weeks week"     . ($weeks   == 1 ? "" : "s") . ", " if ($weeks);
	$time .= "$days day"       . ($days    == 1 ? "" : "s") . ", " if ($weeks || $days);
	$time .= "$hours hour"     . ($hours   == 1 ? "" : "s") . ", " if ($weeks || $days || $hours);
	$time .= "$minutes minute" . ($minutes == 1 ? "" : "s") . ", " if ($weeks || $days || $hours || $minutes);
	$time .= "$seconds second" . ($seconds == 1 ? "" : "s")        if ($weeks || $days || $hours || $minutes || $seconds);

	return $time;
}

sub time_parse {
	my $time = $_[0];
	my $parsed_time = 0;

	# milliseconds
	while ($time =~ s/(\d+)\s*(?:milliseconds|ms)//g) {
		$parsed_time += $1;
	}
	# seconds
	while ($time =~ s/(\d+)\s*s(?:econds?)?//g) {
		$parsed_time += $1 * 1000;
	}
	# minutes
	while ($time =~ s/(\d+)\s*m(?:inutes?)?//g) {
		$parsed_time += $1 * 1000 * 60;
	}
	# hours
	while ($time =~ s/(\d+)\s*h(?:ours?)?//g) {
		$parsed_time += $1 * 1000 * 60 * 60;
	}
	# days
	while ($time =~ s/(\d+)\s*d(?:ays?)?//g) {
		$parsed_time += $1 * 1000 * 60 * 60 * 24;
	}
	# weeks
	while ($time =~ s/(\d+)\s*w(?:eeks?)?//g) {
		$parsed_time += $1 * 1000 * 60 * 60 * 24 * 7;
	}

	if ($time !~ /^\s*$/) {
		print_err('Error while parsing the date!');
		return 0;
	}

	return $parsed_time;
}

################################################################################
# Debugging
################################################################################

sub debug_message {
        open(DEBUG, ">> $ENV{HOME}/.dau/.debug");

        print DEBUG $_[0];

        close (DEBUG);
}

#BEGIN {
#	use warnings;
#
#	open(STDERR, ">> $ENV{HOME}/.dau/.STDERR");
#}
