##################################################################
##    irssi Quiz (iQuiz) script (2010-2016) by wilk/xorandor    ##
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
# - standard Dizzy/Pomieszany files (also without "pyt"/"odp" prefixes):
#
# pyt Evaluate: 2+2=?
# odp four
# pyt Star closest to Earth?
# odp Sun
# ...
#
# - standard Mieszacz files (also without line numbers):
#
# 1 alpha
# 2 beta
# 3 gamma
# 4 delta
# ...
#
# - standard Familiada files (can have any number of answers per question, used also for Multi):
#
# Planets of our Solar System:
# Mercury*Venus*Earth*Mars*Jupiter*Saturn*Uranus*Neptune
# First six alkanes:
# methane*ethane*propane*butane*pentane*hexane
# ...

# >>> To view all available commands and settings type: /quiz

# only core modules
use strict;
use warnings;
use Irssi qw(theme_register current_theme command_bind settings_add_int settings_add_bool settings_add_str settings_get_int settings_get_bool settings_get_str settings_set_int settings_set_bool settings_set_str printformat timeout_add_once timeout_remove signal_add_last signal_remove signal_stop signal_emit active_win);
use Time::HiRes qw(time);
use constant { QT_STD => 1, QT_MIX => 2, QT_FAM => 3, QT_MUL => 4, QT_SCR => 5 }; # QT_MIL => 6, QT_FOR => 7

our $VERSION = '160919';
our %IRSSI = (
	authors			=> 'wilk',
	name			=> 'iQuiz',
	description		=> 'irssi quiz script', # one script to bind them all
	license			=> 'GNU GPL v3 or any later version',
	changed			=> (($VERSION =~ /^(\d\d)(\d\d)(\d\d)/) ? "20$1-$2-$3" : $VERSION),
	url				=> 'http://iquiz.quizpl.net',
	contact			=> 'http://mail.quizpl.net',
	changes			=> 'see http://www.quizpl.net/viewtopic.php?f=3&t=404',
	usage			=> 'see http://www.quizpl.net/viewtopic.php?f=3&t=587'
);

##### Hardcoded settings #####
my $_display_delay = 100;			# msec; workaround for display issue (response before request)
my $_start_delay = 5000;			# msec; delay between /qon and showing first question (or 0)
my $_standby_delay = 1000;			# msec; delay between /qon and showing first question (or 0) while on standby
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
my $_qstats_records = 5;			# int; number of time/speed record places in /qstats

my $_next_delay = 10;				# sec; default delay between questions
my $_next_delay_long = 20;			# sec; default delay between questions (fam/mul) (longer delay to prevent flooding and give a breath)
my $_round_duration = 90;			# sec; default round duration
my $_hint_alpha = '.';				# char; default substitution symbol for alphabet characters in hints (special characters are left intact)
my $_hint_digit = '.';				# char; default substitution symbol for digit characters in hints (special characters are left intact)

my $_quiz_types = 5;				# (do not change)

##### Internal stuff #####
use constant { T_HMS => 0, T_S => 1, T_MS => 2 }; # 0: h/m/s, 1: s only, 2: s.ms
use constant { INSTANT => 1, PREPDOTS => 1, V_INT => 1, V_BOOL => 2, V_STR => 3 };

my %quiz = (
	chan => undef, file => '',
	type => 0, tcnt => 0, # copies just in case someone modifies settings directly while quiz is running
	ison => 0, inq => 0, standby => 0,
	stime => 0, qtime => 0,
	qcnt => 0, qnum => 0, hnum => 0,
	score => 0, answers => 0,
	tnext => undef, tround => undef, thint => undef, tremind => undef, twarn => undef,
	hprot => 0, rprot => 0,
	data => [],		# data[]{question realquestion answer answers{}}
	teams => [],	# teams[]{score answers}
	players => {},	# players{}{nick timestamp score answers team besttime alltime bestspeed allspeed}
	lookup => {}, dcnt => 0, dmax => 0, lmax => 0, dots => [], hwords => []
);

my %settings_int = (
	'quiz_type' => 1,
	'quiz_teams' => 2,
	'quiz_delay' => $_next_delay,
	'quiz_delay_long' => $_next_delay_long,
	'quiz_round_duration' => $_round_duration,
	'quiz_max_hints' => 0,
	'quiz_words_style' => 0,
	'quiz_anticheat_delay' => 3,
	'quiz_first_anticheat_delay' => 7,
	'quiz_points_per_answer' => 1,
	'quiz_min_points' => 1,
	'quiz_max_points' => 50,
	'quiz_scoring_mode' => 4,
	'quiz_ranking_type' => 3,
);

my %settings_bool = (
	'quiz_antigoogler' => 1,
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
	'quiz_keep_scores' => 0,
	'quiz_cmd_hint' => 1,
	'quiz_cmd_remind' => 1,
);

my %settings_str = (
	'quiz_hint_alpha' => $_hint_alpha,
	'quiz_hint_digit' => $_hint_digit,
	'quiz_smart_mix_chars' => '\d()",.;:?!',
);

##### Theme (only channel messages are localized by default, feel free to customize here or via /format, except authorship) #####
# quiz_inf_*, quiz_wrn_* & quiz_err_* messages are irssi only	- use irssi formatting and irssi color codes
# quiz_msg_* messages are sent on channel						- use sprintf formatting and mIRC color codes:
# \002 - bold  \003$fg(,$bg)? - color  \017 - plain  \026 - reverse  \037 - underline
# quiz_inc_* - not sent directly, used as inclusions
# quiz_flx_* - not sent directly, words' inflections
# Important: To prevent visual glitches use two digit color codes! i.e. \00304 instead of \0034
theme_register([
	'quiz_inf_start',		'%_iQuiz:%_ Aby uzyskac pomoc wpisz: /quiz',
	'quiz_inf_delay',		'%_iQuiz:%_ %gZmieniono opoznienie miedzy pytaniami na: %_$0%_ sek.%n',
	'quiz_inf_duration',	'%_iQuiz:%_ %gZmieniono czas trwania rundy na: %_$0%_ sek.%n',
	'quiz_inf_type',		'%_iQuiz:%_ %gZmieniono tryb gry na: %_$0%_%n',
	'quiz_inf_teams',		'%_iQuiz:%_ %gZmieniono liczbe druzyn na: %_$0%_%n',
	'quiz_inf_reset',		'%_iQuiz:%_ %gWszystkie ustawienia zostaly przywrocone do poczatkowych wartosci%n',
	'quiz_inf_reload',		'%_iQuiz:%_ %gPlik z pytaniami zostal ponownie wczytany%n',

	'quiz_wrn_reload',		'%_iQuiz:%_ %YZmienila sie liczba pytan (po ponownym wczytaniu)%n',

	'quiz_err_ison',		'%_iQuiz:%_ %RQuiz jest juz uruchomiony%n',
	'quiz_err_isoff',		'%_iQuiz:%_ %RQuiz nie jest uruchomiony%n',
	'quiz_err_server',		'%_iQuiz:%_ %RBrak polaczenia z serwerem%n',
	'quiz_err_channel',		'%_iQuiz:%_ %RBledna nazwa kanalu%n',
	'quiz_err_nochannel',	'%_iQuiz:%_ %RKanal "$0" nie jest otwarty%n',
	'quiz_err_filename',	'%_iQuiz:%_ %RBledna nazwa pliku%n',
	'quiz_err_nofile',		'%_iQuiz:%_ %RPlik "$0" nie zostal odnaleziony%n',
	'quiz_err_file',		'%_iQuiz:%_ %RPlik "$0" wydaje sie byc uszkodzony%n',
	'quiz_err_argument',	'%_iQuiz:%_ %RBledny parametr polecenia%n',
	'quiz_err_noquestion',	'%_iQuiz:%_ %RPoczekaj az pytanie zostanie zadane%n',
	'quiz_err_type',		'%_iQuiz:%_ %RBledny tryb gry%n',
	'quiz_err_delay',		'%_iQuiz:%_ %RBledna wartosc opoznienia miedzy pytaniami%n',
	'quiz_err_duration',	'%_iQuiz:%_ %RBledna wartosc czasu trwania rundy%n',
	'quiz_err_teams',		'%_iQuiz:%_ %RBledna liczba druzyn%n',
	'quiz_err_ranking',		'%_iQuiz:%_ %RBledna liczba graczy%n',
	'quiz_err_na',			'%_iQuiz:%_ %RTa funkcja jest niedostepna przy obecnych ustawieniach%n',

	'quiz_msg',						'%s', # custom text
	'quiz_msg_start1',				"\00303>>> \00310iQuiz by wilk wystartowal \00303<<<",
	'quiz_msg_start2',				"\00303Polecenia: !podp, !przyp, !ile, !ile nick",
	'quiz_msg_start2_f',			"\00303Polecenia: !przyp, !ile, !ile nick, !join 1-%u", # 1: max teams
	'quiz_msg_start2_m',			"\00303Polecenia: !przyp, !ile, !ile nick",
	'quiz_msg_stop1',				"\00303>>> \00310iQuiz by wilk zakonczony \00303<<<",
	'quiz_msg_stop2',				"\00303Liczba rund: \00304%u \00303Czas gry: \00304%s", # 1: round, 2: time_str (hms)
	'quiz_msg_question',			"\00303\037Pytanie %u/%u:\037 %s", # see below
	'quiz_msg_question_x',			"\00303\037Haslo %u/%u:\037 %s", # see below
	'quiz_msg_question_fm',			"\00303\037Pytanie %u/%u:\037 %s \00303(\00313%u\00303 %s, czas: %u sek.)", # 1: round, 2: rounds, 3: question (quiz_inc_question), 4: answers, 5: quiz_flx_answers, 6: round time (s)
	'quiz_inc_question',			"\00300,01 %s \017", # 1: question (antygoogler takes first color code to harden question - must use background color if using antigoogler; if any color is used finish with "\017" to reset it)
	'quiz_msg_hint',				"\00303Podpowiedz: \00304%s", # 1: hint
	'quiz_inc_hint_alpha',			"\00310%s\00304", # 1: symbol (color codes are used to distinguish between hidden letter and real dot, but you may omit them)
	'quiz_inc_hint_digit',			"\00310%s\00304", # 1: symbol (same as above)
	'quiz_msg_remind',				"\00303Przypomnienie: %s", # 1: question (quiz_inc_question)
	'quiz_msg_delay',				"\00303Opoznienie miedzy pytaniami: \00304%u\00303 sek.", # 1: time (s)
	'quiz_msg_duration',			"\00303Czas trwania rundy: \00304%u\00303 sek.", # 1: time (s)
	'quiz_msg_score',				"\00304%s\00303\002\002, zdobyles(as) jak dotad \00304%d\00303 %s.", # 1: nick, 2: score, 3: quiz_flx_points
	'quiz_msg_noscore',				"\00304%s\00303\002\002, nie zdobyles(as) jeszcze zadnego punktu!", # 1: nick
	'quiz_msg_score_other',			"\00304%s\00303 zdobyl(a) jak dotad \00304%d\00303 %s.", # see quiz_msg_score
	'quiz_msg_noscore_other',		"\00304%s\00303 nie zdobyl(a) jeszcze zadnego punktu!", # 1: nick
	'quiz_msg_noscores',			"\00303Tablica wynikow jest jeszcze pusta.",
	'quiz_msg_scores',				"\00303Wyniki quizu po %s i %u %s:", # 1: time_str (hms), 2: question, 3: quiz_flx_questions, 4: questions (total), 5: quiz_flx_questions (total)
	'quiz_msg_scores_place',		"\00303%u. miejsce: \00304%s\00303 - \00304%d\00303 %s [%.1f%%] (sr. czas zgadywania: %10\$.3f sek.)", # 1: place, 2: nick, 3: score, 4: quiz_flx_points, 5: score%, 6: answers, 7: quiz_flx_answers, 8: answers%, 9: best time, 10: avg time, 11: best speed, 12: avg speed, 13: spacer
	'quiz_msg_scores_place_full',	"\00303%u. miejsce: \00304%s\00303 - \00304%d\00303 %s [%.1f%%] (%u %s, sr. czas zgadywania: %10\$.3f sek.)", # see quiz_msg_scores_place
	'quiz_msg_team_score',			"\00303Druzyna %u (%s): \00304%d\00303 %s", # 1: team, 2: players (comma separated), 3: score, 4: quiz_flx_points, 5: score%, 6: answers, 7: quiz_flx_answers, 8: answers%
	'quiz_msg_team_score_full',		"\00303Druzyna %u (%s): \00304%d\00303 %s (%6\$u %7\$s)", # see quiz_msg_team_score
	'quiz_msg_team_join',			"\00303Dolaczyles(as) do Druzyny %u (%s).", # 1: team, 2: players (comma separated)
	'quiz_inc_team_nick',			"\00307%s\00303", # 1: nick
	'quiz_msg_scores_times',		"\00303Najszybsi (czas): %s", # 1: players (comma separated)
	'quiz_msg_scores_speeds',		"\00303Najszybsi (zn/s): %s", # 1: players (comma separated)
	'quiz_inc_scores_record',		"\00303%u. \00304%s\00303 (%.3f)", # 1: place, 2: nick, 3: time/speed record
	'quiz_msg_congrats',			"\00303Brawo, \00304%s\00303! Dostajesz %s za odpowiedz \00304%s\00303 podana po czasie %.3f sek. (%.3f zn/s) - suma punktow: \00304%d\00303.", # 1: nick, 2: quiz_inc_got_point*, 3: answer, 4: time (ms), 5: speed (chars/s), 6: total score
	'quiz_inc_got_points',			"\00304%d\00303 %s", # 1: points, 2: quiz_flx_points
	'quiz_inc_got_point',			"\00303%s", # 1: quiz_flx_point
	'quiz_inc_hours',				'%u godz.',		# 1: hours
	'quiz_inc_minutes',				'%u min.',		# 1: minutes
	'quiz_inc_seconds',				'%u sek.',		# 1: seconds
	'quiz_inc_seconds_ms',			'%.3f sek.',	# 1: seconds.milliseconds
	'quiz_msg_warn_timeout',		"\00307Uwaga, zostalo jeszcze tylko \00304%u\00307 sek. na odpowiadanie!", # 1: time (s)
	'quiz_msg_all_answers',			"\00303Wszystkie odpowiedzi zostaly odgadniete!",
	'quiz_msg_timeout',				"\00303Czas na odpowiadanie uplynal!",
	'quiz_msg_next',				"\00303Nastepne pytanie za %u sek...", # 1: time (s)
	'quiz_msg_next_x',				"\00303Nastepne haslo za %u sek...", # 1: time (s)
	'quiz_msg_last',				"\00307Koniec pytan!",
	'quiz_msg_skipped',				"\00303Pytanie zostalo pominiete.",
	# 1 point								/ 1 punkt
	# x points								/ x punktow
	# 2-4, x2-x4 points (x != 1)			/ 2-4, x2-x4 punkty (x != 1)
	'quiz_flx_points',				'punkt/punktow/punkty',
	# 1 answer								/ 1 odpowiedz
	# x answers								/ x odpowiedzi
	# 2-4, x2-x4 answers (x != 1)			/ 2-4, x2-x4 odpowiedzi (x != 1)
	'quiz_flx_answers',				'odpowiedz/odpowiedzi/odpowiedzi',
	# after 1 question						/ po 1 pytaniu
	# after x questions						/ po x pytaniach
	# after 2-4, x2-x4 questions (x != 1)	/ po 2-4, x2-x4 pytaniach (x != 1)
	'quiz_flx_aquestions',			'pytaniu/pytaniach/pytaniach',
	# from 1 question						/ z 1 pytania
	# from x questions						/ z x pytan
	# from 2-4, x2-x4 questions (x != 1)	/ z 2-4, x2-x4 pytan (x != 1)
	'quiz_flx_fquestions',			'pytania/pytan/pytan',
]);

##### Support routines #####
sub load_quiz {
	my ($fname, $lines) = (shift, 0);
	$quiz{data} = [];
	$quiz{qcnt} = 0;
	return 0 unless (open(my $fh, $fname));
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

sub get_format {
	my ($format, $args) = @_;
	return sprintf(current_theme()->get_format(__PACKAGE__, $format), ref($args) ? @{$args} : (defined($args) ? $args : ()));
}

sub send_ui {
	my ($format, @rest) = @_;
	printformat(MSGLEVEL_CRAP, $format, @rest);
}

sub send_ui_raw {
	print CLIENTCRAP shift;
}

sub send_irc {
	my (undef, undef, $instant) = @_;
	my $msg = get_format(@_);
	if ($quiz{chan}{server}{connected}) {
		if ($instant) { # instant or queued
			$quiz{chan}{server}->send_raw_now("PRIVMSG $quiz{chan}{name} :$msg");
		} else {
			$quiz{chan}{server}->send_raw("PRIVMSG $quiz{chan}{name} :$msg");
		}
		timeout_add_once($_display_delay, 'evt_delayed_show_msg', $msg); # le trick (workaround for chantext showing after owntext)
	} else {
		send_ui_raw($msg); # this helps when we got disconnected not to lose messages like stats
		send_ui('quiz_err_server');
	}
}

sub send_irc_whisper {
	my (undef, undef, $nick, $instant) = @_;
	my $msg = get_format(@_);
	if ($quiz{chan}{server}{connected}) {
		if ($instant) { # instant or queued
			$quiz{chan}{server}->send_raw_now("NOTICE $nick :$msg");
		} else {
			$quiz{chan}{server}->send_raw("NOTICE $nick :$msg");
		}
		timeout_add_once($_display_delay, 'evt_delayed_show_notc', [$msg, $nick]); # le trick (workaround for chantext showing after owntext)
	} else {
		send_ui_raw($msg); # this helps when we got disconnected not to lose messages like stats
		send_ui('quiz_err_server');
	}
}

sub shuffle_text {
	my ($old, $new, $length) = (shift, '', 0);
	my @old = split(//, $old);
	my @mov;
	my $smart = ($quiz{type} == QT_SCR) ? settings_get_bool('quiz_smart_mix') : 0;
	if ($smart) {
		my $chars = settings_get_str('quiz_smart_mix_chars'); #? quotemeta?
		for (my $i = 0; $i < @old; $i++) {
			if ($old[$i] !~ /^[$chars]$/) { # hypen, apostrophe, math symbols will float
				push(@mov, $i);
				$length++;
			}
		}
		$smart = 0 if ($length == length($old)); # no punctations & digits
	} else {
		$length = length($old);
	}
	return $old if ($length < 2); # skip short (and empty)
	my $watchdog = ($length < $_shuffle_threshold) ? 1 : $_shuffle_watchdog;
	do {
		if ($smart) {
			my @new = @old;
			my @tmp = @mov;
			my $i = 0;
			while (@tmp) {
				$i++ while (!grep { $_ == $i } @mov);
				my $j = splice(@tmp, int(rand(@tmp)), 1);
				$new[$i++] = $old[$j];
			}
			$new = join('', @new);
		} else {
			my @tmp = @old;
			$new = '';
			$new .= splice(@tmp, int(rand(@tmp)), 1) while (@tmp);
		}
	} until (($old ne $new) || (--$watchdog <= 0));
	return $new;
}

sub shuffle {
	my ($text, $style) = (shift, settings_get_int('quiz_words_style'));
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
			my $duration = abs(settings_get_int('quiz_round_duration')) || $_round_duration; # abs in case of <0, || in case of ==0
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
		@quiz{qw/dcnt dmax lmax/} = (0) x 3;
		my ($w, $dmax) = (0) x 2;
		foreach my $word (@words) {
			$quiz{lmax} = length($word) if (length($word) > $quiz{lmax});
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
		my $random_but_first = settings_get_bool('quiz_nonrandom_first_hint') && ($quiz{hnum} == ($first_dots ? 2 : 1));
		my ($w, $dmax) = (0) x 2;
		foreach my $r_wdots (@{$quiz{dots}}) {
			if ((ref $r_wdots) && (@$r_wdots > 0)) {
				my @letters = split(//, $words[$w]);
				my @hletters = split(//, $quiz{hwords}[$w]);
				my $sel = (!$random_hints || $random_but_first) ? 0 : int(rand(@$r_wdots));
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
	if ($mode == T_HMS) {
		$h = int($s / 3600);
		$m = int($s / 60) % 60;
		$s %= 60;
	}
	my $str = '';
	$str .= get_format('quiz_inc_hours', $h) . ' ' if ($h);
	$str .= get_format('quiz_inc_minutes', $m) . ' ' if ($m);
	$str .= get_format('quiz_inc_seconds' . (($mode == T_MS) ? '_ms' : ''), $s) if ($s || (!$h && !$m));
	$str =~ s/ $//;
	return $str;
}

sub flex {
	my ($value, $format, $flex) = (abs(shift), shift, 0);
	my @flex = split(/\//, get_format($format));
	if ($value != 1) {
		$flex++;
		$flex++ if ($value =~ /^[2-4]$|[^1][2-4]$/);
	}
	return defined($flex[$flex]) ? $flex[$flex] : '???'; # just a precaution
}

sub score_str		{ return flex(shift, 'quiz_flx_points'); }		# X points
sub answers_str		{ return flex(shift, 'quiz_flx_answers'); }		# X answers
sub aquestions_str	{ return flex(shift, 'quiz_flx_aquestions'); }	# after X questions <- AFTER!
sub fquestions_str	{ return flex(shift, 'quiz_flx_fquestions'); }	# from X questions <- FROM!

sub percents {
	my ($val, $of) = @_;
	return ($of == 0) ? 0 : $val / $of * 100;
}

sub stop_timer {
	my $timer = shift;
	if ($quiz{$timer}) {
		timeout_remove($quiz{$timer});
		$quiz{$timer} = undef;
	}
}

sub stop_question {
	@quiz{qw/inq hnum hprot rprot dcnt dmax lmax/} = (0) x 7;
	stop_timer($_) foreach (qw/tround thint tremind twarn/);
	$quiz{dots} = [];
	$quiz{hwords} = [];
	$quiz{lookup} = {};
}

sub stop_quiz {
	stop_question();
	@quiz{qw/ison standby/} = (0) x 2;
	stop_timer('tnext');
	signal_remove('message public', 'sig_pubmsg');
}

sub init_first_question {
	my $delay = shift;
	if ($delay > 0) {
		$quiz{tnext} = timeout_add_once($delay, 'evt_next_question', undef);
	} else {
		evt_next_question();
	}
}

sub init_next_question {
	my ($msg, $instant) = @_;
	if ($quiz{qnum} >= $quiz{qcnt}) {
		send_irc('quiz_msg', $msg . ' ' . get_format('quiz_msg_last'), $instant);
	} else {
		my $delay = abs(settings_get_int('quiz_delay' . ((($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) ? '_long' : ''))); # abs in case of <0
		$delay ||= ((($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) ? $_next_delay_long : $_next_delay); # in case of ==0
		send_irc('quiz_msg', $msg . ' ' . get_format('quiz_msg_next' . (($quiz{type} == QT_MIX) ? '_x' : ''), $delay), $instant);
		$quiz{tnext} = timeout_add_once($delay * 1000, 'evt_next_question', undef);
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

sub is_valid_data {
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
		$quiz{players}{$addr}{team} = 0 if (!exists $quiz{players}{$addr}{team}); # team_play is on and player is an outsider
		my $team = $quiz{players}{$addr}{team};
		$quiz{teams}[$team]{score} += $points;
		$quiz{teams}[$team]{answers}++;
	}
}

sub hcmd {
	return sprintf(' %-37s - ', shift);
}

sub hvar {
	my ($setting, $type) = @_;
	if ($type == V_INT) {
		return sprintf(' %-26s : %-3d - ', $setting, settings_get_int($setting));
	} elsif ($type == V_BOOL) {
		return sprintf(' %-26s : %-3s - ', $setting, settings_get_bool($setting) ? 'on' : 'off');
	} elsif ($type == V_STR) {
		return sprintf(' %-26s : %-3s - ', $setting, settings_get_str($setting));
	}
}

sub show_help {
	send_ui_raw("%_$IRSSI{name}%_ v$VERSION by wilk (quiz obecnie: " . ($quiz{ison} ? ($quiz{standby} ? 'oczekuje na uruchomienie' : 'trwa') : 'jest wylaczony') . ')');
	send_ui_raw('%_Dostepne polecenia:%_');
	send_ui_raw(hcmd("/qtype [1-$_quiz_types/nazwa]") . 'zmiana rodzaju quizu (bez parametru wybiera kolejny)');
	send_ui_raw(hcmd("/qteams <2-$_max_teams>") . 'zmiana liczby druzyn (tylko Familiada)');
	send_ui_raw(hcmd("/qon [kanal] <plik> [1-$_quiz_types/nazwa] [0-$_max_teams]") . 'rozpoczecie quizu; mozna podac rodzaj quizu i liczbe druzyn');
	send_ui_raw(hcmd('/qstats [miejsca]') . 'wyswietla ranking graczy (Familiada: 0 - pokazuje tylko druzyny)');
	send_ui_raw(hcmd('/qhint') . 'wyswietlenie podpowiedzi (nie w Familiadzie/Multi)');
	send_ui_raw(hcmd('/qremind') . 'przypomnienie pytania');
	send_ui_raw(hcmd('/qskip') . 'pominiecie biezacego pytania');
	send_ui_raw(hcmd('/qoff') . 'przerwanie lub zakonczenie quizu');
	send_ui_raw(hcmd('/qdelay <sekundy>') . 'zmiana opoznienia miedzy pytaniami');
	send_ui_raw(hcmd('/qtime <sekundy>') . 'zmiana czasu trwania rundy (tylko Familiada/Multi)');
	send_ui_raw(hcmd('/qreload') . 'ponowne wczytanie pliku z pytaniami');
	send_ui_raw(hcmd('/qinit') . 'resetuje wszystkie ustawienia do wartosci poczatkowych');
	send_ui_raw('%_Dostepne ustawienia (/set):%_');
	send_ui_raw(hvar('quiz_type', V_INT) . 'rodzaj quizu (1: Dizzy, 2: Mieszacz/Literaki, 3: Familiada, 4: Multi (Familiada bez druzyn), 5: Pomieszany)');
	send_ui_raw(hvar('quiz_teams', V_INT) . "liczba druzyn (2-$_max_teams; tylko Familiada)");
	send_ui_raw(hvar('quiz_delay', V_INT) . 'opoznienie miedzy pytaniami (sek.)');
	send_ui_raw(hvar('quiz_delay_long', V_INT) . 'opoznienie miedzy pytaniami (sek.; tylko Familiada/Multi)');
	send_ui_raw(hvar('quiz_round_duration', V_INT) . 'czas trwania rundy (sek.; tylko Familiada/Multi)');
	send_ui_raw(hvar('quiz_max_hints', V_INT) . 'maksymalna liczba podpowiedzi (0: bez ograniczen, >0: limit podpowiedzi, <0: limit ukrytych znakow; nie dla Familiady/Multi)');
	send_ui_raw(hvar('quiz_words_style', V_INT) . 'styl wyrazow (0: bez zmian, 1: male, 2: DUZE, 3: Kapitaliki; tylko Mieszacz/Pomieszany)');
	send_ui_raw(hvar('quiz_anticheat_delay', V_INT) . 'czas trwania ochrony !podp/!przyp (sek.; 0: wylaczone)');
	send_ui_raw(hvar('quiz_first_anticheat_delay', V_INT) . 'czas trwania ochrony pierwszego !podp/!przyp (sek.; 0: wylaczone)');
	send_ui_raw(hvar('quiz_points_per_answer', V_INT) . 'punkty za poprawna odpowiedz');
	send_ui_raw(hvar('quiz_min_points', V_INT) . 'minimum punktowe (tylko Familiada/Multi)');
	send_ui_raw(hvar('quiz_max_points', V_INT) . 'maksimum punktowe (tylko Familiada/Multi)');
	send_ui_raw(hvar('quiz_scoring_mode', V_INT) . 'tryb punktowania (1: ppa, 2: ppa++, 3: ppa++:max, 4: min++ppa, 5: min++ppa:max, 6: max--ppa:min, 7: max->min; tylko Familiada/Multi)');
	send_ui_raw(hvar('quiz_ranking_type', V_INT) . 'rodzaj rankingu (1: zwykly "1234", 2: zwarty "1223", 3: turniejowy "1224")');
	send_ui_raw(hvar('quiz_antigoogler', V_BOOL) . 'uzywac antygooglera do maskowania pytan?');
	send_ui_raw(hvar('quiz_split_long_lines', V_BOOL) . 'dzielic dlugie linie na czesci (nowsze irssi potrafi samo)?');
	send_ui_raw(hvar('quiz_show_first_hint', V_BOOL) . 'pokazywac podpowiedz razem z pytaniem? (nie dla Familiady/Multi)');
	send_ui_raw(hvar('quiz_first_hint_dots', V_BOOL) . 'pierwsza podpowiedz jako same kropki? (nie dla Familiady/Multi)');
	send_ui_raw(hvar('quiz_random_hints', V_BOOL) . 'losowe odslanianie podpowiedzi? albo od lewej do prawej (nie dla Familiady/Multi)');
	send_ui_raw(hvar('quiz_nonrandom_first_hint', V_BOOL) . 'losowe odslanianie podpowiedzi, poza pierwsza? (nie dla Familiady/Multi)');
	send_ui_raw(hvar('quiz_hint_alpha', V_STR) . 'znak podstawiany w podpowiedziach za litery (nie dla Familiady/Multi)');
	send_ui_raw(hvar('quiz_hint_digit', V_STR) . 'znak podstawiany w podpowiedziach za cyfry (nie dla Familiady/Multi)');
	send_ui_raw(hvar('quiz_words_mode', V_BOOL) . 'mieszac slowa osobno? albo wszystko razem (tylko Mieszacz)');
	send_ui_raw(hvar('quiz_smart_mix', V_BOOL) . 'mieszac kotwiczac cyfry i niektore znaki interpunkcyjne? (tylko Pomieszany)');
	send_ui_raw(hvar('quiz_smart_mix_chars', V_STR) . 'te znaki będą zakotwiczone (regex; tylko Pomieszany)');
	send_ui_raw(hvar('quiz_mix_on_remind', V_BOOL) . 'mieszac litery przy kazdym !przyp? (tylko Mieszacz/Pomieszany)');
	send_ui_raw(hvar('quiz_strict_match', V_BOOL) . 'tylko doslowne odpowiedzi? albo *dopasowane* (nie dla Familiady/Multi)');
	send_ui_raw(hvar('quiz_join_anytime', V_BOOL) . 'wchodzenie do druzyn w dowolnej chwili? (tylko Familiada)' );
	send_ui_raw(hvar('quiz_team_play', V_BOOL) . 'graja tylko gracze z druzyn? (tylko Familiada)');
	send_ui_raw(hvar('quiz_transfer_points', V_BOOL) . 'wraz ze zmiana druzyny przenosic punkty? (tylko Familiada)');
	send_ui_raw(hvar('quiz_limiter', V_BOOL) . 'limitowac najlepsza osobe do 50%+1 punktow? (nie dla Familiady/Multi)');
	send_ui_raw(hvar('quiz_keep_scores', V_BOOL) . 'sumowac punkty z poprzednich quizow?');
	send_ui_raw(hvar('quiz_cmd_hint', V_BOOL) . 'polecenie !podp jest dostepne dla graczy?');
	send_ui_raw(hvar('quiz_cmd_remind', V_BOOL) . 'polecenie !przyp jest dostepne dla graczy?');
}

##### Commands' handlers #####
sub cmd_start {
	if ($quiz{standby}) {
		$quiz{standby} = 0;
		init_first_question($_standby_delay);
		return;
	}
	send_ui('quiz_err_ison'), return if ($quiz{ison});
	my ($args, $r_server, $window) = @_;
	send_ui('quiz_err_server'), return if (!$r_server || !$r_server->{connected});
	my ($chan, $file, $type, $teams) = split(/ /, $args);
	($file, $chan) = ($chan, active_win()->{active}->{name}) if (!defined $file); # single arg call
	send_ui('quiz_err_channel'), return if (!$chan || !$r_server->ischannel($chan));
	{
		{ package Irssi::Nick; } # should prevent irssi bug: "Can't locate package Irssi::Nick for @Irssi::Irc::Nick::ISA at ..."
		$quiz{chan} = $r_server->channel_find($chan);
	}
	send_ui('quiz_err_nochannel', $chan), return if (!$quiz{chan});
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
	send_ui('quiz_err_file', $file), return if (!is_valid_data($lines));
	if (!settings_get_bool('quiz_keep_scores')) {
		$quiz{players} = {};
		$quiz{teams} = [];
		@quiz{qw/score answers/} = (0) x 2;
	} else {
		#delete $quiz{players}{$_}{team} for (keys %{$quiz{players}}); #? unsure...
	}
	send_irc('quiz_msg_start1', INSTANT);
	send_irc('quiz_msg_start2' . (($type == QT_FAM) ? '_f' : (($type == QT_MUL) ? '_m' : '')), $teams, INSTANT);
	@quiz{qw/stime qnum ison/} = (time(), 0, 1);
	if ($type == QT_FAM) {
		$quiz{standby} = 1;
		@{$quiz{teams}[$_]}{qw/score answers/} = (0) x 2 for (0 .. $teams);
	} else {
		$quiz{standby} = 0;
		init_first_question($_start_delay);
	}
	signal_add_last('message public', 'sig_pubmsg');
}

sub cmd_stats {
	send_ui('quiz_err_isoff'), return if (($quiz{score} == 0) && !$quiz{ison});
	send_ui('quiz_err_nochannel'), return if (!$quiz{chan});
	my $num = shift;
	send_ui('quiz_err_ranking'), return if (($num ne '') && ($num !~ /^\d+$/));
	$num = -1 if ($num eq '');
	send_irc('quiz_msg_noscores'), return if (!keys %{$quiz{players}});
	my $qnum = $quiz{qnum};
	$qnum-- if ($quiz{inq});
	send_irc('quiz_msg_scores', [
		time_str(time() - $quiz{stime}, T_HMS),
		$qnum, aquestions_str($qnum),
		$quiz{qcnt}, fquestions_str($quiz{qcnt})]) if (!$quiz{standby});
	my $suffix = '';
	$suffix = '_full' if ((settings_get_int('quiz_points_per_answer') != 1) ||
		((($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) && (settings_get_int('quiz_scoring_mode') != 1)));
	if ($quiz{type} == QT_FAM) {
		my @teams;
		push(@{$teams[$quiz{players}{$_}{team}]}, get_format('quiz_inc_team_nick', $quiz{players}{$_}{nick})) for (keys %{$quiz{players}});
		foreach my $team (1 .. $quiz{tcnt}) {
			my ($score, $answers) = @{$quiz{teams}[$team]}{qw/score answers/};
			send_irc('quiz_msg_team_score' . $suffix, [
				$team,
				(!defined $teams[$team]) ? '' : join(', ', @{$teams[$team]}),
				$score, score_str($score), percents($score, $quiz{score}),
				$answers, answers_str($answers), percents($answers, $quiz{answers})]);
		}
	}
	return if ($quiz{standby} || (($num == 0) && ($quiz{type} == QT_FAM)));
	my ($rank, $place, $exaequo, $prev, $ranking) = (0, 1, 0, undef, settings_get_int('quiz_ranking_type'));
	$ranking = (($ranking < 1) || ($ranking > 3)) ? 1 : $ranking;
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
		last if ($place >= $_qstats_records);
		$place++;
	}
	send_irc('quiz_msg_scores_times', join(', ', @nicks)) if (@nicks);
	$place = 1;
	@nicks = ();
	foreach my $player (sort {
						$quiz{players}{$b}{bestspeed} <=> $quiz{players}{$a}{bestspeed} or
						$quiz{players}{$a}{timestamp} <=> $quiz{players}{$b}{timestamp}
					} keys %{$quiz{players}}) {
		push(@nicks, get_format('quiz_inc_scores_record', [$place, $quiz{players}{$player}{nick}, $quiz{players}{$player}{bestspeed}]));
		last if ($place >= $_qstats_records);
		$place++;
	}
	send_irc('quiz_msg_scores_speeds', join(', ', @nicks)) if (@nicks);
}

sub cmd_delay {
	my $delay = shift;
	send_ui('quiz_err_delay'), return if (($delay !~ /^\d+$/) || ($delay < 1));
	my $type = $quiz{ison} ? $quiz{type} : settings_get_int('quiz_type');
	settings_set_int('quiz_delay' . ((($type == QT_FAM) || ($type == QT_MUL)) ? '_long' : ''), $delay);
	send_irc('quiz_msg_delay', $delay) if ($quiz{ison});
	send_ui('quiz_inf_delay', $delay);
}

sub cmd_time {
	my $duration = shift;
	#? send_ui('quiz_err_na'), return if (($quiz{type} != QT_FAM) && ($quiz{type} != QT_MUL));
	send_ui('quiz_err_duration'), return if (($duration !~ /^\d+$/) || ($duration < 1));
	settings_set_int('quiz_round_duration', $duration);
	send_irc('quiz_msg_duration', $duration) if ($quiz{ison});
	send_ui('quiz_inf_duration', $duration);
}

sub cmd_teams {
	my $teams = shift;
	#? send_ui('quiz_err_na'), return if (($quiz{type} != QT_FAM) && ($quiz{type} != QT_MUL));
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
	send_irc('quiz_msg_stop2', [$quiz{qnum}, time_str(time() - $quiz{stime}, T_HMS)]);
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
	if (is_valid_data($lines)) {
		send_ui(($quiz{qcnt} != $cnt) ? 'quiz_wrn_reload' : 'quiz_inf_reload');
		if ((($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) && $quiz{inq}) {
			%{$quiz{lookup}} = map { lc($_) => $_ } keys %{$quiz{data}[$quiz{qnum}]{answers}};
		}
	} else {
		stop_quiz();
		send_irc('quiz_msg_stop1');
		send_irc('quiz_msg_stop2', [$quiz{qnum}, time_str(time() - $quiz{stime}, T_HMS)]);
		send_ui('quiz_err_file', $quiz{file});
	}
}

sub cmd_help {
	show_help();
}

sub cmd_irssi_help {
	my $cmd = shift;
	if ($cmd =~ /^i?quiz$/) {
		show_help();
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

sub evt_next_question {
	$quiz{qtime} = time();
	$quiz{qnum}++;
	my $suffix = '';
	if ($quiz{type} == QT_MIX) {
		$suffix = '_x';
	} elsif (($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) {
		%{$quiz{lookup}} = map { lc($_) => $_ } keys %{$quiz{data}[$quiz{qnum}]{answers}};
		$suffix = '_fm';
	}
	my $duration = abs(settings_get_int('quiz_round_duration')) || $_round_duration; # abs in case of <0, || in case of ==0
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
	}
	$quiz{inq} = 1;
	my $delay = settings_get_int('quiz_first_anticheat_delay');
	if ($delay > 0) {
		$quiz{hprot} = 1;
		$quiz{thint} = timeout_add_once($delay * 1000, sub { $quiz{hprot} = 0 }, undef);
		if ((($quiz{type} == QT_MIX) || ($quiz{type} == QT_SCR)) && settings_get_bool('quiz_mix_on_remind')) {
			$quiz{rprot} = 1;
			$quiz{tremind} = timeout_add_once($delay * 1000, sub { $quiz{rprot} = 0 }, undef);
		}
	}
}

sub evt_round_timeout_warn {
	send_irc('quiz_msg_warn_timeout', $_round_warn_time);
}

sub evt_round_timeout {
	stop_question();
	init_next_question(get_format('quiz_msg_timeout')); #? INSTANT?
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
	return unless (($team >= 1) && ($team <= $quiz{tcnt}));
	if (exists $quiz{players}{$addr}) {
		if (settings_get_bool('quiz_transfer_points')) {
			my ($score, $answers) = @{$quiz{players}{$addr}}{qw/score answers/};
			if (exists($quiz{players}{$addr}{team}) && ($quiz{players}{$addr}{team} != 0)) { # not an outsider
				my $from = $quiz{players}{$addr}{team};
				$quiz{teams}[$from]{score} -= $score;
				$quiz{teams}[$from]{answers} -= $answers;
			}
			$quiz{teams}[$team]{score} += $score;
			$quiz{teams}[$team]{answers} += $answers;
		}
		$quiz{players}{$addr}{team} = $team;
	} else {
		@{$quiz{players}{$addr}}{qw/nick timestamp team/} = ($nick, time(), $team);
		@{$quiz{players}{$addr}}{qw/score answers besttime alltime bestspeed allspeed/} = (0) x 6;
	}
	my @teams;
	push(@{$teams[$quiz{players}{$_}{team}]}, get_format('quiz_inc_team_nick', $quiz{players}{$_}{nick})) for (keys %{$quiz{players}});
	send_irc_whisper('quiz_msg_team_join', [$team, join(', ', @{$teams[$team]})], $nick) if (defined $teams[$team]);
}

sub show_hint {
	return unless (($quiz{type} != QT_FAM) && ($quiz{type} != QT_MUL) && settings_get_bool('quiz_cmd_hint'));
	return if ($quiz{hprot});
	my $hints_limit = settings_get_int('quiz_max_hints');
	make_hint(PREPDOTS) if (!@{$quiz{dots}} && ($hints_limit < 0));
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
}

sub show_remind {
	return unless (settings_get_bool('quiz_cmd_remind'));
	if ((($quiz{type} == QT_MIX) || ($quiz{type} == QT_SCR)) && settings_get_bool('quiz_mix_on_remind')) {
		return if ($quiz{rprot});
		my $delay = settings_get_int('quiz_anticheat_delay');
		if ($delay > 0) {
			$quiz{rprot} = 1;
			$quiz{tremind} = timeout_add_once($delay * 1000, sub { $quiz{rprot} = 0 }, undef);
		}
	}
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

sub check_answer {
	my ($nick, $addr, $answer) = @_;
	if (($quiz{type} == QT_FAM) || ($quiz{type} == QT_MUL)) {
		return unless (exists($quiz{lookup}{$answer}) && ($quiz{data}[$quiz{qnum}]{answers}{$quiz{lookup}{$answer}} > 0));
		return unless (($quiz{type} == QT_MUL) || !settings_get_bool('quiz_team_play') || (exists($quiz{players}{$addr}) && exists($quiz{players}{$addr}{team}) && ($quiz{players}{$addr}{team} != 0))); # last condition: for non team players there is no record
		my ($time, $match) = (time(), $quiz{lookup}{$answer});
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
		return unless (($answer eq lc($quiz{data}[$quiz{qnum}]{answer})) ||
			(!settings_get_bool('quiz_strict_match') && (index($answer, lc $quiz{data}[$quiz{qnum}]{answer}) >= 0)));
		my ($time, $points) = (time(), settings_get_int('quiz_points_per_answer'));
		return unless (!settings_get_bool('quiz_limiter') || !exists($quiz{players}{$addr}) ||
			($quiz{players}{$addr}{score} < int($quiz{qcnt} * 0.5 + 1) * $points)); # 50%+1
		stop_question();
		correct_answer($addr, $nick, $time, $points, $answer);
		init_next_question(get_format('quiz_msg_congrats', [
			$nick,
			($points == 1) ? get_format('quiz_inc_got_point', score_str($points)) : get_format('quiz_inc_got_points', [$points, score_str($points)]),
			$quiz{data}[$quiz{qnum}]{answer},
			$time - $quiz{qtime},
			length($answer) / ($time - $quiz{qtime}),
			$quiz{players}{$addr}{score}]), INSTANT);
	}
}

##### Signals' handlers #####
sub sig_pubmsg {
	my ($r_server, $msg, $nick, $addr, $target) = @_;
	return if (!$quiz{ison} || ($r_server->{tag} ne $quiz{chan}{server}{tag}) || (lc($target) ne lc($quiz{chan}{name})));
	for ($msg) {
		tr/\t/ /;			# tabs to spaces
		s/ {2,}/ /g;		# fix double spaces
		s/^ +| +$//g;		# trim leading/trailing spaces
		s/\002|\003(?:\d{1,2}(?:,\d{1,2})?)?|\017|\026|\037//g;		# remove formatting
		# \002 - bold  \003$fg(,$bg)? - color  \017 - plain  \026 - reverse  \037 - underline
	}
	return if ($msg eq '');
	my $lmsg = lc $msg;
	if ($lmsg =~ /^!ile(?:\s+([^\s]+))?/) {
		show_score($nick, $addr, $1)
	} elsif ($lmsg =~ /^!join\s+(\d)$/) {
		join_team($nick, $addr, $1);
	}
	return if (!$quiz{inq});
	if ($lmsg eq '!podp') {
		show_hint();
	} elsif (($lmsg eq '!przyp') || ($lmsg eq '!pyt')) {
		show_remind();
	}
	check_answer($nick, $addr, $lmsg);
}

##### Bindings #####
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
command_bind('qstats',	'cmd_stats');
command_bind('qoff',	'cmd_stop');
command_bind('qreload',	'cmd_reload');
command_bind('qinit',	'cmd_init');

##### User settings #####
settings_add_int($IRSSI{name}, $_, $settings_int{$_}) for (keys %settings_int);
settings_add_bool($IRSSI{name}, $_, $settings_bool{$_}) for (keys %settings_bool);
settings_add_str($IRSSI{name}, $_, $settings_str{$_}) for (keys %settings_str);

##### Initialization #####
timeout_add_once($_display_delay, 'evt_delayed_load_info', undef); # le trick (workaround for info showing before script load message)
