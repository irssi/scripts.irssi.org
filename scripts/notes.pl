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
use warnings;

use Irssi;
use DBI;
use DBM::Deep;
use List::MoreUtils qw(any);
no autovivification;
use feature qw(fc);
use Data::Dumper;

our $VERSION = '1.0';
our %IRSSI = (
    authors     => 'vague',
    contact     => 'vague!#irssi@freenode',
    name        => 'notes',
    description => 'Keeps notes on users and displayes the note in /whois output if the host/nick matches',
    license     => 'GPL2',
    changed     => '22 Apr 20:00:00 CEST 2017',
);

my ($notes, $expando);
my @chatnets;
my $DEBUG_ENABLED;

push @chatnets, $_->{name} for(Irssi::chatnets());

sub DEBUG { $DEBUG_ENABLED }

sub _print {
  my ($msg, $w) = @_;
  $w = Irssi::active_win() unless $w;
  $w->print($msg, Irssi::MSGLEVEL_CLIENTCRAP);
}

sub _error {
  my ($msg, $w) = @_;
  $w = Irssi::active_win() unless $w;
  $w->print($msg, Irssi::MSGLEVEL_CLIENTCRAP);
}

sub _debug {
  my ($msg, $w) = @_;

  return unless DEBUG;

  $w = Irssi::active_win() unless $w;
  $w->print($msg, Irssi::MSGLEVEL_CLIENTCRAP);
}

sub init {
  $DEBUG_ENABLED = Irssi::settings_get_bool("notes_verbose");
  my $filename = Irssi::settings_get_str("notes_db") // Irssi::get_irssi_dir() . "/notes.db";
  $filename =~ s,^~,$ENV{HOME},e;
  _debug "Loading database from " . $filename, Irssi::window_find_refnum(1);
  $notes = DBM::Deep->new( file => $filename, autoflush => 1 );
  $expando = '';
}
 
sub sig_whois {
  my ($server, $data, undef, undef) = @_;
  my ($me, $nick, $user, $host) = split(" ", $data);
  my $network = fc $server->{tag};
  $nick = fc $nick;

  if ($notes->{$network}{nick}{$nick}) {
    $expando = $notes->{$network}{nick}{$nick};
  }
  else {
    my $masks = $notes->{$network}{mask};
    while (my ($mask, $value) = each %$masks) {
      if ($server->mask_match_address(fc $mask, $nick, sprintf('%s@%s', $user, $host))) {
        $expando = $value;
      }
    }
  }
}

sub expand_note {
  my $tmp = $expando;
  $expando = '';
  return $tmp;
}

sub cmd_notes_add {
  my ($data, $server, $witem) = @_;
  my ($args, $rest) = Irssi::command_parse_options('notes add', $data);
  my ($type, $pattern);

  unless ($rest) {
    _error "You have to specify notes to add", $witem;
  }

  if (any {/nick|mask/i} keys %$args) {
    _error("Can't specify both -nick and -mask", $witem) && return if $args->{nick} && $args->{mask};

    $type = $args->{nick} ? 'nick' : 'mask';
    $pattern = fc $args->{$type};
  }

  my $patt = join('|', @chatnets);
  my @networks = grep {/$patt/i} keys %$args;

  unless (@networks) {
    push @networks, fc $server->{tag};
  }

  unless ($type && $pattern) {
    _error "Could not parse command\n" . usage(), $witem;
    return;
  }

  for (@networks) {
    $notes->{$_}{$type}{$pattern} = $rest;
    _print "Added $type $pattern to $_ with data: $rest", $witem;
  }
}

sub cmd_notes_del {
  my ($data, $server, $witem) = @_;
  my ($args, $rest) = Irssi::command_parse_options('notes del', $data);
  my ($type, $pattern);

  if (any {/nick|mask/i} keys %$args) {
    _error("Can't specify both -nick and -mask", $witem) && return if $args->{nick} && $args->{mask};

    $type = $args->{nick} ? 'nick' : 'mask';
    $pattern = fc $args->{$type};
  }

  my $patt = join('|', @chatnets);
  my @networks = grep {/$patt/i} keys %$args;

  my $purge = (defined $args->{purge} ? 1 : 0);
  unless ($purge || ($type && $pattern)) {
    _error "Could not parse command\n" . usage(), $witem;
    return;
  }

  if ($purge && !@networks) {
    $notes->clear;
    _print "Deleted all notes", $witem;
    return;
  }
  else {
    push @networks, fc $server->{tag} if !@networks;
  }

  for (@networks) {
    if ($purge) {
      delete $notes->{$_};
      _print "Deleted all notes for users on $_", $witem;
    }
    elsif ($notes->{$_}{$type}{$pattern}) {
      delete $notes->{$_}{$type}{$pattern};
      delete $notes->{$_}{$type} if !keys %{$notes->{$_}{$type}};
      delete $notes->{$_} if !keys %{$notes->{$_}};
      _print "Deleted $type $pattern from $_", $witem;
    }
    else {
      _error "\u$type '$pattern' on '$_' not found", $witem;
    }
  }
}

sub cmd_notes_list {
  my ($data, $server, $witem) = @_;
  my ($args, $rest) = Irssi::command_parse_options('notes list', $data);
  my ($type, $pattern);

  if (any {/nick|mask/i} keys %$args) {
    _error("Can't specify both -nick and -mask", $witem) && return if $args->{nick} && $args->{mask};

    $type = $args->{nick} ? 'nick' : 'mask';
    $pattern = fc $args->{$type};
  }

  my $patt = join('|', @chatnets);
  my @networks = map {fc} grep {/$patt/i} keys %$args;
  my $all = !$type && !$pattern;

  if ($all) {
    for my $tag (keys %$notes) {
      next if @networks && !any {/$tag/} @networks;
      next unless keys %{$notes->{$tag}};

      _print "--- Notes for $tag ---", $witem;
      my $nicks = $notes->{$tag}->{nick};
      while (my ($nick, $value1) = each %$nicks) {
        _print "$nick: $value1", $witem;
      }
      my $masks = $notes->{$tag}->{mask};
      while (my ($hostmask, $value2) = each %$masks) {
        _print "$hostmask: $value2", $witem;
      }
    }
  }
  else {
    unless (@networks) {
      push @networks, fc $server->{tag};
    }

    for (@networks) {
      if ($type && $pattern) {
        if ($notes->{$_}{$type}{$pattern}) {
          _print "--- Note on $_/$type/$pattern ---", $witem;
          _print $notes->{$_}{$type}{$pattern}, $witem;
        }
        else {
          _print "--- Nothing on $_/$type/$pattern ---", $witem;
        }
      }
      else {
        return unless keys %{$notes->{$_}};
  
        Irssi::active_win()->print("--- Notes for $_ ---");
        my $nicks = $notes->{$_}{nick};
        while (my ($nick, $value1) = each %$nicks) {
          Irssi::active_win()->print($nick . ": " . $value1);
        }
        my $masks = $notes->{$_}{mask};
        while (my ($hostmask, $value2) = each %$masks) {
          Irssi::active_win()->print($hostmask . ": " . $value2);
        }
      }
    }
  }
}

sub usage {
  return "Usage: %_/notes%_ add [-tag] -nick|-mask <pattern> <notes>\n" .
         "       %_/notes%_ del [-tag] [-purge] -nick|-mask <pattern>\n" .
         "       %_/notes%_ list [-tag] [-nick|-mask <pattern>]";
}

Irssi::command_bind('notes' => sub {
  my ( $data, $server, $item ) = @_;
  $data =~ s/\s+$//g;
  Irssi::command_runsub ('notes', $data, $server, $item ) ;
});

Irssi::command_bind('notes add', 'cmd_notes_add');
Irssi::command_bind('notes del', 'cmd_notes_del');
Irssi::command_bind('notes list', 'cmd_notes_list');
Irssi::command_bind('notes help', sub { Irssi::active_win()->print(usage()); });

Irssi::command_set_options('notes add', join(' ', @chatnets) . ' +nick +mask');
Irssi::command_set_options('notes del', join(' ', @chatnets) . ' purge +nick +mask');
Irssi::command_set_options('notes list', join(' ', @chatnets) . ' +nick +mask');

Irssi::settings_add_str('Notes', 'notes_db', Irssi::get_irssi_dir() . "/notes.db");
Irssi::settings_add_bool('Notes', 'notes_verbose', 0);

Irssi::signal_add('setup changed' => \&init);
Irssi::signal_add_first('event 311', \&sig_whois);
Irssi::expando_create('NOTE', \&expand_note,
                     {'event 311' => 'None' });

init();
