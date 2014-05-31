#! /usr/bin/perl
#
#    $Id: autochannel.pl,v 1.2 2007/09/20 06:58:11 peder Exp $
#
# Copyright (C) 2007 by Peder Stray <peder@ninja.no>
#

use strict;
use Irssi;
use Irssi::Irc;

use Data::Dumper;
$Data::Dumper::Indent = 1;

# ======[ Script Header ]===============================================

use vars qw{$VERSION %IRSSI};
($VERSION) = ' $Revision: 1.2 $ ' =~ / (\d+\.\d+) /;
%IRSSI = (
          name        => 'autochannel',
          authors     => 'Peder Stray',
          contact     => 'peder@ninja.no',
          url         => 'http://ninja.no/irssi/autochannel.pl',
          license     => 'GPL',
          description => 'Auto add channels to channel list on join',
         );

# ======[ Signal hooks ]================================================

# "message join", SERVER_REC, char *channel, char *nick, char *address
sub sig_message_join {
    my($server,$channel,$nick,$addr) = @_;

    return unless $nick eq $server->{nick};
    return unless $server->{chatnet};
    return unless Irssi::settings_get_bool('channel_add_on_join');
    
    Irssi::command(sprintf "channel add %s %s %s",
		   Irssi::settings_get_bool('channel_add_with_auto')
		   ? '-auto' : '',
		   $channel,
		   $server->{chatnet},
		  );
}

# "message part", SERVER_REC, char *channel, char *nick, char *address, char *reason
sub sig_message_part {
    my($server,$channel,$nick,$addr,$reason) = @_;

    return unless $nick eq $server->{nick};
    return unless $server->{chatnet};
    return unless
      Irssi::settings_get_bool('channel_remove_on_part') ||
	  Irssi::settings_get_bool('channel_remove_auto_on_part');

    if (Irssi::settings_get_bool('channel_remove_on_part')) {
	Irssi::command(sprintf "channel remove %s %s",
		       $channel,
		       $server->{chatnet},
		      );
    }
    elsif (Irssi::settings_get_bool('channel_remove_auto_on_part')) {
	Irssi::command(sprintf "channel add %s %s %s",
		       '-noauto',
		       $channel,
		       $server->{chatnet},
		      );
    }
}

# ======[ Setup ]=======================================================

# --------[ Settings ]--------------------------------------------------

Irssi::settings_add_bool('autochannel', 'channel_add_on_join', 1);
Irssi::settings_add_bool('autochannel', 'channel_add_with_auto', 1);
Irssi::settings_add_bool('autochannel', 'channel_remove_auto_on_part', 1);
Irssi::settings_add_bool('autochannel', 'channel_remove_on_part', 0);

# --------[ Signals ]---------------------------------------------------

Irssi::signal_add_last('message join', 'sig_message_join');
Irssi::signal_add_last('message part', 'sig_message_part');

# ======[ END ]=========================================================

# Local Variables:
# header-initial-hide: t
# mode: header-minor
# end:
