use strict;
use warnings;
use vars qw($VERSION %IRSSI);
use Irssi;

$VERSION = '0.0.7';
%IRSSI = (
	name => 'fnotify',
	authors => 'Tyler Abair, Thorsten Leemhuis, James Shubin' .
               ', Serge van Ginderachter, Michael Davies',
	contact => 'fedora@leemhuis.info, serge@vanginderachter.be',
	description => 'Write notifications to a file in a consistent format.',
	license => 'GNU General Public License',
	url => 'http://www.leemhuis.info/files/fnotify/fnotify https://ttboj.wordpress.com/',
);

#
#	README
#
# To use:
# $ cp fnotify.pl ~/.irssi/scripts/fnotify.pl
# irssi> /load perl
# irssi> /script load fnotify
# irssi> /set fnotify_ignore_hilight 0 # ignore hilights of priority 0
# irssi> /set fnotify_own on           # turn on own notifications
#

#
#	AUTHORS
#
# Add self to notification file
# version 0.0.7
# Michael Davies <michael@the-davies.net>
#
# Ignore hilighted messages with priority = fnotify_ignore_hilight
# version: 0.0.6
# Tyler Abair <tyler.abair@gmail.com>
#
# Strip non-parsed left over codes (Bitlbee otr messages)
# version: 0.0.5
# Serge van Ginderachter <serge@vanginderachter.be>
#
# Consistent output formatting by James Shubin:
# version: 0.0.4
# https://ttboj.wordpress.com/
# note: changed license back to original GPL from Thorsten Leemhuis (svg)
#
# Modified from the Thorsten Leemhuis <fedora@leemhuis.info>
# version: 0.0.3
# http://www.leemhuis.info/files/fnotify/fnotify
#
# In parts based on knotify.pl 0.1.1 by Hugo Haas:
# http://larve.net/people/hugo/2005/01/knotify.pl
#
# Which is based on osd.pl 0.3.3 by Jeroen Coekaerts, Koenraad Heijlen:
# http://www.irssi.org/scripts/scripts/osd.pl
#
# Other parts based on notify.pl from Luke Macken:
# http://fedora.feedjack.org/user/918/
#

my %config;

Irssi::settings_add_int('fnotify', 'fnotify_ignore_hilight' => -1);
$config{'ignore_hilight'} = Irssi::settings_get_int('fnotify_ignore_hilight');

Irssi::settings_add_bool('fnotify', 'fnotify_own', 0);
$config{'own'} = Irssi::settings_get_bool('fnotify_own');

Irssi::signal_add(
    'setup changed' => sub {
        $config{'ignore_hilight'} = Irssi::settings_get_int('fnotify_ignore_hilight');
        $config{'own'} = Irssi::settings_get_bool('fnotify_own');
    }
);

#
#	catch private messages
#
sub priv_msg {
	my ($server, $msg, $nick, $address, $target) = @_;
	my $msg_stripped = Irssi::strip_codes($msg);
	my $network = $server->{tag};
	filewrite('' . $network . ' ' . $nick . ' ' . $msg_stripped);
}

#
#	catch 'hilight's
#
sub hilight {
	my ($dest, $text, $stripped) = @_;
    my $ihl = $config{'ignore_hilight'};
	if ($dest->{level} & MSGLEVEL_HILIGHT && $dest->{hilight_priority} != $ihl) {
		my $server = $dest->{server};
		my $network = $server->{tag};
		filewrite($network . ' ' . $dest->{target} . ' ' . $stripped);
	}
}

#
#	catch own messages
#
sub own_public {
	my ($dest, $msg, $target) = @_;
	if ($config{'own'}) {
		filewrite($dest->{'nick'} . ' ' .$msg );
	}
}

sub own_private {
	my ($dest, $msg, $target, $orig_target) = @_;
	if ($config{'own'}) {
		filewrite($dest->{'nick'} . ' ' .$msg );
	}
}

#
#	write to file
#
sub filewrite {
	my ($text) = @_;
	my $fnfile = Irssi::get_irssi_dir() . "/fnotify";
	if (!open(FILE, ">>", $fnfile)) {
		print CLIENTCRAP "Error: cannot open $fnfile: $!";
	} else {
		print FILE $text . "\n";
		if (!close(FILE)) {
			print CLIENTCRAP "Error: cannot close $fnfile: $!";
		}
	}
}

#
#	irssi signals
#
Irssi::signal_add_last("message private", "priv_msg");
Irssi::signal_add_last("print text", "hilight");
Irssi::signal_add_last("message own_public", "own_public");
Irssi::signal_add_last("message own_private", "own_private");

