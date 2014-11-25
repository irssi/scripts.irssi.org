# todo: grap topic changes

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '0.0.3';
%IRSSI = (
	authors     => 'Thorsten Leemhuis',
	contact     => 'fedora@leemhuis.info',
	name        => 'fnotify',
	description => 'Write a notification to a file that shows who is talking to you in which channel.',
	url         => 'http://www.leemhuis.info/files/fnotify/',
	license     => 'GNU General Public License',
	changed     => '$Date: 2007-01-13 12:00:00 +0100 (Sat, 13 Jan 2007) $'
);

#--------------------------------------------------------------------
# In parts based on knotify.pl 0.1.1 by Hugo Haas
# http://larve.net/people/hugo/2005/01/knotify.pl
# which is based on osd.pl 0.3.3 by Jeroen Coekaerts, Koenraad Heijlen
# http://www.irssi.org/scripts/scripts/osd.pl
#
# Other parts based on notify.pl from Luke Macken
# http://fedora.feedjack.org/user/918/
#
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# Private message parsing
#--------------------------------------------------------------------

sub priv_msg {
	my ($server,$msg,$nick,$address,$target) = @_;
	filewrite($nick." " .$msg );
}

#--------------------------------------------------------------------
# Printing hilight's
#--------------------------------------------------------------------

sub hilight {
    my ($dest, $text, $stripped) = @_;
    if ($dest->{level} & MSGLEVEL_HILIGHT) {
	filewrite($dest->{target}. " " .$stripped );
    }
}

#--------------------------------------------------------------------
# The actual printing
#--------------------------------------------------------------------

sub filewrite {
	my ($text) = @_;
	# FIXME: there is probably a better way to get the irssi-dir...
        open(FILE,">>$ENV{HOME}/.irssi/fnotify");
	print FILE $text . "\n";
        close (FILE);
}

#--------------------------------------------------------------------
# Irssi::signal_add_last / Irssi::command_bind
#--------------------------------------------------------------------

Irssi::signal_add_last("message private", "priv_msg");
Irssi::signal_add_last("print text", "hilight");

#- end
