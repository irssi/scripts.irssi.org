use Irssi;
use LWP::UserAgent;
use strict;
use vars qw($VERSION %IRSSI $cache);

$VERSION = '1.01';
%IRSSI = (
    authors 	=> 'Eric Jansen',
    contact 	=> 'chaos@sorcery.net',
    name 	=> 'imdb',
    description => 'Automatically lookup IMDB-numbers in nicknames',
    license 	=> 'GPL',
    modules	=> 'LWP::UserAgent',
    url		=> 'http://xyrion.org/irssi/',
    changed 	=> 'Sat Mar  1 12:39:49 CET 2003'
);

my $ua = new LWP::UserAgent;
$ua->agent('Irssi; ' . $ua->agent);

# Set the timeout to one second, so it won't freeze the client too long on laggy connections
$ua->timeout(1);

sub event_nickchange {

    my ($channel, $nick, $old_nick) = @_;

    # Lookup any 7-digit number in someone elses nick
    if($nick->{'nick'} ne $channel->{'ownnick'}->{'nick'} && $nick->{'nick'} =~ /\D(\d{7})(?:\D|$)/) {

	my $id = $1;

	# See if we know the title already
	if(defined $cache->{$id}) {

	    # Print it
	    $channel->printformat(MSGLEVEL_CRAP, 'imdb_lookup', $old_nick, $cache->{$id}->{'title'}, $cache->{$id}->{'year'});
	}

	# Otherwise, contact IMDB
	else {

	    # Fetch the movie detail page
    	    my $req = new HTTP::Request(GET => "http://us.imdb.com/Title?$id");
	    my $res = $ua->request($req);

	    # Get the title and year from the fetched page
    	    if($res->is_success && $res->content =~ /<title>(.+?) \((\d+)\)<\/title>/) {

		my ($title, $year) = ($1, $2);

		# Decode special characters in the title
		$title =~ s/&#(\d+);/pack('U*', $1)/eg;

		# Print it
		$channel->printformat(MSGLEVEL_CRAP, 'imdb_lookup', $old_nick, $title, $year);

		# And cache it
		$cache->{$id} = {
		    'title'	=> $title,
		    'year'	=> $year
		};
	    }
	}
    }
}

Irssi::theme_register([
    'imdb_lookup', '{nick $0} is watching {hilight $1} ($2)'
]);
Irssi::signal_add('nicklist changed', 'event_nickchange');
