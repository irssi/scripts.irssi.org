# by Stefan 'tommie' Tomanek
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "2002123101";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "NoteServ",
    description => "Utilizes NoteServ to implement a buddylist",
    license     => "GPLv2",
    changed     => "$VERSION",
    sbitems     => "noteserv"
);

use Irssi;
use Irssi::Irc;
use Irssi::TextUI;

use vars qw(%notifies);

sub sig_event_connected ($) {
    my ($server) = @_;
    my $net = Irssi::settings_get_str('noteserv_ircnet');
    return unless (lc $server->{tag} eq lc $net);
    my $username = Irssi::settings_get_str('noteserv_login');
    my $password = Irssi::settings_get_str('noteserv_password');
    return unless $username && $password;
    $server->command('squery noteserv login '.$username.' '.$password);
    $server->command('squery noteserv notify');
}

sub sig_server_disconnected ($) {
    my ($server) = @_;
    my $net = Irssi::settings_get_str('noteserv_ircnet');
    return unless (lc $server->{tag} eq lc $net);
    %notifies = ();
}

sub sig_message_irc_notice ($$$) {
    my ($server, $msg, $nick, $address, $target) = @_;
    return unless lc $nick eq 'noteserv';
    #print $msg;
    if ($msg =~ /\d+\. Notify: (.*?)\!(.*?)\@(.*?) \(.*?\)/) {
	my ($name, $user, $host, $time) = ($1,$2,$3,$4);
    } elsif ($msg =~ /^(.*?) \((.*?)\) is on \(.*?\)/) {
	$notifies{$1} = { mask => $2, status => 1 };
	Irssi::statusbar_items_redraw('noteserv');
	Irssi::signal_stop() if Irssi::settings_get_bool('noteserv_hide_messages');
    } elsif ($msg =~ /^(.*?) \((.*?)\) gets (in)?visible/) {
	$notifies{$1} = { mask => $2, status => not defined $3 };
	Irssi::statusbar_items_redraw('noteserv');
	Irssi::signal_stop() if Irssi::settings_get_bool('noteserv_hide_messages');
    } elsif ($msg =~ /^(.*?) \((.*?)\) signs (on|off)/) {
	$notifies{$1} = { mask => $2, status => ($3 eq 'on') };
	Irssi::statusbar_items_redraw('noteserv');
	Irssi::signal_stop() if Irssi::settings_get_bool('noteserv_hide_messages');
    }
}

sub draw_bar ($$) {
    my ($item, $get_size) = @_;
    my $line = "";
    foreach (keys %notifies) {
	if ($notifies{$_}{status}) {
	    $line .= '%Go%n';
	} else {
	    $line .= '%Ro%n';
	}
	$line .= ' '.$_.' ';
    }
    my $format = "{sb ".$line."}";
    $item->{min_size} = $item->{max_size} = length($line);
    $item->default_handler($get_size, $format, 0, 1);
}

Irssi::signal_add('message irc notice', \&sig_message_irc_notice);
Irssi::statusbar_item_register('noteserv', 0, "draw_bar");

Irssi::settings_add_str('NoteServ', 'noteserv_ircnet', 'IRCNet');
Irssi::settings_add_str('NoteServ', 'noteserv_login', '');
Irssi::settings_add_str('NoteServ', 'noteserv_password', '');
Irssi::settings_add_bool('NoteServ', 'noteserv_show_offline', 1);
Irssi::settings_add_bool('NoteServ', 'noteserv_hide_messages', 0);

Irssi::signal_add('event connected', \&sig_event_connected);
Irssi::signal_add('server disconnected', \&sig_server_disconnected);

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded';
