# url grabber, yes it sucks
#
# infected with the gpl virus
#
# Thomas Graf <tgraf@europe.com>
#
# version: 0.2
#
# Commands:
#
#   /URL LIST
#   /URL CLEAR
#   /URL OPEN [<nr>]
#   /URL QUOTE [<nr>]
#   /URL HEAD [<nr>]            !! Blocking !!
#   /HEAD <url>                 !! Blocking !!
#
# Config Values
#
# [url logfile]
#  url_log                log urls to url_log_file
#  url_log_file           file to save urls
#  url_log_format         format in url logfile
#  url_log_timestamp      format of timestamp in url logfile
#
# [url log in memory]
#  url_log_browser        command to execute to open url, %f will be replaced with the url
#  url_log_size           keep that many urls in the list
#
# [http head stuff]
#  url_head_format        format of HEAD output
#  url_auto_head          do a head on every url received
#  url_auto_head_format   format of auto head output
#
#
# Database installation
# - create database and user
# - create table url ( id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
#      time INT UNSIGNED, nick VARCHAR(25), target VARCHAR(25), url VARCHAR(255));
#   or similiar :)
#
#
# todo:
#
#  - fix XXX marks
#  - xml output?
#  - don't output "bytes" if content-length is not available
#  - prefix with http:// if no prefix is given

use Irssi;
use Irssi::Irc;

$VERSION = "0.2";
%IRSSI = (
    authors     => 'Thomas Graf',
    contact     => 'irssi@reeler.org',
    name        => 'url_log',
    description => 'logs urls to textfile or/and database, able to list, quote, open or `http head` saved urls.',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.reeler.org/url/',
);

use LWP;
use LWP::UserAgent;
use HTTP::Status;
use DBI;

use POSIX qw(strftime);

use strict;

my @urls;
my $user_agent = new LWP::UserAgent;

$user_agent->agent("IrssiUrlLog/0.2");

# hmm... stolen..
# -verbatim- import expand
sub expand {
  my ($string, %format) = @_;
  my ($exp, $repl);
  $string =~ s/%$exp/$repl/g while (($exp, $repl) = each(%format));
  return $string;
}
# -verbatim- end

sub print_msg
{
    Irssi::active_win()->print("@_");
}

#
# open url in brower using url_log_brower command
#
sub open_url
{
    my ($data) = @_;

    my ($nick, $target, $url) = split(/ /, $data);

    my $pid = fork();

    if ($pid) {
        Irssi::pidwait_add($pid);
    } elsif (defined $pid) { # $pid is zero here if defined
        my $data = expand(Irssi::settings_get_str("url_log_browser"), "f", $url);
        # XXX use exec
        system $data;
        exit;
    } else {
        # weird fork error
        print_msg "Can't fork: $!";
    }
}

sub head
{
    my ($url) = @_;
    my $req = new HTTP::Request HEAD => $url;
    my $res = $user_agent->request($req);
    return $res;
}

#
# do a HEAD
#
sub do_head
{
    my ($url) = @_;

    my $res = head($url);

    if ($res->code ne RC_OK) {
        Irssi::active_win()->printformat(MSGLEVEL_CRAP, 'url_head', $url, "\n" .
            $res->status_line());
    } else {

        my $t = expand(Irssi::settings_get_str("url_head_format"),
           "u", $url,
           "t", scalar $res->content_type,
           "l", scalar $res->content_length,
           "s", scalar $res->server);

        Irssi::active_win()->printformat(MSGLEVEL_CRAP, 'url_head', $url, $t);
    }
}

#
# called if url is detected, should do a HEAD and print a 1-liner
#
sub do_auto_head
{
    my ($url, $window) = @_;

    return if ($url !~ /^http:\/\//);

    my $res = head($url);

    if ($res->code ne RC_OK) {
        $window->printformat(MSGLEVEL_CRAP, 'url_auto_head', $res->status_line());
    } else {

        my $t = expand(Irssi::settings_get_str("url_auto_head_format"),
           "u", $url,
           "c", $res->code,
           "t", scalar $res->content_type,
           "l", scalar $res->content_length,
           "s", scalar $res->server);

        $window->printformat(MSGLEVEL_CRAP, 'url_auto_head', $t);
    }
}

#
# log url to file
#
sub log_to_file
{
    my ($nick, $target, $text) = @_;
    my ($lfile) = glob Irssi::settings_get_str("url_log_file");

    if ( open(LFD, ">> $lfile") ) {

        my %h = {
            time => time,
            nick => $nick,
            target => $target,
            url => $text
        };

        print LFD expand(Irssi::settings_get_str("url_log_format"),
          "s", strftime(Irssi::settings_get_str("url_log_timestamp_format"), localtime),
          "n", $nick,
          "t", $target,
          "u", $text), "\n";

        close LFD;
    } else {
        print_msg "Warning: Unable to open file $lfile $!";
    }
}


#
# log url to database
#
sub log_to_database
{
    my ($nick, $target, $text) = @_;

    # this is quite expensive, but...
    my $dbh = DBI->connect(Irssi::settings_get_str("url_log_db_dsn"),
                           Irssi::settings_get_str("url_log_db_user"),
                           Irssi::settings_get_str("url_log_db_password"))
    or print_msg "Can't connect to database " . $DBI::errstr;

    if ($dbh) {

        my $sql = "INSERT INTO url (time, nick, target, url) VALUES (UNIX_TIMESTAMP()," .
          $dbh->quote($nick) . "," . $dbh->quote($target) . "," . $dbh->quote($text) . ")";

        $dbh->do($sql) or print_msg "Can't execute sql command: " . $DBI::errstr;

        $dbh->disconnect();
    }
}

#
# head command handler
#
sub sig_head
{
    my ($cmd_line, $server, $win_item) = @_;
    my @args = split(' ', $cmd_line);

    my $url;

    if (@args <= 0) {

        if ($#urls eq 0) {
            return;
        }

        $url = $urls[$#urls];
        $url =~ s/^.*?\s.*?\s//;
    } else {
        $url = lc(shift(@args));
    }

    do_head($url);
}

#
# msg handler
#
sub sig_msg
{
    my ($server, $data, $nick, $address) = @_;
    my ($target, $text) = split(/ :/, $data, 2);

    # very special, but better than just \w::/* and www.*
    while ($text =~ s#.*?(^|\s)(\w+?://.+?|[\w\.]{3,}/[\w~\.]+?(/|/\w+?\.\w+?))(\s|$)(.*)#$5#i) {

        return if ($1 =~ /^\.\./);

        push @urls, "$nick $target $2";

        # XXX resize correctly if delta is > 1
        if ($#urls >= Irssi::settings_get_int("url_log_size")) {
            shift @urls;
        }

        my $ischannel = $server->ischannel($target);
        my $level = $ischannel ? MSGLEVEL_PUBLIC : MSGLEVEL_MSGS;
        $target = $nick unless $ischannel;
        my $window = $server->window_find_closest($target, $level);

        if ( Irssi::settings_get_bool("url_log_auto_head") ) {
            do_auto_head($2, $window);
        }

        if ( Irssi::settings_get_bool("url_log") ) {
            log_to_file($nick, $target, $2);
        }

        if ( Irssi::settings_get_bool("url_log_db") ) {
            log_to_database($nick, $target, $2);
        }
    }
}

sub print_url_list_item
{
    my ($n, $data) = @_;
    my ($src, $dst, $url) = split(/ /, $data);

    Irssi::active_win()->printformat(MSGLEVEL_CRAP, 'url_list', $n, $src, $dst, $url);
}

#
# url command handler
#
sub sig_url
{
    my ($cmd_line, $server, $win_item) = @_;
    my @args = split(' ', $cmd_line);

    if (@args <= 0) {
        print_msg "URL LIST [<nr>]       list all url(s)";
        print_msg "    OPEN [<nr>]       open url in browser";
        print_msg "    QUOTE [<nr>]      quote url (print to current channel)";
        print_msg "    HEAD              send HEAD to server";
        print_msg "    CLEAR             clear url list";
        return;
    }

    my $action = lc(shift(@args));

    if ($action eq "list") {

        if (@args > 0) {
            my $i = shift(@args);
            print_url_list_item($i, $urls[$i]);
        } else {
            my $i = 0;
            foreach my $l (@urls) {
                print_url_list_item($i, $l);
                $i++;
            }
        }

    } elsif($action eq "open") {

        my $i = $#urls;
        if (@args > 0) {
            $i = shift(@args);
        }
        open_url($urls[$i]);

    } elsif ($action eq "quote") {

        my $i = $#urls;
        if (@args > 0) {
            $i = shift(@args);
        }
        Irssi::active_win()->command("SAY URL: " . $urls[$i]);

    } elsif ($action eq "clear") {

        splice @urls;

    } elsif ($action eq "head") {

        my $i = $#urls;
        if (@args > 0) {
            $i = shift(@args);
        }
        my $url = $urls[$i];
        $url =~ s/^.*?\s.*?\s//;

        do_head($url);

    } else {
        print_msg "Unknown action";
    }
}


Irssi::command_bind('head', 'sig_head');
Irssi::command_bind('url', 'sig_url');
Irssi::signal_add_first('event privmsg', 'sig_msg');

Irssi::settings_add_bool("url_log", "url_log", 1);
Irssi::settings_add_bool("url_log", "url_log_auto_head", 1);
Irssi::settings_add_bool("url_log", "url_log_db", 0);
Irssi::settings_add_str("url_log", "url_log_db_dsn", 'DBI:mysql:irc_url:localhost');
Irssi::settings_add_str("url_log", "url_log_db_user", 'irc_url');
Irssi::settings_add_str("url_log", "url_log_db_password", 'nada');
Irssi::settings_add_str("url_log", "url_log_file", "~/.irssi/url");
Irssi::settings_add_str("url_log", "url_log_timestamp_format", '%c');
Irssi::settings_add_str("url_log", "url_log_format", '%s %n %t %u');
Irssi::settings_add_str("url_log", "url_log_browser", 'galeon -n -x %f > /dev/null');
Irssi::settings_add_int("url_log", "url_log_size", 25);
Irssi::settings_add_str("url_log", "url_auto_head_format", '%c %t %l bytes');
Irssi::settings_add_str("url_log", "url_head_format", '
Content-Type: %t
Length:       %l bytes
Server:       %s');


Irssi::theme_register(['url_head', '[%gHTTP Head%n %g$0%n]$1-',
                       'url_auto_head', '[%gHEAD%n] $0-',
                       'url_list', '[$0] $1 %W$2%n $3-']);
