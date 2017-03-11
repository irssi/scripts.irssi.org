# by Stefan 'tommie' Tomanek <stefan@pico.ruhr.de>
#
#

use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "20170204";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "postpone",
    description => "Postpones messages sent to a splitted user and resends them when the nick rejoins",
    license     => "GPLv2",
    changed     => "$VERSION",
    commands     => "postpone"
);

use Irssi 20020324;
use vars qw(%messages);

sub draw_box ($$$$) {
    my ($title, $text, $footer, $colour) = @_;
    my $box = '';
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {
        $box .= '%R|%n '.$_."\n";
    }
    $box .= '%R`--<%n'.$footer.'%R>->%n';
    $box =~ s/%.//g unless $colour;
    return $box;
}

sub show_help() {
    my $help="Postpone $VERSION
/postpone help
    Display this help
/postpone flush <nick>
    Flush postponed messages to <nick>
/postpone discard <nick>
    Discard postponed messages to <nick>
/postpone list
    List postponed messages
";
    my $text = '';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP &draw_box("Postpone", $text, "help", 1);
}


sub event_send_text ($$$) {
    my ($line, $server, $witem) = @_;
    return unless ($witem && $witem->{type} eq "CHANNEL");
    if ($line =~ /^(\w+?): (.*)$/) {
	my ($target, $msg) = ($1,$2);
	if ($witem->nick_find($target)) {
	    # Just leave me alone
	    return;
	} else {
	    $witem->print("%B>>%n %U".$target."%U is not here, message has been postponed: \"".$line."\"", MSGLEVEL_CLIENTCRAP);
	    push @{$messages{$server->{tag}}{$witem->{name}}{$target}}, $line;
	    Irssi::signal_stop();
	}
    }
}

sub event_message_join ($$$$) {
    my ($server, $channel, $nick, $address) = @_;
    return unless (defined $messages{$server->{tag}});
    return unless (defined $messages{$server->{tag}}{$channel});
    return unless (defined $messages{$server->{tag}}{$channel}{$nick});
    return unless (scalar(@{$messages{$server->{tag}}{$channel}{$nick}}) > 0);
    my $chan = $server->channel_find($channel);
    $chan->print("%B>>%n Sending postponed messages for ".$nick, MSGLEVEL_CLIENTCRAP);
    while (scalar(@{$messages{$server->{tag}}{$channel}{$nick}}) > 0) {
	my $msg = pop @{$messages{$server->{tag}}{$channel}{$nick}};
	$server->command('MSG '.$channel.' '.$msg);
    }
    
}

sub cmd_postpone ($$$) {
    my ($args, $server, $witem) = @_;
    my @arg = split(/ /, $args);
    if (scalar(@arg) < 1) {
	#foo
    } elsif (($arg[0] eq 'discard' || $arg[0] eq 'flush') && defined $arg[1]) {
	return unless ($witem && $witem->{type} eq "CHANNEL");
	while (scalar(@{$messages{$server->{tag}}{$witem->{name}}{$arg[1]}}) > 0) {
	    my $msg = pop @{$messages{$server->{tag}}{$witem->{name}}{$arg[1]}};
	    $server->command('MSG '.$witem->{name}.' '.$msg) if $arg[0] eq 'flush';
	}
    } elsif ($arg[0] eq 'list') {
	my $text;
	foreach (keys %messages) {
	    $text .= $_."\n";
	    foreach my $channel (keys %{$messages{$_}}) {
		$text .= " %U".$channel."%U \n";
		foreach my $nick (sort keys %{$messages{$_}{$channel}}) {
		    $text .= ' |'.$_."\n" foreach @{$messages{$_}{$channel}{$nick}};
		}
	    }
	}
	print CLIENTCRAP &draw_box('Postpone', $text, 'messages', 1);
    } elsif ($arg[0] eq 'help') {
	show_help();
    }
}

Irssi::command_bind('postpone', \&cmd_postpone);

Irssi::signal_add('send text', \&event_send_text);
Irssi::signal_add('message join', \&event_message_join);

print CLIENTCRAP "%B>>%n Postpone ".$VERSION." loaded: /postpone help for help";

