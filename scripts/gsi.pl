#!/usr/bin/perl -w
# <<< MISSION STATEMENT >>>
#
#  gsi.pl
# Looks up an 8 digit number in the Norwegian yellowpages...
# ( http://www.gulesider.no/ )
#
# Prints information after removing identical entries.
# Written by <mistr@sensewave.com> for irssi 0.8.9
#
# TODO:
#  - enhance the regexes (less stripping, better matching)
#  - shrink code (more generalized subs)
#  - add functionality for name and address lookups
#
# <<< BEGING CODE >>>
use strict;
use LWP::UserAgent;
use URI::Heuristic;
use vars qw($VERSION %IRSSI);

$VERSION = "220904-04:30:00";

%IRSSI = (
    authors     => "mistr",
    contact     => "mistr\@sensewave.com",
    name        => "gsi",
    modules     => 'LWP::UserAgent, URI::Heuristic',
    description => "/gsi <phone nr> checks number via http://gulesider.no. Norwegian 8-digit numbers only. Nice if you have caller-ID and are as paranoid as me.",
    license     => "Public Domain",
    url         => "http://irssi.org/scripts",
    changed     => "$VERSION"
);
# No need to change
my $owner = "mistr.atat.sensewave.dotdot.com";
my $banner = "[http://gulesider.no]";
# Don't touch
Irssi::settings_add_bool('gsi', 'gsi_debug', 0);
Irssi::print("Set gsi_debug ON for debugging output");
Irssi::command_bind('gsi', 'cmd_gsi');
Irssi::print("Added command /gsi");

# Subs
sub cmd_gsi {
	my $debug = Irssi::settings_get_bool('gsi_debug');
	undef $debug unless ( $debug == 1 ) ;
  	my ($lookup,$server,$witem) = @_;
	$lookup =~ s/\s+//g;
        if ( $lookup =~ m/^([0-9]{8}?)$/ ) {
	  	$lookup = $1;
	} else {
		print CLIENTCRAP "%R>>%n Syntax error. Use /gsi <8digitnumber>";
	  	return;
	}
	print CLIENTCRAP "%R>>%n Looking up $lookup";
	my $address = "http://www.gulesider.no/gsi/numberSearch.do?tel=";
	$address .= $lookup;
	chomp(my $raw_url = $address);
	my $url = URI::Heuristic::uf_urlstr($raw_url);
	my $ua = LWP::UserAgent->new();
	$ua->agent("$owner");
	my $req = HTTP::Request->new(GET => $url);
	$req->referer("$owner");
	my $response = $ua->request($req);
	if ($response->is_error()) {
		print CLIENTCRAP "%R>>%n Something went wrong fetching by HTTP";
		return;
	} else {
       		my $rawdata = $response->content(); # get the data
		$_ = $rawdata;
		if ( m/0 treff\./s ) {
			print CLIENTCRAP "%R>>%n $banner No hits.";
			undef $lookup;
			return;
		} elsif ( /S\&oslash\;ket\ ga\ treff\ i(.*)Gule Sider(.*)og(.*)Telefonkatalogen(.*)/ms ) {
			print CLIENTCRAP "%R>>%n $banner Multiple listings. Manual search needed.";
			print CLIENTCRAP "%R>>%n \($address\)";
			undef $lookup;
			return;
		}
		my $result = codezap( $rawdata );
		( $debug ) && Irssi::print("debug - $result");
		$_ = $result;
		if ( /\([0-9]+ treff\)(.*)function\ submitDrill\(select\)/ ) { # multiple hits
			my $rest = $1;
			( $debug ) && Irssi::print("debug - MULTIPLE HITS");
			$rest =~ s/[vV]is.treffene.i.kart//g;
			$rest =~ s/[Tt]reff.i.+\(\d+.treff\)//g;
			my ($result, %sorted);
			while ($_ = $rest) {
				m/^[ ]*(.+?)\ (\d{2,}[\d ]+\d{2,3})[ ]+/;
				my $info = $1;
				my $number = $2;
				$rest = $';
				( $debug ) && Irssi::print("debug - $info - $number");
				$result = $info . " " . $number;
				$sorted{$result}++;
			}
			foreach $result (sort keys %sorted) {
				print CLIENTCRAP "%R>>%n $banner $result";
			}
			undef $lookup;
			return;
		} elsif ( m/.*totalt 1 treff\. (.+) ([\d ]+) (.*[a-z-_.+=]+\@[a-z-_.+=]+\..+? )?Send.*/ ) {
			( $debug ) && Irssi::print("debug - 1 HIT STANDARD");
			my $info = $1;
			my $number = $2;
			my $other = $3;
			if ( $other =~ m/\w{3,}/ ) { $number .= " " . $other; }
			$info =~ s/[Ss]e ogs.+? [A-Z ]+[A-Z]{2,} //;
			$result = splitwords( $info ); 
			$result .= " $number"
		} elsif ( /.*treffene i kart (.*) ([\d ]+) (.*[a-z-_.+=]+\@[a-z-_.+=]+\..+? )?\'\)\;/) {
			( $debug ) && Irssi::print("debug - 1 HIT OTHER");
			my $info = $1;
			my $number = $2;
			my $other = $3;
			if ( $other =~ m/\w{3,}/ ) { $number .= " " . $other; }
			$result = splitwords( $info ); 
			$result .= " $number"
		} else {
			( $debug ) && Irssi::print("debug - FAILED REGEX");
			$result = "Unrecognized reply from server";
		}
		print CLIENTCRAP "%R>>%n $banner $result";
		undef $lookup;
		return;
	}
}	

sub codezap {
        my $zap = join('', @_);
	$zap =~ s/\&nbsp\;?//g;
	$zap =~ s/\&amp\;?/\&/g;
	$zap =~ s/\<.+?\>/ /msg;
	$zap =~ s/\s+/ /mg;
	$zap =~ s/ +/ /mg;
	$zap =~ s/^ +$//mg;
	return "$zap";
}

sub splitwords {
        my $workload = join('', @_);
	my @result;
	foreach ( split(' ', $workload) ) {
		if (m/([A-Z][^A-Z ]+)([A-Z][^A-Z ]+)/) {
			push(@result, $1 . " " . $2);
		} else {
			push(@result, $_);
		}
	}
	return join(' ', @result);
}

