#
# Copyright (C) 2007-2021 by Peder Stray <peder.stray@gmail.com>
#

use strict;
use Irssi;
use Irssi::Irc;

use vars qw{$VERSION %IRSSI};
($VERSION) = ' $Revision: 1.3.1 $ ' =~ / (\d+(\.\d+)+) /;
%IRSSI = (
	  name        => 'autochannel',
	  authors     => 'Peder Stray',
	  contact     => 'peder.stray@gmail.com',
	  url         => 'https://github.com/pstray/irssi-autochannel',
	  license     => 'GPL',
	  description => 'Auto add channels to channel list on join',
	 );

# "channel joined", channel
sub sig_channel_joined {
    my($c) = @_;

    my $server  = $c->{server};
    my $channel = $c->{name};

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

Irssi::settings_add_bool('autochannel', 'channel_add_on_join', 1);
Irssi::settings_add_bool('autochannel', 'channel_add_with_auto', 1);
Irssi::settings_add_bool('autochannel', 'channel_remove_auto_on_part', 1);
Irssi::settings_add_bool('autochannel', 'channel_remove_on_part', 0);

Irssi::signal_add_last('channel joined', 'sig_channel_joined');
Irssi::signal_add_last('message part', 'sig_message_part');
