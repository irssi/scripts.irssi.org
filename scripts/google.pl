# - Google.pl

# - You have to modify this line to the path
# - of your LWP-dir

use lib '/usr/lib/perl5/vendor_perl/5.6.1';

use Irssi;
use LWP::UserAgent;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '1.00';
%IRSSI = (
    authors     => 'Oddbjørn Kvalsund',
    contact     => 'oddbjorn.kvalsund@hiof.no',
    name        => 'Google',
    description => 'This script queries google.com and returns the results.',
    license     => 'Public Domain',
);

## Usage:
## /google [-p, prints to current window] [-<number>, number of searchresults returned] search-criteria1 search-criteria2 ...
##
## History:
## - Sun May 19 2002
##   Version 0.1 - Initial release
## -------------------------------

#-------------------------------------------------
my $nr_sites = 3; # Search-results returned
my $prefix = ""; # Message printed before results
#-------------------------------------------------

sub cmd_google {

        my ($data, $server, $witem) = @_;
        my $url = "";
	my $nr_sites = 3;
	my $i = 0;
	my (@lines, @pages);
	my $mode = "quiet";

	# If user supplied nr_sites, activate his setting
	if ( $data =~ /-(\d\s)/ ) { $nr_sites = $1 };
	if ($data =~ /-10/) { $nr_sites = 10 };
	$data =~ s/-\d+//g; # remove nr_sites from $data

	# Switch to public mode
	# and return error msg if invalid window
	if ( $data =~ /-p/ ) {
		$mode = "public";
		if ( ! $witem ) {
		  Irssi::active_win()->print("Must be run run in a valid window (CHANNEL|QUERY)");
		  return;
		}
	}
	$data =~ s/-p//g; # remove -p from $data

	# Format the query-string
	$data =~ s/\s/+/g;
	my $query = $data;

	# Initialize LWP
	my $ua = new LWP::UserAgent;
	$ua->agent("AgentName/0.1 " . $ua->agent);

	# Do the actual seach
        my $req = new HTTP::Request GET => "http://www.google.com/search?hl=en&q=$query";
        my $res = $ua->request($req);
        my $content = $res->content;

	# Replace <br> with newlines
	# and remove tags
        $content =~ s/\<br\>/\n/g;
        $content =~ s/\<.+?\>//sg;

	# Make array @pages of all search-results
        @lines = split("\n", $content);
        @pages = grep (/pages$/, @lines);

	# Remove empty entries in @pages
	for ($i=0;$i<=$#pages;$i++) {
		$pages[$i] =~ s/\s+.*//g;
		if ($pages[$i] =~ /(^\n|\s+\n)/){ splice(@pages, $i, 1) };
		if ($pages[$i] !~ /\./){ splice(@pages, $i, 1) };
	}

	if($nr_sites > $#pages) { $nr_sites = $#pages + 1};

	# Print pages to current window if public-mode specified
	# else display a private notice of returned pages
	if ( $mode eq "public") {
	  if ($prefix ne "") { $witem->command("/SAY $prefix") } ;
          for ($i=0; $i<$nr_sites; $i++) {
                $pages[$i] =~ s/\s+.*//g;
		$witem->command("/SAY http://$pages[$i]");
          }
	}
	else {
	  for ($i=0; $i<$nr_sites; $i++) {
		$pages[$i] =~ s/\s+.*//g;
		Irssi::active_win()->print("http://$pages[$i]");
	  }
	}
}

Irssi::command_bind('google', 'cmd_google');
