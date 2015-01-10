# Watch script para irssi

# watch script consiste en un pequeño script que interpreta
# este novedoso sistema de notify que nos evita la tarea de
# tener que comprobar cada X tiempo si alguien de nuestro notify
# esta en el irc, este script solamente podra ser usado en redes
# que lo permitan, como por ejemplo irc-hispano.

use strict;
use vars qw($VERSION %IRSSI);
$VERSION = '1.0';
%IRSSI = (
 authors     => 'ThEbUtChE',
 contact     => 'thebutche@interec.org',
 name        => 'Watch script',
 description => 'Uso del comando watch para irssi.',
 license     => 'BSD',
 url         => 'http://www.nebulosa.org',
 changed     => 'viernes, 17 de enero de 2003, 03:19:15 CET',
 bugs        => 'ninguno'
);

use Irssi;
use Irssi::Irc;
use POSIX qw(floor);



sub watch_list
{
    my($file) = Irssi::get_irssi_dir."/watch";
    my($nick);
    local(*FILE);

    open FILE, "<", $file;
    while (<FILE>) {
	    my @nick = split;
	    Irssi::print "Notify \002@nick[0]\002";
    }
    close FILE;
}

sub esta_notify
{
	my ($ni) = @_;

    my($file) = Irssi::get_irssi_dir."/watch";
    my($nick);
    local(*FILE);
    open FILE, "<", $file;
    while (<FILE>) {
        my @nick = split;
	    if (@nick[0] eq $ni) { return 1; }
    }
    close FILE;
    return 0;
}

sub watch_add
{
	my ($nick) = @_;
	my($file) = Irssi::get_irssi_dir."/watch";
    local(*FILE);
	if ($nick eq "") { Irssi::print "Debes decir un nick a incluir en la lista."; return; 
	} elsif (esta_notify($nick)) { Irssi::print "El nick ya esta en el notify."; return; }

    open FILE, ">>", $file;
                print FILE join("\t","$nick\n");
    close FILE;
    Irssi::print "El nick $nick ha sido metido en el notify";
    Irssi::active_win()->command("quote watch +$nick");

}

sub watch_del
{
	my ($ni) = @_;
        my($file) = Irssi::get_irssi_dir."/watch";
        my($file2) = Irssi::get_irssi_dir."/watch2";
	    local(*FILE);
	    local(*FILE2);
        if ($ni eq "") { Irssi::print "Debes decir un nick a borrar de la lista."; return;
        } elsif (!esta_notify($ni)) { Irssi::print "El nick no esta en el notify."; return; }

    open FILE2, ">", $file2;
        print FILE2 "";
    close FILE2;

    open FILE, "<", $file;
    open FILE2, ">>", $file2;
    while (<FILE>) {
        my @nick = split;
        if (@nick[0] eq $ni) { 
	    } else {
            print FILE2 join("\t","@nick[0]\n");
	    }
    }
    close FILE;
    close FILE2;

    open FILE, ">", $file;
	print FILE "";
    close FILE;

    open FILE, ">>", $file;
    open FILE2, "<", $file2;
    while (<FILE2>) {
        my @nick = split;
		print FILE join("\t","@nick[0]\n");
    }
    close FILE;
    close FILE2;

    Irssi::active_win()->command("quote watch -$ni");
    Irssi::print "Usuario \002$ni\002 Borrado de la lista de notify";

}

sub watch_list_online
{
    Irssi::active_win()->command("quote watch l");
}

sub watch 
{
	my ($arg) = @_;
	my ($cmd, $nick) = split(/ /, $arg);
	if ($cmd eq "list") {
		watch_list();
	} elsif ($cmd eq "add") {
		watch_add($nick);
	} elsif ($cmd eq "del") {
		watch_del($nick);
	} else {
		watch_list_online();
	}
}

sub mete_lista
{
    my($file) = Irssi::get_irssi_dir."/watch";
    my($nick);
    local(*FILE);
	my $ret;
    open FILE, "<", $file;
    while (<FILE>) {
        my @nick = split;
	    $ret .= "+@nick[0],";
    }
	chop $ret;
    Irssi::active_win()->command("quote watch $ret");
    close FILE;
}

sub event_is_online
{
	my ($server, $data) = @_;
	my ($me, $nick, $ident, $host) = split(/ /, $data);
    Irssi::print "\002$nick\002 \0034[\003$ident\@$host\0034]\003 has joined to IRC";
}

sub event_is_offline
{
	my ($server, $data) = @_;
	my ($me, $nick) = split(/ /, $data);
    Irssi::print "\002$nick\002 has left IRC";
}

sub null
{
}

Irssi::command_bind('watch', 'watch');
Irssi::signal_add_last('event connected', 'mete_lista');
Irssi::signal_add('event 604', 'event_is_online');
Irssi::signal_add('event 605', 'null');
Irssi::signal_add('event 601', 'event_is_offline');
Irssi::signal_add('event 600', 'event_is_online');

