# Copyright 2009 -- 2011, Olof Johansson <olof@ethup.se>
# Improved by Cyprien Debu <frey@notk.org>, 2014
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use v5.10.1;
use strict;
use HTML::Entities;
use Irssi;
use JSON::Parse qw(json_to_perl);
use LWP::UserAgent;
use Regexp::Common qw(URI);
use URI;
use URI::QueryParam;
use XML::Simple;

our $VERSION = '1.00';
our %IRSSI = (
  authors     => 'Olof "zibri" Johansson, Cyprien Debu',
  contact     => 'olof@ethup.se, frey@notk.org',
  name        => 'vidinfo',
  description => 'Prints some info of a linked video automatically',
  license     => 'GPL',
  changed     => '2014-07'
);

my $sn = $IRSSI{name};

my %domains = (
  'dailymotion.com' => {
    idextr => \&idextr_dailymotion_com,
    site => 'dm', 
  },
  'vimeo.com' => {
    idextr => \&idextr_vimeo_com,
    site => 'vm', 
  },
  'youtu.be' => {
    idextr => \&idextr_youtu_be,
    site => 'yt',
  },
  'youtube.com' => {
    idextr => \&idextr_youtube_com,
    site => 'yt',
  },
);

my $domains_rx = '(' . join('|', keys %domains) . ')';
my %rules = {};
my $default_rule = '=';

Irssi::settings_add_bool($sn, $sn.'_print_own', 0);
Irssi::settings_add_str ($sn, $sn.'_print_rules', $default_rule);
Irssi::settings_add_str ($sn, $sn.'_site_color', '7');

sub print_help {
  print( <<EOF

$sn: $IRSSI{description}.
The format of the message is: "Site: title (duration)"

Available options (see /set $sn):
- print_own: if true, print info also for own messages
- site_color: color of the "Site:" part of the message
- print_rules: decide in which channel/query you want to print the message and how.
  Three rules exist: '-': don't print, '=': print for you (CRAP level), '+': send a message to the channel/query.
  The setting in itself is a comma-separated set of rules followed by a regex to apply the rule.
  Example: '=,+^#foo\$,-bar' which reads like this:
    '=' is the default rule: show video info only for you by default
    '+^#foo\$': send the info as a message in the channel #foo
    '-bar': don't print anything in channels containing 'bar'
  Hint: to distinguish between channels and queries (for example, print the message for you in channels, but nothing in queries), you can use this setting: '-,=^#'.
EOF
  );
}

sub on_msg_public {
  my ($srv, $msg, $nick, $addr, $tgt) = @_;
  Irssi::signal_continue($srv, $msg, $nick, $addr, $tgt);
  main($srv, $msg, $tgt);
}

sub on_msg_private {
  my ($srv, $msg, $nick, $addr) = @_;
  Irssi::signal_continue($srv, $msg, $nick, $addr);
  main($srv, $msg, $nick);
}

sub on_msg_own_public {
  my ($srv, $msg, $tgt) = @_;
  Irssi::signal_continue($srv, $msg, $tgt);
  main($srv, $msg, $tgt) if (Irssi::settings_get_bool($sn.'_print_own'));
}

sub on_msg_own_private {
  my ($srv, $msg, $tgt, $orig_tgt) = @_;
  Irssi::signal_continue($srv, $msg, $tgt, $orig_tgt);
  main($srv, $msg, $tgt) if (Irssi::settings_get_bool($sn.'_print_own'));
}

sub main {
  my ($srv, $msg, $tgt) = @_;

  return unless $msg =~ /$domains_rx/i;

  my $rule = get_rule($tgt);

  return if (not $rule =~ /^[=+]$/);

  # Process each video link in message
  process($srv, $tgt, $rule, $_) for (get_vids($msg)); 
}

sub get_rule {
  my $tgt = shift;

  foreach (keys %rules) {
    return $rules{$_} if ($tgt =~ /$_/);
  }

  return $default_rule;
}

sub load_rules {
  state $rules_str = $default_rule;

  return if ($rules_str eq Irssi::settings_get_str($sn.'_print_rules'));

  $rules_str = Irssi::settings_get_str($sn.'_print_rules');
  %rules = {};

  $default_rule = '-' if (length $rules_str == 0);

  foreach (split ',', $rules_str) {
    $rules{substr($_, 1)} = substr($_, 0, 1) if (length $_ > 1);
    $default_rule = $_ if (length $_ == 1);
  }
}

sub process {
  my ($srv, $tgt, $rule, $vid) = @_;

  my $info = get_title($vid);
    
  if (exists $info->{error}) {
    print_error($srv, $tgt, $info->{error});
  } else {
    print_title($srv, $tgt, $rule, $info->{site}, $info->{title}, $info->{duration});
  }
}

sub canon_domain {
  my $_ = shift;
  s/^www\.//;
  return $_;
}

sub idextr_dailymotion_com {
  my $u = URI->new(shift);
  my $_ = ($u->path_segments())[2];
  s/_.+//;
  return $_;
}

sub idextr_vimeo_com {
  my $u = URI->new(shift);
  return ($u->path_segments())[1];
}

sub idextr_youtu_be {
  my $u = URI->new(shift);
  return ($u->path_segments())[1];
}

sub idextr_youtube_com {
  my $u = URI->new(shift);
  return $u->query_param('v') if $u->path eq '/watch';
}

sub vid_from_uri {
  my $uri = URI->new(shift);
  my $domain = canon_domain($uri->host);

  my $info = $domains{$domain};

  return { 
    id => $domains{$domain}->{idextr}->($uri),
    site => $domains{$domain}->{site},
  } if ref $domains{$domain}->{idextr} eq 'CODE';
}

sub get_vids {
  my $msg = shift;
  my $re_uri = qr($RE{URI}{HTTP}{-scheme=>'https?'});
  my @vids;

  foreach ($msg =~ /$re_uri/g) {
    my $vid = vid_from_uri($_);
    push @vids, $vid if $vid;
  }

  return @vids;
}

sub do_get {
  my $ua = LWP::UserAgent->new();

  $ua->agent("$sn/$VERSION (irssi)");
  $ua->timeout(3);
  $ua->env_proxy;

  return $ua->get(shift);
}

sub dm_get_title {
  my $response = shift;
  
  my $json = json_to_perl($response->decoded_content);
  
  my $title = $json->{title};
  my $s = $json->{duration};

  my $m = $s / 60;
  my $d = sprintf "%d:%02d", $m, $s % 60;

  return ($title, $d);
}

sub vm_get_title {
  my $response = shift;
  
  my $json = (json_to_perl($response->decoded_content))->[0];

  my $title = $json->{title};
  my $s = $json->{duration};

  my $m = $s / 60;
  my $d = sprintf "%d:%02d", $m, $s % 60;

  return ($title, $d);
}

sub yt_get_title {
  my $response = shift;

  my $content = $response->decoded_content;

  my $xml = XMLin($content)->{'media:group'};
  my $title = $xml->{'media:title'}->{content};
  my $s = $xml->{'yt:duration'}->{seconds};

  my $m = $s / 60;
  my $d = sprintf "%d:%02d", $m, $s % 60;

  return ($title, $d);
}

sub get_title {
  my $vid = shift;
  my $site = $vid->{site};

  my %sites = (
    dm => { 
      sitename => 'DailyMotion',
      get_title => \&dm_get_title,
      url => "https://api.dailymotion.com/video/$vid->{id}?fields=title,duration",
    },
    vm => { 
      sitename => 'Vimeo',
      get_title => \&vm_get_title,
      url => "http://vimeo.com/api/v2/video/$vid->{id}.json",
    },
    yt => {
      sitename => 'YouTube',
      get_title => \&yt_get_title,
      url => "http://gdata.youtube.com/feeds/api/videos/$vid->{id}",
    },
  );

  my $response = do_get($sites{$site}->{url});

  if ($response->is_success) {
    my ($title, $duration) = $sites{$site}->{get_title}->($response);

    if ($title) {
      return {
        title => $title,
        duration => $duration,
        site => $sites{$site}->{sitename},
      };
    }

    return {error => 'could not find title'};
  }
  
  return {error => $response->message};
}

sub print_error {
  my ($srv, $tgt, $msg) = @_;
  $srv->window_item_find($tgt)->printformat(
    MSGLEVEL_CLIENTCRAP, $sn.'_error', $msg
  );
}

sub print_title {
  my ($srv, $tgt, $rule, $site, $title, $time) = @_;

  $title = decode_entities($title);
  $time = decode_entities($time);
  my $c = Irssi::settings_get_str($sn.'_site_color');
  my $line = ($c ne '' ? "\x03$c$site:\x03" : "$site:") . " $title ($time)";

  for ($rule) {
    when (/=/) {
      my $witem = Irssi::window_item_find $tgt;
      $witem->print($line);
    }
    when (/\+/) {
      # Remove colors in channels with mode 'c'
      my $chan = $srv->channel_find($tgt);
      if (defined $chan and $chan->{mode} =~ /c/ and $c ne '') {
        $line = "\x02$site:\x02 $title ($time)";
      }
      $srv->command("msg $tgt $line");
    }
    default { }
  }
}

load_rules();

Irssi::theme_register([
  $sn.'_error', '%rError fetching video title:%n $0',
]);

Irssi::signal_add("message public", \&on_msg_public);
Irssi::signal_add("message private", \&on_msg_private);
Irssi::signal_add("message own_public", \&on_msg_own_public );
Irssi::signal_add("message own_private", \&on_msg_own_private );
Irssi::signal_add("setup changed", \&load_rules);

# Help command handler
Irssi::command_bind 'help', sub {
  $_[0] =~ s/\s+$//g;
  return unless $_[0] eq $sn;
  print_help;
  Irssi::signal_stop;
};

# Subcommands handler
Irssi::command_bind $sn, sub {
  my ($data, $server, $item) = @_;
  $data =~ s/\s+$//g;
  Irssi::command_runsub $sn, $data, $server, $item;
};

# Subcommands
Irssi::command_bind "$sn help",  \&print_help;

