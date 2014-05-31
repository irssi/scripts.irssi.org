
#############
# ZaMz0n 28-Oct-2003
# ZaMz0n 10-Dec-2003
#############

use strict;
use Irssi;
use LWP::Simple;
use vars qw($VERSION %IRSSI);

$VERSION = '1.21';
%IRSSI = (
        authors     => 'ZaMz0n',
        contact     => 'zamzon@freakpower.com',
        name        => 'cddb',
        description => 'Find CDs by Artist, Disc name or Track name in CDDB.',
        license     => 'Free',
        url         => 'http://www.gracenote.com/music/',
        changed     => 'Wed Oct 29 01:27:00 CET 2003',
        commands    => 'cddb'
);

# MAIN FUNCTION STARTS HERE
sub cddb_query {

# Set SEARCH variables
 my $howto = "\cbUsage:\cb !cddb [<query>] [-d <disc title>] [-a <artist name>] [-t <track name>]";
 my $searches = shift;
 my ($search, $out, $line, $info, $htmlpage, @url, @content) = '';
 my @output = ();

# DISPLAY USAGE
 $searches =~ s/^\s*$//;
 $searches = $searches." ";
 if ($searches eq " ") {
  push (@output, $howto);
  push (@output, "--");
  return @output;
 }

# CONVERT PARAMETERS
  $search = $searches;
  $search =~ s/-d\ /&qdisc=/;
  $search =~ s/-a\ /&qartist=/;
  $search =~ s/-t\ /&qtrack=/;
  $search =~ s/\ &/&/g;
  $search =~ s/\ /+/g;

# START SEARCHING
  push (@output, "Searching CDDB with \cb$searches");
  my $initial_url = "http://www.gracenote.com/music/search-adv.html?n=1&x=0&y=0&q=".$search;

  @url = `curl -s "$initial_url" | grep -i xm | cut -f4 -d'"'| grep -i htm`;

  if (!@url) {push(@output, "No match found.");}
  else {
   $url[0] =~ s/\/xm/http:\/\/www.gracenote.com\/xm/;
   $url[0] =~ s/html/html\n/;
   $url[0] =~ s/\x0a//g;
   push (@output, "in CDDB: $url[0]");

   $htmlpage = get $url[0];
   @content = split /\x0d/, $htmlpage;

   $out = 0;
   foreach $line (@content) {
    if ($line =~ s/Disc\ Info//) {$out = 1; $info='';}
    if ($out) {
     if ($line =~ s/Track\ Title//) {$out = 0; $line = '';}
     if ($line ne '') {$info .= $line;}
    }
   }

# FORMAT OUTPUT
   $info =~ s/\x0a/\ /g;
   $info =~ s/\.html/\.html/;
   $info =~ s/<[^>]*>/\ /gs;
   $info =~ s/\ \ \ \ //g;
   $info = ":       ".$info;
   push (@output, $info);
  }
push (@output, "--");
return @output;
}

sub results_write {
 my ($server,$target,@lines) = @_;
 my $i = 0;
 for($i=0;$i<$#lines;$i++) {
  $server->command("MSG $target $lines[$i]");
 }
}

sub message_public {
 my ($server,$msg,$nick,$address,$target) = @_;
 if (($msg =~ /^\!cddb\s+(.+)$/) || ($msg =~ /^\!cddb/)) {
  my @lines = cddb_query($1);
  results_write($server,$target,@lines);
 }
}

sub message_own_public {
 my ($server,$msg,$target) = @_;
 message_public($server,$msg,$server->{nick},0,$target);
}

sub message_private {
 my ($server,$msg,$nick,$address) = @_;
 message_public($server,$msg,$nick,$address,$nick);
}

sub message_own_private {
 my ($server,$msg,$target,$otarget) = @_;
 message_public($server,$msg,$server->{nick},0,$target);
}


Irssi::signal_add_first('message own_public','message_own_public');
Irssi::signal_add_first('message private','message_private');
Irssi::signal_add_first('message own_private','message_own_private');
Irssi::signal_add_first('message public','message_public');
