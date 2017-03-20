# signal_hilight.pl - (c) 2017 John Morrissey <jwm@horde.net>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# About
# =====
#
# When you're away, sends highlighted messages to you via Signal.
#
#
# To use
# ======
#
# 1. Install signal-cli (https://github.com/AsamK/signal-cli).
#
# 2. Register a new Signal account for this device, or link to an existing
#    one.
#
#    It's better to create a dedicated Signal account to have this script
#    send messages from. This requires a dedicated phone number to receive
#    the verification code text message for the new Signal account. Google
#    Voice numbers are useful here.
#
#    Linking gives the host running irssi the same access to the account
#    (such as reading messages, changing account settings, and more) as the
#    Signal app has on your phone or computer.
#
#    - Register a new account:
#      - signal-cli -u +12128675309 register
#      - Retrieve verification
#      - signal-cli -u +12128675309 verify VERIFICATION-CODE-FROM-SMS
#
#    - Link to an existing account:
#      - signal-cli link -n $(hostname)
#      - qrencode -o device-link-qrcode.png 'tsdevice:/?uuid=...'
#      - View device-link-qrcode.png.
#      - Scan the QR code with the Signal app
#        (Settings -> Linked Devices -> Link New Device).
#
# 3. Load the script and configure:
#    - /script load signal_hilight.pl
#    - /set signal_phonenumber_from +12128675309
#    - /set signal_phonenumber_to +12128675309

use strict;
use warnings;

use POSIX;

use Irssi;

our $VERSION = '1.0';
our %IRSSI = (
	author => 'John Morrissey',
	contact => 'jwm@horde.net',
	name => 'signal_hilight',
	description => 'Send highlighted messages via Signal',
	licence => 'BSD',
);

my $IS_AWAY = 0;

sub send_notification {
	my ($message) = @_;

	my $pid = fork();
	if ($pid > 0) {
		Irssi::pidwait_add($pid);
	} else {
		eval {
			my $from = Irssi::settings_get_str('signal_phonenumber_from');
			my $to = Irssi::settings_get_str('signal_phonenumber_to');

			if ($from && $to &&
			    open(SIGNAL_CLI, '|-', "signal-cli -u $from send $to")) {

				print SIGNAL_CLI "$message";
				close(SIGNAL_CLI);
			}
		};
		POSIX::_exit(0);
	}
}

sub sig_print_text {
	my ($dest, $text, $stripped) = @_;

	if ($IS_AWAY &&
	    ($dest->{level} & MSGLEVEL_PUBLIC) &&
	    ($dest->{level} & (MSGLEVEL_HILIGHT|MSGLEVEL_MSGS)) &&
	    ($dest->{level} & MSGLEVEL_NOHILIGHT) == 0) {

		send_notification($dest->{target} . ": $stripped");
	}
}

sub sig_message_public {
	my ($server, $msg, $nick, $address, $target) = @_;

	if ($server->{usermode_away}) {
		$IS_AWAY = 1;
	} else {
		$IS_AWAY = 0;
	}
}

sub sig_message_private {
	my ($server, $msg, $nick, $address, $target) = @_;

	if ($server->{usermode_away}) {
		send_notification("$nick: $msg");
	}
}

Irssi::signal_add('print text', \&sig_print_text);
Irssi::signal_add_last('message public', \&sig_message_public);
Irssi::signal_add_last('message private', \&sig_message_private);

Irssi::settings_add_str('misc', 'signal_phonenumber_from', '');
Irssi::settings_add_str('misc', 'signal_phonenumber_to', '');
