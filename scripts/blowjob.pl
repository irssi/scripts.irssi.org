#!/usr/bin/perl -w
use strict;

# BlowJob 0.9.1, a crypto script - ported from xchat
# was based on rodney mulraney's crypt
# changed crypting method to Blowfish+Base64+randomness+Z-compression
# needs :
#         Crypt::CBC,
#         Crypt::Blowfish,
#         MIME::Base64,
#         Compress::Zlib
#
# crypted format is :
# HEX(Base64((paranoia-factor)*(blowfish(RANDOM+Zcomp(string))+RANDOM)))
#
# 04-22-2015 Updated for compatibility with current Crypt::CBC
# 10-03-2004 Removed seecrypt, fixed two minor bugs
# 09-03-2004 Supporting multiline messages now.
# 08-03-2004 Lots of bugfixes on the irssi version by Thomas Reifferscheid
# 08-03-2004 CONF FILE FORMAT CHANGED
#
#            from server:channel:key:paranoia
#            to   server:channel:paranoia:key
#
#            /perm /bconf /setkey /showkey working now
#            keys may contain colons ":" now.
#
#
# 06-12-2001 Added default umask for blowjob.keys
# 05-12-2001 Added paranoia support for each key
# 05-12-2001 Added conf file support
# 05-12-2001 Added delkey and now can handle multi-server/channel keys
# 05-12-2001 permanent crypting to a channel added
# 05-12-2001 Can now handle multi-channel keys
# just /setkey <key> on the channel you are to associate a channel with a key
#
# --- conf file format ---
#
# # the generic key ( when /setkey has not been used )
# key:            generic key value
# # header that marks a crypted sentance
# header:         {header}
# # enable wildcards for multiserver entries ( useful for OPN for example )
# wildcardserver: yes
#
# --- end of conf file ---
#
# iMil <imil@gcu-squad.org>
# skid <skid@gcu-squad.org>
# Foxmask <odemah@gcu-squad.org>
# Thomas Reifferscheid <blowjob@reifferscheid.org>

use Crypt::CBC;
use Crypt::Blowfish;
use MIME::Base64;
use Compress::Zlib;

use Irssi::Irc;
use Irssi;
use vars qw($VERSION %IRSSI $cipher);

$VERSION = "0.9.0";
%IRSSI = (
    authors => 'iMil,Skid,Foxmask,reiffert',
    contact => 'imil@gcu-squad.org,blowjob@reifferscheid.org,#blowtest@freenode',
    name => 'blowjob',
    description => 'Crypt IRC communication with blowfish encryption. Supports public #channels, !channels, +channel, querys and dcc chat. Roadmap for Version 1.0.0 is to get some feedback and cleanup. Join #blowtest on freenode (irc.debian.org) to get latest stuff available. Note to users upgrading from versions prior to 0.8.5: The blowjob.keys format has changed.',
    license => 'GNU GPL',
    url => 'http://ftp.gcu-squad.org/misc/',
);


############# IRSSI README AREA #################################
#To install this script just do
#/script load ~/blowjob-irssi.pl
#  and
#/blowhelp
#  to read all the complete feature of the script :)
#To uninstall it do
#/script unload blowjob-irssi
################################################################


my $key = 'very poor key' ; # the default key
my $header = "{blow}";
# Crypt loops, 1 should be enough for everyone imho ;)
# please note with a value of 4, a single 4-letter word can generate
# a 4 line crypted sentance
my $paranoia = 1;
# add a server mask by default ?
my $enableWildcard="yes";

my $alnum = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

my $gkey;
sub loadconf
{
  my $fconf =Irssi::get_irssi_dir()."/blowjob.conf";
  my @conf;
  open (CONF, q{<}, $fconf);

  if (!( -f CONF)) {
    Irssi::print("\00305> $fconf not found, setting to defaults\n");
    Irssi::print("\00305> creating $fconf with default values\n\n");
    close(CONF);
    open(CONF, q{>}, $fconf);
    print CONF "key:			$key\n";
    print CONF "header:			$header\n";
    print CONF "wildcardserver:		$enableWildcard\n";
    close(CONF);
    return 1;
  }

  @conf=<CONF>;
  close(CONF);

  my $current;
  foreach(@conf) {
    $current = $_;
    $current =~ s/\n//g;
    if ($current =~ m/key/) {
      $current =~ s/.*\:[\ \t]*//;
      $key = $current;
      $gkey = $key;
    }
    if ($current =~ m/header/) {
      $current =~ s/.*\:[\s\t]*\{(.*)\}.*/{$1}/;
      $header = $current;
    }
    if ($current =~ m/wildcardserver/) {
      $current =~ s/.*\:[\ \t]*//;
      $enableWildcard = $current;
    }
  }
  Irssi::print("\00314- configuration file loaded\n");
  return 1;
}
loadconf;

my $kfile ="$ENV{HOME}/.irssi/blowjob.keys";
my @keys;
$gkey=$key;
my $gparanoia=$paranoia;

sub loadkeys
{
  if ( -e "$kfile" ) {
    open (KEYF, q{<}, $kfile);
    @keys = <KEYF>;
    close (KEYF);
  }
  Irssi::print("\00314- keys reloaded (Total:\00315 ".scalar @keys."\00314)\n");
  return 1;
}
loadkeys;

sub getkey
{
  my ($curserv, $curchan) = @_;

  my $gotkey=0;
  my $serv;
  my $chan;
  my $fkey;

  foreach(@keys) {
    chomp;                                            # keys can contain ":" now. Note:
    my ($serv,$chan,$fparanoia,$fkey)=split /:/,$_,4; # place of paranoia has changed!
    if ( $curserv =~ /$serv/ and $curchan eq $chan ) {
      $key= $fkey;
      $paranoia=$fparanoia;
      $gotkey=1;
    }
  }
  if (!$gotkey) {
    $key=$gkey;
    $paranoia=$gparanoia;
  }
  $cipher=new Crypt::CBC(-key=> $key, -cipher=> 'Blowfish', -header => 'randomiv');
}

sub setkey
{
  my (undef,$server, $channel) = @_;
  if (! $channel) { return 1; }
  my $curchan = $channel->{name};
  my $curserv = $server->{address};
  # my $key = $data;

  my $fparanoia;

  my $newchan=1;
  umask(0077);
  unless ($_[0] =~ /( +\d$)/) {
     $_[0].= " $gparanoia";
  }
  ($key, $fparanoia) = ($_[0] =~ /(.*) +(\d)/);

  if($enableWildcard =~ /[Yy][Ee][Ss]/) {
      $curserv =~ s/(.*?)\./(.*?)\./;
    Irssi::print("\00314IRC server wildcards enabled\n");
  }

  # Note, place of paranoia has changed!
  my $line="$curserv:$curchan:$fparanoia:$key";

  open (KEYF, q{>}, $kfile);
  foreach(@keys) {
    s/\n//g;
    if (/^$curserv\:$curchan\:/) {
      print KEYF "$line\n";
      $newchan=0;
    } else {
      print KEYF "$_\n";
    }
  }
  if ($newchan) {
    print KEYF "$line\n";
  }
  close (KEYF);
  loadkeys;
  Irssi::active_win()->print("\00314key set to \00315$key\00314 for channel \00315$curchan");
  return 1 ;
}

sub delkey
{
  my ($data, $server, $channel) = @_;
  my $curchan = $channel->{name};
  my $curserv = $server->{address};

  my $serv;
  my $chan;

  open (KEYF, q{>}, $kfile);
  foreach(@keys) {
    s/\n//g;
    ($serv,$chan)=/^(.*?)\:(.*?)\:/;
   unless ($curserv =~ /$serv/ and $curchan=~/^$chan$/) {
      print KEYF "$_\n";
    }
  }
  close (KEYF);
  Irssi::active_win()->print("\00314key for channel \00315$curchan\00314 deleted");
  loadkeys;
  return 1 ;
}

sub showkey {
  my (undef, $server, $channel) = @_;
  if (! $channel) { return 1; }
  my $curchan = $channel->{name};
  my $curserv = $server->{address};

  getkey($curserv,$curchan);

  Irssi::active_win()->print("\00314current key is : \00315$key");
  return 1 ;
}

sub enc
{
  my ($curserv,$curchan, $in) = @_;
  my $prng1="";
  my $prng2="";

  # copy & paste from former sub blow()

  for (my $i=0;$i<4;$i++) {
    $prng1.=substr($alnum,int(rand(61)),1);
    $prng2.=substr($alnum,int(rand(61)),1);
  }


  getkey($curserv,$curchan);

  $cipher->start('encrypting');

  my $tbout = compress($in);
  my $i;
  for ($i=0;$i<$paranoia;$i++) {
    $tbout = $prng1.$tbout;
    $tbout = $cipher->encrypt($tbout);
    $tbout .= $prng2;
  }

  $tbout = encode_base64($tbout);
  $tbout = unpack("H*",$tbout);
  $tbout = $header." ".$tbout;
  $tbout =~ s/=+$//;	

  $cipher->finish();

  return (length($tbout),$tbout);

}

sub irclen
{
  my ($len,$curchan,$nick,$userhost) = @_;

  # calculate length of "PRIVMSG #blowtest :{blow} 4b7257724a ..." does not exceed
  # it may not exceed 511 bytes
  # result gets handled by caller.

  return ($len + length($curchan) + length("PRIVMSG : ") + length($userhost) + 1 + length($nick) );
}
sub recurs
{
  my ($server,$curchan,$in) = @_;

  # 1. devide input line by 2.                    <--|
  #    into two halfes, called $first and $second.   |
  # 2. try to decrease $first to a delimiting " "    |
  #    but only try on the last 8 bytes              ^
  # 3. encrypt $first                                |
  #    if result too long, call sub recurs($first)----
  # 4. encrypt $second                               ^
  #    if result too long, call sub recurs($second)--|
  # 5. pass back encrypted halfes as reference
  #    to an array.


  my $half = length($in)/2-1;
  my $first = substr($in,0,$half);
  my $second = substr($in,$half,$half+3);
  if ( (my $pos = rindex($first," ",length($first)-8) ) != -1)
  {
	$second = substr($first,$pos+1,length($first)-$pos) . $second;
        $first = substr($first,0,$pos);
  }

  my @a;

  my ($len,$probablyout);

  ($len,$probablyout) = enc($server->{address},$curchan,$first);

  if ( irclen($len,$curchan,$server->{nick},$server->{userhost}) > 510)
  {
    my @b=recurs($server,$curchan,$first);
    push(@a,@{$b[0]});
  } else {
    push(@a,$probablyout);
  }

  ($len,$probablyout) = enc($server->{address},$curchan,$second);
  if ( irclen($len,$curchan,$server->{nick},$server->{userhost}) > 510)
  {
    my @b = recurs($server,$curchan,$second);
    push(@a,@{$b[0]});
  } else {
    push(@a,$probablyout);
  }
  return \@a;

}


sub printout
{
   my ($aref,$server,$curchan) = @_;

   # encrypted lines get stored [ '{blow} yxcvasfd', '{blow} qewrdf', ... ];
   # in an arrayref

   foreach(@{$aref})
   {
     	$server->command("/^msg -$server->{tag} $curchan ".$_);
   }
}

sub enhanced_printing
{
  my ($server,$curchan,$in) = @_;

  # calls the recursing sub recurs ... and 
  my $arref = recurs($server,$curchan,$in);
  # print out.
  printout($arref,$server,$curchan);

}

sub blow
{
  my ($data, $server, $channel) = @_;
  if (! $channel) { return 1;}
  my $in = $data ;
  my $nick = $server->{nick};
  my $curchan = $channel->{name};
  my $curserv = $server->{address};

  my ($len,$encrypted_message) = enc($curserv,$curchan,$in);

  $server->print($channel->{name}, "<$nick|{crypted}> \00311$in",MSGLEVEL_CLIENTCRAP);

  $len = length($encrypted_message); # kept for debugging

  if ( irclen($len,$curchan,$server->{nick},$server->{userhost}) > 510)
  {
    # if complete message too long .. see sub irclen
    enhanced_printing($server,$curchan,$data);
  } else {
    # everything is fine, just print out
    $server->command("/^msg -$server->{tag} $curchan $encrypted_message");
  }

  return 1 ;
}

sub infoline
{
  my ($server, $data, $nick, $address) = @_;

  my ($channel,$text,$msgline,$msgnick,$curchan,$curserv);

  if ( ! defined($address) ) # dcc chat
  {
    $msgline = $data;
    $curserv = $server->{server}->{address};
    $channel = $curchan = "=".$nick;
    $msgnick = $nick;
    $server  = $server->{server};
  } else 
  {
    ($channel, $text) = $data =~ /^(\S*)\s:(.*)/;
    $msgline = $text;
    $msgnick = $server->{nick};
    $curchan = $channel;
    $curserv = $server->{address};
  }

  if ($msgline =~ m/^$header/) {
    my $out = $msgline;
    $out =~ s/\0030[0-9]//g;
    $out =~ s/^$header\s*(.*)/$1/;

    if ($msgnick eq $channel)
    {
       $curchan = $channel = $nick;
    }

    getkey($curserv,$curchan);

    $cipher->start('decrypting');
    $out = pack("H*",$out);
    $out = decode_base64($out);

    my $i;
    for ($i=0;$i<$paranoia;$i++) {
      $out = substr($out,0,(length($out)-4));
      $out = $cipher->decrypt($out);
      $out = substr($out,4);
    }
    $out = uncompress($out);

    $cipher->finish;

    if(length($out))
    {
       $server->print($channel, "<$nick|{uncrypted}> \00311$out", MSGLEVEL_CLIENTCRAP);
       Irssi::signal_stop();
    }
    return 1;

  }
  return 0 ;
}

sub dccinfoline
{
  my ($server, $data) = @_;
  infoline($server,$data,$server->{nick},undef);
}
my %permchans={};
sub perm
{
   my ($data, $server, $channel) = @_;
   if (! $channel) { return 1; }
   my $curchan = $channel->{name};
   my $curserv = $server->{address};
  
   if ( exists($permchans{$curserv}{$curchan}) && $permchans{$curserv}{$curchan} == 1) {
    delete $permchans{$curserv}{$curchan};
    Irssi::active_win()->print("\00314not crypting to \00315$curchan\00314 on \00315$curserv\00314 anymore");
  } else {
    $permchans{$curserv}{$curchan} = 1;
    Irssi::active_win()->print("\00314crypting to \00315$curchan on \00315$curserv");
  }
  return 1;
}
sub myline
{
  my ($data, $server, $channel) = @_;
  if (! $channel) { return 1; }
  my $curchan = $channel->{name};
  my $curserv = $server->{address};
  my $line = shift;
  chomp($line);
  if (length($line) == 0)
  {
    return;
  }
  my $gotchan = 0;
  foreach(@keys) {
    s/\n//g;
    my ($serv,$chan,undef,undef)=split /:/;
    if ( ($curserv =~ /$serv/ && $curchan =~ /^$chan$/ && exists($permchans{$curserv}{$curchan}) && $permchans{$curserv}{$curchan} == 1) || (exists($permchans{$curserv}{$curchan}) && $permchans{$curserv}{$curchan} == 1))
    {
      $gotchan = 1;
    }
  }
  if ($gotchan)
  {

    blow($line,$server,$channel);
    Irssi::signal_stop();
    return 1;
  }
}

sub reloadconf
{
  loadconf;
  loadkeys;
}
sub help
{
  Irssi::print("\00314[\00303bl\003090\00303wjob\00314]\00315 script :\n");
  Irssi::print("\00315/setkey <newkey> [<paranoia>] :\00314 new key for current channel\n") ;
  Irssi::print("\00315/delkey                       :\00314 delete key for current channel");
  Irssi::print("\00315/showkey                      :\00314 show your current key\n") ;
  Irssi::print("\00315/blow   <line>                :\00314 send crypted line\n") ;
  Irssi::print("\00315/perm                         :\00314 flag current channel as permanently crypted\n") ;
  Irssi::print("\00315/bconf                        :\00314 reload blowjob.conf\n") ;

  return 1 ;
}

Irssi::print("blowjob script $VERSION") ;
Irssi::print("\n\00314[\00303bl\003090\00303wjob\00314] v$VERSION\00315 script loaded\n\n");
Irssi::print("\00314- type \00315/blowhelp\00314 for options\n") ;
Irssi::print("\00314- paranoia level is      : \00315$paranoia\n") ;
Irssi::print("\00314- generic key is         : \00315$key\n") ;
Irssi::print("\n\00314* please read script itself for documentation\n");
Irssi::signal_add("event privmsg","infoline") ;
Irssi::signal_add("dcc chat message","dccinfoline");
Irssi::command_bind("blowhelp","help") ;
Irssi::command_bind("setkey","setkey") ;
Irssi::command_bind("delkey","delkey");
Irssi::command_bind("blow","blow") ;
Irssi::command_bind("showkey","showkey") ;
Irssi::command_bind("perm","perm") ;
Irssi::command_bind("bconf","reloadconf") ;
Irssi::signal_add("send text","myline") ;
