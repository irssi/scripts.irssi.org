# shortenurl.pl v 0.7.1 by Marcin Ró¿ycki (derwan@irssi.pl)
#
# Usage:
#   /shortenurl [url]
#   /shortenurl -L
#   /shortenurl [index]
#
# Settings:
#   shortenurl_autoconvert_minlen [length]
#      if shortenurl_autoconvert_minlen is greater than 0 and length of url is
#      greater than shortenurl_autoconvert_minlen then link will be
#      converted automaticaly
#
# Simultaneously there can be three links converted!
# 
# Special thanks to Piotr Kucharski (Beeth) for changes in 42.pl/url/ service which
# made communication between script and web easier.
#


use strict;
use vars qw($VERSION %IRSSI);

use LWP::UserAgent;
use POSIX '_exit';
use IO::File;
use Irssi qw( command_bind version settings_add_int settings_get_int signal_add_last theme_register active_win );

$VERSION = '0.7.1';
%IRSSI = (
  authors      => 'Marcin Rozycki',
  contact      => 'derwan@irssi.pl',
  name         => 'shortenurl',
  description  => 'shortenurl',
  license      => 'GNU GPL v2',
  url          => 'http://derwan.irssi.pl',
  changed      => 'Sat Jun 26 19:17:02 CEST 2004',
);

our $agent = sprintf("Irssi %s ", version);
our $active = 0;
our $active_max = 3;
our @url = ();
our %tags = ();
our %cache = ();
our $maxlength = 0;

theme_register([
   'shortenurl_url_list', '[%_$0%_] url %_$1%_ [by $2 ($3), $4 secs ago]',
   'shortenurl_url_show', 'Shortened url $0 => %_$1%_',
   'shortenurl_connect', 'Connecting to http://42.pl/url, this may take a while...',
   'shortenurl_url_error', 'Cannot connect to http://42.pl/url service!'
]);

sub shortenurl ($$$) {
  my ($data, $server, $witem) = @_;
  $witem = $server->window_item_find($1) if ( $data =~ s/^-w\s([^\s]+)\s// );
  $witem = active_win() unless $witem;
  if ( $data =~ /^-L/i ) {
     my $time = time();
     for (my $idx = 0; $idx <= $#url; $idx++) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'shortenurl_url_list', sprintf('%2d',($idx + 1)),
	   url2short($url[$idx]->[0]), $url[$idx]->[1], $url[$idx]->[2], ($time - $url[$idx]->[3]) );
     }
     return;
  } elsif ( $data =~ m/^\d+$/ ) {
     if ( my $url = $url[--$data] ) {
        $server->command('shortenurl ' . $url->[0]);
     } else {
        Irssi::print("shortenurl: index too high", MSGLEVEL_CRAP);
     }
     return;
  } elsif ( not $data ) {
    Irssi::print('Usage: /shortenurl [url]', MSGLEVEL_CRAP);
    Irssi::print('Usage: /shortenurl -L', MSGLEVEL_CRAP);
    Irssi::print('Usage: /shortenurl [index]', MSGLEVEL_CRAP);
    return;
  }
  
  my $url = $data;
  $url =~ s/([^\w])/sprintf("%%%02X",ord($1))/ge;

  my $hash = unpack('H*', $url);
  if ( exists $cache{$hash} ) {
     $witem->printformat(MSGLEVEL_CRAP, 'shortenurl_url_show', url2short($data), $cache{$hash});
     return;
  }
     
  return if ( $active > $active_max );

  my $reader = IO::File->new() or return;
  my $writer = IO::File->new() or return;
  pipe($reader, $writer);
  my $pid = fork();

  if ( $pid ) {
    $active++;
    close($writer);
    Irssi::pidwait_add($pid);
    $witem->printformat(MSGLEVEL_CRAP, 'shortenurl_connect');
    $tags{$reader} = [ Irssi::input_add(fileno($reader), INPUT_READ, \&do_fork, $reader), $server->{tag}, $witem->{name} ];
  } elsif ( defined $pid ) {
    close($reader);
    my $ua = new LWP::UserAgent;
    $ua->agent($agent . $ua->agent);
    my $request = new HTTP::Request GET => "http://42.pl/url/?auto=1&url=$url";
    my $s = $ua->request($request);
    my $content = $s->content();
    my $buf = ( $content =~ m/(http\:\/\/[^\s]+)/  ) ? "$1 -- $hash -- $data\n" : 0;
    print($writer "$buf\n");
    close($writer);
    POSIX::_exit(1);
  } else {
    close($reader);
    close($writer);
    Irssi::print("Cannot fork!");
  }
}

sub url2short ($) {
  my $url = shift;
  my $length = length($url);
  substr($url, 15, $length - 32) = '...' if ( $length - 32 > 0 );
  return $url;		 
}

sub do_fork {
  my $reader = shift();
  my $data = <$reader>;
  Irssi::input_remove($tags{$reader}->[0]);
  close($reader);
  my $server = Irssi::server_find_tag($tags{$reader}->[1]);
  my $window = ( $server ) ? $server->window_item_find($tags{$reader}->[2]) : undef;
  $tags{$reader} = ();
  delete $tags{$reader};
  $active--;
  $window = active_win() unless $window;
  if ( $data =~ m/(.*) -- (.*) -- (.*)/ ) {
     $window->printformat(MSGLEVEL_CRAP, 'shortenurl_url_show', url2short($3), $1);
     $cache{$2} = $1;
  } else {
     $window->printformat(MSGLEVEL_CRAP, 'shortenurl_url_error');
  }
}

sub do_shortenurl ($$$$$) {
  my ($server, $data, $who, $where, $winname) = @_;
  while ( $data =~ m/((http|ftp|https):\/\/[^\s]+)/g ) {
     my ($test, $url) = (0, $1);
     $server->command(sprintf('shortenurl -w %s %s', $winname, $url)) if
        ( $url !~ m/^http:\/\/42\.pl\/url/ and $maxlength > 0 and length($url) > $maxlength );
     foreach my $u ( @url ) {  
        $test = 1, last if ( $u->[0] eq $url );
     }
     next if $test;
     unshift @url, [ $url, $who, $where, time ];
     $#url = 9 if ( $#url > 9 );
  }
}

sub do_setup { $maxlength = settings_get_int('shortenurl_autoconvert_minlen'); };

command_bind('shortenurl', 'shortenurl');
command_bind('42.pl', 'shortenurl');
signal_add_last('message public' => sub { do_shortenurl($_[0], $_[1], $_[2], $_[4], $_[4]) });
signal_add_last('message private' => sub { do_shortenurl($_[0], $_[1], $_[2], $_[3], $_[2]) });
signal_add_last('setup changed', 'do_setup');
settings_add_int('misc', 'shortenurl_autoconvert_minlen', $maxlength);

do_setup();
