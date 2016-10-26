use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '1.00';
%IRSSI = (
    authors     => 'Erik Fears',
    contact     => 'strtok@softhome.net',
    name        => 'whos',
    description => 'This script allows ' .
                   'you to view all users ' .
                   'on a specific server.',
    license     => 'GPL',
);

Irssi::command_bind('whos', \&cmd_whos);
Irssi::signal_add('redir whos', \&sig_whos);
Irssi::signal_add('redir whosend', \&sig_whosend);

Irssi::theme_register([
   'whos' => '%#{channelhilight $[-10]0} %|{nick $[!9]1} $[!3]2 $[!2]3 $4@$5 {comment {hilight $6}}',
   'whos_end' => 'End of /WHOS list'
]);

#server name given in /whos if any
my $SERVER_NAME;

#WHOS <CHANNEL>
sub cmd_whos
{
   my @parv;
   my ($data, $server, $witem) = @_;
   my $chan;

   if( !($witem && $witem->{type} eq "CHANNEL") ) 
   {
      return;
   }

   $chan = $witem->{name};

   @parv = split(/\s+/,$data); 

   $server->redirect_event("who", 1, $chan, 0, undef, {
      "event 352" => "redir whos",
      "event 315" => "redir whosend",
      "" => "event empty"}
   );

  
   if(length($parv[0]) <= 0)
   {
      $SERVER_NAME = $server->{tag};
   }
   else
   {
      $SERVER_NAME = $parv[0];
   }

   $server->send_raw("WHO " . $chan);
}

#strtok #ribena strtok not.deprecated irc.choopa.net strtok H@ :0 (char *, const char *);


sub sig_whos
{
   my @who;
   my ($server, $msg, $nick, $address, $target) = @_;

   @who = split(/\s+/,$msg,9);

   if($who[4] =~ /$SERVER_NAME/)
   {
      Irssi::printformat(MSGLEVEL_CRAP, 'whos',$who[1], $who[5],$who[6], $who[7], $who[2], $who[3], $who[8]);
   }
}

sub sig_whosend
{
   my ($server, $msg, $nick, $address, $target) = @_;
   Irssi::printformat(MSGLEVEL_CRAP, 'whos_end');
}
