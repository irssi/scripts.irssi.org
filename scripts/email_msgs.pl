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

$VERSION = '1.0';
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

# user configurable variables (1->yes; 0->no):
##############################################
# your destination email address:
my $email_addr = 'x@y.z';
# whether the script should work only when away:
my $away_only  = 0;
# include detailed info like the hostname of the sender:
my $detailed   = 1;
# interval to check for messages (in seconds):
my $interval   = 300;
# whether public messages received (including mentions) should be emailed:
my $pub_r_msgs = 0;
# whether private messages received should be emailed:
my $pri_r_msgs = 1;
# whether public messages sent should be emailed:
my $pub_s_msgs = 1;
# whether private messages sent should be emailed:
my $pri_s_msgs = 1;
# whether public mentions received should be emailed (when $pub_r_msgs=0):
my $mentions   = 1;
##############################################

Irssi::settings_add_str('misc', $IRSSI{'name'} . '_from_address',
	'irssi@' . ($ENV{'HOST'} || 'localhost'));
Irssi::settings_add_str('misc', $IRSSI{'name'} . '_to_address',
	$email_addr);
Irssi::settings_add_str('misc', $IRSSI{'name'} . '_subject',
	'IRC Messages');

Irssi::theme_register([
	$FORMAT,
	'{line_start}{hilight ' . $IRSSI{'name'} . ':} $0'
]);

Irssi::timeout_add($interval*1000, 'check_messages', '');

my $from_addr = Irssi::settings_get_str($IRSSI{'name'} . '_from_address');
my $to_addr   = Irssi::settings_get_str($IRSSI{'name'} . '_to_address');
my $subject   = Irssi::settings_get_str($IRSSI{'name'} . '_subject');

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

if ($pub_r_msgs || $mentions) {
	Irssi::signal_add_last("message public", "handle_pubmsg");
}
if ($pri_r_msgs) {
	Irssi::signal_add_last("message private", "handle_privmsg");
}
if ($pub_s_msgs) {
	Irssi::signal_add_last("message own_public", "handle_ownpubmsg");
}
if ($pri_s_msgs) {
	Irssi::signal_add_last("message own_private", "handle_ownprivmsg");
}
