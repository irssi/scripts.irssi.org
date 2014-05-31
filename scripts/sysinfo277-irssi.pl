#!/usr/bin/perl -w
#
# Copyright (c) 2002, 2003 David Rudie
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $ident: sysinfo277-irssi.pl,v 2.77 2003/09/01 04:20:02 drudie Exp $
#


$VERSION = '2.77';
%IRSSI = (
  authors	=> 'David Rudie',
  contact	=> 'david@inexistent.com',
  name		=> 'SysInfo',
  description	=> 'Cross-platform/architecture system information script.',
  license	=> 'BSD',
  url		=> 'http://www.inexistent.com/',
  changed	=> 'Mon Sep 01 04:20 PDT 2003',
  bugs		=> 'Probably some if it cannot read /proc.'
);


use Irssi;
use POSIX qw(floor);
use strict;


# Set up the arrays and variables first.
use vars qw(
  @arr
  @arr1
  @arr2
  $cpu
  @cpu
  @cpuinfo
  $data
  @data
  $df
  @dmesgboot
  @hinv
  @meminfo
  $mhz
  @mhz
  $model
  @netdev
  @netstat
  @nic
  @nicname
  $smp
  @smp
  $stream
  $sysctl
  @uptime
  $var
  $vara
  $varb
  $varc
  $vard
  $varh
  $varm
  $varp
  $varx
  $vary
  $varz
);


my $os		= `uname -s`; chop($os);
my $osn		= `uname -n`; chop($osn);
my $osv		= `uname -r`; chop($osv);
my $osm		= `uname -m`; chop($osm);
my $uname	= "$os $osv/$osm";


my $darwin	= 1 if $os =~ /^Darwin$/;
my $freebsd	= 1 if $os =~ /^FreeBSD$/;
my $linux	= 1 if $os =~ /^Linux$/;
my $netbsd	= 1 if $os =~ /^NetBSD$/;
my $openbsd	= 1 if $os =~ /^OpenBSD$/;
my $irix	= 1 if $os =~ /^IRIX$/;
my $irix64	= 1 if $os =~ /^IRIX64$/;


my $alpha	= 1 if $osm =~ /^alpha$/;
my $armv4l	= 1 if $osm =~ /^armv4l$/;
my $armv5l	= 1 if $osm =~ /^armv5l$/;
my $i586	= 1 if $osm =~ /^i586$/;
my $i686	= 1 if $osm =~ /^i686$/;
my $ia64	= 1 if $osm =~ /^ia64$/;
my $mips	= 1 if $osm =~ /^mips$/;
my $parisc64	= 1 if $osm =~ /^parisc64$/;
my $ppc		= 1 if $osm =~ /^ppc$/;
my $x86_64	= 1 if $osm =~ /^x86_64$/;


my $l26 = 1 if $osv =~ /^2\.6/;


sub cmd_sysinfo {
  # Specify your NIC interface name (eth0, rl0, fxp0, etc) and a name for it.
  #
  # Example: @nic     = ('eth0', 'eth1');
  #          @nicname = ('External', 'Internal');
  #
  # NOTE: If you set one then you HAVE to set the other.
  @nic		= split(/;/, Irssi::settings_get_str('sysinfo_nics'));
  @nicname	= split(/;/, Irssi::settings_get_str('sysinfo_nicnames'));


  # These are the default settings for which information gets displayed.
  # 0 = Off; 1 = On
  my $showHostname	= 1;
  my $showOS		= 1;
  my $showCPU		= 1;
  my $showProcesses	= 1;
  my $showUptime	= 1;
  my $showLoadAverage	= 1;
  my $showBattery	= 0;
  my $showMemoryUsage	= 1;
  my $showDiskUsage	= 1;
  my $showNetworkTraffic= 1;


  ###############################################
  ### Nothing below here should need changed. ###
  ###############################################


  if($linux) {
    @cpuinfo		= &openfile("/proc/cpuinfo");
    @meminfo		= &openfile("/proc/meminfo");
    @netdev		= &openfile("/proc/net/dev");
    @uptime		= &openfile("/proc/uptime");
  } elsif($irix || $irix64) {
    @hinv		= `hinv`;
  } else {
    @dmesgboot		= &openfile("/var/run/dmesg.boot");
    @netstat		= `netstat -ibn`;
    if($darwin) {
      $sysctl		= '/usr/sbin/sysctl';
    } else {
      $sysctl		= '/sbin/sysctl';
    }
  }


  if($armv4l || $armv5l) {
    $df			= 'df -k';
  } else {
    $df			= 'df -lk';
  }


  if($showCPU) {
    if($freebsd) {
      if($alpha) {
        @cpu		= grep(/^COMPAQ/, @dmesgboot);
        $cpu		= join("\n", $cpu[0]);
      } else {
        @cpu		= grep(/CPU: /, @dmesgboot);
        $cpu		= join("\n", @cpu);
        @cpu		= split(/: /, $cpu);
        $cpu		= $cpu[1];
        @smp		= grep(/ cpu/, @dmesgboot);
        $smp		= scalar @smp;
      }
    }
    if($netbsd) {
      if($alpha) {
        @cpu		= grep(/^COMPAQ/, @dmesgboot);
        $cpu		= join("\n", $cpu[0]);
        @cpu		= split(/, /, $cpu);
        $cpu		= $cpu[0];
      } else {
        @cpu		= grep(/cpu0: /, @dmesgboot);
        @cpu		= grep(!/apic/, @cpu);
        $cpu		= join("\n", $cpu[0]);
        @cpu		= split(/: /, $cpu);
        $cpu		= $cpu[1];
        @smp		= grep(/cpu\d+:/, @dmesgboot);
        @smp		= grep(/MHz/, @smp);
        $smp		= scalar @smp;
      }
    }
    if($openbsd) {
      @cpu		= grep(/cpu0: /, @dmesgboot);
      @cpu		= grep(/[M|G]Hz/, @cpu);
      $cpu		= join("\n", @cpu);
      @cpu		= split(/: /, $cpu);
      $cpu		= $cpu[1];
    }
    if($irix || $irix64) {
      @cpu		= grep(/CPU:/, @hinv);
      $cpu		= join("\n", @cpu);
      $cpu		=~ s/^.*(R[0-9]*) .*$/$1/;
      @mhz		= grep(/MHZ/, @hinv);
      $mhz		= join("\n", @mhz);
      $mhz		= $mhz[0];
      $mhz		=~ s/^.* ([0-9]*) MHZ.*$/$1/;
      @smp		= grep(/ IP/, @hinv);
      $smp		= scalar @smp;
      chop($cpu);
      chop($mhz);
      $cpu		= "MIPS $cpu ($mhz MHz)";
    }
    if($linux) {
      if($alpha) {
        $cpu		= &cpuinfo("cpu\\s+: ");
        $model		= &cpuinfo("cpu model\\s+: ");
        $cpu		= "$cpu $model";
        $smp		= &cpuinfo("cpus detected\\s+: ");
      }
      if($armv4l || $armv5l) {
        $cpu		= &cpuinfo("Processor\\s+: ");
      }
      if($i686 || $i586 || $x86_64) {
        $cpu		= &cpuinfo("model name\\s+: ");
        $cpu		=~ s/(.+) CPU family\t+\d+MHz/$1/g;
        $cpu		=~ s/(.+) CPU .+GHz/$1/g;
        $mhz		= &cpuinfo("cpu MHz\\s+: ");
        $cpu		= "$cpu ($mhz MHz)";
        @smp		= grep(/processor\s+: /, @cpuinfo);
        $smp		= scalar @smp;
      }
      if($ia64) {
        $cpu		= &cpuinfo("vendor\\s+: ");
        $model		= &cpuinfo("family\\s+: ");
        $mhz		= &cpuinfo("cpu MHz\\s+: ");
        $mhz		= sprintf("%.2f", $mhz);
        $cpu		= "$cpu $model ($mhz MHz)";
        @smp		= grep(/processor\s+: /, @cpuinfo);
        $smp		= scalar @smp;
      }
      if($mips) {
        $cpu		= &cpuinfo("cpu\\s+: ");
        $model		= &cpuinfo("cpu model\\s+: ");
        $cpu		= "$cpu $model";
      }
      if($parisc64) {
        $cpu		= &cpuinfo("cpu\\s+: ");
        $model		= &cpuinfo("model name\\s+: ");
        $mhz		= &cpuinfo("cpu MHz\\s+: ");
        $mhz		= sprintf("%.2f", $mhz);
        $cpu		= "$model $cpu ($mhz MHz)";
      }
      if($ppc) {
        $cpu		= &cpuinfo("cpu\\s+: ");
        $mhz		= &cpuinfo("clock\\s+: ");
        if($cpu =~ /^9.+/) {
          $model	= "IBM PowerPC G5";
        } elsif($cpu =~ /^74.+/) {
          $model	= "Motorola PowerPC G4";
        } else {
          $model	= "IBM PowerPC G3";
        }
        $cpu		= "$model $cpu ($mhz)";
      }
    } elsif($darwin) {
      $cpu		= `hostinfo | grep 'Processor type' | cut -f2 -d':'`; chomp($cpu);
      $cpu		=~ s/^\s*(.+)\s*$/$1/g;
      if($cpu =~ /^ppc7.+/) {
        $cpu		= "Motorola PowerPC G4";
      }
      $mhz		= `$sysctl -n hw.cpufrequency`; chomp($mhz);
      $mhz		= sprintf("%.2f", $mhz / 1000000);
      $cpu		= "$cpu ($mhz MHz)";
      $smp		= `hostinfo | grep "physically available" | cut -f1 -d' '`; chomp($smp);
    }
    if($smp && $smp gt 1) {
      $cpu = "$smp x $cpu";
    }
  }


  my $output;
  if($showHostname)		{ $output  = "Hostname: $osn - "; }
  if($showOS)			{ $output .= "OS: $uname - "; }
  if($showCPU)			{ $output .= "CPU: $cpu - "; }
  if($showProcesses)		{ $output .= "Processes: ".&processes." - "; }
  if($showUptime)		{ $output .= "Uptime: ".&uptime." - "; }
  if($showLoadAverage)		{ $output .= "Load Average: ".&loadaverage." - "; }
  if($showBattery)		{ $output .= "Battery: ".&battery." - "; }
  if($showMemoryUsage)		{ $output .= "Memory Usage: ".&memoryusage." - "; }
  if($showDiskUsage)		{ $output .= "Disk Usage: ".&diskusage." - "; }
  if($showNetworkTraffic)	{ $output .= &networktraffic; }
  $output =~ s/ - $//g;
  Irssi::active_win()->command("/ $output");
  return 1;
}


sub battery {
  $data = "";
  if(open(FD, '/proc/apm')) {
    while($stream = <FD>) {
      $data .= $stream;
      @data = split(/\n/, $data);
    }
    close(FD);
  }
  $data = $data[0];
  $data =~ s/.+\s(\d+%).+/$1/;
  return $data;
}


sub cpuinfo {
  my $string = shift;
  @arr = grep(/$string/, @cpuinfo);
  $var = join("\n", $arr[0]);
  @arr = split(/: /, $var);
  $var = $arr[1];
  return $var;
}


sub diskusage {
  if($irix || $irix64) {
    $vara = `$df | grep -v Filesystem | awk '{ sum+=\$3 / 1024 / 1024}; END { print sum }'`; chomp($vara);
    $vard = `$df | grep -v Filesystem | awk '{ sum+=\$4 / 1024 / 1024}; END { print sum }'`; chomp($vard);
  } else {
    $vara = `$df | grep -v Filesystem | awk '{ sum+=\$2 / 1024 / 1024}; END { print sum }'`; chomp($vara);
    $vard = `$df | grep -v Filesystem | awk '{ sum+=\$3 / 1024 / 1024}; END { print sum }'`; chomp($vard);
  }
  $varp = sprintf("%.2f", $vard / $vara * 100);
  $vara = sprintf("%.2f", $vara);
  $vard = sprintf("%.2f", $vard);
  return $vard."GB/".$vara."GB ($varp%)";
}


sub loadaverage {
  $var = `uptime`; chomp($var);
  if($irix || $irix64 || $linux) {
    @arr = split(/average: /, $var, 2);
  } else {
    @arr = split(/averages: /, $var, 2);
  }
  @arr = split(/, /, $arr[1], 2);
  $var = $arr[0];
  return $var;
}


sub meminfo {
  my $string = shift;
  @arr = grep(/$string/, @meminfo);
  $var = join("\n", $arr[0]);
  @arr = split(/\s+/, $var);
  $var = $arr[1];
  return $var;
}


sub memoryusage {
  if($linux) {
    if($l26) {
      $vara = &meminfo("MemTotal:") * 1024;
      $varb = &meminfo("Buffers:") * 1024;
      $varc = &meminfo("Cached:") * 1024;
      $vard = &meminfo("MemFree:") * 1024;
    } else {
      @arr = grep(/Mem:/, @meminfo);
      $var = join("\n", @arr);
      @arr = split(/\s+/, $var);
      $vara = $arr[1];
      $varb = $arr[5];
      $varc = $arr[6];
      $vard = $arr[3];
    }
    $vard = ($vara - $vard) - $varb - $varc;
  } elsif($darwin) {
    $vard = `vm_stat | grep 'Pages active' | awk '{print \$3}'` * 4096;
    $vara = `$sysctl -n hw.physmem`;
  } elsif($irix || $irix64) {
    $var = `top -d1 | grep Memory`; chomp($var);
    $vara = $var;
    $vard = $var;
    $vara =~ s/^.* ([0-9]*)M max.*$/$1/;
    $vara *= 1024 * 1024;
    $vard =~ s/^.* ([0-9]*)M free,.*$/$1/;
    $vard = $vara - ($vard * 1024 * 1024);
  } else {
    $vard = `vmstat -s | grep 'pages active' | awk '{print \$1}'` * `vmstat -s | grep 'per page' | awk '{print \$1}'`;
    $vara = `$sysctl -n hw.physmem`;
  }
  $varp = sprintf("%.2f", $vard / $vara * 100);
  $vara = sprintf("%.2f", $vara / 1024 / 1024);
  $vard = sprintf("%.2f", $vard / 1024 / 1024);
  return $vard."MB/".$vara."MB ($varp%)";
}


sub networkinfobsd {
  $varc = shift;
  $vard = shift;
  @arr = grep(/$varc/, @netstat);
  @arr = grep(/Link/, @arr);
  $var = join("\n", @arr);
  @arr = split(/\s+/, $var);
  $var = $arr[$vard] / 1024 / 1024;
  $var = sprintf("%.2f", $var);
  return $var;
}


sub networkinfolinux {
  $varc = shift;
  $vard = shift;
  @arr = grep(/$varc/, @netdev);
  $var = join("\n", @arr);
  @arr = split(/:\s*/, $var);
  @arr = split(/\s+/, $arr[1]);
  $var = $arr[$vard] / 1024 / 1024;
  $var = sprintf("%.2f", $var);
  return $var;
}


sub networktraffic {
  $vara = 0;
  $varz = "";
  $varb = scalar @nic;
  if($nic[$vara] ne "") {
    while($vara lt $varb) {
      if($nic[$vara] ne "") {
        if($darwin || $freebsd) {
          $varx = &networkinfobsd($nic[$vara], 6);
          $vary = &networkinfobsd($nic[$vara], 9);
        }
        if($netbsd || $openbsd) {
          $varx = &networkinfobsd($nic[$vara], 4);
          $vary = &networkinfobsd($nic[$vara], 5);
        }
        if($linux) {
          $varx = &networkinfolinux($nic[$vara], 0);
          $vary = &networkinfolinux($nic[$vara], 8);
        }
        $varz .= $nicname[$vara]." Traffic (".$nic[$vara]."): ".$varx."MB In/".$vary."MB Out - ";
      }
      $vara++;
    }
    return $varz;
  }
}


sub openfile {
  my $string = shift;
  $data = "";
  if(open(FD, $string)) {
    while($stream = <FD>) {
      $data .= $stream;
      @data = split(/\n/, $data);
    }
    close(FD);
  }
  return @data;
}


sub processes {
  if($irix || $irix64) {
    $var = `ps -e | grep -v PID | wc -l`;
  } else {
    $var = `ps ax | grep -v PID | wc -l`;
  }
  chomp($var);
  $var = $var;
  $var =~ s/^\s+//;
  $var =~ s/\s+$//;
  return $var;
}


sub uptime {
  if($irix || $irix64) {
    $var = `uptime`; chomp($var);
    if($var =~ /day/) {
      $var =~ s/^.* ([0-9]*) day.* ([0-9]*):([0-9]*), .*$/$1d $2h $3m/;
    } elsif($var =~/min/) {
      $var =~ s/^.* ([0-9]*) min.*$/0d 0h $1m/;
    } else {
      $var =~ s/^.* ([0-9]*):([0-9]*),.*$/0d $1h $2m/;
    }
    return $var;
  } else {
    if($freebsd) {
      $var = `$sysctl -n kern.boottime | awk '{print \$4}'`;
    }
    if($netbsd || $openbsd || $darwin) {
      $var = `$sysctl -n kern.boottime`;
    }
    if($linux) {
      @arr = split(/ /, $uptime[0]);
      $varx = $arr[0];
    } else {
      chomp($var);
      $var =~ s/,//g;
      $vary = `date +%s`; chomp($vary);
      $varx = $vary - $var;
    }
    $varx = sprintf("%2d", $varx);
    $vard = floor($varx / 86400);
    $varx %= 86400;
    $varh = floor($varx / 3600);
    $varx %= 3600;
    $varm = floor($varx / 60);
    if($vard eq 0) { $vard = ''; } elsif($vard >= 1) { $vard = $vard.'d '; }
    if($varh eq 0) { $varh = ''; } elsif($varh >= 1) { $varh = $varh.'h '; }
    if($varm eq 0) { $varm = ''; } elsif($varm >= 1) { $varm = $varm.'m'; }
    return $vard.$varh.$varm;
  }
}

Irssi::settings_add_str("sysinfo", "sysinfo_nics", "");
Irssi::settings_add_str("sysinfo", "sysinfo_nicnames", "");

Irssi::command_bind("sysinfo", "cmd_sysinfo");
