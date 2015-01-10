use strict;
use vars qw($VERSION %IRSSI);
use Irssi;
use Irssi::Irc;
use DBI;

$VERSION = '1.02';
%IRSSI = (
   authors      => 'John Engelbrecht',
   contact      => 'jengelbr@yahoo.com',
   name         => 'twsocials.pl',
   description  => 'IRC version of Social Commands',
   license      => 'Public Domain',
   changed      => 'Sat Nov 20 18:25:12 CST 2004',
   url          => 'http://irssi.darktalker.net/',
);

my $instrut =
  ".------------------------------------------------------.\n".
  "| 1.) shell> mkdir ~/.irssi/scripts                    |\n".
  "| 2.) shell> cp twsocials.pl ~/.irssi/scripts/         |\n".
  "| 3.) shell> mkdir ~/.irssi/scripts/autorun            |\n".
  "| 4.) shell> ln -s ~/.irssi/scripts/twsocials.pl \\     |\n".
  "|            ~/.irssi/scripts/autorun/twsocials.pl     |\n".
  "| 5.) /help            (Will list all your socials)    |\n".
  "|     /socials         (Shows you a list of arguments) |\n".
  "|     /socials list    (Shows a list of socials)       |\n".
  "|     /socials <social>(Contents of the Social command)|\n".
  "| 6.) /toggle twsocials_instruct and last /save        |\n".
  "|------------------------------------------------------|\n".
  "|  Options:                                   Default: |\n".
  "|  /toggle twsocials_remote                     OFF    |\n".
  "|  /toggle twtopic_instruct     |Startup instructions  |\n".
  "|------------------------------------------------------|\n".
  "|  Note:                                               |\n".
  "|  If twsocials_remote is ON, that will enable public  |\n".
  "|  and private social commands to work, such as the    |\n".
  "|  the following.                                      |\n".
  "|                                                      |\n".
  "|  < TechWizard> !social                               |\n".
  "|  < TechWizard> !social list                          |\n".
  "|  < TechWizard> !social blist                         |\n".
  "|  < TechWizard> !hug                                  |\n".
  "|  < TechWizard> !hug JohnDoe                          |\n".
  "|  < TechWizard> !hug JohnDoe 1                        |\n".
  "\`------------------------------------------------------'";


my $maxsize=62;
my $lastcmd="";
my $home_chan="";
my $path = "~/.irssi/socials";
my @colname = ("Dark Black","Dark Red","Dark Green","Dark Yellow","Dark Blue","Dark Magenta","Dark Cyan","Dark White","Bold Black","Bold Red","Bold Green","Bold Yellow","Bold Blue","Bold Magenta","Bold Cyan","Bold White","Reset","O");
my @mirc_color_name = ("~R0","~R1","~R2","~R3","~R4","~R5","~R6","~R7","~B0","~B1","~B2","~B3","~B4","~B5","~B6","~B7","~RS");
my @mirc_color_arr = ("\0031","\0035","\0033","\0037","\0032","\0036","\00310","\0030","\00314","\0034","\0039","\0038","\00312","\00313","\00311","\00315","\017");
my ($r0,$r1,$r2,$r3,$r4,$r5,$r6,$r7,$b0,$b1,$b2,$b3,$b4,$b5,$b6,$b7,$rs) = @mirc_color_arr;
   $path =~ s/^~\//$ENV{'HOME'}\//;
my $bc=$r4;
my $bt=$r2;
my $m1=$r1;
my $m2=$b1;

################ Checking Social's home Directory #############
init_socpath();   
###############################################################

sub message_public {
  my($server, $data, $nick, $address, $target) = @_;
  if(!Irssi::settings_get_bool('twsocials_remote')) { return; }
  $home_chan=$target;
  $data =~ s/\r//;
  my $socname;
  my @data_arr = split " ", $data;
  if(@data_arr[0] eq "!social") {
     if(!$#data_arr) {
        syntax($server,$target);
        return; 
        }
     if(@data_arr[1] eq "color") {
        colorlist($server,$target);
        return; 
        }     
     if(@data_arr[1] eq "list") {
        soclist($server,$target);
        return; 
        }     
     if(@data_arr[1] eq "blist") {
        socblist($server,$target);
        return; 
        }     
     if(@data_arr[1] eq "add") {
        if($#data_arr == 1) {
           $server->command("msg $target $r3(USAGE) $rs!social$b4 add$rs <social>$r3 :$rs$r2 Adds a new Social.");
           return; 
           } 
        $socname = @data_arr[2];
        addsoc($server,$target,$socname);
        return; 
        }     
     if(@data_arr[1] eq "del") {
        if($#data_arr == 1) {
           $server->command("msg $target $r3(USAGE) $rs!social$b4 dels$rs <social> $r3:$r2 Deletes a Social.");
           return; 
           }        
        $socname = @data_arr[2];
        delsoc($server,$target,$socname);
        return; 
        }     
     if(@data_arr[1] eq "set") {
        if($#data_arr <= 3) {
           set_syntax($server, $target, $socname);
           return; 
           }
        $socname = @data_arr[2];
        my $set = @data_arr[3];
        my $cutstr = "@data_arr[0] @data_arr[1] @data_arr[2] @data_arr[3] ";
        $data =~ s/$cutstr//;
        setsoc($server,$target,$socname,$set,$data);
        return; 
        }     
     $socname = @data_arr[1];
     print_social($server, $target, $socname);
     return;
     }
  if(@data_arr[0] eq "!soclist") {
     soclist($server,$target);
     return; 
     }
  my $chr="!";
  $socname = @data_arr[0];
  my @socname_arr = split //, $socname;
  if(@socname_arr[0] ne $chr) { return; }
  $socname =~ s/$chr//;
  my ($nick2,$msgsw);
  if(!ifexist_social($socname)) { return; }
  if($#data_arr == 0) {
     $nick2 = "UNSET";
     $msgsw=0;
     }
  if($#data_arr == 1) {
     $nick2 = @data_arr[1];
     $msgsw=0;
     }
  if($#data_arr == 2) {
     $nick2 = @data_arr[1];
     $msgsw=1;
     }  
  my $chan = Irssi::Irc::Server->channel_find($home_chan);
  my $nick_obj = $chan->nick_find($nick2);
  if($nick_obj->{nick} eq "" && $nick2 ne "UNSET") { 
     $server->command("msg $target nickname does not exist.");
     return;
     }
  do_social($server,$target,$socname,$nick,$nick2,$msgsw);
}

sub message_private {
  my($server, $data, $nick, $address) = @_;
  if(!Irssi::settings_get_bool('twsocials_remote')) { return; }
  my $target=$nick;
  $home_chan=$target;
  $data =~ s/\r//;
  my $socname;
  my @data_arr = split " ", $data;
  if(@data_arr[0] eq "!social") {
     if(!$#data_arr) {
        syntax($server,$target);
        return; 
        }
     if(@data_arr[1] eq "color") {
        colorlist($server,$target);
        return; 
        }     
     if(@data_arr[1] eq "list") {
        soclist($server,$target);
        return; 
        }     
     if(@data_arr[1] eq "blist") {
        socblist($server,$target);
        return; 
        }     
     if(@data_arr[1] eq "add") {
        if($#data_arr == 1) {
           $server->command("msg $target $r3(USAGE) $rs!social$b4 add$rs <social>$r3 :$rs$r2 Adds a new Social.");
           return; 
           } 
        $socname = @data_arr[2];
        addsoc($server,$target,$socname);
        return; 
        }     
     if(@data_arr[1] eq "del") {
        if($#data_arr == 1) {
           $server->command("msg $target $r3(USAGE) $rs!social$b4 dels$rs <social> $r3:$r2 Deletes a Social.");
           return; 
           }        
        $socname = @data_arr[2];
        delsoc($server,$target,$socname);
        return; 
        }     
     if(@data_arr[1] eq "set") {
        if($#data_arr <= 3) {
           set_syntax($server, $target, $socname);
           return; 
           }
        $socname = @data_arr[2];
        my $set = @data_arr[3];
        my $cutstr = "@data_arr[0] @data_arr[1] @data_arr[2] @data_arr[3] ";
        $data =~ s/$cutstr//;
        setsoc($server,$target,$socname,$set,$data);
        return; 
        }     
     $socname = @data_arr[1];
     print_social($server, $target, $socname);
     return;
     }
  if(@data_arr[0] eq "!soclist") {
     soclist($server,$target);
     return; 
     }
  my $chr="!";
  $socname = @data_arr[0];
  my @socname_arr = split //, $socname;
  if(@socname_arr[0] ne $chr) { return; }
  $socname =~ s/$chr//;
  my ($nick2,$msgsw);
  if(!ifexist_social($socname)) { return; }
  if($#data_arr == 0) {
     $nick2 = "UNSET";
     $msgsw=0;
     }
  if($#data_arr == 1) {
     $nick2 = @data_arr[1];
     $msgsw=0;
     }
  if($#data_arr == 2) {
     $nick2 = @data_arr[1];
     $msgsw=1;
     }  
  my $nick1 = $nick;
  do_social($server,$target,$socname,$nick1,$nick2,$msgsw);
}

sub on_public {
  my($server, $data, $nick, $address, $target) = @_;
  if(!Irssi::settings_get_bool('twsocials_remote')) { return; }
  if($data !~ /^!/) { return; } 
  $home_chan=$nick;
  $target=Irssi::active_win()->{active}->{name};
  $home_chan=$target;
  $data =~ s/\r//;
  my $socname;
  my @data_arr = split " ", $data;
  if(@data_arr[0] eq "!social") {
     if(!$#data_arr) {
        syntax($server,$target);
        return; 
        }
     if(@data_arr[1] eq "color") {
        colorlist($server,$target);
        return; 
        }     
     if(@data_arr[1] eq "list") {
        soclist($server,$target);
        return; 
        }     
     if(@data_arr[1] eq "blist") {
        socblist($server,$target);
        return; 
        }     
     if(@data_arr[1] eq "add") {
        if($#data_arr == 1) {
           $server->command("msg $target $r3(USAGE) $rs!social$b4 add$rs <social>$r3 :$rs$r2 Adds a new Social.");
           return; 
           }
        $socname = @data_arr[2];
        addsoc($server,$target,$socname);
        return; 
        }     
     if(@data_arr[1] eq "del") {
        if($#data_arr == 1) {
           $server->command("msg $target $r3(USAGE) $rs!social$b4 dels$rs <social> $r3:$r2 Deletes a Social.");
           return; 
           }
        $socname = @data_arr[2];
        delsoc($server,$target,$socname);
        return; 
        }     
     if(@data_arr[1] eq "set") {
        if($#data_arr <= 3) {
           set_syntax($server, $target, $socname);
           return;
           }
        $socname = @data_arr[2];
        my $set = @data_arr[3];
        my $cutstr = "@data_arr[0] @data_arr[1] @data_arr[2] @data_arr[3] ";
        $data =~ s/$cutstr//;
        setsoc($server,$target,$socname,$set,$data);
        return; 
        }     
     $socname = @data_arr[1];
     print_social($server, $target, $socname);
     return;
     }
  if(@data_arr[0] eq "!soclist") {
     soclist($server,$target);
     return; 
     }
  my $chr="!";  
  $socname = @data_arr[0];
  my @socname_arr = split //, $socname;
  if(@socname_arr[0] ne $chr) { return; }
  $socname =~ s/$chr//;
  my ($nick2,$msgsw);
  if(!ifexist_social($socname)) {
     return;
     }
  if($#data_arr == 0) {
     $nick2 = "UNSET";
     $msgsw=0;
     }
  if($#data_arr == 1) {
     $nick2 = @data_arr[1];
     $msgsw=0;
     }
  if($#data_arr == 2) {
     $nick2 = @data_arr[1];
     $msgsw=1;
     }  
  my $nick1 = $server->{nick};
  my $chan = Irssi::Irc::Server->channel_find($home_chan);
  my $nick_obj = $chan->nick_find($nick2);
  if($nick_obj->{nick} eq "" && $nick2 ne "UNSET") { 
     $server->command("msg $target nickname does not exist.");
     return;
     }
  do_social($server,$target,$socname,$nick1,$nick2,$msgsw);
}

sub on_private {
  my($server, $data, $nick, $address, $target) = @_;
  if(!Irssi::settings_get_bool('twsocials_remote')) { return; }
  if($data !~ /^!/) { return; } 
  $home_chan=$nick;
  $target=$nick;
  $data =~ s/\r//;
  my $socname;
  my @data_arr = split " ", $data;
  if(@data_arr[0] eq "!social") {
     if(!$#data_arr) {
        syntax($server,$target);
        return; 
        }
     if(@data_arr[1] eq "color") {
        colorlist($server,$target);
        return; 
        }     
     if(@data_arr[1] eq "list") {
        soclist($server,$target);
        return; 
        }     
     if(@data_arr[1] eq "blist") {
        socblist($server,$target);
        return; 
        }     
     if(@data_arr[1] eq "add") {
        if($#data_arr == 1) {
           $server->command("msg $target $r3(USAGE) $rs!social$b4 add$rs <social>$r3 :$rs$r2 Adds a new Social.");
           return; 
           }
        $socname = @data_arr[2];
        addsoc($server,$target,$socname);
        return; 
        }     
     if(@data_arr[1] eq "del") {
        if($#data_arr == 1) {
           $server->command("msg $target $r3(USAGE) $rs!social$b4 dels$rs <social> $r3:$r2 Deletes a Social.");
           return; 
           }
        $socname = @data_arr[2];
        delsoc($server,$target,$socname);
        return; 
        }     
     if(@data_arr[1] eq "set") {
        if($#data_arr <= 3) {
           set_syntax($server, $target, $socname);
           return;
           }
        $socname = @data_arr[2];
        my $set = @data_arr[3];
        my $cutstr = "@data_arr[0] @data_arr[1] @data_arr[2] @data_arr[3] ";
        $data =~ s/$cutstr//;
        setsoc($server,$target,$socname,$set,$data);
        return; 
        }     
     $socname = @data_arr[1];
     print_social($server, $target, $socname);
     return;
     }
  if(@data_arr[0] eq "!soclist") {
     soclist($server,$target);
     return; 
     }
  my $chr="!";  
  $socname = @data_arr[0];
  my @socname_arr = split //, $socname;
  if(@socname_arr[0] ne $chr) { return; }
  $socname =~ s/$chr//;
  my ($msgsw,$nick2);
  if(!ifexist_social($socname)) {
     return;
     }
  if($#data_arr == 0) {
     $nick2 = "UNSET";
     $msgsw=0;
     }
  if($#data_arr == 1) {
     $nick2 = @data_arr[1];
     $msgsw=0;
     }
  if($#data_arr == 2) {
     $nick2 = @data_arr[1];
     $msgsw=1;
     }  
  my $nick1 = $server->{nick};
  $target = $nick;
  do_social($server,$target,$socname,$nick1,$nick2,$msgsw);
}

sub addsoc {
   my ($server,$target,$socname) = @_;
   if(ifexist_social($socname)) {
      $server->command("msg $target r3social: $rs$socname already exist.");
      return;
      }
   #write_social($socname,$fpriv,$fself,$fnobody,$fpublic,$fyou,$fthem) 
   write_social($socname,"0","UNSET","UNSET","UNSET","UNSET","UNSET");
   irssicmd_socials($socname);
   $server->command("msg $target $r2 done.");   
   return;
}

sub irssi_addsoc {
   my ($data, $server, $witem) = @_;
   my @data_arr = split / /, $data;
   if(@data_arr[0] eq "") { 
      irssi_syntax();
      return;
      }
   my $socname = @data_arr[0];
   if(ifexist_social($socname)) {
      print "$rs$socname already exist.";
      return;
      }
   write_social($socname,"0","UNSET","UNSET","UNSET","UNSET","UNSET");
   irssicmd_socials($socname);
   print "$r2 done.";
   return;
}

sub delsoc {
   my ($server,$target,$socname) = @_;
   if(!ifexist_social($socname)) {
      $server->command("msg $target $r3 DELETE $socname: $rs$socname social does not exist.");
      return;
      }
   my $filename ="$path/$socname.txt";
   unlink($filename);
   irssicmd_socials($socname);
   $server->command("msg $target $r2 done.");   
   return;
}

sub irssi_delsoc {
   my ($data, $server, $witem) = @_;
   my @data_arr = split / /, $data;
   if(@data_arr[0] eq "") { 
      irssi_syntax();
      return;
      }
   my $socname = @data_arr[0];
   if(!ifexist_social($socname)) {
      print "$r3 DELETE $socname: $rs$socname social does not exist.";
      return;
      }
   my $filename ="$path/$socname.txt";
   unlink($filename);
   irssicmd_socials($socname);
   print "$r2 done.";
   return;
}

sub setsoc {
   my ($server,$target,$socname,$set,$data) = @_;
   my @sets = ("priv","nobody","public","self","them","you");
   if(!ifexist_social($socname)) {
      $server->command("msg $target $r3 SET social: $rs$socname does not exist.");
      return;
      }
   $set = "\L$set";
   my $found=0;
   foreach(@sets) { if($set eq $_) { $found=1; } }
   if(!$found) {
      $server->command("msg $target $r3 social:$rs invalid field name.");
      return;
      }  
   my $filename = "$path/$socname.txt";
   my $cx=0;
   my ($fpriv, $fnobody, $fpublic, $fself, $fthem, $fyou);
   open(FILE,"<", $filename) or do {
      print "File $filename not found.";
      return;
      };
   while (<FILE>) {
      chomp;
      $fpriv = $_ if($cx == 0);
      $fnobody = $_ if($cx == 1);
      $fpublic = $_ if($cx == 2);
      $fself = $_ if($cx == 3);
      $fthem = $_ if($cx == 4);
      $fyou = $_ if($cx == 5);
      $cx++;
      }
   close FILE;
   $fpriv   = $data if($set eq "priv");
   $fnobody = $data if($set eq "nobody");
   $fpublic = $data if($set eq "public");
   $fself   = $data if($set eq "self");
   $fthem   = $data if($set eq "them");
   $fyou    = $data if($set eq "you");
   write_social($socname,$fpriv,$fself,$fnobody,$fpublic,$fyou,$fthem);
   $server->command("msg $target $r2 done.");   
   irssicmd_socials($socname);
   return;   
}

sub irssi_setsoc {
   my ($data, $server, $witem) = @_;
   my @data_arr = split / /, $data;
   if($#data_arr <=1) { 
      irssi_set_syntax();
      return;
      }
   my $cutstr = "/";
   my $socname = @data_arr[0];
   my $set = @data_arr[1];
   $cutstr = "$socname $set ";
   $data =~ s/$cutstr//g;
   my @sets = ("priv","nobody","public","self","them","you");
   if(!ifexist_social($socname)) {
      print "$r3 SET social: $rs$socname does not exist.";
      return;
      }
   $set = "\L$set";
   my $found=0;
   foreach(@sets) { if($set eq $_) { $found=1; } }
   if(!$found) {
      print "$r3 social:$rs invalid field name.";
      return;
      }  
   my $filename = "$path/$socname.txt";
   my $cx=0;
   my ($fpriv, $fnobody, $fpublic, $fself, $fthem, $fyou);
   open(FILE,"<", $filename) or do {
      print "File $filename not found.";
      return;
      };
   while (<FILE>) {
      chomp;
      $fpriv = $_ if($cx == 0);
      $fnobody = $_ if($cx == 1);
      $fpublic = $_ if($cx == 2);
      $fself = $_ if($cx == 3);
      $fthem = $_ if($cx == 4);
      $fyou = $_ if($cx == 5);
      $cx++;
      }
   close FILE;
   $fpriv   = $data if($set eq "priv");
   $fnobody = $data if($set eq "nobody");
   $fpublic = $data if($set eq "public");
   $fself   = $data if($set eq "self");
   $fthem   = $data if($set eq "them");
   $fyou    = $data if($set eq "you");
   write_social($socname,$fpriv,$fself,$fnobody,$fpublic,$fyou,$fthem);
   print "$r2 done.";
   irssicmd_socials($socname);
   return;   
}

sub syntax {
   my ($server,$target) = @_;
   $server->command("msg $target $r3(USAGE) $rs!social             $r3 :$r2 Prints this screen.");
   $server->command("msg $target         !social <social>   $r3  :$r2 Displays the social msgs");
   $server->command("msg $target         !social$b4 add $rs<social>$r3 :$r2 Adds a new Social.");
   $server->command("msg $target         !social$b4 del $rs<social>$r3 :$r2 Dels a Social.");
   $server->command("msg $target         !social$b4 set $rs<social>$r3 :$r2 Sets The social msg per line.");
   $server->command("msg $target         !social$b4 list    $r3     :$r2 A list of socials.");
   $server->command("msg $target         !social$b4 blist   $r3     :$r2 A list of socials in a box.");
   $server->command("msg $target         !social$b4 color   $r3     :$r2 A list of color codes.");
   $server->command("msg $target         !soclist           $r3  :$r2 Prints a list of socials.");
   $server->command("msg $target         !<social>          $r3  :$r2 does the Social.");
}

sub irssi_syntax {
   my ($server,$target) = @_;
   print "$r3(USAGE) $rs!social             $r3 :$r2 Prints this screen.";
   print "        !social <social>   $r3  :$r2 Displays the social msgs";
   print "        !social$b4 add $rs<social>$r3 :$r2 Adds a new Social.";
   print "        !social$b4 del $rs<social>$r3 :$r2 Dels a Social.";
   print "        !social$b4 set $rs<social>$r3 :$r2 Sets The social msg per line.";
   print "        !social$b4 list    $r3     :$r2 A list of socials.";
   print "        !social$b4 blist   $r3     :$r2 A list of socials in a box.";
   print "        !social$b4 color   $r3     :$r2 A list of color codes.";
   print "        !soclist           $r3  :$r2 Prints a list of socials.";
   print "        !<social>          $r3  :$r2 does the Social.";
}

sub colorlist {
   my ($server,$target) = @_;
   my $title = "$bc($bt Color List $bc)";
   my $spc = ' 'x50;
   my $text = "";
   my $tmp = "";
   my $cx=0;
   my $bar = "------------------------------------------------------------------";
   $bar = ".".substr($bar,0,int(($maxsize-13)/2)).$title.substr($bar,0,int(($maxsize-13)/2)).".";
   $server->command("msg $target $bc$bar$rs");

   my ($text,$blah);
   foreach (@colname)  {
   my $col = substr("@mirc_color_name[$cx] = @colname[$cx]$spc",0,20);
      $tmp = $text.$col;
      if(strsize($tmp) >= $maxsize) {
         $text.=' 'x50;
         $blah =~ s/\003//;
         $blah = @mirc_color_arr[$cx];
         $text = substr(" $text",0,$maxsize);
         $text = "$bc|$rs$text$bc|$rs";
         $server->command("msg $target $text");
         $text="";
         }
      $text=$text.$col;
      $cx++;
      }
   $bar = "-------------------------------------------------------------------------------------------";
   $bar = "`".substr($bar,0,$maxsize)."\'";
   $server->command("msg $target $bc$bar$rs");
   return;
}

sub irssi_colorlist {
   my ($server,$target) = @_;
   my $spc = ' 'x50;
   my $title = "$bc($bt Color List $bc)";
   my $bar = "------------------------------------------------------------------";
   $bar = ".".substr($bar,0,int(($maxsize-13)/2)).$title.substr($bar,0,int(($maxsize-13)/2)).".";
   print "$bc$bar$rs";
   my $cx=0;
   my ($text,$blah);
   foreach (@colname)  {
   my $col = substr("@mirc_color_name[$cx] = @colname[$cx]$spc",0,20);
      my $tmp = $text.$col;
      if(strsize($tmp) >= $maxsize) {
         $text.=' 'x50;
         $blah =~ s/\003//;
         $blah = @mirc_color_arr[$cx];
         $text = substr(" $text",0,$maxsize);
         $text = "$bc|$rs$text$bc|$rs";
         print $text;
         $text="";
         }
      $text=$text.$col;
      $cx++;
      }
   $bar = "-------------------------------------------------------------------------------------------";
   $bar = "`".substr($bar,0,$maxsize)."\'";
   print "$bc$bar$rs";
   return;
}

sub set_syntax {
   my ($server,$target) = @_;
   $server->command("msg $target $r3(USAGE) $rs!social$b4 set$rs <social>$b4 nobody $rs<msg>: Sets the message when no nickname is set.");
   $server->command("msg $target        !social$b4 set $rs<social>$b4 public $rs<msg> : Sets the message for the channel");
   $server->command("msg $target        !social$b4 set $rs<social>$b4 self   $rs<msg> : Sets the message when you social yourself.");
   $server->command("msg $target        !social$b4 set $rs<social>$b4 you    $rs<msg> : Sets message that will be messaged to you.");
   $server->command("msg $target        !social$b4 set $rs<social>$b4 them   $rs<msg> : Sets The social message that will be sent to them.");
   return;
}

sub irssi_set_syntax {
   my ($server,$target) = @_;
   print "$r3(USAGE)";
   print "!social$b4 set$rs <social>$b4 nobody $rs<msg>: Sets the message when no nickname is set.";
   print "!social$b4 set $rs<social>$b4 public $rs<msg>: Sets the message for the channel";
   print "!social$b4 set $rs<social>$b4 self   $rs<msg>: Sets the message when you social yourself.";
   print "!social$b4 set $rs<social>$b4 you    $rs<msg>: Sets message that will be messaged to you.";
   print "!social$b4 set $rs<social>$b4 them   $rs<msg>: Sets The social message that will be sent to them.";
   return;
}

sub soclist{
   my ($server,$target) = @_;
   my $text="";
   my $cutstr=".txt";
   my @array;
   opendir(DIR,$path) or return 0;
   while (defined(my $file = readdir(DIR))) {
      if($file =~ m".txt") { 
         my $tmp=$file;
         $tmp =~ s/$cutstr//;
         push(@array,$tmp); 
         }
      }
   closedir(DIR);
   @array = sort(@array);
   foreach(@array) { $text.=" $_"; }
   $server->command("msg $target $text");
   return;
}

sub socblist {
   my ($server,$target) = @_;
   my @array;
   my $text="";
   opendir(DIR,$path) or return 0;
   my $title = "$bc($bt Social List $bc)";
   my $bar = "------------------------------------------------------------------";
   $bar = ".".substr($bar,0,int(($maxsize-15)/2)).$title.substr($bar,0,int(($maxsize-15)/2)+1).".";
   $server->command("msg $target $bc$bar$rs");
   my $spc = "                                ";
   my $cutstr=".txt";
   opendir(DIR,$path) or return 0;
   while (defined(my $file = readdir(DIR))) {
      if($file =~ m".txt") { 
         my $tmp=$file;
         $tmp =~ s/$cutstr//;
         push(@array,$tmp); 
         }
      }
   closedir(DIR);
   @array = sort(@array);
   foreach(@array) {
     my $name;
     my $socname=$_;
     $socname =~ s/$cutstr//;
     if(!get_social_str($socname,"priv")) { 
        $name = substr(" $socname$spc",0,10); 
        }
     else { 
        $name = substr("*$socname$spc",0,10); 
        }
     my $tmp = $text.$name;
     if(strsize($tmp) >= $maxsize) {
         $text.="                                                                           ";
         $text = substr(" $text",0,($maxsize));
         $text = "$bc|$rs$text$bc|$rs";
         $server->command("msg $target $text");
         $text="";
         }
      $text=$text.$name;
      }
   $text.="                                                                           ";
   $text = substr(" $text",0,($maxsize));
   $text = "$bc|$rs$text$bc|$rs";
   $server->command("msg $target $text");
   $bar = "-------------------------------------------------------------------------------------------";
   $bar = "`".substr($bar,0,$maxsize)."\'";
   $server->command("msg $target $bc$bar$rs");
   return;
}

sub irssi_socblist {
   my ($data, $server, $witem) = @_;
   my @array;
   my $text="";
   opendir(DIR,$path) or return 0;
   my $title = "$bc($bt Social List $bc)";
   my $bar = "------------------------------------------------------------------";
   $bar = ".".substr($bar,0,int(($maxsize-15)/2)).$title.substr($bar,0,int(($maxsize-15)/2)+1).".";
   print "$bc$bar$rs";
   my $spc = "                                ";
   my $cutstr=".txt";
   opendir(DIR,$path) or return 0;
   while (defined(my $file = readdir(DIR))) {
      if($file =~ m".txt") { 
         my $tmp=$file;
         $tmp =~ s/$cutstr//;
         push(@array,$tmp); 
         }
      }
   closedir(DIR);
   @array = sort(@array);
   foreach(@array) {
     my $name;
     my $socname=$_;
     $socname =~ s/$cutstr//;
     if(!get_social_str($socname,"priv")) { 
        $name = substr(" $socname$spc",0,10); 
        }
     else { 
        $name = substr("*$socname$spc",0,10); 
        }
     my $tmp = $text.$name;
     if(strsize($tmp) >= $maxsize) {
         $text.="                                                                           ";
         $text = substr(" $text",0,($maxsize));
         $text = "$bc|$rs$text$bc|$rs";
         print "$text";
         $text="";
         }
      $text=$text.$name;
      }
   $text.="                                                                           ";
   $text = substr(" $text",0,($maxsize));
   $text = "$bc|$rs$text$bc|$rs";
   print "$text";
   $bar = "-------------------------------------------------------------------------------------------";
   $bar = "`".substr($bar,0,$maxsize)."\'";
   print "$bc$bar$rs";
   return;
}

sub do_social {
   my ($server,$target,$socname,$name1,$name2,$msgsw) = @_;
   my $text;
   if($name1 eq $name2) {
      $text = get_social_str($socname,"self");
      $text= social_parse($name1,$name2,$text);
      $server->command("msg $target $text");
      return;
      }
   if($name2 eq "UNSET") {
      $text = get_social_str($socname,"nobody");
      $text= social_parse($name1,$name2,$text);
      $server->command("msg $target $text");
      return;
      }
   if(get_social_str("priv")) {
      $text = get_social_str($socname,"public");
      $text= social_parse($name1,$name2,$text);
      $server->command("msg $target $text");
      if($msgsw) {
         $text = get_social_str($socname,"you");
         $text= social_parse($name1,$name2,$text);
         $server->command("msg $name1 $text");
         $text = get_social_str($socname,"them");
         $text= social_parse($name1,$name2,$text);
         $server->command("msg $name2 $text");
         }
      }
   else {
      $text = get_social_str($socname,"you");
      $text= social_parse($name1,$name2,$text);
      $server->command("msg $name1 $text");
      $text = get_social_str($socname,"them");
      $text= social_parse($name1,$name2,$text);
      $server->command("msg $name2 $text");
      }
   return;
}

sub print_social {
   my ($server,$target,$socname) = @_;
   my $text="";
   my $filename = "$path/$socname.txt";
   my $cx=0;
   my ($fpriv, $fnobody, $fpublic, $fself, $fthem, $fyou);
   open(FILE,"<", $filename) or do {
      $server->command("msg $target $socname does not exist.");   
      return;
      };
   while (<FILE>) {
      chomp;
      $fpriv = $_ if($cx == 0);
      $fnobody = $_ if($cx == 1);
      $fpublic = $_ if($cx == 2);
      $fself = $_ if($cx == 3);
      $fthem = $_ if($cx == 4);
      $fyou = $_ if($cx == 5);
      $cx++;
      }
   close FILE;
   $server->command("msg $target $r3    Name:$r2 $socname");
   $server->command("msg $target $r3 Private:$r2 $fpriv");
   $server->command("msg $target $r3  Nobody:$r2 ".colsocial($fnobody));
   $server->command("msg $target $r3  Public:$r2 ".colsocial($fpublic));
   $server->command("msg $target $r3    Self:$r2 ".colsocial($fself));
   $server->command("msg $target $r3    Them:$r2 ".colsocial($fthem));
   $server->command("msg $target $r3     You:$r2 ".colsocial($fyou));
   return;
}

sub irssi_print_social {
   my ($data, $server, $item) = @_;
   my @data_arr = split / /, $data;
   my $cutstr = "/";
   if (@data_arr[0] =~ m/^[(set)|(blist)|(add)|(list)|(del)|(color)]/i && !ifexist_social(@data_arr[0])) {
    Irssi::command_runsub ('social', $data, $server, $item);
    return;
    }
   my $socname = @data_arr[0];
   my $text="";
   my $filename = "$path/$socname.txt";
   my $cx=0;
   my ($fpriv, $fnobody, $fpublic, $fself, $fthem, $fyou);
   open(FILE,"<", $filename) or do {
      print "$socname does not exist."; 
      return;
      };
   while (<FILE>) {
      chomp;
      $fpriv = $_ if($cx == 0);
      $fnobody = $_ if($cx == 1);
      $fpublic = $_ if($cx == 2);
      $fself = $_ if($cx == 3);
      $fthem = $_ if($cx == 4);
      $fyou = $_ if($cx == 5);
      $cx++;
      }
   close FILE;
   print"$r3    Name:$r2 $socname";
   print"$r3 Private:$r2 $fpriv";
   print"$r3  Nobody:$r2 ".colsocial($fnobody);
   print"$r3  Public:$r2 ".colsocial($fpublic);
   print"$r3    Self:$r2 ".colsocial($fself);
   print"$r3    Them:$r2 ".colsocial($fthem);
   print"$r3     You:$r2 ".colsocial($fyou);
   return;
}

sub colsocial {
    my ($str) = @_;
    my $name1 = "$r2 name1$rs";
    my $name2 = "$r2 name2$rs";
    return $str;
}

sub color_parse {
    my ($str) = @_;
    my $cx=0;
    foreach(@mirc_color_name) { 
       my $old = @mirc_color_name[$cx];
       my $new = @mirc_color_arr[$cx];
       $str =~ s/$old/$new/g;
       $cx++;
       }
    return $str;
}

sub social_parse {
   my ($name1,$name2,$str) = @_;
   $name1 = "$r2$name1$rs";
   $name2 = "$r2$name2$rs";
   $str =~ s/name1/$name1/g;
   $str =~ s/name2/$name2/g;
   return $str;
}

sub get_social_str {
   my ($social,$colum) = @_;
   my $filename = "$path/$social.txt";
   my $cx=0;
   my ($fpriv, $fnobody, $fpublic, $fself, $fthem, $fyou);
   open(FILE,"<", $filename);
   while (<FILE>) {
      chomp;
      $fpriv = color_parse($_) if($cx == 0);
      $fnobody = color_parse($_) if($cx == 1);
      $fpublic = color_parse($_) if($cx == 2);
      $fself = color_parse($_) if($cx == 3);
      $fthem = color_parse($_) if($cx == 4);
      $fyou = color_parse($_) if($cx == 5);
      $cx++;
   }
   close FILE;
   return $fpriv if($colum eq "priv");
   return $fself if($colum eq "self");
   return $fnobody if($colum eq "nobody");
   return $fpublic if($colum eq "public");
   return $fyou if($colum eq "you");
   return $fthem if($colum eq "them");
   return "UNSET";
}

sub ifexist_social {
   my ($socname) = @_;
   my $cutstr= ".txt";
   my $filename = "$path/$socname.txt";
   opendir(DIR,$path) or return 0;
   while (defined(my $file = readdir(DIR))) {
      if($file =~ m".txt") { 
         my $tmp=$file;
         $tmp =~ s/$cutstr//;
         return 1 if($socname eq $tmp);
         }
      }
   return 0;
}

sub strsize {
   my ($word) = @_;
   my @word_arr = split //, $word;
   return $#word_arr+1;
}

sub write_social {
   my ($socname,$fpriv,$fself,$fnobody,$fpublic,$fyou,$fthem) = @_;
   my $filename = "$path/$socname.txt";
   open(FILE,">", $filename);
   print FILE "$fpriv\n";
   print FILE "$fnobody\n";
   print FILE "$fpublic\n";
   print FILE "$fself\n";
   print FILE "$fthem\n";
   print FILE "$fyou\n";
   close FILE;
   return;
}

sub irssicmd_reset {
   for my $cmd (Irssi::commands()) {
      if($cmd->{category} eq "Social Commands") {
         my $tmp=$cmd->{cmd};
         Irssi::command_unbind($tmp,'on_cmd');
      }
   }
}

sub irssicmd_socials {
   my ($socname) = @_;
   irssicmd_reset();
   my $cutstr= ".txt";
   my $filename = "$path/$socname.txt";
   opendir(DIR,$path) or return 0;
   while (defined(my $file = readdir(DIR))) {
      if($file =~ m".txt") { 
         my $tmp=$file;
         $tmp =~ s/$cutstr//;
         Irssi::command_bind($tmp,'on_cmd','Social Commands');
         }
      }
}

sub on_cmd {
   my ($data, $server, $witem) = @_;
   my @data_arr = split / /, $lastcmd;
   my $cutstr = "/";
   my $socname = @data_arr[0];
   $socname =~ s/$cutstr//;
   my $target=Irssi::active_win()->{active}->{name};
   $home_chan=$target;
   my $nick = "TechWizard";
   my ($msgsw, $nick2);
   if($#data_arr == 0) {
      $nick2 = "UNSET";
      $msgsw=0;
      }
   if($#data_arr == 1) {
      $nick2 = @data_arr[1];
      $msgsw=0;
      }
   if($#data_arr == 2) {
      $nick2 = @data_arr[1];
      $msgsw=1;
      }  
   if($home_chan =~ /^#/) {
      my $chan = Irssi::Irc::Server->channel_find($home_chan);
      my $nick_obj = $chan->nick_find($nick2);
      if($nick_obj->{nick} eq "" && $nick2 ne "UNSET") { 
         $server->command("msg $target nickname does not exist.");
         return;
         }
      }
   do_social($server,$target,$socname,$nick,$nick2,$msgsw);
}

sub cmd_sig {
   my($args) = @_;
   irssicmd_socials();
   $lastcmd=$args;
}

sub check_dir {
    my $sw=1;
    opendir(DIR,$path) or $sw=0;
    closedir(DIR);
    return $sw;
}

sub init_socpath {
   if(check_dir()) { return; }
   my @socnam_arr = ("beer","bslap","chains","cut","drp","fart","french","halo",
                  "hug","hump","kiss","smacks","smooch","spank","stab","staple",
                  "strip","trout","whips","yawn"
   );
   my @socline_arr = (
               "0\nWho wants Beer!?!?!?\nname1 throws name2 a fresh cold beer out of the fridge.\nname1 opens up a nice cold beer, and drinks it.\nname1 tosses you a nice cold beer, better catch it!!\nyou just tossed name2 a nice cold beer.\n",
               "0\nLook OUT!!!! name1 is ready to Bitch slap someone!!!!\nname1 Bitch slaps name2 Violently, OUWWW that gotta hurt!\nname1 Bitch Slaps themself hard, Are they Crazy or what???\nyou gotten Bitch Slapped by name1, can you call 911?.\nyou violently bitch slap name2.\n",
               "0\nname1 looks around swinging the chains around, who shall be my victim?\nname1 chains name2 up, Ohh... Boy, name2 is gonna get it...\nname1 chain themself up, and swallowed the keys.\nname1 chained you up, aren't you wondering what they will do next?\nyou just chained up name2, whats next? torchure?\n",
               "0\nname1 wants to cut something......\nname1 cut name2 arms and legs off with blood on your face\nname1 cut something on them off\nyou cut everything off of their body\nyou cut name2 arms and legs off and blood flies everywhere\n",
               "0\nname1 goes out and buys a box of ~R1Dr.Pepper~RS.\nname1 tosses a ~R1Dr.Pepper~RS can to name2, If you waste it, You're Dead.\nname1 grabs a ~R1Dr.Pepper~RS, pops it open and gulps it down... aaahhhh.....\nname1 tosses you a can of ~R1Dr.Pepper~RS.\nyou gave name2 a can of ~R1Dr.Pepper~RS.\n",
               "0\nname1 farts, Roam roam!!!! Can ya hear it?\nname1 farts towards name2!! QUICK Wear a Gas Mask!!!!\nname1 farts up a storm and kills themself.\nname1 farts towards you, EWWWWW!!! can ya smell it????\nyou farted towards name2! you B*stard!\n",
               "0\nname1 need to be french\nname1 french name2 until name2 cant breathe\nname1 want to be french\nname1 french them until name1 cant breathe\nyou french name2 with all you got\n",
               "0\nname1 looks around seeing whoes innocent.\nname1 does their best best to look innocent.\nname1 looks and the mirror and finds a gold circle.\nblah\n",
               "0\nname1 needs a hug.\nname1 hugs name2 tightly.\nname1 hugs themself tightly.\nname1 hugs you tightly.\nyou hugs name2 tightly.\n",
               "0\nname1 wants to be hump........\nname1 hump name2 until name1 drop\nname1 hump themself\nname1 hump them hard and passionately\nyou hump name2 with all you got\n",
               "0\nname1 needs a kiss.\nname1 kisses name2 passionately.\nname1 kisses themself passionately.\nname1 kisses them passionately.\nyou kisses name2 passionately.\n",
               "0\nname1 smacks his monkey slowly.\nname1 smacks name2 for being an idiot, What were they thinking???\nname1 smacks and smacks until his face burns red.\nname1 smacks you for being an idiot.\nyou smacked name2, that damn idiot, what were they thinking???\n",
               "0\nname1 smooches everyone in the channel.\nname1 smooches name2. AWW aint that cute.. NOT!!!\nname1 tries to smooch themself, but can't. Anyone got a mirror????\nname1 smooches you very passionately.\nyou have smooched name2 on the lips.\n",
               "0\nname1 looks for a paddle to spank someone's ass with.\nname1 spanks name2 ass for being naughty.....\nname1 is trying to spank their own ass, does somebody have a paddle?\nyou felt something on your ass, you turned around a look, did name1 spank you?\nhow did feel spanking name2's ass.\n",
               "0\nLook OUT!!!! name1 is ready to Stab someone with a knife!!!!\nname1 Stabs name2 Violently, I  hope they got life insurance\nname1 tries to Stab themself with a knife, 911, SUICIDE!!!\nname1 slaps ya with their dirty trout, are you going to let them get away with that???\nyou slapped name2 with your trout, I hope ya cleaned it first.\n",
               "0\nname1 grabs a staple gun and reloads the gun.\nname1 staples name2 to the wall, now they can't run, MUahahaha....\nname1 tries to staple themself to the wall, OUWWWW!!\nyou got stapled to the wall by name1.\nyou have stapled name2 to the wall.\n",
               "0\nname1 is waiting for someone to strip down, any volunteers?\nname1 strips name2 down one clothes after another.\nname1 watches themself in a mirror while stripping down.\nname1 is removing ya clothes.\nyou are removing name2's clothes, you better hope that camera is ready.\n",
               "0\nname1 is juggling the trout while looking for their victim.\nname1 slaps name2 with their dirty trout, *SPLAT*!!!\nname1 slaps himself with a dead trout, EWWWWWWW\nname1 slaps you with a dead trout, EWWWWWWW!!!\nyou slapped name2 with a dead trout, EWWWWWWW!!!\n",
               "0\nname1 is looking for a whip to torture someone.......RUN............\nname1 whips name2 until name1 sees blood.....\nname1 whips themself without mercy\nname1 whips them violently\nyou whips name2 with everything you have\n",
               "0\nname1 yawns and stretches.\nname1 yawns at name2, mann.. You're boring.\nname1 yawns and stretches and then falls over, WHOOPS!!\nname1 yawns at you, they are very bored.\nyou yawned at name2, how rude....\n",
   );
   my $cx=0;
   print "Mkdir $path.";
   mkdir($path);
   print "Inserting socials into $path.";
   foreach my $socname (@socnam_arr) {
      my $filename = "$path/$socname.txt";
      open(FILE,">", $filename);
      print FILE @socline_arr[$cx];
      close FILE;
      $cx++;
   }
}

Irssi::command_bind('social','irssi_print_social','tech_addon');
Irssi::command_bind('social set','irssi_setsoc','tech_addon');
Irssi::command_bind('social color','irssi_colorlist','tech_addon');
Irssi::command_bind('social reset','irssicmd_reset','tech_addon');
Irssi::command_bind('social add','irssi_addsoc','tech_addon');
Irssi::command_bind('social del','irssi_delsoc','tech_addon');
Irssi::command_bind('social list','irssi_socblist','tech_addon');
Irssi::command_bind('soclist','irssi_socblist','tech_addon');
Irssi::command_bind('soccolor','irssi_socblist','tech_addon');

Irssi::signal_add_first('send command', 'cmd_sig');
Irssi::signal_add_last('message public', 'message_public');
Irssi::signal_add_last('message private', 'message_private');
Irssi::signal_add_last("message own_public", "on_public");
Irssi::signal_add_last("message own_private", "on_private");
Irssi::settings_add_bool('tech_addon', 'twsocials_instruct', 1);
Irssi::settings_add_bool('tech_addon', 'twsocials_remote', 0);
irssicmd_socials();

if(Irssi::settings_get_bool('twsocials_instruct')) {
   print $instrut;
   }

