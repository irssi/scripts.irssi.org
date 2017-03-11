# Copyright (C) 2015 Felipe F. Tonello <eu@felipetonello.com>
#
# Based on fnotify.pl 0.0.5 by Thorsten Leemhuis, James Shubin and
#   Serge van Ginderachter
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# NOTE:
# This program requires libnotify, perl-glib-object-introspection and
# perl-html-parser packages

use strict;
use Irssi;
use HTML::Entities;
use Glib::Object::Introspection; # Ignore 'late INIT' warning message if autoloading
use Encode;

our $VERSION = '1.0.1';
our %IRSSI = (
	authors     => 'Felipe F. Tonello',
	contact     => 'eu@felipetonello.com',
	name        => 'desktop-notify',
	description => 'Sends notification using the Desktop Notifications Specification.',
	license     => 'GPL v3+',
);

# /set notify_icon <icon-name>
# List of standard icons can be found here:
# http://standards.freedesktop.org/icon-naming-spec/icon-naming-spec-latest.html#names
my $notify_icon;
my $term_charset;

my $help = '
/set notify_icon <icon-name>
    Change notificationicon (default is mail-message-new). A complete list of standard ' .
'icons can be found here: ' .
'http://standards.freedesktop.org/icon-naming-spec/icon-naming-spec-latest.html#names
';

sub init {
	Glib::Object::Introspection->setup(
		basename => 'Notify',
		version => '0.7',
		package => 'Notify');
	Notify::init('Irssi');
}

sub UNLOAD {
	Notify::uninit();
}

sub setup_changed {
	$notify_icon = Irssi::settings_get_str('notify_icon');
	$term_charset = Irssi::settings_get_str('term_charset');
}

sub priv_msg {
	my ($server, $msg, $nick, $address) = @_;
	my $window = Irssi::active_win();

	# We shouldn't notify if active window is the same as the private message
	if ($window->{active}->{name} eq $nick) {
		return;
	}

	my $msg = HTML::Entities::encode_entities(Irssi::strip_codes($msg), "\<>&'");
	my $network = $server->{tag};
	my $noti = Notify::Notification->new($nick . '@' . $network, decode($term_charset, $msg), $notify_icon);
	$noti->show();
}

sub hilight {
	my ($dest, $text, $stripped) = @_;
	my $server = $dest->{server};
	my $window = Irssi::active_win();

	# Check if we should notify user of message:
	# * if message is notice or highligh type
	# * if the channel belongs to the current server
	# * if the user is not focused on the channel window
	if (!($server &&
		  $dest->{level} & (MSGLEVEL_HILIGHT | MSGLEVEL_NOTICES) &&
		  $server->ischannel($dest->{target}) &&
		  $window->{refnum} != $dest->{window}->{refnum})) {
		return;
	}

	my $network = $server->{tag};
	my $msg = HTML::Entities::encode_entities($stripped, "\'<>&");
	my $noti = Notify::Notification->new($dest->{target} . '@' . $network, decode($term_charset, $msg), $notify_icon);
	$noti->show();
}

Irssi::settings_add_str('desktop-notify', 'notify_icon', 'mail-message-new');

Irssi::signal_add('setup changed' => \&setup_changed);
Irssi::signal_add_last('message private' => \&priv_msg);
Irssi::signal_add_last('print text' => \&hilight);

Irssi::command_bind('help', sub {
		if ($_[0] eq $IRSSI{name}) {
			Irssi::print($help, MSGLEVEL_CLIENTCRAP);
			Irssi::signal_stop();
		}
	}
);

init();
setup_changed();
