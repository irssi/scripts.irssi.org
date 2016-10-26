use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.9";
%IRSSI = (
	'authors'	=> 'Marcin Rozycki, Stanislaw Halik',
	'contact'	=> 'derwan@irssi.pl',
	'name'		=> 'paste',
	'description'	=> 'Usage: /paste [-all|-msgs|-public] [-c|-b] [-s|-l| where] [lines]',
	'url'		=> 'http://derwan.irssi.pl',
	'license'	=> 'GNU GPL v2',
	'changed'	=> 'Tue Oct 12 23:37:12 CEST 2004'
);

use Irssi::TextUI;
use POSIX qw(strftime);

# Examples:
#	/paste
#	/paste -l
#	/paste -l +9
#	/paste derwan +2,11,18-23
#	/paste derwan,#irssi -msgs -5,22,18+1 16
#	/paste -s -30

Irssi::settings_add_str("misc", "paste_save_file", Irssi::get_irssi_dir() . "/paste.save");
Irssi::settings_add_int("misc", "paste_default_level", 0);
Irssi::settings_add_bool("misc", "paste_use_colors", 0);
Irssi::settings_add_bool("misc", "paste_send_index", 0);

my $paste_use_level = MSGLEVEL_SNOTES;
my $paste_warning_send = 10;
my $paste_warning_show = 60;

sub paste {
	my ($server, $window, $where, $size, $yes) = ($_[1], Irssi::active_win(), undef, undef, 0);
	my $colorize = Irssi::settings_get_bool("paste_use_colors");
	my $level = Irssi::settings_get_int("paste_default_level");
	my $file = Irssi::settings_get_str("paste_save_file");
	my @lines = ();
	my @args = split(/ |,/, $_[0]);
	while ($_ = shift(@args))
	{
		/^\d+$/ and push(@lines, $_), next;
		/^(\+|-)\d+$/ and $_ = "1" . $_;
		/^\d+\+\d+$/ and do {
			my ($i, $x) = split(/\+/, $_);
			$_ = $i . "-" . ($i+$x);
		};
		/^\d+-\d+$/ and do {
			my ($i, $x) = split(/-/, $_);
			push(@lines, $i..$x);
			next;
		};
		/^-(a|all)$/ and $level = 0, next;
		/^-(m|msgs)$/ and $level = 1, next;
		/^-(p|public)$/ and $level = 2, next;
		/^-c$/ and $colorize = 1, next;
		/^-b$/ and $colorize = 0, next;
		/^-(l|s)$/ and $where = $_, next;
		/^-yes$/i and $yes = 1, next;
		/^(-|\d)/ and do {
			$window->print("Paste: Bad argument: $_", $paste_use_level);
			return;
		};
		$where .= ($where) ? "," . $_ : $_;
	};
	if ($where !~ /^-(l|s)/) {
		$window->print("Paste: Not connected to server", $paste_use_level), return if (!$server or !$server->{connected});
		unless ($where) {
			$window->print("Paste: Not joined to any channel or query window", $paste_use_level), return
					if (!$_[2] or $_[2]->{type} !~ /^(channel|query)/i);
			$where = $window->get_active_name();
		};
	} elsif ($where =~ /^-l/) {
		$colorize = 0;
		$size = $window->{width} - 6;
		$size -= (length(strftime(Irssi::settings_get_str("timestamp_format"), localtime)) + 1) if (Irssi::settings_get_bool("timestamps"));
	}elsif (!$file) {
		$window->print("Paste: Savefile is not defined, use: /SET paste_save_file [path], to set this", $paste_use_level);
		return;
	};
	my ($line, $idx_last, $cnt) = ($window->view()->{buffer}->{cur_line}, undef, 0);
	@lines = ($where =~ /^-l/) ? (1..($window->{height})) : (1) if ($#lines < 0);
	my @buffer = ();
	for my $idx (sort {$a <=> $b} @lines) {
		next if ($idx == $idx_last);
		while ($idx) {
			last unless ($line);
			my $line_level = $line->{info}->{level};
			if ($level == 0 && ($line_level & ($paste_use_level)) == 0 or
			    $level == 1 && ($line_level & (MSGLEVEL_MSGS)) != 0 or
			    $level == 2 && ($line_level & (MSGLEVEL_PUBLIC)) != 0) {
				if (++$cnt == $idx) {
					my $text = $line->get_text($colorize);
					$text = substr($text, 0, ($size-1)).'$' if ($size and length($text) > $size);
					push @buffer, [$idx, $text];
					$idx_last = $idx;
					undef $idx;
				};

			};
			$line = $line->prev();
		};
		last unless ($line);
	};
	if ($#buffer < 0) {
		$window->print("Paste: Buffer for this window in this level is empty", $paste_use_level);
		return;
	}elsif (!$yes and ($where !~ /^-(l|s)/ && $#buffer > $paste_warning_send or $where =~ /^-l/ && $#buffer > $paste_warning_show)) {
		$window->print("Paste: Doing this is not a good idea. Add -YES option to command if you really mean it", $paste_use_level);
		return;
	};
	if ($where =~ /^-s/) {
		open (F, ">>", $file) or do {
			$window->print("Paste: Cannot write savefile \"$file\"", $paste_use_level);
			return;
		};
		print F "\n-- paste ".strftime("%c", localtime)." ($server->{tag})\n";
	};
	$_ = $where;
	my $index_test = Irssi::settings_get_bool("paste_send_index");
	for (my $loop = $#buffer; $loop >= 0; $loop--) {
		/^-l/ and $window->print("%K[%n%_".sprintf("%3d", $buffer[$loop][0])."%_%K]%n $buffer[$loop][1]", $paste_use_level), next;
		/^-s/ and do {
			print F $buffer[$loop][1]."\n";
			next;
		};
		my $text = ($index_test) ? sprintf("%03d", $buffer[$loop][0]) ." $buffer[$loop][1]" : $buffer[$loop][1];
		$server->command("msg $where ".to_mirc($text));
	};
	/^-s/ and do {
		close(F);
		$window->print("Paste: Saved ".($#buffer + 1)." lines in \"$file\"", $paste_use_level);
	};
}

# too_mirc()
# Stanislaw Halik <weirdo@blindfold.no-ip.com>
sub to_mirc ($)
{
 my $text = shift();
 $text =~ s/[\004]g\//\003\002\002/g;
 $text =~ s/[\004]\?\/+/\0030\002\002/g;
 $text =~ s/[\004]0\//\0031\002\002/g;
 $text =~ s/[\004]0/\0031\002\002/g;
 $text =~ s/[\004]1\//\0032\002\002/g;
 $text =~ s/[\004]1/\0032\002\002/g;
 $text =~ s/[\004]2\//\0033\002\002/g;
 $text =~ s/[\004]2/\0033\002\002/g;
 $text =~ s/[\004]<\//\0034\002\002/g;
 $text =~ s/[\004]</\0034\002\002/g;
 $text =~ s/[\004]4\//\0035\002\002/g;
 $text =~ s/[\004]4/\0035\002\002/g;
 $text =~ s/[\004]5\//\0036\002\002/g;
 $text =~ s/[\004]5/\0036\002\002/g;
 $text =~ s/[\004]6\//\0037\002\002/g;
 $text =~ s/[\004]6/\0037\002\002/g;
 $text =~ s/[\004]>\//\0038\002\002/g;
 $text =~ s/[\004]>/\0038\002\002/g;
 $text =~ s/[\004]:\//\0039\002\002/g;
 $text =~ s/[\004]:/\0039\002\002/g;
 $text =~ s/[\004]3\//\00310\002\002/g;
 $text =~ s/[\004]3/\00310\002\002/g;
 $text =~ s/[\004]\;\//\00311\002\002/g;
 $text =~ s/[\004]\;/\00311\002\002/g;
 $text =~ s/[\004]9\//\00312\002\002/g;
 $text =~ s/[\004]9/\00312\002\002/g;
 $text =~ s/[\004]=\//\00313\002\002/g;
 $text =~ s/[\004]=/\00313\002\002/g;
 $text =~ s/[\004]8\//\00314\002\002/g;
 $text =~ s/[\004]8/\00314\002\002/g;
 $text =~ s/[\004]7\//\00315\002\002/g;
 $text =~ s/[\004]7/\00315\002\002/g;
 $text =~ s/[\004]g\//\003\002\002/g;
 $text =~ s/[\004]g/\003\002\002/g;
 $text =~ s/[\004]8\//\003\002\002/g;
 $text =~ s/[\004]8/\003\002\002/g;
 return $text;
}

Irssi::command_bind("paste", "paste");

