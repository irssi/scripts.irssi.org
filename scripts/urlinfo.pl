use strict;
use warnings;
use 5.014;
use utf8;
use Encode;
use Irssi;
use POSIX ();

our $VERSION = "1.6";
our %IRSSI = (
    authors     => 'David Leadbeater',
    contact     => 'dgl@dgl.cx',
    name        => 'urlinfo',
    description => 'Print short summaries about URLs from known services that are mentioned on IRC. (Including YouTube, etc.)',
    license     => 'WTFPL <http://dgl.cx/licence>',
    url         => 'http://dgl.cx/irssi',
);

# This is needed so it can still run standalone for testing.
BEGIN {
  Irssi->import(20140628) if __PACKAGE__ =~ /Irssi/; # This needs Irssi 0.8.17
}

BEGIN {
  eval {
    require HTML::TreeBuilder;
    require URI;
  } or do {
    print "\x{3}8You need to install HTML::TreeBuilder and URI";
    if (-f "/etc/debian_version") {
      print "Try running: \x{3}9sudo apt-get install libhtml-treebuilder-perl libwww-perl";
    }
    die $@;
  }
}

# ------- Settings
# /SET urlinfo_title_unknown ON|OFF
#   Show title of all unknown sites. (There is a timeout to prevent against
#   obvious resource exhaustion attacks, but remember this script has no
#   warranty.)
#
# /SET urlinfo_timeout 10
#   How many seconds after which to give up trying to fetch a URL
#
# /SET urlinfo_ignore_domains example\.org example\.com
#   Space separated list of regular expressions of domains to ignore
#
# /SET urlinfo_ignore_targets freenode #something efnet/#example
#   Space separated list of targets to ignore.
#
# /SET urlinfo_send_channels freenode #something efnet/#example
#   Space separated list of targets to post in the channel.
#
# /SET urlinfo_custom_domains my\.domain/thing irssi\.org=description
#   A limited way of configuring custom domains, if you need something more
#   complex edit SITES below.
#   Format: domain[/path[=from]]

# ------- Sites configuration

# This script aims to be data driven, this hash has "site_name => {site details}"
# site details is a hash reference which can contain:
#   cleanup: A regexp of text to remove from the resulting string
#   domain: A string (or regexp, with qr//) of the domain to match (www. is
#     removed automatically).
#   from: Where to read the info "title", "description" (meta description) or
#     a regexp to match the content (default "title")
#   example: Example of this URL
#   expected: What the example should return (see end for testing)
#   items: An array ref of additional hashes to allow multiple of these values
#     e.g.: items => [ { domain => "example.com" } ]
#   path: Path component (string or regexp)
#
my %SITES = (
  vimeo => {
    cleanup => qr/\s*on Vimeo$/,
    domain => "vimeo.com",
    path => qr{/\d+},
    example => "http://vimeo.com/80871338",
    expected => "Journey Part 1",
  },
  youtube => {
    cleanup => qr/\s*-\s*YouTube$/,
    items => [
      {
        domain => "youtu.be",
        example => "http://youtu.be/ghGoI7xVtSI",
        expected => "Rick Astley - Never Gonna Give You Up (Live 1987)",
      },
      {
        domain => "youtube.com",
        path => "/watch",
        example => "https://www.youtube.com/watch?v=ghGoI7xVtSI",
        expected => "Rick Astley - Never Gonna Give You Up (Live 1987)",
      },
    ],
  },
  metacpan => {
    cleanup => qr/\s*-\s*metacpan\.org$/,
    domain => "metacpan.org",
    path => qr{^/pod/},
    example => "https://metacpan.org/pod/release/DOY/Reply-0.34/lib/Reply.pm",
    from => "description",
    expected => "read, eval, print, loop, yay!",
  },
  pypi => {
    domain => "pypi.python.org",
    path => qr{^/pypi/},
    from => "description",
    example => "https://pypi.python.org/pypi/stanford-corenlp-python/3.3.6-0",
    expected => "A Stanford Core NLP wrapper (wordseer fork)",
  },
  gist => {
    cleanup => qr/\s*-\s*Gist is .*$/,
    domain => "gist.github.com",
    from => ["og:title", "description"],
    example => "https://gist.github.com/dgl/792206",
    expected => "An install script that installs a development version of perl (from ".
                "git) and keeps a particular set of modules installed. Sort of ".
                "perlbrew for blead, but not quite.",
  },
  github => {
    domain => "github.com",
    items => [
      { # issue, commit or pull
        cleanup => qr/\s*·.*$/,
        path => qr{^/[^/]+/[^/]+/(?:issues|commit|pull)/[a-f0-9]},
        example => "https://github.com/irssi/irssi/commit/669add",
        expected => "FS#155 hilight -tag",
      },
      { # user or project
        from => "og:description",
        path => qr{^/[^/]+(?:/[^/]+)?$},
        example => "https://github.com/irssi/irssi",
        expected => "irssi - The client of the future",
      },
    ],
  },
);

# ------- Site handling

sub expand {
  my @expanded_sites;
  for my $site(keys %SITES) {
    expand_site(\@expanded_sites, $site, $SITES{$site}, {});
  }
  return @expanded_sites;
}

# This essentially implements inheritance (via the "items" key), to reduce
# duplication.
sub expand_site {
  my($expanded_sites, $site, $site_data, $current) = @_;
  delete $current->{items};
  my $s = {
    name => $site,
    from => "title",
    %$current,
    %$site_data,
  };
  if (exists $s->{items}) {
    expand_site($expanded_sites, $site, $_, $s) for @{$s->{items}};
  } else {
    push @$expanded_sites, $s;
  }
}

sub _matcher {
  my($site, $item) = @_;
  return 1 unless defined $site;
  return 1 if ref $site eq 'ARRAY' && grep _matcher($_, $item), @$site;
  return 1 if ref $site && $site->isa("Regexp") && $item =~ $site;
  return $site eq $item;
}

sub get_site {
  my($sites, $url) = @_;

  my $uri = URI->new($url);
  $uri = URI->new("http://$url") unless $uri and $uri->scheme;
  return unless $uri and $uri->can("host") and $uri->host and $uri->scheme =~ /^https?$/;
  
  for my $site(@$sites) {
    my $match = 1;
    $match &&= _matcher($site->{domain}, $uri->host =~ s/^www\.//ri);
    $match &&= _matcher($site->{$_}, $uri->$_) for qw(scheme host path query fragment);
    return $site, $uri if $match;
  }

  if (Irssi::settings_get_bool("urlinfo_title_unknown")) {
    return { name => "unknown", from => "title" }, $uri;
  }

  return;
}

my %from = (
  title => sub {
    $_[0]->look_down(_tag => 'title')->as_trimmed_text;
  },
  description => sub {
    my $el = $_[0]->look_down(_tag => 'meta', name => 'description');
    $el && $el->attr('content');
  },
  'og:description' => sub {
    my $el = $_[0]->look_down(_tag => 'meta', property => 'og:description');
    $el && $el->attr('content');
  },
  'og:title' => sub {
    my $el = $_[0]->look_down(_tag => 'meta', property => 'og:title');
    $el && $el->attr('content');
  },
);

sub get_info {
  my($site, $uri) = @_;
  my $from = $site->{from};
  my $tree = HTML::TreeBuilder->new_from_url($uri);
  my $info;
  if (!ref $from || ref $from eq 'ARRAY') {
    $info = join ": ", grep defined, map $from{$_}->($tree), ref $from ? @$from : $from;
  } else {
    $info = join "", $tree->as_html =~ $from;
  }
  $info =~ s/$site->{cleanup}// if $site->{cleanup};
  $info =~ s/([\x00-\x19])/sprintf "\\x%x", ord $1/ger;
}

# ------- IRC message handling

# John Gruber's URL regexp (nicely handles people putting URLs in parens, etc)
my $URL_RE = qr{((?:[a-z][\w-]+:(?:/{1,3}|[a-z0-9%])|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’]))};

my $pipe_in_progress;
my @sites;
my $timeout = 10;

sub msg {
  my($server, $text, $nick, undef, $target) = @_;
  # TODO: Add a queue / multiple pipe support?
  return if $pipe_in_progress;

  my $msg_time = time;
  my $tag = $server->{tag};
  $target = $target || $nick;
  $text = Irssi::strip_codes($text);

  if (my($url) = $text =~ $URL_RE) {
    my($site, $uri) = get_site(\@sites, $url);
    return unless $site;
    return if ignored($uri, $server, $target);

    fork_wrapper(sub { # Child
      my($fh) = @_;
      syswrite $fh, "  " . encode_utf8(get_info($site, $uri));
    },
    sub { # Parent
      my $in = decode_utf8($_[0]);
      if ($in =~ s/^- //) {
        print "\x{3}4urlinfo error:\x{3} $in";
        return;
      }
      $in =~ s/^  //;
      return unless $in;

      # Avoid reusing server just in case it is no longer valid
      my $server = Irssi::server_find_tag($tag);
      my $win = find_window($server, $target);

      my $view = $win->view;
      my $line = $view->get_lines;
      while ($line && ($line = $line->next)) {
        if ($line->{info}->{time} >= $msg_time) {
          if ($line->get_text(0) =~ /\Q$url/) {
            last;
          }
        }
      }

      my $timestamp = POSIX::strftime(
        Irssi::settings_get_str("timestamp_format"), localtime $msg_time);
      # I'm sure I shouldn't have to care about colours here...
      my $pad = length Irssi::strip_codes($timestamp);

      if (not(send2channel($server,$target,$url,$in))) {
        my $text = $win->format_get_text(__PACKAGE__, $server, $target,
          "urlinfo", " " x $pad, $in);
        $win->print_after($line, MSGLEVEL_NO_ACT|MSGLEVEL_CLIENTCRAP,
          $text, $msg_time);
        $view->redraw;
      }
    });
  }
}

sub send2channel {
  my ($server,$target,$url,$in) =@_;
  my @cl= split(" ",Irssi::settings_get_str('urlinfo_send_channels'));
  my $s=0;

  foreach ( @cl) {
    if ( $_ eq $target || $_ eq $server->{tag}."/".$target) {
      $s=1;
      $server->command("msg $target urlinfo: $url -> $in");
      last;
    }
  }

  return $s;
}

sub ignored {
  my($uri, $server, $target) = @_;
  my @ignored_domains = split / /, Irssi::settings_get_str('urlinfo_ignore_domains');
  my $domain = $uri->host =~ s/^www\.//r;
  return 1 if grep $domain =~ /^$_$/, @ignored_domains;

  my $chans = $server->isupport("chantypes") || '#&';
  my $chan_match = qr/^[$chans]/;

  for my $ignored_target (split / /, Irssi::settings_get_str('urlinfo_ignore_targets')) {
    my($mtag, $mtarget) = split m{/}, $ignored_target;
    if ($mtag =~ $chan_match) {
      $mtarget = $mtag;
      $mtag = "*";
    }
    return 1 if _match($mtag, $server->{tag}) &&
      (!$mtarget || _match($mtarget, $target));
  }

  return 0;
}

sub _match {
  my($pattern, $name) = @_;
  $pattern =~ s/\*/.*/g;
  $name =~ /^$pattern$/i;
}

sub find_window {
  my($server, $target) = @_;
  if (my $witem = $server->window_item_find($target)) {
    return $witem->window;
  } else {
    # Maybe they have a msgs window?
    my $win = Irssi::window_find_name("(msgs)");
    # Ultimate fallback
    $win = Irssi::window_find_refnum(1) unless $win;
    return $win;
  }
}

# Based on scriptassist.
sub fork_wrapper {
  my($child, $parent) = @_;

  pipe(my $rfh, my $wfh);

  my $pid = fork;
  $pipe_in_progress = 1;

  return unless defined $pid;

  if ($pid) {
    close $wfh;
    Irssi::pidwait_add($pid);
    my $pipetag;
    my @args = ($rfh, \$pipetag, $parent);
    $pipetag = Irssi::input_add(fileno($rfh), Irssi::INPUT_READ, \&pipe_input, \@args);
  } else {
    eval {
      local $SIG{ALRM} = sub { die "Timed out\n" };
      alarm $timeout;
      $child->($wfh);
    };
    alarm 0;
    syswrite $wfh, encode_utf8("- $@") if $@;
    POSIX::_exit(1);
  }
}

sub pipe_input {
  my ($rfh, $pipetag, $parent) = @{$_[0]};
  my $line = <$rfh>;
  close($rfh);
  Irssi::input_remove($$pipetag);
  $pipe_in_progress = 0;
  $parent->($line);
}

sub setup_changed {
  $timeout = Irssi::settings_get_int("urlinfo_timeout");

  @sites = expand();
  for my $site (split / /, Irssi::settings_get_str("urlinfo_custom_domains")) {
    next unless $site;

    my($re, $from) = split /=/, $site;
    $from ||= "title";
    my($domain, $path) = split m{/}, $re, 2;
    expand_site(\@sites, "custom", {
        domain => qr/^$domain$/,
        path => defined $path ? qr/^\/$path/ : undef,
        from => $from,
    }, {});
  }
}

# ------- Initialization

if (caller) {
  # Irssi specific initialization
  require Irssi::TextUI;

  Irssi::settings_add_str($IRSSI{name}, "urlinfo_custom_domains", "");
  Irssi::settings_add_str($IRSSI{name}, "urlinfo_ignore_domains", "");
  Irssi::settings_add_str($IRSSI{name}, "urlinfo_ignore_targets", "");
  Irssi::settings_add_str($IRSSI{name}, "urlinfo_send_channels", "");
  Irssi::settings_add_int($IRSSI{name}, "urlinfo_timeout", $timeout);
  Irssi::settings_add_bool($IRSSI{name}, "urlinfo_title_unknown", 0);

  Irssi::signal_add("message irc action" => \&msg);
  Irssi::signal_add("message private" => \&msg);
  Irssi::signal_add("message public" => \&msg);

  Irssi::signal_add_last("setup changed", \&setup_changed);
  setup_changed();

  Irssi::theme_register([
    'urlinfo' => '$0 %Kinfo:%n $1',
  ]);

} else {
  # Built in test. Run this script outside Irssi to use.
  @sites = expand();
  for my $site(@sites) {
    next unless $site->{example};
    my($found_site, $uri) = get_site(\@sites, $site->{example});
    if ($found_site != $site) {
      die "Got $found_site->{name}, expected $site->{name}";
    }
    say "Get $uri";
    my $result = get_info($site, $uri);
    say $result;
    die "Got $result, expected $site->{expected}" unless $result eq $site->{expected};
  }
  say "OK";
}
