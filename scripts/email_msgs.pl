# Copyright (c) 2010 Adam James <atj@pulsewidth.org.uk>
# Copyright (c) 2015 Igor Duarte Cardoso <igordcard@gmail.com>

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Changelog:
# 1.0 - initial release, based on email_privmsgs 0.5:
#   * support for public messages as well (with/without mentions);
#   * support for own messages as well;
#   * configuration options to select what messages should be emailed:
#     - public received;
#     - private received;
#     - private sent;
#     - public sent;
#     - public mentions received.
#   * configuration option to choose whether the user must be away or not;
#   * configuration option to select message check/email interval;
#   * configuration option for the destination email address;
#   * configuration option to activate detailed info:
#     - currently only to email the user's hostname (for spam tracking e.g.).

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use POSIX qw(strftime);

use Email::Sender::Simple qw(try_to_sendmail);
use Email::Simple;
use Email::Simple::Creator;

$VERSION = '1.1';
%IRSSI = (
	authors => 'Igor Duarte Cardoso, Adam James',
	contact => 'igordcard@gmail.com, atj@pulsewidth.org.uk',
	url =>
		"http://www.igordcard.com",
	name => 'email_msgs',
	description =>
		"Emails you messages sent/received while you're away or not. " .
		"Works for both public mentions and private messages." .
		"When away, it is very useful in combination with screen_away. " .
		"Based on email_privmsgs, with advanced features and options. " .
		"Requires Email::Sender.",
	license => 'MIT',
);

my $FORMAT = $IRSSI{'name'} . '_crap';
my $msgs = {};

##############################################
# your destination email address:
my $to_addr;
# your sender email address:
my $from_addr;
# email subject
my $subject;
# whether the script should work only when away:
my $away_only;
# include detailed info like the hostname of the sender:
my $detailed;
# interval to check for messages (in seconds):
my $interval;
# whether public messages received (including mentions) should be emailed:
my $pub_r_msgs;
# whether private messages received should be emailed:
my $pri_r_msgs;
# whether public messages sent should be emailed:
my $pub_s_msgs;
# whether private messages sent should be emailed:
my $pri_s_msgs;
# whether public mentions received should be emailed (when $pub_r_msgs=0):
my $mentions;
##############################################

Irssi::settings_add_str('misc', $IRSSI{'name'} . '_from_address',
	'irssi@' . ($ENV{'HOST'} || 'localhost'));
Irssi::settings_add_str('misc', $IRSSI{'name'} . '_to_address',
	'x@y.z');
Irssi::settings_add_str('misc', $IRSSI{'name'} . '_subject',
	'IRC Messages');
Irssi::settings_add_bool('misc', $IRSSI{'name'} . '_away_only', 0);
Irssi::settings_add_bool('misc', $IRSSI{'name'} . '_detailed', 1);
Irssi::settings_add_int('misc', $IRSSI{'name'} . '_interval', 300);
Irssi::settings_add_bool('misc', $IRSSI{'name'} . '_pri_r_msgs', 1);
Irssi::settings_add_bool('misc', $IRSSI{'name'} . '_pub_s_msgs', 1);
Irssi::settings_add_bool('misc', $IRSSI{'name'} . '_pri_s_msgs', 1);
Irssi::settings_add_bool('misc', $IRSSI{'name'} . '_pub_r_msgs', 0);
Irssi::settings_add_bool('misc', $IRSSI{'name'} . '_mentions', 1);

Irssi::theme_register([
	$FORMAT,
	'{line_start}{hilight ' . $IRSSI{'name'} . ':} $0'
]);

my ($timetag, $t_pri_r_msgs, $t_pub_s_msgs, $t_pri_s_msgs, $t_pub_r_msgs);
Irssi::signal_add('setup changed', \&sig_setup_changed);

sig_setup_changed();

sub sig_setup_changed {
	$from_addr = Irssi::settings_get_str($IRSSI{'name'} . '_from_address');
	$to_addr   = Irssi::settings_get_str($IRSSI{'name'} . '_to_address');
	$subject   = Irssi::settings_get_str($IRSSI{'name'} . '_subject');
	$away_only = Irssi::settings_get_bool($IRSSI{'name'} . '_away_only');
	$detailed  = Irssi::settings_get_bool($IRSSI{'name'} . '_detailed');
	my $i  = Irssi::settings_get_int($IRSSI{'name'} . '_interval');
	if ($i != $interval) {
		$interval=$i;
		if (defined $timetag) {
			Irssi::timeout_remove($timetag);
		}
		$timetag= Irssi::timeout_add($interval*1000, 'check_messages', '');
	}
	my $pr  = Irssi::settings_get_bool($IRSSI{'name'} . '_pri_r_msgs');
	if ($pr != $pri_r_msgs) {
		$pri_r_msgs= $pr;
		if ($pri_r_msgs) {
			Irssi::signal_add_last("message private", "handle_privmsg");
			$t_pri_r_msgs=1;
		} elsif (defined $t_pri_r_msgs) {
			Irssi::signal_remove("message private", "handle_privmsg");
			$t_pri_r_msgs=undef;
		}
	}
	my $pus  = Irssi::settings_get_bool($IRSSI{'name'} . '_pub_s_msgs');
	if ($pus != $pub_s_msgs) {
		$pub_s_msgs= $pus;
		if ($pub_s_msgs) {
			Irssi::signal_add_last("message own_public", "handle_ownpubmsg");
			$t_pub_s_msgs=1;
		} elsif (defined $t_pub_s_msgs) {
			Irssi::signal_remove("message own_public", "handle_ownpubmsg");
			$t_pub_s_msgs=undef;
		}
	}
	my $ps  = Irssi::settings_get_bool($IRSSI{'name'} . '_pri_s_msgs');
	if ($ps != $pri_s_msgs) {
		$pri_s_msgs= $ps;
		if ($pri_s_msgs) {
			Irssi::signal_add_last("message own_private", "handle_ownprivmsg");
			$t_pri_s_msgs=1;
		} elsif (defined $t_pri_s_msgs) {
			Irssi::signal_remove("message own_private", "handle_ownprivmsg");
			$t_pri_s_msgs=undef;
		}
	}
	my $pur  = Irssi::settings_get_bool($IRSSI{'name'} . '_pub_r_msgs');
	my $men  = Irssi::settings_get_bool($IRSSI{'name'} . '_mentions');
	my $pm = $pub_r_msgs || $mentions;
	$pub_r_msgs= $pur;
	$mentions= $men;
	if (($pub_r_msgs || $mentions) != $pm) {
		if ($pub_r_msgs || $mentions) {
			Irssi::signal_add_last("message public", "handle_pubmsg");
			$t_pub_r_msgs=1;
		} elsif (defined $t_pub_r_msgs) {
			Irssi::signal_remove("message public", "handle_pubmsg");
			$t_pub_r_msgs= undef;
		}
	}
}

sub handle_ownprivmsg {
	my ($server, $message, $target, $orig_target) = @_;

	if ($server->{usermode_away} || !$away_only) {
		add_msg($server, $message, $server->{nick}, $from_addr, "\@$target");
	}
}

sub handle_ownpubmsg {
	my ($server, $message, $target) = @_;

	if ($server->{usermode_away} || !$away_only) {
		add_msg($server, $message, $server->{nick}, $from_addr, $target);
	}
}

sub handle_privmsg {
	my ($server, $message, $user, $address) = @_;

	if ($server->{usermode_away} || !$away_only) {
		add_msg($server, $message, $user, $address, "\@$user");
	}
}

sub handle_pubmsg {
	my ($server, $message, $user, $address, $target) = @_;

	if ($server->{usermode_away} || !$away_only) {
		if (index($message,$server->{nick}) >= 0 || $pub_r_msgs) {
			add_msg($server, $message, $user, $address, $target);
		}
	}
}

sub check_messages {
	if (scalar(keys(%{$msgs})) > 0) {
		send_email();
		$msgs = {};
	}

	return 0;
}

sub add_msg {
	my ($server, $message, $user, $address, $target) = @_;

	unless (defined $msgs->{$server->{chatnet}}) {
		$msgs->{$server->{chatnet}} = {};
	};

	unless (defined $msgs->{$server->{chatnet}}{$target}) {
		$msgs->{$server->{chatnet}}->{$target} = {};
	};

	unless (defined $msgs->{$server->{chatnet}}{$target}{$user}) {
		$msgs->{$server->{chatnet}}->{$target}->{$user} = [];
	};

	push(@{$msgs->{$server->{chatnet}}->{$target}->{$user}},
		[time, $message, $address]
	);
}

sub generate_email {
	my @lines = ();
	my $detail;

	if (scalar(keys(%{$msgs})) == 0) {
		return undef;
	}

	for my $network (keys %{$msgs}) {
		push(@lines, $network);
		push(@lines, '=' x length($network));
		push(@lines, '');

		for my $target (keys %{$msgs->{$network}}) {
			push(@lines, $target);
			push(@lines, '-' x length($target));
			for my $user (keys %{$msgs->{$network}{$target}}) {
				for my $ele (@{$msgs->{$network}->{$target}->{$user}}) {
					$detail = $detailed ? " ($ele->[2])" : "";
					push(@lines, sprintf("[%s] <%s> %s%s", 
						strftime("%T", localtime($ele->[0])),
						$user, $ele->[1], $detail)
					);
				}
				push(@lines, '');
			}
		}
	}

	return \@lines;
}

sub send_email {
	my $body = generate_email();

	unless (defined($body)) {
		return;
	}

	my $email = Email::Simple->create(
		header => [
			To => $to_addr,
			From => $from_addr,
			Subject => $subject,
		],
		body => join("\n", @{$body}),
	);

	if (! try_to_sendmail($email)) {
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, $FORMAT, 
			"an error occurred when sending an email to " . 
			Irssi::settings_get_str($IRSSI{'name'} . '_to_address') .
			" from " .
			Irssi::settings_get_str($IRSSI{'name'} . '_from_address') .
			" subject " .
			Irssi::settings_get_str($IRSSI{'name'} . '_subject') .
			" with content:\n" .
			join("\n", @{$body})
		);
	}
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, $FORMAT,
		"A message was sent to your email.");
}
