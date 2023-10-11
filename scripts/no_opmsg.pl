use strict;
use warnings;
use experimental 'signatures';
use Irssi;

our $VERSION = '0.1'; # 533b021b83d26b0
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'no_opmsg',
    description => 'Kill incoming op messages.',
    license     => 'ISC',
   );

our ($op_message);
sub expando_op_message {
    $op_message // ''
}

sub sig_event_op_public ($server, $recoded, $nick, $addr, $target) {
    my $statusmsg = $server->isupport('statusmsg') // '@';
    my $st = "[\Q$statusmsg\E]";
    $target =~ s/^(($st)+)//;
    local $op_message = $1;
    if ($target =~ /^!/) {
	my $ch_obj = $server->channel_find($target);
	$target = $ch_obj->{visible_name} if $ch_obj;
    }
    Irssi::signal_stop;
    Irssi::signal_emit('message public', $server, $recoded, $nick, $addr, $target);
}

Irssi::expando_create('op_message' => \&expando_op_message, { 'event privmsg' => 'none' });
Irssi::signal_add_first('message irc op_public' => 'sig_event_op_public');
