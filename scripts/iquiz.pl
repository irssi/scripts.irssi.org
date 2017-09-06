##################################################################
##    irssi Quiz (iQuiz) script (2010-2017) by wilk/xorandor    ##
##################################################################
## Script inspired by classic mIRC scripts: "Dizzy" by Dizzy,   ##
##   "Mieszacz" & "Familiada" by snajperx (both with my later   ##
##   upgrades).                                                 ##
## Other credits:                                               ##
##   Bjoern 'fuchs' Krombholz for splitlong.pl calculations     ##
##################################################################

# Tested more or less with irssi 0.8.15 & 0.8.18 and Perl 5.8.8, 5.10.1, 5.14.2, 5.16.3 & 5.18.2

# Script works with:
#
# - standard "Dizzy" files (also without "pyt"/"odp" prefixes) - used also for "Pomieszany":
#
# pyt Evaluate: 2+2=?
# odp four
# pyt Star closest to Earth?
# odp Sun
# ...
#
# - standard "Mieszacz" files (also without line numbers):
#
# 1 alpha
# 2 beta
# 3 gamma
# 4 delta
# ...
#
# - standard "Familiada" files (can have any number of answers per question, not only 10) - used also for "Multi":
#
# Planets of our Solar System:
# Mercury*Venus*Earth*Mars*Jupiter*Saturn*Uranus*Neptune
# First six alkanes:
# methane*ethane*propane*butane*pentane*hexane
# ...

# >>> To review all available commands and settings type: /quiz OR /help quiz

use strict;
use warnings;
use Irssi qw(theme_register current_theme command_bind settings_add_int settings_add_bool settings_add_str settings_get_int settings_get_bool settings_get_str settings_set_int settings_set_bool settings_set_str printformat timeout_add_once timeout_remove signal_add_last signal_remove signal_stop signal_emit);
use Time::HiRes qw(time);

our $VERSION = '170819';
our %IRSSI = (
	authors			=> 'wilk',
	name			=> 'iQuiz',
	description		=> 'irssi quiz script',
	license			=> 'GNU GPL v3 or any later version',
	changed			=> ($VERSION =~ /^(\d\d)(\d\d)(\d\d)/) ? "20$1-$2-$3" : $VERSION,
	url				=> 'http://iquiz.quizpl.net',
	contact			=> 'http://mail.quizpl.net',
	changes			=> 'see http://www.quizpl.net/viewtopic.php?f=3&t=404',
	usage			=> 'see http://www.quizpl.net/viewtopic.php?f=3&t=587'
);

##### Hardcoded settings #####
my $_start_delay = 5000;			# msec; delay between /qon and showing first question (or 0) - to let players concentrate and be ready
my $_bonus_delay = 1000;			# msec; time interval to account second fast answer
my $_max_teams = 5;					# int; max allowed teams (5 is reasonable)
my $_shuffle_watchdog = 10;			# int; max shuffling repetitions to prevent mixed == original, but avoid infinite loop
my $_shuffle_threshold = 3;			# int; below this length reshuffling is off (to prevent mixed == original)
my $_randomized_antigoogler = 0;	# bool; use better, randomized antigoogler? (will increase question length)
my $_smarter_antigoogler = 1;		# bool; use smarter antigoogler? (leaves some empty spaces for better line breaking)
my $_smarter_antigoogler_chunk = 2;	# int; leaves empty space every after this many substitutions (for use with $_smarter_antigoogler)
my $_protect_urls = 1;				# bool; turn off antigoogler if URL is detected in question?
my $_round_warn_time = 15;			# sec; seconds before round end to show warning (0 = off)
my $_round_warn_coeff = 1.5;		# float; round duration must be longer than coeff * $_round_warn_time to show warning (protection)
my $_qstats_ranks = 0;				# bool; 0: /qstats param corresponds to number of players, 1: /qstats param corresponds to rank
my $_qstats_records = 5;			# int; number of time/speed record places in /qstats (0 - off)
my $_no_hints_spam = 1;				# bool; do not show fully revealed answer as a hint (except the first)?
my $_flex_separator = '/';			# char; separator used in quiz_flx_* formats
my $_team_separator = ', ';			# str; team players separator eq. "nick1, nick2, nick3"

my $_display_delay = 100;			# msec; workaround for display issue (response before request)
my $_next_delay = 10;				# sec; default delay between questions
my $_next_delay_long = 20;			# sec; default delay between questions (fam/mul) (longer delay to prevent flooding and give a breath)
my $_round_duration = 90;			# sec; default round duration
my $_hints_interval = 10;			# sec; default hints interval
my $_hint_alpha = '.';				# char; default substitution symbol for alphabet characters in hints (special characters are left intact)
my $_hint_digit = '.';				# char; default substitution symbol for digit characters in hints (special characters are left intact)
my $_quiz_types = 5;				# (do not change)

##### Internal stuff #####
use constant { QT_STD => 1, QT_MIX => 2, QT_FAM => 3, QT_MUL => 4, QT_SCR => 5 }; # QT_MIL => 6, QT_FOR => 7
use constant { TIME_HMS => 0, TIME_S => 1, TIME_MS => 2 }; # 0: h/m/s, 1: s only, 2: s.ms
use constant { INSTANT => 1, BONUS => 2, WHISPER => 4, PREPDOTS => 1, INT => 1, BOOL => 2, STR => 3 };

my %quiz = (
	chan => undef, file => '',
	type => 0, tcnt => 0,	# we make copies in case someone modifies settings while quiz is running
	ison => 0,				# /qon ... /qoff (or error while /qreload)
	inq => 0,				# in question
	bonus => 0,				# in bonus interval
	standby => 0,			# /qon QT_FAM ... /qon (/qoff or error in /qreload)
	ended => 0,				# after last question till /qoff
	wantpause => 0,			# pause request (/qpause during question)
	paused => 0,			# paused by /qpause
	stime => 0, qtime => 0,
	qcnt => 0, qnum => 0, hnum => 0,
	score => 0, answers => 0,
	lastone => '',			# nick!ident@host of last answering player
	tnext => undef, tround => undef, thint => undef, thinter => undef, tremind => undef, twarn => undef, tbonus => undef,
	hprot => 0, rprot => 0,
	data => [],				# data[]{question realquestion answer answers{}}
	teams => [],			# teams[]{score answers}
	players => {},			# players{}{nick timestamp score answers team joined besttime alltime bestspeed allspeed}
	lookup => {},
	dcnt => 0,				# total number of currently unrevealed letters
	dmax => 0,				# number of currently unrevealed letters in the "most hidden" word
	dots => [], hwords => [],
	ignored => {},
	lang => 'pl'			# cached setting
);

my %settings_int = (
	'quiz_type' => QT_STD,
	'quiz_teams' => 2,
	'quiz_delay' => $_next_delay,
	'quiz_delay_long' => $_next_delay_long,
	'quiz_timeout' => $_round_duration,
	'quiz_hints_interval' => $_hints_interval,
	'quiz_max_hints' => 0,
	'quiz_words_case' => 0,
	'quiz_anticheat_delay' => 3,
	'quiz_first_anticheat_delay' => 7,
	'quiz_points_per_answer' => 1,
	'quiz_points_per_bonus' => 1,
	'quiz_min_points' => 1,
	'quiz_max_points' => 50,
	'quiz_scoring_mode' => 4,
	'quiz_ranking_type' => 3,
);

my %settings_bool = (
	'quiz_antigoogler' => 1,
	'quiz_autohinter' => 0,
	'quiz_split_long_lines' => 1,
	'quiz_show_first_hint' => 0,
	'quiz_first_hint_dots' => 0,
	'quiz_random_hints' => 1,
	'quiz_nonrandom_first_hint' => 1,
	'quiz_words_mode' => 1,
	'quiz_smart_mix' => 1,
	'quiz_mix_on_remind' => 1,
	'quiz_strict_match' => 1,
	'quiz_join_anytime' => 1,
	'quiz_team_play' => 1,
	'quiz_transfer_points' => 0,
	'quiz_limiter' => 0,
	'quiz_bonus_answer' => 0,
	'quiz_asciize' => 1,
	'quiz_keep_scores' => 0,
	'quiz_keep_teams' => 1,
	'quiz_cmd_hint' => 1,
	'quiz_cmd_remind' => 1,
);

my %settings_str = (
	'quiz_hint_alpha' => $_hint_alpha,
	'quiz_hint_digit' => $_hint_digit,
	'quiz_smart_mix_chars' => '\d()",.;:?!',
	'quiz_lang' => $quiz{lang},
);

##### Theme (only channel messages are localized by default, feel free to customize here or via /format, except authorship) #####
# quiz_inf_*, quiz_wrn_* & quiz_err_* messages are irssi only	- use irssi formatting and irssi color codes
# quiz_msg_* messages are sent on channel						- use sprintf formatting and mIRC color codes:
# \002 - bold  \003$fg(,$bg)? - color  \017 - plain  \026 - reverse  \037 - underline
# quiz_sfx_* - appended to after some quiz_msg_*
# quiz_inc_* - not sent directly, used as inclusions
# quiz_flx_* - not sent directly, words' inflections
# Important: To prevent visual glitches use two digit color codes, i.e. \00304 instead of \0034
# Comment: In few places I've put two bold codes between color code and comma. Unfortunately some flawed parsers consider this as a background color (even without a valid number value after!) and display a mess.
my $theme = [
	'quiz_inf_start',			'%_iQuiz:%_ Aby uzyskac pomoc wpisz: %_/quiz%_%:%_iQuiz:%_ For english language please type: /set quiz_lang en',
	'quiz_inf_start-en',		'%_iQuiz:%_ Type %_/quiz%_ to get help%:%_iQuiz:%_ Aby zmienic jezyk na polski wpisz: /set quiz_lang pl',
	'quiz_inf_delay',			'%_iQuiz:%_ %gZmieniono opoznienie miedzy pytaniami na: %_$0%_ sek.%n',
	'quiz_inf_delay-en',		'%_iQuiz:%_ %gChanged delay between questions to: %_$0%_s%n',
	'quiz_inf_duration',		'%_iQuiz:%_ %gZmieniono czas trwania rundy na: %_$0%_ sek.%n',
	'quiz_inf_duration-en',		'%_iQuiz:%_ %gChanged round duration to: %_$0%_s%n',
	'quiz_inf_type',			'%_iQuiz:%_ %gZmieniono tryb gry na: %_$0%_%n',
	'quiz_inf_type-en',			'%_iQuiz:%_ %gChanged quiz type to: %_$0%_%n',
	'quiz_inf_teams',			'%_iQuiz:%_ %gZmieniono liczbe druzyn na: %_$0%_%n',
	'quiz_inf_teams-en',		'%_iQuiz:%_ %gChanged number of teams to: %_$0%_%n',
	'quiz_inf_reset',			'%_iQuiz:%_ %gWszystkie ustawienia zostaly przywrocone do poczatkowych wartosci%n',
	'quiz_inf_reset-en',		'%_iQuiz:%_ %gAll settings has been reset to default values%n',
	'quiz_inf_reload',			'%_iQuiz:%_ %gPlik z pytaniami zostal ponownie wczytany%n',
	'quiz_inf_reload-en',		'%_iQuiz:%_ %gQuestions\' file reloaded%n',
	'quiz_inf_wantpause',		'%_iQuiz:%_ %gQuiz zostanie wstrzymany po tym pytaniu%n',
	'quiz_inf_wantpause-en',	'%_iQuiz:%_ %gQuiz will be paused after current question%n',
	'quiz_inf_wontpause',		'%_iQuiz:%_ %gWstrzymanie quizu zostalo anulowane%n',
	'quiz_inf_wontpause-en',	'%_iQuiz:%_ %gQuiz suspension revoked%n',
	'quiz_wrn_reload',			'%_iQuiz:%_ %YZmienila sie liczba pytan (po ponownym wczytaniu)%n',
	'quiz_wrn_reload-en',		'%_iQuiz:%_ %YQuestions\' count mismatch after reloading%n',
	'quiz_err_ison',			'%_iQuiz:%_ %RQuiz jest juz uruchomiony%n',
	'quiz_err_ison-en',			'%_iQuiz:%_ %RQuiz is already on%n',
	'quiz_err_isoff',			'%_iQuiz:%_ %RQuiz nie jest jeszcze uruchomiony%n',
	'quiz_err_isoff-en',		'%_iQuiz:%_ %RQuiz is not started yet%n',
	'quiz_err_server',			'%_iQuiz:%_ %RBrak polaczenia z serwerem%n',
	'quiz_err_server-en',		'%_iQuiz:%_ %RNot connected to server%n',
	'quiz_err_channel',			'%_iQuiz:%_ %RBledna nazwa kanalu%n',
	'quiz_err_channel-en',		'%_iQuiz:%_ %RInvalid channel%n',
	'quiz_err_nochannel',		'%_iQuiz:%_ %RKanal "$0" nie jest otwarty%n',
	'quiz_err_nochannel-en',	'%_iQuiz:%_ %RChannel "$0" is not open%n',
	'quiz_err_filename',		'%_iQuiz:%_ %RBledna nazwa pliku%n',
	'quiz_err_filename-en',		'%_iQuiz:%_ %RInvalid filename%n',
	'quiz_err_nofile',			'%_iQuiz:%_ %RPlik "$0" nie zostal odnaleziony%n',
	'quiz_err_nofile-en',		'%_iQuiz:%_ %RFile "$0" not found%n',
	'quiz_err_file',			'%_iQuiz:%_ %RPlik "$0" wydaje sie byc uszkodzony%n',
	'quiz_err_file-en',			'%_iQuiz:%_ %RFile "$0" seems to be corrupted%n',
	'quiz_err_argument',		'%_iQuiz:%_ %RBledny parametr polecenia%n',
	'quiz_err_argument-en',		'%_iQuiz:%_ %RInvalid argument%n',
	'quiz_err_noquestion',		'%_iQuiz:%_ %RPoczekaj az pytanie zostanie zadane%n',
	'quiz_err_noquestion-en',	'%_iQuiz:%_ %RWait until question is asked%n',
	'quiz_err_type',			'%_iQuiz:%_ %RBledny tryb gry%n',
	'quiz_err_type-en',			'%_iQuiz:%_ %RInvalid quiz type%n',
	'quiz_err_delay',			'%_iQuiz:%_ %RBledna wartosc opoznienia miedzy pytaniami%n',
	'quiz_err_delay-en',		'%_iQuiz:%_ %RInvalid delay between questions%n',
	'quiz_err_duration',		'%_iQuiz:%_ %RBledna wartosc czasu trwania rundy%n',
	'quiz_err_duration-en',		'%_iQuiz:%_ %RInvalid round duration%n',
	'quiz_err_teams',			'%_iQuiz:%_ %RBledna liczba druzyn%n',
	'quiz_err_teams-en',		'%_iQuiz:%_ %RInvalid number of teams%n',
	'quiz_err_ranking',			'%_iQuiz:%_ %RBledna liczba graczy%n',
	'quiz_err_ranking-en',		'%_iQuiz:%_ %RInvalid number of players%n',
	'quiz_err_nonick',			'%_iQuiz:%_ %RNie znajduje nicka "$0" na kanale "$1"%n',
	'quiz_err_nonick-en',		'%_iQuiz:%_ %RUnable to find nick "$0" on channel "$1"%n',
	'quiz_err_nonick_global',		'%_iQuiz:%_ %RNie znajduje nicka "$0" na serwerze%n',
	'quiz_err_nonick_global-en',	'%_iQuiz:%_ %RUnable to find nick "$0" on server%n',
	'quiz_err_na',					'%_iQuiz:%_ %RTa funkcja jest niedostepna przy obecnych ustawieniach%n',
	'quiz_err_na-en',				'%_iQuiz:%_ %RThis feature is not available under current settings%n',

	'quiz_msg',					'%s', # custom text
	'quiz_msg_start1',			"\00303>>> \00310iQuiz by \002wilk\002 wystartowal \00303<<<",
	'quiz_msg_start1-en',		"\00303>>> \00310iQuiz by \00304wilk\00310 started \00303<<<",
	'quiz_msg_start2',			"\00303Polecenia: !podp, !przyp, !ile, !ile nick",
	'quiz_msg_start2-en',		"\00303Commands: !hint, !remind, !score, !score nick",
	'quiz_msg_start2_f',		"\00303Polecenia: !przyp, !ile, !ile nick, !join 1-%u", # 1: max teams
	'quiz_msg_start2_f-en',		"\00303Commands: !remind, !score, !score nick, !join 1-%u",
	'quiz_msg_start2_m',		"\00303Polecenia: !przyp, !ile, !ile nick",
	'quiz_msg_start2_m-en',		"\00303Commands: !remind, !score, !score nick",
	'quiz_msg_stop1',			"\00303>>> \00310iQuiz by \002wilk\002 zakonczony \00303<<<",
	'quiz_msg_stop1-en',		"\00303>>> \00310iQuiz by \002wilk\002 is over \00303<<<",
	'quiz_msg_stop2',			"\00303Liczba rund: \00304%u \00303Czas gry: \00304%s", # 1: rounds, 2: time_str (hms)
	'quiz_msg_stop2-en',		"\00303Rounds: \00304%u \00303Duration: \00304%s", # 1: rounds, 2: time_str (hms)
	'quiz_msg_question',		"\00308,01\037Pytanie %u/%u:\037%s", # see below
	'quiz_msg_question-en',		"\00308,01\037Question %u/%u:\037%s",
	'quiz_msg_question_x',		"\00308,01\037Haslo %u/%u:\037%s", # see below
	'quiz_msg_question_x-en',	"\00308,01\037Word %u/%u:\037%s",
	'quiz_msg_question_fm',		"\00308,01\037Pytanie %u/%u:\037%s \00303(\00304%u\00303 %s, czas: %u sek.)", # 1: round, 2: rounds, 3: question (quiz_inc_question), 4: answers, 5: quiz_flx_answers, 6: round time (s)
	'quiz_msg_question_fm-en',	"\00308,01\037Question %u/%u:\037%s \00303(\00304%u\00303 %s, time: %us)",
	'quiz_inc_question',		"\00300,02 %s \017", # 1: question (antygoogler takes first color code to harden question - must use background color if using antigoogler; if any color is used finish with "\017" to reset it)
	'quiz_msg_hint',			"\00303Podpowiedz: \00304%s", # 1: hint
	'quiz_msg_hint-en',			"\00303Hint: \00304%s",
	'quiz_inc_hint_alpha',		"\00310%s\00304", # 1: symbol (color codes are used to distinguish between hidden letter and real dot, but you may omit them)
	'quiz_inc_hint_digit',		"\00310%s\00304", # 1: symbol (same as above)
	'quiz_msg_remind',			"\00303Przypomnienie: %s", # 1: question (quiz_inc_question)
	'quiz_msg_remind-en',		"\00303Reminder: %s",
	'quiz_msg_delay',			"\00303Opoznienie miedzy pytaniami: \00304%u\00303 sek.", # 1: time (s)
	'quiz_msg_delay-en',		"\00303Delay between questions: \00304%u\00303s",
	'quiz_msg_duration',		"\00303Czas trwania rundy: \00304%u\00303 sek.", # 1: time (s)
	'quiz_msg_duration-en',		"\00303Round duration: \00304%u\00303s",
	'quiz_msg_paused',			"\00303Quiz zostaje \00304wstrzymany\00303 do odwolania.",
	'quiz_msg_paused-en',		"\00303Quiz is temporarily \00304suspended\00303 now.",
	'quiz_msg_skipped',			"\00303Pytanie zostalo \00304pominiete\00303.",
	'quiz_msg_skipped-en',		"\00303This question has been \00304skipped\00303.",
	'quiz_msg_score',			"\00304%s\00303\002\002, zdobyles(as) jak dotad \00304%d\00303 %s.", # 1: nick, 2: score, 3: quiz_flx_points
	'quiz_msg_score-en',		"\00304%s\00303\002\002, you have scored \00304%d\00303 %s so far.",
	'quiz_msg_noscore',			"\00304%s\00303\002\002, nie zdobyles(as) jeszcze zadnego punktu!", # 1: nick
	'quiz_msg_noscore-en',		"\00304%s\00303\002\002, you haven't scored any point yet!",
	'quiz_msg_score_other',		"\00304%s\00303 zdobyl(a) jak dotad \00304%d\00303 %s.", # see quiz_msg_score
	'quiz_msg_score_other-en',	"\00304%s\00303 scored \00304%d\00303 %s so far.",
	'quiz_msg_noscore_other',		"\00304%s\00303 nie zdobyl(a) jeszcze zadnego punktu!", # 1: nick
	'quiz_msg_noscore_other-en',	"\00304%s\00303 hasn't scored any point yet!",
	'quiz_msg_noscores',			"\00303Tablica wynikow jest jeszcze pusta.",
	'quiz_msg_noscores-en',			"\00303Scoreboard is still empty.",
	'quiz_msg_scores',				"\00303Wyniki quizu po %s i %u %s:", # 1: time_str (hms), 2: question, 3: quiz_flx_aquestions, 4: questions (total), 5: quiz_flx_fquestions (total)
	'quiz_msg_scores-en',			"\00303Quiz scores after %s and %u %s:",
	'quiz_msg_scores_place',			"\00303%u. miejsce: \00304%s\00303 - \00304%d\00303 %s [%.1f%%] (sr. czas zgadywania: %10\$.3f sek.)", # 1: place, 2: nick, 3: score, 4: quiz_flx_points, 5: score%, 6: answers, 7: quiz_flx_answers, 8: answers%, 9: best time, 10: avg time, 11: best speed, 12: avg speed, 13: spacer
	'quiz_msg_scores_place-en',			"\00303%u. place: \00304%s\00303 - \00304%d\00303 %s [%.1f%%] (avg. guessing time: %10\$.3fs)",
	'quiz_msg_scores_place_full',		"\00303%u. miejsce: \00304%s\00303 - \00304%d\00303 %s [%.1f%%] (%u %s, sr. czas zgadywania: %10\$.3f sek.)", # see quiz_msg_scores_place
	'quiz_msg_scores_place_full-en',	"\00303%u. place: \00304%s\00303 - \00304%d\00303 %s [%.1f%%] (%u %s, avg. guessing time: %10\$.3fs)",
	'quiz_msg_team_score',			"\00303Druzyna %u (%s): \00304%d\00303 %s", # 1: team, 2: players (comma separated), 3: score, 4: quiz_flx_points, 5: score%, 6: answers, 7: quiz_flx_answers, 8: answers%
	'quiz_msg_team_score-en',		"\00303Team %u (%s): \00304%d\00303 %s",
	'quiz_msg_team_score_full',		"\00303Druzyna %u (%s): \00304%d\00303 %s (%6\$u %7\$s)", # see quiz_msg_team_score
	'quiz_msg_team_score_full-en',	"\00303Team %u (%s): \00304%d\00303 %s (%6\$u %7\$s)",
	'quiz_msg_team_join',			"\00303Dolaczyles(as) do Druzyny %u (%s).", # 1: team, 2: players (comma separated)
	'quiz_msg_team_join-en',		"\00303You have joined to Team %u (%s).",
	'quiz_msg_team_change',			"\00303Zmieniles(as) druzyne na Druzyna %u (%s).", # 1: team, 2: players (comma separated)
	'quiz_msg_team_change-en',		"\00303You have changed your team to Team %u (%s).",
	'quiz_inc_team_nick',			"\00307%s\00303", # 1: nick
	'quiz_msg_scores_times',		"\00303Najszybsi (czas): %s", # 1: players (comma separated)
	'quiz_msg_scores_times-en',		"\00303Fastest players (time): %s",
	'quiz_msg_scores_speeds',		"\00303Najszybsi (zn/s): %s", # 1: players (comma separated)
	'quiz_msg_scores_speeds-en',	"\00303Fastest players (ch/s): %s",
	'quiz_inc_scores_record',		"\00303%u. \00304%s\00303 (%.3f)", # 1: place, 2: nick, 3: time/speed record
	'quiz_msg_congrats',			"\00303Brawo, \00304%s\00303! Otrzymujesz %s za odpowiedz \00304%s\00303 podana po czasie %.3f sek. (%.3f zn/s) - suma punktow: \00304%d\00303.", # 1: nick, 2: quiz_inc_got_point*, 3: answer, 4: time (ms), 5: speed (chars/s), 6: total score
	'quiz_msg_congrats-en',			"\00303Congrats, \00304%s\00303! You get %s for an answer \00304%s\00303 given after %.3fs (%.3f chars/s) - total points: \00304%d\00303.",
	'quiz_msg_congrats_bonus',		"\00303Niezle, \00304%s\00303. Ty rowniez dostajesz %s za swoja odpowiedz podana po czasie %4\$.3f sek. (%5\$.3f zn/s) - suma punktow: \00304%6\$d\00303.", # see above
	'quiz_msg_congrats_bonus-en',	"\00303Good one, \00304%s\00303! You also get %s for your answer given after %4\$.3fs (%5\$.3f chars/s) - total points: \00304%6\$d\00303.",
	'quiz_inc_got_points',			"\00304%d\00303 %s", # 1: points, 2: quiz_flx_points
	'quiz_inc_got_points-en',		"\00304%d\00303 %s",
	'quiz_inc_got_point',			"\00303%s", # 1: quiz_flx_point
	'quiz_inc_got_point-en',		"\00303a %s",
	'quiz_inc_hours',			'%u godz.',		# 1: hours
	'quiz_inc_hours-en',		'%u hr',
	'quiz_inc_minutes',			'%u min.',		# 1: minutes
	'quiz_inc_minutes-en',		'%u min',
	'quiz_inc_seconds',			'%u sek.',		# 1: seconds
	'quiz_inc_seconds-en',		'%u sec',
	'quiz_inc_seconds_ms',		'%.3f sek.',	# 1: seconds.milliseconds
	'quiz_inc_seconds_ms-en',	'%.3f sec',
	'quiz_msg_warn_timeout',	"\00307Zostalo jeszcze tylko \00304%u\00307 sek. na odpowiadanie!", # 1: time (s)
	'quiz_msg_warn_timeout-en',	"\00307Only \00304%u\00307s left for answering!",
	'quiz_msg_all_answers',		"\00303Wszystkie odpowiedzi zostaly odgadniete!",
	'quiz_msg_all_answers-en',	"\00303All answers were given!",
	'quiz_msg_timeout',			"\00303Czas na odpowiadanie uplynal!",
	'quiz_msg_timeout-en',		"\00303Timeout!",
	'quiz_msg_ignored',			"\00303Gracz \00304%s\00303 zostal dodany do listy ignorowanych!", # 1: nick
	'quiz_msg_ignored-en',		"\00303Player \00304%s\00303 has been blacklisted!",
	'quiz_msg_unignored',		"\00303Gracz \00304%s\00303 zostal usuniety z listy ignorowanych.", # 1: nick
	'quiz_msg_unignored-en',	"\00303Player \00304%s\00303 has been removed from blacklist.", # 1: nick
	'quiz_sfx_next',			"\00303Nastepne pytanie za %u sek...", # 1: time (s)
	'quiz_msg_next-en',			"\00303Next question in %us...",
	'quiz_sfx_next_x',			"\00303Nastepne haslo za %u sek...", # 1: time (s)
	'quiz_msg_next_x-en',		"\00303Next word in %us...",
	'quiz_sfx_last',			"\00307Koniec pytan!",
	'quiz_msg_last-en',			"\00307No more questions!",
	'quiz_sfx_limit',			"\00307Masz juz 50%%+1 punktow - wygrales(as), daj pograc innym. ;)",
	'quiz_msg_limit-en',		"\00307You have 50%%+1 points now, you've won - let others play. ;)",
	'quiz_sfx_paused',			"\00307Quiz zostaje wstrzymany do odwolania.",
	'quiz_sfx_paused-en',		"\00307Quiz is temporarily suspended now.",
	# 1 point / x points / 2-4, x2-x4 points (x != 1)	|	1 punkt / x punktow / 2-4, x2-x4 punkty (x != 1)
	'quiz_flx_points',			'punkt/punktow/punkty',
	'quiz_flx_points-en',		'point/points/points',
	# 1 answer / x answers / 2-4, x2-x4 answers (x != 1)	|	1 odpowiedz / x odpowiedzi / 2-4, x2-x4 odpowiedzi (x != 1)
	'quiz_flx_answers',			'odpowiedz/odpowiedzi/odpowiedzi',
	'quiz_flx_answers-en',		'answer/answers/answers',
	# (after) 1 question / x questions / 2-4, x2-x4 questions (x != 1)	|	(po) 1 pytaniu / x pytaniach / 2-4, x2-x4 pytaniach (x != 1)
	'quiz_flx_aquestions',		'pytaniu/pytaniach/pytaniach',
	'quiz_flx_aquestions-en',	'question/questions/questions',
	# (from) 1 question / x questions / 2-4, x2-x4 questions (x != 1)	|	(z) 1 pytania / x pytan / 2-4, x2-x4 pytan (x != 1)
	'quiz_flx_fquestions',		'pytania/pytan/pytan',
	'quiz_flx_fquestions-en',	'question/questions/questions',
];
my $_theme = {@$theme};

theme_register($theme);

##### Main routines #####
sub load_quiz {
	my ($fname, $lines) = (shift, 0);
	$quiz{data} = [];
	$quiz{qcnt} = 0;
	return 0 unless (open(my $fh, '<', $fname));
	while (<$fh>) {
		s/[\n\r]//g;	# chomp is platform dependent ($/)
		tr/\t/ /;		# tabs to spaces
		s/ {2,}/ /g;	# fix double spaces
		s/^ +| +$//g;	# trim leading/trailing spaces/tabs
		next if (/^ *$/);
		if (($quiz{type} == QT_STD) || ($quiz{type} == QT_SCR)) {
			if ($lines % 2) {
				s/^o(dp|pd) //i; # remove format (broken as well)
				$quiz{data}[++$quiz{qcnt}]{answer} = $_; # ++ only on complete question
			} else {
				s/^p(yt|ty) //i; # remove format (broken as well)
				$quiz{data}[$quiz{qcnt} + 1]{($quiz{type} == QT_STD) ? 'question' : 'realquestion'} = $_;
			}
		} elsif ($quiz{type} == QT_MIX) {
			s/^\d+ //; # remove format
			$quiz{data}[++$quiz{qcnt}]{answer} = $_;
		} elsif (($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) {
			if ($lines % 2) {
				s/ +\*/*/g; # fix format
				s/\* +/*/g; # fix format
				my $enum = 1;
				# ++ only on complete question
				%{$quiz{data}[++$quiz{qcnt}]{answers}} = map { $_ => $enum++ } split /\*/;
			} else {
				$quiz{data}[$quiz{qcnt} + 1]{question} = $_;
			}
		}
		$lines++;
	}
	close($fh);
	return $lines;
}

sub l10n {
	my $text = shift;
	my $lang = $quiz{lang};
	if (ref($text)) {
		return exists($text->{$lang}) ? $text->{$lang} : $text->{pl};
	} else {
		my $l10n = $text . (($lang eq 'pl') ? '' : '-' . $lang);
		return exists($_theme->{$l10n}) ? $l10n : $text;
	}
}

sub get_format {
	my ($format, $args) = @_;
	return sprintf(current_theme()->get_format(__PACKAGE__, l10n($format)), ref($args) ? @{$args} : (defined($args) ? $args : ()));
}

sub send_ui {
	my ($format, @rest) = @_;
	printformat(MSGLEVEL_CRAP, l10n($format), @rest);
}

sub send_ui_raw {
	print CLIENTCRAP shift;
}

sub send_irc {
	my (undef, undef, $flags, $nick) = @_;
	$flags //= 0;
	my $msg = get_format(@_);
	if ($quiz{chan}{server}{connected}) {
		my $data = (($flags & WHISPER) ? "NOTICE $nick" : "PRIVMSG $quiz{chan}{name}") . " :$msg"; # notice?
		if ($flags & INSTANT) { # instant or queued?
			$quiz{chan}{server}->send_raw_now($data);
		} else {
			$quiz{chan}{server}->send_raw($data);
		}
		if ($flags & WHISPER) { # le trick (workaround for chantext showing after owntext)
			timeout_add_once($_display_delay, 'evt_delayed_show_notc', [$msg, $nick]);
		} else {
			timeout_add_once($_display_delay, 'evt_delayed_show_msg', $msg);
		}
	} else {
		send_ui_raw($msg); # this helps when we got disconnected not to lose any messages (like stats)
		send_ui('quiz_err_server');
	}
}

sub shuffle_text {
	my ($text, $shuffled, $length) = (shift, '', 0);
	my @text = split(//, $text);
	my @floaters;
	my $smart = ($quiz{type} == QT_SCR) ? settings_get_bool('quiz_smart_mix') : 0;
	if ($smart) {
		my $chars = settings_get_str('quiz_smart_mix_chars'); #? quotemeta?
		for (my $i = 0; $i < @text; $i++) {
			if ($text[$i] !~ /^[$chars]$/) { # hypen, apostrophe, math symbols will float
				push(@floaters, $i);
				$length++;
			}
		}
		$smart = 0 if ($length == length($text)); # no punctations & digits
	} else {
		$length = length($text);
	}
	return $text if ($length < 2); # skip short (and empty)
	my $watchdog = ($length < $_shuffle_threshold) ? 1 : $_shuffle_watchdog;
	my $same = 1;
	if (!$smart) { # check same letter repetition
		foreach my $char (@text) {
			if ($char ne $text[0]) {
				$same = 0;
				last;
			}
		}
	} else {
		foreach my $id (@floaters) {
			if ($text[$id] ne $text[$floaters[0]]) {
				$same = 0;
				last;
			}
		}
	}
	return $text if ($same); # nothing to shuffle
	do {
		if ($smart) {
			my @shuffled = @text; # this way we have anchors already in place
			my @tmp = @floaters;
			foreach my $dst (@floaters) {
				my $src = splice(@tmp, int(rand(@tmp)), 1);
				$shuffled[$dst] = $text[$src];
			}
			$shuffled = join('', @shuffled);
		} else {
			my @tmp = @text;
			$shuffled = '';
			$shuffled .= splice(@tmp, int(rand(@tmp)), 1) while (@tmp);
		}
	} until (($text ne $shuffled) || (--$watchdog <= 0));
	return $shuffled;
}

sub shuffle {
	my ($text, $style) = (shift, settings_get_int('quiz_words_case'));
	my $keepfmt = ($quiz{type} == QT_SCR) ? 1 : settings_get_bool('quiz_words_mode');
	if ($style == 1) {
		$text = lc $text;
	} elsif ($style == 2) {
		$text = uc $text;
	} elsif ($style == 3) {
		$text = join(' ', map { ucfirst lc } split(/ /, $text));
	}
	if ($keepfmt) {
		return join(' ', map { shuffle_text($_) } split(/ /, $text));
	} else {
		$text =~ s/ //g;
		return shuffle_text($text);
	}
}

sub antigoogle {
	my $text = shift;
	return $text unless (settings_get_bool('quiz_antigoogler') && ($text =~ / /));
	return $text if ($_protect_urls && ($text =~ m<https?://|www\.>));
	my ($fg, $bg) = (get_format('quiz_inc_question', '') =~ /^\003(\d{1,2}),(\d{1,2})/);
	return $text unless (defined($fg) && defined($bg));
	($fg, $bg) = map { int } ($fg, $bg);
	my @set = ('a'..'z', 'A'..'Z', 0..9);
	my @h; my @v;
	#t = \00300,01 (quiz_inc_question)
	#h = \0031,01 \00301,01 \00301
	#v = \0030,01 \00300,01 \00300
	if ($bg < 10) {
		push(@h, "\0030$bg");
		push(@h, "\003$bg,0$bg", "\0030$bg,0$bg") if ($_randomized_antigoogler);
	} else {
		push(@h, "\003$bg");
		push(@h, "\003$bg,$bg") if ($_randomized_antigoogler);
	}
	$bg = substr("0$bg", -2); # make sure $bg is 2-char
	if ($fg < 10) {
		push(@v, "\0030$fg");
		push(@v, "\003$fg,$bg", "\0030$fg,$bg") if ($_randomized_antigoogler);
	} else {
		push(@v, "\003$fg");
		push(@v, "\003$fg,$bg") if ($_randomized_antigoogler);
	}
	my @lines;
	if (settings_get_bool('quiz_split_long_lines')) {
		# very ugly, but required calculations depending on type of question
		my $raw_crap = length(get_format('quiz_inc_question', ''));
		my $msg_crap = $raw_crap;
		if (!$quiz{inq}) {
			my $suffix = ($quiz{type} == QT_MIX) ? '_x' : ((($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) ? '_fm' : '');
			my $answers = keys %{$quiz{lookup}};
			my $duration = abs(settings_get_int('quiz_timeout')) || $_round_duration; # abs in case of <0, || in case of ==0
			$msg_crap += length(get_format('quiz_msg_question' . $suffix, [$quiz{qnum}, $quiz{qcnt}, '', $answers, answers_str($answers), $duration]));
		} else {
			$msg_crap += length(get_format('quiz_msg_remind', ''));
		}
		my $cutoff = 497 - length($quiz{chan}{server}{nick} . $quiz{chan}{server}{userhost} . $quiz{chan}{name});
		my @words = split(/ /, $text);
		$text = shift(@words);
		my ($line, $subst) = (1, 1);
		while (@words) {
			my $ag = $h[int(rand(@h))] . $set[int(rand(@set))] . $v[int(rand(@v))];
			$ag = ' ' if ($_smarter_antigoogler && ($subst % ($_smarter_antigoogler_chunk + 1) == 0));
			my $word = shift(@words);
			if (length($text . $ag . $word) > $cutoff - (($line == 1) ? $msg_crap : $raw_crap)) {
				push(@lines, $text);
				$text = $word;
				$line++;
				$subst = 1;
			} else {
				$text .= $ag . $word;
				$subst++;
			}
		}
	} else {
		if ($_smarter_antigoogler) {
			my @words = split(/ /, $text);
			$text = shift(@words);
			my $subst = 1;
			while (@words) {
				my $ag = $h[int(rand(@h))] . $set[int(rand(@set))] . $v[int(rand(@v))];
				$ag = ' ' if ($subst++ % ($_smarter_antigoogler_chunk + 1) == 0);
				$text .= $ag . shift(@words);
			}
		} else {
			while ($text =~ / /) {
				my $ag = $h[int(rand(@h))] . $set[int(rand(@set))] . $v[int(rand(@v))];
				$text =~ s/ /$ag/; # one by one, not /g
			}
		}
	}
	push(@lines, $text);
	return @lines;
}

sub put_dots {
	my ($hint, $format, $setting, $default, $marker) = @_;
	my $char = settings_get_str($setting); #? substr(settings_get_str($setting), 0, 1)
	my $dot = get_format($format, ($char eq '') ? $default : $char);
	$hint =~ s/$marker/$dot/g; # le trick grande finale
	my ($scol, $ecol) = ($dot =~ /^(\003\d{1,2}(?:,\d{1,2})?).(\003\d{1,2}(?:,\d{1,2})?)$/);
	if (defined($scol) && defined($ecol)) {
		$hint =~ s/$ecol $scol/ /g; # optimize color codes
		$hint =~ s/$ecol$scol//g;
		$hint =~ s/$ecol$//;
	}
	return $hint;
}

sub make_hint {
	my $dots_only = shift;
	my @words = split(/ /, $quiz{data}[$quiz{qnum}]{answer});
	if (!@{$quiz{dots}}) { # make first dots
		@quiz{qw/dcnt dmax/} = (0) x 2;
		$quiz{hwords} = [];
		my ($w, $dmax) = (0) x 2;
		foreach my $word (@words) {
			my ($l, $hword, $dcnt) = (0, '', 0);
			foreach my $letter (split(//, $word)) {
				if ($letter =~ /^[a-z0-9]$/i) {
					push(@{$quiz{dots}[$w]}, $l);
					$hword .= ($letter =~ /^[0-9]$/) ? "\002" : "\001"; # le trick (any ASCII non-printable char)
					$quiz{dcnt}++;
					$dcnt++;
				} else {
					$hword .= $letter;
				}
				$l++;
			}
			push(@{$quiz{hwords}}, $hword);
			$dmax = $dcnt if ($dcnt > $dmax);
			$w++;
		}
		$quiz{dmax} = $dmax;
	}
	return '' if ($dots_only); # prep dots only
	$quiz{hnum}++;
	my $first_dots = settings_get_bool('quiz_first_hint_dots');
	if (!$first_dots || ($quiz{hnum} > 1)) { # reveal some dots
		my $random_hints = settings_get_bool('quiz_random_hints');
		my $show_first = settings_get_bool('quiz_nonrandom_first_hint') && ($quiz{hnum} == ($first_dots ? 2 : 1));
		my ($w, $dmax) = (0) x 2;
		foreach my $r_wdots (@{$quiz{dots}}) {
			if ((ref $r_wdots) && (@$r_wdots > 0)) {
				my @letters = split(//, $words[$w]);
				my @hletters = split(//, $quiz{hwords}[$w]);
				my $sel = (!$random_hints || $show_first) ? 0 : int(rand(@$r_wdots));
				$hletters[@$r_wdots[$sel]] = $letters[@$r_wdots[$sel]];
				$quiz{hwords}[$w] = join('', @hletters);
				splice(@$r_wdots, $sel, 1);
				$quiz{dcnt}--;
				$dmax = @$r_wdots if (@$r_wdots > $dmax);
			}
			$w++;
		}
		$quiz{dmax} = $dmax;
	}
	my $hint = join(' ', @{$quiz{hwords}});
	$hint = put_dots($hint, 'quiz_inc_hint_alpha', 'quiz_hint_alpha', $_hint_alpha, "\001");
	$hint = put_dots($hint, 'quiz_inc_hint_digit', 'quiz_hint_digit', $_hint_digit, "\002");
	return $hint;
}

sub make_remind {
	if (!$quiz{inq} || settings_get_bool('quiz_mix_on_remind')) {
		if ($quiz{type} == QT_SCR) {
			$quiz{data}[$quiz{qnum}]{question} = shuffle($quiz{data}[$quiz{qnum}]{realquestion});
		} elsif ($quiz{type} == QT_MIX) {
			$quiz{data}[$quiz{qnum}]{question} = shuffle($quiz{data}[$quiz{qnum}]{answer});
		}
	}
	return antigoogle($quiz{data}[$quiz{qnum}]{question});
}

sub time_str {
	my ($s, $mode) = @_;
	my ($h, $m) = (0) x 2;
	if ($mode == TIME_HMS) {
		$h = int($s / 3600);
		$m = int($s / 60) % 60;
		$s %= 60;
	}
	my $str = '';
	$str .= get_format('quiz_inc_hours', $h) . ' ' if ($h);
	$str .= get_format('quiz_inc_minutes', $m) . ' ' if ($m);
	$str .= get_format('quiz_inc_seconds' . (($mode == TIME_MS) ? '_ms' : ''), $s) if ($s || (!$h && !$m));
	$str =~ s/ $//;
	return $str;
}

sub flex {
	my ($value, $format, $flex) = (abs(shift), shift, 0);
	my @flex = split(/$_flex_separator/, get_format($format));
	if ($value != 1) {
		$flex++;
		$flex++ if ($value =~ /^[2-4]$|[^1][2-4]$/);
	}
	return defined($flex[$flex]) ? $flex[$flex] : '???'; # just a precaution when user messes up
}

sub score_str		{ return flex(shift, 'quiz_flx_points'); }		# X points
sub answers_str		{ return flex(shift, 'quiz_flx_answers'); }		# X answers
sub aquestions_str	{ return flex(shift, 'quiz_flx_aquestions'); }	# after X questions <- AFTER!
sub fquestions_str	{ return flex(shift, 'quiz_flx_fquestions'); }	# from X questions <- FROM!

sub percents {
	my ($val, $of) = @_;
	return ($of == 0) ? 0 : $val / $of * 100;
}

sub asciize {
	my $text = shift;
	return $text unless (settings_get_bool('quiz_asciize'));
	$text =~ s/ę/e/g; $text =~ s/ó/o/g; $text =~ s/ą/a/g; $text =~ s/ś/s/g; $text =~ s/ł/l/g;
	$text =~ s/ż/z/g; $text =~ s/ź/z/g; $text =~ s/ć/c/g; $text =~ s/ń/n/g;
	$text =~ s/Ę/E/g; $text =~ s/Ó/O/g; $text =~ s/Ą/A/g; $text =~ s/Ś/S/g; $text =~ s/Ł/L/g;
	$text =~ s/Ż/Z/g; $text =~ s/Ź/Z/g; $text =~ s/Ć/C/g; $text =~ s/Ń/N/g;
	return $text;
}

sub stop_timer {
	my $timer = shift;
	if ($quiz{$timer}) {
		timeout_remove($quiz{$timer});
		$quiz{$timer} = undef;
	}
}

sub stop_question {
	@quiz{qw/inq bonus hnum hprot rprot dcnt dmax/} = (0) x 7;
	stop_timer($_) foreach (qw/tround thint thinter tremind twarn tbonus/);
	$quiz{dots} = [];
	$quiz{hwords} = [];
	$quiz{lookup} = {};
}

sub stop_quiz {
	stop_question();
	@quiz{qw/ison standby ended wantpause paused/} = (0) x 5;
	stop_timer('tnext');
	$quiz{lastone} = '';
	signal_remove('message public', 'sig_pubmsg');
}

sub init_next_question {
	my ($msg, $flags) = @_;
	$flags //= 0;
	if ($quiz{qnum} >= $quiz{qcnt}) {
		send_irc('quiz_msg', $msg . (($flags & BONUS) ? '' : ' ' . get_format('quiz_sfx_last')), $flags);
		$quiz{ended} = 1;
	} else {
		my $suffix = '';
		if ($quiz{wantpause}) {
			$suffix = ' ' . get_format('quiz_sfx_paused') unless ($flags & BONUS);
			@quiz{qw/wantpause paused/} = (0, 1);
		} else {
			unless ($flags & BONUS) {
				my $delay;
				if (($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) {
					$delay = abs(settings_get_int('quiz_delay_long')) || $_next_delay_long; # abs in case of <0, || in case of ==0
				} else {
					$delay = abs(settings_get_int('quiz_delay')) || $_next_delay; # abs in case of <0, || in case of ==0
				}
				$suffix = ' ' . get_format('quiz_sfx_next' . (($quiz{type} == QT_MIX) ? '_x' : ''), $delay);
				$quiz{tnext} = timeout_add_once($delay * 1000, 'evt_show_question', undef);
			}
		}
		send_irc('quiz_msg', $msg . $suffix, $flags);
	}
}

sub name_to_type {
	my ($name, $type) = (shift, undef);
	return $name if ($name =~ /^\d+$/);
	my %type = (diz => 1, std => 1, sta => 1, nrm => 1, nor => 1, zwy => 1,
				mie => 2, mix => 2, lit => 2,
				fam => 3, dru => 3, tea => 3,
				mul => 4, all => 4, wsz => 4, bez => 4,
				pom => 5, scr => 5);
	foreach my $key (keys %type) {
		$type = $type{$key}, last if (lc($name) =~ /^$key/i);
	}
	return $type;
}

sub is_valid_quiz {
	return (($quiz{qcnt} < 1) ||
		((($quiz{type} == QT_STD) || ($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL) ||
		($quiz{type} == QT_SCR)) && ($quiz{qcnt} * 2 != shift))) ? 0 : 1;
}

sub correct_answer {
	my ($addr, $nick, $timestamp, $points, $answer) = @_;
	@{$quiz{players}{$addr}}{qw/besttime bestspeed/} = (0) x 2 if (!exists $quiz{players}{$addr});
	@{$quiz{players}{$addr}}{qw/nick timestamp/} = ($nick, $timestamp);
	my $time = $timestamp - $quiz{qtime};
	my $speed = length($answer) / $time;
	$quiz{players}{$addr}{alltime} += $time;
	$quiz{players}{$addr}{allspeed} += $speed;
	$quiz{players}{$addr}{besttime} = $time if (($quiz{players}{$addr}{besttime} == 0) || ($quiz{players}{$addr}{besttime} > $time));
	$quiz{players}{$addr}{bestspeed} = $speed if (($quiz{players}{$addr}{bestspeed} == 0) || ($quiz{players}{$addr}{bestspeed} < $speed));
	$quiz{players}{$addr}{score} += $points;
	$quiz{players}{$addr}{answers}++;
	$quiz{score} += $points;
	$quiz{answers}++;
	if ($quiz{type} == QT_FAM) {
		$quiz{players}{$addr}{team} = 0 if (!exists $quiz{players}{$addr}{team}); # team_play is on and player is an outsider (outsiders = team 0)
		my $team = $quiz{players}{$addr}{team};
		$quiz{teams}[$team]{score} += $points;
		$quiz{teams}[$team]{answers}++;
	}
}

sub hcmd {
	return sprintf(' %-32s - ', shift);
}

sub hvar {
	my ($setting, $type) = @_;
	if ($type == INT) {
		return sprintf(' %-26s : %-3d - ', $setting, settings_get_int($setting));
	} elsif ($type == BOOL) {
		return sprintf(' %-26s : %-3s - ', $setting, settings_get_bool($setting) ? 'on' : 'off');
	} elsif ($type == STR) {
		return sprintf(' %-26s : %-3s - ', $setting, settings_get_str($setting));
	}
}

sub show_help {
	my $type = settings_get_int('quiz_type');
	my $state = l10n({	pl => 'jest wylaczony',
						en => 'is offline'});
	if ($quiz{ison}) {
		if ($quiz{standby}) {
			$state = l10n({	pl => 'oczekuje na uruchomienie',
							en => 'is on standby'});
		} elsif ($quiz{ended}) {
			$state = l10n({	pl => 'dobiegl konca',
							en => 'has finished'});
		} elsif ($quiz{paused}) {
			$state = l10n({	pl => 'jest wstrzymany',
							en => 'is paused'});
		} else {
			$state = l10n({	pl => 'trwa',
							en => 'is ongoing'});
		}
	}
	send_ui_raw("%_$IRSSI{name}%_ v$VERSION by wilk (" . l10n({	pl => 'quiz obecnie',
																en => 'quiz currently'}) . ": %_$state%_)");
	send_ui_raw(l10n({	pl => '%_Dostepne polecenia:%_ ([] - parametr opcjonalny, <> - parametr wymagany)',
						en => '%_Available commands:%_ ([] - optional argument, <> - required argument)'}));
	send_ui_raw(hcmd('/qtype ' . l10n({	pl => "[1-$_quiz_types/nazwa]",
										en => "[1-$_quiz_types/name]"})) . l10n({	pl => 'zmiana rodzaju quizu (bez parametru wybiera kolejny)',
																					en => 'change quiz type'}));
	if ($type == QT_FAM) {
		send_ui_raw(hcmd("/qteams <2-$_max_teams>") . l10n({	pl => 'zmiana liczby druzyn',
																en => 'change number of teams'}));
		send_ui_raw(hcmd('/qon ' . l10n({	pl => "[kanal] <plik> [1-$_quiz_types/nazwa] [0-$_max_teams]",
											en => "[channel] <file> [1-$_quiz_types/name] [0-$_max_teams]"})) . l10n({	pl => 'rozpoczecie quizu (mozna podac rodzaj quizu i liczbe druzyn)',
																														en => 'start the quiz (you can provide its type and number of teams)'}));
		send_ui_raw(hcmd('/qstats ' . l10n({	pl => '[miejsca]',
												en => '[places]'})) . l10n({	pl => 'wyswietla ranking graczy (0: pokazuje tylko druzyny)',
																				en => 'display scoreboard (0: teams only)'}));
	} else {
		send_ui_raw(hcmd('/qon ' . l10n({	pl => "[kanal] <plik> [1-$_quiz_types/nazwa]",
											en => "[channel] <file> [1-$_quiz_types/name]"})) . l10n({	pl => 'rozpoczecie quizu (mozna tez podac rodzaj quizu)',
																										en => 'start the quiz (you can provide its type)'}));
		send_ui_raw(hcmd('/qstats ' . l10n({	pl => '[miejsca]',
												en => '[places]'})) . l10n({	pl => 'wyswietla ranking graczy',
																				en => 'display scoreboard'}));
	}
	send_ui_raw(hcmd('/qhint') . l10n({	pl => 'wyswietlenie podpowiedzi',
										en => 'show next hint'})) if (($type != QT_FAM) && ($type != QT_MUL));
	send_ui_raw(hcmd('/qremind') . l10n({	pl => 'przypomnienie biezacego pytania',
											en => 'remind current question'}));
	send_ui_raw(hcmd('/qskip') . l10n({	pl => 'pominiecie biezacego pytania',
										en => 'skip current question'}));
	send_ui_raw(hcmd('/qpause') . l10n({	pl => 'wstrzymanie quizu (od nastepnego pytania)',
											en => 'suspend the quiz'}));
	send_ui_raw(hcmd('/qoff') . l10n({	pl => 'przerwanie lub zakonczenie quizu',
										en => 'break or finish the quiz'}));
	send_ui_raw(hcmd('/qdelay ' . l10n({	pl => '<sekundy>',
											en => '<seconds>'})) . l10n({	pl => 'zmiana opoznienia miedzy pytaniami',
																			en => 'change delay between questions'}));
	send_ui_raw(hcmd('/qtime ' . l10n({	pl => '<sekundy>',
										en => '<seconds>'})) . l10n({	pl => 'zmiana czasu trwania rundy',
																		en => 'change round duration'})) if (($type == QT_FAM) || ($type == QT_MUL));
	send_ui_raw(hcmd('/qignore <nick>') . l10n({	pl => '(od)blokowanie problematycznego gracza',
													en => '(un)ignore a cheating player'}));
	send_ui_raw(hcmd('/qreload') . l10n({	pl => 'ponowne wczytanie pliku z pytaniami',
											en => 'reload questions'}));
	send_ui_raw(hcmd('/qinit') . l10n({	pl => 'resetuje ustawienia do wartosci poczatkowych',
										en => 'reset settings to default values'}));
	send_ui_raw(l10n({	pl => '%_Dostepne ustawienia (/set):%_',
						en => '%_Available settings (/set):%_'}));
	send_ui_raw(hvar('quiz_type', INT) . l10n({	pl => 'rodzaj quizu (1: Dizzy, 2: Mieszacz/Literaki, 3: Familiada, 4: Multi (Familiada bez druzyn), 5: Pomieszany)',
												en => 'quiz type (1: Dizzy, 2: Mieszacz/Literaki, 3: Familiada, 4: Multi (Familiada w/o teams), 5: Pomieszany)'}));
	send_ui_raw(hvar('quiz_teams', INT) . l10n({	pl => 'liczba druzyn',
													en => 'number of teams'}) . " (2-$_max_teams)") if ($type == QT_FAM);
	if (($type == QT_FAM) || ($type == QT_MUL)) {
		send_ui_raw(hvar('quiz_delay_long', INT) . l10n({	pl => 'opoznienie miedzy pytaniami (sek.)',
															en => 'delay between questions (sec)'}));
		send_ui_raw(hvar('quiz_timeout', INT) . l10n({	pl => 'czas trwania rundy (sek.)',
														en => 'round duration (sec)'}));
	} else {
		send_ui_raw(hvar('quiz_delay', INT) . l10n({	pl => 'opoznienie miedzy pytaniami (sek.)',
														en => 'delay between questions (sec)'}));
		send_ui_raw(hvar('quiz_max_hints', INT) . l10n({	pl => 'limit podpowiedzi (0: bez ogr., >0: limit podp., <0: limit ukrytych znakow)',
															en => 'max. number of hints (0: no limit, >0: number of hints, <0: number of hidden chars)'}));
		send_ui_raw(hvar('quiz_autohinter', BOOL) . l10n({	pl => 'automatyczne podpowiedzi?',
															en => 'show automatic hints?'}));
		send_ui_raw(hvar('quiz_hints_interval', INT) . l10n({	pl => 'opoznienie pomiedzy auto-podpowiedziami (sek.)',
																en => 'automatic hints interval (sec)'}));
	}
	send_ui_raw(hvar('quiz_words_case', INT) . l10n({	pl => 'styl wyrazow (0: bez zmian, 1: male, 2: DUZE, 3: Kapitaliki)',
														en => 'words\' case (0: no change, 1: l-case, 2: U-case, 3: Caps)'})) if (($type == QT_MIX) || ($type == QT_SCR));
	send_ui_raw(hvar('quiz_antigoogler', BOOL) . l10n({	pl => 'uzywac antygooglera do ochrony pytan?',
														en => 'protect questions with antigoogler?'}));
	send_ui_raw(hvar('quiz_split_long_lines', BOOL) . l10n({	pl => 'dzielic dlugie linie na czesci (nowsze irssi potrafi samo)?',
																en => 'split long lines?'}));
	send_ui_raw(hvar('quiz_anticheat_delay', INT) . l10n({	pl => 'czas trwania ochrony !podp/!przyp (sek.; 0: wylaczone)',
															en => '!hint/!remind protection delay (sec; 0: off)'}));
	send_ui_raw(hvar('quiz_first_anticheat_delay', INT) . l10n({	pl => 'czas trwania ochrony pierwszego !podp/!przyp (sek.; 0: wylaczone)',
																	en => 'first !hint/!remind protection delay (sec; 0: off)'}));
	if (($type != QT_FAM) && ($type != QT_MUL)) {
		send_ui_raw(hvar('quiz_show_first_hint', BOOL) . l10n({	pl => 'pokazywac podpowiedz razem z pytaniem?',
																en => 'show questions along with first hint?'}));
		send_ui_raw(hvar('quiz_first_hint_dots', BOOL) . l10n({	pl => 'pierwsza podpowiedz jako same kropki?',
																en => 'first hint as dots only?'}));
		send_ui_raw(hvar('quiz_random_hints', BOOL) . l10n({	pl => 'losowe odslanianie podpowiedzi? albo od lewej do prawej',
																en => 'reveal random chars in hints? otherwise from left to right'}));
		send_ui_raw(hvar('quiz_nonrandom_first_hint', BOOL) . l10n({	pl => 'losowe odslanianie podpowiedzi, poza pierwsza?',
																		en => 'reveal random chars in hints, except first hint?'}));
		send_ui_raw(hvar('quiz_hint_alpha', STR) . l10n({	pl => 'znak podstawiany w podpowiedziach za litery',
															en => 'character substituted for letters'}));
		send_ui_raw(hvar('quiz_hint_digit', STR) . l10n({	pl => 'znak podstawiany w podpowiedziach za cyfry',
															en => 'character substituted for digits'}));
	}
	send_ui_raw(hvar('quiz_words_mode', BOOL) . l10n({	pl => 'mieszac slowa osobno? albo wszystko razem',
														en => 'scramble words separately? otherwise all together'})) if ($type == QT_MIX);
	if ($type == QT_SCR) {
		send_ui_raw(hvar('quiz_smart_mix', BOOL) . l10n({	pl => 'mieszac kotwiczac cyfry i niektore znaki interpunkcyjne?',
															en => 'anchor some characters? (digits/punctation)'}));
		send_ui_raw(hvar('quiz_smart_mix_chars', STR) . l10n({	pl => 'te znaki beda zakotwiczone (regex)',
																en => 'anchor these characters (regex)'}));
	}
	send_ui_raw(hvar('quiz_mix_on_remind', BOOL) . l10n({	pl => 'mieszac litery przy kazdym !przyp?',
															en => 'scramble letters with each !remind?'})) if (($type == QT_MIX) || ($type == QT_SCR));
	if ($type == QT_FAM) {
		send_ui_raw(hvar('quiz_join_anytime', BOOL) . l10n({	pl => 'wchodzenie do druzyn w dowolnej chwili?',
																en => 'allow joining teams at any time?'}));
		send_ui_raw(hvar('quiz_team_play', BOOL) . l10n({	pl => 'graja tylko gracze z druzyn?',
															en => 'only team players can answer?'}));
		send_ui_raw(hvar('quiz_transfer_points', BOOL) . l10n({	pl => 'wraz ze zmiana druzyny przenosic tez punkty?',
																en => 'transfer scores when player changes a team?'}));
	}
	send_ui_raw(hvar('quiz_strict_match', BOOL) . l10n({	pl => 'tylko doslowne odpowiedzi? albo *dopasowane*',
															en => 'only strict answers? or allow *matching*'})) if (($type != QT_FAM) && ($type != QT_MUL));
	send_ui_raw(hvar('quiz_points_per_answer', INT) . l10n({	pl => 'punkty za poprawna odpowiedz',
																en => 'points given for correct answer'}));
	if (($type == QT_FAM) || ($type == QT_MUL)) {
		send_ui_raw(hvar('quiz_min_points', INT) . l10n({	pl => 'minimum punktowe',
															en => 'min. points'}));
		send_ui_raw(hvar('quiz_max_points', INT) . l10n({	pl => 'maksimum punktowe',
															en => 'max. points'}));
		send_ui_raw(hvar('quiz_scoring_mode', INT) . l10n({	pl => 'tryb punktowania (1: ppa, 2: ppa++, 3: ppa++:max, 4: min++ppa, 5: min++ppa:max, 6: max--ppa:min, 7: max->min',
															en => 'scoring mode (1: ppa, 2: ppa++, 3: ppa++:max, 4: min++ppa, 5: min++ppa:max, 6: max--ppa:min, 7: max->min'}));
	} else {
		send_ui_raw(hvar('quiz_bonus_answer', BOOL) . l10n({	pl => 'uznawac dodatkowa szybka odpowiedz drugiego gracza? (max. 1 sek.)',
																en => 'accept second fastest answer? (within 1s)'}));
		send_ui_raw(hvar('quiz_points_per_bonus', INT) . l10n({	pl => 'punkty za druga najszybsza odpowiedz',
																en => 'points given for second fastest answer'}));
		send_ui_raw(hvar('quiz_limiter', BOOL) . l10n({	pl => 'limitowac najlepsza osobe do 50%+1 punktow?',
														en => 'limit best player to 50%+1 of total points?'}));
	}
	send_ui_raw(hvar('quiz_asciize', BOOL) . l10n({	pl => 'konwertowac znaki diakrytyczne w odpowiedziach do ASCII? (utf8)',
													en => 'convert diacritic marks in answers to ASCII? (utf8)'}));
	send_ui_raw(hvar('quiz_ranking_type', INT) . l10n({	pl => 'rodzaj rankingu (1: zwykly "1234", 2: zwarty "1223", 3: turniejowy "1224")',
														en => 'ranking type (1: ordinal "1234", 2: dense "1223", 3: competition "1224")'}));
	send_ui_raw(hvar('quiz_keep_scores', BOOL) . l10n({	pl => 'sumowac punkty z poprzednich quizow?',
														en => 'keep scores between quizzes?'}));
	send_ui_raw(hvar('quiz_keep_teams', BOOL) . l10n({	pl => 'jesli zachowujemy punkty, to pozostawiac zawodnikow w druzynach miedzy quizami?',
														en => 'keep teams\' composition as well?'})) if ($type == QT_FAM);
	send_ui_raw(hvar('quiz_cmd_hint', BOOL) . l10n({	pl => 'polecenie !podp jest dostepne dla graczy?',
														en => 'should !hint command be available?'}));
	send_ui_raw(hvar('quiz_cmd_remind', BOOL) . l10n({	pl => 'polecenie !przyp jest dostepne dla graczy?',
														en => 'should !remind command be available?'}));
	send_ui_raw(hvar('quiz_lang', STR) . l10n({	pl => 'wersja jezykowa komunikatow (dostepne: "pl" oraz "en")',
												en => 'language version (available: "pl" and "en")'}));
}

##### Commands' handlers #####
sub cmd_start {
	if ($quiz{standby}) {
		$quiz{standby} = 0;
		evt_show_question();
		return;
	}
	send_ui('quiz_err_ison'), return if ($quiz{ison});
	my ($args, $r_server, $r_window) = @_;
	send_ui('quiz_err_server'), return if (!ref($r_server) || !$r_server->{connected});
	my ($chan, $file, $type, $teams) = split(/ /, $args);
	($file, $chan) = ($chan, ref($r_window) ? $r_window->{name} : undef) if (!defined $file); # single arg call?
	send_ui('quiz_err_channel'), return if (!$chan || !$r_server->ischannel($chan));
	{
		{ package Irssi::Nick; } # should prevent irssi bug: "Can't locate package Irssi::Nick for @Irssi::Irc::Nick::ISA at ..."
		$quiz{chan} = $r_server->channel_find($chan);
	}
	send_ui('quiz_err_nochannel', $chan), return if (!defined $quiz{chan});
	$file = (glob $file)[0]; # open() does not support "~"
	send_ui('quiz_err_filename'), return if (!$file);
	send_ui('quiz_err_nofile', $file), return if (!-e $file);
	$type = defined($type) ? name_to_type($type) : settings_get_int('quiz_type');
	send_ui('quiz_err_type'), return if (!$type || ($type < 0) || ($type > $_quiz_types));
	if (defined $teams) {
		send_ui('quiz_err_type'), return if (($type != QT_FAM) && ($type != QT_MUL));
		if (($type == QT_MUL) && ($teams >= 2)) {
			$type = QT_FAM;
		} elsif (($type == QT_FAM) && ($teams < 2)) {
			$type = QT_MUL;
		}
	} else {
		$teams = settings_get_int('quiz_teams');
	}
	send_ui('quiz_err_teams'), return if (($type == QT_FAM) && (($teams !~ /^\d+$/) || ($teams < 2) || ($teams > $_max_teams)));
	settings_set_int('quiz_type', $type);
	settings_set_int('quiz_teams', $teams) if ($teams >= 2);
	@quiz{qw/type tcnt file/} = ($type, $teams, $file);
	my $lines = load_quiz($file);
	send_ui('quiz_err_file', $file), return if (!is_valid_quiz($lines));
	if (!settings_get_bool('quiz_keep_scores')) {
		$quiz{players} = {};
		$quiz{teams} = [];
		@quiz{qw/score answers/} = (0) x 2;
	} else {
		if (!settings_get_bool('quiz_keep_teams') && ($type == QT_FAM)) {
			delete $quiz{players}{$_}{team} for (keys %{$quiz{players}});
		}
	}
	send_irc('quiz_msg_start1', INSTANT);
	send_irc('quiz_msg_start2' . (($type == QT_FAM) ? '_f' : (($type == QT_MUL) ? '_m' : '')), $teams, INSTANT);
	@quiz{qw/stime ison/} = (time(), 1);
	@quiz{qw/qnum inq ended/} = (0) x 3;
	if ($type == QT_FAM) {
		$quiz{standby} = 1;
		@{$quiz{teams}[$_]}{qw/score answers/} = (0) x 2 for (0 .. $teams);
	} else {
		$quiz{standby} = 0;
		if ($_start_delay > 0) {
			$quiz{tnext} = timeout_add_once($_start_delay, 'evt_show_question', undef);
		} else {
			evt_show_question();
		}
	}
	signal_add_last('message public', 'sig_pubmsg');
}

sub cmd_stats {
	send_ui('quiz_err_isoff'), return if (($quiz{score} == 0) && !$quiz{ison});
	my $num = shift;
	send_ui('quiz_err_ranking'), return if (($num ne '') && ($num !~ /^\d+$/));
	$num = -1 if ($num eq '');
	send_irc('quiz_msg_noscores'), return if (!keys %{$quiz{players}});
	my $qnum = $quiz{qnum};
	$qnum-- if ($quiz{inq});
	send_irc('quiz_msg_scores', [
		time_str(time() - $quiz{stime}, TIME_HMS),
		$qnum, aquestions_str($qnum),
		$quiz{qcnt}, fquestions_str($quiz{qcnt})]) if (!$quiz{standby});
	my $suffix = '';
	$suffix = '_full' if ((settings_get_int('quiz_points_per_answer') != 1) ||
		((($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) && (settings_get_int('quiz_scoring_mode') != 1)));
	if ($quiz{type} == QT_FAM) {
		my @teams;
		push(@{$teams[$quiz{players}{$_}{team}]}, get_format('quiz_inc_team_nick', $quiz{players}{$_}{nick})) for (sort { $quiz{players}{$a}{joined} <=> $quiz{players}{$b}{joined} } keys %{$quiz{players}});
		foreach my $team (sort {
							$quiz{teams}[$b]{score} <=> $quiz{teams}[$a]{score} or
							$quiz{teams}[$b]{answers} <=> $quiz{teams}[$a]{answers}
						} 1 .. $quiz{tcnt}) {
			my ($score, $answers) = @{$quiz{teams}[$team]}{qw/score answers/};
			send_irc('quiz_msg_team_score' . $suffix, [
				$team,
				(!defined $teams[$team]) ? '' : join($_team_separator, @{$teams[$team]}),
				$score, score_str($score), percents($score, $quiz{score}),
				$answers, answers_str($answers), percents($answers, $quiz{answers})]);
		}
	}
	return if ($quiz{standby} || (($num == 0) && ($quiz{type} == QT_FAM)));
	my ($rank, $place, $exaequo, $prev, $ranking) = (0, 1, 0, undef, settings_get_int('quiz_ranking_type'));
	$ranking = (($ranking < 1) || ($ranking > 3)) ? 1 : $ranking; # in case of dumb value
	foreach my $player (sort {
						$quiz{players}{$b}{score} <=> $quiz{players}{$a}{score} or
						$quiz{players}{$b}{answers} <=> $quiz{players}{$a}{answers} or
						$quiz{players}{$a}{timestamp} <=> $quiz{players}{$b}{timestamp}
					} keys %{$quiz{players}}) {
		my ($score, $answers) = @{$quiz{players}{$player}}{qw/score answers/};
		if (!defined($prev) || ($ranking == 1) || ($score != $prev)) { # 1234
			$rank += 1 + $exaequo;
			$exaequo = 0;
			$prev = $score;
		} else {
			if ($ranking == 3) { # 1224
				$exaequo++;
			} elsif ($ranking == 2) { # 1223
				# nop
			} else { # 1234 / fallback
				$rank++;
			}
		}
		last if ($_qstats_ranks && ($num > 0) && ($rank > $num));
		send_irc('quiz_msg_scores_place' . $suffix, [
			$rank,
			$quiz{players}{$player}{nick},
			$score, score_str($score), percents($score, $quiz{score}),
			$answers, answers_str($answers), percents($answers, $quiz{answers}),
			$quiz{players}{$player}{besttime}, ($answers > 0) ? $quiz{players}{$player}{alltime} / $answers : 0,
			$quiz{players}{$player}{bestspeed}, ($answers > 0) ? $quiz{players}{$player}{allspeed} / $answers : 0,
			($rank < 10) ? ' ' : '']);
		last if (!$_qstats_ranks && ($place == $num));
		$place++;
	}
	return if ($num != -1);
	$place = 1;
	my @nicks;
	foreach my $player (sort {
						$quiz{players}{$a}{besttime} <=> $quiz{players}{$b}{besttime} or
						$quiz{players}{$a}{timestamp} <=> $quiz{players}{$b}{timestamp}
					} keys %{$quiz{players}}) {
		push(@nicks, get_format('quiz_inc_scores_record', [$place, $quiz{players}{$player}{nick}, $quiz{players}{$player}{besttime}]));
		last if (++$place > $_qstats_records);
	}
	send_irc('quiz_msg_scores_times', join(', ', @nicks)) if (@nicks);
	$place = 1;
	@nicks = ();
	foreach my $player (sort {
						$quiz{players}{$b}{bestspeed} <=> $quiz{players}{$a}{bestspeed} or
						$quiz{players}{$a}{timestamp} <=> $quiz{players}{$b}{timestamp}
					} keys %{$quiz{players}}) {
		push(@nicks, get_format('quiz_inc_scores_record', [$place, $quiz{players}{$player}{nick}, $quiz{players}{$player}{bestspeed}]));
		last if (++$place > $_qstats_records);
	}
	send_irc('quiz_msg_scores_speeds', join(', ', @nicks)) if (@nicks);
}

sub cmd_delay {
	my $delay = shift;
	send_ui('quiz_err_delay'), return if (($delay !~ /^\d+$/) || ($delay < 1));
	my $type = $quiz{ison} ? $quiz{type} : settings_get_int('quiz_type');
	settings_set_int('quiz_delay' . ((($type == QT_FAM) || ($type == QT_MUL)) ? '_long' : ''), $delay);
	if ($quiz{ison}) {
		send_irc('quiz_msg_delay', $delay);
	} else {
		send_ui('quiz_inf_delay', $delay);
	}
}

sub cmd_time {
	#?send_ui('quiz_err_na'), return if (($quiz{type} != QT_FAM) && ($quiz{type} != QT_MUL));
	my $duration = shift;
	send_ui('quiz_err_duration'), return if (($duration !~ /^\d+$/) || ($duration < 1));
	settings_set_int('quiz_timeout', $duration);
	if ($quiz{ison}) {
		send_irc('quiz_msg_duration', $duration);
	} else {
		send_ui('quiz_inf_duration', $duration);
	}
}

sub cmd_teams {
	#?send_ui('quiz_err_na'), return if (($quiz{type} != QT_FAM) && ($quiz{type} != QT_MUL));
	my $teams = shift;
	send_ui('quiz_err_ison'), return if ($quiz{ison});
	send_ui('quiz_err_teams'), return if (($teams !~ /^\d+$/) || ($teams < 2) || ($teams > $_max_teams));
	settings_set_int('quiz_teams', $teams);
	send_ui('quiz_inf_teams', $teams);
}

sub cmd_type {
	send_ui('quiz_err_ison'), return if ($quiz{ison});
	my $type = shift;
	if ($type ne '') {
		$type = name_to_type($type);
		send_ui('quiz_err_type'), return if (!$type || ($type < 1) || ($type > $_quiz_types));
	} else {
		$type = (settings_get_int('quiz_type') % $_quiz_types) + 1;
	}
	settings_set_int('quiz_type', $type);
	send_ui('quiz_inf_type', ('Dizzy', 'Mieszacz/Literaki', 'Familiada', 'Multi (Familiada bez druzyn)', 'Pomieszany')[$type - 1]);
}

sub cmd_skip {
	send_ui('quiz_err_isoff'), return if (!$quiz{ison});
	send_ui('quiz_err_noquestion'), return if (!$quiz{inq});
	stop_question();
	init_next_question(get_format('quiz_msg_skipped'));
}

sub cmd_pause {
	send_ui('quiz_err_isoff'), return if (!$quiz{ison} || $quiz{standby});
	if ($quiz{wantpause}) {		# second pause request during question - cancel
		$quiz{wantpause} = 0;
		send_ui('quiz_inf_wontpause');
	} elsif ($quiz{paused}) {	# unpause quiz
		$quiz{paused} = 0;
		evt_show_question();
	} elsif ($quiz{inq}) {		# pause request during question
		$quiz{wantpause} = 1;
		send_ui('quiz_inf_wantpause');
	} else {					# pause request between questions
		stop_timer('tnext');
		$quiz{paused} = 1;
		send_irc('quiz_msg_paused');
	}
}

sub cmd_hint {
	send_ui('quiz_err_isoff'), return if (!$quiz{ison});
	send_ui('quiz_err_na'), return if (($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL));
	send_ui('quiz_err_noquestion'), return if (!$quiz{inq});
	send_irc('quiz_msg_hint', make_hint());
}

sub cmd_remind {
	send_ui('quiz_err_isoff'), return if (!$quiz{ison});
	send_ui('quiz_err_na'), return if (($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL));
	send_ui('quiz_err_noquestion'), return if (!$quiz{inq});
	my @lines = make_remind();
	my $line = 1;
	foreach my $text (@lines) {
		if ($line++ == 1) {
			send_irc('quiz_msg_remind', get_format('quiz_inc_question', $text));
		} else {
			send_irc('quiz_inc_question', $text);
		}
	}
}

sub cmd_stop {
	send_ui('quiz_err_isoff'), return if (!$quiz{ison});
	stop_quiz();
	send_irc('quiz_msg_stop1');
	send_irc('quiz_msg_stop2', [$quiz{qnum}, time_str(time() - $quiz{stime}, TIME_HMS)]);
}

sub cmd_init {
	settings_set_int($_, $settings_int{$_}) for (keys %settings_int);
	settings_set_bool($_, $settings_bool{$_}) for (keys %settings_bool);
	settings_set_str($_, $settings_str{$_}) for (keys %settings_str);
	send_ui('quiz_inf_reset');
}

sub cmd_reload {
	send_ui('quiz_err_isoff'), return if (!$quiz{ison});
	my $cnt = $quiz{qcnt};
	my $lines = load_quiz($quiz{file});
	if (is_valid_quiz($lines)) {
		send_ui(($quiz{qcnt} != $cnt) ? 'quiz_wrn_reload' : 'quiz_inf_reload');
		if ((($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) && $quiz{inq}) {
			%{$quiz{lookup}} = map { lc($_) => $_ } keys %{$quiz{data}[$quiz{qnum}]{answers}};
		}
	} else {
		stop_quiz();
		send_irc('quiz_msg_stop1');
		send_irc('quiz_msg_stop2', [$quiz{qnum}, time_str(time() - $quiz{stime}, TIME_HMS)]);
		send_ui('quiz_err_file', $quiz{file});
	}
}

sub cmd_ignore {
	send_ui('quiz_err_isoff'), return if (!defined $quiz{chan});
	my $who = shift;
	$who =~ s/^ +| +$//g; # trim leading/trailing spaces (nick autocompletion)
	my $r_nick = $quiz{chan}->nick_find($who);
	send_ui('quiz_err_nonick', $who, $quiz{chan}{name}), return if (!$r_nick);
	my ($nick, $addr) = ($r_nick->{nick}, $r_nick->{host});
	if (exists($quiz{ignored}{$addr})) {
		send_irc('quiz_msg_unignored', $quiz{ignored}{$addr});
		delete $quiz{ignored}{$addr};
	} else {
		send_irc('quiz_msg_ignored', $nick);
		$quiz{ignored}{$addr} = $nick;
	}
}

sub cmd_help {
	show_help(shift);
}

sub cmd_irssi_help {
	my $cmd = shift;
	if ($cmd =~ /^i?quiz(?: (.+))?$/) {
		show_help($1 || '');
		signal_stop();
	}
}

##### Timers' events #####
sub evt_delayed_show_msg {
	my ($msg) = @_;
	signal_emit('message own_public', $quiz{chan}{server}, $msg, $quiz{chan}{name});
}

sub evt_delayed_show_notc {
	my $ref = shift;
	my ($msg, $nick) = @{$ref};
	signal_emit('message irc own_notice', $quiz{chan}{server}, $msg, $nick);
}

sub evt_delayed_load_info {
	send_ui('quiz_inf_start');
}

sub evt_show_question {
	$quiz{qtime} = time();
	$quiz{qnum}++;
	my $suffix = '';
	if ($quiz{type} == QT_MIX) {
		$suffix = '_x';
	} elsif (($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) {
		%{$quiz{lookup}} = map { lc($_) => $_ } keys %{$quiz{data}[$quiz{qnum}]{answers}};
		$suffix = '_fm';
	}
	my $duration = abs(settings_get_int('quiz_timeout')) || $_round_duration; # abs in case of <0, || in case of ==0
	my @lines = make_remind();
	my $line = 1;
	foreach my $text (@lines) {
		if ($line++ == 1) {
			my $answers = keys %{$quiz{lookup}};
			send_irc('quiz_msg_question' . $suffix, [
				$quiz{qnum}, $quiz{qcnt},
				get_format('quiz_inc_question', $text),
				$answers, answers_str($answers),
				$duration], INSTANT);
		} else {
			send_irc('quiz_inc_question', $text, INSTANT); #? not INSTANT?
		}
	}
	if (($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) {
		$quiz{tround} = timeout_add_once($duration * 1000, 'evt_round_timeout', undef);
		if (($_round_warn_time > 0) && ($duration > $_round_warn_time * $_round_warn_coeff)) {
			$quiz{twarn} = timeout_add_once(($duration - $_round_warn_time) * 1000, 'evt_round_timeout_warn', undef);
		}
	} else {
		send_irc('quiz_msg_hint', make_hint()) if (settings_get_bool('quiz_show_first_hint'));
		my $delay = settings_get_int('quiz_first_anticheat_delay');
		if ($delay > 0) {
			@quiz{qw/hprot rprot/} = (1) x 2;
			$quiz{thint} = timeout_add_once($delay * 1000, sub { $quiz{hprot} = 0 }, undef);
			$quiz{tremind} = timeout_add_once($delay * 1000, sub { $quiz{rprot} = 0 }, undef);
		}
		if (settings_get_bool('quiz_autohinter')) {
			$delay = abs(settings_get_int('quiz_hints_interval')) || $_hints_interval; # abs in case of <0, || in case of ==0
			$quiz{thinter} = timeout_add_once($delay * 1000, 'evt_show_hint', undef);
		}
	}
	$quiz{inq} = 1;
}

sub evt_round_timeout_warn {
	send_irc('quiz_msg_warn_timeout', $_round_warn_time);
}

sub evt_round_timeout {
	stop_question();
	init_next_question(get_format('quiz_msg_timeout')); #? INSTANT?
}

sub evt_show_hint {
	show_hint();
}

sub evt_stop_bonus {
	stop_question();
}

##### User interaction - responses / handlers #####
sub show_score {
	my ($nick, $addr, $who) = @_;
	if ($who && (lc($nick) ne lc($who))) {
		my $found = 0;
		foreach my $player (keys %{$quiz{players}}) {
			if (lc($quiz{players}{$player}{nick}) eq lc($who)) {
				send_irc('quiz_msg_score_other', [$quiz{players}{$player}{nick}, $quiz{players}{$player}{score}, score_str($quiz{players}{$player}{score})]);
				$found++;
				last;
			}
		}
		send_irc('quiz_msg_noscore_other', $who) if (!$found);
	} else {
		if (exists $quiz{players}{$addr}) {
			send_irc('quiz_msg_score', [$nick, $quiz{players}{$addr}{score}, score_str($quiz{players}{$addr}{score})]);
		} else {
			send_irc('quiz_msg_noscore', $nick);
		}
	}
}

sub join_team {
	my ($nick, $addr, $team) = @_;
	return unless (($quiz{type} == QT_FAM) && (settings_get_bool('quiz_join_anytime') || $quiz{standby}));
	return if (($team < 1) || ($team > $quiz{tcnt}));
	my ($time, $from) = (time(), 0);
	if (exists $quiz{players}{$addr}) {
		$from = exists($quiz{players}{$addr}{team}) ? $quiz{players}{$addr}{team} : 0;
		return if ($from == $team);
		if (settings_get_bool('quiz_transfer_points')) {
			my ($score, $answers) = @{$quiz{players}{$addr}}{qw/score answers/};
			$quiz{teams}[$from]{score} -= $score;	$quiz{teams}[$from]{answers} -= $answers;
			$quiz{teams}[$team]{score} += $score;	$quiz{teams}[$team]{answers} += $answers;
		}
	} else {
		@{$quiz{players}{$addr}}{qw/nick timestamp/} = ($nick, $time);
		@{$quiz{players}{$addr}}{qw/score answers besttime alltime bestspeed allspeed/} = (0) x 6;
	}
	@{$quiz{players}{$addr}}{qw/team joined/} = ($team, $time);
	my @teams;
	push(@{$teams[$quiz{players}{$_}{team}]}, get_format('quiz_inc_team_nick', $quiz{players}{$_}{nick})) for (sort { $quiz{players}{$a}{joined} <=> $quiz{players}{$b}{joined} } keys %{$quiz{players}});
	send_irc('quiz_msg_team_' . (($from != 0) ? 'change' : 'join'), [$team, join($_team_separator, @{$teams[$team]})], WHISPER, $nick) if (defined $teams[$team]);
}

sub show_hint {
	return if ($quiz{hprot} || ($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL) || !settings_get_bool('quiz_cmd_hint'));
	my $hints_limit = settings_get_int('quiz_max_hints');
	make_hint(PREPDOTS) if (($quiz{hnum} == 0) && ($hints_limit < 0));
	return unless (($quiz{hnum} == 0) || !$_no_hints_spam || ($quiz{dcnt} > 0));
	if (($hints_limit == 0) ||
		(($hints_limit > 0) && ($quiz{hnum} < $hints_limit)) ||
		(($hints_limit < 0) && ($quiz{dmax} > abs($hints_limit)))) {
			send_irc('quiz_msg_hint', make_hint());
			my $delay = settings_get_int('quiz_anticheat_delay');
			if ($delay > 0) {
				$quiz{hprot} = 1;
				$quiz{thint} = timeout_add_once($delay * 1000, sub { $quiz{hprot} = 0 }, undef);
			}
	}
	if (settings_get_bool('quiz_autohinter')) {
		stop_timer('thinter');
		my $delay = abs(settings_get_int('quiz_hints_interval')) || $_hints_interval; # abs in case of <0, || in case of ==0
		$quiz{thinter} = timeout_add_once($delay * 1000, 'evt_show_hint', undef);
	}
}

sub show_remind {
	return if ($quiz{rprot} || !settings_get_bool('quiz_cmd_remind'));
	my @lines = make_remind();
	my $line = 1;
	foreach my $text (@lines) {
		if ($line++ == 1) {
			send_irc('quiz_msg_remind', get_format('quiz_inc_question', $text));
		} else {
			send_irc('quiz_inc_question', $text);
		}
	}
	my $delay = settings_get_int('quiz_anticheat_delay');
	if ($delay > 0) {
		$quiz{rprot} = 1;
		$quiz{tremind} = timeout_add_once($delay * 1000, sub { $quiz{rprot} = 0 }, undef);
	}
}

sub check_answer {
	my ($nick, $addr, $answer) = @_;
	if (($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) {
		return unless (exists($quiz{lookup}{lc $answer}) &&
						($quiz{data}[$quiz{qnum}]{answers}{$quiz{lookup}{lc $answer}} > 0));
		return unless (($quiz{type} == QT_MUL) || !settings_get_bool('quiz_team_play') ||
						(exists($quiz{players}{$addr}) && exists($quiz{players}{$addr}{team}) && ($quiz{players}{$addr}{team} != 0))); # last condition: for non team players there is no record yet // autovivification...
		my ($time, $match) = (time(), $quiz{lookup}{lc $answer});
		my $answers = keys %{$quiz{data}[$quiz{qnum}]{answers}};
		my $id = $quiz{data}[$quiz{qnum}]{answers}{$match};
		my $value = $answers - $id + 1;
		my $points = settings_get_int('quiz_points_per_answer'); # ppa
		my $min = settings_get_int('quiz_min_points');
		my $max = settings_get_int('quiz_max_points');
		my $mode = settings_get_int('quiz_scoring_mode');
		if ($mode == 2) { # ppa++
			$points *= $value;
		} elsif ($mode == 3) { # ppa++:max
			$points *= $value;
			$points = $max if ($points > $max);
		} elsif ($mode == 4) { # min++ppa
			($points *= $value - 1) += $min;
		} elsif ($mode == 5) { # min++ppa:max
			($points *= $value - 1) += $min;
			$points = $max if ($points > $max);
		} elsif ($mode == 6) { # max--ppa:min
			$points = $max - $points * ($id - 1);
			$points = $min if ($points < $min);
		} elsif ($mode == 7) { # max->min
			$points = int(($value - 1) * ($max - $min) / ($answers - 1) + $min + 0.5);
		#} elsif ($mode == 8) { # max%:min
		#	$points = int($max * $value / $answers + 0.5);
		#	$points = $min if ($points < $min);
		}
		correct_answer($addr, $nick, $time, $points, $answer);
		send_irc('quiz_msg_congrats', [
			$nick,
			($points == 1) ? get_format('quiz_inc_got_point', score_str($points)) : get_format('quiz_inc_got_points', [$points, score_str($points)]),
			$match,
			$time - $quiz{qtime},
			length($answer) / ($time - $quiz{qtime}),
			$quiz{players}{$addr}{score}]);
		$quiz{data}[$quiz{qnum}]{answers}{$match} *= -1;
		if (!grep { $_ > 0 } values %{$quiz{data}[$quiz{qnum}]{answers}}) {
			stop_question();
			init_next_question(get_format('quiz_msg_all_answers')); #? not INSTANT
		}
	} else {
		return unless ((lc($answer) eq lc($quiz{data}[$quiz{qnum}]{answer})) ||
			(!settings_get_bool('quiz_strict_match') && (index(lc $answer, lc $quiz{data}[$quiz{qnum}]{answer}) >= 0)));
		my ($time, $points) = (time(), settings_get_int('quiz_points_per_' . ($quiz{bonus} ? 'bonus' : 'answer')));
		my $limit = int($quiz{qcnt} * 0.5 + 1) * $points; # 50%+1
		my $limiter = settings_get_bool('quiz_limiter');
		return unless (!$limiter || !exists($quiz{players}{$addr}) || ($quiz{players}{$addr}{score} < $limit));
		return if ($quiz{bonus} && ($quiz{lastone} eq "$nick!$addr")); # prevents bonus duplication
		$quiz{lastone} = "$nick!$addr";
		correct_answer($addr, $nick, $time, $points, $answer);
		my $bonus = 0;
		if (settings_get_bool('quiz_bonus_answer')) {
			if ($quiz{bonus}) {
				stop_question();
				$bonus = 1;
			} else {
				stop_timer('thinter');
				@quiz{qw/hprot rprot/} = (1) x 2; # just in case
				$quiz{tbonus} = timeout_add_once($_bonus_delay, 'evt_stop_bonus', undef);
				$quiz{bonus} = 1;
			}
		} else {
			stop_question();
		}
		init_next_question(get_format('quiz_msg_congrats' . ($bonus ? '_bonus' : ''), [
			$nick,
			($points == 1) ? get_format('quiz_inc_got_point', score_str($points)) : get_format('quiz_inc_got_points', [$points, score_str($points)]),
			$quiz{data}[$quiz{qnum}]{answer},
			$time - $quiz{qtime},
			length($answer) / ($time - $quiz{qtime}),
			$quiz{players}{$addr}{score}]) . (($limiter && ($quiz{players}{$addr}{score} >= $limit)) ? ' ' . get_format('quiz_sfx_limit') : ''), INSTANT | ($bonus ? BONUS : 0));
	}
}

##### Signals' handlers #####
sub sig_pubmsg {
	my ($r_server, $msg, $nick, $addr, $target) = @_;
	return if (!$quiz{ison} || (lc($r_server->{tag}) ne lc($quiz{chan}{server}{tag})) || (lc($target) ne lc($quiz{chan}{name})) || exists($quiz{ignored}{$addr}));
	for ($msg) { # cleanup
		tr/\t/ /;			# tabs to spaces
		s/ {2,}/ /g;		# fix double spaces
		s/^ +| +$//g;		# trim leading/trailing spaces
		s/\002|\003(?:\d{1,2}(?:,\d{1,2})?)?|\017|\026|\037//g;		# remove formatting
		# \002 - bold  \003$fg(,$bg)? - color  \017 - plain  \026 - reverse  \037 - underline
	}
	return if ($msg eq '');
	my @cmds = split(/\t/, l10n({	pl => '!podp	!przyp	!pyt	!ile	!join',
									en => '!hint	!remind	!remind	!score	!join'}));
	show_score($nick, $addr, $1) if ($msg =~ /^$cmds[3](?:\s+([^\s]+))?/i);
	return if ($quiz{ended} && !$quiz{bonus});
	join_team($nick, $addr, $1) if ($msg =~ /^$cmds[4]\s+(\d)$/i);
	return if (!$quiz{inq});
	my $lmsg = lc $msg;
	if ($lmsg eq $cmds[0]) {
		show_hint();
	} elsif (($lmsg eq $cmds[1]) || ($lmsg eq $cmds[2])) {
		show_remind();
	}
	check_answer($nick, $addr, asciize($msg));
}

sub sig_config_changed {
	my $lang = lc settings_get_str('quiz_lang');
	$lang = 'pl' if (($lang ne 'pl') && ($lang ne 'en')); # fallback
	$quiz{lang} = $lang;
}

##### Bind user commands #####
command_bind('help',	'cmd_irssi_help');
command_bind('quiz',	'cmd_help');
command_bind('qtype',	'cmd_type');
command_bind('qteams',	'cmd_teams');
command_bind('qon',		'cmd_start');
command_bind('qdelay',	'cmd_delay');
command_bind('qtime',	'cmd_time');
command_bind('qhint',	'cmd_hint');
command_bind('qremind',	'cmd_remind');
command_bind('qskip',	'cmd_skip');
command_bind('qpause',	'cmd_pause');
command_bind('qignore',	'cmd_ignore');
command_bind('qstats',	'cmd_stats');
command_bind('qoff',	'cmd_stop');
command_bind('qreload',	'cmd_reload');
command_bind('qinit',	'cmd_init');

##### Create user settings #####
settings_add_int($IRSSI{name}, $_, $settings_int{$_}) for (keys %settings_int);
settings_add_bool($IRSSI{name}, $_, $settings_bool{$_}) for (keys %settings_bool);
settings_add_str($IRSSI{name}, $_, $settings_str{$_}) for (keys %settings_str);

##### Initialization #####
sig_config_changed();
signal_add_last('setup changed', 'sig_config_changed');
timeout_add_once($_display_delay, 'evt_delayed_load_info', undef); # le trick (workaround for info showing before script load message)
