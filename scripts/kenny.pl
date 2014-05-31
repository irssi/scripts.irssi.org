# (c) 2002 by Gerfried Fuchs <alfie@channel.debian.de>

use Irssi qw(command_bind command signal_add_last signal_stop settings_get_bool settings_add_bool);
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '2.3.1';

%IRSSI = (
  'authors'     => 'Gerfried Fuchs',
  'contact'     => 'alfie@channel.debian.de',
  'name'        => 'kenny speech',
  'description' => 'autodekennyfies /kenny, adds /kenny, /dekenny. Based on Jan-Pieter Cornets signature version',
  'license'     => 'BSD',
  'url'         => 'http://alfie.ist.org/projects/irssi/scripts/kenny.pl',
  'changed'     => '2002-06-13',
);

# Maintainer & original Author:  Gerfried Fuchs <alfie@channel.debian.de>
# Based on signature kenny from: Jan-Pieter Cornet <johnpc@xs4all.nl>
# Autodekenny-suggestion:        BC-bd <bd@bc-bd.org>

# Sugguestions from darix: Add <$nick> to [kenny] line patch

# This script offers you /kenny and /dekenny which both do the kenny-filter
# magic on the argument you give it.  Despite it's name *both* do kenny/dekenny
# the argument; the difference is that /kenny writes it to the channel/query
# but /dekenny only to your screen.

# Version-History:
# ================
# 2.3.1 -- fixed autodekenny in channels for people != yourself
#
# 2.3.0 -- fixed kenny in querys
#          fixed dekenny in status window
#
# 2.2.3 -- fixed pattern matching for autokenny string ("\w" != "a-z" :/)
#
# 2.2.2 -- first version available to track history from...

# TODO List
# ... currently empty


sub KennyIt {
   ($_)=@_;my($p,$f);$p=3-2*/[^\W\dmpf_]/i;s.[a-z]{$p}.vec($f=join('',$p-1?chr(
   sub{$_[0]*9+$_[1]*3+$_[2] }->(map {/p|f/i+/f/i}split//,$&)+97):('m','p','f')
   [map{((ord$&)%32-1)/$_%3}(9, 3,1)]),5,1)='`'lt$&;$f.eig;return ($_);
};


sub cmd_kenny {
   my ($msg, undef, $channel) = @_;
   $channel->command("msg $channel->{'name'} ".KennyIt($msg));
}


sub cmd_dekenny {
   my ($msg, undef, $channel) = @_;

   if ($channel) {
      $channel->print('[kenny] '.KennyIt($msg), MSGLEVEL_CRAP);
   } else {
      Irssi::print('[kenny] '.KennyIt($msg), MSGLEVEL_CRAP);
   }
}


sub sig_kenny {
   my ($server, $msg, $nick, $address, $target) = @_;
   if ($msg=~m/^[^a-z]*[mfp]{3}(?:[^a-z]|[mfp]{3})+$/i) {
      $target=$nick if $target eq "";

      # the address may _never_ be emtpy, if it is its own_public
      $nick=$server->{'nick'} if $address eq "";

      $server->window_item_find($target)->print("[kenny] <$nick> " .
                                                KennyIt($msg), MSGLEVEL_CRAP);
      signal_stop if not settings_get_bool('show_kenny_too');
   }
}


command_bind('kenny',   'cmd_kenny');
command_bind('dekenny', 'cmd_dekenny');

signal_add_last('message own_public',  'sig_kenny');
signal_add_last('message public',      'sig_kenny');
signal_add_last('message own_private', 'sig_kenny');
signal_add_last('message private',     'sig_kenny');

settings_add_bool('lookandfeel', 'show_kenny_too', 0);
