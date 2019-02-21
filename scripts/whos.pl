use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '1.01';
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
Irssi::command_bind('whoss', \&cmd_whoss);
Irssi::signal_add('redir whos', \&sig_whos);
Irssi::signal_add('redir whosend', \&sig_whosend);

Irssi::theme_register([
   'whos' => '%#{channelhilight $[-10]0} %|{nick $[!9]1} $[!3]2 $[!2]3 $4@$5 {comment {hilight $6}}',
   'whos_end' => 'End of /WHOS list',
   'whos_hil' => '{hilight $0} $1'
]);

#results
my %res;

#WHOS <CHANNEL>
sub cmd_whos
{
   my @parv;
   my ($data, $server, $witem) = @_;
   my $chan;
   if (exists $res{$server->{tag}}) {
      $res{$server->{tag}}=();
   }
   $res{$server->{tag}}->{result}=();
   $res{$server->{tag}}->{server}=();
   $res{$server->{tag}}->{regex}='';

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
      $res{$server->{tag}}->{regex}='';
   }
   else
   {
      $res{$server->{tag}}->{regex}=$parv[0];
   }

   $server->send_raw("WHO " . $chan);
}

#strtok #ribena strtok not.deprecated irc.choopa.net strtok H@ :0 (char *, const char *);


sub sig_whos
{
   my @who;
   my ($server, $msg, $nick, $address, $target) = @_;

   @who = split(/\s+/,$msg,9);

   $res{$server->{tag}}->{result}->{$who[5]}=[@who];
}

sub sig_whosend
{
   my ($server, $msg, $nick, $address, $target) = @_;
   if ($res{$server->{tag}}->{regex} eq '') {
      $res{$server->{tag}}->{regex}= $nick;
   }
   Irssi::printformat(MSGLEVEL_CRAP,'whos_hil','regex:',$res{$server->{tag}}->{regex});
   foreach (sort keys %{$res{$server->{tag}}->{result}}) {
      my @r=@{$res{$server->{tag}}->{result}->{$_}};
      if ($r[4] =~ m/$res{$server->{tag}}->{regex}/ ) {
         Irssi::printformat(MSGLEVEL_CRAP,'whos',@r[1,5,6,7,2,3,8]);
      }
      $res{$server->{tag}}->{server}->{$r[4]}=1;
   }
   Irssi::printformat(MSGLEVEL_CRAP, 'whos_end');
}

sub cmd_whoss {
   my ($args, $server, $witem) = @_;
   Irssi::printformat(MSGLEVEL_CRAP,'whos_hil','servers:');
   foreach (sort keys %{$res{$server->{tag}}->{server}}) {
      Irssi::print($_,MSGLEVEL_CRAP);
   }
}

# vim:set ts=3 sw=3 expandtab:
