#!/usr/bin/perl
#

use strict;
use vars qw($VERSION %IRSSI);
$VERSION = '2003071904';
%IRSSI = (
    authors     => 'Stefan \'tommie\' Tomanek',
    contact     => 'stefan@pico.ruhr.de',
    name        => 'Forward',
    description => 'forward incoming messages to another nick',
    license     => 'GPLv2',
    url         => 'http://irssi.org/scripts/',
    changed     => $VERSION,
    modules     => '',
    commands    => "forward"
);

use Irssi 20020324;

use vars qw(%forwards);

sub show_help() {
    my $help = $IRSSI{name}." ".$VERSION."
/forward to <nick>
    Forward incoming messages to <nick>
/forward remove
    Disable forwarding in the current chatnet

You can remotely en- or disable forwarding by sending an
ctcp command to your client. Set a password and use
 /CTCP <nickname> forward <password>
or
 /CTCP <nickname> noforward
to enable or diable forwarding to your current nick.
";
    my $text='';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }   
    print CLIENTCRAP &draw_box($IRSSI{name}, $text, $IRSSI{name}." help", 1);
}

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

sub sig_message_private ($$$$) {
    my ($server, $msg, $nick, $address) = @_;
    my $chatnet = $server->{chatnet};
    return unless defined $forwards{$chatnet};
    if ($forwards{$chatnet}{active}) {
	my $to = $forwards{$chatnet}{to};
	my $text = "[forwarded MSG from ".$nick."] ".$msg;
	$server->command("notice $to ".$text);
    }
}

sub sig_ctcp_msg_forward ($$$$$) {
    my ($server, $args, $nick, $address, $target) = @_;
    my $pass = Irssi::settings_get_str('forward_remote_password');
    unless ($pass) {
	print CLIENTCRAP '%R>>%n No forward password set, forwarding not enabled!';
	$server->command("nctcp ".$nick." FORWARD Forwarding forbidden!");
	return 0;
    }
    if ($pass eq $args) {
	$server->command("nctcp ".$nick." FORWARD Forwarding enabled");
	set_forward($server->{chatnet}, $nick);
    }
}

sub sig_ctcp_msg_noforward ($$$$$) {
    my ($server, $args, $nick, $address, $target) = @_;
    my $chatnet = $server->{chatnet};
    return unless defined $forwards{$chatnet};
    return unless ($forwards{$chatnet}{to} eq $nick);
    $server->command("nctcp ".$nick." NOFORWARD Forwarding disabled");
    remove_forward($server->{chatnet});
}


sub set_forward ($$) {
    my ($chatnet, $nick) = @_;
    print CLIENTCRAP "%B>>%n Forwarding messages from $chatnet to > $nick <";
    $forwards{$chatnet}{to} = $nick;
    $forwards{$chatnet}{active} = 1;
}

sub remove_forward ($) {
    my ($chatnet) = @_;
    delete $forwards{$chatnet};
    print CLIENTCRAP "%B>>%n No longer forwarding messages from $chatnet";
}

sub cmd_forward ($$$) {
    my ($arg, $server, $witem) = @_;
    return unless defined $server;
    my @args = split(/ /, $arg);
    if (@args < 1 || $args[0] eq 'help') {
	show_help();
    } elsif (@args[0] eq 'to') {
	shift @args;
	return unless @args;
	set_forward($server->{chatnet}, $args[0]);
    } elsif (@args[0] eq 'remove') {
	remove_forward($server->{chatnet});
    }
}


Irssi::signal_add('message private', \&sig_message_private);
Irssi::signal_add('ctcp msg forward', \&sig_ctcp_msg_forward);
Irssi::signal_add('ctcp msg noforward', \&sig_ctcp_msg_noforward);
Irssi::settings_add_str($IRSSI{name}, 'forward_remote_password', '');

Irssi::command_bind('forward' => \&cmd_forward);

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /forward help for help';
