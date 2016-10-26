# $Id: modelist-r.pl,v 0.8.0-rc4 2004/11/04 19:56 derwan Exp $
#
# This script creates cache of channel invites, ban exceptions and reops.
# Reop list is included only in ircd >= 2.11.0 (in IRCnet) - for other servers
# and networks use modelist.pl ( http://derwan.irssi.pl/modelist.pl).
#
# Script commands:
#   /si   - shows channel invites
#   /se   - shows ban exception
#   /sr   - shows reop list
#   
#   /uninvite [<index and masks separated with spaces>]
#         - removes the specified invite(s) from the channel
#   /unexcept [<index and masks separated with spaces>]
#         - removes the specified ban exception(s) from the channel
#   /unreop [<index and masks separated with spaces>]
#         - removes the specified reop(s) from the channel
#
#   Examples:
#      /si
#      /uninvite 1
#      /unexcept *!*@127.0.0.1
#      /unreop 1 *!*@127.0.0.1 5
#
# After loading modelist-r.pl run command
#   /statusbar window add -priority 0 -after usercount modelist 
#
# You can customize the look of this item from theme file:
#   sb_modelist = "{sb $0 modes ($1-)}";
#   sb_ml_b = "b/%r$*%n"; # bans
#   sb_ml_e = "e/%c$*%n"; # ban exceptions
#   sb_ml_I = "I/%G$*%n"; # invites
#   sb_ml_R = "R/%R$*%n"; # reops
#   sb_ml_space = " ";    # separator
#
# Theme formats:
#   modelist                   $0 - index, $1 - channel, $2 - hostmask, 3 - mode 
#   modelist_long              $4 - nick, $5 - time
#   modelist_empty             $0 - channel, $1 - mode
#   modelist_chan_not_synced   $0 - channel
#   modelist_not_joined
#   modelist_server_version    $0 - version
#   

use strict;
use vars ('$VERSION', '%IRSSI');

use Irssi 20020600 ();
use Irssi::Irc;
use Irssi::TextUI;

$VERSION = '0.8.0-rc4';
%IRSSI =
(
   'authors'      => 'Marcin Rozycki',
   'contact'      => 'derwan@irssi.pl',
   'name'         => 'modelist-r',
   'description'  => 'Cache of invites, ban exceptions and reops in channel. Script commands: '.
                     '/si, /se, /sr, /unexcept, /uninvite, /unreop (version only for ircd >= 2.11.0).',
   'license'      => 'GNU GPL v2',
   'modules'      => '',
   'url'          => 'http://derwan.irssi.pl',
   'changed'      => 'Thu Nov  4 17:56:17 2004',
);

Irssi::theme_register
([
   # $0 - index, $1 - channel name, $2 - hostmask, $3 - mode (invite, ban exception, reop)
   'modelist', '$0 - {channel $1}: $3 {ban $2}',
   # $0 - index, $1 - channel name, $2 - hostmask, $3 - mode, $4 - nick, $5 - time
   'modelist_long', '$0 - {channel $1}: $3 {ban $2} {comment by {nick $4}, $5 secs ago}',
   # $0 - channel name, $1 - mode
   'modelist_empty', 'No $1s in channel {channel $0}',
   # $0 - channel name
   'modelist_chan_not_synced', 'Channel not fully synchronized yet, try again after a while',
   # $0 - channel name
   'modelist_chan_no_modes', 'Channel {channel $0} doesn\'t support modes',
   'modelist_not_joined', 'Not joined to any channel',
   # $0 - version
   'modelist_server_version', 'This script working only in ircd {hilight >= 2.11.0} with reop list {comment active ircd $0}' 
]);

# $modelist{str servertag}->{lc str channel}->{str mode} = [ $moderec, ... ]
# $moderec = [ str hostmask, str nick, str time ]
my %modelist = ();

# $synced{str servertag}->{lc str channel} = int synced
my %synced = ();

#  $visible{str mode} = str list
my %visible =
(
   'e' => 'ban exception',
   'I' => 'invite',
   'R' => 'reop'
);

# $sb->{str mode} = int modes
my $sb = {};

# server redirections:
#   'modelist I' ( 346, 347, 403, 442, 472, 479, 482)
#   'modelist e' ( 348, 349, 403, 442, 472, 479, 482)
#   'modelist R' ( 344, 345, 403, 442, 472, 479, 482)
Irssi::Irc::Server::redirect_register('modelist I', 0, 0, { 'event 346' => 1 }, {
   'event 347' => 1, # end of channel invite list
   'event 403' => 1, # no such channel
   'event 442' => 1, # you're not on that channel
   'event 472' => 1, # unknown mode
   'event 479' => 1, # illegal channel name
   'event 482' => 1  # you're not channel operator
}, undef );

Irssi::Irc::Server::redirect_register('modelist e', 0, 0, { 'event 348' => 1 }, {
   'event 349' => 1, # end of channel exception list
   'event 403' => 1,
   'event 442' => 1,
   'event 472' => 1,
   'event 479' => 1,
   'event 482' => 1
}, undef );

Irssi::Irc::Server::redirect_register('modelist R', 0, 0, { 'event 344' => 1 }, {
   'event 345' => 1, # end of channel reop list
   'event 403' => 1,
   'event 442' => 1,
   'event 472' => 1,
   'event 479' => 1,
   'event 482' => 1
}, undef );

# create_channel (rec channel, int sync)
sub create_channel ($;$)
{
    destroy_channel($_[0]);
    sb_update();

    my ($server, $tag, $channel) = ($_[0]->{server}, $_[0]->{server}->{tag}, lc $_[0]->{name});
    
    
    if ( !test_version($server) or $_[0]->{no_modes} )
    {
       $synced{$tag}->{$channel} = 1;
       return;
    }
    $synced{$tag}->{$channel} = ( defined $_[1] ) ? $_[1] : 0;
        
    $modelist{$tag}->{$channel}->{I} = [];
    $server->redirect_event('modelist I', 1, $channel, 0, undef, {
       'event 346' => 'redir modelist invite',
                '' => 'event empty'
    });
    $server->send_raw(sprintf('mode %s +I', $channel));

    $modelist{$tag}->{$channel}->{e} = [];
    $server->redirect_event('modelist e', 1, $channel, 0, undef, {
       'event 348' => 'redir modelist except',
                '' => 'event empty'
    });
    $server->send_raw(sprintf('mode %s +e', $channel));

    $modelist{$tag}->{$channel}->{R} = [];
    $server->redirect_event('modelist R', 1, $channel, 0, undef, {
       'event 344' => 'redir modelist reop',
       'event 345' => 'redir modelist sync',
       'event 403' => 'redir modelist sync',
       'event 442' => 'redir modelist sync',
       'event 472' => 'redir modelist sync',
       'event 479' => 'redir modelist sync',
       'event 482' => 'redir modelist sync',
       '' => 'event empty'
    });
    $server->send_raw(sprintf('mode %s +R', $channel));
}

# destroy_channel (rec channel)
sub destroy_channel ($)
{
   my ($tag, $channel) = ($_[0]->{server}->{tag}, lc $_[0]->{name});
   delete $synced{$tag}->{$channel};
   delete $modelist{$tag}->{$channel};
   sb_update();
}

# sig_redir_modelist (rec server, str data, str mode)
sub sig_redir_modelist ($$$)
{
   my $chanrec = $_[0]->channel_find(((split(' ', $_[1], 3))[1]));
   if ( ref $chanrec )
   {
      mode($chanrec, 1, $_[2], ((split(/ +/, $_[1], 4))[2]), undef);
   }
}

# mode (rec channel, int type, str mode, str hostmask, str setby) 
sub mode ($$$$$)
{
    my $rec = get_list($_[0], $_[2]);
    if ( ref $rec and $_[1] eq 1 )
    {    
       push @{$rec}, [ $_[3], $_[4], time ];
    }
    elsif ( ref $rec and $_[1] eq 0 )
    {
       for ( my $idx = 0; $idx <= $#{$rec}; $idx++ )
       {
         if ( lc $rec->[$idx]->[0] eq lc $_[3] )
         {
            splice @{$rec}, $idx, 1;
            last;
         }
       }
    }
    sb_update();
}

# sig_channel_sync (rec channel)
sub sig_channel_sync ($)
{
   if ( ++$synced{$_[0]->{server}->{tag}}->{lc $_[0]->{name}} < 2 )
   {
      Irssi::signal_stop();
   }
}

# sig_modelist_sync (rec server, str data)
sub sig_modelist_sync ($$)
{
   my $chanrec = $_[0]->channel_find(((split(/ +/, $_[1], 3))[1]));
   if ( ref $chanrec )
   {
      Irssi::signal_emit('channel sync', $chanrec);
      sb_update();
   }
}

# sig_message_irc_mode (rec server, str channel, str nick, str userhost, str mode)
sub sig_message_irc_mode ($$$$$)
{
   my $chanrec = $_[0]->channel_find($_[1]);
   unless ( ref $chanrec )
   {
      return;
   }
   
   my ($q, $mods, @a) = (1, split(/ +/, $_[4]));
   foreach my $mod ( split('', $mods) )
   {
       ( $mod eq '+' ) and $q = 1, next;
       ( $mod eq '-' ) and $q = 0, next;
       my $a = ( rindex('beIkloRvhx', $mod) >= 0 && $q eq 1 or rindex('beIkoRvhx', $mod) >= 0 && $q eq 0 ) ? shift(@a) : undef;
       if ( rindex('eIR', $mod) >= 0 )
       {
          mode($chanrec, $q, $mod, $a, $_[2]);
       }
   }
}

# get_list (rec channel, str mode), rec list
sub get_list ($$)
{
   if ( ref $_[0] and defined $modelist{$_[0]->{server}->{tag}}->{lc $_[0]->{name}}->{$_[1]} )
   {
       return $modelist{$_[0]->{server}->{tag}}->{lc $_[0]->{name}}->{$_[1]};
   }
}

# test_version (rec server), bool 0/1
sub test_version ($)
{
   if ( $_[0] and ref $_[0] and $_[0]->{version} =~ m/^(\d+\.\d+)\./ and $1 >= 2.11 )
   {
      return 1;
   }
   return 0;
}


# test_channel (rec channel, bool quiet), bool 0/1
sub test_channel ($;$)
{
   unless ( ref $_[0] and $_[0]->{type} eq 'CHANNEL' )
   {
       Irssi::printformat(MSGLEVEL_CRAP, 'modelist_not_joined') unless ( $_[1] );
       return 0;
   }
   if ( $_[0]->{no_modes} )
   {
       $_[0]->printformat(MSGLEVEL_CRAP, 'modelist_chan_no_modes', $_[0]->{name}) unless ( $_[1] );
       return 0;
   }
   if ( !test_version($_[0]->{server}) )
   {
      $_[0]->printformat(MSGLEVEL_CRAP, 'modelist_server_version', $_[0]->{server}->{version}) unless ( $_[1] );
      return 0;
   
   }
   if ( $synced{$_[0]->{server}->{tag}}->{lc $_[0]->{name}} < 2 )
   {
      $_[0]->printformat(MSGLEVEL_CRAP, 'modelist_chan_not_synced', $_[0]->{name}) unless ( $_[1] );
      return 0;
   }   
   return 1;
}

# cmd_modelist_show (str mode)
sub cmd_modelist_show ($)
{
   my $chanrec = Irssi::active_win() ? Irssi::active_win()->{active} : undef;
   unless ( test_channel($chanrec) )
   {
      return;
   }
   my $rec = get_list($chanrec, $_[0]);
   unless ( $#{$rec} >= 0 )
   {
       $chanrec->printformat
       (
           MSGLEVEL_CRAP, 'modelist_empty', $chanrec->{name}, $visible{$_[0]}
       );
       return;
   }        
   for ( my $idx = 0; $idx <= $#{$rec}; $idx++ )
   {
      $chanrec->printformat
      (
          MSGLEVEL_CRAP, ( defined $rec->[$idx]->[1] ? 'modelist_long' : 'modelist'), 
          ($idx + 1), $chanrec->{name}, visible($rec->[$idx]->[0]), $visible{$_[0]},
          $rec->[$idx]->[1], (time() - $rec->[$idx]->[2])
       );
   }
}

# cmd_modelist_del (str mode, str data)
sub cmd_modelist_del ($$)
{
   my $chanrec = Irssi::active_win() ? Irssi::active_win()->{active} : undef;
   unless ( test_channel($chanrec) )
   {
      return;
   }
   my ($rec, @m) = (get_list($chanrec, $_[0]));
   foreach my $search ( split /[,;\s]+/, $_[1] )
   {
      if ( $search =~ m/^\d+$/ ) 
      {
          next unless ( $search-- and $search <= $#{$rec} );
          $search = $rec->[$search]->[0];
      }
      push @m, $search;
   }
   if ( $#m >= 0 )
   {
       $chanrec->{server}->command(sprintf("mode %s -%s %s", $chanrec->{name}, $_[0] x scalar(@m), join(' ', @m)));
   }
}

# visible (str data), str data
sub visible ($)
{
   my $str = shift();
   $str =~ tr/\240\002\003\037\026/\206\202\203\237\226/;
   return $str;
}

# sb_update ()
sub sb_update ()
{
   $sb->{b} = $sb->{e} = $sb->{I} = $sb->{R} = $sb->{T} = 0;
   
   my $chanrec = Irssi::active_win() ? Irssi::active_win()->{active} : undef;
   unless ( test_channel($chanrec, 1) )
   {
      return;
   }

   $sb->{b} = scalar @{[$chanrec->bans]};
   $sb->{e} = scalar @{get_list($chanrec, 'e')};
   $sb->{I} = scalar @{get_list($chanrec, 'I')};
   $sb->{R} = scalar @{get_list($chanrec, 'R')};
   $sb->{T} = $sb->{b} + $sb->{e} + $sb->{I} + $sb->{R};

   Irssi::statusbar_items_redraw('modelist');
}

# sb_modelist(rec item, bool get_size_only)
# tahnks usercount.pl!
sub sb_modelist ($$)
{
   unless ( $sb->{T} )
   {
      $_[0]->{min_size} = $_[0]->{max_size} = 0 if ( ref $_[0] );
      return;
   }

   my $theme = Irssi::current_theme();
   my $format = $theme->format_expand('{sb_modelist}');

   if ( $format  )
   {
      my ($str, $space) = ('', $theme->format_expand('{sb_ml_space}'));
      foreach my $mod ( 'b', 'e', 'I', 'R' )
      {
         next unless ( $sb->{$mod} > 0 );
         my $tmp = $theme->format_expand
         (
             sprintf('{sb_ml_%s %d}', $mod, $sb->{$mod}), Irssi::EXPAND_FLAG_IGNORE_EMPTY
         );
         $str .= $tmp . $space;
      }
      $str =~ s/\Q$space\E$//;
      $format = $theme->format_expand
      (
         sprintf('{sb_modelist %d %s}', $sb->{T}, $str), Irssi::EXPAND_FLAG_IGNORE_REPLACES
      );
   }
   else
   {
       my $str = undef;
       foreach my $mod ( 'b', 'e', 'I', 'R' )
       {
          next unless ( $sb->{$mod} > 0 );
          $str .= sprintf('%s%d ', $mod, $sb->{$mod})
       }
       chop($str);
       $format = sprintf('{sb \%%_%d\%%_ modes ', $sb->{T});
       $format .= sprintf('\%%c(\%%n%s\%%c)', $str) if ( $str );
   }  

   $_[0]->default_handler($_[1], $format, undef, 1);
}

Irssi::signal_add_first('channel sync', 'sig_channel_sync');
Irssi::signal_add('channel joined' => sub { create_channel($_[0], 0) });
Irssi::signal_add('channel destroyed' => sub { destroy_channel($_[0]) });
Irssi::signal_add('redir modelist invite' => sub { sig_redir_modelist($_[0], $_[1], 'I'); });
Irssi::signal_add('redir modelist except' => sub { sig_redir_modelist($_[0], $_[1], 'e'); });
Irssi::signal_add('redir modelist reop' => sub { sig_redir_modelist($_[0], $_[1], 'R'); });
Irssi::signal_add('redir modelist sync', 'sig_modelist_sync');
Irssi::signal_add('message irc mode', 'sig_message_irc_mode');
Irssi::signal_add_last('ban new', 'sb_update');
Irssi::signal_add_last('ban remove', 'sb_update');
Irssi::signal_add_last('window changed', 'sb_update');
Irssi::signal_add_last('window item changed', 'sb_update');
Irssi::command_bind('si' => sub { cmd_modelist_show('I') });
Irssi::command_bind('se' => sub { cmd_modelist_show('e') });
Irssi::command_bind('sr' => sub { cmd_modelist_show('R') });
Irssi::command_bind('uninvite' => sub { cmd_modelist_del('I', $_[0]) });
Irssi::command_bind('unexcept' => sub { cmd_modelist_del('e', $_[0]) });
Irssi::command_bind('unreop' => sub { cmd_modelist_del('R', $_[0]) });

sb_update();

Irssi::statusbar_item_register('modelist', undef, 'sb_modelist');
Irssi::statusbars_recreate_items();

foreach my $server ( Irssi::servers )
{
   foreach my $chanrec ( $server->channels )
   {
      create_channel($chanrec, 1);  
   }
}




