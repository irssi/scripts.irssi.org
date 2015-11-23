use strict;
use warnings;

our $VERSION = '0.2'; # 49f841075725906
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'complete_at',
    description => 'Complete nicks after @ (twitter-style)',
    license     => 'ISC',
   );

# Usage
# =====
# write @ and type on the Tab key to complete nicks

{ package Irssi::Nick }

my $complete_char = '@';

sub complete_at {
    my ($cl, $win, $word, $start, $ws) = @_;
    if ($cl && !@$cl
	    && $win && $win->{active}
	    && $win->{active}->isa('Irssi::Channel')) {
	if ((my $pos = rindex $word, $complete_char) > -1) {
	    my ($pre, $post) = ((substr $word, 0, $pos), (substr $word, $pos + 1));
	    my $pre2 = length $start ? "$start $pre" : $pre;
	    my $pre3 = length $pre2 ? "$pre2$complete_char" : "";
	    Irssi::signal_emit('complete word', $cl, $win, $post, $pre3, $ws);
	    unless (@$cl) {
		push @$cl, grep { /^\Q$post/i } map { $_->{nick} } $win->{active}->nicks();
	    }
	    map { $_ = "$pre$complete_char$_" } @$cl;
	}
    }
}

Irssi::signal_add_last('complete word' => 'complete_at');
