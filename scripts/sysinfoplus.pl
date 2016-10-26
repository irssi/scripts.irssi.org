
# Those <censored> mIRC'ers have all those irritating system info "remotes" to
# brag about their system.
# Now, it's up to Irssi users to brag about their pentium 75's and 2 Gio harddisks.
# :)

# Differences to Juerd-only-version:
# -YASFU units (Mio, Gio) - http://snull.cjb.net/?yasfu
# -Free memory and free swap are displayed (previously only total swap/mem)
# -Reorganized and tuned output
# -Displays length of your virtual penis (this is quite tricky, so you might want to disable it by commenting)
# -Doesn't display info on nfs/smbfs/none-type mounts (edit script if you want those)

# Vpenis is not 100% compatible with Cras' vpenis.sh - I have fixed some bugs:
# -More network filesystems excluded (originally only NFS was excluded)
# -Total amount of memory counts (not the used amount, as before)

# Changelog 2.10 -> 2.20: memory/swap info is displayed now (it was broken previously) and code is properly indented

$VERSION = "2.20";
%IRSSI = (
	  authors     => "Juerd, Tronic",
	  contact     => "trn\@iki.fi",
	  name        => "SysinfoPlus",
	  description => "Linux system information (with vPenis and other stuff)",
	  license     => "Public Domain",
	  url         => "http://juerd.nl/irssi/",
	  changed     => "Mon Nov 04 15:17:30 EET 2002"
	  );

BEGIN{
    use vars '$console';
    eval q{
	use Irssi;
	Irssi::version();
    };
    $console = !!$@;
}

use strict;

# Tronic has no time for maintaining this and Juerd hates braces, so it might be better
# not to expect any new versions ...

sub sysinfo{
    # This should really need indenting, but I'm kinda lazy.
    
    my (@uname, $ret, @pci, $usr, $avg, $up, $vpenis);
    
    @uname = (split ' ', `uname -a`)[0..2];
    
    $ret = "Host '@uname[1]', running @uname[0] @uname[2] - ";
    
    open FOO, '/proc/cpuinfo';
    while (<FOO>){
	/^processor\s*:\s*(\d+)/         ? $ret .= "Cpu$1: "
	  : /^model name\s*:\s*(\w+[ A-Za-z]*)/ ? do { my $t = $1; $t =~ s/\s+$//; $ret .= "$t " }
	: /^cpu MHz\s*:\s*([\.\d]+)/       ? $ret .= int(.5+$1) . ' MHz '
	  : undef;
    }
    close FOO;
    $ret =~ s/( ?)$/;$1/;
    open FOO, '/proc/pci';
    while (<FOO>){
	/^\s*(?:multimedia )?(.*?)( storage| compatible)? controller/i and push @pci, $1;
    }
    close FOO;
    $ret .= 'PCI: ' . join(',', map ucfirst, @pci) . '; ' if @pci;
    if (`uptime` =~ /^.*?up\s*(.*?),\s*(\d+) users?,.*: ([\d\.]+)/){
	($usr, $avg) = ($2, $3);
	($up = $1) =~ s/\s*days?,\s*|\+/d+/;
	$ret .= "Up: $up; Users: $usr; Load: $avg; ";
    }
    
    # Free space
    $ret .= "Free:";
    if (`free` =~ /Mem:\s*(\d*)\s*\d*\s*(\d*)/) { $ret .= " [Mem: " . int(.5 + $2/2**10) . "/" . int(.5 + $1/2**10) . " Mio]"; } # For compatibility: replace $1 with $2
    if (`free` =~ /Swap:\s*(\d*)\s*\d*\s*(\d*)/) { $ret .= " [Swap: " . int(.5 + $2/2**10) . "/" . int(.5 + $1/2**10) . " Mio]"; } # For compatibility: replace $1 with $2

    for (`df -m -x nfs -x smbfs -x none`) {
	/^\/\S*\s*(\S*)\s*\S*\s*(\S*)\s*\S*\s*(\S*)/ and $ret .= " [$3: $2/$1 Mio]";
    }
    $ret .= ";";
    
    # Vpenis (derived from vpenis.sh)
    $vpenis = 70;
    if (`cat /proc/uptime` =~ /(\d*)/) { $vpenis += int($1/3600/24)/10; }
    if (`cat /proc/cpuinfo` =~ /MHz\s*:\s*(\S*)/) { $vpenis += $1/30; }
    if (`free` =~ /Mem:\s*(\d*)\s*(\d*)/) { $vpenis += $1/1024/3; } # For compatibility: replace $1 with $2
    for (`df -P -k -x nfs -x smbfs -x none|grep -v blocks`) { # For compatibility: remove -x smbfs -x none
	if (/^\S*\s*(\S*)/) { $usr = $1; $vpenis += ((/^\/dev\/(scsi|sd)/) ? 2*$usr : $usr)/1024/50/15; }
    }
    $ret .= " Vpenis: " . int($vpenis)/10 . " cm;";
    
    if ($console){
	print "$ret\n";
    }else{
	Irssi::active_win->command("/say $ret");
    }
} #end of sub
  
if ($console){
    sysinfo();
}else{
    Irssi::command_bind('sysinfo', 'sysinfo')
}
