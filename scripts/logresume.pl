# Idea based on queryresume.pl by Stefan Tomanek

### NOTES/BUGS
# - /set logresume_query_lines
# - /set logresume_channel_lines (set to 0 to make this script act more like queryresume.pl)
# - Coloured logs (/set autolog_colors ON) work perfectly well, and are recommended if you want it to look like you never left
# - bonus feature: /logtail 10 will print the last 10 lines of a log
# - bonus feature: /logview will open the log in your PAGER, or do e.g. /logview screen vim -R.  You'll need to be using irssi in screen.  Running the program without screen is possible, but you need to ^L to redraw after closing it, and if you look at it too long irssi blocks on output and all your connections will ping out
# - behaviour on channel join fail is potentially a little odd.  Unmotivated to test or fix this.

use strict;
use Irssi;
use Fcntl qw( :seek O_RDONLY );

our $VERSION = "0.6";
our %IRSSI = (
  name        => "logresume",
  description => "print last n lines of logs when opening queries/channels",
  url         => "http://explodingferret.com/linux/irssi/logresume.pl",
  authors     => "ferret",
  contact     => "ferret(tA)explodingferret(moCtoD), ferret on irc.freenode.net",
  licence     => "Public Domain",
  changed     => "2012-10-08",
  changes     => "0.6: added memory of windows that have been logresumed already"
               . "0.5: added /logtail and /logview"
               . "0.4: fixed problem with lines containing %, removed use warnings"
               . "0.3: swapped File::ReadBackwards for internal tail implementation",
  modules     => "",
  commands    => "logtail, logview",
  settings    => "logresume_channel_lines, logresume_query_lines",
);

Irssi::print "$IRSSI{name} version $VERSION loaded, see the top of the script for help";
if ( ! Irssi::settings_get_bool('autolog') ) {
  Irssi::print( "$IRSSI{name}: /set autolog is currently OFF.  This script probably won't work well unless it's ON" );
}

Irssi::settings_add_int($IRSSI{name}, 'logresume_channel_lines', 15);
Irssi::settings_add_int($IRSSI{name}, 'logresume_query_lines',   20);

my $debug = 0;
sub debug_print { $debug and Irssi::print $IRSSI{name} . ' %RDEBUG%n: ' . $_[0]; } 
sub prettyprint { Irssi::print $IRSSI{name} . ' %Winfo%n: ' . $_[0]; } 

# This hash of hashes maps servertag -> item names -> _irssi.  The point of this is so that
# we don't print the last n log entries into a window that just recently had that item in it
# (e.g. on server reconnect), since that content is like right there already.
# the _irssi hash key is used as a unique identifier for windows (although they get reused).
# Was using refnum for this originally, but it's very difficult to implement with that due to
# the way the 'window refnum changed' and 'window destroyed' signals work (mostly the order
# they run in).
my %haveprinted;

# initial fill of hash
sub inithash {
  for my $win ( Irssi::windows() ) {
    for my $winitem ( $win->items() ) {
      next unless $winitem->{type} eq 'QUERY' or $winitem->{type} eq 'CHANNEL';
      next unless defined $winitem->{server} and defined $winitem->{name};
      $haveprinted{$winitem->{server}{tag}}{$winitem->{name}} = $win->{_irssi};
    }
  }
}

inithash();

# a new log was opened! initiate the process of printing some stuff to the screen
Irssi::signal_add_last 'log started' => sub {
  my ( $log ) = @_;
  my $lines;

  for my $logitem ( @{ $log->{items} } ) {
    my $server = Irssi::server_find_tag( $logitem->{servertag} );
    next unless defined $server;
    
    next unless defined $logitem->{name};
    my $winitem = $server->window_item_find( $logitem->{name} );
    next unless defined $winitem;
    
    my $irssiref = $winitem->window()->{_irssi};
    my $servertag = $server->{tag};
    my $itemname = $winitem->{name};

    debug_print( "log started | servertag='$servertag' itemname='$itemname' irssiref='$irssiref'" );
  
    if( $winitem->{type} eq 'QUERY' ) {
      $lines = Irssi::settings_get_int('logresume_query_lines');
    } elsif( $winitem->{type} eq 'CHANNEL' ) {
      $lines = Irssi::settings_get_int('logresume_channel_lines');
    } else {
      next;  # other window types not implemented
    }
    
    # don't print log output if we already did for this window, as that would indicate the
    # item was recently in this window, so the scrollback contains this stuff already
    if( $haveprinted{$servertag}{$itemname} ne $irssiref ) {
      $haveprinted{$servertag}{$itemname} = $irssiref;
      debug_print( "log started || not recorded as already printed, will do print_tail" );
      print_tail( $winitem, $lines );
    }
  }
};

# when windows are destroyed we need to remove entries from %haveprinted
Irssi::signal_add 'window destroyed' => sub {
  my ( $win ) = @_;
  my $irssiref = $win->{_irssi};
  debug_print( "window destroyed | refnum='$win->{refnum}' irssiref='$irssiref'" );

  for my $servertag (keys %haveprinted) {
    for my $itemname (keys %{$haveprinted{$servertag}}) {
      if ( $haveprinted{$servertag}{$itemname} eq $irssiref ) {
        debug_print( "window destroyed || removed servertag='$servertag' itemname='$itemname'" );
        $haveprinted{$servertag}{$itemname} = '';
      }
    }
  }
};

Irssi::signal_add 'window item moved' => sub {
  my ( $to_win, $winitem, $from_win ) = @_;
  my $servertag = $winitem->{server}{tag};
  my $itemname = $winitem->{name};

  debug_print( "window item moved | servertag='$servertag' itemname='$itemname' was='$haveprinted{$servertag}{$itemname}' fromref='$from_win->{_irssi}' toref='$to_win->{_irssi}'" );
  $haveprinted{$servertag}{$itemname} = $to_win->{_irssi};
};

Irssi::signal_add 'query nick changed' => sub {
  my ( $win, $oldnick ) = @_;

  debug_print( "query nick changed | oldnick='$oldnick' newnick='$win->{name}' transferring='$haveprinted{$win->{server}{tag}}{$oldnick}'" );
  $haveprinted{$win->{server}{tag}}{$win->{name}} = $haveprinted{$win->{server}{tag}}{$oldnick};
  $haveprinted{$win->{server}{tag}}{$oldnick} = '';
};

sub print_tail {
  my ( $winitem, $lines ) = @_; # winitem is a channel or query or whatever

  return unless $lines > 0;

  my $log = get_log_filename( $winitem );
  return unless defined $log;

  my $winrec = $winitem->window(); # need to print to the window, not the window item

  for( tail( $lines, $log ) ) { # sub tail is defined below
    s/%/%%/g; # prevent irssi format notation being expanded
    $winrec->print( $_, MSGLEVEL_NEVER );
  }

  $winrec->print( '%K[%Clogresume%n ' . $log . '%K]%n' );
}


sub get_log_filename {
  my ( $winitem ) = @_;
  my ( $tag, $name ) = ( $winitem->{server}{tag}, $winitem->{name} );

  my @logs = map { $_->{real_fname} } grep {
    grep {
      $_->{name} eq $name and $_->{servertag} eq $tag
    } @{ $_->{items} }
  } Irssi::logs();

  unless( @logs ) {
    debug_print( "no logfile for $tag, $name" );
    return undef;
  }

  debug_print( "surplus logfile for $tag, $name: $_" ) for @logs[1..$#logs];
  return $logs[0];
}


Irssi::command_bind 'logtail' => sub {
  my ( $lines ) = @_;
  if ( not $lines =~ /[1-9][0-9]*/ ) {
    prettyprint( 'usage: /logtail <number>' );
  }

  print_tail( Irssi::active_win()->{active}, $lines );
};


# irssi will NOT communicate in any way with the server while the command is running, unless the command returns immediately (e.g. running screen in screen, or backgrounded X11 text editor).  So use screen.
# usage: /logview foo bar baz
#  will run: foo bar baz filename.log
Irssi::command_bind 'logview' => sub {
  my ( $args, $server, $winitem ) = @_;

  my $log = get_log_filename( $winitem );
  return unless defined $log;

  my $pager = $ENV{PAGER} || "less";
  my $program = $_[0] || "screen $pager";

  system( split( / /, $program ), $log ) == 0 or do {
    if ( $? == -1 ) {
      prettyprint( "logview: running command '$program $log' failed: $!" );
    } elsif ( $? & 127 ) {
      prettyprint( "logview: running command '$program $log' died with signal " . ( $? & 127 ) );
    } else {
      prettyprint( "logview: running command '$program $log' exited with status " . ( $? >> 8 ) );
    }
  };
};


sub tail {
  my ( $needed_lines, $filename ) = @_;
  return unless $needed_lines > 0;

  my @lines = ();

  sysopen( my $fh, $filename, O_RDONLY ) or return;
  binmode $fh;
  my $blksize = (stat $fh)[11];

  # start at the end of the file 
  my $pos = sysseek( $fh, 0, SEEK_END ) or return;

  # for the first chunk read a trailing partial block, so we start on what's probably a natural disk boundary
  # if there's no trailing partial block read a full one
  # Also guarantees that $pos will become zero before it becomes negative
  $pos -= $pos % $blksize || $blksize;

  # - 1 is because $lines[0] is partial
  while ( @lines - 1 < $needed_lines ) {
    # go to top of this chunk
    sysseek( $fh, $pos, SEEK_SET ) or last; # partial output better than none

    sysread( $fh, my $buf, $blksize );
    last if $!;

    # ruin my lovely generic tail function
    $buf =~ s/^--- Log.*\n//mg;

    if ( @lines ) {
      splice @lines, 0, 1, split( /\n/, $buf . $lines[0], -1 );
    } else {
      @lines = split( /\n/, $buf, -1 );
      # unix philosophy (as tail, wc, etc.): trailing newline is not a line for counting purposes
      pop @lines if @lines and $lines[-1] eq "";
    }

    last if $pos == 0;

    $pos -= $blksize;
  }

  return ( $needed_lines >= @lines ? @lines : @lines[ -$needed_lines .. -1 ] );
}
