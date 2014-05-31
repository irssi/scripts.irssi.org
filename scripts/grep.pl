# /GREP [-i] [-w] [-v] [-F] <perl-regexp> <command to run>
#
# -i: match case insensitive
# -w: only print matches that form whole words
# -v: Invert the sense of matching, to print non-matching lines.
# -F: match as a fixed string, not a regexp
#
# if you want /FGREP, do: /alias FGREP GREP -F

use Irssi;
use strict;
use Text::ParseWords;
use vars qw($VERSION %IRSSI); 
$VERSION = "2.1";
%IRSSI = (
	authors	    => "Timo \'cras\' Sirainen, Wouter Coekaerts",
	contact	    => "tss\@iki.fi, wouter\@coekaerts.be", 
	name        => "grep",
	description => "/GREP [-i] [-w] [-v] [-F] <perl-regexp> <command to run>",
	license     => "Public Domain",
	url         => "http://wouter.coekaerts.be/irssi/",
	changed	    => "2008-01-13"
);

my ($match, $v);

sub sig_text {
	my ($dest, $text, $stripped_text) = @_;
	Irssi::signal_stop() if (($stripped_text =~ /$match/) == $v);	
}

sub cmd_grep {
	my ($data,$server,$item) = @_;
	my ($option,$cmd,$i,$w,$F);
	$v = 0;
	$F = 0;
  
	# split the arguments, keep quotes
	my (@args)  = &quotewords(' ', 1, $data);

	# search for options
	while ($args[0] =~ /^-/) {
		$option = shift(@args);
		if ($option eq '-i') {$i = 1;}
		elsif ($option eq '-v') {$v = 1;}
		elsif ($option eq '-w') {$w = 1;}
		elsif ($option eq '-F') {$F = 1;}	
		else {
			Irssi::print("Unknown option: $option",MSGLEVEL_CLIENTERROR);
			return;
		}
	}

	# match = first argument, but remove quotes
	($match) = &quotewords(' ', 0, shift(@args));
	# cmd = the rest (with quotes)
	$cmd = join(' ',@args);

	# check if the regexp is valid
	eval("'' =~ /$match/");
	if($@) { # there was an error
		chomp $@;
		Irssi::print($@,MSGLEVEL_CLIENTERROR);
		return;
	}
	
	if ($F) {
		$match =~ s/(\(|\)|\[|\]|\{|\}|\\|\*|\.|\?|\|)/\\$1/g;
	}
	if ($w) {
		$match = '\b' . $match . '\b';
	}
	if ($i) {
		$match = '(?i)' . $match;
	}

	Irssi::signal_add_first('print text', 'sig_text');
	Irssi::signal_emit('send command', $cmd, $server, $item);
	Irssi::signal_remove('print text', 'sig_text');
}

Irssi::command_bind('grep', 'cmd_grep');
