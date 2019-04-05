#!/usr/bin/perl -w
#
# this is a VERY experimental code, use at own risk
#
# WARNING:
#  I am still not sure of the UTF-8 handling. It may only work if you
#  are on a UTF-8 terminal, with UTF-8ized settings.
#
# TODO:
#  - make urlfeed_title, urlfeed_link, urlfeed_description work for
#    already-created feeds, not only the new ones
#  - some exclude-list would be useful I guess
#  - enhance urlfeed_find_url() maybe
#  - TEST IT! it's not idiot-proof at the moment
#

use strict;
use vars qw($VERSION %IRSSI);
use POSIX qw(strftime);
use Irssi;
use Irssi::Irc;
use Encode;
use XML::RSS;
use Regexp::Common qw /URI/;

$VERSION = '1.31';

%IRSSI = (
    authors     => 'Jakub Jankowski',
    contact     => 'shasta@toxcorp.com',
    name        => 'URLfeed',
    description => 'Provides RSS feeds with URLs pasted on your channels.',
    license     => 'GNU GPLv2 or later',
    url         => 'http://toxcorp.com/irc/irssi/urlfeed/',
    changed     => '2019-03-02'
);

# These rules apply only to per-channel RSS files, NOT to the bundle!
# $stripchan is replaced with channel name, BUT with stripped #!&+
# $chan is replaced with channel name
# $tag is replaced with server tag

my $rss_title = 'URLs on $chan';
my $rss_link = 'http://toxcorp.com/irc/irssi/';
my $rss_description = 'List of URLs recently pasted on $chan $tag channel';
my $rss_path = $ENV{HOME}.'/public_html/rss/$tag/$stripchan.rdf';
my $rss_bundle_path = $ENV{HOME}.'/public_html/rss/all.rdf';
my $max_items = 15;
my $bundle_max_items = 40;
my $debug = 1;
my $provide_bundle = 0;

sub urlfeed_build_path {
  my ($tag, $chan) = @_;
  my ($stripchan) = $chan =~ /^[\!\#\&\+](.+)/g;
  my $str = Irssi::settings_get_str('urlfeed_path');
  $str =~ s/\$tag/$tag/gi;
  $str =~ s/\$chan/$chan/gi;
  $str =~ s/\$stripchan/$stripchan/gi;
  $str .= $chan . ".rdf" if ($str =~ /\/$/);
  return $str;
}

sub urlfeed_replace ($$$) {
  my ($str, $tag, $chan) = @_;
  my ($stripchan) = $chan =~ /^[\!\#\&\+](.+)/g;
  $str =~ s/\$tag/$tag/gi;
  $str =~ s/\$chan/$chan/gi;
  $str =~ s/\$stripchan/$stripchan/gi;
  return $str;
}

sub urlfeed_touch_file ($) {
  my ($f) = @_;
  my ($basedir) = $f =~ /(.*)\/[^\/]*$/;
  my @dirs = split(/[\/]+/, $basedir);
  local *FH;
  my $path = "";

  foreach my $idx (1..$#dirs) {
    $path .= "/" . $dirs[$idx];
    if (! -d $path) {
      Irssi::print("URLfeed warning: $path is not a dir, trying to mkdir");
      eval { mkdir($path); };
      if ($@) {
	Irssi::print("URLfeed error: couldn't mkdir($path): $@");
	return 0;
      }
    }
  }

  if (! -w $basedir) {
    Irssi::print("URLfeed error: $basedir isn't writable");
    return 0;
  }

  eval { open(FH, '+<',$f); };
  if ($@) {
    Irssi::print("URLfeed error: couldn't open $f for writing: $@");
    return 0;
  }

  close(FH);

  return 1;
}

sub urlfeed_format_time ($) {
  my @t = localtime($_[0]);
  my $time = strftime("%Y-%m-%dT%H:%M:%S", @t);
  my $tzd = strftime("%z", @t);
  return sprintf("%s%s:%s", $time, substr($tzd,0,3), substr($tzd,3));
}

# we might make use of timestamp someday
sub urlfeed_rss_add {
  my ($timestamp, $tag, $chan, $nickname, $text, $url) = @_;

  return 0 unless (defined $url && defined $tag && defined $chan);

  $nickname = "guest" unless (defined $nickname);
  $text = $url unless (defined $text);

  my $filename = urlfeed_build_path($tag, $chan);
  if (!urlfeed_touch_file($filename)) {
    Irssi::print("URLfeed error: Couldn't touch $filename");
    return 0;
  }

  # UTF-8 is the default encoding
  my $rss = new XML::RSS (version => '1.0' );
  eval { $rss->parsefile($filename); };
  if ($@) {
    Irssi::print("URLfeed notice: rss->parsefile($filename) failed. Creating new RSS") if (Irssi::settings_get_bool('urlfeed_debug'));
    $rss->channel(
      title        => urlfeed_replace(Irssi::settings_get_str('urlfeed_title'), $tag, $chan),
      link         => urlfeed_replace(Irssi::settings_get_str('urlfeed_link'), $tag, $chan),
      description  => urlfeed_replace(Irssi::settings_get_str('urlfeed_description'), $tag, $chan)
    );
  }

  # tiny spam protection
  foreach my $item (@{$rss->{'items'}}) {
    return 0 if (lc($url) eq lc($item->{'link'}));
  }

  my $guard = 0;
  while (@{$rss->{'items'}} >= Irssi::settings_get_int('urlfeed_max_items') && $guard++ < 10000) {
    pop(@{$rss->{'items'}});
  }

  $rss->add_item(title => Encode::decode_utf8($text),
                 link  => $url,
		 dc    => { creator => $nickname, date => urlfeed_format_time($timestamp) },
                 mode  => 'insert'
            );

  $rss->save($filename);

  return 1 unless (Irssi::settings_get_bool('urlfeed_provide_bundle'));

  # now do the bundle part
  $filename = Irssi::settings_get_str('urlfeed_bundle_path');
  if (!urlfeed_touch_file($filename)) {
    Irssi::print("URLfeed error: Couldn't touch $filename");
    return 0;
  }
  my $brss = new XML::RSS (version => '1.0' );
  eval { $brss->parsefile($filename); };
  if ($@) {
    Irssi::print("URLfeed notice: rss->parsefile($filename) failed. Creating new RSS") if (Irssi::settings_get_bool('urlfeed_debug'));
    $brss->channel(
      title        => $rss_title,
      link         => $rss_link,
      description  => $rss_description
    );
  }

  # tiny spam protection
  foreach my $item (@{$brss->{'items'}}) {
    return 0 if (lc($url) eq lc($item->{'link'}));
  }

  my $guard = 0;
  while (@{$brss->{'items'}} >= Irssi::settings_get_int('urlfeed_bundle_max_items') && $guard++ < 10000) {
    pop(@{$brss->{'items'}});
  }

  $brss->add_item(title => Encode::decode_utf8($text),
                 link  => $url,
		 dc    => { creator => $nickname . " on " . $tag, date => urlfeed_format_time($timestamp) },
                 mode  => 'insert'
            );

  $brss->save($filename);

  return 1;
}

# based on urlgrab.pl by David Leadbeater
sub urlfeed_find_urls {
  my ($text) = @_;
  my @chunks = split(/[ \t]+/, $text);
  my @urls = ();

  foreach my $chunk (@chunks) {
    if ($chunk =~ /($RE{URI}{HTTP}{-scheme => qr#https?#})/ ||
	$chunk =~ /($RE{URI}{FTP})/ ||
	$chunk =~ /($RE{URI}{NNTP})/ ||
	$chunk =~ /($RE{URI}{news})/) {
      push(@urls, $1);
    } elsif ($chunk =~ /(www\.[a-zA-Z0-9\/\\\:\?\%\.\&\;=#\-\_\!\+\~\,]+)/i) {
      push(@urls, "http://" . $1);
    }
  }
  return @urls;
}

sub urlfeed_process {
  my ($time, $tag, $target, $nick, $text) = @_;

  my @urls = urlfeed_find_urls($text);

  foreach my $url (@urls) {
    my $retval = urlfeed_rss_add($time, $tag, $target, $nick, $text, $url);
    if (Irssi::settings_get_bool('urlfeed_debug')) {
      # escape url, in case it needs to be Irssi::print()ed
      $url =~ s/\%/\%\%/g;
      if ($retval == 1) {
	Irssi::print("URLfeed notice: URL $url (pasted by $nick on $target/$tag) successfully added to RSS feed.");
      } elsif ($retval == 0) {
	Irssi::print("URLfeed notice: Adding URL $url (pasted by $nick on $target/$tag) to RSS failed.");
      }
    }
  }
}

sub urlfeed_message_own_public {
  my ($server, $text, $target) = @_;
  return unless ($target =~ /^[\!\#\&\+]/);
  $target = '!' . substr($target, 6) if ($target =~ /^\!/);
  urlfeed_process(time, $server->{tag}, lc($target), $server->{nick}, $text);
}

sub urlfeed_message_public {
  my ($server, $text, $nick, $hostmask, $target) = @_;
  return unless ($target =~ /^[\!\#\&\+]/);
  urlfeed_process(time, $server->{tag}, lc($target), $nick, $text);
}

Irssi::settings_add_bool('urlfeed', 'urlfeed_debug',     $debug);
Irssi::settings_add_bool('urlfeed', 'urlfeed_provide_bundle', $provide_bundle);
Irssi::settings_add_int ('urlfeed', 'urlfeed_max_items', $max_items);
Irssi::settings_add_int ('urlfeed', 'urlfeed_bundle_max_items', $bundle_max_items);
Irssi::settings_add_str ('urlfeed', 'urlfeed_title',     $rss_title);
Irssi::settings_add_str ('urlfeed', 'urlfeed_link',      $rss_link);
Irssi::settings_add_str ('urlfeed', 'urlfeed_description', $rss_description);
Irssi::settings_add_str ('urlfeed', 'urlfeed_path',      $rss_path);
Irssi::settings_add_str ('urlfeed', 'urlfeed_bundle_path',      $rss_bundle_path);

Irssi::signal_add_last('message public',     'urlfeed_message_public');
Irssi::signal_add_last('message own_public', 'urlfeed_message_own_public');
