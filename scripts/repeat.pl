use Irssi;
use strict;

use vars qw($VERSION %IRSSI);

$VERSION="0.2.0";
%IRSSI = (
	authors=> 'BC-bd',
	contact=> 'bd@bc-bd.org',
	name=> 'repeat',
	description=> 'Hide duplicate lines',
	license=> 'GPL v2',
	url=> 'http://bc-bd.org/blog/irssi/',
);

# repeal.pl: ignore repeated messages
# 
# for irssi 0.8.5 by bd@bc-bd.org
#
#########
# USAGE
###
# 
# This script hides repeated lines from:
#
#   dude> Plz Help me!!!
#   dude> Plz Help me!!!
#   dude> Plz Help me!!!
#   guy> foo
#
# Becomes:
#
#   dude> Plz Help me!!!
#   guy> foo
#
# Or with 'repeat_show' set to ON:
#
#   dude> Plz Help me!!!
# Irssi: Message repeated 3 times
#   guy> foo
#
#########
# OPTIONS
#########
#
# /set repeat_show <ON|OFF>
#   * ON  : show info line: 'Message repeated N times'
#   * OFF : don't show it.
#
# /set repeat_count <N>
#   N : Display a message N times, then ignore it.
#
###
################
###
# Changelog
#
# Version 0.2.0
# - addes support for /me
#
# Version master
# - updated url
#
# Version 0.1.3
# - fix: also check before own message (by Wouter Coekaerts)
#
# Version 0.1.2
# - removed stray debug message (duh!)
#
# Version 0.1.1
# - off by one fixed
# - fixed missing '$'
#
# Version 0.1.0
# - initial release
#
my %said;
my %count;

sub sig_public {
  my ($server, $msg, $nick, $address, $target) = @_;

	my $maxcount = Irssi::settings_get_int('repeat_count');

	my $window = $server->window_find_item($target);
	my $refnum = $window->{refnum};

	my $this = $refnum.$nick.$msg;

	my $last = $said{$refnum};
	my $i = $count{$refnum};

	if ($last eq $this and not $nick eq $server->{nick}) {
		$count{$refnum} = $i +1;

		if ($i >= $maxcount) {
			Irssi::signal_stop();
		}
	} else {
		if ($i > $maxcount && Irssi::settings_get_bool('repeat_show')) {
			$window->print("Message repeated ".($i-1)." times");
		}

		$count{$refnum} = 1;
		$said{$refnum} = $this;
	}
}

sub sig_own_public {
	my ($server, $msg, $target) = @_;
	sig_public ($server, $msg, $server->{nick}, "", $target);
}

sub remove_window {
	my ($num) = @_;

	delete($count{$num});
	delete($said{$num});
}

sub sig_refnum {
	my ($window,$old) = @_;
	my $refnum = $window->{refnum};

	$count{$refnum} = $count{old};
	$said{$refnum} = $count{old};

	remove_window($old);
}

sub sig_destroyed {
	my ($window) = @_;
	remove_window($window->{refnum});
}

Irssi::signal_add('message public', 'sig_public');
Irssi::signal_add('message own_public', 'sig_own_public');
Irssi::signal_add('message irc action', 'sig_public');
Irssi::signal_add_last('window refnum changed', 'sig_refnum');
Irssi::signal_add_last('window destroyed', 'sig_destroyed');

Irssi::settings_add_int('misc', 'repeat_count', 1);
Irssi::settings_add_bool('misc', 'repeat_show', 1);

