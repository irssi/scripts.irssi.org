# Copyright (c) 2010 Adam James <atj@pulsewidth.org.uk>

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

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use POSIX qw(strftime);

use Email::Sender::Simple qw(try_to_sendmail);
use Email::Simple;
use Email::Simple::Creator;

$VERSION = '0.5';
%IRSSI = (
	authors => 'Adam James',
	contact => 'atj@pulsewidth.org.uk',
	url => 'http://git.pulsewidth.org.uk/?p=irssi-scripts.git;a=summary',
	name => 'email_privmsgs',
	description =>
		"Emails you private messages sent while you're away. " .
		"Useful in combination with screen_away. " .
		"Requires Email::Sender.",
	license => 'MIT',
);

my $FORMAT = $IRSSI{'name'} . '_crap';
my $msgs = {};

Irssi::settings_add_str('misc', $IRSSI{'name'} . '_from_address',
	'irssi@' . (%ENV->{'HOST'} || 'localhost'));
Irssi::settings_add_str('misc', $IRSSI{'name'} . '_to_address',
	%ENV->{'USER'});
Irssi::settings_add_str('misc', $IRSSI{'name'} . '_subject',
	'IRC Private Messages from Irssi');

Irssi::theme_register([
	$FORMAT,
	'{line_start}{hilight ' . $IRSSI{'name'} . ':} $0'
]);

# check the message log every 30 minutes
Irssi::timeout_add(30*60*1000, 'check_messages', '');

sub handle_privmsg() {
	my ($server, $message, $user, $address, $target) = @_;

	# only log messages if the user is away
	unless ($server->{usermode_away}) {
		return;
	}

	add_privmsg($server, $message, $user, $address);
}

sub check_messages() {
	if (scalar(keys(%{$msgs})) > 0) {
		send_email();
		$msgs = {};
	}

	return 0;
}

sub add_privmsg() {
	my ($server, $message, $user, $addr) = @_;
	
	unless (defined $msgs->{$server->{chatnet}}) {
		$msgs->{$server->{chatnet}} = {};
	};

	unless (defined $msgs->{$server->{chatnet}}{$user}) {
		$msgs->{$server->{chatnet}}->{$user} = [];
	};

	push(@{$msgs->{$server->{chatnet}}->{$user}},
		[time, $message]
	);
}

sub generate_email() {
	my @lines = ();

	if (scalar(keys(%{$msgs})) == 0) {
		return undef;
	}

	for my $network (keys %{$msgs}) {
		push(@lines, $network);
		push(@lines, '=' x length($network));
		push(@lines, '');

		for my $user (keys %{$msgs->{$network}}) {
			for my $ele (@{$msgs->{$network}->{$user}}) {
				push(@lines, sprintf("[%s] <%s> %s", 
					strftime("%T", localtime($ele->[0])),
					$user, $ele->[1])
				);
			}
			push(@lines, '');
		}
	}

	return \@lines;
}

sub send_email() {
	my $body = generate_email();

	unless (defined($body)) {
		return;
	}

	my $email = Email::Simple->create(
		header => [
			To => Irssi::settings_get_str($IRSSI{'name'} . '_to_address'),
			From => Irssi::settings_get_str($IRSSI{'name'} . '_from_address'),
			Subject => Irssi::settings_get_str($IRSSI{'name'} . '_subject'),
		],
		body => join("\n", @{$body}),
	);

	if (! try_to_sendmail($email)) {
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, $FORMAT, 
			"an error occurred when sending an email to " . 
			Irssi::settings_get_str($IRSSI{'name'} . '_to_address')
		);
	}
}

Irssi::signal_add_last("message private", "handle_privmsg");
