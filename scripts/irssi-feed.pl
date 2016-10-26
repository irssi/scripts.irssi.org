# uses XML::Feed (yep, debian's libxml-feed-perl has huge dependencies...)
#
# Displays messages in status window, unless a window irssi-feed exists
# Add one with /window new hidden /window name irssi-feed
#
# Command format:
# /feed {add|set|list|rm} [--uri <address>] [--id <short name>] [--color %<color>] [--newid <new short name>] [--interval <seconds>]
#
# Note: Since XML::Feed's HTTP doesn't support async usage, I implemented an
# an own HTTP client. It won't do anything sensible when redirected and does
# not support https.

use strict;
use warnings;
use feature 'state';
use XML::Feed;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);
use List::Util qw(min);
use IO::Socket::INET;
use Errno;
use Getopt::Long qw(GetOptionsFromString);
our $VERSION = "20130209";
our %IRSSI = (
	authors     => 'Julius Michaelis',
	contact     => 'iRRSi@cserv.dyndns.org', # see also: JCaesar on freenode, probably idling in #irssi
	name        => 'iRSSi feed reader',
	description => 'Parses and announces XML/Atom feeds',
	license     => 'GPLv3',
	url         => 'https://github.com/jcaesar/irssi-feed',
	changed     => '$VERSION',
);
use Irssi qw(command_bind timeout_add INPUT_READ INPUT_WRITE);

sub save_config {
	our @feeds;
	my $str = '';
	foreach my $feed (@feeds) {
		if(defined $feed) {
			$str .= " --id $feed->{id}" if($feed->{id});
			$str .= " --uri $feed->{uri}";
			$str .= " --interval $feed->{configtimeout} " if($feed->{configtimeout});
			$str .= " --color $feed->{color} " if($feed->{color});
			$str .= "\n";
		}
	}
	Irssi::settings_set_str('feedlist', $str);
}

sub initialize {
	our @feeds;
	feedreader_cmd("add$_") foreach(split(/\n/,Irssi::settings_get_str('feedlist')));
	feedprint("Loaded ".($#feeds+1)." feeds");
	check_feeds();
}

sub feedreader_cmd {
	my ($data, $server, $window_item) = @_;
	my ($cmd, $args) = split(/ /, $data, 2);
	my $feed_id;
	my $feed_uri;
	my $feed_timeout = 0;
	my $feed_color = 'NOMODIFY';
	my $feed_newid;
	if(!GetOptionsFromString($args, 
		'uri=s' => \$feed_uri,
		'id=s' => \$feed_id,
		'interval=i' => \$feed_timeout,
		'color=s' => \$feed_color,
		'newid=s' => \$feed_newid)
	) {
		feedprint("Could not parse options of $data");
		return;
	}
	my $feed = find_feed_by('id', $feed_id) // find_feed_by('url', $feed_uri);
	$feed_timeout = valid_timeout($feed_timeout) if($feed_timeout);
	if($feed_color ne 'NOMODIFY' && $feed_color !~ m/^%[0-9krbygmpcwKRBYGMPCWFU#]$/ && $feed_color) {
		feedprint("Invalid color.");
		$feed_color = 'NOMODIFY';
	}
	if($cmd eq "add") {
		if($feed) {
			feedprint("Failed to add feed " . feed_stringrepr($feed) . ": Already exists");
		} elsif(!$feed_uri) {
			feedprint("Failed to add feed. No uri given.");
		} else {
			$feed_color = '' if($feed_color eq 'NOMODIFY');
			$feed = feed_new($feed_uri, $feed_timeout, $feed_id, $feed_color);
			feedprint("Added feed " . feed_stringrepr($feed, 'long')) if($window_item);
			save_config();
			check_feeds();
		}
	} elsif ($cmd eq "set") {
		if(!$feed) {
			feedprint("No feed found.");
		} else {
			$feed->{active} = 1;
			$feed->{io}->{failed} = 0;
			$feed->{timeout} = valid_timeout($feed->{configtimeout});
			$feed->{uri} = $feed_uri if($feed_uri && $feed_id);
			$feed->{color} = $feed_color unless($feed_color eq 'NOMODIFY');
			$feed->{timeout} = $feed_timeout if($feed_timeout);
			$feed->{id} = $feed_newid if($feed_newid);
			save_config();
			feedprint("Modified feed: ". feed_stringrepr($feed, 'long'));
			check_feeds();
		}
	} elsif ($cmd eq "list") {
		our @feeds;
		if($#feeds < 0) {
			feedprint("Feed list: empty");
		} else {
			feedprint("Feed list:");
			foreach my $feed (sort { $a->{color} cmp $b->{color} } @feeds) {
				feedprint("   " . feed_stringrepr($feed, 'long'));
			}
		}
		check_feeds(); # for the lulz
	} elsif ($cmd eq "rem" || $cmd eq "rm") {
		if($feed) {
			feed_delete($feed);
			feedprint("Feed deleted: " . feed_stringrepr($feed));
		} elsif(!defined $args) {
			my $foundone = 0;
			our @feeds;
			foreach(@feeds) {
				if(not $_->{active}) {
					$foundone = 1;
					feed_delete($_);
					feedprint("Feed deleted: " . feed_stringrepr($_));
				}
			}
			feedprint("No inactive feeds.") if(!$foundone);
		} else {
			feedprint("No feed to remove.");
		}
		save_config;
	} else {
		feedprint("Unknown command: /feed $cmd");
	}
}

sub all_feeds_gen1 { our @feeds; $_->{generation} or return 0 for @feeds; 1 }

sub check_feeds {
	state $timeoutcntr = 0;
	my $thistimeout = shift // $timeoutcntr;
	our @feeds;
	my $nextcheck = ((min(map { feed_check($_) } @feeds)) // 0) + 1;
	if($thistimeout == $timeoutcntr) {
		my $fivemin = clock_gettime(CLOCK_MONOTONIC) + 301;
		$nextcheck = $fivemin if $nextcheck > $fivemin;
		my $timeout = $nextcheck - clock_gettime(CLOCK_MONOTONIC);
		$timeout = 5 if $timeout < 5;
		$timeoutcntr += 1;
		my $hackcopy = $timeoutcntr; # to avoid passing a reference. I don't understand why it happens
		Irssi::timeout_add_once(1000 * $timeout, \&check_feeds, $hackcopy) if((scalar(grep { $_->{active} } @feeds)) > 0);
	}
}

sub find_feed_by {
	my ($by, $hint) = @_;
	return unless $hint;
	our @feeds;
	foreach(@feeds) {
		return $_ if(lc($_->{$by}) eq lc($hint));
	}
	return 0;
}

sub valid_timeout {
	my ($to) = @_;
	our $default_timeout;
	$to = $default_timeout unless($to);
	$to = 3600 if $to > 86400;
	$to = 10 if $to < 10;
	return $to;
}

sub feed_new {
	my $uri = shift;
	my $timeout = shift;
	my $id = shift;
	my $color = shift;
	state $nextfid = 1;
	my $feed = {
		id => $id // "$nextfid",
		uri => URI->new($uri),
		name => $uri,
		color => $color,
		lastcheck => clock_gettime(CLOCK_MONOTONIC) - 86400,
		timeout => valid_timeout($timeout), # next actual timeout. Doubled on error
		configtimeout => $timeout,
		active => 1, # use to deactivate when an error has been encountered.
		itemids => {"dummy" => -1},
		generation => 0,
		io => {
			readtag => 0,
			writetag => 0,
			conn => 0,
			failed => 0,
			state => 0,
			buffer => '',
			xml => 0,
		},
	};
	$nextfid += 1;
	our @feeds;
	push(@feeds, $feed);
	if($feed->{uri}->scheme ne 'http') {
		$feed->{active} = 0;
		if($feed->{uri}->scheme eq 'https') {
			$feed->{uri}->scheme('http');
			feedprint(feed_stringrepr($feed) . " has https uri, https is not supported. Do /feed set " . $feed->{id} . " to reactivate with http.");
		} else {
			feedprint("Unsupported uri scheme ".$feed->{uri}->scheme." in feed " . feed_stringrepr($feed));
		}
	}
	return $feed;
}

sub feed_check {
	my $feed = shift;
	return if(not $feed->{active});
	my $now = clock_gettime(CLOCK_MONOTONIC);
	if(($now - $feed->{lastcheck}) > $feed->{timeout}) {
		if($feed->{io}->{failed} >= 3) {
			$feed->{timeout} = valid_timeout($feed->{timeout} * 2);
			$feed->{generation} += 1; # so the "Skipped n feed entries" message won't hang forever
			return 0;
		}
		feedprint("Warning, stall feed " . feed_stringrepr($feed)) if($feed->{io}->{conn});
		feed_cleanup_conn($feed, 1);
		my $conn = $feed->{io}->{conn} = IO::Socket::INET->new(
			Blocking => 0,
			Proto => 'tcp',
			PeerHost => $feed->{uri}->host,
			PeerPort => $feed->{uri}->port,
			#Timeout => DO NOT SET TIMEOUT. It will activate blocking io...
		);
		if($conn) {
			$feed->{io}->{readtag}  = Irssi::input_add(fileno($conn), INPUT_READ,  \&feed_io_event_read, $feed);
			$feed->{io}->{writetag} = Irssi::input_add(fileno($conn), INPUT_WRITE, \&feed_io_event_write, $feed);
		}
		$feed->{io}->{failed} += 1;
		$feed->{lastcheck} = $now;
	}
	return $feed->{lastcheck} + $feed->{timeout};
}

sub feed_io_event_read {
	my $self = shift;
#	feedprint($self->{id} . " rdev " . (length $self->{io}->{buffer}));
	if($self->{io}->{state} == 1) {
		my $buf = '';
		my $readcnt = 8192;
		my $ret = $self->{io}->{conn}->read($buf, $readcnt) // 0;
		$self->{io}->{buffer} .= $buf;
		if($ret < $readcnt and $! != Errno::EAGAIN) {
			$self->{io}->{conn}->shutdown(SHUT_RD);
			feed_cleanup_conn($self);
			$self->{io}->{state} = 2;
			feed_parse_buffer($self);
		}
	}
	if($self->{io}->{conn} and not $self->{io}->{conn}->connected) {
		feed_cleanup_conn($self, 0);
		return;
	}
}

sub feed_io_event_write {
	my $self = shift;
	if(not $self->{io}->{conn}->connected) {
		feed_cleanup_conn();
		return;
	}
	if($self->{io}->{state} == 0) {
		my $query = $self->{uri}->path // '/';
		$query .= '?' . $self->{uri}->query if $self->{uri}->query;
		my $req = "GET " . $query . " HTTP/1.0\r\n" .
				"Host: " . $self->{uri}->host . "\r\n" .
				"User-Agent: Irssi feed reader " . $VERSION . "\r\n" .
				"Accept-Encoding: gzip\r\n" .
				"Connection: close\r\n\r\n";
		$self->{io}->{conn}->send($req);
		Irssi::input_remove($self->{io}->{writetag}) if $self->{io}->{writetag};
		$self->{io}->{writetag} = 0;
		$self->{io}->{state} = 1;
		# $self->{io}->{conn}->shutdown(SHUT_WR); Appearantly sends a FIN,ACK, and e.g. Wikipedia interprets that as: Don't return the data...
	}
}

sub feed_cleanup_conn {
	my $feed = shift;
	my $delbuffer = shift;
	Irssi::input_remove($feed->{io}->{readtag}) if $feed->{io}->{readtag};
	$feed->{io}->{readtag} = 0;
	Irssi::input_remove($feed->{io}->{writetag}) if $feed->{io}->{writetag};
	$feed->{io}->{writetag} = 0;
	if($feed->{io}->{conn}) {
		$feed->{io}->{conn}->shutdown(SHUT_RDWR);
		if($feed->{io}->{conn}->connected) {
			$feed->{io}->{conn}->close;
		}
	}
	$feed->{io}->{conn} = 0;
	$feed->{io}->{buffer} = '' if $delbuffer;
	$feed->{io}->{state} = 0;
}

sub feed_parse_buffer {
	my $feed = shift;
	return unless($feed->{io}->{state} == 2);
	my $http = HTTP::Response->parse($feed->{io}->{buffer});
	if($http->is_redirect) {
		my $location = $http->header('Location');
		my $uri = URI->new($location);
		if($location) {
			feedprint('Feed ' . feed_stringrepr($feed) . ' got redirected to ' . $location);
			$feed->{uri} = $uri;
			# fake soonish needed recheck:
			$feed->{lastcheck} = clock_gettime(CLOCK_MONOTONIC) - $feed->{timeout} + 1;
			check_feeds();
		} else {
			feedprint('Feed ' . feed_stringrepr($feed) . ' got redirected, but the destination was not determinable');
			$feed->{active} = 0;
		}
	}
	return if not $http->is_success;
	my $httpcontent = $http->decoded_content;
	my $data = eval { $feed->{io}->{xml} = XML::Feed->parse(\$httpcontent) };
	if($data) {
		$feed->{name} = $data->title;
		$feed->{io}->{failed} = 0;
		$feed->{timeout} = valid_timeout($feed->{configtimeout});
	} else {
		$feed->{timeout} = valid_timeout($feed->{timeout} * 2);
	}
	feed_cleanup_conn($feed, 1);
	feed_announce($feed);
}

sub feed_announce {
	my $feed = shift;
	my $nulldate = DateTime->new(year => 0);
	feed_announce_item($feed, $_)
		foreach
		sort { DateTime->compare_ignore_floating($a->issued // $nulldate, $b->issued // $nulldate) }
		grep {defined $_} feed_get_news($feed);
	finished_load_message();
}

sub feed_get_news {
	my $self = shift;
	my $data = $self->{io}->{xml};
	return if(!$data);
	my @news = ();
	my $itemids = $self->{itemids};
	for my $item ($data->entries) {
		push(@news, $item) if(not exists $itemids->{$item->id});
		$itemids->{$item->id} = $self->{generation};
	}
	# forget about old entries
	foreach (keys %$itemids) {
		delete($itemids->{$_}) if($itemids->{$_} < $self->{generation});
	}
	if($self->{generation} == 0) {
		our $initial_skips;
		$initial_skips += $#news; # no +1 missing
		@news = ($news[ 0 ])
	}
	$self->{generation} += 1;
	$self->{io}->{xml} = 0;
	return @news;
}

sub feed_announce_item {
	my ($feed, $news) = @_;
	my $space = "";
	$space =~ s//' ' x ((length $feed->{id}) + 3)/e;
	my $titleline = $news->title;
	$titleline =~ s/\s*\n\s*/ | /g;
	feedprint('<' . feed_stringrepr($feed) . '> ' . $titleline . "\n" . $space . $news->link, Irssi::MSGLEVEL_PUBLIC);
}

sub finished_load_message {
	our $initial_skips;
	if($initial_skips && all_feeds_gen1()) {
		feedprint("Skipped $initial_skips feed entries.");
		$initial_skips = 0;
	}
}

sub feed_delete {
	my $self = shift;
	feed_cleanup_conn($self);
	our @feeds;
	@feeds = grep { $_ != $self } @feeds;
}

sub feed_stringrepr {
	my ($feed, $long) = @_;
	return unless $feed;
	if($long) {
		return "#" .
		($feed->{color} ? $feed->{color} : '') .
		$feed->{id} .
		($feed->{color} ? '%n' : '') .
		": " .
		$feed->{name} . 
		(($feed->{name} ne $feed->{uri}) ? (" (" .$feed->{uri}. ")") : "") . 
		($feed->{active} ? " ":" in")."active, " . 
		$feed->{timeout} ."s";
	} else {
		return ($feed->{color} ? $feed->{color} : '') .
		$feed->{id} .
		($feed->{color} ? '%n' : '');
	}
}

sub feedprint {
	my ($msg) = @_;
	state $feedwin = 0;
	$feedwin = 0 if(not $feedwin or $feedwin->{name} ne 'irssi-feed');
	if(not $feedwin) {
		foreach my $w (Irssi::windows()) { #feeling a little bad here
			if ($w->{name} eq 'irssi-feed') {
				$feedwin = $w;
				last;
			}
		}
	}
	if($feedwin) {
		$feedwin->print($msg, Irssi::MSGLEVEL_PUBLIC);
	} else {
		Irssi::print($msg);
	}
}

Irssi::command_bind('feed', \&feedreader_cmd);
Irssi::settings_add_str('feedreader', 'feedlist', '');
our $initial_skips = 0;
our @feeds = ();
Irssi::timeout_add_once(500, \&initialize, 0);
our $default_timeout = 600;
