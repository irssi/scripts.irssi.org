use 5.014;  # strict, Unicode 6, unicode regexp modifiers
BEGIN {
  require charnames;
  if ($^V gt v5.16.0) {
    charnames->import(':loose');
  } else {
    print "unicode.pl: Loose unicode matching not supported on this version of Perl.";
    print "Upgrade to 5.16 or newer for case-insensitive names.";
    charnames->import(':full');
  }
}
use Encode qw(decode_utf8 encode_utf8);
use POSIX ();
use Unicode::UCD qw(charblock charblocks charinfo);

use Irssi qw(command_bind command_bind_first);
our $VERSION = "2";
our %IRSSI = (
    authors     => 'David Leadbeater',
    contact     => 'dgl@dgl.cx',
    name        => 'unicode',
    description => 'Get infomation about unicode characters',
    license     => 'WTFPL <http://dgl.cx/licence>',
    url         => 'http://dgl.cx/irssi',
);

my $CHARCODE_RE = qr/(?:\d+|(?:U\+|0x)[0-9a-f]+)/ai;

my $pipe_in_progress;

my $USAGE = <<'EOF';
/UNICODE <character | code | name | block name>

Print details about Unicode characters or blocks.

Details about a single character:
  /unicode 😸
  /unicode U+1F626

Print details about a block (more concise):
  /unicode Emoticons

Print details about a range:
  /unicode U+1F600..U+1F700

Find a character:
  /unicode /\bcat\b/
EOF

if (Irssi::settings_get_str('term_charset') !~ /utf-8/i) {
  print "\x{3}4unicode.pl\x{3}: term_charset is not set to UTF-8. ",
    "Please set your terminal and Irssi to use UTF-8 so this script works correctly.";
  print "Current settings:";
  print "  Irssi term_charset = ", Irssi::settings_get_str('term_charset');
  print "  $_ = $ENV{$_}" for grep /^(?:LANG|LC_|TERM$)/, keys %ENV;
}

# TODO: Can we fix Irssi to not need encoding here?
sub p { Irssi::active_win()->print(encode_utf8("@_"), MSGLEVEL_CLIENTCRAP) }

command_bind_first help => sub {
  my($arg) = @_;
  return unless $arg =~ /^unicode\s*$/i;
  print $USAGE;
  print "[Perl internal unicode version " . Unicode::UCD::UnicodeVersion() . "]";
  Irssi::signal_stop();
};

command_bind unicode => sub {
  my($arg) = @_;

  if(!$arg) {
    print "Usage: /UNICODE <character | code | name | block name>";
    print "See /help unicode for more.";
    return;
  }

  # Decode is always required right now, but really irssi core should handle
  # this so written in a future proof way.
  $arg = decode_utf8 $arg unless Encode::is_utf8($arg, 1);

  if (length $arg == 1) {
    # Single character
    print_info(ord $arg, 1);
  } elsif ($arg =~ /^$CHARCODE_RE\s*$/) {
    # Character code (decimal or hex)
    print_info($arg, 1);
  } elsif ($arg =~ /^($CHARCODE_RE)\s*\.\.\s*($CHARCODE_RE)\s*$/) {
    # Character range
    my($start, $end) = (charinfo($1), charinfo($2));
    print_info($_) for hex $start->{code} .. hex $end->{code};
  } elsif ($arg =~ m{/(.*)/\s*$}) {
    my $re = qr/$1/i;
    if ($pipe_in_progress) {
      p "Another unicode search is in progress";
      return;
    }
    fork_wrapper(sub { # Child
      my($fh) = @_;
      my @found;
      my $data = "";
      # This is not a public API at all, but taking 2 minutes when using the
      # public API is a bit of a joke, so we take advantage of perl's cache if
      # we can.
      $data = do "unicore/Name.pl";
      if (!$data) {
        for my $block(map { $_->[0] } values %{charblocks()}) {
          for($block->[0] .. $block->[1]) {
            my $name = charnames::viacode($_);
            next unless $name;
            $data .= sprintf "%X %s\n", $_, $name;
          }
        }
      }
      while ($data =~ /(?:^([A-F0-9]+).*$re)/gm) {
        push @found, $1;
      }
      if(@found > 100) {
        syswrite $fh, "- More than 100 matches found, aborting";
      } else {
        syswrite $fh, "@found";
      }
    },
    sub { # Parent
      my($line) = @_;
      if ($line =~ /^- (.*)/) {
        p $1;
      } elsif (!$line) {
        p "No matches found";
      } else {
        print_info($_) for sort { hex $a <=> hex $b } split / /, $line;
      }
    });
  } else {
    # Character (or named sequence) or block name
    my $string = charnames::string_vianame($arg);
    if ($string) {
      # Character(s) found
      for my $char(split //, $string) {
        print_info(ord $char);
      }
    } elsif(charblock $arg) {
      my $block = charblock($arg);
      print_info($_) for $block->[0]->[0] .. $block->[0]->[1];
    } else {
      p "Not found. Try for example /unicode /\\bcat\\b/ for partial matching.";
    }
  }
};

sub print_info {
  my($character, $extra) = @_;
  my $info = charinfo $character;

  if (!$info) {
    p "Character not found" if $extra;
  } else {
    p chr(hex $info->{code}) . " (U+$info->{code}): $info->{name}";
    return unless $extra;

    my %extra;
    for(qw(block category script)) {
      $extra{$_} = $info->{$_}
    }
    # Optional things
    for(qw(decimal digit numeric upper lower title)) {
      $extra{$_} = $info->{$_} if $info->{$_};
    }
    $extra{"utf-8 (hex)"} = join "", map sprintf("\\x%02x", ord), split //, encode_utf8 chr(hex $info->{code});
    p " " x (7 + length $info->{code}), join(", ", map { "$_=$extra{$_}" } sort keys %extra);
  }
}

# Based on scriptassist.
sub fork_wrapper {
  my($child, $parent) = @_;

  pipe(my $rfh, my $wfh);

  my $pid = fork;
  $pipe_in_progress = 1;

  return unless defined $pid;

  if($pid) {
    close $wfh;
    Irssi::pidwait_add($pid);
    my $pipetag;
    my @args = ($rfh, \$pipetag, $parent);
    $pipetag = Irssi::input_add(fileno($rfh), INPUT_READ, \&pipe_input, \@args);
  } else {
    eval {
      $child->($wfh);
    };
    syswrite $wfh, "- $@" if $@;
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

command_bind charblocks => sub {
  my @blocks = sort keys %{charblocks()};
  print for @blocks;
}
