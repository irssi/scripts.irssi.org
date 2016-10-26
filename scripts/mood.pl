#!/usr/bin/perl
#
# This script tracks the general mood in a channel.
# 
#
# Changelog:
# 19.03.2002
# *first release
#
# 20.03.2002
# *some regexp tweaking
#
# 07.04.2002
# *own messages can be interpreted

use strict;

use vars qw($VERSION %IRSSI);

$VERSION = "20031207";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "Mood",
    description => "Keeps track of the channel mood",
    license     => "GPLv2",
    sbitems     => "moodbar",
    changed     => "$VERSION",
);

use Irssi;
use Irssi::TextUI;
use vars qw(%channels $eye $refresh $shouting $bored_mouth);

sub find_smiley {
    my ($msg) = @_;
    my $eyes = '[:=8;]';
    my $noses = '[\-\o]?';
    my $sad = '[\(\<\[]';
    my $happy = '[\)\>\]D]';
    my %smiley = ($eyes.$noses.$happy         =>  10,
		  $sad.$noses.$eyes           =>  10,
		  $eyes.$noses.$sad           => -10,
		  $happy.$noses.$eyes         => -10,
		  $eyes.'\.+'.$noses.$sad     => -20,
		  $happy.$noses.'\.+'.$eyes   => -20,
		 );
    foreach (keys(%smiley)) {
	return($smiley{$_}) if ($msg =~ m/.*($_).*/);
    }
    return 0;
}

sub event_event_privmsg {
    my ($server, $data, $nick, $address) = @_;
    my ($target, $msg) = split(/ :/, $data,2);
    change_mood($target, find_smiley($msg));
}

sub event_message_own_public {
    my ($server, $msg, $target) = @_;
    change_mood($target, find_smiley($msg));
}

sub event_message_kick {
    my ($server, $channel, $nick, $kicker, $address, $reason) = @_;
    change_mood($channel, -20);
}

sub event_ban_new {
    my ($channel, $ban) = @_;
    my $name = $channel->{name};
    change_mood($name, -20);
}

sub event_ban_remove {
    my ($channel, $ban) = @_;
    my $name = $channel->{name};
    change_mood($name, 20);
}

sub event_netsplit_new {
    my ($netsplit) = @_;
    #FIXME Not Idea :)
    #Irssi::print $netsplit->{nick};
}

sub event_window_hilight {
    my ($window) = @_;
    open_mouth();
}

sub change_mood {
    my ($name, $points) = @_;
    if (not exists $channels{$name}) {
	$channels{lc $name} = 0;
    }
    $channels{lc $name} += $points;
    mood_refresh();
}

sub draw_smiley {
    my ($points) = @_;
    
    my $mouth = $bored_mouth;
    my $nose = Irssi::settings_get_str('mood_nose');
    
    if    ($points > 20) { $mouth = 'D'; }
    elsif ($points >  0) { $mouth = ')'; }
    elsif ($points <-20) { $mouth = '<'; }
    elsif ($points <  0) { $mouth = '('; }
    if ($shouting) { $mouth = 'O' };
    return $eye.$nose.$mouth;
}

sub mood_show {
    my ($item, $get_size_only) = @_;
    my $win = !Irssi::active_win() ? undef : Irssi::active_win()->{active};
    
    if (ref $win && ($win->{type}) and $win->{type} eq "CHANNEL") {
	my $target = lc $win->{name};
	my $face = draw_smiley($channels{$target});
	my $format = "{sb ".$face."}";
	$item->{min_size} = $item->{max_size} = length($face);
	$item->default_handler($get_size_only, $format, 0, 1);
    } else {
	$item->{min_size} = $item->{max_size} = 0;
    }
}

sub mood_decay {
    foreach (keys %channels) {
	if    ($channels{$_} < 0) {
	    $channels{$_}++;
	    mood_refresh() if (! draw_smiley($channels{$_}) eq draw_smiley($channels{$_}-1));
	} elsif ($channels{$_} > 0) {
	    $channels{$_}--;
	    mood_refresh() if (! draw_smiley($channels{$_}) eq draw_smiley($channels{$_}+1));
	}
    }
}

sub close_eyes {
    ($refresh) && Irssi::timeout_remove($refresh);
    $eye = '|';
    mood_refresh();
    $refresh=Irssi::timeout_add(200, 'open_eyes' , undef);
}

sub open_eyes {
    ($refresh) && Irssi::timeout_remove($refresh);
    $eye = ':';
    mood_refresh();
    my $min_delay = Irssi::settings_get_int('mood_blink');
    my $next_close = int( rand()*6000 + $min_delay );
    $refresh=Irssi::timeout_add($next_close, 'close_eyes', undef);
}

sub open_mouth {
    $shouting = 1;
    mood_refresh();
    Irssi::timeout_add(2000, 'close_mouth', undef);
}

sub close_mouth {
    Irssi::timeout_remove('close_mouth');
    $shouting = 0;
    mood_refresh();
}

sub mood_refresh {
    Irssi::statusbar_items_redraw('moodbar');
}

sub change_bored_mouth {
    $bored_mouth = ('\\\\\\\\', '|', '/')[int( rand(3) )];
}

#Irssi::signal_add('window item hilight', 'event_window_hilight');
Irssi::signal_add('event privmsg', 'event_event_privmsg');
Irssi::signal_add('message own_public', 'event_message_own_public');
Irssi::signal_add('message kick','event_message_kick');
Irssi::signal_add('ban new','event_ban_new');
Irssi::signal_add('ban remove','event_ban_remove');
Irssi::signal_add('netsplit new','event_netsplit_new');

Irssi::settings_add_int('misc', 'mood_blink', 6000);
Irssi::settings_add_str('misc', 'mood_nose', '-');

Irssi::statusbar_item_register('moodbar', 0, 'mood_show');

Irssi::timeout_add(5000, 'mood_decay', undef);
Irssi::timeout_add(10000, 'change_bored_mouth', undef);

close_mouth;
change_bored_mouth();
open_eyes();
