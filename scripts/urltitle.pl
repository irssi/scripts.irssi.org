# please contact me with comments/suggestions/fixes
# you'll find me at most larger irc networks as obyn.
#
# this is how it works:
# <nick> oh lol: http://lololol.lol/lol
# becomes:
# <nick> oh lol: http://lololol.lol/lol (welcum 2 lolpage - the home of lulz)
#
# big thanks to the man behind dns.pl, simmel and klippo.

use vars qw($VERSION %IRSSI);

$VERSION = "0.3";
%IRSSI = (
	authors 	=> 'robin hansson',
	contact 	=> 'junk@dataninja.net',
	name 		=> 'urltitle',
	changed		=> 'May 15 2009',
	description	=> 'prints title of url pasted/typed in channels',
	license 	=> 'uh? contact-me-if-you-made-improvements-license',
	url 		=> 'http://robin.webcust2.prq.se/urltitle.pl',
);

no warnings;
use strict;
use Irssi;
use POSIX;
use Encode;
use Encode::Guess;
use LWP::UserAgent;
use HTML::Entities;

my ($cache);

sub find_url {
	my ($server, $data, $nick, $mask, $target) = @_;
	my (%url_hash, $url, $title, $cached);
	my $msg = $data;
	if ( $msg =~ m#http://# ) {
		while ($data =~ s#.*?(\s|^)(https?://.+?)(\s|$)(.*)#$4#i) {
			$url = $2;
			if (defined $cache->{$url}) {
				$title = $cache->{$url}->{'title'};
			}
			else {
				$title = get_url($url);
			}
			if ($title) {
				$url_hash{ $url } = $title;
				for $url (keys %url_hash) {
					$title = $url_hash{ $url };
				}
			}
		}
		for $url (keys %url_hash) {
			$title = $url_hash{$url};
			$title = "(02" . $title . ")";
			$msg =~ s#\Q$url\E#$url $title#;
		}
		{ 
			no warnings; 
			Irssi::signal_continue($server, $msg, $nick, $mask, $target); 
		}
	}
}

sub get_url {
	my ($ua, $res, $enc, $url, $title);
	($url) = @_;
	$ua = LWP::UserAgent->new;
	$ua->max_size(50000);
	$ua->timeout(3);

	$res = $ua->get("$url");

	if ($res->is_success && $res->content =~ m#<title>(.{3,100})</title>#si) {
		$title = decode_entities($1);
		$title =~ s#[\n\t\r]*##g;
		$title =~ s#\s+#\ #g;
		$enc = guess_encoding($title, qw/latin1 utf8 CP1252/);
		$title = encode('utf8', $title) unless ($enc =~ /utf\-?8/si);
		$cache->{$url} = {'title' => $title};
	}
	return $title;
}

Irssi::signal_add('message public', \&find_url);
