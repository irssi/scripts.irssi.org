use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '2.1';
%IRSSI = (
    authors     => 'Daenyth',
    contact     => 'Daenyth /at/ gmail /dot/ com',
    name        => 'Complete Last-Spoke',
    description => 'When using tab completion on an empty input buffer, complete to the nick of the person who spoke most recently.',
    license     => 'GPL2',
);

my %list_of_speakers;

sub complete_to_last_nick {
	my ($strings, $window, $word, $linestart, $want_space) = @_;
	return unless ($linestart eq '' && $word eq '');

	my $last_speaker = get_last_speaker($window);
	return unless defined $last_speaker;
	my $suffix = Irssi::settings_get_str('completion_char');
	@$strings = $last_speaker . $suffix;
	$$want_space = 1;
	Irssi::signal_stop();
}

sub get_last_speaker {
	my $window = shift;
	return $list_of_speakers{$window->{active}->{name}};
}

sub store_last_speaker {
	my ($server, $message, $speaker, $address, $target) = @_;
	$list_of_speakers{$target} = $speaker;
}

sub store_last_actor {
	my ($server, $args, $actor, $address, $target) = @_;
	$list_of_speakers{$target} = $actor;
}

Irssi::signal_add_first( 'complete word',  \&complete_to_last_nick );
Irssi::signal_add_last ( 'message public', \&store_last_speaker    );
Irssi::signal_add_last ( 'ctcp action',    \&store_last_actor      );

