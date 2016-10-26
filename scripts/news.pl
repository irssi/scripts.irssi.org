#
# This script requires external perl module News::NNTPClient. You can download
# sources of this module from:
#		http://www.cpan.org/authors/id/RVA/NNTPClient-0.37.tar.gz
#		http://derwan.irssi.pl/perl-modules/NNTPClient-0.37.tar.gz
# Usage:
#	/ARTICLE [-s <server>] [-p <port>] [-P <password> -U <login>] [-l <group> <count>] [-a] [-L <index>] <Message-ID>
# Settings:
#	/SET news_nntp_server [server] (default environment variable 'NNTPSERVER' is used (or news.tpi.pl if variable not set))
#	/SET news_nntp_port [port] (default is 119)
#	/SET news_show_headers [headers] (default: from newsgroups subject message-id date lines)
#	/SET news_use_news_window [On/Off] (default is On)
#	/SET news_show_signature [On/Off] (default is On)
#	/SET news_use_body_colors [On/Off] (default is On)
#	/SET news_check_count [count] (default is 5)
#	/SET news_use_auth [On/Off] (default is Off)
#	/SET news_auth_user [login]
#	/SET news_auth_password [password]

use strict;
use Irssi;
use 5.6.0;
use POSIX;

use vars qw($VERSION %IRSSI);
$VERSION = "0.5.9";
%IRSSI = (
	'authors'	=> 'Marcin Rozycki, Mathieu Doidy',
	'contact'	=> 'derwan@irssi.pl',
	'name'		=> 'news',
	'description'	=> 'News reader, usage:  /article [-s <server>] [-p <port>] [-P <password> -U <login>] [-l <group> <count>] [-a] [-L <index>] <message-id>',
	'url'		=> 'http://derwan.irssi.pl',
	'license'	=> 'GNU GPL v2',
	'changed'	=> 'Fri Feb  6 21:26:57 CET 2004',
);

use News::NNTPClient;

my $debug_level = 0;
my $nntp_server = $ENV{'NNTPSERVER'}; $nntp_server = 'news.tpi.pl' unless $nntp_server;
my $nntp_port = '119';
my $default_headers = 'from newsgroups';
my $check_count = 5;
my %pipe_tag = ();
my $news_window_name = 'news';
my @colors = (15, 12, 03, 06, 05, 07, 14);
my @articles = ();

Irssi::command_bind article => sub {
	my $usage = '/article [-s <server>] [-p <port>] [-P <password> -U <login>] [-l <group> <count>] [-a] [-L <index>] <Message-ID>';

	my $window;
	if (Irssi::settings_get_bool('news_use_news_window')) {
		$window = Irssi::window_find_name($news_window_name);
		if (!$window) {
			Irssi::command('^window new hide');
			Irssi::command('^window name '.$news_window_name);
			$window = Irssi::window_find_name($news_window_name);
		}
	} else {
		$window = Irssi::active_win();
	}

	my $server = Irssi::settings_get_str('news_nntp_server');
	$server = $nntp_server unless $server;
	my $port = Irssi::settings_get_int('news_nntp_port');
	$port = $nntp_port unless ($port > 0);
	my $count = Irssi::settings_get_int('news_check_count');
	$count = $check_count unless ($count > 0);

	my ($connection, $artid, $group, $strip, $showall, @article);
	my ($auth, $user, $password);
	my $yes = 0;

	@_ = split(/ +/, $_[0]);
	while ($_ = shift(@_))
	{
		/^-a$/ and $showall = 1, next;
		/^-s$/ and $server = shift(@_), next;
		/^-p$/ and $port = shift(@_), next;
		/^-P$/ and $password = shift(@_), next;
		/^-U$/ and $user = shift(@_), next;
		/^-l$/ and do {
			$group = shift(@_);
			$window->printformat(MSGLEVEL_CLIENTCRAP, 'news_group_missing', $usage), return unless ($group);
			$_ = shift(@_);
			$count = $_, next if ($_ =~ /^\d+$/ and $_ > 0);
		};
		/^-yes$/i and ++$yes, next;
		/^-L$/ and do {
			$window->printformat(MSGLEVEL_CLIENTCRAP, 'news_no_artids'), return if ($#articles < 0);
			if ($artid = shift(@_)) {
				$window->printformat(MSGLEVEL_CLIENTCRAP, 'news_unknown_argument', $artid, $usage), return if ($artid !~ /^\d+/ or $artid < 0 or $artid > 10);
				$window->printformat(MSGLEVEL_CLIENTCRAP, 'news_unknown_artid', ++$artid), return unless ($articles[--$artid]);
			    $_ = $articles[$artid]->[0];
            } else {
				for (my $idx = 0; $idx <= $#articles; $idx++) {
					$window->printformat(MSGLEVEL_CLIENTCRAP, 'news_artid_show',
						($idx + 1), $articles[$idx]->[0], $articles[$idx]->[1], $articles[$idx]->[2]);
				}
			    return;
            }
		};
		/^-/ and $window->printformat(MSGLEVEL_CLIENTCRAP, 'news_unknown_argument', $_, $usage), return;
		$artid = ($_ =~ /^<.*>$/) ? $_ : '<'.$_.'>';
		last;
	}

	$window->printformat(MSGLEVEL_CLIENTCRAP, 'news_server_unknown', $server), return if (!$server or $server !~ /^..*\...*/);
	$window->printformat(MSGLEVEL_CLIENTCRAP, 'news_port_unknown', $port), return if (!$port or $port !~ /^\d+$/ or $port == 0 or $port > 65535);
	$window->printformat(MSGLEVEL_CLIENTCRAP, 'news_missing_argument', $usage), return if (!$group and !$artid);
	$window->printformat(MSGLEVEL_CLIENTCRAP, 'news_article_unknown', $artid), return if (!$group and $artid !~ /^<..*\@..*>$/);

	my ($rh, $wh);
	pipe($rh, $wh);

	my $pid = fork();
	unless (defined $pid) {
		close($rh); close($wh);
		$window->printformat(MSGLEVEL_CLIENTCRAP, 'news_cannot_fork');
		return;

	} elsif ($pid) {
		close ($wh);
		$window->printformat(MSGLEVEL_CLIENTCRAP, 'news_server_connecting', $server, $port, $artid);
		Irssi::pidwait_add($pid);
		$pipe_tag{$rh} = Irssi::input_add(fileno($rh), INPUT_READ, \&news_fork, $rh);
		return;
	}

	close($rh);

	$connection = new News::NNTPClient($server, $port, $debug_level);
	print($wh "not_connected $server $port\n"), goto END unless ($connection->{CODE} =~ /^(200|201)$/);
	print($wh "connected ".$connection->{MESG}."\n");

        if ($user && $password or Irssi::settings_get_bool('news_use_auth')) {
		$user = Irssi::settings_get_str('news_auth_user') unless defined $user;
		$password = Irssi::settings_get_str('news_auth_password') unless defined $password;
		$connection->authinfo($user,$password);
	}
	
	
	if ($group) {
		print($wh "listgroup_yes $count\n"), goto END if ($count > 10 and !$yes);
		print($wh "listgroup_request $server $group\n");
		my @list = $connection->listgroup($group);
		print($wh "listgroup_error $server ".$connection->{MESG}."\n"), goto END if ($#list < 0);

		my $num = $#list;
		print($wh "listgroup_num $group $num $count\n");
		@list = @list[($num - $count) .. $num] if ($num > --$count);

		N: while ($_ = shift(@list))
		{
			chomp;
			print($wh "space\n");
			foreach my $xhdr ("From", "Subject", "Message-ID")
			{
				my @reply = $connection->xhdr($xhdr, $_);
				chomp $reply[0]; $reply[0] =~ s/^\d+ //;
				goto N unless ($reply[0]);
				if ($xhdr eq "Message-ID") {
					print($wh "memo $reply[0]\,news.pl: listgroup,$group\n");
				} elsif ($xhdr eq "From") {
					$reply[0] = "\002" . $reply[0] . "\002";
				}
				print($wh "listgroup_header $xhdr $reply[0]\n");
			}
		}
		print($wh "space\n");

	} else {
		my $show_headers = $default_headers .' '. Irssi::settings_get_str('news_show_headers');
		my ($head, $idx, $usecolors, $bodycolor) = (1, 0, Irssi::settings_get_bool('news_use_body_colors'), $colors[0]);

		print($wh "article_request $server $artid\n");
		foreach ($connection->article($artid))
		{
			unless ($idx++) {
				print($wh "space\n");
				print($wh "memo $artid\,news.pl: read,$server\n");
			}
			chomp; s/\t/        /g;
			/^-- / and do {
				last if (!$showall and !Irssi::settings_get_bool('news_show_signature'));
				$bodycolor = $colors[6], $usecolors = 0 if $usecolors;
			};
			unless ($head) {
				/^$/ and next if (!$showall and $strip++);
				/^..*$/ and $strip = 0;
				if ($usecolors) {
					$_ =~ /^[>| ]+/;
					my $prefix = $&; $prefix =~ s/ //g;
					$bodycolor = ($_ =~ /^[>]+/) ? $colors[(((length($prefix)-1) %5)+1)] : $colors[0];
				}
				print($wh "article_body \003$bodycolor$_\n");
				next;
			}
			/^$/ and print($wh "space\n"), $head = 0, next;
			my ($header, $text) = split(/: /, $_, 2);
			print($wh "article_header $header $text\n") if ($showall or $show_headers =~ /\b$header\b/i);
		}
		print($wh "article_notexist $server $artid\n") unless ($idx);
		print($wh "space\n") unless ($strip);
	}

	END: print($wh "close\n");
	close($wh);
	POSIX::_exit(1);
};

sub memo {
	my ($text, $who, $where) = @_;
	G: while ($text =~ /<[A-Za-z0-9\S]+\@[A-Za-z0-9\S]+>/g)
	{
		my $artid = $&;
		foreach my $array (@articles) { goto G if ($artid eq $array->[0]); }
		unshift @articles, [$artid, $who, $where];
	}
	$#articles = 9 if ($#articles > 9);
}

sub news_fork {
	my $rh = shift;
	while (<$rh>)
	{
		chomp;
		/^close/ and last;
		/^memo / and memo(split(",", $', 3)), next;
		my ($theme, @args) = split / +/, $_, 5;
		my $window = Irssi::window_find_name($news_window_name);
		$window = Irssi::active_win() unless $window;
		$window->printformat(MSGLEVEL_CLIENTCRAP, 'news_' . $theme, @args);
	}

	Irssi::input_remove($pipe_tag{$rh});
	close($rh);
}

Irssi::signal_add_last 'message private' => sub { memo($_[1], $_[2], $_[3]); };
Irssi::signal_add_last 'message public' => sub { memo($_[1], $_[2], $_[4]); };
Irssi::signal_add_last 'dcc chat message' => sub { memo($_[1], $_[0]->{nick}, "chat"); };

Irssi::theme_register([
	'news_server_unknown',		'NNTP %_server unknown%_ or not defined, use: /set news_nntp_server [server], to set it',
	'news_server_bad',		'%_Bad%_ NNTP server {hilight $0} (bad hostname or addres)',
	'news_port_unknown',		'%_NNTP port%_ unknown or not defined, use: /set news_nntp_port [port], to set it',
	'news_missing_argument',	'Missing argument, usage: $0-',
	'news_unknown_argument',	'Unknown argument \'$0\', usage: $1-',
	'news_server_connecting',	'Connecting to {hilight $0} on port {hilight $1}, wait...',
	'news_not_connected',		'%_Cannot connect%_ to NNTP server $0 on port $1',
	'news_connected',		'%_Connected%_; $0-',
	'news_article_unknown',		'Unknown message-id {hilight $0}',
	'news_article_notexist',	'No article {hilight $1} on $0',
	'news_article_request',		'Sending query about article {hilight $1} to $0, wait...',
	'news_article_body',		'$0-',
	'news_article_header',		'%c$0:%n %_$1-%_',
	'news_group_missing',		'Missing argument: newsgroup, usage: $0-',
	'news_listgroup_request',	'Looking for %_new articles%_ in {hilight $1}, wait...',
	'news_listgroup_error',		'Listgroup result: $1-',
	'news_listgroup_num',		'$1 articles in group $0; fetching headers (max in $2 articles), wait...',
	'news_listgroup_header',	'%c$0:%n $1-',
	'news_listgroup_yes',		'Count > 10 ($0). Doing this is not a good idea. Add -YES option to command if you really mean it',
	'news_no_artids',		'Sorry, list of logged message-id\'s is empty :/',
	'news_cannot_fork',		'Cannot fork process',
	'news_artid_show',		'[%_$[!-2]0%_] article %c$1%n [by {hilight $2} ($3-)]',
	'news_unknown_artid',		'Article {hilight $0} not found, type /article -L, to displays list of logged message-id\'s',
	'news_space',				' '
]);

# registering settings
Irssi::settings_add_bool('misc', 'news_use_news_window', 1);
Irssi::settings_add_str('misc', 'news_nntp_server', $nntp_server);
Irssi::settings_add_int('misc', 'news_nntp_port', $nntp_port);
Irssi::settings_add_str('misc', 'news_show_headers', $default_headers.' subject message-id date lines content-transfer-encoding');
Irssi::settings_add_bool('misc', 'news_show_signature', 1);
Irssi::settings_add_bool('misc', 'news_use_body_colors', 1);
Irssi::settings_add_bool('misc', 'news_use_auth', 0);
Irssi::settings_add_str('misc', 'news_auth_user', '');
Irssi::settings_add_str('misc', 'news_auth_password', '');
Irssi::settings_add_int('misc', 'news_check_count', $check_count);
