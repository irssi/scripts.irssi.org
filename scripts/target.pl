use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "2003020801";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "Target",
    description => "advances IRC warfare to the next level ;)",
    license     => "GPLv2",
    url         => "http://scripts.irssi.org",
    sbitems     => 'target',
    changed     => "$VERSION",
    commands	=> "target"
);

use Irssi 20020324;
use Irssi::TextUI;
use vars qw(%target);

sub draw_box ($$$$) {
    my ($title, $text, $footer, $colour) = @_;
    my $box = '';
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {
        $box .= '%R|%n '.$_."\n";
    }                                                                               $box .= '%R`--<%n'.$footer.'%R>->%n';
    $box =~ s/%.//g unless $colour;
    return $box;
}

sub show_help() {
    my $help=$IRSSI{name}." ".$VERSION."
/target lock <nick>
    Target <nick> for current channel
/target unlock
    Unlock current target
/target kick [reason]
    Kick the locked target
/target ban [reason]
    Knockout the selected target
";
    my $text = '';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP draw_box($IRSSI{name}." help", $text, "help", 1) ;
}


sub lock_target ($$$) {
    my ($server, $channel, $nick) = @_;
    my $witem = $server->window_find_item($channel);
    $witem->print("%R>>%n Target acquired: +>".$nick."<+", MSGLEVEL_CLIENTCRAP) if (ref $witem && not $target{$server->{tag}}{$channel} eq $nick);
    $target{$server->{tag}}{$channel} = $nick;
    Irssi::statusbar_items_redraw('target');
}

sub unlock_target ($$) {
    my ($server, $channel) = @_;
    delete $target{$server->{tag}}{$channel};
    delete $target{$server->{tag}} unless (keys %{ $target{$server->{tag}} });
    Irssi::statusbar_items_redraw('target');
}

sub kick_target ($$$$) {
    my ($server, $witem, $ban, $reason) = @_;
    my $nick = $target{$server->{tag}}{$witem->{name}};
    return unless $nick;
    #my $reason = 'Target destroyed';
    my $cmd = 'kick '.$nick.' '.$reason;
    if ($ban) {
	$cmd = 'kn '.$nick.' '.$reason;
    }
    $witem->command($cmd);
}

sub sb_target ($$) {
    my ($item, $get_size_only) = @_;
    my $line = '';
    my $witem = Irssi::active_win()->{active};
    if (ref $witem && $witem->{type} eq 'CHANNEL') {
	my $tag = $witem->{server}->{tag};
	if ($target{$tag}{$witem->{name}}) {
	    $line .= '+>';
	    if ($witem->nick_find($target{$tag}{$witem->{name}})) {
		$line .= '%R';
	    } else {
		$line .= '%y';
	    }
	    $line .= $target{$tag}{$witem->{name}};
	    $line .= '%n';
	    $line .= '<+';
	}
    }
    my $format = "{sb ".$line."}";
    $item->{min_size} = $item->{max_size} = length($line);
    $item->default_handler($get_size_only, $format, 0, 1);
}

sub sig_message_kick ($$$$$$) {
    my ($server, $channel, $nick, $kicker, $address, $reason) = @_;
    if (Irssi::settings_get_bool('target_lock_only_on_own_kicks')) {
	return unless ($kicker eq $server->{nick});
    }
    lock_target($server, $channel, $nick);
    Irssi::statusbar_items_redraw('target');
}

sub cmd_target ($$$) {
    my ($args, $server, $witem) = @_;
    my @arg = split(/ +/, $args);
    if (@arg == 0) {
	# list targets
	show_help();
    } elsif ($arg[0] eq 'lock') {
	return unless $server;
	return unless ref $witem;
	return unless $witem->{type} eq 'CHANNEL';
	return unless defined $arg[1];
	lock_target($server, $witem->{name}, $arg[1]);
    } elsif ($arg[0] eq 'unlock') {
	return unless $server;
        return unless ref $witem;
        return unless $witem->{type} eq 'CHANNEL';
	unlock_target($server, $witem->{name});
    } elsif ($arg[0] eq 'kick') {
	shift @arg;
	return unless $server;
	return unless ref $witem;
	return unless $witem->{type} eq 'CHANNEL';
        my $reason = @arg ? join(" ", @arg) : 'Target destroyed';;
	kick_target($server, $witem, 0, $reason);
    } elsif ($arg[0] eq 'ban') {
	shift @arg;
        return unless $server;
        return unless ref $witem;
        return unless $witem->{type} eq 'CHANNEL';
        my $reason = @arg ? join(" ", @arg) : 'Target destroyed';;
        kick_target($server, $witem, 1, $reason);
    } elsif ($arg[0] eq 'help') {
	show_help();
    }
}


Irssi::signal_add('message join', sub { Irssi::statusbar_items_redraw('target'); });
Irssi::signal_add('message part', sub { Irssi::statusbar_items_redraw('target'); });
Irssi::signal_add('window item changed', sub { Irssi::statusbar_items_redraw('target'); });
Irssi::signal_add('window changed', sub { Irssi::statusbar_items_redraw('target'); });
Irssi::signal_add('message kick', \&sig_message_kick);
Irssi::statusbar_item_register('target', 0, 'sb_target');

Irssi::settings_add_bool($IRSSI{name}, 'target_lock_only_on_own_kicks', 0);

Irssi::command_bind('target', \&cmd_target);
foreach my $cmd ('lock', 'unlock', 'kick', 'ban', 'help') {
    Irssi::command_bind('target '.$cmd => sub {
        cmd_openurl("$cmd ".$_[0], $_[1], $_[2]); });
}

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /target help for help';
