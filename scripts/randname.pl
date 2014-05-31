# RandName 1.0
# 
# set a random real name taken from a file
# 
# derived from quitmsg.pl by Timo Sirainen

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = '1.0';
%IRSSI = (
        authors         => 'legion',
	contact         => 'a.lepore(at)email.it',
	name            => 'RandName',
	description     => 'Random "/set real_name" taken from a file.',
	license         => 'Public Domain',
	changed         => 'Sat Dec  6 12:28:04 CET 2003',
);

sub randname {

	my $namefile = glob Irssi::settings_get_str('random_realname_file');

	open (FILE, $namefile) || return;
	my $lines = 0; while(<FILE>) { $lines++; };
	my $line = int(rand($lines))+1;

	my $realname;
	seek(FILE, 0, 0); $. = 0;
	while(<FILE>) {
		next if ($. != $line);
		chomp;
		$realname = $_;
		last;
	}
	close(f);
	
	Irssi::print("%9RandName.pl%_:", MSGLEVEL_CRAP);
	Irssi::command("set real_name $realname");

} ##

Irssi::signal_add('gui exit', 'randname');
Irssi::command_bind('randname', 'randname');
Irssi::settings_add_str('misc', 'random_realname_file', '~/.irssi/irssi.realnames');
