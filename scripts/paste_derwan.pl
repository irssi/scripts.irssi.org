# $Id: paste_derwan.pl,v 1.0-rc5 2004/11/13 14:32 derwan Exp $
#

use strict;
use vars qw($VERSION %IRSSI %HELP);

use Irssi 0 qw
(
   active_win server_find_tag signal_stop window_find_name parse_special
);

$VERSION = '1.0-rc5';
%IRSSI =
(
   'authors'      => 'Marcin Rozycki',
   'contact'      => 'derwan@irssi.pl',
   'name'         => 'paste',
   'description'  => 'Pasting lines to specified targets, type "/paste -help" for help',
   'license'      => 'GNU GPL v2',
   'modules'      => '',
   'url'          => 'http://derwan.irssi.pl',   
   'changed'      => 'Sat Nov 13 14:32:13 2004',
);

$HELP{'paste'} = <<EOF;
PASTE [-help] [-c] [-q] [-msg | -notice] [-<server tag>] [<target>] [<indexes>]

    -help: print this help
    -c: enable colors
    -q: quiet mode (pasted lines are not dispalyed)
    -msg: sends messages as msg (as default)
    -notice: sends messages as notice
    -<server target>: sends messages to specified server
    <target>: targets (separated with commas)
    <indexes>: indexes of lines to paste ( separated with spaces)

Examples:

    /PASTE                           - pasting to active channel or query
    /PASTE -c                        - pasting to active channel or query with colors
    /PASTE -c 1 3-5                  - pasting to active channel or query lines 1, 3, 4 and 5
    /PASTE -notice                   - pasting to active item - messages sent as notice, not msg
    /PASTE derwan                    - sends messages to derwan 
    /PASTE -ircnet -c derwan,#irssi  - sends messages (with colors) to derwan and #irssi in IRCNet

Paste window - indexes:

    [0] [<index>] [<index from>-<index to>]
    
Examples:

    0          - cancel
    4          - line 4
    4 8 9 10   - lines 4, 8, 9, 10
    4 8-10     - lines 4, 8, 9, 10

Themes:

    paste_normal             - \$0 line
    paste_reverse            - \$0 line
    paste_count              - \$0 count, \$1 server tag, \$2 target
    paste_input
    paste_no_server          - \$0 comment
    paste_argument_missing   - \$0 option, \$1 comment
    paste_argument_unknown   - \$0 option, \$1 comment
    paste_nothing

Your version is $VERSION - for updates visit $IRSSI{url}
Mail bug reports and suggestions to <$IRSSI{contact}>
EOF

my ( $p );

# paste (str data, rec server, rec window)
sub paste ($$$)
{
    buf_destroy();

    $p = {};
    $p->{color} = 0;
    $p->{cmd} = 'msg';
    $p->{quiet} = 0;

    my $win = active_win();

    foreach my $arg ( split /\s+/, $_[0] )
    {
       ( $arg eq '-help' ) and Irssi::print($HELP{'paste'}, MSGLEVEL_CLIENTCRAP), return;
       ( $arg eq '-c' ) and $p->{color} = 1, next;
       ( $arg eq '-q' ) and $p->{quiet} = 1, next;
       ( $arg =~ m/^-(msg|notice)$/ ) and $p->{cmd} = $1, next;
       ( $arg =~ m/^-(.*)$/ and !$p->{tag} ) and $p->{tag} = $1, next;
       ( $arg =~ m/^([^-\s]*[^-\d]+[^\s]*)$/ and !$p->{target} ) and $p->{target} = $1, next;
       ( $arg =~ m/^([1-9]\d*)$/ ) and $p->{l}->{$1} = 1, next;
       if ( $arg =~ m/^([1-9]\d*)-(\d+)$/ and $1 <= $2 )
       {
          map { $p->{l}->{$_} = $p->{buf}->[$_-1] } ( $1 .. $2 );
          next;
       }

       $win->printformat
       (
          MSGLEVEL_CRAP, 'paste_argument_unknown', $arg, 'type /paste -help for help'
       );
       buf_destroy(), return;
    }

    if ( !exists $p->{tag} or !defined $p->{tag} )
    {
       if ( !ref $_[1] and !ref $win->{server} )
       {
           $win->printformat
	   (
	      MSGLEVEL_CRAP, 'paste_argument_missing', 'server tag', 'type /paste -help for help'
	   );
           buf_destroy(), return;     
       }
       $p->{tag} = ( ref $_[1] ) ? $_[1]->{tag} : $win->{active}->{server}->{tag};
    }
    elsif ( ! ref server_find_tag($p->{tag}) )
    {
       $win->printformat
       (
          MSGLEVEL_CRAP, 'paste_argument_unknown', $p->{tag}, 'not connected to that server'
       );
       buf_destroy(), return;
    }

    unless ( exists $p->{target} and defined $p->{target} )
    {
       if ( !ref $win->{active} or !$win->{active}->{name} )
       {
          $win->printformat
	  (
	     MSGLEVEL_CRAP, 'paste_argument_missing', 'target', 'type /paste -help for help'
          );
          buf_destroy(), return;
       }
       $p->{target} = $win->{active}->{name};
    }

    if ( buf_create() == 0 )
    {
       $win->printformat
       (
          MSGLEVEL_CRAP, 'paste_nothing'
       );
       buf_destroy(), return;
    }
    
    foreach my $idx ( keys %{$p->{l}} )
    {
       $p->{l}->{$idx} = $p->{buf}->[$idx-1];
    }

    buf_destroy(), return if ( buf_flush() != 0 );

    $p->{win} = sprintf('paste.%d', (int(rand(9000))+1000));
    my $input = Irssi::Windowitem::window_create($p->{win}, 1);
    $input->set_name($p->{win});
    $input->set_history($p->{win});
    $input->change_server(server_find_tag($p->{tag}));

    my $width = $input->{width} - 8;
    my $theme = 'normal';

    for ( my $idx = $#{$p->{buf}}; $idx >= 0; $idx-- )
    {
      my $text = $p->{buf}->[$idx]->get_text(0);
      $text = sprintf
      (
         '%03d %'.( length($text) > $width ? '.'.($width-1).'s$' : '-'.$width.'s' ).
	 ' %03d', $idx+1, $text, $idx+1
      );
      $input->printformat(MSGLEVEL_NOHILIGHT, 'paste_'.$theme, $text);
      $theme = $theme eq 'normal' ? 'reverse' : 'normal';
    }

    $input->printformat(MSGLEVEL_NOHILIGHT, 'paste_input');
    $input->set_active();
};

sub buf_create ()
{
    return unless ( defined $p and ref $p );

    my $win = active_win();
    return 0 unless ( ref $win );  
    
    my $curline =  $win->view()->{buffer}->{cur_line};
    return 0 unless ( ref $curline );

    for ( my $idx = 0; $idx < 100; $idx++ )
    {
       last unless ( ref $curline );
       push @{$p->{buf}}, $curline;
       $curline = $curline->prev();
    }

    return ( $#{$p->{buf}} >= 0 ? 1 : 0 );
}

sub buf_flush ()
{
    return unless ( defined $p and ref $p );
    
    my $serv = server_find_tag($p->{tag});

    unless ( ref $serv and $serv->{connected} )
    {
       active_win()->printformat
       (
          MSGLEVEL_CRAP, 'paste_no_server', $p->{tag}
       );       

       return -1;
    }

    my $count = 0;
    foreach my $idx ( sort { $b <=> $a } ( keys %{$p->{l}} ) )
    {
       if ( defined $p->{l}->{$idx} and ref $p->{l}->{$idx} and ++$count )
       {
          if ( $p->{quiet} == 0 )
	  {       
	     my $cmd = sprintf
	     (
	        '%s %s %s', $p->{cmd}, $p->{target}, convertstr($p->{l}->{$idx}->get_text($p->{color}))
	     );
             $serv->command($cmd);
          }
	  else
	  {
             my $raw = sprintf
	     (
                '%s %s :%s', ( $p->{cmd} eq 'msg' ? 'privmsg' : 'notice' ), $p->{target},
		convertstr($p->{l}->{$idx}->get_text($p->{color}))
             );
	     $serv->send_raw($raw);
          }
	     
       }
    }

    if ( $count > 0 )
    {
       active_win()->printformat(MSGLEVEL_CRAP, 'paste_count', $count, $p->{tag}, $p->{target});
    }
    else
    {
       active_win()->printformat(MSGLEVEL_CRAP, 'paste_nothing');
    }

    return $count;
}

# sig_send_command (str data, rec server, rec window)
sub sig_send_command ($$$)
{
    unless ( defined $p and ref $p and defined $p->{win} )
    {
       return;
    }
    
    my $win = active_win();

    if ( $_[0] eq 0 )
    {
       buf_destroy(), return;
    }
    
    if ( substr($_[0], 0, 1) eq parse_special('$K') )
    {
       return;
    }

    unless ( ref $win and $win->{name} eq $p->{win} )
    {
       return;
    }

    signal_stop ();

    $win->destroy();
    delete $p->{win};

    foreach my $arg ( split /\s+/, $_[0] )
    {
       if ( $arg =~ m/^(\d+)$/ and $1 > 0 )
       {
          $p->{l}->{$1} = $p->{buf}->[$1-1];
       }
       elsif ( $arg =~ m/^([1-9]\d*)-(\d+)$/ and $1 <= $2 )
       {
          map { $p->{l}->{$_} = $p->{buf}->[$_-1] } ( $1 .. $2 );
       }
       else
       {
          active_win()->printformat(MSGLEVEL_CRAP, 'paste_argument_unknown', $arg, 'type /paste -help for help');
       }      
    }

    buf_flush();
    buf_destroy();
};

sub buf_destroy ()
{
   if ( defined $p and ref $p )
   {
       @{$p->{buf}} = () if ( defined $p->{buf} and ref $p->{buf} );
       %{$p->{l}} = () if ( defined $p->{l} and ref $p->{l} );
       if ( defined $p->{win} )
       {
          my $win = window_find_name($p->{win});
          $win->destroy if ( ref $win );
       }
       undef ( $p );
   }
}              

# convertstr (str text), str text
# thanks for Stanislaw Halik <weirdo@blindfold.no-ip.com>
sub convertstr ($)
{
   if ( $_[0] )
   {
      $_[0] =~ s/[\004]g\//\003\002\002/g;
      $_[0] =~ s/[\004]\?\/+/\0030\002\002/g;
      $_[0] =~ s/[\004]0\//\0031\002\002/g;
      $_[0] =~ s/[\004]0/\0031\002\002/g;
      $_[0] =~ s/[\004]1\//\0032\002\002/g;
      $_[0] =~ s/[\004]1/\0032\002\002/g;
      $_[0] =~ s/[\004]2\//\0033\002\002/g;
      $_[0] =~ s/[\004]2/\0033\002\002/g;
      $_[0] =~ s/[\004]<\//\0034\002\002/g;
      $_[0] =~ s/[\004]</\0034\002\002/g;
      $_[0] =~ s/[\004]4\//\0035\002\002/g;
      $_[0] =~ s/[\004]4/\0035\002\002/g;
      $_[0] =~ s/[\004]5\//\0036\002\002/g;
      $_[0] =~ s/[\004]5/\0036\002\002/g;
      $_[0] =~ s/[\004]6\//\0037\002\002/g;
      $_[0] =~ s/[\004]6/\0037\002\002/g;
      $_[0] =~ s/[\004]>\//\0038\002\002/g;
      $_[0] =~ s/[\004]>/\0038\002\002/g;
      $_[0] =~ s/[\004]:\//\0039\002\002/g;
      $_[0] =~ s/[\004]:/\0039\002\002/g;
      $_[0] =~ s/[\004]3\//\00310\002\002/g;
      $_[0] =~ s/[\004]3/\00310\002\002/g;
      $_[0] =~ s/[\004]\;\//\00311\002\002/g;
      $_[0] =~ s/[\004]\;/\00311\002\002/g;
      $_[0] =~ s/[\004]9\//\00312\002\002/g;
      $_[0] =~ s/[\004]9/\00312\002\002/g;
      $_[0] =~ s/[\004]=\//\00313\002\002/g;
      $_[0] =~ s/[\004]=/\00313\002\002/g;
      $_[0] =~ s/[\004]8\//\00314\002\002/g;
      $_[0] =~ s/[\004]8/\00314\002\002/g;
      $_[0] =~ s/[\004]7\//\00315\002\002/g;
      $_[0] =~ s/[\004]7/\00315\002\002/g;
      $_[0] =~ s/[\004]g\//\003\002\002/g;
      $_[0] =~ s/[\004]g/\003\002\002/g;
      $_[0] =~ s/[\004]8\//\003\002\002/g;
      $_[0] =~ s/[\004]8/\003\002\002/g;
   }
   return $_[0];
}

Irssi::theme_register
([
   'paste_normal', '$0-',
   'paste_reverse', '%c$0-%n',
   'paste_input', '%7%r type indexes of lines to paste (type "0" for cancel or "/paste -help" for help): %8%n',
   'paste_count', '%_Irssi%_: {hilight $0} line(s) have been pasted to {nick $2} in $1',
   'paste_argument_unknown', '%_Irssi%_: Unknown option: {hilight $0} {comment $1}',
   'paste_argument_missing', '%_Irssi%_: Not enough parameters given: $0 {comment $1}',
   'paste_no_server', '%_Irssi%_: Not connected to specified server {comment $0}',
   'paste_nothing', '%_Irssi%_: Nothing to paste',
]);

Irssi::signal_add_first('send command', 'sig_send_command');
Irssi::command_bind('paste', 'paste');
