#!/usr/bin/perl
use Irssi 20011210.0250 ();
$VERSION = "1.2";
%IRSSI = (
    authors     => 'David Leadbeater',
    contact     => 'dgl@dgl.cx',
    name        => 'sysinfo-dg',
    description => 'Adds a /sysinfo command which prints system information (linux only).',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.dgl.yi.org/',
);

#This script is mostly my own work but some ideas where taken from /sinfo by
#Laurens Buhler and Alain van Acker. Please leave this credit in the script and
#if you edit it and think the change is worthwhile tell me and i may add it into
#the script and credit you

use strict;
use vars qw/$colour $graphs $graphs2 $colour2 $style/;
Irssi::command_bind("sysinfo","sysinfo");

sub sysinfo{
   my @options = split(/ /,$_[0]);
   my %info;
   my($hostname,$uname,$procs) = basicinfo();
   my($distro) = distro();
   my($uptime,$users,$loadavg) = uptime();
   my($memsize,$memfree) = meminfo();
   my($swapsize,$swapfree) = swapinfo();
   my($cpumodel,$cpumhz,$cpucache,$bogomips) = cpuinfo();
   my %netinfo = netinfo();
   my($disktotal,$diskused,$hddtype) = df();
   my($videocard,$ethernet) = pciinfo();
   my($screenres,$screendepth);
   ($screenres,$screendepth) = screenres() if $ENV{DISPLAY};

   ($colour,$graphs,$graphs2,$colour2,$style) = parseoptions(\%netinfo,@options);

   %info = (   
      'os' => "$uname - $distro",
      'up' => $uptime,
      'cpu' => "$cpumodel, $cpumhz MHz ($bogomips bogomips)",
      'cache' => $cpucache,
      'mem' => ($memsize-$memfree) . "/$memsize MB (" . percent(($memsize-$memfree),$memsize) . ")",
      'host' => $hostname,
      'users' => $users,
      'load' => $loadavg,
      'procs' => $procs,
      'swap' => ($swapsize-$swapfree) . "/$swapsize MB (" . percent(($swapsize-$swapfree),$swapsize) . ")",
      'disk' => "$diskused/$disktotal MB (" . percent($diskused,$disktotal) . ") ($hddtype)",
      'video' => "$videocard at $screenres ($screendepth bits)",
      'ethernet' => $ethernet,
   );

   for(keys %netinfo){
      $info{$_} = "in: $netinfo{$_}{in} MB, out: $netinfo{$_}{out} MB";
   }

   my $tmp;
   for(split(/ /,$style)){
      $tmp .= ircbit($_,$info{$_}) . " ";
   }
   $tmp =~ s/ $//;
   Irssi::active_win()->command('say ' . $tmp);
   ($colour,$graphs,$graphs2,$colour2,$style) = undef;
}

sub parseoptions{
   my($netinfo,@options) = @_;

   my $tmp = shift(@options) if $options[0] =~ /^\-/;
   $tmp =~ s/^\-//;
   for(split //,$tmp){
	  if($_ eq "c"){
		 $tmp =~ /c(\d+)/;
		 $colour = $1;
		 if(!$colour){
			$colour = 3;
		 }
	  }elsif($_ eq "g"){
		 $tmp =~ /g(\d+)/;
		 $graphs = $1;
		 if(!$graphs){
			$graphs = 9;
		 }
	  }elsif($_ eq "G"){
		 $tmp =~ /G(\d+)/;
		 $graphs2 = $1;
	  }elsif($_ eq "C"){
		 $tmp =~ /C(\d+)/;
		 $colour2 = $1;
	  }
   }
   if(!defined $colour2 && $colour){
	  $colour2 = 15;
   }
   if(defined $graphs && !defined $graphs2){
	  $graphs2 = 3;
   }

# We got the names on the command line
   if($options[1]){
      $style = join(" ",@options);
# style name
   }elsif($options[0]){
      if($options[0] eq "std"){
	     $style = "os up cpu mem video";
      }elsif($options[0] eq "bigger"){
	     $style = "os up cpu cache mem load procs disk video";
      }elsif($options[0] eq "full"){
	     $style = "host os up cpu cache mem users load procs swap disk video ethernet ".join(" ",keys %{$netinfo});
      }elsif($options[0] eq "net"){
	     $style = join(" ",keys %{$netinfo});
      }elsif($options[0] eq "uptime"){
	     $style = "os up";
      }elsif($options[0] eq "use"){
	     $style = "mem swap disk";
      }
   }else{
# no input - default
      $style = "os up cpu mem video";
   }
   
   return($colour,$graphs,$graphs2,$colour2,$style);
}

sub ircbit{
   my($name,$text) = @_;
   $name = " " . $name if $name =~ /^\d/;
   $text = " " . $text if $text =~ /^\d/;
   if($colour){
	  return "$colour$name$colour2\[$text$colour2\]";
   }else{
      return "$name\[$text\]";
   }
}

sub percent{
   my $percent = sprintf("%.1f",(($_[0]/$_[1])*100));
   if($graphs){
	  my $tmp = "[";
	  for(1..10){
	     if($_ > sprintf("%.0f",$percent / 10)){
			$tmp .= "-" if !defined $colour;
			$tmp .= "$graphs2-" if defined $colour;
	     }else{
		    $tmp .= "|" if !defined $colour;
		    $tmp .= "$graphs|" if defined $colour;
	     }
	  }
	  $tmp .= "]";
	  return $percent."% ".$tmp;
   }
   return $percent."%";
}

sub uptime{
   my $uptimeinfo = `uptime`;
   if ($uptimeinfo =~ /^\s+(\d+:\d+\w+|\d+:\d+:\d+)\s+up\s+(\d+)\s+day.?\W\s+(\d+):(\d+)\W\s+(\d+)\s+\w+\W\s+\w+\s+\w+\W\s+(\d+).(\d+)/igx) {
     return("$2 days, $3 hours, $4 minutes", $5, "$6.$7");
   }elsif ($uptimeinfo =~ /^\s+(\d+:\d+\w+|\d+:\d+:\d+)\s+up+\s+(\d+):(\d+)\W\s+(\d+)\s+\w+\W\s+\w+\s+\w+\W\s+(\d+).(\d+)/igx) {
	  return("$2 hours, $3 minutes", $4, "$5.$6");
   }elsif ($uptimeinfo =~ /^\s+(\d+:\d+\w+|\d+:\d+:\d+)\s+up\s+(\d+)\s+day.?\W\s+(\d+)\s+min\W\s+(\d+)\s+\w+\W\s+\w+\s+\w+\W\s+(\d+).(\d+)/igx) {
	  return("$2 days, $3 minutes", $4, "$5.$6");
   }elsif ($uptimeinfo =~ /^\s+(\d+:\d+\w+|\d+:\d+:\d+)\s+up+\s+(\d+)\s+min\W\s+(\d+)\s+\w+\W\s+\w+\s+\w+\W\s+(\d+).(\d+)/igx) {
	  return("$2 minutes", $3, "$4.$5");
   }
   return undef;
}

sub meminfo{
   my($memsize,$memfree);
   open(MEMINFO, "/proc/meminfo") or return undef;
   while(<MEMINFO>){
      chomp;
      if(/^MemTotal:\s+(\d+)/){
	     $memsize = sprintf("%.2f",$1/1024);
      }elsif(/^MemFree:\s+(\d+)/){
	     $memfree = sprintf("%.2f",$1/1024);
      }
   }
   close(MEMINFO);
   return($memsize,$memfree);
}

sub swapinfo{
   my($swapsize,$swapused);
   open(SWAPINFO, "/proc/swaps");
   while(<SWAPINFO>){
	  chomp;
	  next if !/^\//;
	  /\S+\s+\S+\s+(\S+)\s+(\S+)/;
	  $swapsize += $1;
	  $swapused += $2;
   }
   close(SWAPINFO);
   my $swapfree =  sprintf("%.2f",($swapsize - $swapused) / 1024);
   $swapsize = sprintf("%.2f", $swapsize / 1024);
   return($swapsize,$swapfree);
}

sub netinfo{
   my(%netinfo);
   open(NETINFO, "/proc/net/dev") or return undef;
   while(<NETINFO>){
	  chomp;
	  next if /^(\s+)?(Inter|face|lo)/;
	  /^\s*(\w+):\s*(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+/;
	  $netinfo{$1}{in} = sprintf("%.2f",$2 / 1048576);
	  $netinfo{$1}{out} = sprintf("%.2f",$3 / 1048576);
   }
   close(NETINFO);
   return %netinfo;
}

sub distro{
   my $distro;
   if(-f "/etc/coas"){
      $distro = firstline("/etc/coas");
   }elsif(-f "/etc/environment.corel"){
      $distro = firstline("/etc/environment.corel");
   }elsif(-f "/etc/debian_version"){
      $distro = "Debian ".firstline("/etc/debian_version");
   }elsif(-f "/etc/mandrake-release"){
      $distro = firstline("/etc/mandrake-release");
   }elsif(-f "/etc/SuSE-release"){
      $distro = firstline("/etc/SuSE-release");
   }elsif(-f "/etc/turbolinux-release"){
      $distro = firstline("/etc/turbolinux-release");
   }elsif(-f "/etc/slackware-release"){
      $distro = firstline("/etc/slackware-release");
   }elsif(-f "/etc/redhat-release"){
      $distro = firstline("/etc/redhat-release");
   }
   return $distro;
}

sub df{
   my($disktotal,$diskused,$mainhd);
   for(`df`){
      chomp;
      next if !/^\/dev\/\S+/;
      next if /(cd|cdrom|fd|floppy)/;
      /^(\S+)\s+(\S+)\s+(\S+)/;
	  $mainhd = $1 if !defined $mainhd;
	  next if not defined $1 or not defined $2;
      $disktotal += $2;
      $diskused += $3;
   }
   $disktotal = sprintf("%.2f",$disktotal / 1024);
   $diskused = sprintf("%.2f",$diskused / 1024);

   $mainhd =~ s/\/dev\/([a-z]+)\d+/$1/;
   my $hddtype = firstline("/proc/ide/$mainhd/model");

   return($disktotal,$diskused,$hddtype);
}

sub basicinfo{
   my($hostname,$sysinfo,$procs);
   chomp($hostname = `hostname`);
   chomp($sysinfo = `uname -sr`);
   opendir(PROC, "/proc");
   $procs = scalar grep(/^\d/,readdir PROC);
   return($hostname,$sysinfo,$procs);
}

sub cpuinfo{
   my($cpumodel,$cpusmp,$cpumhz,$cpucache,$bogomips);
   open(CPUINFO, "/proc/cpuinfo") or return undef;
   while(<CPUINFO>){
      if(/^model name\s+\:\s+(.*?)$/){
	     if(defined $cpumodel){
		    if(defined $cpusmp){
			   $cpusmp++;
		    }else{
		       $cpusmp=2;
		    }
	     }else{
	        $cpumodel = $1;
	     }
      }elsif(/^cpu MHz\s+:\s+([\d\.]*)/){
	     $cpumhz = $1;
      }elsif(/^cache size\s+:\s+(.*)/){
	     $cpucache = $1;
      }elsif(/^bogomips\s+:\s+([\d\.]*)/){
		 $bogomips += $1;
	  }
   }
   $cpumodel .= " SMP ($cpusmp processors)" if defined $cpusmp;
   return($cpumodel,$cpumhz,$cpucache,$bogomips);
}

sub pciinfo{
   my($videocard,$ethernet);
   open(PCI, "/proc/pci") or return undef;
   while(<PCI>){
      chomp;
      if(/VGA compatible controller: (.*?)$/){
         $videocard .= "${1}+ ";
      }elsif(/Ethernet controller: (.*?)$/){
	     $ethernet = $1;
      }
   }
   close(PCI);
   $videocard =~ s/\+ $//;
   return($videocard,$ethernet);
}

sub screenres{
   my ($res,$depth);
   for(`xdpyinfo`){
	  if(/\s+dimensions:\s+(\S+)/){
		 $res = $1;
	  }elsif(/\s+depth:\s+(\S+)/){
		 $depth = $1;
	  }
   }
   return($res,$depth);
}

sub firstline{
   my $file = shift;
   open(FILE, "$file") or return undef;
   chomp(my $line = <FILE>);
   close(FILE);
   return $line;
}

