# Away Manager
#
# This script allows you to have different automated
# actions on away
#
# - sets your nick, using a base and a keyword
#   - in example: Crazy_Away
# - insert an away reason
# - say on all channels that your away
#
# This is my first IRSSI script, but I'll try to make it
# better soon.
# If you have ideas to improve it, or make it more efficient,
# contact me at crazycat@c-p-f.org

use Irssi;
use Irssi::Irc;
use strict;

use vars qw($VERSION %IRSSI);

$VERSION = '1.0';
%IRSSI = (
    authors     => 'CrazyCat',
    contact     => 'crazycat@c-p-f.org',
    name        => 'ExtAway',
    description => 'Extended Away & Back programm',
    license     => 'GNU GPLv2 or later',
    changed     => '$Date: 2005/01/12 03:04:01$'
);

my $xa_confile = Irssi::get_irssi_dir()."/xa.config";
my %infos = ();
my ($oldnick, $t_away);

sub init {
	# verifying if settings file exists
	if (!(open xa_settings, q{<}, $xa_confile)) {
		putlog("No config file: /xahelp for help");
		return 0;
	};
	# reading the config file
	while (my $line = <xa_settings>) {
		$line =~ s/\n//;
		my ($xa_key,$xa_val) = split(/:/, $line);
		$xa_key =~ tr/[A-Z]/[a-z]/;
		if ($xa_val ne "") {
			$infos{$xa_key} = $xa_val;
		}
	}
	close xa_settings;
}

sub xa_go {
	# Main procedure to go away
	my($data,$server,$channel) = @_;
	my $xa_nick = "";
	my $xa_reason = "";
	if ($server->{usermode_away}) {
		# oooops! already marged as away
		&putlog("You're allready marqued as away ($server->{away_reason})");
		return 0;
	}
	$oldnick = $server->{nick};
	$t_away = time();
	my $t_data = split(/ /, $data);
	if ($t_data < 2) {
		# away called with just a keyword
		$xa_nick = $data;
		$xa_nick  =~ tr/[A-Z]/[a-z]/;
		$xa_reason = $infos{$xa_nick};
	} else {
		# this is a new reason
		($xa_nick, $xa_reason) = $data =~ /^(\S+) (.*)/;
		&xa_add($xa_nick, $xa_reason);
	}
	if ($xa_reason eq "") {
		putlog("Sorry, <$xa_nick> is not defined");
	} else {
		my $nick = "$infos{'bnick'}$xa_nick";
		foreach my $server (Irssi::servers) {
			$server->command("AWAY $xa_reason");
			$server->command("NICK $nick");
			foreach my $chan ($server->channels) {
				$server->command("DESCRIBE $chan->{name} is away [Reason: $xa_reason]");
			}
		}
	}
}

sub xa_back {
	# the way to be back
	my($data,$server,$channel) = @_;
	if (!$server->{usermode_away}) {
		&putlog("You're not marqued as away");
		return 0;
	}
	my $delay = time() - $t_away;
	my $f_delay = f_delay($delay);
	foreach my $server (Irssi::servers) {
		foreach my $chan ($server->channels) {
			$server->command("DESCRIBE $chan->{name} is back from [$server->{away_reason}] - $f_delay away");
		}
		$server->command("AWAY");
		$server->command("NICK $oldnick");
	}
}

sub putlog {
	# procedure to write in status window
	my ($window) = Irssi::active_win();
	Irssi::print("[$IRSSI{'name'}] @_", MSGLEVEL_CLIENTNOTICE);
	
}

sub f_delay {
	# formatting the away time
	my $seconds = shift;
	my ($hours, $minutes, $formated);
	if ($seconds > 3600) {
		$hours = int($seconds / 3600);
		$formated .= $hours."h:";
		$seconds = $seconds - ($hours * 3600);
	}
	if ($seconds > 60) {
		$minutes = int($seconds / 60);
		$formated .= $minutes."m:";
		$seconds = $seconds - ($minutes * 60);
	}
	$formated .= $seconds."s";
	return $formated;
}

sub xa_add {
	# Adding the keyword and the reason in the config file
	# may create double entries...
	my($kw, $reason) = @_;
	if(!(open xa_settings, q{>>}, $xa_confile)) {
		&putlog("Unable to open file $xa_confile");
	}
	print xa_settings "$kw:$reason\n";
	close xa_settings;
	$infos{$kw} = $reason;
}

sub xa_save {
	# save the temp infos (might correct the double entries)
	my ($data,$server,$channel) = @_;
	if(!(open xa_settings, q{>}, $xa_confile)) {
		&putlog("Unable to create file $xa_confile");
	}
	print xa_settings "bnick:$infos{'bnick'}\n";
	while (my ($kw, $line) = each %infos) {
		if ($kw ne "bnick") {
			print xa_settings "$kw:$infos{$kw}\n";
		}
	}
	close xa_settings;
}
		
sub xa_nick {
	# The way to add the base nick
	my ($data,$server,$channel) = @_;
	if ($data eq "") {
		putlog("You must define your base_nick")
	}
	$infos{'bnick'} = $data;
	&xa_save;
}

sub xa_help {
	&putlog("Help for $IRSSI{name} : $IRSSI{description}");
	&putlog("  Setting your base nick: /xanick <base_nick>");
	&putlog("  Going away: /aw <keyword> [reason]");
	&putlog("     if keyword exists in the base, reason is automatically displayed");
	&putlog("     if keyword is a new one, you MUST give a reason");
	&putlog("  -- Nota: your away nick will be <base_nick><keyword> --");
	&putlog("  Coming back from away: /back");
	&putlog("  Saving all datas: /xasave (take care, setting your base_nick will save all your datas)");
}
#
# main
#
&init();
if ($infos{'bnick'} eq "") {
	&putlog("Please, give a base nick with /xanick <base_nick>");
	&putlog("Use /xahelp to get some help");
}
Irssi::command_bind("aw", "xa_go");
Irssi::command_bind("back", "xa_back");
Irssi::command_bind("xahelp", "xa_help");
Irssi::command_bind("xanick", "xa_nick");
Irssi::command_bind("xasave", "xa_save");

