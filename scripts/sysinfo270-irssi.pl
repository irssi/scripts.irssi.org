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
# $ident: sysinfo270-irssi.pl,v 2.70 2003/07/30 22:52:24 drudie Exp $
#

use strict;
use vars qw($VERSION %IRSSI);
$VERSION = '2.70';
%IRSSI = (
 authors	=> 'David Rudie',
 contact	=> 'david@inexistent.com',
 name		=> 'SysInfo',
 description	=> 'Cross-platform/architecture system information script.',
 license	=> 'BSD',
 url		=> 'http://www.inexistent.com/',
 changed	=> 'Wed Jul 30 22:52 PST 2003',
 bugs		=> 'Probably some if it cannot read /proc.'
);


use Irssi;
use POSIX qw(floor);


sub cmd_sysinfo {
 my $nic_1			= Irssi::settings_get_str('sysinfo_nic_1');
 my $nic_2			= Irssi::settings_get_str('sysinfo_nic_2');
 my $nic_3			= Irssi::settings_get_str('sysinfo_nic_3');
 my $nic_1_name	= Irssi::settings_get_str('sysinfo_nic_1_name');
 my $nic_2_name	= Irssi::settings_get_str('sysinfo_nic_2_name');
 my $nic_3_name	= Irssi::settings_get_str('sysinfo_nic_3_name');

 my($n1,$n2,$n3);
 if($nic_1 ne '') { $n1 = 1; }
 if($nic_2 ne '') { $n2 = 1; }
 if($nic_3 ne '') { $n3 = 1; }


 my $os			= `uname -s`; chop($os);
 my $osn		= `uname -n`; chop($osn);
 my $osv		= `uname -r`; chop($osv);
 my $osm		= `uname -m`; chop($osm);
 my $uname	= "$os $osv/$osm";

 my($darwin, $freebsd, $linux, $netbsd, $openbsd);
 if($os =~ /^Darwin$/)	{ $darwin	= 1; }
 if($os =~ /^FreeBSD$/)	{ $freebsd	= 1; }
 if($os =~ /^Linux$/)	{ $linux	= 1; }
 if($os =~ /^NetBSD$/)	{ $netbsd	= 1; }
 if($os =~ /^OpenBSD$/)	{ $openbsd	= 1; }

 my($alpha, $armv4l, $i586, $i686, $ia64, $mips, $parisc64, $ppc);
 if($osm =~ /^alpha$/)	 { $alpha	= 1; }
 if($osm =~ /^armv4l$/)	 { $armv4l	= 1; }
 if($osm =~ /^i586$/)	 { $i586	= 1; }
 if($osm =~ /^i686$/)	 { $i686	= 1; }
 if($osm =~ /^ia64$/)	 { $ia64	= 1; }
 if($osm =~ /^mips$/)	 { $mips	= 1; }
 if($osm =~ /^parisc64$/){ $parisc64	= 1; }
 if($osm =~ /^ppc$/)	 { $ppc		= 1; }

 my $l26;
 if($osv >= 2.6)	{ $l26		= 1; }


 my $cpuinfo	= "";
 my $meminfo	= "";
 my $netdev	= "";
 my $uptime	= "";
 my $dmesgboot	= "";
 
 my (@cpuinfo, @meminfo, @netdev, @uptime, @dmesgboot, @netstat, $sysctl);
 if($linux) {
  open(CPUINFO, "<", "/proc/cpuinfo");
  while(my $data = <CPUINFO>) {
   $cpuinfo		.= $data;
   @cpuinfo		= split(/\n/, $cpuinfo);
  }
  close(CPUINFO);
  open(MEMINFO, "<", "/proc/meminfo");
  while(my $data = <MEMINFO>) {
   $meminfo		.= $data;
   @meminfo		= split(/\n/, $meminfo);
  }
  close(MEMINFO);
  open(NETDEV, "<", "/proc/net/dev");
  while(my $data = <NETDEV>) {
   $netdev		.= $data;
   @netdev		= split(/\n/, $netdev);
  }
  close(NETDEV);
  open(UPTIME, "<", "/proc/uptime");
  while(my $data = <UPTIME>) {
   $uptime		.= $data;
   @uptime		= split(/\n/, $uptime);
  }
  close(UPTIME);
 } else {
  open(DMESG, "<", "/var/run/dmesg.boot");
  while(my $data = <DMESG>) {
   $dmesgboot		.= $data;
   @dmesgboot		= split(/\n/, $dmesgboot);
  }
  close(DMESG);
  @netstat		= `netstat -ibn`;
  if($darwin) {
   $sysctl		= '/usr/sbin/sysctl';
  } else {
   $sysctl		= '/sbin/sysctl';
  }
 }

 my $df;
 if($armv4l) {
  $df			= 'df -k';
 } else {
  $df			= 'df -lk';
 }

 my (@cpu, $cpu, @smp, $smp, @model, $model, @mhz, $mhz);
 if($freebsd) {
  if($alpha) {
   @cpu			= grep(/^COMPAQ/, @dmesgboot);
   $cpu			= join("\n", $cpu[0]);
  } else {
   @cpu			= grep(/CPU: /, @dmesgboot);
   $cpu			= join("\n", @cpu);
   @cpu			= split(/: /, $cpu);
   $cpu			= $cpu[1];
   @smp			= grep(/ cpu/, @dmesgboot);
   $smp			= scalar @smp;
  }
 }
 if($netbsd) {
  if($alpha) {
   @cpu			= grep(/^COMPAQ/, @dmesgboot);
   $cpu			= join("\n", $cpu[0]);
   @cpu			= split(/, /, $cpu);
   $cpu			= $cpu[0];
  } else {
   @cpu			= grep(/cpu0: /, @dmesgboot);
   @cpu			= grep(!/apic/, @cpu);
   $cpu			= join("\n", $cpu[0]);
   @cpu			= split(/: /, $cpu);
   $cpu			= $cpu[1];
   @smp			= grep(/cpu\d+:/, @dmesgboot);
   @smp			= grep(/MHz/, @smp);
   $smp			= scalar @smp;
  }
 }
 if($openbsd) {
  @cpu			= grep(/cpu0: /, @dmesgboot);
  @cpu			= grep(/[M|G]Hz/, @cpu);
  $cpu			= join("\n", @cpu);
  @cpu			= split(/: /, $cpu);
  $cpu			= $cpu[1];
 }
 if($linux) {
  if($alpha) {
   @cpu			= grep(/cpu\s+: /, @cpuinfo);
   $cpu			= join("\n", $cpu[0]);
   @cpu			= split(/: /, $cpu);
   $cpu			= $cpu[1];
   @model		= grep(/cpu model\s+: /, @cpuinfo);
   $model		= join("\n", $model[0]);
   @model		= split(/: /, $model);
   $model		= $model[1];
   $cpu			= "$cpu $model";
   @smp			= grep(/cpus detected\s+: /, @cpuinfo);
   $smp			= join("\n", @smp);
   @smp			= split(/: /, $smp);
   $smp			= $smp[1];
  }
  if($armv4l) {
   @cpu			= grep(/Processor\s+: /, @cpuinfo);
   $cpu			= join("\n", $cpu[0]);
   @cpu			= split(/: /, $cpu);
   $cpu			= $cpu[1];
  }
  if($i686 || $i586) {
   @cpu			= grep(/model name\s+: /, @cpuinfo);
   $cpu			= join("\n", $cpu[0]);
   @cpu			= split(/: /, $cpu);
   $cpu			= $cpu[1];
   $cpu			=~ s/(.+) CPU family\t+\d+MHz/$1/g;
   $cpu			=~ s/(.+) CPU .+GHz/$1/g;
   @mhz			= grep(/cpu MHz\s+: /, @cpuinfo);
   $mhz			= join("\n", $mhz[0]);
   @mhz			= split(/: /, $mhz);
   $mhz			= $mhz[1];
   $cpu			= "$cpu ($mhz MHz)";
   @smp			= grep(/processor\s+: /, @cpuinfo);
   $smp			= scalar @smp;
  }
  if($ia64) {
   @cpu			= grep(/vendor\s+: /, @cpuinfo);
   $cpu			= join("\n", $cpu[0]);
   @cpu			= split(/: /, $cpu);
   $cpu			= $cpu[1];
   @model		= grep(/family\s+: /, @cpuinfo);
   $model		= join("\n", $model[0]);
   @model		= split(/: /, $model);
   $model		= $model[1];
   @mhz			= grep(/cpu MHz\s+: /, @cpuinfo);
   $mhz			= join("\n", $mhz[0]);
   @mhz			= split(/: /, $mhz);
   $mhz			= sprintf("%.2f", $mhz[1]);
   $cpu			= "$cpu $model ($mhz MHz)";
   @smp			= grep(/processor\s+: /, @cpuinfo);
   $smp			= scalar @smp;
  }
  if($mips) {
   @cpu			= grep(/cpu\s+: /, @cpuinfo);
   $cpu			= join("\n", $cpu[0]);
   @cpu			= split(/: /, $cpu);
   $cpu			= $cpu[1];
   @model		= grep(/cpu model\s+: /, @cpuinfo);
   $model		= join("\n", $model[0]);
   @model		= split(/: /, $model);
   $model		= $model[1];
   $cpu			= "$cpu $model";
  }
  if($parisc64) {
   @cpu			= grep(/cpu\s+: /, @cpuinfo);
   $cpu			= join("\n", $cpu[0]);
   @cpu			= split(/: /, $cpu);
   $cpu			= $cpu[1];
   @model		= grep(/model name\s+: /, @cpuinfo);
   $model		= join("\n", $model[0]);
   @model		= split(/: /, $model);
   $model		= $model[1];
   @mhz			= grep(/cpu MHz\s+: /, @cpuinfo);
   $mhz			= join("\n", $mhz[0]);
   @mhz			= split(/: /, $mhz);
   $mhz			= sprintf("%.2f", $mhz[1]);
   $cpu			= "$model $cpu ($mhz MHz)";
  }
  if($ppc) {
   @cpu			= grep(/cpu\s+: /, @cpuinfo);
   $cpu			= join("\n", $cpu[0]);
   @cpu			= split(/: /, $cpu);
   $cpu			= $cpu[1];
   @mhz			= grep(/clock\s+: /, @cpuinfo);
   $mhz			= join("\n", $mhz[0]);
   @mhz			= split(/: /, $mhz);
   $mhz			= $mhz[1];
   if($cpu =~ /^9.+/) {
    $model		= "IBM PowerPC G5";
   } elsif($cpu =~ /^74.+/) {
    $model		= "Motorola PowerPC G4";
   } else {
    $model		= "IBM PowerPC G3";
   }
   $cpu			= "$model $cpu ($mhz)";
  }
 } elsif($darwin) {
  $cpu			= `hostinfo | grep 'Processor type' | cut -f2 -d':'`; chop($cpu);
  $cpu			= "$cpu," . `AppleSystemProfiler | grep 'Machine speed' | cut -f2 -d'='`;
 }
 if($smp && $smp gt 1) {
  $cpu = "$smp x $cpu";
 }


 my $procs	= `ps ax | grep -v PID | wc -l`; chop($procs);
 $procs			= $procs;
 $procs			=~ s/^\s+//;
 $procs			=~ s/\s+$//;

 my ($boottime, $ticks, $currenttime, $days, $hours, $mins);
 if($freebsd) {
  $boottime		= `$sysctl -n kern.boottime | awk '{print \$4}'`;
 }
 if($netbsd || $openbsd || $darwin) {
  $boottime		= `$sysctl -n kern.boottime`;
 }
 if($linux) {
  @uptime		= split(/ /, $uptime[0]);
  $ticks		= $uptime[0];
 } else {
  chop($boottime);
  $boottime		=~ s/,//g;
  $currenttime		= `date +%s`; chop($currenttime);
  $ticks		= $currenttime - $boottime;
 }
 $ticks			= sprintf("%2d", $ticks);
 $days			= floor($ticks / 86400);
 $ticks			%= 86400;
 $hours			= floor($ticks / 3600);
 $ticks			%= 3600;
 $mins			= floor($ticks / 60);
 if($days  eq 0) { $days  = ''; } elsif($days  >= 1) { $days  = $days.  'd '; }
 if($hours eq 0) { $hours = ''; } elsif($hours >= 1) { $hours = $hours. 'h '; }
 if($mins  eq 0) { $mins  = ''; } elsif($mins  >= 1) { $mins  = $mins.  'm';  }
 $uptime = $days . $hours . $mins;

 my ($load, @load);
 $load			= `uptime`; chop($load);
 if($linux) {
  @load			= split(/average: /,  $load, 2);
 } else {
  @load			= split(/averages: /, $load, 2);
 }
 @load			= split(/, /, $load[1], 2);
 $load			= $load[0];


 my (@memtotal, $memtotal, @membuffers, $membuffers, @memcached, $memcached, @memused, $memused);
 if($linux) {
  if($l26) {
   @memtotal		= grep(/MemTotal:/, @meminfo);
   $memtotal		= join("\n", @memtotal);
   @memtotal		= split(/\s+/, $memtotal);
   $memtotal		= $memtotal[1] * 1024;
   @membuffers		= grep(/Buffers:/, @meminfo);
   $membuffers		= join("\n", @membuffers);
   @membuffers		= split(/\s+/, $membuffers);
   $membuffers		= $membuffers[1] * 1024;
   @memcached		= grep(/Cached:/, @meminfo);
   $memcached		= join("\n", @memcached);
   @memcached		= split(/\s+/, $memcached);
   $memcached		= $memcached[1] * 1024;
   @memused		= grep(/MemFree:/, @meminfo);
   $memused		= join("\n", @memused);
   @memused		= split(/\s+/, $memused);
   $memused		= ($memtotal - ($memused[1] * 1024)) - $membuffers - $memcached;
  } else {
   @meminfo		= grep(/Mem:/, @meminfo);
   $meminfo		= join("\n", @meminfo);
   @meminfo		= split(/\s+/, $meminfo);
   $memtotal		= $meminfo[1];
   $memused		= $meminfo[2] - $meminfo[5] - $meminfo[6];
  }
 } elsif($darwin) {
  $memused		= `vm_stat | grep 'Pages active' | awk '{print \$3}'` * 4096;
  $memtotal		= `$sysctl -n hw.physmem`;
 } else {
  $memused		= `vmstat -s | grep 'pages active' | awk '{print \$1}'` * `vmstat -s | grep 'per page' | awk '{print \$1}'`;
  $memtotal		= `$sysctl -n hw.physmem`;
 }
 my $mempused		= sprintf("%.2f", $memused / $memtotal * 100);
 $memtotal		= sprintf("%.2f", $memtotal / 1024 / 1024);
 $memused		= sprintf("%.2f", $memused / 1024 / 1024);


 my $hddtotal	= `$df | grep -v Filesystem | awk '{ sum+=\$2 / 1024 / 1024}; END { print sum }'`; chop($hddtotal);
 my $hddused	= `$df | grep -v Filesystem | awk '{ sum+=\$3 / 1024 / 1024}; END { print sum }'`; chop($hddused);
 my $hddpused	= sprintf("%.2f", $hddused / $hddtotal * 100);
 $hddtotal		= sprintf("%.2f", $hddtotal);
 $hddused		  = sprintf("%.2f", $hddused);

 my (@lan_in_1, $lan_in_1, @lan_out_1, $lan_out_1,
     @lan_in_2, $lan_in_2, @lan_out_2, $lan_out_2,
     @lan_in_3, $lan_in_3, @lan_out_3, $lan_out_3);
 if($n1) {
  if($darwin || $freebsd) {
   @lan_in_1		= grep(/$nic_1/, @netstat);
   @lan_in_1		= grep(/Link/, @lan_in_1);
   $lan_in_1		= join("\n", @lan_in_1);
   @lan_in_1		= split(/\s+/, $lan_in_1);
   $lan_in_1		= $lan_in_1[6] / 1024 / 1024;
  }
  if($netbsd || $openbsd) {
   @lan_in_1		= grep(/$nic_1/, @netstat);
   @lan_in_1		= grep(/Link/, @lan_in_1);
   $lan_in_1		= join("\n", @lan_in_1);
   @lan_in_1		= split(/\s+/, $lan_in_1);
   $lan_in_1		= $lan_in_1[4] / 1024 / 1024;
  }
  if($linux) {
   @lan_in_1		= grep(/$nic_1/, @netdev);
   $lan_in_1		= join("\n", @lan_in_1);
   @lan_in_1		= split(/:\s*/, $lan_in_1);
   @lan_in_1		= split(/\s+/, $lan_in_1[1]);
   $lan_in_1		= $lan_in_1[0] / 1024 / 1024;
  }
  $lan_in_1		= sprintf("%.2f", $lan_in_1);
  if($darwin || $freebsd) {
   @lan_out_1		= grep(/$nic_1/, @netstat);
   @lan_out_1		= grep(/Link/, @lan_out_1);
   $lan_out_1		= join("\n", @lan_out_1);
   @lan_out_1		= split(/\s+/, $lan_out_1);
   $lan_out_1		= $lan_out_1[9] / 1024 / 1024;
  }
  if($netbsd || $openbsd) {
   @lan_out_1		= grep(/$nic_1/, @netstat);
   @lan_out_1		= grep(/Link/, @lan_out_1);
   $lan_out_1		= join("\n", @lan_out_1);
   @lan_out_1		= split(/\s+/, $lan_out_1);
   $lan_out_1		= $lan_out_1[5] / 1024 / 1024;
  }
  if($linux) {
   @lan_out_1		= grep(/$nic_1/, @netdev);
   $lan_out_1		= join("\n", @lan_out_1);
   @lan_out_1		= split(/:\s*/, $lan_out_1);
   @lan_out_1		= split(/\s+/, $lan_out_1[1]);
   $lan_out_1		= $lan_out_1[8] / 1024 / 1024;
  }
  $lan_out_1		= sprintf("%.2f", $lan_out_1);
 }


 if($n2) {
  if($darwin || $freebsd) {
   @lan_in_2		= grep(/$nic_2/, @netstat);
   @lan_in_2		= grep(/Link/, @lan_in_2);
   $lan_in_2		= join("\n", @lan_in_2);
   @lan_in_2		= split(/\s+/, $lan_in_2);
   $lan_in_2		= $lan_in_2[6] / 1024 / 1024;
  }
  if($netbsd || $openbsd) {
   @lan_in_2		= grep(/$nic_2/, @netstat);
   @lan_in_2		= grep(/Link/, @lan_in_2);
   $lan_in_2		= join("\n", @lan_in_2);
   @lan_in_2		= split(/\s+/, $lan_in_2);
   $lan_in_2		= $lan_in_2[4] / 1024 / 1024;
  }
  if($linux) {
   @lan_in_2		= grep(/$nic_2/, @netdev);
   $lan_in_2		= join("\n", @lan_in_2);
   @lan_in_2		= split(/:\s*/, $lan_in_2);
   @lan_in_2		= split(/\s+/, $lan_in_2[1]);
   $lan_in_2		= $lan_in_2[0] / 1024 / 1024;
  }
  $lan_in_2		= sprintf("%.2f", $lan_in_2);
  if($darwin || $freebsd) {
   @lan_out_2		= grep(/$nic_2/, @netstat);
   @lan_out_2		= grep(/Link/, @lan_out_2);
   $lan_out_2		= join("\n", @lan_out_2);
   @lan_out_2		= split(/\s+/, $lan_out_2);
   $lan_out_2		= $lan_out_2[9] / 1024 / 1024;
  }
  if($netbsd || $openbsd) {
   @lan_out_2		= grep(/$nic_2/, @netstat);
   @lan_out_2		= grep(/Link/, @lan_out_2);
   $lan_out_2		= join("\n", @lan_out_2);
   @lan_out_2		= split(/\s+/, $lan_out_2);
   $lan_out_2		= $lan_out_2[4] / 1024 / 1024;
  }
  if($linux) {
   @lan_out_2		= grep(/$nic_2/, @netdev);
   $lan_out_2		= join("\n", @lan_out_2);
   @lan_out_2		= split(/:\s*/, $lan_out_2);
   @lan_out_2		= split(/\s+/, $lan_out_2[1]);
   $lan_out_2		= $lan_out_2[8] / 1024 / 1024;
  }
  $lan_out_2		= sprintf("%.2f", $lan_out_2);
 }


 if($n3) {
  if($darwin || $freebsd) {
   @lan_in_3		= grep(/$nic_3/, @netstat);
   @lan_in_3		= grep(/Link/, @lan_in_3);
   $lan_in_3		= join("\n", @lan_in_3);
   @lan_in_3		= split(/\s+/, $lan_in_3);
   $lan_in_3		= $lan_in_3[6] / 1024 / 1024;
  }
  if($netbsd || $openbsd) {
   @lan_in_3		= grep(/$nic_3/, @netstat);
   @lan_in_3		= grep(/Link/, @lan_in_3);
   $lan_in_3		= join("\n", @lan_in_3);
   @lan_in_3		= split(/\s+/, $lan_in_3);
   $lan_in_3		= $lan_in_3[4] / 1024 / 1024;
  }
  if($linux) {
   @lan_in_3		= grep(/$nic_3/, @netdev);
   $lan_in_3		= join("\n", @lan_in_3);
   @lan_in_3		= split(/:\s*/, $lan_in_3);
   @lan_in_3		= split(/\s+/, $lan_in_3[1]);
   $lan_in_3		= $lan_in_3[0] / 1024 / 1024;
  }
  $lan_in_3		= sprintf("%.2f", $lan_in_3);
  if($darwin || $freebsd) {
   @lan_out_3		= grep(/$nic_3/, @netstat);
   @lan_out_3		= grep(/Link/, @lan_out_3);
   $lan_out_3		= join("\n", @lan_out_3);
   @lan_out_3		= split(/\s+/, $lan_out_3);
   $lan_out_3		= $lan_out_3[9] / 1024 / 1024;
  }
  if($netbsd || $openbsd) {
   @lan_out_3		= grep(/$nic_3/, @netstat);
   @lan_out_3		= grep(/Link/, @lan_out_3);
   $lan_out_3		= join("\n", @lan_out_3);
   @lan_out_3		= split(/\s+/, $lan_out_3);
   $lan_out_3		= $lan_out_3[4] / 1024 / 1024;
  }
  if($linux) {
   @lan_out_3		= grep(/$nic_3/, @netdev);
   $lan_out_3		= join("\n", @lan_out_3);
   @lan_out_3		= split(/:\s*/, $lan_out_3);
   @lan_out_3		= split(/\s+/, $lan_out_3[1]);
   $lan_out_3		= $lan_out_3[8] / 1024 / 1024;
  }
  $lan_out_3		= sprintf("%.2f", $lan_out_3);
 }


 my $output  = "Hostname: $osn - ";
 $output .= "OS: $uname - ";
 $output .= "CPU: $cpu - ";
 $output .= "Processes: $procs - ";
 $output .= "Uptime: $uptime - ";
 $output .= "Load Average: $load - ";
 $output .= "Memory Usage: $memused" . "mb/$memtotal" . "mb ($mempused%) - ";
 $output .= "Disk Usage: $hddused" . "gb/$hddtotal" . "gb ($hddpused%) - ";
 if($n1) { $output .= "$nic_1_name Traffic ($nic_1): $lan_in_1" . "mb/" . $lan_out_1 . "mb - "; }
 if($n2) { $output .= "$nic_2_name Traffic ($nic_2): $lan_in_2" . "mb/" . $lan_out_2 . "mb - "; }
 if($n3) { $output .= "$nic_3_name Traffic ($nic_3): $lan_in_3" . "mb/" . $lan_out_3 . "mb - "; }
 $output =~ s/ - $//g;
 Irssi::active_win()->command("/ $output");
}

Irssi::settings_add_str("sysinfo", "sysinfo_nic_1", "");
Irssi::settings_add_str("sysinfo", "sysinfo_nic_2", "");
Irssi::settings_add_str("sysinfo", "sysinfo_nic_3", "");
Irssi::settings_add_str("sysinfo", "sysinfo_nic_1_name", "External");
Irssi::settings_add_str("sysinfo", "sysinfo_nic_2_name", "Internal");
Irssi::settings_add_str("sysinfo", "sysinfo_nic_3_name", "Wireless");

Irssi::command_bind("sysinfo", "cmd_sysinfo");
