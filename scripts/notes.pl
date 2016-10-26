# First, add $NOTE to your /format whois line so the output is shown, for example use
# '/format whois {nick $0} {nickhost $1@$2}%:{whois ircname $3}%:{whois note $NOTE}' which would produce
# Dec 12 21:24:18 -!- vague [~vague@c-e0ebe055.14-500-64736c10.cust.bredbandsbolaget.se]
# Dec 12 21:24:18 -!-  ircname  : vague
# Dec 12 21:24:18 -!-  note     : A nice guy but can be a PITA :)
# ...
#
# See /notes help for more help
#
# Prerequisites:
# irssi 0.8.13+
# DBM::Deep
# DBI

use strict;
use Irssi;
use DBI;
use Data::Dumper;
use DBM::Deep;

use vars qw($VERSION %IRSSI);

$VERSION = '0.31';
%IRSSI = (
    authors     => 'vague',
    contact     => 'vague!#irssi\@freenode',
    name        => 'notes',
    description => 'Keeps notes on users and displayes the note in /whois output if the host/nick matches',
    license     => 'GPL2',
);

my $notes;
my $note_expando = '';
my @chatnets;
push @chatnets, $_->{name} for(Irssi::chatnets());

my $DEBUG_ENABLED = 1;
sub DEBUG { $DEBUG_ENABLED }

sub init {
  my $filename = Irssi::settings_get_str("notes_db") || Irssi::get_irssi_dir() . "/notes.db";
  $notes = DBM::Deep->new( $filename );
}

sub _print {
  my ($msg) = @_;
  Irssi::active_win->print($msg, Irssi::MSGLEVEL_CLIENTCRAP);
}

sub _error {
  my ($msg) = @_;
  Irssi::active_win->print($msg, Irssi::MSGLEVEL_CLIENTCRAP);
}

sub _debug_print {
  return unless DEBUG;
  my ($msg) = @_;
  Irssi::active_win->print($msg, Irssi::MSGLEVEL_CLIENTCRAP);
}

sub sig_whois {
  my ($server, $data, undef, undef) = @_;
  my ($me, $nick, $user, $host) = split(" ", $data);

  if(exists $notes->{lc $server->{tag}}->{nick}->{lc $nick}) {
    $note_expando = $notes->{lc $server->{tag}}->{nick}->{lc $nick};
  }
  else {
    my $masks = $notes->{lc $server->{tag}}->{mask};
    while(my ($mask, $value) = each %$masks) {
      if($server->mask_match_address(lc $mask, '*', "$nick!$user\@$host")) {
        $note_expando = $value;
        return;
      }
    }
  }
}

sub expando_note {
  my ($tmp) = $note_expando;
  $note_expando = '';
  return $tmp;
}

sub cmd_notes_add {
  my ($args, $server, $witem) = @_;
  my $tmpargs = [ sort {$a =~ /^-/ <=> $b !~ /^-/} split / /, $args ];
  my @options_list = Irssi::command_parse_options('notes add', join(' ', @$tmpargs));

  if(!@options_list) {
    _error "Could not parse arguments\n" . usage();
    return;
  }

  my @minusargs = grep {/^-/} split / /, $args;
  my @rest = grep {!/^-/} split / /, $args;
  my ($network, $type, $pattern);

  foreach(@minusargs) {
    s/^-//;
    if(/nick|mask/i) {
      $type = $_;
      $pattern = shift @rest;
    }
    else {
      if(join(' ', @chatnets) =~ /$_/i) {
        $network = $_;
      }
    }
  }

  if(not defined $network) {
    $network = Irssi::active_server()->{tag};
  }

  unless ($type || $pattern) {
    _error "Could not parse command\n" . usage();
    return;
  }

  $notes->{lc $network}->{lc $type}->{lc $pattern} = join ' ', @rest;
  _print "Added $pattern to $network";
}

sub cmd_notes_del {
  my ($args, $server, $witem) = @_;
  my $tmpargs = [ sort {$a =~ /^-/ <=> $b !~ /^-/} split / /, $args ];
  my @options_list = Irssi::command_parse_options('notes del', join(' ', @$tmpargs));

  if(!@options_list) {
    _error "Could not parse arguments\n" . usage();
    return;
  }

  my @minusargs = grep {/^-/} split / /, $args;
  my @rest = grep {!/^-/} split / /, $args;
  my ($network, $type, $pattern, $purge);

  foreach(@minusargs) {
    s/^-//;
    if(/nick|mask/i) {
      $type = $_;
      $pattern = shift @rest;
    }
    elsif(/purge/) {
      $purge = 1;
    }
    else {
      if(join(' ', @chatnets) =~ /$_/i) {
        $network = $_;
      }
    }
  }

  unless ($purge || $type || $pattern) {
    _error "Could not parse command\n" . usage();
    return;
  }

  if($purge) {
    if(defined $network) {
      delete $notes->{lc $network};
      _print "Deleted all notes in $network";
    }
    else {
      $notes->clear;
      _print "Deleted all notes";
    }
  }
  else {
    if(not defined $network) {
      $network = Irssi::active_server()->{tag};
    }

    if(exists $notes->{lc $network}->{lc $type}->{lc $pattern}) {
      delete $notes->{lc $network}->{lc $type}->{lc $pattern};
      _print "Deleted $pattern from $network";
    }
    else {
      _error "\u$type '$pattern' on '$network' not found";
    }
  }
}

sub cmd_notes_list {
  my ($args, $server, $witem) = @_;
  my $tmpargs = [ sort {$a =~ /^-/ <=> $b !~ /^-/} split / /, $args ];
  my @options_list = Irssi::command_parse_options('notes list', join(' ', @$tmpargs));

  if(!@options_list) {
    _error "Could not parse arguments\n" . usage();
    return;
  }

  my @minusargs = grep {/^-/} split / /, $args;
  my @rest = grep {!/^-/} split / /, $args;
  my ($network, $type, $pattern, $all);

  foreach(@minusargs) {
    s/^-//;
    if(/nick|mask/i) {
      $type = $_;
      $pattern = shift @rest;
    }
    elsif(/all/) {
      $all = 1;
    }
    else {
      if(join(' ', @chatnets) =~ /$_/i) {
        $network = $_;
      }
    }
  }

  if(not defined $network) {
    $network = Irssi::active_server()->{tag};
  }

  if($all) {
    foreach my $tag (keys %$notes) {
      Irssi::active_win()->{active}->print("--- Notes for $tag ---");
      my $nicks = $notes->{$tag}->{nick};
      while(my ($nick, $value1) = each %$nicks) {
        Irssi::active_win()->{active}->print($nick . ": " . $value1);
      }
      my $masks = $notes->{$tag}->{mask};
      while(my ($hostmask, $value2) = each %$masks) {
        Irssi::active_win()->{active}->print($hostmask . ": " . $value2);
      }
    }
  }
  else {
    if(defined $type && defined $pattern) {
      Irssi::active_win()->{active}->print("--- Note on $network/$pattern ---");
      Irssi::active_win()->{active}->print($notes->{lc $network}->{lc $type}->{lc $pattern});
    }
    else {
      Irssi::active_win()->{active}->print("--- Notes for $network ---");
      my $nicks = $notes->{lc $network}->{nick};
      while(my ($nick, $value1) = each %$nicks) {
        Irssi::active_win()->{active}->print($nick . ": " . $value1);
      }
      my $masks = $notes->{lc $network}->{mask};
      while(my ($hostmask, $value2) = each %$masks) {
        Irssi::active_win()->{active}->print($hostmask . ": " . $value2);
      }
    }
  }
}

sub usage {
  return "Usage: %_/notes%_ add [-tag] -nick|-mask pattern <notes>\n" .
         "       %_/notes%_ del [-tag] -purge|(-nick|-mask pattern)\n" .
         "       %_/notes%_ list [-tag] -all|(-nick|-mask pattern)";
}

Irssi::command_bind('notes' => sub {
  my ( $data, $server, $item ) = @_;
  $data =~ s/\s+$//g;
  Irssi::command_runsub ('notes', $data, $server, $item ) ;
});

Irssi::command_bind('notes add', \&cmd_notes_add);
Irssi::command_bind('notes del', \&cmd_notes_del);
Irssi::command_bind('notes list', \&cmd_notes_list);
Irssi::command_bind('notes help', sub { Irssi::active_win()->print(usage()); });

Irssi::command_set_options('notes add', join(' ', @chatnets) . ' nick mask');
Irssi::command_set_options('notes del', join(' ', @chatnets) . ' purge nick mask');
Irssi::command_set_options('notes list', join(' ', @chatnets) . ' all nick mask');

Irssi::settings_add_str('Notes', 'notes_db', Irssi::get_irssi_dir() . "/notes.db");

Irssi::signal_add_first('event 311', \&sig_whois);
Irssi::expando_create('NOTE', \&expando_note,
                     {'event 311' => 'None' });

init();
