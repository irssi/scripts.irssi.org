#
# Commands: /ASCII, /COLSAY, /COLME, /COLTOPIC, /COLKICK, /COLQUIT
# Usage:
#	/ASCII [-c1234] [-f <fontname>] [-p <prefix>] [-l|-s|-m <where>] <text>
#	/COLSAY [-1234] [-m <where>] <text>
#	/COLME [-1234] <text>
#	/COLTOPIC [-1234] <text>
#	/COLKICK [-1234] [nick(,nick_1,...,nick_n)] <reason>
#	/COLQUIT [-1234] <reason>
# Settings:
#	/SET ascii_figlet_path [path]
#	/SET ascii_default_font [fontname]	
#	/SET ascii_default_colormode [1-4]
#	/SET ascii_default_prefix [prefix]
#	/SET ascii_default_kickreason [reason]
#	/SET ascii_default_quitreason [reason]
#
# Script is bassed on figlet.
#

use strict;
use Irssi;
use Irssi::Irc;

use vars qw($VERSION %IRSSI);

$VERSION = "1.6.3";
%IRSSI = (
	"authors"       => "Marcin Rozycki",
	"contact"       => "derwan\@irssi.pl",
	"name"          => "ascii-art",
	"description"   => "Ascii-art bassed on figlet. Available commands: /ASCII, /COLSAY, /COLME, /COLTOPIC, /COLKICK, /COLQUIT.",
	"url"           => "http://derwan.irssi.pl",
	"license"       => "GNU GPL v2",
	"changed"       => "Fri Jun 21 17:17:53 CEST 2002"
);

use IPC::Open3;

# defaults
my $ascii_default_font = "small.flf";
my $ascii_default_kickreason = "Irssi BaBy!";
my $ascii_default_quitreason = "I Quit!";
my $ascii_last_color = undef;
my @ascii_colors = (12, 12, 12, 9, 5, 4, 13, 8, 7, 3, 11, 10, 2, 6, 6, 6, 6, 10, 8, 7, 4, 3, 9, 11, 2, 12, 13, 5);

# registering themes
Irssi::theme_register([
	'ascii_not_connected',		'%_$0:%_ You\'re not connected to server',
	'ascii_not_window',		'%_$0:%_ Not joined to any channel or query window',
	'ascii_not_chanwindow',		'%_$0:%_ Not joined to any channel',
	'ascii_not_chanop',		'%_$0:%_ You\'re not channel operator in {hilight $1}',
	'ascii_figlet_notfound',	'%_Ascii:%_ Cannot execute {hilight $0} - file not found or bad permissions',
	'ascii_figlet_notset',		'%_Ascii:%_ Cannot find external program %_figlet%_, usign /SET ascii_figlet_path [path], to set it',
	'ascii_cmd_syntax',		'%_$0:%_ $1, usage: $2',
	'ascii_figlet_error',		'%_Ascii: Figlet returns error:%_ $0-',
	'ascii_fontlist',		'%_Ascii:%_ Available fonts [in $0]: $1 ($2)',
	'ascii_empty_fontlist',		'%_Ascii:%_ Cannot find figlet fonts in $0',
	'ascii_unknown_fontdir',	'%_Ascii:%_ Cannot find figlet fontdir',
	'ascii_show_line',		'$0-'

]);

# str find_figlet_path()
sub find_figlet_path {
	foreach my $dir (split(/\:/, $ENV{'PATH'}))
	{
		return "$dir/figlet" if ($dir and -x "$dir/figlet");
	}
}

# int randcolor()
sub randcolor {
	return $ascii_colors[int(rand(12)+2)];
}

# str colorline($colormode, $text)
sub colorline {
	my ($colormode, $text) = @_;
	my $colortext = undef;
	my $last = ($ascii_last_color) ? $ascii_last_color : randcolor();
	my $indx = $last;

	if ($colormode =~ /3/) {
		$ascii_last_color = randcolor();
	}elsif ($colormode =~ /4/) {
		$ascii_last_color = $ascii_colors[$last];
	}elsif ($colormode !~ /2/) {
		$ascii_last_color = $ascii_colors[14+$last];
	}

	while ($text =~ /./g)
	{
		my $char = "$&";

		if ($colormode =~ /3/) {
			while ($indx == $last) { $indx = randcolor(); };
			$last = $indx;
		}elsif ($colormode =~ /4/) {
			$indx = $ascii_colors[$indx];
		}elsif ($last) {
			$indx = $ascii_colors[$last];
			undef $last;
		} else {
			$indx = $ascii_colors[$indx];
			$last = $indx + 14;
		};

		$colortext .= $char, next if ($char eq " ");
		$colortext .= "\003" . sprintf("%02d", $indx) . $char;
		$colortext .= $char if ($char eq ",");
	};

	return $colortext;
};

# int colormode()
sub colormode {
	my $mode = Irssi::settings_get_int("ascii_default_colormode");
	$mode =~ s/-//g;
	return (!$mode or $mode > 4) ? 1 : $mode;
};

# bool ascii_test($command, $flags, $server, $window)
sub ascii_test {
	my ($cmd, $test, $server, $window) = @_;

	if ($test =~ /s/ and !$server || !$server->{connected}) {
		Irssi::printformat(MSGLEVEL_CRAP, "ascii_not_connected", $cmd);
		return 0;
	};
	if ($test =~ /W/ and !$window || $window->{type} !~ /(channel|query)/i) {
		Irssi::printformat(MSGLEVEL_CRAP, "ascii_not_window", $cmd);
		return 0;
	};
	if ($test =~ /(w|o)/ and !$window || $window->{type} !~ /channel/i) {
		Irssi::printformat(MSGLEVEL_CRAP, "ascii_not_chanwindow", $cmd);
		return 0;
	};
	if ($test =~ /o/ and !$window->{chanop}) {
		Irssi::printformat(MSGLEVEL_CRAP, "ascii_not_chanop", $cmd, Irssi::active_win()->get_active_name());
		return 0;
	};

	return 1;
}

# void cmd_ascii()
# handles /ascii
sub cmd_ascii
{
	my $usage = "/ASCII [-c1234] [-f <fontname>] [-p <prefix>] [-l|-s|-m <where>] <text>";
	my $font = Irssi::settings_get_str("ascii_default_font");
	my $prefix = Irssi::settings_get_str("ascii_default_prefix");
	my ($arguments, $server, $witem) = @_;
	my ($text, $cmd, $mode);

	$font = $ascii_default_font unless ($font);
	$ascii_last_color = randcolor();

	my $figlet = Irssi::settings_get_str("ascii_figlet_path");
	if (!$figlet or !(-x $figlet)) {
		my $theme = ($figlet) ? "ascii_figlet_notfound" : "ascii_figlet_notset";
		Irssi::printformat(MSGLEVEL_CRAP, $theme, $figlet);
		return;
	};

	my @foo = split(/ +/, $arguments);
	while ($_ = shift(@foo))
	{
		/^-l$/ and show_figlet_fonts($figlet), return;
		/^-c$/ and $mode = colormode(), next;
		/^-(1|2|3|4)$/ and s/-//g, $mode = $_, next;
		/^-f$/ and $font = shift(@foo), next;
		/^-p$/ and $prefix = shift(@foo), next;
		/^-m$/ and $cmd = shift(@foo), next;
		/^-s$/ and $cmd =  0, next;
		/^-/ and Irssi::printformat(MSGLEVEL_CRAP, "ascii_cmd_syntax", "Ascii", "Unknown argument: $_", $usage), return;
		$text = ($#foo < 0) ? $_ : $_ . " " . join(" ", @foo);
		last;
	}

	unless (length($text)) {
		Irssi::printformat(MSGLEVEL_CRAP, "ascii_cmd_syntax", "Ascii", "Missing arguments", $usage);
		return;
	};

	if ($cmd eq "") {
		return unless (ascii_test("Ascii", "sW", $server, $witem));
		$cmd = Irssi::active_win()->get_active_name();
	} elsif ($cmd ne "0" and !ascii_test("Ascii", "s", $server, $witem)) {
		return;
	}

	my $pid = open3(*FIGIN, *FIGOUT, *FIGERR, $figlet, qw(-k -f), $font, $text);

	while (<FIGOUT>)
	{
		chomp;
		next unless (/[^ ]/);
		$_ = colorline($mode, $_) if ($mode);
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, "ascii_show_line", $prefix.$_), next if ($cmd eq "0");
		$server->command("msg $cmd $prefix$_");
	}

	while (<FIGERR>)
	{
		chomp;
		Irssi::printformat(MSGLEVEL_CRAP, "ascii_figlet_error", $_);
	};

	close FIGIN;
	close FIGOUT;
	close FIGERR;

	waitpid $pid, 0;
}

# void show_figlet_fonts(figlet path)
sub show_figlet_fonts {
	my @fontlist;
	if (my $fontdir = `"$_[0]" -I 2 2>/dev/null`) {
		chomp $fontdir;
		foreach my $font (glob $fontdir."/*.flf")
		{
			$font =~ s/^$fontdir\///;
			$font =~ s/\.flf$//;
			push @fontlist, $font;
		}
		if ($#fontlist < 0) {
			Irssi::printformat(MSGLEVEL_CRAP, "ascii_fontlist_empty", $fontdir);
		} else {
			Irssi::printformat(MSGLEVEL_CRAP, "ascii_fontlist", $fontdir, join(", ", @fontlist), scalar(@fontlist));
		}
	} else {
		Irssi::printformat(MSGLEVEL_CRAP, "ascii_unknown_fontdir");
	}
}

# void cmd_colsay()
# handles /colsay
sub cmd_colsay {
	my $usage = "/COLSAY [-1234] [-m <where>] <text>";
	my ($arguments, $server, $witem) = @_;
	my ($cmd, $text);
	my $mode = colormode();

	$ascii_last_color = randcolor();

	my @foo = split(/ /, $arguments);
	while ($_ = shift(@foo))
	{
		/^-(1|2|3|4)$/ and $mode = $_, next;
		/^-m$/i and $cmd = shift(@foo), next;
		/^-/ and Irssi::printformat(MSGLEVEL_CRAP, "ascii_cmd_syntax", "Colsay", "Unknown argument: $_", $usage), return;
		$text = ($#foo < 0) ? $_ : $_ . " " . join(" ", @foo);
		last;
	};

	unless (length($text)) {
		Irssi::printformat(MSGLEVEL_CRAP, "ascii_cmd_syntax", "Colsay", "Missing arguments", $usage);
		return;
	};

	if ($cmd) {
		return unless (ascii_test("Colsay", "s", $server, $witem));
	} else {
		return unless (ascii_test("Colsay", "sW", $server, $witem));
		$cmd = Irssi::active_win()->get_active_name();
	};

	$server->command("msg $cmd ".colorline($mode, $text));
}


sub cmd_colme {
	my $usage = "/COLME [-1234] <text>";
	my ($arguments, $server, $witem) = @_;
	my $mode = colormode();
	my $text;

	$ascii_last_color = randcolor();

	my @foo = split(/ /, $arguments);
	while ($_ = shift(@foo))
	{
		/^-(1|2|3|4)$/ and $mode = $_, next;
		/^-/ and Irssi::printformat(MSGLEVEL_CRAP, "ascii_cmd_syntax", "Colme", "Unknown argument: $_", $usage), return;
		$text = ($#foo < 0) ? $_ : $_ . " " . join(" ", @foo);
		last;
	};

	unless (length($text)) {
		Irssi::printformat(MSGLEVEL_CRAP, "ascii_cmd_syntax", "Colme", "Missing arguments", $usage);
		return;
	};

	return unless (ascii_test("Colme", "sW", $server, $witem));
	$witem->command("me ".colorline($mode, $text));
}

# void cmd_coltopic()
# handles /coltopic
sub cmd_coltopic {
	my $usage = "/COLTOPIC [-1234] <text>";
	my ($arguments, $server, $witem) = @_;
	my $mode = colormode();
	my $text;

	$ascii_last_color = randcolor();

	my @foo = split(/ /, $arguments);
	while ($_ = shift(@foo))
	{
		/^-(1|2|3|4)$/ and $mode = $_, next;
		/^-/ and Irssi::printformat(MSGLEVEL_CRAP, "ascii_cmd_syntax", "Coltopic", "Unknown argument: $_", $usage), return;
		$text = ($#foo < 0) ? $_ : $_ . " " . join(" ", @foo);
		last;
	};

	unless (length($text)) {
		Irssi::printformat(MSGLEVEL_CRAP, "ascii_cmd_syntax", "Coltopic", "Missing arguments", $usage);
		return;
	};

	return unless (ascii_test("Coltopic", "sw", $server, $witem));

	$server->command("topic " . Irssi::active_win()->get_active_name() . " " . colorline($mode, $text));
};

# void cmd_colkick()
# handles /colkick
sub cmd_colkick {
	my $usage = "/COLKICK [-1234] [nick(,nick_1,...,nick_n)] <reason>";
	my ($arguments, $server, $witem) = @_;
	my $kickreason = Irssi::settings_get_str("ascii_default_kickreason");
	my $mode = colormode();
	my $who = undef;

	$ascii_last_color = randcolor();
	$kickreason = $ascii_default_kickreason unless ($kickreason);

	my @foo = split(/ /, $arguments);
	while ($_ = shift(@foo))
	{
		/^-(1|2|3|4)$/ and $mode = $_, next;
		/^-/ and Irssi::printformat(MSGLEVEL_CRAP, "ascii_cmd_syntax", "Colkick", "Unknown argument: $_", $usage), return;
		$kickreason = join(" ", @foo) if ($#foo >= 0);
		$who = $_;
		last;
	};

	if (!$who or !length($kickreason)) {
		Irssi::printformat(MSGLEVEL_CRAP, "ascii_cmd_syntax", "Colkick", "Missing arguments", $usage);
		return;
	};

	return unless (ascii_test("Colkick", "swo", $server, $witem));
	$witem->command("kick $who ".colorline($mode, $kickreason));
};

# void cmd_colquit()
# handles /colquit
sub cmd_colquit {
	my $usage = "/COLQUIT [-1234] <reason>";
	my ($arguments, $server, $witem) = @_;
	my $quitreason = Irssi::settings_get_str("ascii_default_quitreason");
	my $mode = colormode();

	$ascii_last_color = randcolor();
	$quitreason = $ascii_default_quitreason unless ($quitreason);

	my @foo = split(/ /, $arguments);
	while ($_ = shift(@foo))
	{
		/^-(1|2|3|4)$/ and $mode = $_, next;
		/^-/ and Irssi::printformat(MSGLEVEL_CRAP, "ascii_cmd_syntax", "Colquit", "Unknown argument: $_", $usage), return;
		$quitreason = ($#foo < 0) ? $_ : $_ . " " . join(" ", @foo);
		last;
	};

	unless (length($quitreason)) {
		Irssi::printformat(MSGLEVEL_CRAP, "ascii_cmd_syntax", "Colquit", "Missing arguments", $usage);
		return;
	};

	return unless (ascii_test("Colquit", "s", $server, $witem));
	$server->command("quit " . colorline($mode, $quitreason));
}

# registering settings
Irssi::settings_add_str("misc", "ascii_default_font", $ascii_default_font);
Irssi::settings_add_str("misc", "ascii_default_kickreason", $ascii_default_kickreason);
Irssi::settings_add_str("misc", "ascii_default_quitreason", $ascii_default_quitreason);
Irssi::settings_add_str("misc", "ascii_default_prefix", "");
Irssi::settings_add_int("misc", "ascii_default_colormode", 1);
Irssi::settings_add_str("misc", "ascii_figlet_path", find_figlet_path);

# binding commands
Irssi::command_bind("ascii", "cmd_ascii");
Irssi::command_bind("colsay", "cmd_colsay");
Irssi::command_bind("colme", "cmd_colme");
Irssi::command_bind("coltopic", "cmd_coltopic");
Irssi::command_bind("colkick", "cmd_colkick");
Irssi::command_bind("colquit", "cmd_colquit");
