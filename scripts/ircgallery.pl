# Show IRC gallery (http://irc-galleria.net, finnish only) information
# on /WHOIS or /GALLERY

# version 1.13
# for irssi 0.8.0 by Timo Sirainen
use Symbol;
use vars qw($VERSION %IRSSI); 
$VERSION = "1.13";
%IRSSI = (
    authors	=> "Timo \'cras\' Sirainen",
    contact	=> "tss\@iki.fi", 
    name	=> "ircgallery",
    description	=> "Show IRC gallery (http://irc-galleria.net, finnish only) information on /WHOIS or /GALLERY",
    license	=> "Public Domain",
    url		=> "http://irssi.org/",
    changed	=> "2002-03-04T22:47+0100"
);


Irssi::theme_register([
  'whois_gallery', '{whois gallery $1}',
  'gallery_header', '{hilight $0} - IRC gallery information',
  'gallery_line', ' $[8]0 : $1',
  'gallery_footer', 'End of info',
  'gallery_notfound', '$0 is not in IRC gallery',
  'gallery_nolist', 'Nick list of IRC gallery not downloaded yet - please wait'
]);


my $cache_path = glob "~/.irssi/ircgallery";
my @print_queue;

my $nicklist_path = "$cache_path/nicks.list";
my $gallery_nicks_time = 0;
my %gallery_nicks = {};

my $last_whois_nick;

sub get_view_url {
  return 'http://irc-galleria.net/view.php?nick='.$_[0];
}

# print the gallery information - assumes the file is in cache directory
sub print_gallery {
  my $nick = shift;

  my $found = 0;
  my $next_channels = 0;
  my $channels;

  $. = "\n";
  my $f = gensym;
  if (!open($f, "$cache_path/$nick")) {
    Irssi::print("Couldn't open file $cache_path/$nick: $!", MSGLEVEL_CLIENTERROR);
    return;
  }
  while (<$f>) {
    last if (/\<title\>.*Etsi nick/); # unknown nick

    if ($next_channels) {
      if (m,\<a .*\>(#.*)\</a>,) {
        $channels .= "$1 ";
        next;
      } else {
        $next_channels = 0;
        if ($channels) {
          Irssi::printformat(MSGLEVEL_CRAP, 'gallery_line',
		"channels", $channels);
	  $channels = "";
	}
      }
    }

    if (/\<h1\>[^\(]*\(([^\)]*)/) {
      my $realname = $1;
      Irssi::printformat(MSGLEVEL_CRAP, 'gallery_header', $nick);
      Irssi::printformat(MSGLEVEL_CRAP, 'gallery_line',
                "ircname", $realname);
      Irssi::printformat(MSGLEVEL_CRAP, 'gallery_line',
		"url", get_view_url($nick));
      $found = 1;
      next;
    }

    if (/\<img.*src="([^"]*)".*alt="$nick"/) {
      Irssi::printformat(MSGLEVEL_CRAP, 'gallery_line',
		"image", "http://irc-galleria.net/$1");
      next;
    }

    my ($title, $value) = $_ =~ m,\<span class="otsikko"\>([^:]+):\</span\> (.*)\<br /\>,;
    if ($value =~ m,\<a .*\>(.*)\</a\>,) {
      $value = $1;
    }
    $next_channels = 1 if (m,\<span class="otsikko"\>Kanavat,);
    
    if ($title && $value) {
      if ($title eq "Maili") {
        $title = "e-mail";
      } elsif ($title =~ /Kaupunki/) {
        $title = "city";
      } elsif ($title eq "Syntynyt") {
        $title = "birthday";
      } elsif ($title eq "Muutettu") {
        $title = "last modified";
      }
      Irssi::printformat(MSGLEVEL_CRAP, 'gallery_line', $title, $value);
    }
  }
  close($f);

  if ($found) {
    Irssi::printformat(MSGLEVEL_CRAP, 'gallery_footer', $nick);
  } elsif ($print_notfound{$nick}) {
    Irssi::printformat(MSGLEVEL_CRAP, 'gallery_notfound', $nick);
  }
  
  delete $print_notfound{$nick};
}

# download the info from gallery to cache dir,
# if the files aren't there already.
sub download_nicks_info {
  foreach my $nick (@_) {
    my $filename = "$cache_path/$nick";
    if (! -f $filename) {
      # FIXME: we could do this ourself with sockets...
      Irssi::command("exec - wget -O$filename.tmp -q -UMozilla ".get_view_url($nick)."; mv $filename.tmp $filename");
    }
  }
}

# print info from all given nicks that have file in cache dir
sub gallery_show {
  foreach my $nick (@_) {
    if (-f "$cache_path/$nick") {
      print_gallery($nick);
    } else {
      push @print_queue, $nick;
    }
  }
}

sub print_whois_gallery {
  my ($server, $nick) = @_;

  if ($gallery_nicks{lc $nick}) {
    $server->printformat($nick, MSGLEVEL_CRAP, 'whois_gallery',
			 $nick, get_view_url($nick));
  }
}

# /WHOIS - print the gallery URL after realname
sub event_whois {
  my ($server, $data) = @_;
  my ($temp, $nick) = split(" ", $data);

  print_whois_gallery($server, $last_whois_nick) if ($last_whois_nick);
  $last_whois_nick = $nick;
}

sub event_end_of_whois {
  my ($server) = @_;

  if ($last_whois_nick) {
    print_whois_gallery($server, $last_whois_nick);
    $last_whois_nick = undef;
  }
}

# /GALLERY <nicks>
sub cmd_gallery {
  my @nicks = split(/[, ]/, $_[0]);
  
  if (!$gallery_nicks_time) {
    Irssi::printformat(MSGLEVEL_CLIENTERROR, 'gallery_nolist');
    return;
  }

  my @new_list;
  foreach my $nick (@nicks) {
    my $gallery_nick = $gallery_nicks{lc $nick};
    if (!$gallery_nick) {
      Irssi::printformat(MSGLEVEL_CRAP, 'gallery_notfound', $nick);
    } else {
      push @new_list, $gallery_nick;
    }
  }
  
  download_nicks_info(@new_list);
  gallery_show(@new_list);

  if ($gallery_nicks_time < time()-(3600*8)) {
    # nicklist hasn't been updated for a while, refresh it
    download_nicklist();
  }
}

# parse all known nicks from nick index file 
sub parse_nicks {
  my $filename = shift;

  %gallery_nicks = {};
  $gallery_nicks_time = time();

  my $f = gensym;
  if (!open($f, $filename)) {
    Irssi::print("Couldn't open file $filename: $!", MSGLEVEL_CLIENTERROR);
    return;
  }
  while (<$f>) {
    if (m,\<a href="view.php.*\>(.*)\</a\>,) {
      $gallery_nicks{lc $1} = $1;
    }
  }
  close($f);
}

# /EXEC finished - maybe there's new files downloaded in cache dir?
sub sig_exec_remove {
  my @new_queue;

  if (-f $nicklist_path) {
    parse_nicks($nicklist_path);
    unlink($nicklist_path);
  }

  foreach my $nick (@print_queue) {
    if (-f "$cache_path/$nick") {
      print_gallery($nick);
    } else {
      push @new_queue, $nick;
    }
  }
  @print_queue = @new_queue;
}

sub download_nicklist {
  Irssi::command("exec - wget -O$nicklist_path -q -UMozilla http://irc-galleria.net/list.php?letter=_");
}

# clear cache dir
if (-d $cache_path) {
  unlink(<$cache_path/*>);
} else {
  mkdir($cache_path, 0700) || die "Can't create cache directory $cache_dir";
}

# we need the nick list, get it once per hour
download_nicklist();

Irssi::signal_add_first('event 311', 'event_whois');
Irssi::signal_add_first('event 318', 'event_end_of_whois');
Irssi::signal_add('exec remove', 'sig_exec_remove');
Irssi::command_bind('gallery', 'cmd_gallery');
