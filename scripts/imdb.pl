use strict;
use Irssi;
use LWP::UserAgent;
use HTML::Entities;
use vars qw($VERSION %IRSSI $cache);

$VERSION = '1.04';
%IRSSI = (
    authors 	=> 'Eric Jansen',
    contact 	=> 'chaos@sorcery.net',
    name 	=> 'imdb',
    description => 'Automatically lookup IMDB-numbers in nicknames',
    license 	=> 'GPL',
    modules	=> 'LWP::UserAgent HTML::Entities',
    url		=> 'http://xyrion.org/irssi/',
    changed 	=> '2021-10-09',
    selfcheckcmd=> 'imdb check',
);

my $ua = new LWP::UserAgent;
$ua->agent('Irssi; ' . $ua->agent);

# Set the timeout to five second, so it won't freeze the client too long on laggy connections
$ua->timeout(5);

my $last_result;

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
	    my $req = new HTTP::Request(GET => "http://www.imdb.com/title/tt$id/");
	    my $res = $ua->request($req);

	    # Get the title and year from the fetched page
	    if($res->is_success
		&& $res->content  =~ /<title>(.+?) \((.+)\).*<\/title>/) {

	# https://www.imdb.com/title/tt1234567/
	# <title>&quot;So You Think You Can Dance&quot; The Top 14 Perform (TV Episode 2008) - IMDb</title>
	# https://www.imdb.com/title/tt0234567/
	# <title>The Ranchman's Nerve (1911) - IMDb</title>

		my ($title, $year) = ($1, $2);

		# Decode special characters in the title
		$title= decode_entities($title);
		$last_result= { title=> $title, year=> $year };

		# Print it
		if ($channel->{type} eq "CHANNEL" ) {
		    $channel->printformat(MSGLEVEL_CRAP, 'imdb_lookup', $old_nick, $title, $year);
		} else {
		    Irssi::printformat(MSGLEVEL_CRAP, 'imdb_lookup', $old_nick, $title, $year);
		}

		# And cache it
		$cache->{$id} = {
		    'title'	=> $title,
		    'year'	=> $year
		};
	    }
	}
    }
}

# /imdb
sub cmd {
    my ($args, $server, $witem)=@_;
    if ($args =~ m/check/) {
	my $s='ok';
	$last_result= {};
	$witem->{'ownnick'}->{'nick'}="sepp";
	my $nick={ nick=>"susi_1234567" };
	event_nickchange( $witem, $nick , "imdb");
	unless ( $last_result->{title} =~ m/You Can Dance/ ) {
	    $s="Error: title ($last_result->{title})";
	}
	unless ($last_result->{year} =~ m/2008/ ) {
	    $s="Error: year ($last_result->{year})";
	}
	Irssi::print("imdb: self check: $s");
	my $schs =  exists $Irssi::Script::{'selfcheckhelperscript::'};
	Irssi::command("selfcheckhelperscript $s") if ( $schs );
    } elsif ( $args =~ m/\d{7}/ ) {
	$args =~ s/\s//g;
	$witem->{'ownnick'}->{'nick'}="sepp";
	my $nick={ nick=>"susi_$args" };
	event_nickchange( $witem, $nick , "imdb");
    }
}

Irssi::theme_register([
    'imdb_lookup', '{nick $0} is watching {hilight $1} ($2)'
]);
Irssi::signal_add('nicklist changed', 'event_nickchange');
Irssi::command_bind($IRSSI{name},\&cmd);

# vim:set ts=8 sw=4:
