#!/usr/bin/perl
#
# by Atoms

use strict;
use HTTP::Tiny;

use vars qw($VERSION %IRSSI);

use Irssi qw(command_bind active_win);
$VERSION = '1.1';
%IRSSI = (
    authors	=> 'Atoms',
    contact	=> 'atoms@tups.lv',
	patch   => 'spowers@dimins.com',
    name	=> 'tinyurl',
    description	=> 'create a tinyurl from a long one',
    license	=> 'GPL',
);

command_bind(
    tinyurl => sub {
      my ($msg, $server, $witem) = @_;
      my $answer = tinyurl($msg);
      if ($answer) {
        print CLIENTCRAP "$answer";
        if ($witem && ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY')) {
  	      $witem->command("MSG " . $witem->{name} ." ". $answer);
        }
      }
    }
);

sub tinyurl {
  my $url = shift;
  my $content = "url=$url";    
        
  #added to fix URLs containing a '&'
  $url=url_encode($url);

  my %options = (
    agent => "tinyurl for irssi/1.0 "
  );

  my %form_params = (
    url => $url
  );
  
  my $ua = HTTP::Tiny->new(%options);
  my $res = $ua->request('POST', 'http://tinyurl.com/create.php', { 
      content => $content,
      headers => { 'content-type' => 'application/x-www-form-urlencoded' },
  });

  if ($res->{success}) {
    return get_tiny_url($res->{content});
  } else {
    print CLIENTCRAP "ERROR: tinyurl: tinyurl is down or not pingable";
    return "";
  }
}

#added because the URL was not being url_encoded. This would cause only 
#the portion of the URL before the first "&" to be properly sent to tinyurl.
sub url_encode {
        my $url = shift;
        $url =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
        return $url;
}

sub get_tiny_url($) {
	
	my $tiny_url_body = shift;
	$tiny_url_body =~ /(.*)(data\-clipboard\-text=\")(.*)(\")(.*)/;

	return $3;
}
