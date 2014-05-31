use Irssi;
use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "1.0";
%IRSSI = (
      authors     => "David Leadbeater",
      contact     => "dgl\@dgl.cx",
      url         => "http://irssi.dgl.cx/",
      license     => "GNU GPLv2 or later", 
      name        => "foreach user",
      description => "Extends the /foreach command to have /foreach user 
        (users in a channel).
        Syntax: /foreach user [hostmask] command.",
);

# Examples:
# /foreach user /whois $0
# /foreach user *!eviluser@* /k $0 evil!  (consider kicks.pl ;) )

Irssi::command_bind('foreach user', sub {
   my($command) = @_;
   return unless length $command;

   my $mask = '*!*@*';
   # see if it begins with a mask (kind of assumes cmdchars is /).
   if($command !~ m!^/! && $command =~ /^\S+[!@]/) { 
      ($mask,$command) = split / /, $command, 2;
      # make sure the mask is okay.
      $mask .= '@*' if $mask !~ /\@/;
      $mask = "*!$mask" if $mask !~ /!/;
   }

   my $channel = ref Irssi::active_win ? Irssi::active_win->{active} : '';
   return unless ref $channel;

   for my $nick($channel->nicks) {
      next unless ref $nick;
      next unless $channel->{server}->mask_match_address($mask, $nick->{nick},
         $nick->{host} ? $nick->{host} : '');
      
      # the backtracking is only so $$0 is escaped (don't ask me why...)
      (my $tmpcommand = $command) =~ s/(?<!\$)\$(\d)/
         if($1 == 0) {
            $nick->{nick}
         }elsif($1 == 1) {
            $nick->{host}
         }elsif($1 == 2) {
            (split('@',$nick->{host}))[0];
         }elsif($1 == 3) {
            (split('@',$nick->{host}))[1];
         }elsif($1 == 4) {
            $nick->{realname}
         }
      /eg;
      $tmpcommand =~ s/\$\$(\d)/\$$1/g;
      $channel->command($tmpcommand);
   }
} );

